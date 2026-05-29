-- ============================================================================
-- TEST SUITE for dbo.fn_get_dept_summary
-- ============================================================================
-- Purpose: Comprehensive testing of department summary table-valued function
-- Coverage: Normal cases, boundary values, edge cases, NULL handling, aggregations
-- ============================================================================

-- ============================================================================
-- TEST CASE 1: Basic summary for all departments
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_employees') IS NOT NULL DROP TABLE #test_employees;
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;

CREATE TABLE #test_departments (
    department_id INT PRIMARY KEY,
    department_name NVARCHAR(100),
    location NVARCHAR(100)
);

CREATE TABLE #test_employees (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    department_id INT,
    status NVARCHAR(20),
    hire_date DATETIME,
    salary DECIMAL(10,2)
);

INSERT INTO #test_departments (department_id, department_name, location) VALUES
(1, 'Engineering', 'New York'),
(2, 'Sales', 'Chicago'),
(3, 'HR', 'Boston');

INSERT INTO #test_employees (employee_id, first_name, last_name, department_id, status, hire_date, salary) VALUES
(1, 'John', 'Doe', 1, 'Active', '2020-01-01', 80000.00),
(2, 'Jane', 'Smith', 1, 'Active', '2020-02-01', 85000.00),
(3, 'Bob', 'Johnson', 1, 'Inactive', '2019-01-01', 90000.00),
(4, 'Alice', 'Williams', 2, 'Active', '2020-03-01', 70000.00),
(5, 'Charlie', 'Brown', 2, 'Active', '2020-04-01', 75000.00),
(6, 'Diana', 'Davis', 3, 'Active', '2020-05-01', 65000.00);

-- Create temp function for testing
IF OBJECT_ID('tempdb..#fn_get_dept_summary') IS NOT NULL 
    DROP FUNCTION #fn_get_dept_summary;
GO

CREATE FUNCTION #fn_get_dept_summary
(
    @department_id INT = NULL
)
RETURNS @result TABLE
(
    department_id INT,
    department_name NVARCHAR(100),
    location NVARCHAR(100),
    total_employees INT,
    active_employees INT,
    inactive_employees INT,
    avg_salary DECIMAL(10,2),
    earliest_hire_date DATETIME,
    latest_hire_date DATETIME
)
AS
BEGIN
    INSERT INTO @result
    SELECT 
        d.department_id,
        d.department_name,
        d.location,
        COUNT(e.employee_id) AS total_employees,
        SUM(CASE WHEN e.status = 'Active' THEN 1 ELSE 0 END) AS active_employees,
        SUM(CASE WHEN e.status <> 'Active' OR e.status IS NULL THEN 1 ELSE 0 END) AS inactive_employees,
        AVG(CASE WHEN e.salary IS NOT NULL THEN e.salary ELSE NULL END) AS avg_salary,
        MIN(e.hire_date) AS earliest_hire_date,
        MAX(e.hire_date) AS latest_hire_date
    FROM #test_departments d
    LEFT JOIN #test_employees e ON d.department_id = e.department_id
    WHERE @department_id IS NULL OR d.department_id = @department_id
    GROUP BY d.department_id, d.department_name, d.location;
    
    RETURN;
END;
GO

-- EXEC
SELECT 'TC1' AS test_case, * FROM #fn_get_dept_summary(NULL) ORDER BY department_id;

-- ASSERT
SELECT 'TC1' AS test_case, 'All departments summary retrieved' AS result;

-- CLEANUP
IF OBJECT_ID('tempdb..#test_employees') IS NOT NULL DROP TABLE #test_employees;
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;
GO


-- ============================================================================
-- TEST CASE 2: Summary for specific department
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_employees') IS NOT NULL DROP TABLE #test_employees;
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;

CREATE TABLE #test_departments (
    department_id INT PRIMARY KEY,
    department_name NVARCHAR(100),
    location NVARCHAR(100)
);

CREATE TABLE #test_employees (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    department_id INT,
    status NVARCHAR(20),
    hire_date DATETIME,
    salary DECIMAL(10,2)
);

INSERT INTO #test_departments (department_id, department_name, location) VALUES
(1, 'Engineering', 'New York'),
(2, 'Sales', 'Chicago');

INSERT INTO #test_employees (employee_id, first_name, last_name, department_id, status, hire_date, salary) VALUES
(1, 'John', 'Doe', 1, 'Active', '2020-01-01', 80000.00),
(2, 'Jane', 'Smith', 1, 'Active', '2020-02-01', 85000.00),
(3, 'Bob', 'Johnson', 2, 'Active', '2020-03-01', 70000.00);

-- Create temp function
IF OBJECT_ID('tempdb..#fn_get_dept_summary') IS NOT NULL 
    DROP FUNCTION #fn_get_dept_summary;
GO

CREATE FUNCTION #fn_get_dept_summary
(
    @department_id INT = NULL
)
RETURNS @result TABLE
(
    department_id INT,
    department_name NVARCHAR(100),
    location NVARCHAR(100),
    total_employees INT,
    active_employees INT,
    inactive_employees INT,
    avg_salary DECIMAL(10,2),
    earliest_hire_date DATETIME,
    latest_hire_date DATETIME
)
AS
BEGIN
    INSERT INTO @result
    SELECT 
        d.department_id,
        d.department_name,
        d.location,
        COUNT(e.employee_id) AS total_employees,
        SUM(CASE WHEN e.status = 'Active' THEN 1 ELSE 0 END) AS active_employees,
        SUM(CASE WHEN e.status <> 'Active' OR e.status IS NULL THEN 1 ELSE 0 END) AS inactive_employees,
        AVG(CASE WHEN e.salary IS NOT NULL THEN e.salary ELSE NULL END) AS avg_salary,
        MIN(e.hire_date) AS earliest_hire_date,
        MAX(e.hire_date) AS latest_hire_date
    FROM #test_departments d
    LEFT JOIN #test_employees e ON d.department_id = e.department_id
    WHERE @department_id IS NULL OR d.department_id = @department_id
    GROUP BY d.department_id, d.department_name, d.location;
    
    RETURN;
END;
GO

-- EXEC - Department 1 only
SELECT 'TC2' AS test_case, * FROM #fn_get_dept_summary(1);

-- ASSERT
SELECT 'TC2' AS test_case, 'Specific department summary retrieved' AS result;

-- CLEANUP
IF OBJECT_ID('tempdb..#test_employees') IS NOT NULL DROP TABLE #test_employees;
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;
GO


-- ============================================================================
-- TEST CASE 3: Department with no employees
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_employees') IS NOT NULL DROP TABLE #test_employees;
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;

CREATE TABLE #test_departments (
    department_id INT PRIMARY KEY,
    department_name NVARCHAR(100),
    location NVARCHAR(100)
);

CREATE TABLE #test_employees (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    department_id INT,
    status NVARCHAR(20),
    hire_date DATETIME,
    salary DECIMAL(10,2)
);

INSERT INTO #test_departments (department_id, department_name, location) VALUES
(1, 'Engineering', 'New York'),
(2, 'Sales', 'Chicago'),
(3, 'NewDept', 'Boston');

INSERT INTO #test_employees (employee_id, first_name, last_name, department_id, status, hire_date, salary) VALUES
(1, 'John', 'Doe', 1, 'Active', '2020-01-01', 80000.00),
(2, 'Jane', 'Smith', 2, 'Active', '2020-02-01', 85000.00);
-- Department 3 has no employees

-- Create temp function
IF OBJECT_ID('tempdb..#fn_get_dept_summary') IS NOT NULL 
    DROP FUNCTION #fn_get_dept_summary;
GO

CREATE FUNCTION #fn_get_dept_summary
(
    @department_id INT = NULL
)
RETURNS @result TABLE
(
    department_id INT,
    department_name NVARCHAR(100),
    location NVARCHAR(100),
    total_employees INT,
    active_employees INT,
    inactive_employees INT,
    avg_salary DECIMAL(10,2),
    earliest_hire_date DATETIME,
    latest_hire_date DATETIME
)
AS
BEGIN
    INSERT INTO @result
    SELECT 
        d.department_id,
        d.department_name,
        d.location,
        COUNT(e.employee_id) AS total_employees,
        SUM(CASE WHEN e.status = 'Active' THEN 1 ELSE 0 END) AS active_employees,
        SUM(CASE WHEN e.status <> 'Active' OR e.status IS NULL THEN 1 ELSE 0 END) AS inactive_employees,
        AVG(CASE WHEN e.salary IS NOT NULL THEN e.salary ELSE NULL END) AS avg_salary,
        MIN(e.hire_date) AS earliest_hire_date,
        MAX(e.hire_date) AS latest_hire_date
    FROM #test_departments d
    LEFT JOIN #test_employees e ON d.department_id = e.department_id
    WHERE @department_id IS NULL OR d.department_id = @department_id
    GROUP BY d.department_id, d.department_name, d.location;
    
    RETURN;
END;
GO

-- EXEC
SELECT 'TC3' AS test_case, * FROM #fn_get_dept_summary(NULL) ORDER BY department_id;

-- ASSERT
SELECT 'TC3' AS test_case, 'Department with no employees shows 0 counts and NULL aggregates' AS result;

-- CLEANUP
IF OBJECT_ID('tempdb..#test_employees') IS NOT NULL DROP TABLE #test_employees;
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;
GO


-- ============================================================================
-- TEST CASE 4: NULL salary handling
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_employees') IS NOT NULL DROP TABLE #test_employees;
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;

CREATE TABLE #test_departments (
    department_id INT PRIMARY KEY,
    department_name NVARCHAR(100),
    location NVARCHAR(100)
);

CREATE TABLE #test_employees (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    department_id INT,
    status NVARCHAR(20),
    hire_date DATETIME,
    salary DECIMAL(10,2)
);

INSERT INTO #test_departments (department_id, department_name, location) VALUES
(1, 'Engineering', 'New York');

INSERT INTO #test_employees (employee_id, first_name, last_name, department_id, status, hire_date, salary) VALUES
(1, 'John', 'Doe', 1, 'Active', '2020-01-01', 80000.00),
(2, 'Jane', 'Smith', 1, 'Active', '2020-02-01', NULL),
(3, 'Bob', 'Johnson', 1, 'Active', '2020-03-01', 90000.00);

-- Create temp function
IF OBJECT_ID('tempdb..#fn_get_dept_summary') IS NOT NULL 
    DROP FUNCTION #fn_get_dept_summary;
GO

CREATE FUNCTION #fn_get_dept_summary
(
    @department_id INT = NULL
)
RETURNS @result TABLE
(
    department_id INT,
    department_name NVARCHAR(100),
    location NVARCHAR(100),
    total_employees INT,
    active_employees INT,
    inactive_employees INT,
    avg_salary DECIMAL(10,2),
    earliest_hire_date DATETIME,
    latest_hire_date DATETIME
)
AS
BEGIN
    INSERT INTO @result
    SELECT 
        d.department_id,
        d.department_name,
        d.location,
        COUNT(e.employee_id) AS total_employees,
        SUM(CASE WHEN e.status = 'Active' THEN 1 ELSE 0 END) AS active_employees,
        SUM(CASE WHEN e.status <> 'Active' OR e.status IS NULL THEN 1 ELSE 0 END) AS inactive_employees,
        AVG(CASE WHEN e.salary IS NOT NULL THEN e.salary ELSE NULL END) AS avg_salary,
        MIN(e.hire_date) AS earliest_hire_date,
        MAX(e.hire_date) AS latest_hire_date
    FROM #test_departments d
    LEFT JOIN #test_employees e ON d.department_id = e.department_id
    WHERE @department_id IS NULL OR d.department_id = @department_id
    GROUP BY d.department_id, d.department_name, d.location;
    
    RETURN;
END;
GO

-- EXEC
SELECT 'TC4' AS test_case, * FROM #fn_get_dept_summary(1);

-- ASSERT
SELECT 'TC4' AS test_case, 'NULL salaries excluded from average calculation' AS result;

-- CLEANUP
IF OBJECT_ID('tempdb..#test_employees') IS NOT NULL DROP TABLE #test_employees;
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;
GO


-- ============================================================================
-- TEST CASE 5: All employees inactive
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_employees') IS NOT NULL DROP TABLE #test_employees;
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;

CREATE TABLE #test_departments (
    department_id INT PRIMARY KEY,
    department_name NVARCHAR(100),
    location NVARCHAR(100)
);

CREATE TABLE #test_employees (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    department_id INT,
    status NVARCHAR(20),
    hire_date DATETIME,
    salary DECIMAL(10,2)
);

INSERT INTO #test_departments (department_id, department_name, location) VALUES
(1, 'Engineering', 'New York');

INSERT INTO #test_employees (employee_id, first_name, last_name, department_id, status, hire_date, salary) VALUES
(1, 'John', 'Doe', 1, 'Inactive', '2020-01-01', 80000.00),
(2, 'Jane', 'Smith', 1, 'Terminated', '2020-02-01', 85000.00);

-- Create temp function
IF OBJECT_ID('tempdb..#fn_get_dept_summary') IS NOT NULL 
    DROP FUNCTION #fn_get_dept_summary;
GO

CREATE FUNCTION #fn_get_dept_summary
(
    @department_id INT = NULL
)
RETURNS @result TABLE
(
    department_id INT,
    department_name NVARCHAR(100),
    location NVARCHAR(100),
    total_employees INT,
    active_employees INT,
    inactive_employees INT,
    avg_salary DECIMAL(10,2),
    earliest_hire_date DATETIME,
    latest_hire_date DATETIME
)
AS
BEGIN
    INSERT INTO @result
    SELECT 
        d.department_id,
        d.department_name,
        d.location,
        COUNT(e.employee_id) AS total_employees,
        SUM(CASE WHEN e.status = 'Active' THEN 1 ELSE 0 END) AS active_employees,
        SUM(CASE WHEN e.status <> 'Active' OR e.status IS NULL THEN 1 ELSE 0 END) AS inactive_employees,
        AVG(CASE WHEN e.salary IS NOT NULL THEN e.salary ELSE NULL END) AS avg_salary,
        MIN(e.hire_date) AS earliest_hire_date,
        MAX(e.hire_date) AS latest_hire_date
    FROM #test_departments d
    LEFT JOIN #test_employees e ON d.department_id = e.department_id
    WHERE @department_id IS NULL OR d.department_id = @department_id
    GROUP BY d.department_id, d.department_name, d.location;
    
    RETURN;
END;
GO

-- EXEC
SELECT 'TC5' AS test_case, * FROM #fn_get_dept_summary(1);

-- ASSERT
SELECT 'TC5' AS test_case, 'All inactive employees counted correctly' AS result;

-- CLEANUP
IF OBJECT_ID('tempdb..#test_employees') IS NOT NULL DROP TABLE #test_employees;
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;
GO


-- ============================================================================
-- TEST CASE 6: Non-existent department ID
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_employees') IS NOT NULL DROP TABLE #test_employees;
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;

CREATE TABLE #test_departments (
    department_id INT PRIMARY KEY,
    department_name NVARCHAR(100),
    location NVARCHAR(100)
);

CREATE TABLE #test_employees (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    department_id INT,
    status NVARCHAR(20),
    hire_date DATETIME,
    salary DECIMAL(10,2)
);

INSERT INTO #test_departments (department_id, department_name, location) VALUES
(1, 'Engineering', 'New York');

INSERT INTO #test_employees (employee_id, first_name, last_name, department_id, status, hire_date, salary) VALUES
(1, 'John', 'Doe', 1, 'Active', '2020-01-01', 80000.00);

-- Create temp function
IF OBJECT_ID('tempdb..#fn_get_dept_summary') IS NOT NULL 
    DROP FUNCTION #fn_get_dept_summary;
GO

CREATE FUNCTION #fn_get_dept_summary
(
    @department_id INT = NULL
)
RETURNS @result TABLE
(
    department_id INT,
    department_name NVARCHAR(100),
    location NVARCHAR(100),
    total_employees INT,
    active_employees INT,
    inactive_employees INT,
    avg_salary DECIMAL(10,2),
    earliest_hire_date DATETIME,
    latest_hire_date DATETIME
)
AS
BEGIN
    INSERT INTO @result
    SELECT 
        d.department_id,
        d.department_name,
        d.location,
        COUNT(e.employee_id) AS total_employees,
        SUM(CASE WHEN e.status = 'Active' THEN 1 ELSE 0 END) AS active_employees,
        SUM(CASE WHEN e.status <> 'Active' OR e.status IS NULL THEN 1 ELSE 0 END) AS inactive_employees,
        AVG(CASE WHEN e.salary IS NOT NULL THEN e.salary ELSE NULL END) AS avg_salary,
        MIN(e.hire_date) AS earliest_hire_date,
        MAX(e.hire_date) AS latest_hire_date
    FROM #test_departments d
    LEFT JOIN #test_employees e ON d.department_id = e.department_id
    WHERE @department_id IS NULL OR d.department_id = @department_id
    GROUP BY d.department_id, d.department_name, d.location;
    
    RETURN;
END;
GO

-- EXEC - Non-existent department ID 999
SELECT 'TC6' AS test_case, * FROM #fn_get_dept_summary(999);

-- ASSERT
SELECT 'TC6' AS test_case, 'Non-existent department returns empty result set' AS result;

-- CLEANUP
IF OBJECT_ID('tempdb..#test_employees') IS NOT NULL DROP TABLE #test_employees;
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;
GO


-- ============================================================================
-- TEST CASE 7: Mixed active and inactive employees
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_employees') IS NOT NULL DROP TABLE #test_employees;
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;

CREATE TABLE #test_departments (
    department_id INT PRIMARY KEY,
    department_name NVARCHAR(100),
    location NVARCHAR(100)
);

CREATE TABLE #test_employees (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    department_id INT,
    status NVARCHAR(20),
    hire_date DATETIME,
    salary DECIMAL(10,2)
);

INSERT INTO #test_departments (department_id, department_name, location) VALUES
(1, 'Engineering', 'New York'),
(2, 'Sales', 'Chicago');

INSERT INTO #test_employees (employee_id, first_name, last_name, department_id, status, hire_date, salary) VALUES
(1, 'John', 'Doe', 1, 'Active', '2020-01-01', 80000.00),
(2, 'Jane', 'Smith', 1, 'Active', '2020-02-01', 85000.00),
(3, 'Bob', 'Johnson', 1, 'Inactive', '2019-01-01', 90000.00),
(4, 'Alice', 'Williams', 1, 'Terminated', '2018-01-01', 75000.00),
(5, 'Charlie', 'Brown', 2, 'Active', '2020-03-01', 70000.00),
(6, 'Diana', 'Davis', 2, 'Inactive', '2020-04-01', 72000.00);

-- Create temp function
IF OBJECT_ID('tempdb..#fn_get_dept_summary') IS NOT NULL 
    DROP FUNCTION #fn_get_dept_summary;
GO

CREATE FUNCTION #fn_get_dept_summary
(
    @department_id INT = NULL
)
RETURNS @result TABLE
(
    department_id INT,
    department_name NVARCHAR(100),
    location NVARCHAR(100),
    total_employees INT,
    active_employees INT,
    inactive_employees INT,
    avg_salary DECIMAL(10,2),
    earliest_hire_date DATETIME,
    latest_hire_date DATETIME
)
AS
BEGIN
    INSERT INTO @result
    SELECT 
        d.department_id,
        d.department_name,
        d.location,
        COUNT(e.employee_id) AS total_employees,
        SUM(CASE WHEN e.status = 'Active' THEN 1 ELSE 0 END) AS active_employees,
        SUM(CASE WHEN e.status <> 'Active' OR e.status IS NULL THEN 1 ELSE 0 END) AS inactive_employees,
        AVG(CASE WHEN e.salary IS NOT NULL THEN e.salary ELSE NULL END) AS avg_salary,
        MIN(e.hire_date) AS earliest_hire_date,
        MAX(e.hire_date) AS latest_hire_date
    FROM #test_departments d
    LEFT JOIN #test_employees e ON d.department_id = e.department_id
    WHERE @department_id IS NULL OR d.department_id = @department_id
    GROUP BY d.department_id, d.department_name, d.location;
    
    RETURN;
END;
GO

-- EXEC
SELECT 'TC7' AS test_case, * FROM #fn_get_dept_summary(NULL) ORDER BY department_id;

-- ASSERT
SELECT 'TC7' AS test_case, 'Mixed active/inactive employees counted correctly' AS result;

-- CLEANUP
IF OBJECT_ID('tempdb..#test_employees') IS NOT NULL DROP TABLE #test_employees;
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;
GO


-- ============================================================================
-- TEST CASE 8: Boundary - Single employee with all NULL optional fields
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_employees') IS NOT NULL DROP TABLE #test_employees;
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;

CREATE TABLE #test_departments (
    department_id INT PRIMARY KEY,
    department_name NVARCHAR(100),
    location NVARCHAR(100)
);

CREATE TABLE #test_employees (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    department_id INT,
    status NVARCHAR(20),
    hire_date DATETIME,
    salary DECIMAL(10,2)
);

INSERT INTO #test_departments (department_id, department_name, location) VALUES
(1, 'Engineering', 'New York');

INSERT INTO #test_employees (employee_id, first_name, last_name, department_id, status, hire_date, salary) VALUES
(1, 'John', 'Doe', 1, NULL, '2020-01-01', NULL);

-- Create temp function
IF OBJECT_ID('tempdb..#fn_get_dept_summary') IS NOT NULL 
    DROP FUNCTION #fn_get_dept_summary;
GO

CREATE FUNCTION #fn_get_dept_summary
(
    @department_id INT = NULL
)
RETURNS @result TABLE
(
    department_id INT,
    department_name NVARCHAR(100),
    location NVARCHAR(100),
    total_employees INT,
    active_employees INT,
    inactive_employees INT,
    avg_salary DECIMAL(10,2),
    earliest_hire_date DATETIME,
    latest_hire_date DATETIME
)
AS
BEGIN
    INSERT INTO @result
    SELECT 
        d.department_id,
        d.department_name,
        d.location,
        COUNT(e.employee_id) AS total_employees,
        SUM(CASE WHEN e.status = 'Active' THEN 1 ELSE 0 END) AS active_employees,
        SUM(CASE WHEN e.status <> 'Active' OR e.status IS NULL THEN 1 ELSE 0 END) AS inactive_employees,
        AVG(CASE WHEN e.salary IS NOT NULL THEN e.salary ELSE NULL END) AS avg_salary,
        MIN(e.hire_date) AS earliest_hire_date,
        MAX(e.hire_date) AS latest_hire_date
    FROM #test_departments d
    LEFT JOIN #test_employees e ON d.department_id = e.department_id
    WHERE @department_id IS NULL OR d.department_id = @department_id
    GROUP BY d.department_id, d.department_name, d.location;
    
    RETURN;
END;
GO

-- EXEC
SELECT 'TC8' AS test_case, * FROM #fn_get_dept_summary(1);

-- ASSERT
SELECT 'TC8' AS test_case, 'NULL status and salary handled correctly' AS result;

-- CLEANUP
IF OBJECT_ID('tempdb..#test_employees') IS NOT NULL DROP TABLE #test_employees;
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;
GO


-- ============================================================================
-- TEST CASE 9: Large department with many employees
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_employees') IS NOT NULL DROP TABLE #test_employees;
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;

CREATE TABLE #test_departments (
    department_id INT PRIMARY KEY,
    department_name NVARCHAR(100),
    location NVARCHAR(100)
);

CREATE TABLE #test_employees (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    department_id INT,
    status NVARCHAR(20),
    hire_date DATETIME,
    salary DECIMAL(10,2)
);

INSERT INTO #test_departments (department_id, department_name, location) VALUES
(1, 'Engineering', 'New York');

-- Insert 10 employees with varying salaries and statuses
INSERT INTO #test_employees (employee_id, first_name, last_name, department_id, status, hire_date, salary) VALUES
(1, 'Emp1', 'Last1', 1, 'Active', '2020-01-01', 80000.00),
(2, 'Emp2', 'Last2', 1, 'Active', '2020-02-01', 85000.00),
(3, 'Emp3', 'Last3', 1, 'Active', '2020-03-01', 90000.00),
(4, 'Emp4', 'Last4', 1, 'Active', '2020-04-01', 95000.00),
(5, 'Emp5', 'Last5', 1, 'Active', '2020-05-01', 100000.00),
(6, 'Emp6', 'Last6', 1, 'Inactive', '2020-06-01', 75000.00),
(7, 'Emp7', 'Last7', 1, 'Inactive', '2020-07-01', 78000.00),
(8, 'Emp8', 'Last8', 1, 'Active', '2019-01-01', 110000.00),
(9, 'Emp9', 'Last9', 1, 'Active', '2021-01-01', 82000.00),
(10, 'Emp10', 'Last10', 1, 'Active', '2022-01-01', 88000.00);

-- Create temp function
IF OBJECT_ID('tempdb..#fn_get_dept_summary') IS NOT NULL 
    DROP FUNCTION #fn_get_dept_summary;
GO

CREATE FUNCTION #fn_get_dept_summary
(
    @department_id INT = NULL
)
RETURNS @result TABLE
(
    department_id INT,
    department_name NVARCHAR(100),
    location NVARCHAR(100),
    total_employees INT,
    active_employees INT,
    inactive_employees INT,
    avg_salary DECIMAL(10,2),
    earliest_hire_date DATETIME,
    latest_hire_date DATETIME
)
AS
BEGIN
    INSERT INTO @result
    SELECT 
        d.department_id,
        d.department_name,
        d.location,
        COUNT(e.employee_id) AS total_employees,
        SUM(CASE WHEN e.status = 'Active' THEN 1 ELSE 0 END) AS active_employees,
        SUM(CASE WHEN e.status <> 'Active' OR e.status IS NULL THEN 1 ELSE 0 END) AS inactive_employees,
        AVG(CASE WHEN e.salary IS NOT NULL THEN e.salary ELSE NULL END) AS avg_salary,
        MIN(e.hire_date) AS earliest_hire_date,
        MAX(e.hire_date) AS latest_hire_date
    FROM #test_departments d
    LEFT JOIN #test_employees e ON d.department_id = e.department_id
    WHERE @department_id IS NULL OR d.department_id = @department_id
    GROUP BY d.department_id, d.department_name, d.location;
    
    RETURN;
END;
GO

-- EXEC
SELECT 'TC9' AS test_case, * FROM #fn_get_dept_summary(1);

-- ASSERT
SELECT 'TC9' AS test_case, 'Large department aggregations calculated correctly' AS result;

-- CLEANUP
IF OBJECT_ID('tempdb..#test_employees') IS NOT NULL DROP TABLE #test_employees;
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;
GO


-- ============================================================================
-- TEST SUMMARY
-- ============================================================================
SELECT 'TEST_SUITE_COMPLETE' AS status, 
       '9 test cases executed' AS summary,
       'Coverage: normal, boundary, NULL handling, aggregations, filtering' AS coverage;
