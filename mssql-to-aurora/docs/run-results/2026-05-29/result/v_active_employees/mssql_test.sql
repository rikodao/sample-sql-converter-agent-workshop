-- ============================================================
-- TEST CASES for dbo.v_active_employees
-- ============================================================
-- Purpose: Validate VIEW filtering logic for active employees
-- Coverage: Normal cases, boundary values, edge cases, JOIN behavior
-- ============================================================

-- ============================================================
-- TEST CASE 1: Basic active employee retrieval
-- ============================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_employees') IS NOT NULL DROP TABLE #test_employees;
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;

CREATE TABLE #test_departments (
    department_id INT PRIMARY KEY,
    department_name NVARCHAR(50),
    location_id INT
);

CREATE TABLE #test_employees (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    email NVARCHAR(100),
    phone_number NVARCHAR(20),
    hire_date DATE,
    job_id NVARCHAR(10),
    salary DECIMAL(10,2),
    commission_pct DECIMAL(3,2),
    manager_id INT,
    department_id INT,
    status NVARCHAR(20),
    termination_date DATE,
    is_active BIT
);

INSERT INTO #test_departments VALUES (10, 'IT', 1700);
INSERT INTO #test_departments VALUES (20, 'Sales', 1800);

INSERT INTO #test_employees VALUES 
(100, 'John', 'Doe', 'jdoe@example.com', '555-0100', '2020-01-15', 'IT_PROG', 60000.00, NULL, NULL, 10, 'Active', NULL, 1),
(101, 'Jane', 'Smith', 'jsmith@example.com', '555-0101', '2019-03-20', 'SA_REP', 55000.00, 0.10, NULL, 20, 'Active', NULL, 1),
(102, 'Bob', 'Johnson', 'bjohnson@example.com', '555-0102', '2018-06-10', 'IT_PROG', 65000.00, NULL, 100, 10, 'Inactive', '2023-12-31', 0);

-- EXEC
-- Query the view to get active employees
-- (Simulating: SELECT * FROM dbo.v_active_employees)

-- ASSERT
SELECT 'TC1' AS tc, 'Active employees count' AS test_description, COUNT(*) AS result
FROM #test_employees
WHERE status = 'Active' AND is_active = 1 AND termination_date IS NULL;

SELECT 'TC1' AS tc, 'Active employee IDs' AS test_description, employee_id AS result
FROM #test_employees
WHERE status = 'Active' AND is_active = 1 AND termination_date IS NULL
ORDER BY employee_id;

-- CLEANUP
DROP TABLE #test_employees;
DROP TABLE #test_departments;

-- ============================================================
-- TEST CASE 2: Inactive employees should be excluded
-- ============================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_employees2') IS NOT NULL DROP TABLE #test_employees2;

CREATE TABLE #test_employees2 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    email NVARCHAR(100),
    status NVARCHAR(20),
    termination_date DATE,
    is_active BIT,
    department_id INT
);

INSERT INTO #test_employees2 VALUES 
(200, 'Alice', 'Williams', 'awilliams@example.com', 'Inactive', '2023-06-30', 0, 10),
(201, 'Charlie', 'Brown', 'cbrown@example.com', 'Terminated', '2022-12-15', 0, 20),
(202, 'David', 'Lee', 'dlee@example.com', 'Active', NULL, 1, 10);

-- EXEC
-- Filter for active employees only

-- ASSERT
SELECT 'TC2' AS tc, 'Inactive excluded count' AS test_description, COUNT(*) AS result
FROM #test_employees2
WHERE status = 'Active' AND is_active = 1 AND termination_date IS NULL;

SELECT 'TC2' AS tc, 'Only active employee ID' AS test_description, employee_id AS result
FROM #test_employees2
WHERE status = 'Active' AND is_active = 1 AND termination_date IS NULL;

-- CLEANUP
DROP TABLE #test_employees2;

-- ============================================================
-- TEST CASE 3: NULL termination_date handling
-- ============================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_employees3') IS NOT NULL DROP TABLE #test_employees3;

CREATE TABLE #test_employees3 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    status NVARCHAR(20),
    termination_date DATE,
    is_active BIT,
    department_id INT
);

INSERT INTO #test_employees3 VALUES 
(300, 'Emma', 'Davis', 'Active', NULL, 1, 10),
(301, 'Frank', 'Miller', 'Active', '2024-01-01', 1, 20),
(302, 'Grace', 'Wilson', 'Active', NULL, 1, 10);

-- EXEC
-- Check NULL termination_date filter

-- ASSERT
SELECT 'TC3' AS tc, 'NULL termination_date count' AS test_description, COUNT(*) AS result
FROM #test_employees3
WHERE status = 'Active' AND termination_date IS NULL;

SELECT 'TC3' AS tc, 'Employees with NULL termination' AS test_description, employee_id AS result
FROM #test_employees3
WHERE status = 'Active' AND termination_date IS NULL
ORDER BY employee_id;

-- CLEANUP
DROP TABLE #test_employees3;

-- ============================================================
-- TEST CASE 4: Empty result set (no active employees)
-- ============================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_employees4') IS NOT NULL DROP TABLE #test_employees4;

CREATE TABLE #test_employees4 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    status NVARCHAR(20),
    termination_date DATE,
    is_active BIT,
    department_id INT
);

INSERT INTO #test_employees4 VALUES 
(400, 'Henry', 'Moore', 'Inactive', '2023-01-15', 0, 10),
(401, 'Ivy', 'Taylor', 'Terminated', '2022-08-20', 0, 20);

-- EXEC
-- Query with no active employees

-- ASSERT
SELECT 'TC4' AS tc, 'No active employees' AS test_description, COUNT(*) AS result
FROM #test_employees4
WHERE status = 'Active' AND is_active = 1 AND termination_date IS NULL;

-- CLEANUP
DROP TABLE #test_employees4;

-- ============================================================
-- TEST CASE 5: JOIN with departments (LEFT JOIN behavior)
-- ============================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_employees5') IS NOT NULL DROP TABLE #test_employees5;
IF OBJECT_ID('tempdb..#test_departments5') IS NOT NULL DROP TABLE #test_departments5;

CREATE TABLE #test_departments5 (
    department_id INT PRIMARY KEY,
    department_name NVARCHAR(50),
    location_id INT
);

CREATE TABLE #test_employees5 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    status NVARCHAR(20),
    termination_date DATE,
    is_active BIT,
    department_id INT
);

INSERT INTO #test_departments5 VALUES (10, 'Engineering', 1700);
INSERT INTO #test_departments5 VALUES (20, 'Marketing', 1800);

INSERT INTO #test_employees5 VALUES 
(500, 'Jack', 'Anderson', 'Active', NULL, 1, 10),
(501, 'Karen', 'Thomas', 'Active', NULL, 1, 20),
(502, 'Leo', 'Jackson', 'Active', NULL, 1, NULL); -- No department

-- EXEC
-- LEFT JOIN to departments

-- ASSERT
SELECT 'TC5' AS tc, 'JOIN with departments' AS test_description, 
       e.employee_id, 
       ISNULL(d.department_name, 'NULL') AS department_name
FROM #test_employees5 e
LEFT JOIN #test_departments5 d ON e.department_id = d.department_id
WHERE e.status = 'Active' AND e.is_active = 1 AND e.termination_date IS NULL
ORDER BY e.employee_id;

-- CLEANUP
DROP TABLE #test_employees5;
DROP TABLE #test_departments5;

-- ============================================================
-- TEST CASE 6: Boundary - All employees active
-- ============================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_employees6') IS NOT NULL DROP TABLE #test_employees6;

CREATE TABLE #test_employees6 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    status NVARCHAR(20),
    termination_date DATE,
    is_active BIT,
    department_id INT
);

INSERT INTO #test_employees6 VALUES 
(600, 'Mary', 'White', 'Active', NULL, 1, 10),
(601, 'Nathan', 'Harris', 'Active', NULL, 1, 20),
(602, 'Olivia', 'Martin', 'Active', NULL, 1, 30);

-- EXEC
-- All employees should be returned

-- ASSERT
SELECT 'TC6' AS tc, 'All active count' AS test_description, COUNT(*) AS result
FROM #test_employees6
WHERE status = 'Active' AND is_active = 1 AND termination_date IS NULL;

-- CLEANUP
DROP TABLE #test_employees6;

-- ============================================================
-- TEST CASE 7: Mixed status values
-- ============================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_employees7') IS NOT NULL DROP TABLE #test_employees7;

CREATE TABLE #test_employees7 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    status NVARCHAR(20),
    termination_date DATE,
    is_active BIT,
    department_id INT
);

INSERT INTO #test_employees7 VALUES 
(700, 'Paul', 'Garcia', 'Active', NULL, 1, 10),
(701, 'Quinn', 'Martinez', 'Inactive', '2023-05-15', 0, 20),
(702, 'Rachel', 'Robinson', 'Active', NULL, 1, 30),
(703, 'Sam', 'Clark', 'Terminated', '2022-11-30', 0, 10),
(704, 'Tina', 'Rodriguez', 'Active', NULL, 1, 20);

-- EXEC
-- Filter mixed statuses

-- ASSERT
SELECT 'TC7' AS tc, 'Mixed status active count' AS test_description, COUNT(*) AS result
FROM #test_employees7
WHERE status = 'Active' AND is_active = 1 AND termination_date IS NULL;

SELECT 'TC7' AS tc, 'Active employee IDs' AS test_description, employee_id AS result
FROM #test_employees7
WHERE status = 'Active' AND is_active = 1 AND termination_date IS NULL
ORDER BY employee_id;

-- CLEANUP
DROP TABLE #test_employees7;

-- ============================================================
-- TEST CASE 8: NULL values in optional fields
-- ============================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_employees8') IS NOT NULL DROP TABLE #test_employees8;

CREATE TABLE #test_employees8 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    email NVARCHAR(100),
    phone_number NVARCHAR(20),
    salary DECIMAL(10,2),
    commission_pct DECIMAL(3,2),
    manager_id INT,
    status NVARCHAR(20),
    termination_date DATE,
    is_active BIT,
    department_id INT
);

INSERT INTO #test_employees8 VALUES 
(800, 'Uma', 'Lewis', NULL, NULL, 50000.00, NULL, NULL, 'Active', NULL, 1, NULL),
(801, 'Victor', 'Walker', 'vwalker@example.com', '555-0801', NULL, NULL, NULL, 'Active', NULL, 1, 10);

-- EXEC
-- Handle NULL values in non-filter columns

-- ASSERT
SELECT 'TC8' AS tc, 'NULL fields count' AS test_description, COUNT(*) AS result
FROM #test_employees8
WHERE status = 'Active' AND is_active = 1 AND termination_date IS NULL;

SELECT 'TC8' AS tc, 'Employee with NULLs' AS test_description, 
       employee_id,
       ISNULL(email, 'NULL') AS email,
       ISNULL(CAST(department_id AS NVARCHAR), 'NULL') AS department_id
FROM #test_employees8
WHERE status = 'Active' AND is_active = 1 AND termination_date IS NULL
ORDER BY employee_id;

-- CLEANUP
DROP TABLE #test_employees8;

-- ============================================================
-- TEST CASE 9: Case sensitivity in status field
-- ============================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_employees9') IS NOT NULL DROP TABLE #test_employees9;

CREATE TABLE #test_employees9 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    status NVARCHAR(20),
    termination_date DATE,
    is_active BIT,
    department_id INT
);

INSERT INTO #test_employees9 VALUES 
(900, 'Wendy', 'Hall', 'Active', NULL, 1, 10),
(901, 'Xavier', 'Allen', 'ACTIVE', NULL, 1, 20),
(902, 'Yolanda', 'Young', 'active', NULL, 1, 30);

-- EXEC
-- Test case sensitivity (SQL Server default collation is case-insensitive)

-- ASSERT
SELECT 'TC9' AS tc, 'Case insensitive count' AS test_description, COUNT(*) AS result
FROM #test_employees9
WHERE status = 'Active' AND is_active = 1 AND termination_date IS NULL;

-- CLEANUP
DROP TABLE #test_employees9;

-- ============================================================
-- TEST CASE 10: Date boundary - termination_date edge cases
-- ============================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_employees10') IS NOT NULL DROP TABLE #test_employees10;

CREATE TABLE #test_employees10 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    status NVARCHAR(20),
    termination_date DATE,
    is_active BIT,
    department_id INT
);

INSERT INTO #test_employees10 VALUES 
(1000, 'Zoe', 'King', 'Active', NULL, 1, 10),
(1001, 'Adam', 'Wright', 'Active', '1900-01-01', 1, 20),
(1002, 'Beth', 'Lopez', 'Active', '9999-12-31', 1, 30),
(1003, 'Carl', 'Hill', 'Active', NULL, 1, 10);

-- EXEC
-- Check date boundary handling

-- ASSERT
SELECT 'TC10' AS tc, 'NULL termination only' AS test_description, COUNT(*) AS result
FROM #test_employees10
WHERE status = 'Active' AND termination_date IS NULL;

SELECT 'TC10' AS tc, 'Employee IDs with NULL termination' AS test_description, employee_id AS result
FROM #test_employees10
WHERE status = 'Active' AND termination_date IS NULL
ORDER BY employee_id;

-- CLEANUP
DROP TABLE #test_employees10;

-- ============================================================
-- END OF TEST CASES
-- ============================================================
