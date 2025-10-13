# Production-Ready T-SQL Data Quality Framework Documentation

## Overview

This document provides comprehensive documentation for the optimized and consolidated T-SQL Data Quality Framework. The framework has been designed to be production-ready, efficient, and maintainable.

## Summary of Quality Checks

| Check Name | Purpose | Status |
|------------|---------|--------|
| NULL Value Validation | Validates that non-nullable columns do not contain NULL values | Optimized |
| Data Type Validation | Ensures data in numeric columns is properly formatted and valid | Optimized |
| Referential Integrity Check | Validates foreign key relationships and identifies orphaned records | Optimized |
| Future Date Check | Business rule validation to prevent future dates in historical columns | New |
| Unique Constraint Check | Validates data consistency and uniqueness constraints | Optimized |
| Comprehensive Logging | Centralized logging mechanism for all quality checks | New |
| Error Handling Framework | Robust error handling with transaction safety | New |
| Performance Optimization | Set-based operations and efficient query patterns | Optimized |
| Execution Summary Reporting | Detailed reporting of check results and performance metrics | New |

## Key Features

### 1. Production-Ready Design
- **Idempotent Operations**: All scripts can be safely re-run without side effects
- **Transaction Safety**: Proper error handling prevents partial updates
- **Comprehensive Logging**: All operations are logged with detailed metadata
- **Performance Optimized**: Uses set-based operations instead of cursors where possible

### 2. Modular Architecture
- **Pre-Check Setup**: Initializes logging tables and configuration
- **Quality Checks**: Organized by check type with consistent patterns
- **Error Handling**: Centralized error capture and reporting
- **Summary Reporting**: Comprehensive execution summary and results

### 3. Comprehensive Coverage
- **Data Completeness**: NULL value validation
- **Data Type Integrity**: Validates data types and formats
- **Referential Integrity**: Foreign key relationship validation
- **Business Rule Validation**: Customizable business logic checks
- **Data Consistency**: Uniqueness and constraint validation

## Usage Instructions

### Prerequisites
- SQL Server 2016 or later (uses STRING_AGG function)
- Appropriate database permissions (CREATE TABLE, SELECT, INSERT)
- Database context set to target database

### Execution Steps

1. **Review and Customize**:
   ```sql
   -- Customize business rule tables in the script
   INSERT INTO @FutureDateTables VALUES 
       ('YourTable', 'YourDateColumn');
   ```

2. **Execute the Script**:
   ```sql
   -- Run the complete framework
   EXEC [Path_to_Script]/Output_DI_OptimiseTSQLScript.sql
   ```

3. **Review Results**:
   ```sql
   -- Check execution results
   SELECT * FROM DataQualityLog 
   WHERE ExecutionId = 'YourExecutionId'
   ORDER BY ExecutionTime DESC;
   ```

### Configuration Options

#### Custom Business Rules
To add custom business rules, modify the business rule validation section:

```sql
-- Add your custom tables and columns
INSERT INTO @FutureDateTables VALUES 
    ('Orders', 'OrderDate'),
    ('Invoices', 'InvoiceDate'),
    ('YourCustomTable', 'YourDateColumn');
```

#### Logging Retention
To manage log retention, add a cleanup job:

```sql
-- Clean up logs older than 30 days
DELETE FROM DataQualityLog 
WHERE ExecutionTime < DATEADD(DAY, -30, GETDATE());
```

## Output Interpretation

### Execution Summary
The script returns a summary with the following fields:
- **ExecutionId**: Unique identifier for the execution
- **OverallStatus**: PASSED, PASSED_WITH_WARNINGS, or FAILED
- **TotalChecks**: Number of checks executed
- **ErrorCount**: Number of checks that found errors
- **WarningCount**: Number of checks that found warnings

### Severity Levels
- **ERROR**: Critical issues that must be addressed
- **WARNING**: Issues that should be reviewed but may not be critical
- **INFO**: Informational messages indicating successful checks

### Log Table Schema
```sql
CREATE TABLE DataQualityLog (
    LogId BIGINT IDENTITY(1,1) PRIMARY KEY,
    ExecutionId UNIQUEIDENTIFIER NOT NULL,
    CheckName NVARCHAR(255) NOT NULL,
    CheckType NVARCHAR(100) NOT NULL,
    TableName NVARCHAR(255),
    ColumnName NVARCHAR(255),
    Severity NVARCHAR(20) NOT NULL,
    ErrorCount INT DEFAULT 0,
    ErrorMessage NVARCHAR(MAX),
    SampleBadData NVARCHAR(MAX),
    ExecutionTime DATETIME2 DEFAULT GETDATE(),
    Duration_MS INT
);
```

## Performance Considerations

### Optimization Techniques Used
1. **Set-Based Operations**: Eliminates row-by-row processing
2. **Dynamic SQL**: Allows for flexible, reusable checks
3. **Indexed Logging**: Efficient querying of historical results
4. **Parameterized Queries**: Prevents SQL injection and improves performance

### Monitoring Recommendations
- Monitor execution duration trends
- Set up alerts for ERROR severity issues
- Review WARNING items regularly
- Archive old log data based on retention policies

## Maintenance and Extension

### Adding New Checks
1. Follow the established pattern for error handling
2. Use the `#LogQualityCheck` procedure for consistent logging
3. Include appropriate BEGIN TRY/END TRY blocks
4. Test thoroughly before production deployment

### Customization Guidelines
- Modify business rule sections for organization-specific requirements
- Adjust severity levels based on business impact
- Add custom check types as needed
- Maintain consistent naming conventions

## Troubleshooting

### Common Issues
1. **Permission Errors**: Ensure proper database permissions
2. **Missing Tables**: Script handles missing tables gracefully
3. **Performance Issues**: Consider running during off-peak hours for large databases
4. **Log Table Growth**: Implement regular cleanup procedures

### Support Information
- Review execution logs for detailed error information
- Check SQL Server error logs for system-level issues
- Validate database schema changes that might affect checks

## Version History

| Version | Date | Changes |
|---------|------|----------|
| 1.0 | 2024 | Initial production-ready framework |

---

*This framework provides a solid foundation for data quality monitoring in production environments. Regular review and customization based on specific business requirements will ensure optimal effectiveness.*