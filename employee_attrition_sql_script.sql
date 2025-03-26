-- ============================================================
-- 1. CREATE DATABASE AND TABLE STRUCTURE
-- ============================================================
-- Create a new database for employee attrition analysis
CREATE DATABASE EmployeeAttrition;
USE EmployeeAttrition;

-- Create the main table to store cleaned employee data
CREATE TABLE employee_data (
    EmployeeID INT PRIMARY KEY AUTO_INCREMENT,  -- Unique identifier for each employee
    Age INT NOT NULL,
    Attrition TINYINT NOT NULL,   -- 1 = Yes, 0 = No
    BusinessTravel VARCHAR(50) NOT NULL,
    Department VARCHAR(50) NOT NULL,
    DistanceFromHome INT NOT NULL,
    Education INT CHECK (Education BETWEEN 1 AND 5),
    EducationField VARCHAR(50) NOT NULL,
    Gender VARCHAR(10) NOT NULL,
    JobRole VARCHAR(50) NOT NULL,
    MaritalStatus VARCHAR(20) NOT NULL,
    MonthlyIncome INT NOT NULL,
    NumCompaniesWorked INT,
    OverTime TINYINT NOT NULL,   -- 1 = Yes, 0 = No
    TotalWorkingYears INT,
    YearsAtCompany INT NOT NULL,
    JobSatisfaction INT CHECK (JobSatisfaction BETWEEN 1 AND 4),  -- Job satisfaction rating (1-4 scale)
    WorkLifeBalance INT CHECK (WorkLifeBalance BETWEEN 1 AND 4),  -- Work-life balance rating (1-4 scale)
    JobInvolvement INT CHECK (JobInvolvement BETWEEN 1 AND 4)   -- Job involvement rating (1-4 scale)
);

-- Preview the first 10 rows of the raw employee dataset to inspect data structure and values before analysis.  
select * from raw_employee_data LIMIT 10 ;

-- ============================================================
-- 2. CLEAN AND TRANSFORM DATA
-- ============================================================
-- Convert categorical 'Yes/No' values into numeric values (1 and 0)
-- This ensures consistency and improves data processing efficiency.
UPDATE raw_employee_data
SET  Attrition = CASE WHEN attrition = 'yes' then 1 else 0 end;

UPDATE raw_employee_data
SET  overtime = CASE WHEN overtime = 'yes' then 1 else 0 end;

-- ============================================================
-- 3. INSERT CLEANED DATA INTO MAIN TABLE
-- ============================================================
-- Move the cleaned data from the raw table into the main table
INSERT INTO employee_data (
    Age, Attrition, BusinessTravel, Department, DistanceFromHome,
    Education, EducationField, Gender, JobRole, MaritalStatus,
    MonthlyIncome, NumCompaniesWorked, OverTime, TotalWorkingYears,
    YearsAtCompany, JobSatisfaction, WorkLifeBalance, JobInvolvement
)
SELECT 
    Age, Attrition, BusinessTravel, Department, DistanceFromHome,
    Education, EducationField, Gender, JobRole, MaritalStatus,
    MonthlyIncome, NumCompaniesWorked, OverTime, TotalWorkingYears,
    YearsAtCompany, JobSatisfaction, WorkLifeBalance, JobInvolvement
FROM raw_employee_data;

-- Verify Data Import
select * from employee_data limit 10;

-- Remove raw data table after data transfer
drop table raw_employee_data;

-- Check for missing values in key columns to ensure data completeness.  
SELECT 
    SUM(CASE WHEN Age IS NULL THEN 1 ELSE 0 END) AS Missing_Age,
    SUM(CASE WHEN Attrition IS NULL THEN 1 ELSE 0 END) AS Missing_Attrition,
    SUM(CASE WHEN BusinessTravel IS NULL THEN 1 ELSE 0 END) AS Missing_BusinessTravel,
    SUM(CASE WHEN DistanceFromHome IS NULL THEN 1 ELSE 0 END) AS Missing_DistanceFromHome
FROM employee_data;

-- no missing values were found in these columns.

-- ================================================
-- 4. STANDARDIZE CATEGORICAL DATA
-- ================================================
-- Standardize Business Travel values:
-- The dataset originally contains 'Travel_Rarely', 'Travel_Frequently', and 'Non-Travel'.
-- Rename them to 'Rarely', 'Frequently', and 'No Travel'.
UPDATE employee_data 
SET BusinessTravel = 'Rarely' WHERE BusinessTravel = 'Travel_Rarely';

UPDATE employee_data 
SET BusinessTravel = 'Frequently' WHERE BusinessTravel = 'Travel_Frequently';

UPDATE employee_data 
SET BusinessTravel = 'No Travel' WHERE BusinessTravel = 'Non-Travel';

-- Standardize Gender values:
-- Convert 'Male' to 'M' and 'Female' to 'F'.
update employee_data set gender = 'M' where gender = 'male';
update employee_data set gender = 'F' where gender = 'female';

-- Standardize Marital Status values:
-- Convert long text categories into abbreviations:
-- 'Single' → 'S', 'Married' → 'M', 'Divorced' → 'D'
UPDATE employee_data SET MaritalStatus = 'S' WHERE MaritalStatus = 'Single';
UPDATE employee_data SET MaritalStatus = 'M' WHERE MaritalStatus = 'Married';
UPDATE employee_data SET MaritalStatus = 'D' WHERE MaritalStatus = 'Divorced';

-- ================================================
-- 5. DETECT AND TREAT OUTLIERS IN MONTHLY INCOME
-- ================================================
-- Detect Outliers in Monthly Income:
-- Checking min, max, and avg values for Age, Monthly Income, and Years at Company to identify potential outliers.
SELECT MIN(Age), MAX(Age), AVG(Age) FROM employee_data;
SELECT MIN(MonthlyIncome), MAX(MonthlyIncome), AVG(MonthlyIncome) FROM employee_data;
SELECT MIN(YearsAtCompany), MAX(YearsAtCompany), AVG(YearsAtCompany) FROM employee_data;

-- Treat Outliers in Monthly Income using a Threshold Table:
-- Outliers in Monthly Income can significantly impact analysis.
-- A common method to treat high-income outliers is to cap values beyond 
-- a reasonable threshold.
-- Here, we define a threshold as 3 times the average Monthly Income.
-- Any Monthly Income exceeding this limit will be replaced with the threshold value.
UPDATE employee_data e
JOIN (SELECT AVG(MonthlyIncome) * 3 AS income_threshold FROM employee_data) AS t
ON e.MonthlyIncome > t.income_threshold
SET e.MonthlyIncome = t.income_threshold;

-- ================================================
-- 6. ADD CATEGORICAL COLUMNS FOR ANALYSIS
-- ================================================
-- Add Tenure Category.
ALTER TABLE employee_data ADD COLUMN TenureCategory VARCHAR(20);

-- Assigning tenure categories based on YearsAtCompany
UPDATE employee_data
SET TenureCategory =
	CASE
		WHEN YearsAtCompany < 3 THEN 'Short-Term'
        WHEN YearsAtCompany BETWEEN 3 AND 7 THEN 'Medium-Term'
        ELSE 'Long-Term'
	END;

-- Add Salary Category.
ALTER TABLE employee_data ADD COLUMN SalaryCategory VARCHAR(20);

-- Categorizing employees based on their monthly income.
UPDATE employee_data
SET SalaryCategory = 
	CASE
		WHEN MonthlyIncome < 3000 THEN 'Low'
        WHEN MonthlyIncome BETWEEN 3000 AND 8000 THEN 'Medium'
        ELSE 'High'
	END;

-- Check Data After Cleaning
SELECT * FROM employee_data LIMIT 10;

-- ================================================
-- 7. ATTRITION ANALYSIS
-- ================================================
-- Calculate Overall Attrition Rate
SELECT
	SUM(Attrition) AS TotalAttrition,
    COUNT(*) AS TotalEmployees,
    ROUND((SUM(Attrition) / COUNT(*)) * 100 , 2) AS AttritionRate
FROM employee_data;

-- Attrition Analysis by Department
SELECT Department,
	COUNT(*) AS TotalEmployees,
    SUM(Attrition) AS AttritionCount,
    ROUND((SUM(Attrition) / COUNT(*)) * 100 , 2) AS AttritionRate
FROM employee_data
GROUP BY Department
ORDER BY AttritionRate DESC;

-- Attrition Analysis by Salary Category
SELECT SalaryCategory,
	COUNT(*) AS TotalEmployees,
    SUM(Attrition) AS AttritionCount,
    ROUND((SUM(Attrition) / COUNT(*)) * 100 , 2) AS AttritionRate
FROM employee_data
GROUP BY SalaryCategory
ORDER BY AttritionRate DESC;

-- Attrition Analysis by Job Role
SELECT JobRole,
	COUNT(*) AS TotalEmployees,
    SUM(Attrition) AS AttritionCount,
    ROUND((SUM(Attrition) / COUNT(*)) * 100 , 2) AS AttritionRate
FROM employee_data
GROUP BY JobRole
ORDER BY AttritionRate DESC;
 
-- Attrition Analysis by Tenure Category
SELECT TenureCategory,
	COUNT(*) AS TotalEmployees,
    SUM(Attrition) AS AttritionCount,
    ROUND((SUM(Attrition) / COUNT(*)) * 100 , 2) AS AttritionRate
FROM employee_data
GROUP BY TenureCategory
ORDER BY AttritionRate DESC;

-- Attrition Analysis by Work-Life Balance
SELECT WorkLifeBalance,
	COUNT(*) AS TotalEmployees,
    SUM(Attrition) AS AttritionCount,
    ROUND((SUM(Attrition) / COUNT(*)) * 100 , 2) AS AttritionRate
FROM employee_data
GROUP BY WorkLifeBalance
ORDER BY AttritionRate DESC;

-- Attrition Analysis by Overtime
SELECT OverTime,
	COUNT(*) AS TotalEmployees,
    SUM(Attrition) AS AttritionCount,
    ROUND((SUM(Attrition) / COUNT(*)) * 100 , 2) AS AttritionRate
FROM employee_data
GROUP BY OverTime
ORDER BY AttritionRate DESC;

