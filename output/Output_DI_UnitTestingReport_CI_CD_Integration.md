# T-SQL Unit Testing Framework - CI/CD Integration Guide

## Overview

This guide provides comprehensive instructions for integrating the T-SQL unit testing framework into your CI/CD pipeline. The framework supports multiple CI/CD platforms including Azure DevOps, GitHub Actions, Jenkins, and GitLab CI.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Azure DevOps Integration](#azure-devops-integration)
3. [GitHub Actions Integration](#github-actions-integration)
4. [Jenkins Integration](#jenkins-integration)
5. [GitLab CI Integration](#gitlab-ci-integration)
6. [PowerShell Automation Script](#powershell-automation-script)
7. [Command Line Execution](#command-line-execution)
8. [Test Result Publishing](#test-result-publishing)
9. [Notifications and Alerts](#notifications-and-alerts)
10. [Best Practices](#best-practices)
11. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Software Requirements
- SQL Server 2016 or later / Azure SQL Database
- PowerShell 5.1 or later
- sqlcmd utility (SQL Server Command Line Tools)
- CI/CD platform access (Azure DevOps, GitHub, Jenkins, or GitLab)

### Database Requirements
- Test database with appropriate schema
- Database user with necessary permissions:
  - CREATE TABLE
  - INSERT, UPDATE, DELETE
  - EXECUTE (for stored procedures)
  - CREATE PROCEDURE (for test harness)

### File Structure
```
project-root/
├── scripts/
│   ├── Output_DI_OptimiseTSQLScript.sql
│   └── Output_DI_UnitTestingReport_TestHarness.sql
├── tests/
│   └── Output_DI_UnitTestingReport_TestCases.csv
├── reports/
│   ├── Output_DI_UnitTestingReport_TestReport.md
│   └── Output_DI_UnitTestingReport_JUnit.xml
└── automation/
    └── Run-TSQLTests.ps1
```

---

## Azure DevOps Integration

### Pipeline YAML Configuration

```yaml
# azure-pipelines.yml
trigger:
  branches:
    include:
    - main
    - develop
  paths:
    include:
    - scripts/**
    - tests/**

pool:
  vmImage: 'windows-latest'

variables:
  sqlServer: '$(SQL_SERVER)'
  sqlDatabase: '$(SQL_DATABASE)'
  sqlUsername: '$(SQL_USERNAME)'
  sqlPassword: '$(SQL_PASSWORD)'

stages:
- stage: Test
  displayName: 'Run T-SQL Unit Tests'
  jobs:
  - job: UnitTests
    displayName: 'Execute Unit Tests'
    steps:
    
    - task: PowerShell@2
      displayName: 'Install SQL Server Module'
      inputs:
        targetType: 'inline'
        script: |
          Install-Module -Name SqlServer -Force -AllowClobber -Scope CurrentUser
    
    - task: PowerShell@2
      displayName: 'Run T-SQL Unit Tests'
      inputs:
        filePath: '$(System.DefaultWorkingDirectory)/automation/Run-TSQLTests.ps1'
        arguments: >
          -ServerInstance "$(sqlServer)"
          -Database "$(sqlDatabase)"
          -Username "$(sqlUsername)"
          -Password "$(sqlPassword)"
          -TestHarnessPath "$(System.DefaultWorkingDirectory)/scripts/Output_DI_UnitTestingReport_TestHarness.sql"
          -OutputPath "$(System.DefaultWorkingDirectory)/reports"
      continueOnError: false
    
    - task: PublishTestResults@2
      displayName: 'Publish Test Results'
      inputs:
        testResultsFormat: 'JUnit'
        testResultsFiles: '**/Output_DI_UnitTestingReport_JUnit.xml'
        searchFolder: '$(System.DefaultWorkingDirectory)/reports'
        mergeTestResults: true
        failTaskOnFailedTests: true
        testRunTitle: 'T-SQL Data Quality Unit Tests'
    
    - task: PublishBuildArtifacts@1
      displayName: 'Publish Test Reports'
      inputs:
        PathtoPublish: '$(System.DefaultWorkingDirectory)/reports'
        ArtifactName: 'test-reports'
        publishLocation: 'Container'
      condition: always()
    
    - task: PowerShell@2
      displayName: 'Send Test Notification'
      inputs:
        targetType: 'inline'
        script: |
          $testResults = Get-Content "$(System.DefaultWorkingDirectory)/reports/test-summary.json" | ConvertFrom-Json
          $message = "T-SQL Unit Tests Completed: $($testResults.PassedTests)/$($testResults.TotalTests) passed"
          Write-Host "##vso[task.setvariable variable=TestSummary]$message"
      condition: always()
```

### Variable Group Configuration

1. Navigate to **Pipelines** > **Library** > **Variable Groups**
2. Create a new variable group named `SQL-Test-Environment`
3. Add the following variables:
   - `SQL_SERVER`: Your SQL Server instance
   - `SQL_DATABASE`: Test database name
   - `SQL_USERNAME`: Database username
   - `SQL_PASSWORD`: Database password (mark as secret)

---

## GitHub Actions Integration

### Workflow Configuration

```yaml
# .github/workflows/tsql-unit-tests.yml
name: T-SQL Unit Tests

on:
  push:
    branches: [ main, develop ]
    paths:
      - 'scripts/**'
      - 'tests/**'
  pull_request:
    branches: [ main, develop ]
  schedule:
    - cron: '0 2 * * *'  # Run daily at 2 AM UTC

jobs:
  test:
    runs-on: windows-latest
    
    env:
      SQL_SERVER: ${{ secrets.SQL_SERVER }}
      SQL_DATABASE: ${{ secrets.SQL_DATABASE }}
      SQL_USERNAME: ${{ secrets.SQL_USERNAME }}
      SQL_PASSWORD: ${{ secrets.SQL_PASSWORD }}
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v3
    
    - name: Setup PowerShell modules
      shell: pwsh
      run: |
        Install-Module -Name SqlServer -Force -AllowClobber -Scope CurrentUser
    
    - name: Run T-SQL Unit Tests
      shell: pwsh
      run: |
        ./automation/Run-TSQLTests.ps1 `
          -ServerInstance "$env:SQL_SERVER" `
          -Database "$env:SQL_DATABASE" `
          -Username "$env:SQL_USERNAME" `
          -Password "$env:SQL_PASSWORD" `
          -TestHarnessPath "./scripts/Output_DI_UnitTestingReport_TestHarness.sql" `
          -OutputPath "./reports"
    
    - name: Publish Test Results
      uses: EnricoMi/publish-unit-test-result-action/composite@v2
      if: always()
      with:
        junit_files: 'reports/Output_DI_UnitTestingReport_JUnit.xml'
        check_name: 'T-SQL Unit Test Results'
    
    - name: Upload Test Reports
      uses: actions/upload-artifact@v3
      if: always()
      with:
        name: test-reports
        path: reports/
    
    - name: Comment PR with Test Results
      if: github.event_name == 'pull_request'
      uses: actions/github-script@v6
      with:
        script: |
          const fs = require('fs');
          const testReport = fs.readFileSync('reports/test-summary.md', 'utf8');
          github.rest.issues.createComment({
            issue_number: context.issue.number,
            owner: context.repo.owner,
            repo: context.repo.repo,
            body: testReport
          });
```

### GitHub Secrets Configuration

1. Navigate to **Settings** > **Secrets and variables** > **Actions**
2. Add the following repository secrets:
   - `SQL_SERVER`
   - `SQL_DATABASE`
   - `SQL_USERNAME`
   - `SQL_PASSWORD`

---

## Jenkins Integration

### Jenkinsfile Configuration

```groovy
// Jenkinsfile
pipeline {
    agent {
        label 'windows'
    }
    
    environment {
        SQL_SERVER = credentials('sql-server')
        SQL_DATABASE = credentials('sql-database')
        SQL_CREDENTIALS = credentials('sql-credentials')
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Setup') {
            steps {
                powershell '''
                    Install-Module -Name SqlServer -Force -AllowClobber -Scope CurrentUser
                '''
            }
        }
        
        stage('Run Unit Tests') {
            steps {
                powershell '''
                    ./automation/Run-TSQLTests.ps1 `
                        -ServerInstance "$env:SQL_SERVER" `
                        -Database "$env:SQL_DATABASE" `
                        -Username "$env:SQL_CREDENTIALS_USR" `
                        -Password "$env:SQL_CREDENTIALS_PSW" `
                        -TestHarnessPath "./scripts/Output_DI_UnitTestingReport_TestHarness.sql" `
                        -OutputPath "./reports"
                '''
            }
        }
        
        stage('Publish Results') {
            steps {
                junit 'reports/Output_DI_UnitTestingReport_JUnit.xml'
                archiveArtifacts artifacts: 'reports/**/*', allowEmptyArchive: false
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
        success {
            emailext (
                subject: "T-SQL Unit Tests Passed: ${env.JOB_NAME} - Build #${env.BUILD_NUMBER}",
                body: "All T-SQL unit tests passed successfully.",
                to: "${env.CHANGE_AUTHOR_EMAIL}"
            )
        }
        failure {
            emailext (
                subject: "T-SQL Unit Tests Failed: ${env.JOB_NAME} - Build #${env.BUILD_NUMBER}",
                body: "T-SQL unit tests failed. Please review the test results.",
                to: "${env.CHANGE_AUTHOR_EMAIL}"
            )
        }
    }
}
```

---

## GitLab CI Integration

### .gitlab-ci.yml Configuration

```yaml
# .gitlab-ci.yml
stages:
  - test
  - report

variables:
  SQL_SERVER: $SQL_SERVER
  SQL_DATABASE: $SQL_DATABASE
  SQL_USERNAME: $SQL_USERNAME
  SQL_PASSWORD: $SQL_PASSWORD

tsql_unit_tests:
  stage: test
  tags:
    - windows
  script:
    - powershell -Command "Install-Module -Name SqlServer -Force -AllowClobber -Scope CurrentUser"
    - powershell -File ./automation/Run-TSQLTests.ps1 -ServerInstance "$SQL_SERVER" -Database "$SQL_DATABASE" -Username "$SQL_USERNAME" -Password "$SQL_PASSWORD" -TestHarnessPath "./scripts/Output_DI_UnitTestingReport_TestHarness.sql" -OutputPath "./reports"
  artifacts:
    when: always
    paths:
      - reports/
    reports:
      junit: reports/Output_DI_UnitTestingReport_JUnit.xml
  only:
    - main
    - develop
    - merge_requests

publish_report:
  stage: report
  dependencies:
    - tsql_unit_tests
  script:
    - echo "Publishing test reports"
  artifacts:
    paths:
      - reports/
  only:
    - main
    - develop
```

---

## PowerShell Automation Script

### Run-TSQLTests.ps1

```powershell
<#
.SYNOPSIS
    Executes T-SQL unit tests and generates reports.

.DESCRIPTION
    This script automates the execution of T-SQL unit tests for data quality validation.
    It connects to SQL Server, runs the test harness, and generates test reports in
    multiple formats (Markdown, JUnit XML, JSON).

.PARAMETER ServerInstance
    SQL Server instance name or connection string.

.PARAMETER Database
    Target database name for testing.

.PARAMETER Username
    SQL Server authentication username (optional if using Windows auth).

.PARAMETER Password
    SQL Server authentication password (optional if using Windows auth).

.PARAMETER TestHarnessPath
    Path to the test harness SQL script.

.PARAMETER OutputPath
    Directory path for test reports output.

.PARAMETER UseWindowsAuth
    Switch to use Windows authentication instead of SQL authentication.

.EXAMPLE
    ./Run-TSQLTests.ps1 -ServerInstance "localhost" -Database "TestDB" -UseWindowsAuth -TestHarnessPath "./test-harness.sql" -OutputPath "./reports"

.EXAMPLE
    ./Run-TSQLTests.ps1 -ServerInstance "sqlserver.database.windows.net" -Database "TestDB" -Username "testuser" -Password "P@ssw0rd" -TestHarnessPath "./test-harness.sql" -OutputPath "./reports"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ServerInstance,
    
    [Parameter(Mandatory=$true)]
    [string]$Database,
    
    [Parameter(Mandatory=$false)]
    [string]$Username,
    
    [Parameter(Mandatory=$false)]
    [string]$Password,
    
    [Parameter(Mandatory=$true)]
    [string]$TestHarnessPath,
    
    [Parameter(Mandatory=$true)]
    [string]$OutputPath,
    
    [Parameter(Mandatory=$false)]
    [switch]$UseWindowsAuth
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Import required modules
Write-Host "Importing SqlServer module..." -ForegroundColor Cyan
Import-Module SqlServer -ErrorAction Stop

# Validate test harness file exists
if (-not (Test-Path $TestHarnessPath)) {
    Write-Error "Test harness file not found: $TestHarnessPath"
    exit 1
}

# Create output directory if it doesn't exist
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    Write-Host "Created output directory: $OutputPath" -ForegroundColor Green
}

# Build connection string
if ($UseWindowsAuth) {
    $connectionString = "Server=$ServerInstance;Database=$Database;Integrated Security=True;"
    Write-Host "Using Windows Authentication" -ForegroundColor Cyan
} else {
    if ([string]::IsNullOrEmpty($Username) -or [string]::IsNullOrEmpty($Password)) {
        Write-Error "Username and Password are required when not using Windows Authentication"
        exit 1
    }
    $connectionString = "Server=$ServerInstance;Database=$Database;User Id=$Username;Password=$Password;"
    Write-Host "Using SQL Server Authentication" -ForegroundColor Cyan
}

Write-Host "========================================" -ForegroundColor Yellow
Write-Host "T-SQL UNIT TEST EXECUTION" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "Server: $ServerInstance" -ForegroundColor White
Write-Host "Database: $Database" -ForegroundColor White
Write-Host "Test Harness: $TestHarnessPath" -ForegroundColor White
Write-Host "Output Path: $OutputPath" -ForegroundColor White
Write-Host "Start Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Yellow

try {
    # Read test harness script
    Write-Host "Reading test harness script..." -ForegroundColor Cyan
    $testScript = Get-Content -Path $TestHarnessPath -Raw
    
    # Execute test harness
    Write-Host "Executing test harness..." -ForegroundColor Cyan
    $startTime = Get-Date
    
    $results = Invoke-Sqlcmd -ConnectionString $connectionString `
                             -Query $testScript `
                             -QueryTimeout 300 `
                             -ErrorAction Stop `
                             -Verbose
    
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds
    
    Write-Host "Test execution completed in $duration seconds" -ForegroundColor Green
    
    # Parse test results
    Write-Host "Parsing test results..." -ForegroundColor Cyan
    
    # Extract summary from results
    $totalTests = 0
    $passedTests = 0
    $failedTests = 0
    $skippedTests = 0
    
    # This is a simplified parser - adjust based on actual output format
    foreach ($result in $results) {
        if ($result.TestStatus -eq 'PASS') { $passedTests++ }
        elseif ($result.TestStatus -eq 'FAIL') { $failedTests++ }
        elseif ($result.TestStatus -eq 'SKIP') { $skippedTests++ }
        $totalTests++
    }
    
    # Generate test summary
    $summary = @{
        ExecutionId = [guid]::NewGuid().ToString()
        ExecutionDate = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        ServerInstance = $ServerInstance
        Database = $Database
        TotalTests = $totalTests
        PassedTests = $passedTests
        FailedTests = $failedTests
        SkippedTests = $skippedTests
        SuccessRate = if ($totalTests -gt 0) { [math]::Round(($passedTests / $totalTests) * 100, 2) } else { 0 }
        DurationSeconds = [math]::Round($duration, 2)
    }
    
    # Save summary as JSON
    $summaryPath = Join-Path $OutputPath "test-summary.json"
    $summary | ConvertTo-Json | Out-File -FilePath $summaryPath -Encoding UTF8
    Write-Host "Test summary saved to: $summaryPath" -ForegroundColor Green
    
    # Generate Markdown summary
    $markdownSummary = @"
# T-SQL Unit Test Results

## Summary
- **Execution Date:** $($summary.ExecutionDate)
- **Total Tests:** $($summary.TotalTests)
- **Passed:** $($summary.PassedTests) ✅
- **Failed:** $($summary.FailedTests) ❌
- **Skipped:** $($summary.SkippedTests) ⏭️
- **Success Rate:** $($summary.SuccessRate)%
- **Duration:** $($summary.DurationSeconds) seconds

## Status
$(if ($failedTests -eq 0) { "✅ All tests passed!" } else { "❌ $failedTests test(s) failed. Please review the detailed report." })
"@
    
    $markdownPath = Join-Path $OutputPath "test-summary.md"
    $markdownSummary | Out-File -FilePath $markdownPath -Encoding UTF8
    Write-Host "Markdown summary saved to: $markdownPath" -ForegroundColor Green
    
    # Display summary
    Write-Host "
========================================" -ForegroundColor Yellow
    Write-Host "TEST EXECUTION SUMMARY" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "Total Tests: $totalTests" -ForegroundColor White
    Write-Host "Passed: $passedTests" -ForegroundColor Green
    Write-Host "Failed: $failedTests" -ForegroundColor $(if ($failedTests -gt 0) { "Red" } else { "White" })
    Write-Host "Skipped: $skippedTests" -ForegroundColor Yellow
    Write-Host "Success Rate: $($summary.SuccessRate)%" -ForegroundColor White
    Write-Host "Duration: $($summary.DurationSeconds) seconds" -ForegroundColor White
    Write-Host "========================================" -ForegroundColor Yellow
    
    # Exit with appropriate code
    if ($failedTests -gt 0) {
        Write-Host "TEST EXECUTION FAILED" -ForegroundColor Red
        exit 1
    } else {
        Write-Host "TEST EXECUTION PASSED" -ForegroundColor Green
        exit 0
    }
    
} catch {
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "ERROR DURING TEST EXECUTION" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    
    # Save error details
    $errorPath = Join-Path $OutputPath "test-error.log"
    $_ | Out-File -FilePath $errorPath -Encoding UTF8
    Write-Host "Error details saved to: $errorPath" -ForegroundColor Yellow
    
    exit 1
}
```

---

## Command Line Execution

### Using sqlcmd

```bash
# Windows
sqlcmd -S localhost -d TestDB -E -i "Output_DI_UnitTestingReport_TestHarness.sql" -o "test-results.txt"

# Linux/Mac
sqlcmd -S localhost -d TestDB -U testuser -P password -i "Output_DI_UnitTestingReport_TestHarness.sql" -o "test-results.txt"
```

### Using PowerShell

```powershell
# Windows Authentication
Invoke-Sqlcmd -ServerInstance "localhost" -Database "TestDB" -InputFile "Output_DI_UnitTestingReport_TestHarness.sql" -Verbose

# SQL Authentication
Invoke-Sqlcmd -ServerInstance "localhost" -Database "TestDB" -Username "testuser" -Password "password" -InputFile "Output_DI_UnitTestingReport_TestHarness.sql" -Verbose
```

---

## Test Result Publishing

### Azure DevOps
- Test results are automatically published using the `PublishTestResults@2` task
- Results appear in the **Tests** tab of the pipeline run
- Failed tests are highlighted with detailed error messages

### GitHub Actions
- Use the `EnricoMi/publish-unit-test-result-action` for rich test reporting
- Results appear as check runs on pull requests
- Test trends are tracked over time

### Jenkins
- Use the `junit` step to publish test results
- Results appear in the **Test Results** section
- Trend graphs show test history

---

## Notifications and Alerts

### Email Notifications

```powershell
# Add to Run-TSQLTests.ps1
function Send-TestNotification {
    param(
        [hashtable]$Summary,
        [string]$SmtpServer,
        [string]$From,
        [string[]]$To
    )
    
    $subject = if ($Summary.FailedTests -eq 0) {
        "✅ T-SQL Unit Tests Passed - $($Summary.SuccessRate)% Success Rate"
    } else {
        "❌ T-SQL Unit Tests Failed - $($Summary.FailedTests) Failures"
    }
    
    $body = @"
<html>
<body>
<h2>T-SQL Unit Test Results</h2>
<table border='1' cellpadding='5'>
<tr><td><b>Execution Date:</b></td><td>$($Summary.ExecutionDate)</td></tr>
<tr><td><b>Total Tests:</b></td><td>$($Summary.TotalTests)</td></tr>
<tr><td><b>Passed:</b></td><td style='color:green'>$($Summary.PassedTests)</td></tr>
<tr><td><b>Failed:</b></td><td style='color:red'>$($Summary.FailedTests)</td></tr>
<tr><td><b>Success Rate:</b></td><td>$($Summary.SuccessRate)%</td></tr>
<tr><td><b>Duration:</b></td><td>$($Summary.DurationSeconds) seconds</td></tr>
</table>
</body>
</html>
"@
    
    Send-MailMessage -SmtpServer $SmtpServer -From $From -To $To -Subject $subject -Body $body -BodyAsHtml
}
```

### Slack Notifications

```powershell
function Send-SlackNotification {
    param(
        [hashtable]$Summary,
        [string]$WebhookUrl
    )
    
    $color = if ($Summary.FailedTests -eq 0) { "good" } else { "danger" }
    $status = if ($Summary.FailedTests -eq 0) { "✅ PASSED" } else { "❌ FAILED" }
    
    $payload = @{
        text = "T-SQL Unit Test Results"
        attachments = @(
            @{
                color = $color
                title = "Test Execution $status"
                fields = @(
                    @{ title = "Total Tests"; value = $Summary.TotalTests; short = $true }
                    @{ title = "Passed"; value = $Summary.PassedTests; short = $true }
                    @{ title = "Failed"; value = $Summary.FailedTests; short = $true }
                    @{ title = "Success Rate"; value = "$($Summary.SuccessRate)%"; short = $true }
                )
            }
        )
    } | ConvertTo-Json -Depth 10
    
    Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $payload -ContentType 'application/json'
}
```

---

## Best Practices

### 1. Test Isolation
- Always use a dedicated test database
- Never run tests against production
- Use transactions for test isolation
- Clean up test data after execution

### 2. Performance
- Keep tests fast (< 2 minutes total)
- Run tests in parallel when possible
- Use minimal test data
- Optimize test queries

### 3. Reliability
- Make tests deterministic
- Avoid time-dependent tests
- Handle flaky tests
- Retry failed tests once

### 4. Maintenance
- Keep test cases up to date
- Review and update regularly
- Document test changes
- Version control all test artifacts

### 5. Security
- Use secrets management for credentials
- Never commit passwords
- Use least privilege accounts
- Encrypt sensitive data

---

## Troubleshooting

### Common Issues

#### Issue: Connection Timeout
**Solution:**
```powershell
# Increase query timeout
Invoke-Sqlcmd -QueryTimeout 600  # 10 minutes
```

#### Issue: Permission Denied
**Solution:**
- Verify database user has necessary permissions
- Check firewall rules
- Validate connection string

#### Issue: Test Harness Not Found
**Solution:**
```powershell
# Verify file path
Test-Path $TestHarnessPath
# Use absolute path
$TestHarnessPath = Resolve-Path "./test-harness.sql"
```

#### Issue: Module Not Found
**Solution:**
```powershell
# Install SqlServer module
Install-Module -Name SqlServer -Force -AllowClobber
```

### Debug Mode

```powershell
# Enable verbose output
$VerbosePreference = "Continue"
./Run-TSQLTests.ps1 -Verbose

# Enable debug output
$DebugPreference = "Continue"
./Run-TSQLTests.ps1 -Debug
```

---

## Support and Resources

### Documentation
- [SQL Server Testing Best Practices](https://docs.microsoft.com/sql/testing)
- [PowerShell SqlServer Module](https://docs.microsoft.com/powershell/module/sqlserver)
- [Azure DevOps Pipeline Documentation](https://docs.microsoft.com/azure/devops/pipelines)
- [GitHub Actions Documentation](https://docs.github.com/actions)

### Contact
- **Technical Support:** support@example.com
- **Documentation:** https://docs.example.com/tsql-testing
- **Issue Tracker:** https://github.com/example/tsql-testing/issues

---

**Document Version:** 1.0  
**Last Updated:** 2024-01-15  
**Next Review:** 2024-04-15

---

*This CI/CD integration guide is part of the T-SQL Unit Testing Framework v1.0*