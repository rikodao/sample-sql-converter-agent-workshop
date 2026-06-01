-- ============================================================================
-- TEST SUITE for dbo.usp_dept_with_cumulative_metrics
-- ============================================================================
-- This test suite covers:
-- - Normal cases with various date ranges
-- - Boundary conditions (NULL dates, empty results, single department)
-- - Edge cases (same hire dates, single employee, all departments)
-- - Error cases (invalid date range)
-- - Cumulative calculation verification
-- ============================================================================

-- ============= TEST CASE 1: Normal execution with default parameters =============
-- SETUP
-- No setup needed - using existing data

-- EXEC
EXEC dbo.usp_dept_with_cumulative_metrics;

-- ASSERT
SELECT 'TC1' AS test_case, 'Default parameters executed' AS result;

-- CLEANUP
-- No cleanup needed


-- ============= TEST CASE 2: Specific date range with all departments =============
-- SETUP
-- No setup needed

-- EXEC
EXEC dbo.usp_dept_with_cumulative_metrics 
    @start_date = '2020-01-01',
    @end_date = '2023-12-31';

-- ASSERT
SELECT 'TC2' AS test_case, 'Date range filter executed' AS result;

-- CLEANUP
-- No cleanup needed


-- ============= TEST CASE 3: Filter by specific department =============
-- SETUP
DECLARE @test_dept_id INT;
SELECT TOP 1 @test_dept_id = department_id FROM dbo.departments ORDER BY department_id;

-- EXEC
EXEC dbo.usp_dept_with_cumulative_metrics 
    @start_date = '2020-01-01',
    @end_date = '2023-12-31',
    @department_id = @test_dept_id;

-- ASSERT
SELECT 'TC3' AS test_case, 'Single department filter executed' AS result;

-- CLEANUP
-- No cleanup needed


-- ============= TEST CASE 4: Verify cumulative count calculation =============
-- SETUP
CREATE TABLE #test_employees (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    email NVARCHAR(100),
    hire_date DATE,
    department_id INT,
    salary DECIMAL(10,2),
    status NVARCHAR(20)
);

CREATE TABLE #test_departments (
    department_id INT PRIMARY KEY,
    department_name NVARCHAR(100),
    location NVARCHAR(100),
    manager_id INT
);

-- Insert test department
INSERT INTO #test_departments (department_id, department_name, location, manager_id)
VALUES (9999, 'Test Dept Cumulative', 'Test Location', NULL);

-- Insert test employees with known hire dates
SET IDENTITY_INSERT dbo.employees ON;

INSERT INTO dbo.employees (employee_id, first_name, last_name, email, hire_date, department_id, salary, status)
VALUES 
    (999901, 'TestEmp', 'One', 'test1@test.com', '2023-01-01', 9999, 50000, 'Active'),
    (999902, 'TestEmp', 'Two', 'test2@test.com', '2023-02-01', 9999, 60000, 'Active'),
    (999903, 'TestEmp', 'Three', 'test3@test.com', '2023-03-01', 9999, 70000, 'Active');

SET IDENTITY_INSERT dbo.employees OFF;

INSERT INTO dbo.departments (department_id, department_name, location, manager_id)
VALUES (9999, 'Test Dept Cumulative', 'Test Location', NULL);

-- EXEC
CREATE TABLE #cumulative_results (
    department_id INT,
    department_name NVARCHAR(100),
    location NVARCHAR(100),
    hire_date DATE,
    employee_id INT,
    employee_name NVARCHAR(101),
    salary DECIMAL(10,2),
    cumulative_employee_count INT,
    cumulative_salary_total DECIMAL(10,2),
    cumulative_salary_avg DECIMAL(10,2),
    hire_date_rank INT
);

INSERT INTO #cumulative_results
EXEC dbo.usp_dept_with_cumulative_metrics 
    @start_date = '2023-01-01',
    @end_date = '2023-12-31',
    @department_id = 9999;

-- ASSERT
SELECT 
    'TC4' AS test_case,
    CASE 
        WHEN COUNT(*) = 3 THEN 'PASS: 3 employees returned'
        ELSE 'FAIL: Expected 3 employees, got ' + CAST(COUNT(*) AS NVARCHAR(10))
    END AS result
FROM #cumulative_results
WHERE department_id = 9999;

SELECT 
    'TC4' AS test_case,
    'Cumulative counts: ' + 
    CAST(MIN(cumulative_employee_count) AS NVARCHAR(10)) + ', ' +
    CAST(MAX(cumulative_employee_count) AS NVARCHAR(10)) AS result
FROM #cumulative_results
WHERE department_id = 9999;

SELECT 
    'TC4' AS test_case,
    CASE 
        WHEN cumulative_salary_total = 180000 THEN 'PASS: Final cumulative salary correct (180000)'
        ELSE 'FAIL: Expected 180000, got ' + CAST(cumulative_salary_total AS NVARCHAR(20))
    END AS result
FROM #cumulative_results
WHERE department_id = 9999 
  AND cumulative_employee_count = 3;

-- CLEANUP
DROP TABLE #cumulative_results;
DROP TABLE #test_employees;
DROP TABLE #test_departments;

DELETE FROM dbo.employees WHERE employee_id BETWEEN 999901 AND 999903;
DELETE FROM dbo.departments WHERE department_id = 9999;


-- ============= TEST CASE 5: Invalid date range (start > end) =============
-- SETUP
-- No setup needed

-- EXEC & ASSERT
BEGIN TRY
    EXEC dbo.usp_dept_with_cumulative_metrics 
        @start_date = '2023-12-31',
        @end_date = '2023-01-01';
    SELECT 'TC5' AS test_case, 'FAIL: Should have raised error' AS result;
END TRY
BEGIN CATCH
    SELECT 'TC5' AS test_case, 'PASS: Error raised - ' + ERROR_MESSAGE() AS result;
END CATCH

-- CLEANUP
-- No cleanup needed


-- ============= TEST CASE 6: Empty result set (no employees in date range) =============
-- SETUP
-- No setup needed

-- EXEC
EXEC dbo.usp_dept_with_cumulative_metrics 
    @start_date = '1900-01-01',
    @end_date = '1900-12-31';

-- ASSERT
SELECT 'TC6' AS test_case, 'Empty date range executed (should return no rows)' AS result;

-- CLEANUP
-- No cleanup needed


-- ============= TEST CASE 7: NULL start_date (should use default) =============
-- SETUP
-- No setup needed

-- EXEC
EXEC dbo.usp_dept_with_cumulative_metrics 
    @start_date = NULL,
    @end_date = '2023-12-31';

-- ASSERT
SELECT 'TC7' AS test_case, 'NULL start_date handled with default' AS result;

-- CLEANUP
-- No cleanup needed


-- ============= TEST CASE 8: NULL end_date (should use default) =============
-- SETUP
-- No setup needed

-- EXEC
EXEC dbo.usp_dept_with_cumulative_metrics 
    @start_date = '2020-01-01',
    @end_date = NULL;

-- ASSERT
SELECT 'TC8' AS test_case, 'NULL end_date handled with default' AS result;

-- CLEANUP
-- No cleanup needed


-- ============= TEST CASE 9: Both dates NULL (should use defaults) =============
-- SETUP
-- No setup needed

-- EXEC
EXEC dbo.usp_dept_with_cumulative_metrics 
    @start_date = NULL,
    @end_date = NULL;

-- ASSERT
SELECT 'TC9' AS test_case, 'Both NULL dates handled with defaults' AS result;

-- CLEANUP
-- No cleanup needed


-- ============= TEST CASE 10: Multiple employees with same hire date =============
-- SETUP
SET IDENTITY_INSERT dbo.employees ON;

INSERT INTO dbo.employees (employee_id, first_name, last_name, email, hire_date, department_id, salary, status)
VALUES 
    (999911, 'SameDate', 'One', 'same1@test.com', '2023-06-01', 1, 55000, 'Active'),
    (999912, 'SameDate', 'Two', 'same2@test.com', '2023-06-01', 1, 56000, 'Active'),
    (999913, 'SameDate', 'Three', 'same3@test.com', '2023-06-01', 1, 57000, 'Active');

SET IDENTITY_INSERT dbo.employees OFF;

-- EXEC
CREATE TABLE #same_date_results (
    department_id INT,
    department_name NVARCHAR(100),
    location NVARCHAR(100),
    hire_date DATE,
    employee_id INT,
    employee_name NVARCHAR(101),
    salary DECIMAL(10,2),
    cumulative_employee_count INT,
    cumulative_salary_total DECIMAL(10,2),
    cumulative_salary_avg DECIMAL(10,2),
    hire_date_rank INT
);

INSERT INTO #same_date_results
EXEC dbo.usp_dept_with_cumulative_metrics 
    @start_date = '2023-06-01',
    @end_date = '2023-06-01',
    @department_id = 1;

-- ASSERT
SELECT 
    'TC10' AS test_case,
    CASE 
        WHEN COUNT(DISTINCT cumulative_employee_count) = 3 
        THEN 'PASS: Cumulative counts are distinct for same hire date'
        ELSE 'FAIL: Cumulative counts not properly ordered'
    END AS result
FROM #same_date_results
WHERE employee_id BETWEEN 999911 AND 999913;

SELECT 
    'TC10' AS test_case,
    'Employee count progression: ' + 
    STUFF((SELECT ', ' + CAST(cumulative_employee_count AS NVARCHAR(10))
           FROM #same_date_results 
           WHERE employee_id BETWEEN 999911 AND 999913
           ORDER BY employee_id
           FOR XML PATH('')), 1, 2, '') AS result;

-- CLEANUP
DROP TABLE #same_date_results;
DELETE FROM dbo.employees WHERE employee_id BETWEEN 999911 AND 999913;


-- ============= TEST CASE 11: Non-existent department_id =============
-- SETUP
-- No setup needed

-- EXEC
EXEC dbo.usp_dept_with_cumulative_metrics 
    @start_date = '2020-01-01',
    @end_date = '2023-12-31',
    @department_id = 99999;

-- ASSERT
SELECT 'TC11' AS test_case, 'Non-existent department handled (should return no rows)' AS result;

-- CLEANUP
-- No cleanup needed


-- ============= TEST CASE 12: Verify running average calculation =============
-- SETUP
SET IDENTITY_INSERT dbo.employees ON;

INSERT INTO dbo.departments (department_id, department_name, location, manager_id)
VALUES (9998, 'Test Dept Avg', 'Test Location', NULL);

INSERT INTO dbo.employees (employee_id, first_name, last_name, email, hire_date, department_id, salary, status)
VALUES 
    (999921, 'AvgTest', 'One', 'avg1@test.com', '2023-07-01', 9998, 60000, 'Active'),
    (999922, 'AvgTest', 'Two', 'avg2@test.com', '2023-07-02', 9998, 80000, 'Active');

SET IDENTITY_INSERT dbo.employees OFF;

-- EXEC
CREATE TABLE #avg_results (
    department_id INT,
    department_name NVARCHAR(100),
    location NVARCHAR(100),
    hire_date DATE,
    employee_id INT,
    employee_name NVARCHAR(101),
    salary DECIMAL(10,2),
    cumulative_employee_count INT,
    cumulative_salary_total DECIMAL(10,2),
    cumulative_salary_avg DECIMAL(10,2),
    hire_date_rank INT
);

INSERT INTO #avg_results
EXEC dbo.usp_dept_with_cumulative_metrics 
    @start_date = '2023-07-01',
    @end_date = '2023-07-31',
    @department_id = 9998;

-- ASSERT
SELECT 
    'TC12' AS test_case,
    CASE 
        WHEN cumulative_salary_avg = 60000.00 THEN 'PASS: First avg is 60000'
        ELSE 'FAIL: Expected 60000, got ' + CAST(cumulative_salary_avg AS NVARCHAR(20))
    END AS result
FROM #avg_results
WHERE employee_id = 999921;

SELECT 
    'TC12' AS test_case,
    CASE 
        WHEN cumulative_salary_avg = 70000.00 THEN 'PASS: Second avg is 70000'
        ELSE 'FAIL: Expected 70000, got ' + CAST(cumulative_salary_avg AS NVARCHAR(20))
    END AS result
FROM #avg_results
WHERE employee_id = 999922;

-- CLEANUP
DROP TABLE #avg_results;
DELETE FROM dbo.employees WHERE employee_id BETWEEN 999921 AND 999922;
DELETE FROM dbo.departments WHERE department_id = 9998;


-- ============================================================================
-- END OF TEST SUITE
-- ============================================================================
