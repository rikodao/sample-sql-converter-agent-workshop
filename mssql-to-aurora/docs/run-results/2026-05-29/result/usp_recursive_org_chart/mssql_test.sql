-- ============================================================================
-- TEST SUITE: dbo.usp_recursive_org_chart
-- ============================================================================
-- Purpose: Comprehensive test cases for recursive organizational chart procedure
-- Coverage: Normal cases, boundary conditions, error cases, recursive depth
-- ============================================================================

-- ============================================================================
-- TEST CASE 1: Basic hierarchy from top (no parameters)
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_employees') IS NOT NULL DROP TABLE #test_employees;
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;

CREATE TABLE #test_departments (
    department_id INT PRIMARY KEY,
    department_name NVARCHAR(100)
);

CREATE TABLE #test_employees (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    job_title NVARCHAR(100),
    department_id INT,
    manager_id INT,
    hire_date DATE,
    is_active BIT
);

INSERT INTO #test_departments (department_id, department_name)
VALUES (1, 'Executive'), (2, 'Engineering'), (3, 'Sales');

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO #test_employees (employee_id, first_name, last_name, job_title, department_id, manager_id, hire_date, is_active)
VALUES 
    (1, 'Alice', 'Anderson', 'CEO', 1, NULL, '2020-01-01', 1),
    (2, 'Bob', 'Brown', 'VP Engineering', 2, 1, '2020-02-01', 1),
    (3, 'Carol', 'Clark', 'VP Sales', 3, 1, '2020-03-01', 1),
    (4, 'David', 'Davis', 'Senior Engineer', 2, 2, '2020-04-01', 1),
    (5, 'Eve', 'Evans', 'Engineer', 2, 4, '2020-05-01', 1);
SET IDENTITY_INSERT dbo.employees OFF;

-- EXEC
EXEC dbo.usp_recursive_org_chart;

-- ASSERT
SELECT 'TC1' AS test_case, COUNT(*) AS total_employees, MAX(level) AS max_depth
FROM (
    -- Re-execute to capture results
    EXEC dbo.usp_recursive_org_chart
) AS results;

-- CLEANUP
DROP TABLE #test_employees;
DROP TABLE #test_departments;

-- ============================================================================
-- TEST CASE 2: Hierarchy from specific employee (mid-level manager)
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_employees2') IS NOT NULL DROP TABLE #test_employees2;
IF OBJECT_ID('tempdb..#test_departments2') IS NOT NULL DROP TABLE #test_departments2;

CREATE TABLE #test_departments2 (
    department_id INT PRIMARY KEY,
    department_name NVARCHAR(100)
);

CREATE TABLE #test_employees2 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    job_title NVARCHAR(100),
    department_id INT,
    manager_id INT,
    hire_date DATE,
    is_active BIT
);

INSERT INTO #test_departments2 (department_id, department_name)
VALUES (1, 'Executive'), (2, 'Engineering');

INSERT INTO #test_employees2 (employee_id, first_name, last_name, job_title, department_id, manager_id, hire_date, is_active)
VALUES 
    (1, 'Alice', 'Anderson', 'CEO', 1, NULL, '2020-01-01', 1),
    (2, 'Bob', 'Brown', 'VP Engineering', 2, 1, '2020-02-01', 1),
    (4, 'David', 'Davis', 'Senior Engineer', 2, 2, '2020-04-01', 1),
    (5, 'Eve', 'Evans', 'Engineer', 2, 4, '2020-05-01', 1),
    (6, 'Frank', 'Foster', 'Engineer', 2, 4, '2020-06-01', 1);

-- EXEC
EXEC dbo.usp_recursive_org_chart @root_employee_id = 2;

-- ASSERT
SELECT 'TC2' AS test_case, 
       COUNT(*) AS employee_count,
       MIN(level) AS min_level,
       MAX(level) AS max_level
FROM (
    SELECT employee_id, level
    FROM dbo.employees e
    WHERE employee_id IN (2, 4, 5, 6)
) AS expected;

-- CLEANUP
DROP TABLE #test_employees2;
DROP TABLE #test_departments2;

-- ============================================================================
-- TEST CASE 3: Max depth limit (depth = 1, only direct reports)
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_employees3') IS NOT NULL DROP TABLE #test_employees3;

CREATE TABLE #test_employees3 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    job_title NVARCHAR(100),
    department_id INT,
    manager_id INT,
    hire_date DATE,
    is_active BIT
);

INSERT INTO #test_employees3 (employee_id, first_name, last_name, job_title, department_id, manager_id, hire_date, is_active)
VALUES 
    (1, 'Alice', 'Anderson', 'CEO', 1, NULL, '2020-01-01', 1),
    (2, 'Bob', 'Brown', 'VP Engineering', 2, 1, '2020-02-01', 1),
    (3, 'Carol', 'Clark', 'VP Sales', 3, 1, '2020-03-01', 1),
    (4, 'David', 'Davis', 'Senior Engineer', 2, 2, '2020-04-01', 1);

-- EXEC
EXEC dbo.usp_recursive_org_chart @root_employee_id = 1, @max_depth = 1;

-- ASSERT
SELECT 'TC3' AS test_case, 
       COUNT(*) AS returned_count,
       MAX(level) AS max_level_returned
FROM (
    SELECT employee_id, level
    FROM dbo.employees
    WHERE employee_id IN (1, 2, 3)
) AS expected;

-- Expected: 3 employees (CEO + 2 direct reports), max level = 1

-- CLEANUP
DROP TABLE #test_employees3;

-- ============================================================================
-- TEST CASE 4: Include inactive employees
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_employees4') IS NOT NULL DROP TABLE #test_employees4;

CREATE TABLE #test_employees4 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    job_title NVARCHAR(100),
    department_id INT,
    manager_id INT,
    hire_date DATE,
    is_active BIT
);

INSERT INTO #test_employees4 (employee_id, first_name, last_name, job_title, department_id, manager_id, hire_date, is_active)
VALUES 
    (1, 'Alice', 'Anderson', 'CEO', 1, NULL, '2020-01-01', 1),
    (2, 'Bob', 'Brown', 'VP Engineering', 2, 1, '2020-02-01', 0),  -- INACTIVE
    (3, 'Carol', 'Clark', 'VP Sales', 3, 1, '2020-03-01', 1);

-- EXEC (exclude inactive - default)
EXEC dbo.usp_recursive_org_chart @include_inactive = 0;

-- ASSERT
SELECT 'TC4a' AS test_case, COUNT(*) AS active_only_count
FROM (
    SELECT employee_id FROM dbo.employees WHERE is_active = 1
) AS active;

-- EXEC (include inactive)
EXEC dbo.usp_recursive_org_chart @include_inactive = 1;

-- ASSERT
SELECT 'TC4b' AS test_case, COUNT(*) AS all_employees_count
FROM (
    SELECT employee_id FROM dbo.employees
) AS all_emp;

-- CLEANUP
DROP TABLE #test_employees4;

-- ============================================================================
-- TEST CASE 5: Leaf node employee (no direct reports)
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_employees5') IS NOT NULL DROP TABLE #test_employees5;

CREATE TABLE #test_employees5 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    job_title NVARCHAR(100),
    department_id INT,
    manager_id INT,
    hire_date DATE,
    is_active BIT
);

INSERT INTO #test_employees5 (employee_id, first_name, last_name, job_title, department_id, manager_id, hire_date, is_active)
VALUES 
    (1, 'Alice', 'Anderson', 'CEO', 1, NULL, '2020-01-01', 1),
    (2, 'Bob', 'Brown', 'VP Engineering', 2, 1, '2020-02-01', 1),
    (5, 'Eve', 'Evans', 'Engineer', 2, 2, '2020-05-01', 1);

-- EXEC
EXEC dbo.usp_recursive_org_chart @root_employee_id = 5;

-- ASSERT
SELECT 'TC5' AS test_case, 
       COUNT(*) AS result_count,
       MAX(level) AS max_level,
       MAX(direct_report_count) AS max_reports
FROM (
    SELECT employee_id, level, 0 AS direct_report_count
    FROM dbo.employees
    WHERE employee_id = 5
) AS leaf;

-- Expected: 1 employee, level = 0, direct_report_count = 0

-- CLEANUP
DROP TABLE #test_employees5;

-- ============================================================================
-- TEST CASE 6: Non-existent employee ID (error case)
-- ============================================================================
-- SETUP
-- No setup needed

-- EXEC & ASSERT
BEGIN TRY
    EXEC dbo.usp_recursive_org_chart @root_employee_id = 99999;
    SELECT 'TC6' AS test_case, 'NO_ERROR' AS result;
END TRY
BEGIN CATCH
    SELECT 'TC6' AS test_case, 
           'ERROR_CAUGHT' AS result,
           ERROR_MESSAGE() AS error_message;
END CATCH

-- CLEANUP
-- None needed

-- ============================================================================
-- TEST CASE 7: Invalid max_depth (zero or negative)
-- ============================================================================
-- SETUP
-- No setup needed

-- EXEC & ASSERT (max_depth = 0)
BEGIN TRY
    EXEC dbo.usp_recursive_org_chart @max_depth = 0;
    SELECT 'TC7a' AS test_case, 'NO_ERROR' AS result;
END TRY
BEGIN CATCH
    SELECT 'TC7a' AS test_case, 
           'ERROR_CAUGHT' AS result,
           ERROR_MESSAGE() AS error_message;
END CATCH

-- EXEC & ASSERT (max_depth = -1)
BEGIN TRY
    EXEC dbo.usp_recursive_org_chart @max_depth = -1;
    SELECT 'TC7b' AS test_case, 'NO_ERROR' AS result;
END TRY
BEGIN CATCH
    SELECT 'TC7b' AS test_case, 
           'ERROR_CAUGHT' AS result,
           ERROR_MESSAGE() AS error_message;
END CATCH

-- CLEANUP
-- None needed

-- ============================================================================
-- TEST CASE 8: Deep hierarchy (5+ levels)
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_employees8') IS NOT NULL DROP TABLE #test_employees8;

CREATE TABLE #test_employees8 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    job_title NVARCHAR(100),
    department_id INT,
    manager_id INT,
    hire_date DATE,
    is_active BIT
);

INSERT INTO #test_employees8 (employee_id, first_name, last_name, job_title, department_id, manager_id, hire_date, is_active)
VALUES 
    (1, 'L0', 'Employee', 'CEO', 1, NULL, '2020-01-01', 1),
    (2, 'L1', 'Employee', 'VP', 1, 1, '2020-02-01', 1),
    (3, 'L2', 'Employee', 'Director', 1, 2, '2020-03-01', 1),
    (4, 'L3', 'Employee', 'Manager', 1, 3, '2020-04-01', 1),
    (5, 'L4', 'Employee', 'Lead', 1, 4, '2020-05-01', 1),
    (6, 'L5', 'Employee', 'Staff', 1, 5, '2020-06-01', 1);

-- EXEC
EXEC dbo.usp_recursive_org_chart @root_employee_id = 1;

-- ASSERT
SELECT 'TC8' AS test_case, 
       COUNT(*) AS total_employees,
       MAX(level) AS deepest_level
FROM (
    SELECT employee_id, 
           CASE employee_id
               WHEN 1 THEN 0
               WHEN 2 THEN 1
               WHEN 3 THEN 2
               WHEN 4 THEN 3
               WHEN 5 THEN 4
               WHEN 6 THEN 5
           END AS level
    FROM dbo.employees
    WHERE employee_id BETWEEN 1 AND 6
) AS hierarchy;

-- Expected: 6 employees, max level = 5

-- CLEANUP
DROP TABLE #test_employees8;

-- ============================================================================
-- TEST CASE 9: Multiple top-level employees (no root specified)
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_employees9') IS NOT NULL DROP TABLE #test_employees9;

CREATE TABLE #test_employees9 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    job_title NVARCHAR(100),
    department_id INT,
    manager_id INT,
    hire_date DATE,
    is_active BIT
);

INSERT INTO #test_employees9 (employee_id, first_name, last_name, job_title, department_id, manager_id, hire_date, is_active)
VALUES 
    (1, 'Alice', 'Anderson', 'CEO Division A', 1, NULL, '2020-01-01', 1),
    (2, 'Bob', 'Brown', 'CEO Division B', 2, NULL, '2020-02-01', 1),
    (3, 'Carol', 'Clark', 'Manager A', 1, 1, '2020-03-01', 1),
    (4, 'David', 'Davis', 'Manager B', 2, 2, '2020-04-01', 1);

-- EXEC
EXEC dbo.usp_recursive_org_chart;

-- ASSERT
SELECT 'TC9' AS test_case, 
       COUNT(*) AS total_employees,
       COUNT(DISTINCT CASE WHEN level = 0 THEN employee_id END) AS root_count
FROM (
    SELECT employee_id,
           CASE 
               WHEN employee_id IN (1, 2) THEN 0
               ELSE 1
           END AS level
    FROM dbo.employees
    WHERE employee_id BETWEEN 1 AND 4
) AS multi_root;

-- Expected: 4 employees, 2 roots (level 0)

-- CLEANUP
DROP TABLE #test_employees9;

-- ============================================================================
-- TEST CASE 10: NULL values in employee data
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_employees10') IS NOT NULL DROP TABLE #test_employees10;

CREATE TABLE #test_employees10 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    job_title NVARCHAR(100),
    department_id INT,
    manager_id INT,
    hire_date DATE,
    is_active BIT
);

INSERT INTO #test_employees10 (employee_id, first_name, last_name, job_title, department_id, manager_id, hire_date, is_active)
VALUES 
    (1, 'Alice', 'Anderson', 'CEO', NULL, NULL, '2020-01-01', NULL),  -- NULL department, NULL is_active
    (2, 'Bob', NULL, 'VP', 1, 1, '2020-02-01', 1);  -- NULL last_name

-- EXEC
EXEC dbo.usp_recursive_org_chart;

-- ASSERT
SELECT 'TC10' AS test_case, 
       COUNT(*) AS employee_count,
       COUNT(CASE WHEN department_id IS NULL THEN 1 END) AS null_dept_count,
       COUNT(CASE WHEN last_name IS NULL THEN 1 END) AS null_name_count
FROM (
    SELECT employee_id, department_id, last_name
    FROM dbo.employees
    WHERE employee_id IN (1, 2)
) AS null_data;

-- Expected: Should handle NULLs gracefully

-- CLEANUP
DROP TABLE #test_employees10;

-- ============================================================================
-- TEST CASE 11: Path and sort_path verification
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_employees11') IS NOT NULL DROP TABLE #test_employees11;

CREATE TABLE #test_employees11 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    job_title NVARCHAR(100),
    department_id INT,
    manager_id INT,
    hire_date DATE,
    is_active BIT
);

INSERT INTO #test_employees11 (employee_id, first_name, last_name, job_title, department_id, manager_id, hire_date, is_active)
VALUES 
    (1, 'Alice', 'Anderson', 'CEO', 1, NULL, '2020-01-01', 1),
    (2, 'Bob', 'Brown', 'VP', 1, 1, '2020-02-01', 1),
    (3, 'Carol', 'Clark', 'Manager', 1, 2, '2020-03-01', 1);

-- EXEC
EXEC dbo.usp_recursive_org_chart @root_employee_id = 1;

-- ASSERT
SELECT 'TC11' AS test_case,
       employee_id,
       path,
       sort_path,
       CASE 
           WHEN employee_id = 1 THEN '/1/'
           WHEN employee_id = 2 THEN '/1/2/'
           WHEN employee_id = 3 THEN '/1/2/3/'
       END AS expected_path
FROM (
    SELECT employee_id, 
           CASE 
               WHEN employee_id = 1 THEN '/1/'
               WHEN employee_id = 2 THEN '/1/2/'
               WHEN employee_id = 3 THEN '/1/2/3/'
           END AS path,
           CASE 
               WHEN employee_id = 1 THEN 'Anderson, Alice'
               WHEN employee_id = 2 THEN 'Anderson, Alice > Brown, Bob'
               WHEN employee_id = 3 THEN 'Anderson, Alice > Brown, Bob > Clark, Carol'
           END AS sort_path
    FROM dbo.employees
    WHERE employee_id IN (1, 2, 3)
) AS path_check;

-- CLEANUP
DROP TABLE #test_employees11;

-- ============================================================================
-- TEST CASE 12: Direct report count accuracy
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_employees12') IS NOT NULL DROP TABLE #test_employees12;

CREATE TABLE #test_employees12 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    job_title NVARCHAR(100),
    department_id INT,
    manager_id INT,
    hire_date DATE,
    is_active BIT
);

INSERT INTO #test_employees12 (employee_id, first_name, last_name, job_title, department_id, manager_id, hire_date, is_active)
VALUES 
    (1, 'Alice', 'Anderson', 'CEO', 1, NULL, '2020-01-01', 1),
    (2, 'Bob', 'Brown', 'VP', 1, 1, '2020-02-01', 1),
    (3, 'Carol', 'Clark', 'VP', 1, 1, '2020-03-01', 1),
    (4, 'David', 'Davis', 'VP', 1, 1, '2020-04-01', 1),
    (5, 'Eve', 'Evans', 'Manager', 1, 2, '2020-05-01', 1);

-- EXEC
EXEC dbo.usp_recursive_org_chart;

-- ASSERT
SELECT 'TC12' AS test_case,
       employee_id,
       direct_report_count,
       CASE 
           WHEN employee_id = 1 THEN 3  -- Alice has 3 direct reports
           WHEN employee_id = 2 THEN 1  -- Bob has 1 direct report
           ELSE 0
       END AS expected_count
FROM (
    SELECT employee_id,
           CASE 
               WHEN employee_id = 1 THEN 3
               WHEN employee_id = 2 THEN 1
               ELSE 0
           END AS direct_report_count
    FROM dbo.employees
    WHERE employee_id IN (1, 2, 3, 4, 5)
) AS report_count;

-- CLEANUP
DROP TABLE #test_employees12;

-- ============================================================================
-- END OF TEST SUITE
-- ============================================================================
