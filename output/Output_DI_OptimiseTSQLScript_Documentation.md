# Optimized T-SQL Data Quality Validation Script Documentation

## Overview

This document provides comprehensive documentation for the consolidated and optimized T-SQL data quality validation script. The script has been designed for production environments with enhanced error handling, performance optimization, and detailed logging capabilities.

## Script Information

- **Script Name**: `Output_DI_OptimiseTSQLScript.sql`
- **Version**: 1.0
- **Purpose**: Comprehensive data quality validation across multiple tables
- **Target Environment**: SQL Server (2016 and later)

## Tables Validated

- `dbo.SurveyData` - Survey response data
- `dbo.JobData` - Job role definitions
- `dbo.EmployeeData` - Employee information
- `dbo.Countries` - Reference table for country codes

## Quality Checks Summary

| Check Name | Purpose | Status | Table | Column(s) |
|------------|---------|--------|-------|----------|
| Null_SurveyID_Check | Validates SurveyID is not null (Primary Key) | Optimized | SurveyData | SurveyID |
| Null_JobCode_Check | Validates JobCode is not null (Primary Key) | Optimized | JobData | JobCode |
| Null_EmployeeID_Check | Validates EmployeeID is not null (Primary Key) | Optimized | EmployeeData | EmployeeID |
| Unique_JobCode_Check | Ensures JobCode uniqueness within table | Optimized | JobData | JobCode |
| Unique_EmployeeID_Check | Ensures EmployeeID uniqueness within table | Optimized | EmployeeData | EmployeeID |
| Valid_CountryCode_Check | Validates referential integrity with Countries table | Optimized | SurveyData | CountryCode |
| Positive_BaseSalary_Check | Ensures BaseSalary is positive and greater than zero | Optimized | SurveyData | BaseSalary |
| Valid_JobFamily_Check | Validates JobFamily against allowed values list | Optimized | JobData | JobFamily |
| Valid_CurrencyCode_Format_Check | Validates CurrencyCode follows ISO 4217 format (3 chars) | Optimized | SurveyData | CurrencyCode |
| Valid_Email_Format_Check | Validates email format using pattern matching | Optimized | EmployeeData | Email |
| Non_Future_SurveyDate_Check | Ensures SurveyDate is not in the future | Optimized | SurveyData | SurveyDate |
| HireDate_vs_TerminationDate_Check | Validates HireDate is before TerminationDate | Optimized | EmployeeData | HireDate, TerminationDate |

## Key Optimizations Implemented

### 1. **Consolidation & Efficiency**
- **Merged Related Checks**: Combined similar validation patterns (null checks, uniqueness checks) into consolidated sections
- **Set-Based Operations**: All checks use efficient set-based queries instead of row-by-row processing
- **Single Execution Flow**: All checks execute in one script run, reducing overhead
- **Optimized Queries**: Used EXISTS instead of JOINs where appropriate for better performance

### 2. **Production Readiness Enhancements**
- **Comprehensive Error Handling**: TRY-CATCH blocks with detailed error logging
- **Transaction Safety**: All operations are read-only, ensuring no data corruption risk
- **Idempotent Design**: Script can be safely re-run multiple times
- **Configurable Parameters**: Enable/disable logging and detailed output via variables

### 3. **Logging & Monitoring**
- **Centralized Results**: All check results stored in temporary tables for analysis
- **Performance Metrics**: Execution time tracking for each check
- **Violation Details**: Optional detailed violation records for troubleshooting
- **Summary Reporting**: Comprehensive summary with pass/fail counts and timing

### 4. **Code Quality Improvements**
- **Standardized Naming**: Consistent naming conventions across all checks
- **Comprehensive Documentation**: Inline comments and section headers
- **Parameterization**: Configurable options for different execution modes
- **Clean Resource Management**: Proper cleanup of temporary objects

## Usage Instructions

### Basic Execution
```sql
-- Execute with default settings (logging enabled, detailed output enabled)
EXEC sqlcmd -i "Output_DI_OptimiseTSQLScript.sql"
```

### Configuration Options

Modify these variables at the top of the script to customize behavior:

```sql
DECLARE @EnableLogging BIT = 1;     -- Set to 0 to disable detailed logging
DECLARE @DetailedOutput BIT = 1;    -- Set to 0 to hide violation details
```

### Output Interpretation

#### Summary Section
- **Total Checks Executed**: Number of validation rules run
- **Checks Passed**: Number of rules with zero violations
- **Checks Failed**: Number of rules with violations found
- **Overall Status**: PASSED (no violations) or FAILED (violations found)
- **Total Execution Time**: Complete script execution time in milliseconds

#### Detailed Results
For each check, the following information is provided:
- **CheckID**: Unique identifier for the validation rule
- **CheckName**: Descriptive name of the validation
- **TableName**: Target table being validated
- **ColumnName**: Column(s) being validated
- **RuleDescription**: Business rule being enforced
- **ViolationCount**: Number of records violating the rule
- **CheckStatus**: PASSED, FAILED, or ERROR
- **ExecutionTime_MS**: Individual check execution time
- **CheckTimestamp**: When the check was executed

#### Violation Details (Optional)
When `@DetailedOutput = 1`, additional details are provided:
- **ViolationID**: Unique identifier for each violation
- **PrimaryKey**: Primary key of the violating record
- **ViolationDetails**: Specific details about the violation

## Prerequisites

### Database Objects
- All target tables (`SurveyData`, `JobData`, `EmployeeData`) must exist
- Reference table `Countries` must exist with `CountryCode` column
- Tables should have appropriate indexes on columns being validated

### Permissions
- `SELECT` permissions on all target tables
- `CREATE TABLE` permissions for temporary objects (typically granted to all users)

### SQL Server Version
- SQL Server 2016 or later (uses `DATETIME2` data type)
- Compatible with Azure SQL Database

## Performance Considerations

### Recommended Indexes
For optimal performance, ensure the following indexes exist:

```sql
-- SurveyData table
CREATE INDEX IX_SurveyData_CountryCode ON dbo.SurveyData(CountryCode);
CREATE INDEX IX_SurveyData_SurveyDate ON dbo.SurveyData(SurveyDate);

-- JobData table
CREATE UNIQUE INDEX IX_JobData_JobCode ON dbo.JobData(JobCode);
CREATE INDEX IX_JobData_JobFamily ON dbo.JobData(JobFamily);

-- EmployeeData table
CREATE UNIQUE INDEX IX_EmployeeData_EmployeeID ON dbo.EmployeeData(EmployeeID);
CREATE INDEX IX_EmployeeData_Email ON dbo.EmployeeData(Email);

-- Countries reference table
CREATE UNIQUE INDEX IX_Countries_CountryCode ON dbo.Countries(CountryCode);
```

### Execution Time Expectations
- Small datasets (< 10K records): < 1 second
- Medium datasets (10K - 100K records): 1-5 seconds
- Large datasets (100K - 1M records): 5-30 seconds
- Very large datasets (> 1M records): 30+ seconds

## Troubleshooting

### Common Issues

1. **Missing Reference Table**
   - Error: "Invalid object name 'dbo.Countries'"
   - Solution: Create the Countries reference table or modify the script to skip referential integrity checks

2. **Permission Denied**
   - Error: "SELECT permission denied on object..."
   - Solution: Grant SELECT permissions on all target tables

3. **Timeout Issues**
   - Error: "Timeout expired"
   - Solution: Add appropriate indexes or increase query timeout settings

### Performance Tuning

1. **Disable Detailed Output** for large datasets:
   ```sql
   DECLARE @DetailedOutput BIT = 0;
   ```

2. **Add Indexes** on frequently validated columns

3. **Run During Off-Peak Hours** for large datasets

4. **Consider Partitioning** for very large tables

## Maintenance

### Regular Tasks
- Review violation patterns monthly
- Update allowed values lists as business rules change
- Monitor execution times and optimize as needed
- Archive detailed violation logs periodically

### Script Updates
- Add new validation rules by following the existing pattern
- Update business rules (e.g., JobFamily allowed values) as needed
- Enhance error handling based on production experience

## Integration with CI/CD

The script can be integrated into automated deployment pipelines:

```yaml
# Example Azure DevOps pipeline step
- task: SqlAzureDacpacDeployment@1
  displayName: 'Run Data Quality Checks'
  inputs:
    azureSubscription: '$(azureSubscription)'
    ServerName: '$(sqlServerName)'
    DatabaseName: '$(databaseName)'
    SqlFile: 'Output_DI_OptimiseTSQLScript.sql'
    additionalArguments: '-v EnableLogging=1 DetailedOutput=0'
```

## Support and Contact

For questions or issues with this script:
- Review this documentation first
- Check the troubleshooting section
- Contact the Data Engineering team
- Submit issues through your organization's standard support channels

---

**Document Version**: 1.0  
**Last Updated**: 2024  
**Author**: Data Engineering Team