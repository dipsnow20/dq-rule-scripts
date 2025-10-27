# Data Quality Rules for Compensation Survey Data

## Comprehensive DQ Analysis for Survey Data on Compensation Models Across Countries and Industries

| Data Category | Entity | Element Name | Data Quality Rule Name | Data Quality Rule Description | Remarks |
|---------------|--------|--------------|------------------------|-------------------------------|----------|
| Employee Demographics | Employee | Employee_ID | Uniqueness Check | Each Employee_ID must be unique across the entire dataset with no duplicates allowed | Industry best practice - Primary key integrity essential for accurate compensation analysis |
| Employee Demographics | Employee | Employee_Name | Completeness Check | Employee_Name field must not be null or empty for any record | Industry best practice - Required for survey participant identification and validation |
| Employee Demographics | Employee | Age | Value Range Validation | Age must be between 18 and 75 years inclusive | Industry best practice - Reasonable working age range for compensation surveys |
| Employee Demographics | Employee | Gender | Domain Validation | Gender must be one of predefined values: Male, Female, Non-binary, Prefer not to say | Industry best practice - Standardized gender categories for demographic analysis |
| Employee Demographics | Employee | Years_of_Experience | Consistency Check | Years_of_Experience must be less than or equal to (Age - 16) | Industry best practice - Logical consistency between age and experience |
| Geographic Information | Location | Country_Code | Referential Integrity | Country_Code must exist in ISO 3166-1 alpha-2 standard country codes | Industry best practice - Standardized country coding for international compensation analysis |
| Geographic Information | Location | Country_Name | Completeness Check | Country_Name must not be null or empty and must correspond to Country_Code | Industry best practice - Required for geographic compensation benchmarking |
| Geographic Information | Location | Region | Domain Validation | Region must be one of predefined regional classifications (e.g., North America, Europe, Asia-Pacific, etc.) | Industry best practice - Standardized regional groupings for compensation analysis |
| Geographic Information | Location | City | Format Validation | City name must contain only alphabetic characters, spaces, hyphens, and apostrophes | Industry best practice - Standardized city name format for location-based pay analysis |
| Geographic Information | Location | Cost_of_Living_Index | Value Range Validation | Cost_of_Living_Index must be between 0.1 and 5.0 | Industry best practice - Reasonable range for cost of living adjustments in compensation |
| Industry Classification | Industry | Industry_Code | Referential Integrity | Industry_Code must exist in standard industry classification (NAICS or SIC) | Industry best practice - Standardized industry coding for sector-based compensation analysis |
| Industry Classification | Industry | Industry_Name | Completeness Check | Industry_Name must not be null or empty and must correspond to Industry_Code | Industry best practice - Required for industry-specific compensation benchmarking |
| Industry Classification | Industry | Industry_Sector | Domain Validation | Industry_Sector must be one of predefined sectors (Technology, Healthcare, Finance, Manufacturing, etc.) | Industry best practice - Standardized sector groupings for compensation analysis |
| Industry Classification | Industry | Company_Size | Domain Validation | Company_Size must be one of predefined categories (Startup <50, Small 50-249, Medium 250-999, Large 1000+) | Industry best practice - Standardized company size categories for compensation scaling |
| Job Information | Position | Job_ID | Uniqueness Check | Each Job_ID must be unique across the dataset with no duplicates allowed | Industry best practice - Unique job identification essential for position-based analysis |
| Job Information | Position | Job_Title | Completeness Check | Job_Title must not be null or empty for any record | Industry best practice - Required for role-based compensation analysis |
| Job Information | Position | Job_Level | Domain Validation | Job_Level must be one of predefined levels (Entry, Junior, Mid, Senior, Lead, Manager, Director, VP, C-Level) | Industry best practice - Standardized job levels for hierarchical compensation analysis |
| Job Information | Position | Job_Function | Domain Validation | Job_Function must be one of predefined functions (Engineering, Sales, Marketing, HR, Finance, Operations, etc.) | Industry best practice - Standardized job functions for functional compensation analysis |
| Job Information | Position | Reports_To | Referential Integrity | Reports_To must reference a valid Job_ID that exists in the dataset or be null for top-level positions | Industry best practice - Organizational hierarchy validation for management compensation analysis |
| Compensation Data | Salary | Base_Salary | Completeness Check | Base_Salary must not be null or empty for any record | Industry best practice - Core compensation component required for all analysis |
| Compensation Data | Salary | Base_Salary | Value Range Validation | Base_Salary must be between 10000 and 2000000 in local currency | Industry best practice - Reasonable salary range to identify data entry errors |
| Compensation Data | Salary | Currency_Code | Referential Integrity | Currency_Code must exist in ISO 4217 standard currency codes | Industry best practice - Standardized currency coding for international compensation comparison |
| Compensation Data | Salary | Salary_Frequency | Domain Validation | Salary_Frequency must be one of: Annual, Monthly, Weekly, Hourly | Industry best practice - Standardized frequency for salary normalization |
| Compensation Data | Bonus | Annual_Bonus | Value Range Validation | Annual_Bonus must be >= 0 and <= (Base_Salary * 5) if not null | Industry best practice - Reasonable bonus range relative to base salary |
| Compensation Data | Bonus | Bonus_Percentage | Consistency Check | Bonus_Percentage must equal (Annual_Bonus / Base_Salary * 100) when both are present | Industry best practice - Mathematical consistency between bonus amount and percentage |
| Compensation Data | Bonus | Bonus_Type | Domain Validation | Bonus_Type must be one of: Performance, Retention, Signing, Spot, Annual | Industry best practice - Standardized bonus categorization for compensation analysis |
| Compensation Data | Equity | Stock_Options | Value Range Validation | Stock_Options must be >= 0 if not null | Industry best practice - Non-negative equity values |
| Compensation Data | Equity | Equity_Value | Consistency Check | Equity_Value must be calculated consistently based on stock price and number of options/shares | Industry best practice - Accurate equity valuation for total compensation analysis |
| Compensation Data | Equity | Vesting_Schedule | Format Validation | Vesting_Schedule must follow standard format (e.g., '4 years, 1 year cliff' or '25% per year') | Industry best practice - Standardized vesting schedule representation |
| Benefits Data | Benefits | Health_Insurance | Domain Validation | Health_Insurance must be one of: Full, Partial, None | Industry best practice - Standardized health insurance coverage categories |
| Benefits Data | Benefits | Retirement_Plan | Domain Validation | Retirement_Plan must be one of: 401k, Pension, Both, None | Industry best practice - Standardized retirement plan categories |
| Benefits Data | Benefits | Vacation_Days | Value Range Validation | Vacation_Days must be between 0 and 50 days per year | Industry best practice - Reasonable vacation day range for benefit analysis |
| Benefits Data | Benefits | Benefits_Value | Value Range Validation | Benefits_Value must be >= 0 and <= (Base_Salary * 0.5) if not null | Industry best practice - Reasonable benefits value relative to base salary |
| Survey Metadata | Survey | Survey_ID | Uniqueness Check | Each Survey_ID must be unique across the dataset | Industry best practice - Unique survey identification for data lineage |
| Survey Metadata | Survey | Survey_Date | Date Format Validation | Survey_Date must be in valid date format (YYYY-MM-DD) and within last 2 years | Industry best practice - Recent and properly formatted survey dates |
| Survey Metadata | Survey | Survey_Source | Completeness Check | Survey_Source must not be null or empty | Industry best practice - Data provenance tracking for survey reliability |
| Survey Metadata | Survey | Response_Status | Domain Validation | Response_Status must be one of: Complete, Partial, Incomplete | Industry best practice - Standardized response status for data quality assessment |
| Survey Metadata | Survey | Data_Collection_Method | Domain Validation | Data_Collection_Method must be one of: Online, Phone, Email, In-person | Industry best practice - Method tracking for survey bias analysis |
| Validation Data | Validation | Record_Status | Domain Validation | Record_Status must be one of: Valid, Invalid, Under_Review, Flagged | Industry best practice - Record validation status for data quality management |
| Validation Data | Validation | Validation_Date | Date Format Validation | Validation_Date must be in valid date format and >= Survey_Date | Industry best practice - Proper validation timeline tracking |
| Validation Data | Validation | Validation_Notes | Length Validation | Validation_Notes must be <= 500 characters if not null | Industry best practice - Reasonable length limit for validation comments |
| Validation Data | Validation | Data_Quality_Score | Value Range Validation | Data_Quality_Score must be between 0 and 100 | Industry best practice - Standardized quality scoring system |
| Audit Trail | Audit | Created_Date | Date Format Validation | Created_Date must be in valid timestamp format (YYYY-MM-DD HH:MM:SS) | Industry best practice - Proper audit trail timestamp format |
| Audit Trail | Audit | Created_By | Completeness Check | Created_By must not be null or empty | Industry best practice - User accountability for data creation |
| Audit Trail | Audit | Modified_Date | Consistency Check | Modified_Date must be >= Created_Date if not null | Industry best practice - Logical modification date sequence |
| Audit Trail | Audit | Modified_By | Referential Integrity | Modified_By must reference valid user if Modified_Date is present | Industry best practice - User accountability for data modifications |
| Data Relationships | Cross-Entity | Employee_Job_Mapping | Referential Integrity | Each Employee_ID must have corresponding Job_ID and vice versa | Industry best practice - Maintain employee-position relationship integrity |
| Data Relationships | Cross-Entity | Location_Industry_Consistency | Consistency Check | Location and Industry combination must be logically consistent (e.g., Oil industry not in landlocked countries without oil) | Industry best practice - Logical geographic-industry relationship validation |
| Data Relationships | Cross-Entity | Compensation_Currency_Location | Consistency Check | Currency_Code must be appropriate for the Country_Code (primary or commonly used currency) | Industry best practice - Geographic-currency consistency for accurate compensation analysis |
| Data Relationships | Cross-Entity | Total_Compensation_Calculation | Mathematical Validation | Total_Compensation must equal Base_Salary + Annual_Bonus + Equity_Value + Benefits_Value | Industry best practice - Accurate total compensation calculation |

## Summary

This comprehensive data quality framework covers all critical aspects of compensation survey data:

- **Employee Demographics**: Ensuring participant data integrity
- **Geographic Information**: Standardizing location-based analysis
- **Industry Classification**: Maintaining sector-based consistency
- **Job Information**: Validating position and hierarchy data
- **Compensation Data**: Ensuring accurate salary, bonus, and equity information
- **Benefits Data**: Standardizing benefit categorization and valuation
- **Survey Metadata**: Tracking data provenance and collection methods
- **Validation Data**: Managing data quality assessment
- **Audit Trail**: Maintaining data lineage and accountability
- **Data Relationships**: Ensuring cross-entity consistency

All rules are based on industry best practices for compensation survey data quality management and are designed to ensure reliable, accurate, and usable data for compensation benchmarking and analysis.