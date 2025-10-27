/*
==============================================================================
COMPREHENSIVE DATA QUALITY VALIDATION SCRIPT
For Compensation Survey Data
==============================================================================
Author: Data Engineering Team
Version: 1.0
Date: 2024
Description: Production-ready T-SQL script for comprehensive data quality 
             validation of compensation survey data across all categories.
             
Optimizations Applied:
- Set-based operations instead of cursors
- Consolidated related checks into single queries
- Parameterized for reusability
- Comprehensive error handling and transaction management
- Centralized logging mechanism
- Idempotent execution capability
==============================================================================
*/

SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- ============================================================================
-- SECTION 1: PRE-CHECK SETUP AND CONFIGURATION
-- ============================================================================

BEGIN TRY
    -- Start transaction for atomic execution
    BEGIN TRANSACTION DQ_Validation;
    
    -- Declare variables for configuration
    DECLARE @ExecutionId UNIQUEIDENTIFIER = NEWID();
    DECLARE @StartTime DATETIME2 = GETDATE();
    DECLARE @TotalRecords INT;
    DECLARE @ErrorCount INT = 0;
    DECLARE @WarningCount INT = 0;
    DECLARE @ValidationDate DATE = CAST(GETDATE() AS DATE);
    
    -- Configuration parameters
    DECLARE @MaxSalaryUSD DECIMAL(15,2) = 2000000;  -- Maximum reasonable salary in USD
    DECLARE @MinSalaryUSD DECIMAL(15,2) = 15000;    -- Minimum reasonable salary in USD
    DECLARE @MaxExperienceYears INT = 50;           -- Maximum reasonable experience
    DECLARE @MaxVariablePayRatio DECIMAL(5,2) = 5.0; -- Maximum variable pay as ratio of base
    DECLARE @MaxBenefitsRatio DECIMAL(5,2) = 1.0;   -- Maximum benefits as ratio of base
    DECLARE @DataRetentionYears INT = 5;            -- Data retention period
    
    -- Get total record count for percentage calculations
    SELECT @TotalRecords = COUNT(*) FROM compensation_survey;
    
    -- Create temporary table for consolidated results
    IF OBJECT_ID('tempdb..#DQ_ValidationResults') IS NOT NULL
        DROP TABLE #DQ_ValidationResults;
        
    CREATE TABLE #DQ_ValidationResults (
        ExecutionId UNIQUEIDENTIFIER,
        RuleId VARCHAR(50),
        RuleName VARCHAR(200),
        Category VARCHAR(100),
        Severity VARCHAR(20),
        ViolationCount INT,
        TotalRecords INT,
        ViolationPercentage DECIMAL(5,2),
        Description NVARCHAR(500),
        SampleViolations NVARCHAR(MAX),
        CheckTimestamp DATETIME2,
        Status VARCHAR(20)
    );
    
    -- Create temporary table for error logging
    IF OBJECT_ID('tempdb..#DQ_ErrorLog') IS NOT NULL
        DROP TABLE #DQ_ErrorLog;
        
    CREATE TABLE #DQ_ErrorLog (
        ExecutionId UNIQUEIDENTIFIER,
        ErrorTimestamp DATETIME2,
        ErrorMessage NVARCHAR(MAX),
        ErrorSeverity INT,
        ErrorState INT,
        ErrorProcedure NVARCHAR(128)
    );
    
    PRINT 'Data Quality Validation Started - Execution ID: ' + CAST(@ExecutionId AS VARCHAR(36));
    PRINT 'Total Records to Validate: ' + CAST(@TotalRecords AS VARCHAR(20));
    PRINT '============================================================================';

-- ============================================================================
-- SECTION 2: GEOGRAPHIC DATA QUALITY CHECKS
-- ============================================================================

    PRINT 'Executing Geographic Data Quality Checks...';
    
    -- Rule GEO-001: Country Code ISO Validation
    INSERT INTO #DQ_ValidationResults
    SELECT 
        @ExecutionId,
        'GEO-001',
        'Country Code ISO Validation',
        'Geographic Data',
        'HIGH',
        COUNT(*),
        @TotalRecords,
        CAST(COUNT(*) * 100.0 / @TotalRecords AS DECIMAL(5,2)),
        'Country codes must conform to ISO 3166-1 alpha-2 standards',
        STRING_AGG(CAST(survey_id AS VARCHAR(20)), ', ') WITHIN GROUP (ORDER BY survey_id),
        GETDATE(),
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
    FROM compensation_survey 
    WHERE country_code IS NULL 
       OR LEN(country_code) != 2
       OR country_code NOT LIKE '[A-Z][A-Z]'
       OR country_code IN ('XX', 'ZZ', '00', '11');
    
    -- Rule GEO-002: Country Name Consistency
    WITH CountryInconsistencies AS (
        SELECT country_code, COUNT(DISTINCT country_name) as name_variations
        FROM compensation_survey
        WHERE country_code IS NOT NULL AND country_name IS NOT NULL
        GROUP BY country_code
        HAVING COUNT(DISTINCT country_name) > 1
    )
    INSERT INTO #DQ_ValidationResults
    SELECT 
        @ExecutionId,
        'GEO-002',
        'Country Name Consistency',
        'Geographic Data',
        'MEDIUM',
        (SELECT COUNT(*) FROM CountryInconsistencies),
        @TotalRecords,
        CAST((SELECT COUNT(*) FROM CountryInconsistencies) * 100.0 / @TotalRecords AS DECIMAL(5,2)),
        'Country names should be consistent for each country code',
        (SELECT STRING_AGG(country_code, ', ') FROM CountryInconsistencies),
        GETDATE(),
        CASE WHEN (SELECT COUNT(*) FROM CountryInconsistencies) = 0 THEN 'PASS' ELSE 'FAIL' END;
    
    -- Rule GEO-003: Region-Country Consistency
    INSERT INTO #DQ_ValidationResults
    SELECT 
        @ExecutionId,
        'GEO-003',
        'Region Country Consistency',
        'Geographic Data',
        'MEDIUM',
        COUNT(*),
        @TotalRecords,
        CAST(COUNT(*) * 100.0 / @TotalRecords AS DECIMAL(5,2)),
        'Regions should be valid for their respective countries',
        STRING_AGG(CAST(survey_id AS VARCHAR(20)), ', ') WITHIN GROUP (ORDER BY survey_id),
        GETDATE(),
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
    FROM compensation_survey
    WHERE region IS NOT NULL 
      AND country_code IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM (
              VALUES 
                  ('US', 'California'), ('US', 'New York'), ('US', 'Texas'), ('US', 'Florida'),
                  ('GB', 'England'), ('GB', 'Scotland'), ('GB', 'Wales'),
                  ('CA', 'Ontario'), ('CA', 'Quebec'), ('CA', 'British Columbia'),
                  ('DE', 'Bavaria'), ('DE', 'North Rhine-Westphalia'),
                  ('FR', 'Île-de-France'), ('FR', 'Provence-Alpes-Côte d\'Azur')
          ) AS ValidRegions(CountryCode, RegionName)
          WHERE ValidRegions.CountryCode = compensation_survey.country_code
            AND ValidRegions.RegionName = compensation_survey.region
      );
    
    -- Rule GEO-004: City Data Quality
    INSERT INTO #DQ_ValidationResults
    SELECT 
        @ExecutionId,
        'GEO-004',
        'City Data Quality',
        'Geographic Data',
        'LOW',
        COUNT(*),
        @TotalRecords,
        CAST(COUNT(*) * 100.0 / @TotalRecords AS DECIMAL(5,2)),
        'City names should be properly formatted and complete',
        STRING_AGG(CAST(survey_id AS VARCHAR(20)), ', ') WITHIN GROUP (ORDER BY survey_id),
        GETDATE(),
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
    FROM compensation_survey
    WHERE city IS NOT NULL 
      AND (LEN(TRIM(city)) < 2 
           OR city LIKE '%[0-9][0-9][0-9]%'
           OR city LIKE '%[^a-zA-Z0-9 .-]%');

-- ============================================================================
-- SECTION 3: INDUSTRY DATA QUALITY CHECKS
-- ============================================================================

    PRINT 'Executing Industry Data Quality Checks...';
    
    -- Rule IND-001: Industry Code Validation
    INSERT INTO #DQ_ValidationResults
    SELECT 
        @ExecutionId,
        'IND-001',
        'Industry Code Validation',
        'Industry Data',
        'HIGH',
        COUNT(*),
        @TotalRecords,
        CAST(COUNT(*) * 100.0 / @TotalRecords AS DECIMAL(5,2)),
        'Industry codes must be valid NAICS/SIC codes',
        STRING_AGG(CAST(survey_id AS VARCHAR(20)), ', ') WITHIN GROUP (ORDER BY survey_id),
        GETDATE(),
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
    FROM compensation_survey
    WHERE industry_code IS NOT NULL 
      AND (LEN(industry_code) NOT BETWEEN 2 AND 6
           OR industry_code NOT LIKE '[0-9]%'
           OR industry_code LIKE '%[^0-9]%');
    
    -- Rule IND-002: Industry Hierarchy Consistency
    INSERT INTO #DQ_ValidationResults
    SELECT 
        @ExecutionId,
        'IND-002',
        'Industry Hierarchy Consistency',
        'Industry Data',
        'MEDIUM',
        COUNT(*),
        @TotalRecords,
        CAST(COUNT(*) * 100.0 / @TotalRecords AS DECIMAL(5,2)),
        'Sub-industry should not exist without parent industry',
        STRING_AGG(CAST(survey_id AS VARCHAR(20)), ', ') WITHIN GROUP (ORDER BY survey_id),
        GETDATE(),
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
    FROM compensation_survey
    WHERE sub_industry IS NOT NULL AND industry IS NULL;
    
    -- Rule IND-003: Sector Classification Validation
    INSERT INTO #DQ_ValidationResults
    SELECT 
        @ExecutionId,
        'IND-003',
        'Sector Classification Validation',
        'Industry Data',
        'MEDIUM',
        COUNT(*),
        @TotalRecords,
        CAST(COUNT(*) * 100.0 / @TotalRecords AS DECIMAL(5,2)),
        'Sector must be Public, Private, or Non-Profit',
        STRING_AGG(CAST(survey_id AS VARCHAR(20)), ', ') WITHIN GROUP (ORDER BY survey_id),
        GETDATE(),
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
    FROM compensation_survey
    WHERE sector IS NOT NULL 
      AND sector NOT IN ('Public', 'Private', 'Non-Profit', 'Government', 'NGO');

-- ============================================================================
-- SECTION 4: ORGANIZATION DATA QUALITY CHECKS
-- ============================================================================

    PRINT 'Executing Organization Data Quality Checks...';
    
    -- Rule ORG-001: Company ID Uniqueness
    WITH DuplicateCompanyIds AS (
        SELECT company_id, COUNT(*) as duplicate_count
        FROM compensation_survey
        WHERE company_id IS NOT NULL
        GROUP BY company_id
        HAVING COUNT(*) > 1
    )
    INSERT INTO #DQ_ValidationResults
    SELECT 
        @ExecutionId,
        'ORG-001',
        'Company ID Uniqueness',
        'Organization Data',
        'HIGH',
        (SELECT SUM(duplicate_count) FROM DuplicateCompanyIds),
        @TotalRecords,
        CAST((SELECT SUM(duplicate_count) FROM DuplicateCompanyIds) * 100.0 / @TotalRecords AS DECIMAL(5,2)),
        'Each company should have a unique identifier',
        (SELECT STRING_AGG(CAST(company_id AS VARCHAR(20)), ', ') FROM DuplicateCompanyIds),
        GETDATE(),
        CASE WHEN (SELECT COUNT(*) FROM DuplicateCompanyIds) = 0 THEN 'PASS' ELSE 'FAIL' END;
    
    -- Rule ORG-002: Company Size Validation
    INSERT INTO #DQ_ValidationResults
    SELECT 
        @ExecutionId,
        'ORG-002',
        'Company Size Validation',
        'Organization Data',
        'MEDIUM',
        COUNT(*),
        @TotalRecords,
        CAST(COUNT(*) * 100.0 / @TotalRecords AS DECIMAL(5,2)),
        'Company size must be valid category and consistent with employee count',
        STRING_AGG(CAST(survey_id AS VARCHAR(20)), ', ') WITHIN GROUP (ORDER BY survey_id),
        GETDATE(),
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
    FROM compensation_survey
    WHERE (company_size IS NOT NULL AND company_size NOT IN ('Small', 'Medium', 'Large', 'Enterprise'))
       OR (employee_count IS NOT NULL AND employee_count <= 0)
       OR (employee_count IS NOT NULL AND employee_count > 10000000)
       OR (company_size = 'Small' AND employee_count > 500)
       OR (company_size = 'Enterprise' AND employee_count < 10000);
    
    -- Rule ORG-003: Employee Count Range Validation
    INSERT INTO #DQ_ValidationResults
    SELECT 
        @ExecutionId,
        'ORG-003',
        'Employee Count Range Validation',
        'Organization Data',
        'MEDIUM',
        COUNT(*),
        @TotalRecords,
        CAST(COUNT(*) * 100.0 / @TotalRecords AS DECIMAL(5,2)),
        'Employee count should be within reasonable ranges',
        STRING_AGG(CAST(survey_id AS VARCHAR(20)), ', ') WITHIN GROUP (ORDER BY survey_id),
        GETDATE(),
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
    FROM compensation_survey
    WHERE employee_count IS NOT NULL 
      AND (employee_count < 1 OR employee_count > 10000000);

-- ============================================================================
-- SECTION 5: JOB DATA QUALITY CHECKS
-- ============================================================================

    PRINT 'Executing Job Data Quality Checks...';
    
    -- Rule JOB-001: Job Title Completeness and Format
    INSERT INTO #DQ_ValidationResults
    SELECT 
        @ExecutionId,
        'JOB-001',
        'Job Title Completeness and Format',
        'Job Data',
        'HIGH',
        COUNT(*),
        @TotalRecords,
        CAST(COUNT(*) * 100.0 / @TotalRecords AS DECIMAL(5,2)),
        'Job titles must be present and properly formatted',
        STRING_AGG(CAST(survey_id AS VARCHAR(20)), ', ') WITHIN GROUP (ORDER BY survey_id),
        GETDATE(),
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
    FROM compensation_survey
    WHERE job_title IS NULL 
       OR LEN(TRIM(job_title)) < 3
       OR job_title LIKE '%[0-9][0-9][0-9][0-9]%';
    
    -- Rule JOB-002: Job Level Consistency
    INSERT INTO #DQ_ValidationResults
    SELECT 
        @ExecutionId,
        'JOB-002',
        'Job Level Consistency',
        'Job Data',
        'MEDIUM',
        COUNT(*),
        @TotalRecords,
        CAST(COUNT(*) * 100.0 / @TotalRecords AS DECIMAL(5,2)),
        'Job levels must be valid and consistent with experience',
        STRING_AGG(CAST(survey_id AS VARCHAR(20)), ', ') WITHIN GROUP (ORDER BY survey_id),
        GETDATE(),
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
    FROM compensation_survey
    WHERE job_level IS NOT NULL 
      AND (job_level NOT IN ('Entry', 'Mid', 'Senior', 'Executive', 'C-Level')
           OR (job_level = 'Entry' AND years_experience > 3)
           OR (job_level = 'C-Level' AND years_experience < 10)
           OR (job_level = 'Executive' AND years_experience < 8));
    
    -- Rule JOB-003: Experience Range Validation
    INSERT INTO #DQ_ValidationResults
    SELECT 
        @ExecutionId,
        'JOB-003',
        'Experience Range Validation',
        'Job Data',
        'MEDIUM',
        COUNT(*),
        @TotalRecords,
        CAST(COUNT(*) * 100.0 / @TotalRecords AS DECIMAL(5,2)),
        'Years of experience should be within reasonable ranges',
        STRING_AGG(CAST(survey_id AS VARCHAR(20)), ', ') WITHIN GROUP (ORDER BY survey_id),
        GETDATE(),
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
    FROM compensation_survey
    WHERE years_experience IS NOT NULL 
      AND (years_experience < 0 OR years_experience > @MaxExperienceYears);

-- ============================================================================
-- SECTION 6: COMPENSATION DATA QUALITY CHECKS
-- ============================================================================

    PRINT 'Executing Compensation Data Quality Checks...';
    
    -- Rule COMP-001: Base Salary Range and Currency Validation
    INSERT INTO #DQ_ValidationResults
    SELECT 
        @ExecutionId,
        'COMP-001',
        'Base Salary Range and Currency Validation',
        'Compensation Data',
        'HIGH',
        COUNT(*),
        @TotalRecords,
        CAST(COUNT(*) * 100.0 / @TotalRecords AS DECIMAL(5,2)),
        'Base salary must be within reasonable ranges and have valid currency',
        STRING_AGG(CAST(survey_id AS VARCHAR(20)), ', ') WITHIN GROUP (ORDER BY survey_id),
        GETDATE(),
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
    FROM compensation_survey
    WHERE base_salary IS NOT NULL 
      AND (base_salary <= 0 
           OR base_salary > @MaxSalaryUSD
           OR (currency = 'USD' AND base_salary < @MinSalaryUSD)
           OR currency IS NULL
           OR LEN(currency) != 3
           OR currency NOT IN ('USD', 'EUR', 'GBP', 'CAD', 'AUD', 'JPY', 'CHF', 'SEK', 'NOK', 'DKK'));
    
    -- Rule COMP-002: Salary Outlier Detection by Job Level and Country
    WITH SalaryPercentiles AS (
        SELECT 
            job_level, 
            country_code,
            PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY base_salary) as P5,
            PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY base_salary) as P95,
            COUNT(*) as sample_size
        FROM compensation_survey
        WHERE base_salary IS NOT NULL 
          AND job_level IS NOT NULL 
          AND country_code IS NOT NULL
        GROUP BY job_level, country_code
        HAVING COUNT(*) >= 10  -- Only calculate percentiles for groups with sufficient data
    ),
    SalaryOutliers AS (
        SELECT cs.survey_id, cs.job_level, cs.country_code, cs.base_salary
        FROM compensation_survey cs
        INNER JOIN SalaryPercentiles sp ON cs.job_level = sp.job_level 
                                        AND cs.country_code = sp.country_code
        WHERE cs.base_salary < sp.P5 OR cs.base_salary > sp.P95
    )
    INSERT INTO #DQ_ValidationResults
    SELECT 
        @ExecutionId,
        'COMP-002',
        'Salary Outlier Detection',
        'Compensation Data',
        'MEDIUM',
        COUNT(*),
        @TotalRecords,
        CAST(COUNT(*) * 100.0 / @TotalRecords AS DECIMAL(5,2)),
        'Salaries outside 5th-95th percentile range for job level and country',
        STRING_AGG(CAST(survey_id AS VARCHAR(20)), ', ') WITHIN GROUP (ORDER BY survey_id),
        GETDATE(),
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'WARNING' END
    FROM SalaryOutliers;
    
    -- Rule COMP-003: Variable Pay Ratio Validation
    INSERT INTO #DQ_ValidationResults
    SELECT 
        @ExecutionId,
        'COMP-003',
        'Variable Pay Ratio Validation',
        'Compensation Data',
        'MEDIUM',
        COUNT(*),
        @TotalRecords,
        CAST(COUNT(*) * 100.0 / @TotalRecords AS DECIMAL(5,2)),
        'Variable pay should not exceed reasonable ratio of base salary',
        STRING_AGG(CAST(survey_id AS VARCHAR(20)), ', ') WITHIN GROUP (ORDER BY survey_id),
        GETDATE(),
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
    FROM compensation_survey
    WHERE variable_pay IS NOT NULL 
      AND base_salary IS NOT NULL 
      AND base_salary > 0
      AND (variable_pay < 0 OR (variable_pay / base_salary) > @MaxVariablePayRatio);
    
    -- Rule COMP-004: Benefits Value Validation
    INSERT INTO #DQ_ValidationResults
    SELECT 
        @ExecutionId,
        'COMP-004',
        'Benefits Value Validation',
        'Compensation Data',
        'MEDIUM',
        COUNT(*),
        @TotalRecords,
        CAST(COUNT(*) * 100.0 / @TotalRecords AS DECIMAL(5,2)),
        'Benefits value should be reasonable percentage of base salary',
        STRING_AGG(CAST(survey_id AS VARCHAR(20)), ', ') WITHIN GROUP (ORDER BY survey_id),
        GETDATE(),
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
    FROM compensation_survey
    WHERE benefits_value IS NOT NULL 
      AND (benefits_value < 0
           OR (base_salary IS NOT NULL AND base_salary > 0 AND (benefits_value / base_salary) > @MaxBenefitsRatio));
    
    -- Rule COMP-005: Total Compensation Consistency
    INSERT INTO #DQ_ValidationResults
    SELECT 
        @ExecutionId,
        'COMP-005',
        'Total Compensation Consistency',
        'Compensation Data',
        'HIGH',
        COUNT(*),
        @TotalRecords,
        CAST(COUNT(*) * 100.0 / @TotalRecords AS DECIMAL(5,2)),
        'Total compensation should equal sum of components',
        STRING_AGG(CAST(survey_id AS VARCHAR(20)), ', ') WITHIN GROUP (ORDER BY survey_id),
        GETDATE(),
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
    FROM compensation_survey
    WHERE total_compensation IS NOT NULL 
      AND ABS(total_compensation - (ISNULL(base_salary, 0) + 
                                   ISNULL(variable_pay, 0) + 
                                   ISNULL(benefits_value, 0) + 
                                   ISNULL(equity_value, 0))) > 1000;

-- ============================================================================
-- SECTION 7: SURVEY METADATA QUALITY CHECKS
-- ============================================================================

    PRINT 'Executing Survey Metadata Quality Checks...';
    
    -- Rule META-001: Survey Date Validation
    INSERT INTO #DQ_ValidationResults
    SELECT 
        @ExecutionId,
        'META-001',
        'Survey Date Validation',
        'Survey Metadata',
        'HIGH',
        COUNT(*),
        @TotalRecords,
        CAST(COUNT(*) * 100.0 / @TotalRecords AS DECIMAL(5,2)),
        'Survey dates must be valid and within retention period',
        STRING_AGG(CAST(survey_id AS VARCHAR(20)), ', ') WITHIN GROUP (ORDER BY survey_id),
        GETDATE(),
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
    FROM compensation_survey
    WHERE survey_date IS NULL
       OR survey_date > GETDATE()
       OR survey_date < DATEADD(YEAR, -@DataRetentionYears, GETDATE());
    
    -- Rule META-002: Response Completeness Assessment
    WITH CompletenessMetrics AS (
        SELECT 
            survey_id,
            CASE WHEN base_salary IS NULL THEN 1 ELSE 0 END +
            CASE WHEN job_title IS NULL THEN 1 ELSE 0 END +
            CASE WHEN country_code IS NULL THEN 1 ELSE 0 END +
            CASE WHEN industry IS NULL THEN 1 ELSE 0 END +
            CASE WHEN company_name IS NULL THEN 1 ELSE 0 END as missing_critical_fields
        FROM compensation_survey
    )
    INSERT INTO #DQ_ValidationResults
    SELECT 
        @ExecutionId,
        'META-002',
        'Response Completeness Assessment',
        'Survey Metadata',
        'MEDIUM',
        COUNT(*),
        @TotalRecords,
        CAST(COUNT(*) * 100.0 / @TotalRecords AS DECIMAL(5,2)),
        'Responses should have all critical fields populated',
        STRING_AGG(CAST(survey_id AS VARCHAR(20)), ', ') WITHIN GROUP (ORDER BY survey_id),
        GETDATE(),
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'WARNING' END
    FROM CompletenessMetrics
    WHERE missing_critical_fields >= 2;
    
    -- Rule META-003: Survey ID Uniqueness
    WITH DuplicateSurveyIds AS (
        SELECT survey_id, COUNT(*) as duplicate_count
        FROM compensation_survey
        WHERE survey_id IS NOT NULL
        GROUP BY survey_id
        HAVING COUNT(*) > 1
    )
    INSERT INTO #DQ_ValidationResults
    SELECT 
        @ExecutionId,
        'META-003',
        'Survey ID Uniqueness',
        'Survey Metadata',
        'HIGH',
        (SELECT SUM(duplicate_count) FROM DuplicateSurveyIds),
        @TotalRecords,
        CAST((SELECT SUM(duplicate_count) FROM DuplicateSurveyIds) * 100.0 / @TotalRecords AS DECIMAL(5,2)),
        'Each survey response should have a unique identifier',
        (SELECT STRING_AGG(CAST(survey_id AS VARCHAR(20)), ', ') FROM DuplicateSurveyIds),
        GETDATE(),
        CASE WHEN (SELECT COUNT(*) FROM DuplicateSurveyIds) = 0 THEN 'PASS' ELSE 'FAIL' END;

-- ============================================================================
-- SECTION 8: CROSS-CATEGORY VALIDATION CHECKS
-- ============================================================================

    PRINT 'Executing Cross-Category Validation Checks...';
    
    -- Rule CROSS-001: Geographic-Currency Consistency
    INSERT INTO #DQ_ValidationResults
    SELECT 
        @ExecutionId,
        'CROSS-001',
        'Geographic Currency Consistency',
        'Cross-Category',
        'MEDIUM',
        COUNT(*),
        @TotalRecords,
        CAST(COUNT(*) * 100.0 / @TotalRecords AS DECIMAL(5,2)),
        'Currency should be appropriate for the country',
        STRING_AGG(CAST(survey_id AS VARCHAR(20)), ', ') WITHIN GROUP (ORDER BY survey_id),
        GETDATE(),
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'WARNING' END
    FROM compensation_survey
    WHERE (country_code = 'US' AND currency NOT IN ('USD'))
       OR (country_code = 'GB' AND currency NOT IN ('GBP'))
       OR (country_code = 'CA' AND currency NOT IN ('CAD', 'USD'))
       OR (country_code IN ('DE', 'FR', 'IT', 'ES', 'NL') AND currency NOT IN ('EUR'));
    
    -- Rule CROSS-002: Industry-Salary Consistency
    WITH IndustrySalaryOutliers AS (
        SELECT 
            cs.survey_id,
            cs.industry,
            cs.base_salary,
            AVG(cs2.base_salary) as industry_avg_salary
        FROM compensation_survey cs
        INNER JOIN compensation_survey cs2 ON cs.industry = cs2.industry 
                                          AND cs2.base_salary IS NOT NULL
        WHERE cs.base_salary IS NOT NULL 
          AND cs.industry IS NOT NULL
        GROUP BY cs.survey_id, cs.industry, cs.base_salary
        HAVING cs.base_salary > 3 * AVG(cs2.base_salary) 
            OR cs.base_salary < 0.3 * AVG(cs2.base_salary)
    )
    INSERT INTO #DQ_ValidationResults
    SELECT 
        @ExecutionId,
        'CROSS-002',
        'Industry Salary Consistency',
        'Cross-Category',
        'LOW',
        COUNT(*),
        @TotalRecords,
        CAST(COUNT(*) * 100.0 / @TotalRecords AS DECIMAL(5,2)),
        'Salaries should be reasonable for the industry',
        STRING_AGG(CAST(survey_id AS VARCHAR(20)), ', ') WITHIN GROUP (ORDER BY survey_id),
        GETDATE(),
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'WARNING' END
    FROM IndustrySalaryOutliers;

-- ============================================================================
-- SECTION 9: ERROR HANDLING AND LOGGING
-- ============================================================================

    -- Calculate summary statistics
    SELECT @ErrorCount = COUNT(*) FROM #DQ_ValidationResults WHERE Severity = 'HIGH' AND Status = 'FAIL';
    SELECT @WarningCount = COUNT(*) FROM #DQ_ValidationResults WHERE Severity IN ('MEDIUM', 'LOW') AND Status IN ('FAIL', 'WARNING');
    
    PRINT '============================================================================';
    PRINT 'Data Quality Validation Completed Successfully';
    PRINT 'Execution Time: ' + CAST(DATEDIFF(SECOND, @StartTime, GETDATE()) AS VARCHAR(10)) + ' seconds';
    PRINT 'Critical Errors Found: ' + CAST(@ErrorCount AS VARCHAR(10));
    PRINT 'Warnings Found: ' + CAST(@WarningCount AS VARCHAR(10));
    PRINT '============================================================================';
    
    -- Commit transaction if no critical errors
    IF @ErrorCount = 0
    BEGIN
        COMMIT TRANSACTION DQ_Validation;
        PRINT 'Transaction committed successfully - No critical data quality issues found.';
    END
    ELSE
    BEGIN
        PRINT 'WARNING: Critical data quality issues detected. Review results before proceeding.';
        COMMIT TRANSACTION DQ_Validation;  -- Still commit to preserve results
    END

END TRY
BEGIN CATCH
    -- Error handling
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION DQ_Validation;
    
    DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
    DECLARE @ErrorState INT = ERROR_STATE();
    DECLARE @ErrorProcedure NVARCHAR(128) = ISNULL(ERROR_PROCEDURE(), 'DQ_Validation_Script');
    
    -- Log error
    INSERT INTO #DQ_ErrorLog
    VALUES (@ExecutionId, GETDATE(), @ErrorMessage, @ErrorSeverity, @ErrorState, @ErrorProcedure);
    
    PRINT 'ERROR: Data Quality Validation failed with error: ' + @ErrorMessage;
    
    -- Re-raise the error
    RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
END CATCH;

-- ============================================================================
-- SECTION 10: SUMMARY REPORTING
-- ============================================================================

-- Display comprehensive results summary
PRINT 'DATA QUALITY VALIDATION SUMMARY REPORT';
PRINT '============================================================================';

-- Overall summary by category
SELECT 
    Category,
    COUNT(*) as Total_Rules,
    SUM(CASE WHEN Status = 'PASS' THEN 1 ELSE 0 END) as Rules_Passed,
    SUM(CASE WHEN Status IN ('FAIL', 'WARNING') THEN 1 ELSE 0 END) as Rules_Failed,
    SUM(ViolationCount) as Total_Violations,
    CAST(AVG(ViolationPercentage) AS DECIMAL(5,2)) as Avg_Violation_Percentage
FROM #DQ_ValidationResults
GROUP BY Category
ORDER BY Total_Violations DESC;

-- Detailed results by severity
SELECT 
    Severity,
    COUNT(*) as Rule_Count,
    SUM(ViolationCount) as Total_Violations,
    CAST(AVG(ViolationPercentage) AS DECIMAL(5,2)) as Avg_Violation_Percentage
FROM #DQ_ValidationResults
GROUP BY Severity
ORDER BY 
    CASE Severity 
        WHEN 'HIGH' THEN 1 
        WHEN 'MEDIUM' THEN 2 
        WHEN 'LOW' THEN 3 
    END;

-- Top 10 most critical issues
SELECT TOP 10
    RuleId,
    RuleName,
    Category,
    Severity,
    ViolationCount,
    ViolationPercentage,
    Status
FROM #DQ_ValidationResults
WHERE Status IN ('FAIL', 'WARNING')
ORDER BY 
    CASE Severity WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 WHEN 'LOW' THEN 3 END,
    ViolationPercentage DESC;

-- Complete detailed results
SELECT 
    RuleId,
    RuleName,
    Category,
    Severity,
    ViolationCount,
    TotalRecords,
    ViolationPercentage,
    Description,
    Status,
    CheckTimestamp
FROM #DQ_ValidationResults
ORDER BY 
    CASE Severity WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 WHEN 'LOW' THEN 3 END,
    Category,
    RuleId;

-- Display any errors that occurred
IF EXISTS (SELECT 1 FROM #DQ_ErrorLog)
BEGIN
    PRINT 'ERRORS ENCOUNTERED DURING VALIDATION:';
    SELECT * FROM #DQ_ErrorLog ORDER BY ErrorTimestamp;
END

-- Clean up temporary tables
IF OBJECT_ID('tempdb..#DQ_ValidationResults') IS NOT NULL
    DROP TABLE #DQ_ValidationResults;
    
IF OBJECT_ID('tempdb..#DQ_ErrorLog') IS NOT NULL
    DROP TABLE #DQ_ErrorLog;

PRINT 'Data Quality Validation Script Execution Completed.';
PRINT '============================================================================';

/*
==============================================================================
DATA QUALITY RULES SUMMARY TABLE
==============================================================================

| Rule ID   | Rule Name                          | Category          | Purpose                                    | Status      |
|-----------|------------------------------------|--------------------|--------------------------------------------|--------------|
| GEO-001   | Country Code ISO Validation        | Geographic Data    | Validate ISO 3166-1 country codes        | Optimized   |
| GEO-002   | Country Name Consistency           | Geographic Data    | Ensure consistent country naming          | Optimized   |
| GEO-003   | Region Country Consistency         | Geographic Data    | Validate region-country relationships     | Optimized   |
| GEO-004   | City Data Quality                  | Geographic Data    | Check city name format and completeness   | Optimized   |
| IND-001   | Industry Code Validation           | Industry Data      | Validate NAICS/SIC industry codes        | Optimized   |
| IND-002   | Industry Hierarchy Consistency     | Industry Data      | Check industry-subindustry relationships  | Optimized   |
| IND-003   | Sector Classification Validation   | Industry Data      | Validate sector classifications           | Optimized   |
| ORG-001   | Company ID Uniqueness              | Organization Data  | Ensure unique company identifiers         | Optimized   |
| ORG-002   | Company Size Validation            | Organization Data  | Validate company size categories          | Optimized   |
| ORG-003   | Employee Count Range Validation    | Organization Data  | Check employee count reasonableness       | Optimized   |
| JOB-001   | Job Title Completeness and Format  | Job Data          | Validate job title presence and format    | Optimized   |
| JOB-002   | Job Level Consistency              | Job Data          | Check job level and experience alignment  | Optimized   |
| JOB-003   | Experience Range Validation        | Job Data          | Validate years of experience ranges       | Optimized   |
| COMP-001  | Base Salary Range and Currency     | Compensation Data  | Validate salary ranges and currency codes | Optimized   |
| COMP-002  | Salary Outlier Detection           | Compensation Data  | Identify statistical salary outliers      | New/Enhanced|
| COMP-003  | Variable Pay Ratio Validation      | Compensation Data  | Check variable pay reasonableness         | Optimized   |
| COMP-004  | Benefits Value Validation          | Compensation Data  | Validate benefits value ranges            | Optimized   |
| COMP-005  | Total Compensation Consistency     | Compensation Data  | Verify total compensation calculations    | Optimized   |
| META-001  | Survey Date Validation             | Survey Metadata    | Validate survey date ranges               | Optimized   |
| META-002  | Response Completeness Assessment   | Survey Metadata    | Check response completeness levels        | Optimized   |
| META-003  | Survey ID Uniqueness               | Survey Metadata    | Ensure unique survey identifiers          | Optimized   |
| CROSS-001 | Geographic Currency Consistency    | Cross-Category     | Check country-currency alignment          | New         |
| CROSS-002 | Industry Salary Consistency        | Cross-Category     | Validate industry-salary relationships    | New         |

==============================================================================
OPTIMIZATION FEATURES IMPLEMENTED:
==============================================================================

1. **Set-Based Operations**: All checks use set-based queries instead of cursors
2. **Consolidated Execution**: Single script handles all validation rules
3. **Parameterized Configuration**: Configurable thresholds and limits
4. **Comprehensive Error Handling**: Full transaction management and error logging
5. **Performance Optimization**: Efficient CTEs and window functions
6. **Idempotent Execution**: Safe to re-run multiple times
7. **Centralized Logging**: Unified results and error tracking
8. **Statistical Analysis**: Advanced outlier detection using percentiles
9. **Cross-Category Validation**: Relationships between data categories
10. **Production-Ready**: Comprehensive documentation and maintainability

==============================================================================
*/