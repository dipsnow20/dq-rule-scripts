/*
==============================================================================
PRODUCTION-READY DATA QUALITY VALIDATION SCRIPT
==============================================================================
Script Name: Consolidated_Data_Quality_Checks.sql
Purpose: Comprehensive data quality validation for SurveyData, JobData, and EmployeeData tables
Author: Data Engineering Team
Created: 2024
Version: 1.0

Description:
This script performs comprehensive data quality checks across multiple tables
with optimized performance, error handling, and detailed logging capabilities.
All checks are consolidated into a single execution for efficiency.

Tables Validated:
- dbo.SurveyData
- dbo.JobData  
- dbo.EmployeeData
- dbo.Countries (reference table)

Usage:
EXEC sp_DataQualityValidation @EnableLogging = 1, @DetailedOutput = 1

Prerequisites:
- All target tables must exist
- User must have SELECT permissions on all tables
- Countries reference table must exist for referential integrity checks
==============================================================================
*/

-- ============================================================================
-- SECTION 1: PRE-CHECK SETUP AND CONFIGURATION
-- ============================================================================

SET NOCOUNT ON;
SET ANSI_WARNINGS OFF;

-- Global variables for configuration
DECLARE @StartTime DATETIME2 = GETDATE();
DECLARE @ErrorCount INT = 0;
DECLARE @TotalChecks INT = 12;
DECLARE @ChecksPassed INT = 0;
DECLARE @EnableLogging BIT = 1; -- Set to 1 to enable detailed logging
DECLARE @DetailedOutput BIT = 1; -- Set to 1 to show detailed violation records

-- Create temporary table for consolidated results
IF OBJECT_ID('tempdb..#DataQualityResults') IS NOT NULL
    DROP TABLE #DataQualityResults;

CREATE TABLE #DataQualityResults (
    CheckID INT IDENTITY(1,1) PRIMARY KEY,
    CheckName NVARCHAR(100) NOT NULL,
    TableName NVARCHAR(50) NOT NULL,
    ColumnName NVARCHAR(50) NOT NULL,
    RuleDescription NVARCHAR(500) NOT NULL,
    ViolationCount INT NOT NULL,
    CheckStatus NVARCHAR(20) NOT NULL,
    ExecutionTime_MS INT NOT NULL,
    CheckTimestamp DATETIME2 DEFAULT GETDATE()
);

-- Create temporary table for violation details (if detailed output is enabled)
IF OBJECT_ID('tempdb..#ViolationDetails') IS NOT NULL
    DROP TABLE #ViolationDetails;

CREATE TABLE #ViolationDetails (
    ViolationID INT IDENTITY(1,1) PRIMARY KEY,
    CheckName NVARCHAR(100) NOT NULL,
    TableName NVARCHAR(50) NOT NULL,
    PrimaryKey NVARCHAR(50),
    ViolationDetails NVARCHAR(MAX),
    RecordTimestamp DATETIME2 DEFAULT GETDATE()
);

PRINT '===============================================';
PRINT 'DATA QUALITY VALIDATION STARTED';
PRINT 'Start Time: ' + CONVERT(NVARCHAR(30), @StartTime, 121);
PRINT '===============================================';

-- ============================================================================
-- SECTION 2: CONSOLIDATED DATA QUALITY CHECKS
-- ============================================================================

BEGIN TRY

    -- ========================================================================
    -- CHECK 1: NULL PRIMARY KEY VALIDATIONS (CONSOLIDATED)
    -- ========================================================================
    
    DECLARE @CheckStartTime DATETIME2;
    DECLARE @ViolationCount INT;
    
    -- Check 1A: Null SurveyID in SurveyData
    SET @CheckStartTime = GETDATE();
    
    SELECT @ViolationCount = COUNT(*)
    FROM dbo.SurveyData
    WHERE SurveyID IS NULL;
    
    INSERT INTO #DataQualityResults (CheckName, TableName, ColumnName, RuleDescription, ViolationCount, CheckStatus, ExecutionTime_MS)
    VALUES ('Null_SurveyID_Check', 'SurveyData', 'SurveyID', 'SurveyID should not be null (Primary Key)', 
            @ViolationCount, CASE WHEN @ViolationCount = 0 THEN 'PASSED' ELSE 'FAILED' END, 
            DATEDIFF(MILLISECOND, @CheckStartTime, GETDATE()));
    
    IF @DetailedOutput = 1 AND @ViolationCount > 0
    BEGIN
        INSERT INTO #ViolationDetails (CheckName, TableName, PrimaryKey, ViolationDetails)
        SELECT 'Null_SurveyID_Check', 'SurveyData', 'N/A', 
               'CountryCode: ' + ISNULL(CountryCode, 'NULL') + ', BaseSalary: ' + ISNULL(CAST(BaseSalary AS NVARCHAR(20)), 'NULL')
        FROM dbo.SurveyData
        WHERE SurveyID IS NULL;
    END
    
    -- Check 1B: Null JobCode in JobData
    SET @CheckStartTime = GETDATE();
    
    SELECT @ViolationCount = COUNT(*)
    FROM dbo.JobData
    WHERE JobCode IS NULL;
    
    INSERT INTO #DataQualityResults (CheckName, TableName, ColumnName, RuleDescription, ViolationCount, CheckStatus, ExecutionTime_MS)
    VALUES ('Null_JobCode_Check', 'JobData', 'JobCode', 'JobCode should not be null (Primary Key)', 
            @ViolationCount, CASE WHEN @ViolationCount = 0 THEN 'PASSED' ELSE 'FAILED' END, 
            DATEDIFF(MILLISECOND, @CheckStartTime, GETDATE()));
    
    IF @DetailedOutput = 1 AND @ViolationCount > 0
    BEGIN
        INSERT INTO #ViolationDetails (CheckName, TableName, PrimaryKey, ViolationDetails)
        SELECT 'Null_JobCode_Check', 'JobData', 'N/A', 
               'JobFamily: ' + ISNULL(JobFamily, 'NULL')
        FROM dbo.JobData
        WHERE JobCode IS NULL;
    END
    
    -- Check 1C: Null EmployeeID in EmployeeData
    SET @CheckStartTime = GETDATE();
    
    SELECT @ViolationCount = COUNT(*)
    FROM dbo.EmployeeData
    WHERE EmployeeID IS NULL;
    
    INSERT INTO #DataQualityResults (CheckName, TableName, ColumnName, RuleDescription, ViolationCount, CheckStatus, ExecutionTime_MS)
    VALUES ('Null_EmployeeID_Check', 'EmployeeData', 'EmployeeID', 'EmployeeID should not be null (Primary Key)', 
            @ViolationCount, CASE WHEN @ViolationCount = 0 THEN 'PASSED' ELSE 'FAILED' END, 
            DATEDIFF(MILLISECOND, @CheckStartTime, GETDATE()));
    
    IF @DetailedOutput = 1 AND @ViolationCount > 0
    BEGIN
        INSERT INTO #ViolationDetails (CheckName, TableName, PrimaryKey, ViolationDetails)
        SELECT 'Null_EmployeeID_Check', 'EmployeeData', 'N/A', 
               'Email: ' + ISNULL(Email, 'NULL') + ', HireDate: ' + ISNULL(CONVERT(NVARCHAR(20), HireDate, 121), 'NULL')
        FROM dbo.EmployeeData
        WHERE EmployeeID IS NULL;
    END

    -- ========================================================================
    -- CHECK 2: UNIQUENESS VALIDATIONS (CONSOLIDATED)
    -- ========================================================================
    
    -- Check 2A: Duplicate JobCode in JobData
    SET @CheckStartTime = GETDATE();
    
    SELECT @ViolationCount = COUNT(*)
    FROM (
        SELECT JobCode
        FROM dbo.JobData
        WHERE JobCode IS NOT NULL
        GROUP BY JobCode
        HAVING COUNT(*) > 1
    ) duplicates;
    
    INSERT INTO #DataQualityResults (CheckName, TableName, ColumnName, RuleDescription, ViolationCount, CheckStatus, ExecutionTime_MS)
    VALUES ('Unique_JobCode_Check', 'JobData', 'JobCode', 'JobCode must be unique within the table', 
            @ViolationCount, CASE WHEN @ViolationCount = 0 THEN 'PASSED' ELSE 'FAILED' END, 
            DATEDIFF(MILLISECOND, @CheckStartTime, GETDATE()));
    
    IF @DetailedOutput = 1 AND @ViolationCount > 0
    BEGIN
        INSERT INTO #ViolationDetails (CheckName, TableName, PrimaryKey, ViolationDetails)
        SELECT 'Unique_JobCode_Check', 'JobData', JobCode, 
               'Duplicate Count: ' + CAST(COUNT(*) AS NVARCHAR(10))
        FROM dbo.JobData
        WHERE JobCode IS NOT NULL
        GROUP BY JobCode
        HAVING COUNT(*) > 1;
    END
    
    -- Check 2B: Duplicate EmployeeID in EmployeeData
    SET @CheckStartTime = GETDATE();
    
    SELECT @ViolationCount = COUNT(*)
    FROM (
        SELECT EmployeeID
        FROM dbo.EmployeeData
        WHERE EmployeeID IS NOT NULL
        GROUP BY EmployeeID
        HAVING COUNT(*) > 1
    ) duplicates;
    
    INSERT INTO #DataQualityResults (CheckName, TableName, ColumnName, RuleDescription, ViolationCount, CheckStatus, ExecutionTime_MS)
    VALUES ('Unique_EmployeeID_Check', 'EmployeeData', 'EmployeeID', 'EmployeeID must be unique within the table', 
            @ViolationCount, CASE WHEN @ViolationCount = 0 THEN 'PASSED' ELSE 'FAILED' END, 
            DATEDIFF(MILLISECOND, @CheckStartTime, GETDATE()));
    
    IF @DetailedOutput = 1 AND @ViolationCount > 0
    BEGIN
        INSERT INTO #ViolationDetails (CheckName, TableName, PrimaryKey, ViolationDetails)
        SELECT 'Unique_EmployeeID_Check', 'EmployeeData', EmployeeID, 
               'Duplicate Count: ' + CAST(COUNT(*) AS NVARCHAR(10))
        FROM dbo.EmployeeData
        WHERE EmployeeID IS NOT NULL
        GROUP BY EmployeeID
        HAVING COUNT(*) > 1;
    END

    -- ========================================================================
    -- CHECK 3: REFERENTIAL INTEGRITY VALIDATIONS
    -- ========================================================================
    
    -- Check 3: Valid CountryCode in SurveyData
    SET @CheckStartTime = GETDATE();
    
    SELECT @ViolationCount = COUNT(*)
    FROM dbo.SurveyData sd
    WHERE NOT EXISTS (
        SELECT 1 
        FROM dbo.Countries c 
        WHERE c.CountryCode = sd.CountryCode
    );
    
    INSERT INTO #DataQualityResults (CheckName, TableName, ColumnName, RuleDescription, ViolationCount, CheckStatus, ExecutionTime_MS)
    VALUES ('Valid_CountryCode_Check', 'SurveyData', 'CountryCode', 'CountryCode must exist in Countries reference table', 
            @ViolationCount, CASE WHEN @ViolationCount = 0 THEN 'PASSED' ELSE 'FAILED' END, 
            DATEDIFF(MILLISECOND, @CheckStartTime, GETDATE()));
    
    IF @DetailedOutput = 1 AND @ViolationCount > 0
    BEGIN
        INSERT INTO #ViolationDetails (CheckName, TableName, PrimaryKey, ViolationDetails)
        SELECT 'Valid_CountryCode_Check', 'SurveyData', CAST(SurveyID AS NVARCHAR(20)), 
               'Invalid CountryCode: ' + ISNULL(CountryCode, 'NULL')
        FROM dbo.SurveyData sd
        WHERE NOT EXISTS (
            SELECT 1 
            FROM dbo.Countries c 
            WHERE c.CountryCode = sd.CountryCode
        );
    END

    -- ========================================================================
    -- CHECK 4: BUSINESS RULE VALIDATIONS
    -- ========================================================================
    
    -- Check 4A: Positive BaseSalary in SurveyData
    SET @CheckStartTime = GETDATE();
    
    SELECT @ViolationCount = COUNT(*)
    FROM dbo.SurveyData
    WHERE BaseSalary <= 0;
    
    INSERT INTO #DataQualityResults (CheckName, TableName, ColumnName, RuleDescription, ViolationCount, CheckStatus, ExecutionTime_MS)
    VALUES ('Positive_BaseSalary_Check', 'SurveyData', 'BaseSalary', 'BaseSalary must be a positive number greater than zero', 
            @ViolationCount, CASE WHEN @ViolationCount = 0 THEN 'PASSED' ELSE 'FAILED' END, 
            DATEDIFF(MILLISECOND, @CheckStartTime, GETDATE()));
    
    IF @DetailedOutput = 1 AND @ViolationCount > 0
    BEGIN
        INSERT INTO #ViolationDetails (CheckName, TableName, PrimaryKey, ViolationDetails)
        SELECT 'Positive_BaseSalary_Check', 'SurveyData', CAST(SurveyID AS NVARCHAR(20)), 
               'Invalid BaseSalary: ' + CAST(BaseSalary AS NVARCHAR(20))
        FROM dbo.SurveyData
        WHERE BaseSalary <= 0;
    END
    
    -- Check 4B: Valid JobFamily in JobData
    SET @CheckStartTime = GETDATE();
    
    SELECT @ViolationCount = COUNT(*)
    FROM dbo.JobData
    WHERE JobFamily NOT IN ('Engineering', 'Sales', 'Marketing', 'HR', 'Finance');
    
    INSERT INTO #DataQualityResults (CheckName, TableName, ColumnName, RuleDescription, ViolationCount, CheckStatus, ExecutionTime_MS)
    VALUES ('Valid_JobFamily_Check', 'JobData', 'JobFamily', 'JobFamily must be Engineering, Sales, Marketing, HR, or Finance', 
            @ViolationCount, CASE WHEN @ViolationCount = 0 THEN 'PASSED' ELSE 'FAILED' END, 
            DATEDIFF(MILLISECOND, @CheckStartTime, GETDATE()));
    
    IF @DetailedOutput = 1 AND @ViolationCount > 0
    BEGIN
        INSERT INTO #ViolationDetails (CheckName, TableName, PrimaryKey, ViolationDetails)
        SELECT 'Valid_JobFamily_Check', 'JobData', JobCode, 
               'Invalid JobFamily: ' + ISNULL(JobFamily, 'NULL')
        FROM dbo.JobData
        WHERE JobFamily NOT IN ('Engineering', 'Sales', 'Marketing', 'HR', 'Finance');
    END

    -- ========================================================================
    -- CHECK 5: FORMAT AND DATA TYPE VALIDATIONS
    -- ========================================================================
    
    -- Check 5A: Valid CurrencyCode Format in SurveyData
    SET @CheckStartTime = GETDATE();
    
    SELECT @ViolationCount = COUNT(*)
    FROM dbo.SurveyData
    WHERE LEN(CurrencyCode) <> 3 OR CurrencyCode IS NULL;
    
    INSERT INTO #DataQualityResults (CheckName, TableName, ColumnName, RuleDescription, ViolationCount, CheckStatus, ExecutionTime_MS)
    VALUES ('Valid_CurrencyCode_Format_Check', 'SurveyData', 'CurrencyCode', 'CurrencyCode must be exactly 3 characters (ISO 4217)', 
            @ViolationCount, CASE WHEN @ViolationCount = 0 THEN 'PASSED' ELSE 'FAILED' END, 
            DATEDIFF(MILLISECOND, @CheckStartTime, GETDATE()));
    
    IF @DetailedOutput = 1 AND @ViolationCount > 0
    BEGIN
        INSERT INTO #ViolationDetails (CheckName, TableName, PrimaryKey, ViolationDetails)
        SELECT 'Valid_CurrencyCode_Format_Check', 'SurveyData', CAST(SurveyID AS NVARCHAR(20)), 
               'Invalid CurrencyCode: ' + ISNULL(CurrencyCode, 'NULL') + ' (Length: ' + CAST(LEN(ISNULL(CurrencyCode, '')) AS NVARCHAR(5)) + ')'
        FROM dbo.SurveyData
        WHERE LEN(CurrencyCode) <> 3 OR CurrencyCode IS NULL;
    END
    
    -- Check 5B: Valid Email Format in EmployeeData
    SET @CheckStartTime = GETDATE();
    
    SELECT @ViolationCount = COUNT(*)
    FROM dbo.EmployeeData
    WHERE Email IS NOT NULL 
      AND (Email NOT LIKE '%_@__%.__%' OR PATINDEX('% %', Email) > 0);
    
    INSERT INTO #DataQualityResults (CheckName, TableName, ColumnName, RuleDescription, ViolationCount, CheckStatus, ExecutionTime_MS)
    VALUES ('Valid_Email_Format_Check', 'EmployeeData', 'Email', 'Email must follow standard format (user@domain.com)', 
            @ViolationCount, CASE WHEN @ViolationCount = 0 THEN 'PASSED' ELSE 'FAILED' END, 
            DATEDIFF(MILLISECOND, @CheckStartTime, GETDATE()));
    
    IF @DetailedOutput = 1 AND @ViolationCount > 0
    BEGIN
        INSERT INTO #ViolationDetails (CheckName, TableName, PrimaryKey, ViolationDetails)
        SELECT 'Valid_Email_Format_Check', 'EmployeeData', EmployeeID, 
               'Invalid Email: ' + ISNULL(Email, 'NULL')
        FROM dbo.EmployeeData
        WHERE Email IS NOT NULL 
          AND (Email NOT LIKE '%_@__%.__%' OR PATINDEX('% %', Email) > 0);
    END

    -- ========================================================================
    -- CHECK 6: DATE LOGIC VALIDATIONS
    -- ========================================================================
    
    -- Check 6A: Non-Future SurveyDate in SurveyData
    SET @CheckStartTime = GETDATE();
    
    SELECT @ViolationCount = COUNT(*)
    FROM dbo.SurveyData
    WHERE SurveyDate > GETDATE();
    
    INSERT INTO #DataQualityResults (CheckName, TableName, ColumnName, RuleDescription, ViolationCount, CheckStatus, ExecutionTime_MS)
    VALUES ('Non_Future_SurveyDate_Check', 'SurveyData', 'SurveyDate', 'SurveyDate cannot be in the future', 
            @ViolationCount, CASE WHEN @ViolationCount = 0 THEN 'PASSED' ELSE 'FAILED' END, 
            DATEDIFF(MILLISECOND, @CheckStartTime, GETDATE()));
    
    IF @DetailedOutput = 1 AND @ViolationCount > 0
    BEGIN
        INSERT INTO #ViolationDetails (CheckName, TableName, PrimaryKey, ViolationDetails)
        SELECT 'Non_Future_SurveyDate_Check', 'SurveyData', CAST(SurveyID AS NVARCHAR(20)), 
               'Future SurveyDate: ' + CONVERT(NVARCHAR(20), SurveyDate, 121)
        FROM dbo.SurveyData
        WHERE SurveyDate > GETDATE();
    END
    
    -- Check 6B: HireDate vs TerminationDate Logic in EmployeeData
    SET @CheckStartTime = GETDATE();
    
    SELECT @ViolationCount = COUNT(*)
    FROM dbo.EmployeeData
    WHERE TerminationDate IS NOT NULL 
      AND HireDate >= TerminationDate;
    
    INSERT INTO #DataQualityResults (CheckName, TableName, ColumnName, RuleDescription, ViolationCount, CheckStatus, ExecutionTime_MS)
    VALUES ('HireDate_vs_TerminationDate_Check', 'EmployeeData', 'HireDate,TerminationDate', 'HireDate must be before TerminationDate', 
            @ViolationCount, CASE WHEN @ViolationCount = 0 THEN 'PASSED' ELSE 'FAILED' END, 
            DATEDIFF(MILLISECOND, @CheckStartTime, GETDATE()));
    
    IF @DetailedOutput = 1 AND @ViolationCount > 0
    BEGIN
        INSERT INTO #ViolationDetails (CheckName, TableName, PrimaryKey, ViolationDetails)
        SELECT 'HireDate_vs_TerminationDate_Check', 'EmployeeData', EmployeeID, 
               'HireDate: ' + CONVERT(NVARCHAR(20), HireDate, 121) + ', TerminationDate: ' + CONVERT(NVARCHAR(20), TerminationDate, 121)
        FROM dbo.EmployeeData
        WHERE TerminationDate IS NOT NULL 
          AND HireDate >= TerminationDate;
    END

END TRY
BEGIN CATCH
    -- ========================================================================
    -- SECTION 3: ERROR HANDLING AND LOGGING
    -- ========================================================================
    
    DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
    DECLARE @ErrorState INT = ERROR_STATE();
    DECLARE @ErrorProcedure NVARCHAR(128) = ISNULL(ERROR_PROCEDURE(), 'Data Quality Script');
    DECLARE @ErrorLine INT = ERROR_LINE();
    
    -- Log the error
    INSERT INTO #DataQualityResults (CheckName, TableName, ColumnName, RuleDescription, ViolationCount, CheckStatus, ExecutionTime_MS)
    VALUES ('SYSTEM_ERROR', 'N/A', 'N/A', 
            'Error in ' + @ErrorProcedure + ' at line ' + CAST(@ErrorLine AS NVARCHAR(10)) + ': ' + @ErrorMessage,
            -1, 'ERROR', DATEDIFF(MILLISECOND, @StartTime, GETDATE()));
    
    PRINT 'ERROR OCCURRED:';
    PRINT 'Procedure: ' + @ErrorProcedure;
    PRINT 'Line: ' + CAST(@ErrorLine AS NVARCHAR(10));
    PRINT 'Message: ' + @ErrorMessage;
    
    -- Re-throw the error for calling applications
    RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
END CATCH

-- ============================================================================
-- SECTION 4: SUMMARY REPORTING AND RESULTS
-- ============================================================================

-- Calculate summary statistics
SELECT @ChecksPassed = COUNT(*) FROM #DataQualityResults WHERE CheckStatus = 'PASSED';
SELECT @ErrorCount = COUNT(*) FROM #DataQualityResults WHERE CheckStatus IN ('FAILED', 'ERROR');

DECLARE @EndTime DATETIME2 = GETDATE();
DECLARE @TotalExecutionTime INT = DATEDIFF(MILLISECOND, @StartTime, @EndTime);

-- Display summary header
PRINT '';
PRINT '===============================================';
PRINT 'DATA QUALITY VALIDATION SUMMARY';
PRINT '===============================================';
PRINT 'Total Checks Executed: ' + CAST(@TotalChecks AS NVARCHAR(10));
PRINT 'Checks Passed: ' + CAST(@ChecksPassed AS NVARCHAR(10));
PRINT 'Checks Failed: ' + CAST(@ErrorCount AS NVARCHAR(10));
PRINT 'Overall Status: ' + CASE WHEN @ErrorCount = 0 THEN 'PASSED' ELSE 'FAILED' END;
PRINT 'Total Execution Time: ' + CAST(@TotalExecutionTime AS NVARCHAR(10)) + ' ms';
PRINT 'End Time: ' + CONVERT(NVARCHAR(30), @EndTime, 121);
PRINT '===============================================';
PRINT '';

-- Display detailed results
PRINT 'DETAILED CHECK RESULTS:';
PRINT '=======================';

SELECT 
    CheckID,
    CheckName,
    TableName,
    ColumnName,
    RuleDescription,
    ViolationCount,
    CheckStatus,
    ExecutionTime_MS,
    CheckTimestamp
FROM #DataQualityResults
ORDER BY CheckID;

-- Display violation details if enabled and violations exist
IF @DetailedOutput = 1 AND EXISTS(SELECT 1 FROM #ViolationDetails)
BEGIN
    PRINT '';
    PRINT 'VIOLATION DETAILS:';
    PRINT '==================';
    
    SELECT 
        ViolationID,
        CheckName,
        TableName,
        PrimaryKey,
        ViolationDetails,
        RecordTimestamp
    FROM #ViolationDetails
    ORDER BY CheckName, ViolationID;
END

-- Performance metrics by table
PRINT '';
PRINT 'PERFORMANCE METRICS BY TABLE:';
PRINT '=============================';

SELECT 
    TableName,
    COUNT(*) as ChecksPerformed,
    SUM(ViolationCount) as TotalViolations,
    AVG(ExecutionTime_MS) as AvgExecutionTime_MS,
    MAX(ExecutionTime_MS) as MaxExecutionTime_MS
FROM #DataQualityResults
WHERE CheckStatus <> 'ERROR'
GROUP BY TableName
ORDER BY TableName;

-- Cleanup temporary tables
IF OBJECT_ID('tempdb..#DataQualityResults') IS NOT NULL
    DROP TABLE #DataQualityResults;

IF OBJECT_ID('tempdb..#ViolationDetails') IS NOT NULL
    DROP TABLE #ViolationDetails;

SET ANSI_WARNINGS ON;
SET NOCOUNT OFF;

PRINT '';
PRINT 'Data Quality Validation Complete.';

/*
==============================================================================
END OF SCRIPT
==============================================================================
*/