-- ============================================
-- TEST SUITE: dbo.v_employee_full
-- Description: Comprehensive test cases for employee full view
-- Coverage: Normal cases, boundary values, edge cases, JOIN scenarios
-- ============================================

-- ============= TEST CASE 1: Normal - View returns joined data correctly =============
-- SETUP
CREATE TABLE #test_departments_tc1 (
    department_id INT PRIMARY KEY,
    name NVARCHAR(100) NOT NULL,
    parent_id INT NULL,
    created_at DATETIME2 DEFAULT SYSUTCDATETIME()
);

CREATE TABLE #test_employees_tc1 (
    employee_id INT PRIMARY KEY,
    department_id INT NOT NULL,
    first_name NVARCHAR(50) NOT NULL,
    last_name NVARCHAR(50) NOT NULL,
    hire_date DATE NOT NULL,
    is_active BIT DEFAULT 1,
    email NVARCHAR(100) NULL,
    created_at DATETIME2 DEFAULT SYSUTCDATETIME()
);

INSERT INTO #test_departments_tc1 (department_id, name, parent_id)
VALUES (100, N'Engineering', NULL);

INSERT INTO #test_employees_tc1 (employee_id, department_id, first_name, last_name, hire_date, is_active, email)
VALUES (1000, 100, N'John', N'Doe', '2020-01-15', 1, N'john.doe@example.com');

-- EXEC & ASSERT
SELECT 
    'TC1' AS test_case,
    e.employee_id,
    e.first_name,
    e.last_name,
    e.email,
    e.is_active,
    d.department_id,
    d.name AS department_name
FROM #test_employees_tc1 e
INNER JOIN #test_departments_tc1 d ON e.department_id = d.department_id
ORDER BY e.employee_id;

-- CLEANUP
DROP TABLE #test_employees_tc1;
DROP TABLE #test_departments_tc1;

-- ============= TEST CASE 2: Normal - Multiple employees in same department =============
-- SETUP
CREATE TABLE #test_departments_tc2 (
    department_id INT PRIMARY KEY,
    name NVARCHAR(100) NOT NULL,
    parent_id INT NULL,
    created_at DATETIME2 DEFAULT SYSUTCDATETIME()
);

CREATE TABLE #test_employees_tc2 (
    employee_id INT PRIMARY KEY,
    department_id INT NOT NULL,
    first_name NVARCHAR(50) NOT NULL,
    last_name NVARCHAR(50) NOT NULL,
    hire_date DATE NOT NULL,
    is_active BIT DEFAULT 1,
    email NVARCHAR(100) NULL,
    created_at DATETIME2 DEFAULT SYSUTCDATETIME()
);

INSERT INTO #test_departments_tc2 (department_id, name, parent_id)
VALUES (200, N'Sales', NULL);

INSERT INTO #test_employees_tc2 (employee_id, department_id, first_name, last_name, hire_date, is_active, email)
VALUES 
    (2001, 200, N'Alice', N'Smith', '2019-03-10', 1, N'alice.smith@example.com'),
    (2002, 200, N'Bob', N'Johnson', '2021-06-20', 1, N'bob.johnson@example.com'),
    (2003, 200, N'Carol', N'Williams', '2022-01-05', 0, N'carol.williams@example.com');

-- EXEC & ASSERT
SELECT 
    'TC2' AS test_case,
    COUNT(*) AS employee_count,
    d.department_id,
    d.name AS department_name
FROM #test_employees_tc2 e
INNER JOIN #test_departments_tc2 d ON e.department_id = d.department_id
GROUP BY d.department_id, d.name
ORDER BY d.department_id;

-- CLEANUP
DROP TABLE #test_employees_tc2;
DROP TABLE #test_departments_tc2;

-- ============= TEST CASE 3: Normal - Multiple departments with employees =============
-- SETUP
CREATE TABLE #test_departments_tc3 (
    department_id INT PRIMARY KEY,
    name NVARCHAR(100) NOT NULL,
    parent_id INT NULL,
    created_at DATETIME2 DEFAULT SYSUTCDATETIME()
);

CREATE TABLE #test_employees_tc3 (
    employee_id INT PRIMARY KEY,
    department_id INT NOT NULL,
    first_name NVARCHAR(50) NOT NULL,
    last_name NVARCHAR(50) NOT NULL,
    hire_date DATE NOT NULL,
    is_active BIT DEFAULT 1,
    email NVARCHAR(100) NULL,
    created_at DATETIME2 DEFAULT SYSUTCDATETIME()
);

INSERT INTO #test_departments_tc3 (department_id, name, parent_id)
VALUES 
    (300, N'HR', NULL),
    (301, N'Finance', NULL);

INSERT INTO #test_employees_tc3 (employee_id, department_id, first_name, last_name, hire_date, is_active, email)
VALUES 
    (3001, 300, N'David', N'Brown', '2018-05-15', 1, N'david.brown@example.com'),
    (3002, 301, N'Emma', N'Davis', '2020-09-01', 1, N'emma.davis@example.com');

-- EXEC & ASSERT
SELECT 
    'TC3' AS test_case,
    e.employee_id,
    e.first_name,
    e.last_name,
    d.name AS department_name
FROM #test_employees_tc3 e
INNER JOIN #test_departments_tc3 d ON e.department_id = d.department_id
ORDER BY e.employee_id;

-- CLEANUP
DROP TABLE #test_employees_tc3;
DROP TABLE #test_departments_tc3;

-- ============= TEST CASE 4: Boundary - Employee with NULL email =============
-- SETUP
CREATE TABLE #test_departments_tc4 (
    department_id INT PRIMARY KEY,
    name NVARCHAR(100) NOT NULL,
    parent_id INT NULL,
    created_at DATETIME2 DEFAULT SYSUTCDATETIME()
);

CREATE TABLE #test_employees_tc4 (
    employee_id INT PRIMARY KEY,
    department_id INT NOT NULL,
    first_name NVARCHAR(50) NOT NULL,
    last_name NVARCHAR(50) NOT NULL,
    hire_date DATE NOT NULL,
    is_active BIT DEFAULT 1,
    email NVARCHAR(100) NULL,
    created_at DATETIME2 DEFAULT SYSUTCDATETIME()
);

INSERT INTO #test_departments_tc4 (department_id, name, parent_id)
VALUES (400, N'Operations', NULL);

INSERT INTO #test_employees_tc4 (employee_id, department_id, first_name, last_name, hire_date, is_active, email)
VALUES (4001, 400, N'Frank', N'Miller', '2021-02-10', 1, NULL);

-- EXEC & ASSERT
SELECT 
    'TC4' AS test_case,
    e.employee_id,
    e.first_name,
    e.last_name,
    CASE WHEN e.email IS NULL THEN 'NULL' ELSE e.email END AS email,
    e.is_active,
    d.name AS department_name
FROM #test_employees_tc4 e
INNER JOIN #test_departments_tc4 d ON e.department_id = d.department_id
ORDER BY e.employee_id;

-- CLEANUP
DROP TABLE #test_employees_tc4;
DROP TABLE #test_departments_tc4;

-- ============= TEST CASE 5: Boundary - Inactive employee (is_active = 0) =============
-- SETUP
CREATE TABLE #test_departments_tc5 (
    department_id INT PRIMARY KEY,
    name NVARCHAR(100) NOT NULL,
    parent_id INT NULL,
    created_at DATETIME2 DEFAULT SYSUTCDATETIME()
);

CREATE TABLE #test_employees_tc5 (
    employee_id INT PRIMARY KEY,
    department_id INT NOT NULL,
    first_name NVARCHAR(50) NOT NULL,
    last_name NVARCHAR(50) NOT NULL,
    hire_date DATE NOT NULL,
    is_active BIT DEFAULT 1,
    email NVARCHAR(100) NULL,
    created_at DATETIME2 DEFAULT SYSUTCDATETIME()
);

INSERT INTO #test_departments_tc5 (department_id, name, parent_id)
VALUES (500, N'Marketing', NULL);

INSERT INTO #test_employees_tc5 (employee_id, department_id, first_name, last_name, hire_date, is_active, email)
VALUES (5001, 500, N'Grace', N'Wilson', '2017-11-20', 0, N'grace.wilson@example.com');

-- EXEC & ASSERT
SELECT 
    'TC5' AS test_case,
    e.employee_id,
    e.first_name,
    e.last_name,
    e.is_active,
    d.name AS department_name
FROM #test_employees_tc5 e
INNER JOIN #test_departments_tc5 d ON e.department_id = d.department_id
ORDER BY e.employee_id;

-- CLEANUP
DROP TABLE #test_employees_tc5;
DROP TABLE #test_departments_tc5;

-- ============= TEST CASE 6: Boundary - Empty result set (no employees) =============
-- SETUP
CREATE TABLE #test_departments_tc6 (
    department_id INT PRIMARY KEY,
    name NVARCHAR(100) NOT NULL,
    parent_id INT NULL,
    created_at DATETIME2 DEFAULT SYSUTCDATETIME()
);

CREATE TABLE #test_employees_tc6 (
    employee_id INT PRIMARY KEY,
    department_id INT NOT NULL,
    first_name NVARCHAR(50) NOT NULL,
    last_name NVARCHAR(50) NOT NULL,
    hire_date DATE NOT NULL,
    is_active BIT DEFAULT 1,
    email NVARCHAR(100) NULL,
    created_at DATETIME2 DEFAULT SYSUTCDATETIME()
);

INSERT INTO #test_departments_tc6 (department_id, name, parent_id)
VALUES (600, N'Research', NULL);

-- No employees inserted

-- EXEC & ASSERT
SELECT 
    'TC6' AS test_case,
    COUNT(*) AS row_count
FROM #test_employees_tc6 e
INNER JOIN #test_departments_tc6 d ON e.department_id = d.department_id;

-- CLEANUP
DROP TABLE #test_employees_tc6;
DROP TABLE #test_departments_tc6;

-- ============= TEST CASE 7: Edge - Department with no employees (INNER JOIN excludes) =============
-- SETUP
CREATE TABLE #test_departments_tc7 (
    department_id INT PRIMARY KEY,
    name NVARCHAR(100) NOT NULL,
    parent_id INT NULL,
    created_at DATETIME2 DEFAULT SYSUTCDATETIME()
);

CREATE TABLE #test_employees_tc7 (
    employee_id INT PRIMARY KEY,
    department_id INT NOT NULL,
    first_name NVARCHAR(50) NOT NULL,
    last_name NVARCHAR(50) NOT NULL,
    hire_date DATE NOT NULL,
    is_active BIT DEFAULT 1,
    email NVARCHAR(100) NULL,
    created_at DATETIME2 DEFAULT SYSUTCDATETIME()
);

INSERT INTO #test_departments_tc7 (department_id, name, parent_id)
VALUES 
    (700, N'IT', NULL),
    (701, N'Legal', NULL);

INSERT INTO #test_employees_tc7 (employee_id, department_id, first_name, last_name, hire_date, is_active, email)
VALUES (7001, 700, N'Henry', N'Moore', '2019-07-15', 1, N'henry.moore@example.com');

-- EXEC & ASSERT
-- Should only return employee from IT department, not Legal
SELECT 
    'TC7' AS test_case,
    COUNT(*) AS employee_count,
    MAX(d.name) AS department_with_employee
FROM #test_employees_tc7 e
INNER JOIN #test_departments_tc7 d ON e.department_id = d.department_id;

-- CLEANUP
DROP TABLE #test_employees_tc7;
DROP TABLE #test_departments_tc7;

-- ============= TEST CASE 8: Edge - Special characters in names =============
-- SETUP
CREATE TABLE #test_departments_tc8 (
    department_id INT PRIMARY KEY,
    name NVARCHAR(100) NOT NULL,
    parent_id INT NULL,
    created_at DATETIME2 DEFAULT SYSUTCDATETIME()
);

CREATE TABLE #test_employees_tc8 (
    employee_id INT PRIMARY KEY,
    department_id INT NOT NULL,
    first_name NVARCHAR(50) NOT NULL,
    last_name NVARCHAR(50) NOT NULL,
    hire_date DATE NOT NULL,
    is_active BIT DEFAULT 1,
    email NVARCHAR(100) NULL,
    created_at DATETIME2 DEFAULT SYSUTCDATETIME()
);

INSERT INTO #test_departments_tc8 (department_id, name, parent_id)
VALUES (800, N'R&D - Innovation''s Team', NULL);

INSERT INTO #test_employees_tc8 (employee_id, department_id, first_name, last_name, hire_date, is_active, email)
VALUES (8001, 800, N'O''Brien', N'José-María', '2020-04-01', 1, N'obrien.jose@example.com');

-- EXEC & ASSERT
SELECT 
    'TC8' AS test_case,
    e.employee_id,
    e.first_name,
    e.last_name,
    d.name AS department_name
FROM #test_employees_tc8 e
INNER JOIN #test_departments_tc8 d ON e.department_id = d.department_id
ORDER BY e.employee_id;

-- CLEANUP
DROP TABLE #test_employees_tc8;
DROP TABLE #test_departments_tc8;

-- ============= TEST CASE 9: Integration - Test with actual database tables =============
-- SETUP
-- Insert test data
DECLARE @test_dept_id INT = 9000;
DECLARE @test_emp_id INT = 90001;

-- Check if test department exists, if not insert
IF NOT EXISTS (SELECT 1 FROM dbo.departments WHERE department_id = @test_dept_id)
BEGIN
    SET IDENTITY_INSERT dbo.departments ON;
    INSERT INTO dbo.departments (department_id, name, parent_id)
    VALUES (@test_dept_id, N'Test Department TC9', NULL);
    SET IDENTITY_INSERT dbo.departments OFF;
END

-- Insert test employee
IF NOT EXISTS (SELECT 1 FROM dbo.employees WHERE employee_id = @test_emp_id)
BEGIN
    SET IDENTITY_INSERT dbo.employees ON;
    INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email)
    VALUES (@test_emp_id, @test_dept_id, N'Integration', N'Test', '2023-01-01', 1, N'integration.test@example.com');
    SET IDENTITY_INSERT dbo.employees OFF;
END

-- EXEC & ASSERT
SELECT 
    'TC9' AS test_case,
    employee_id,
    first_name,
    last_name,
    email,
    is_active,
    department_id,
    department_name
FROM dbo.v_employee_full
WHERE employee_id = 90001
ORDER BY employee_id;

-- CLEANUP
DELETE FROM dbo.employees WHERE employee_id = 90001;
DELETE FROM dbo.departments WHERE department_id = 9000;

-- ============= TEST CASE 10: Performance - Large result set simulation =============
-- SETUP
CREATE TABLE #test_departments_tc10 (
    department_id INT PRIMARY KEY,
    name NVARCHAR(100) NOT NULL,
    parent_id INT NULL,
    created_at DATETIME2 DEFAULT SYSUTCDATETIME()
);

CREATE TABLE #test_employees_tc10 (
    employee_id INT PRIMARY KEY,
    department_id INT NOT NULL,
    first_name NVARCHAR(50) NOT NULL,
    last_name NVARCHAR(50) NOT NULL,
    hire_date DATE NOT NULL,
    is_active BIT DEFAULT 1,
    email NVARCHAR(100) NULL,
    created_at DATETIME2 DEFAULT SYSUTCDATETIME()
);

INSERT INTO #test_departments_tc10 (department_id, name, parent_id)
VALUES (1000, N'Large Department', NULL);

-- Insert multiple employees
DECLARE @i INT = 1;
WHILE @i <= 20
BEGIN
    INSERT INTO #test_employees_tc10 (employee_id, department_id, first_name, last_name, hire_date, is_active, email)
    VALUES (10000 + @i, 1000, N'Employee' + CAST(@i AS NVARCHAR), N'LastName' + CAST(@i AS NVARCHAR), '2020-01-01', 1, N'emp' + CAST(@i AS NVARCHAR) + '@example.com');
    SET @i = @i + 1;
END

-- EXEC & ASSERT
SELECT 
    'TC10' AS test_case,
    COUNT(*) AS total_employees,
    MIN(e.employee_id) AS min_employee_id,
    MAX(e.employee_id) AS max_employee_id,
    d.name AS department_name
FROM #test_employees_tc10 e
INNER JOIN #test_departments_tc10 d ON e.department_id = d.department_id
GROUP BY d.name;

-- CLEANUP
DROP TABLE #test_employees_tc10;
DROP TABLE #test_departments_tc10;
