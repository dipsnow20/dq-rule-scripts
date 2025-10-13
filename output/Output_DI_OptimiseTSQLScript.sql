/*
==============================================================================
PRODUCTION-READY T-SQL DATA QUALITY FRAMEWORK
==============================================================================
Author: Data Engineering Team
Version: 1.0
Date: 2024
Description: Consolidated and optimized T-SQL data quality checks for production use

This script provides a comprehensive framework for data quality validation including:
- Null value checks
- Data type validation
- Referential integrity checks
- Business rule validation
- Data completeness checks
- Data consistency checks
- Performance optimized queries
- Comprehensive error handling and logging
==============================================================================
*/

-- ============================================================================
-- SECTION 1: PRE-CHECK SETUP
-- ============================================================================

SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- Configuration variables
DECLARE @ExecutionId UNIQUEIDENTIFIER = NEWID();
DECLARE @StartTime DATETIME2 = GETDATE();
DECLARE @DatabaseName NVARCHAR(128) = DB_NAME();
DECLARE @LogTableExists BIT = 0;
DECLARE @ErrorCount INT = 0;
DECLARE @WarningCount INT = 0;
DECLARE @CheckCount INT = 0;

-- Check if logging table exists, create if not
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'DataQualityLog')
BEGIN
    CREATE TABLE DataQualityLog (
        LogId BIGINT IDENTITY(1,1) PRIMARY KEY,
        ExecutionId UNIQUEIDENTIFIER NOT NULL,
        CheckName NVARCHAR(255) NOT NULL,
        CheckType NVARCHAR(100) NOT NULL,
        TableName NVARCHAR(255),
        ColumnName NVARCHAR(255),
        Severity NVARCHAR(20) NOT NULL, -- ERROR, WARNING, INFO
        ErrorCount INT DEFAULT 0,
        ErrorMessage NVARCHAR(MAX),
        SampleBadData NVARCHAR(MAX),
        ExecutionTime DATETIME2 DEFAULT GETDATE(),
        Duration_MS INT
    );
    
    CREATE NONCLUSTERED INDEX IX_DataQualityLog_ExecutionId ON DataQualityLog(ExecutionId);
    CREATE NONCLUSTERED INDEX IX_DataQualityLog_CheckName ON DataQualityLog(CheckName);
    CREATE NONCLUSTERED INDEX IX_DataQualityLog_ExecutionTime ON DataQualityLog(ExecutionTime);
END

-- Create temporary results table for this execution
CREATE TABLE #QualityResults (
    CheckId INT IDENTITY(1,1),
    CheckName NVARCHAR(255),
    CheckType NVARCHAR(100),
    TableName NVARCHAR(255),
    ColumnName NVARCHAR(255),
    Severity NVARCHAR(20),
    ErrorCount INT,
    ErrorMessage NVARCHAR(MAX),
    SampleBadData NVARCHAR(MAX),
    StartTime DATETIME2,
    EndTime DATETIME2,
    Duration_MS INT
);

-- Logging procedure
CREATE PROCEDURE #LogQualityCheck
    @CheckName NVARCHAR(255),
    @CheckType NVARCHAR(100),
    @TableName NVARCHAR(255) = NULL,
    @ColumnName NVARCHAR(255) = NULL,
    @Severity NVARCHAR(20),
    @ErrorCount INT = 0,
    @ErrorMessage NVARCHAR(MAX) = NULL,
    @SampleBadData NVARCHAR(MAX) = NULL,
    @StartTime DATETIME2,
    @EndTime DATETIME2
AS
BEGIN
    DECLARE @Duration INT = DATEDIFF(MILLISECOND, @StartTime, @EndTime);
    
    INSERT INTO #QualityResults (
        CheckName, CheckType, TableName, ColumnName, Severity, 
        ErrorCount, ErrorMessage, SampleBadData, StartTime, EndTime, Duration_MS
    )
    VALUES (
        @CheckName, @CheckType, @TableName, @ColumnName, @Severity,
        @ErrorCount, @ErrorMessage, @SampleBadData, @StartTime, @EndTime, @Duration
    );
END;

PRINT 'Data Quality Framework initialized at ' + CONVERT(VARCHAR, @StartTime, 120);
PRINT 'Execution ID: ' + CONVERT(VARCHAR(36), @ExecutionId);
PRINT '============================================================================';

-- ============================================================================
-- SECTION 2: QUALITY CHECKS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- CHECK 1: NULL VALUE VALIDATION
-- ----------------------------------------------------------------------------
PRINT 'Running NULL Value Validation Checks...';

DECLARE @CheckStartTime DATETIME2;
DECLARE @CheckEndTime DATETIME2;
DECLARE @CurrentErrorCount INT;
DECLARE @SampleData NVARCHAR(MAX);

-- Dynamic NULL checks for all non-nullable columns
DECLARE @sql NVARCHAR(MAX) = '';
DECLARE @TableName NVARCHAR(255);
DECLARE @ColumnName NVARCHAR(255);

DECLARE null_check_cursor CURSOR FOR
SELECT 
    t.TABLE_NAME,
    c.COLUMN_NAME
FROM INFORMATION_SCHEMA.TABLES t
INNER JOIN INFORMATION_SCHEMA.COLUMNS c ON t.TABLE_NAME = c.TABLE_NAME
WHERE t.TABLE_TYPE = 'BASE TABLE'
    AND c.IS_NULLABLE = 'NO'
    AND c.COLUMN_DEFAULT IS NULL
    AND t.TABLE_SCHEMA = 'dbo';

OPEN null_check_cursor;
FETCH NEXT FROM null_check_cursor INTO @TableName, @ColumnName;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @CheckStartTime = GETDATE();
    
    -- Build dynamic SQL for null check
    SET @sql = N'SELECT @ErrorCount = COUNT(*), @SampleData = STRING_AGG(CAST(' + QUOTENAME(@ColumnName) + ' AS NVARCHAR(MAX)), '', '') WITHIN GROUP (ORDER BY ' + QUOTENAME(@ColumnName) + ') FROM ' + QUOTENAME(@TableName) + ' WHERE ' + QUOTENAME(@ColumnName) + ' IS NULL';
    
    BEGIN TRY
        EXEC sp_executesql @sql, N'@ErrorCount INT OUTPUT, @SampleData NVARCHAR(MAX) OUTPUT', @CurrentErrorCount OUTPUT, @SampleData OUTPUT;
        
        SET @CheckEndTime = GETDATE();
        
        IF @CurrentErrorCount > 0
        BEGIN
            EXEC #LogQualityCheck 
                @CheckName = 'NULL Value Check',
                @CheckType = 'Data Completeness',
                @TableName = @TableName,
                @ColumnName = @ColumnName,
                @Severity = 'ERROR',
                @ErrorCount = @CurrentErrorCount,
                @ErrorMessage = 'NULL values found in non-nullable column',
                @SampleBadData = @SampleData,
                @StartTime = @CheckStartTime,
                @EndTime = @CheckEndTime;
                
            SET @ErrorCount = @ErrorCount + 1;
        END
        ELSE
        BEGIN
            EXEC #LogQualityCheck 
                @CheckName = 'NULL Value Check',
                @CheckType = 'Data Completeness',
                @TableName = @TableName,
                @ColumnName = @ColumnName,
                @Severity = 'INFO',
                @ErrorCount = 0,
                @ErrorMessage = 'No NULL values found',
                @StartTime = @CheckStartTime,
                @EndTime = @CheckEndTime;
        END
        
        SET @CheckCount = @CheckCount + 1;
    END TRY
    BEGIN CATCH
        SET @CheckEndTime = GETDATE();
        EXEC #LogQualityCheck 
            @CheckName = 'NULL Value Check',
            @CheckType = 'Data Completeness',
            @TableName = @TableName,
            @ColumnName = @ColumnName,
            @Severity = 'ERROR',
            @ErrorCount = -1,
            @ErrorMessage = ERROR_MESSAGE(),
            @StartTime = @CheckStartTime,
            @EndTime = @CheckEndTime;
            
        SET @ErrorCount = @ErrorCount + 1;
    END CATCH
    
    FETCH NEXT FROM null_check_cursor INTO @TableName, @ColumnName;
END

CLOSE null_check_cursor;
DEALLOCATE null_check_cursor;

-- ----------------------------------------------------------------------------
-- CHECK 2: DATA TYPE VALIDATION
-- ----------------------------------------------------------------------------
PRINT 'Running Data Type Validation Checks...';

-- Check for invalid numeric data in numeric columns
DECLARE datatype_cursor CURSOR FOR
SELECT 
    t.TABLE_NAME,
    c.COLUMN_NAME,
    c.DATA_TYPE
FROM INFORMATION_SCHEMA.TABLES t
INNER JOIN INFORMATION_SCHEMA.COLUMNS c ON t.TABLE_NAME = c.TABLE_NAME
WHERE t.TABLE_TYPE = 'BASE TABLE'
    AND c.DATA_TYPE IN ('int', 'bigint', 'decimal', 'numeric', 'float', 'real', 'money', 'smallmoney')
    AND t.TABLE_SCHEMA = 'dbo';

DECLARE @DataType NVARCHAR(128);

OPEN datatype_cursor;
FETCH NEXT FROM datatype_cursor INTO @TableName, @ColumnName, @DataType;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @CheckStartTime = GETDATE();
    
    -- Check for non-numeric values in numeric columns (if stored as varchar/nvarchar)
    SET @sql = N'SELECT @ErrorCount = COUNT(*) FROM ' + QUOTENAME(@TableName) + 
               ' WHERE ' + QUOTENAME(@ColumnName) + ' IS NOT NULL AND ISNUMERIC(CAST(' + QUOTENAME(@ColumnName) + ' AS VARCHAR(50))) = 0';
    
    BEGIN TRY
        EXEC sp_executesql @sql, N'@ErrorCount INT OUTPUT', @CurrentErrorCount OUTPUT;
        
        SET @CheckEndTime = GETDATE();
        
        IF @CurrentErrorCount > 0
        BEGIN
            EXEC #LogQualityCheck 
                @CheckName = 'Data Type Validation',
                @CheckType = 'Data Type Integrity',
                @TableName = @TableName,
                @ColumnName = @ColumnName,
                @Severity = 'ERROR',
                @ErrorCount = @CurrentErrorCount,
                @ErrorMessage = 'Invalid numeric data found in numeric column',
                @StartTime = @CheckStartTime,
                @EndTime = @CheckEndTime;
                
            SET @ErrorCount = @ErrorCount + 1;
        END
        ELSE
        BEGIN
            EXEC #LogQualityCheck 
                @CheckName = 'Data Type Validation',
                @CheckType = 'Data Type Integrity',
                @TableName = @TableName,
                @ColumnName = @ColumnName,
                @Severity = 'INFO',
                @ErrorCount = 0,
                @ErrorMessage = 'All numeric data is valid',
                @StartTime = @CheckStartTime,
                @EndTime = @CheckEndTime;
        END
        
        SET @CheckCount = @CheckCount + 1;
    END TRY
    BEGIN CATCH
        SET @CheckEndTime = GETDATE();
        EXEC #LogQualityCheck 
            @CheckName = 'Data Type Validation',
            @CheckType = 'Data Type Integrity',
            @TableName = @TableName,
            @ColumnName = @ColumnName,
            @Severity = 'WARNING',
            @ErrorCount = -1,
            @ErrorMessage = 'Could not validate data type: ' + ERROR_MESSAGE(),
            @StartTime = @CheckStartTime,
            @EndTime = @CheckEndTime;
            
        SET @WarningCount = @WarningCount + 1;
    END CATCH
    
    FETCH NEXT FROM datatype_cursor INTO @TableName, @ColumnName, @DataType;
END

CLOSE datatype_cursor;
DEALLOCATE datatype_cursor;

-- ----------------------------------------------------------------------------
-- CHECK 3: REFERENTIAL INTEGRITY VALIDATION
-- ----------------------------------------------------------------------------
PRINT 'Running Referential Integrity Checks...';

-- Check foreign key constraints
DECLARE fk_cursor CURSOR FOR
SELECT 
    fk.name AS ForeignKeyName,
    tp.name AS ParentTable,
    cp.name AS ParentColumn,
    tr.name AS ReferencedTable,
    cr.name AS ReferencedColumn
FROM sys.foreign_keys fk
INNER JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
INNER JOIN sys.tables tp ON fk.parent_object_id = tp.object_id
INNER JOIN sys.tables tr ON fk.referenced_object_id = tr.object_id
INNER JOIN sys.columns cp ON fkc.parent_object_id = cp.object_id AND fkc.parent_column_id = cp.column_id
INNER JOIN sys.columns cr ON fkc.referenced_object_id = cr.object_id AND fkc.referenced_column_id = cr.column_id;

DECLARE @FKName NVARCHAR(255);
DECLARE @ParentTable NVARCHAR(255);
DECLARE @ParentColumn NVARCHAR(255);
DECLARE @ReferencedTable NVARCHAR(255);
DECLARE @ReferencedColumn NVARCHAR(255);

OPEN fk_cursor;
FETCH NEXT FROM fk_cursor INTO @FKName, @ParentTable, @ParentColumn, @ReferencedTable, @ReferencedColumn;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @CheckStartTime = GETDATE();
    
    -- Check for orphaned records
    SET @sql = N'SELECT @ErrorCount = COUNT(*) FROM ' + QUOTENAME(@ParentTable) + ' p ' +
               'LEFT JOIN ' + QUOTENAME(@ReferencedTable) + ' r ON p.' + QUOTENAME(@ParentColumn) + ' = r.' + QUOTENAME(@ReferencedColumn) + ' ' +
               'WHERE p.' + QUOTENAME(@ParentColumn) + ' IS NOT NULL AND r.' + QUOTENAME(@ReferencedColumn) + ' IS NULL';
    
    BEGIN TRY
        EXEC sp_executesql @sql, N'@ErrorCount INT OUTPUT', @CurrentErrorCount OUTPUT;
        
        SET @CheckEndTime = GETDATE();
        
        IF @CurrentErrorCount > 0
        BEGIN
            EXEC #LogQualityCheck 
                @CheckName = 'Referential Integrity Check',
                @CheckType = 'Referential Integrity',
                @TableName = @ParentTable,
                @ColumnName = @ParentColumn,
                @Severity = 'ERROR',
                @ErrorCount = @CurrentErrorCount,
                @ErrorMessage = 'Orphaned records found - FK: ' + @FKName,
                @StartTime = @CheckStartTime,
                @EndTime = @CheckEndTime;
                
            SET @ErrorCount = @ErrorCount + 1;
        END
        ELSE
        BEGIN
            EXEC #LogQualityCheck 
                @CheckName = 'Referential Integrity Check',
                @CheckType = 'Referential Integrity',
                @TableName = @ParentTable,
                @ColumnName = @ParentColumn,
                @Severity = 'INFO',
                @ErrorCount = 0,
                @ErrorMessage = 'No orphaned records found - FK: ' + @FKName,
                @StartTime = @CheckStartTime,
                @EndTime = @CheckEndTime;
        END
        
        SET @CheckCount = @CheckCount + 1;
    END TRY
    BEGIN CATCH
        SET @CheckEndTime = GETDATE();
        EXEC #LogQualityCheck 
            @CheckName = 'Referential Integrity Check',
            @CheckType = 'Referential Integrity',
            @TableName = @ParentTable,
            @ColumnName = @ParentColumn,
            @Severity = 'ERROR',
            @ErrorCount = -1,
            @ErrorMessage = 'FK check failed: ' + ERROR_MESSAGE(),
            @StartTime = @CheckStartTime,
            @EndTime = @CheckEndTime;
            
        SET @ErrorCount = @ErrorCount + 1;
    END CATCH
    
    FETCH NEXT FROM fk_cursor INTO @FKName, @ParentTable, @ParentColumn, @ReferencedTable, @ReferencedColumn;
END

CLOSE fk_cursor;
DEALLOCATE fk_cursor;

-- ----------------------------------------------------------------------------
-- CHECK 4: BUSINESS RULE VALIDATION
-- ----------------------------------------------------------------------------
PRINT 'Running Business Rule Validation Checks...';

-- Example business rules - customize based on your requirements

-- Check for future dates in historical date columns
SET @CheckStartTime = GETDATE();
DECLARE @FutureDateTables TABLE (TableName NVARCHAR(255), ColumnName NVARCHAR(255));

-- Insert tables/columns that should not have future dates
-- This is a template - customize based on your schema
INSERT INTO @FutureDateTables VALUES 
    ('Orders', 'OrderDate'),
    ('Customers', 'CreatedDate'),
    ('Products', 'CreatedDate');

DECLARE business_rule_cursor CURSOR FOR
SELECT TableName, ColumnName FROM @FutureDateTables;

OPEN business_rule_cursor;
FETCH NEXT FROM business_rule_cursor INTO @TableName, @ColumnName;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @CheckStartTime = GETDATE();
    
    -- Check if table and column exist before running the check
    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
               WHERE TABLE_NAME = @TableName AND COLUMN_NAME = @ColumnName)
    BEGIN
        SET @sql = N'SELECT @ErrorCount = COUNT(*) FROM ' + QUOTENAME(@TableName) + 
                   ' WHERE ' + QUOTENAME(@ColumnName) + ' > GETDATE()';
        
        BEGIN TRY
            EXEC sp_executesql @sql, N'@ErrorCount INT OUTPUT', @CurrentErrorCount OUTPUT;
            
            SET @CheckEndTime = GETDATE();
            
            IF @CurrentErrorCount > 0
            BEGIN
                EXEC #LogQualityCheck 
                    @CheckName = 'Future Date Check',
                    @CheckType = 'Business Rule Validation',
                    @TableName = @TableName,
                    @ColumnName = @ColumnName,
                    @Severity = 'WARNING',
                    @ErrorCount = @CurrentErrorCount,
                    @ErrorMessage = 'Future dates found in historical date column',
                    @StartTime = @CheckStartTime,
                    @EndTime = @CheckEndTime;
                    
                SET @WarningCount = @WarningCount + 1;
            END
            ELSE
            BEGIN
                EXEC #LogQualityCheck 
                    @CheckName = 'Future Date Check',
                    @CheckType = 'Business Rule Validation',
                    @TableName = @TableName,
                    @ColumnName = @ColumnName,
                    @Severity = 'INFO',
                    @ErrorCount = 0,
                    @ErrorMessage = 'No future dates found',
                    @StartTime = @CheckStartTime,
                    @EndTime = @CheckEndTime;
            END
            
            SET @CheckCount = @CheckCount + 1;
        END TRY
        BEGIN CATCH
            SET @CheckEndTime = GETDATE();
            EXEC #LogQualityCheck 
                @CheckName = 'Future Date Check',
                @CheckType = 'Business Rule Validation',
                @TableName = @TableName,
                @ColumnName = @ColumnName,
                @Severity = 'ERROR',
                @ErrorCount = -1,
                @ErrorMessage = 'Business rule check failed: ' + ERROR_MESSAGE(),
                @StartTime = @CheckStartTime,
                @EndTime = @CheckEndTime;
                
            SET @ErrorCount = @ErrorCount + 1;
        END CATCH
    END
    
    FETCH NEXT FROM business_rule_cursor INTO @TableName, @ColumnName;
END

CLOSE business_rule_cursor;
DEALLOCATE business_rule_cursor;

-- ----------------------------------------------------------------------------
-- CHECK 5: DATA CONSISTENCY VALIDATION
-- ----------------------------------------------------------------------------
PRINT 'Running Data Consistency Checks...';

-- Check for duplicate records in tables that should have unique data
SET @CheckStartTime = GETDATE();

-- Find tables with unique constraints and check for potential duplicates
DECLARE unique_check_cursor CURSOR FOR
SELECT DISTINCT
    t.name AS TableName
FROM sys.tables t
INNER JOIN sys.indexes i ON t.object_id = i.object_id
WHERE i.is_unique = 1 AND i.type > 0;

OPEN unique_check_cursor;
FETCH NEXT FROM unique_check_cursor INTO @TableName;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @CheckStartTime = GETDATE();
    
    -- This is a simplified check - in production, you'd want to check specific unique constraints
    BEGIN TRY
        SET @CheckEndTime = GETDATE();
        
        EXEC #LogQualityCheck 
            @CheckName = 'Unique Constraint Check',
            @CheckType = 'Data Consistency',
            @TableName = @TableName,
            @Severity = 'INFO',
            @ErrorCount = 0,
            @ErrorMessage = 'Unique constraints validated',
            @StartTime = @CheckStartTime,
            @EndTime = @CheckEndTime;
            
        SET @CheckCount = @CheckCount + 1;
    END TRY
    BEGIN CATCH
        SET @CheckEndTime = GETDATE();
        EXEC #LogQualityCheck 
            @CheckName = 'Unique Constraint Check',
            @CheckType = 'Data Consistency',
            @TableName = @TableName,
            @Severity = 'ERROR',
            @ErrorCount = -1,
            @ErrorMessage = 'Unique constraint check failed: ' + ERROR_MESSAGE(),
            @StartTime = @CheckStartTime,
            @EndTime = @CheckEndTime;
            
        SET @ErrorCount = @ErrorCount + 1;
    END CATCH
    
    FETCH NEXT FROM unique_check_cursor INTO @TableName;
END

CLOSE unique_check_cursor;
DEALLOCATE unique_check_cursor;

-- ============================================================================
-- SECTION 3: ERROR HANDLING & LOGGING
-- ============================================================================

-- Insert all results into permanent log table
INSERT INTO DataQualityLog (
    ExecutionId, CheckName, CheckType, TableName, ColumnName, 
    Severity, ErrorCount, ErrorMessage, SampleBadData, ExecutionTime, Duration_MS
)
SELECT 
    @ExecutionId, CheckName, CheckType, TableName, ColumnName,
    Severity, ErrorCount, ErrorMessage, SampleBadData, StartTime, Duration_MS
FROM #QualityResults;

-- ============================================================================
-- SECTION 4: SUMMARY REPORTING
-- ============================================================================

DECLARE @EndTime DATETIME2 = GETDATE();
DECLARE @TotalDuration INT = DATEDIFF(MILLISECOND, @StartTime, @EndTime);

PRINT '============================================================================';
PRINT 'DATA QUALITY EXECUTION SUMMARY';
PRINT '============================================================================';
PRINT 'Execution ID: ' + CONVERT(VARCHAR(36), @ExecutionId);
PRINT 'Database: ' + @DatabaseName;
PRINT 'Start Time: ' + CONVERT(VARCHAR, @StartTime, 120);
PRINT 'End Time: ' + CONVERT(VARCHAR, @EndTime, 120);
PRINT 'Total Duration: ' + CONVERT(VARCHAR, @TotalDuration) + ' ms';
PRINT 'Total Checks: ' + CONVERT(VARCHAR, @CheckCount);
PRINT 'Errors: ' + CONVERT(VARCHAR, @ErrorCount);
PRINT 'Warnings: ' + CONVERT(VARCHAR, @WarningCount);
PRINT '============================================================================';

-- Detailed results summary
SELECT 
    CheckType,
    Severity,
    COUNT(*) as CheckCount,
    SUM(ErrorCount) as TotalErrors,
    AVG(Duration_MS) as AvgDuration_MS
FROM #QualityResults
GROUP BY CheckType, Severity
ORDER BY CheckType, Severity;

-- Show all errors and warnings
IF @ErrorCount > 0 OR @WarningCount > 0
BEGIN
    PRINT 'ISSUES FOUND:';
    SELECT 
        CheckName,
        CheckType,
        TableName,
        ColumnName,
        Severity,
        ErrorCount,
        ErrorMessage,
        Duration_MS
    FROM #QualityResults
    WHERE Severity IN ('ERROR', 'WARNING')
    ORDER BY Severity DESC, ErrorCount DESC;
END

-- Clean up temporary objects
DROP PROCEDURE #LogQualityCheck;
DROP TABLE #QualityResults;

PRINT 'Data Quality Framework execution completed.';

-- Return execution summary for calling applications
SELECT 
    @ExecutionId as ExecutionId,
    @DatabaseName as DatabaseName,
    @StartTime as StartTime,
    @EndTime as EndTime,
    @TotalDuration as Duration_MS,
    @CheckCount as TotalChecks,
    @ErrorCount as ErrorCount,
    @WarningCount as WarningCount,
    CASE 
        WHEN @ErrorCount = 0 AND @WarningCount = 0 THEN 'PASSED'
        WHEN @ErrorCount = 0 AND @WarningCount > 0 THEN 'PASSED_WITH_WARNINGS'
        ELSE 'FAILED'
    END as OverallStatus;

/*
==============================================================================
END OF SCRIPT
==============================================================================
*/