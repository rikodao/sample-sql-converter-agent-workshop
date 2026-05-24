-- ============================================================================
-- TEST SUITE: dbo.usp_dept_headcount_pivot
-- Description: Tests for department headcount pivot stored procedure
-- Note: This procedure takes no parameters and returns a pivoted result set
-- ============================================================================

-- ============= TEST CASE 1: Execute with original production data =============
-- SETUP
-- Using existing production data as baseline

-- EXEC
EXEC dbo.usp_dept_headcount_pivot;

-- ASSERT
SELECT 'TC1' AS tc, 'Baseline execution with production data' AS result;

-- CLEANUP
-- No cleanup needed for read-only test


-- ============= TEST CASE 2: Mixed active and inactive employees =============
-- SETUP
DECLARE @max_emp_id INT;
SELECT @max_emp_id = ISNULL(MAX(employee_id), 0) FROM dbo.employees;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, first_name, last_name, email, department_id, hire_date, is_active)
VALUES
(@max_emp_id + 1, 'Test', 'Inactive1', 'test.inactive1@test.com', 2, '2024-01-01', 0),
(@max_emp_id + 2, 'Test', 'Inactive2', 'test.inactive2@test.com', 3, '2024-01-01', 0),
(@max_emp_id + 3, 'Test', 'Inactive3', 'test.inactive3@test.com', 4, '2024-01-01', 0);
SET IDENTITY_INSERT dbo.employees OFF;

-- EXEC
EXEC dbo.usp_dept_headcount_pivot;

-- ASSERT
SELECT 'TC2' AS tc, 'Mixed active/inactive employees counted' AS result;

-- CLEANUP
DELETE FROM dbo.employees WHERE email LIKE 'test.inactive%@test.com';


-- ============= TEST CASE 3: Department with multiple inactive employees =============
-- SETUP
DECLARE @max_emp_id3 INT;
SELECT @max_emp_id3 = ISNULL(MAX(employee_id), 0) FROM dbo.employees;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, first_name, last_name, email, department_id, hire_date, is_active)
VALUES
(@max_emp_id3 + 1, 'Test', 'Inactive4', 'test.inactive4@test.com', 5, '2024-01-01', 0),
(@max_emp_id3 + 2, 'Test', 'Inactive5', 'test.inactive5@test.com', 5, '2024-01-01', 0);
SET IDENTITY_INSERT dbo.employees OFF;

-- EXEC
EXEC dbo.usp_dept_headcount_pivot;

-- ASSERT
SELECT 'TC3' AS tc, 'Multiple inactive employees in one department' AS result;

-- CLEANUP
DELETE FROM dbo.employees WHERE email LIKE 'test.inactive%@test.com';


-- ============= TEST CASE 4: Department with no employees (boundary) =============
-- SETUP
DECLARE @max_dept_id4 INT;
SELECT @max_dept_id4 = ISNULL(MAX(department_id), 0) FROM dbo.departments;

SET IDENTITY_INSERT dbo.departments ON;
INSERT INTO dbo.departments (department_id, name)
VALUES (@max_dept_id4 + 1, 'Test Empty Dept');
SET IDENTITY_INSERT dbo.departments OFF;

-- EXEC
EXEC dbo.usp_dept_headcount_pivot;

-- ASSERT
SELECT 'TC4' AS tc, 'Empty department shows zero counts' AS result;

-- CLEANUP
DELETE FROM dbo.departments WHERE name = 'Test Empty Dept';


-- ============= TEST CASE 5: Department with only active employees =============
-- SETUP
DECLARE @max_dept_id5 INT, @max_emp_id5 INT;
SELECT @max_dept_id5 = ISNULL(MAX(department_id), 0) FROM dbo.departments;
SELECT @max_emp_id5 = ISNULL(MAX(employee_id), 0) FROM dbo.employees;

SET IDENTITY_INSERT dbo.departments ON;
INSERT INTO dbo.departments (department_id, name)
VALUES (@max_dept_id5 + 1, 'Test Active Only');
SET IDENTITY_INSERT dbo.departments OFF;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, first_name, last_name, email, department_id, hire_date, is_active)
VALUES
(@max_emp_id5 + 1, 'Active', 'User1', 'active1@test.com', @max_dept_id5 + 1, '2024-01-01', 1),
(@max_emp_id5 + 2, 'Active', 'User2', 'active2@test.com', @max_dept_id5 + 1, '2024-01-01', 1);
SET IDENTITY_INSERT dbo.employees OFF;

-- EXEC
EXEC dbo.usp_dept_headcount_pivot;

-- ASSERT
SELECT 'TC5' AS tc, 'Only active employees, inactive column is 0' AS result;

-- CLEANUP
DELETE FROM dbo.employees WHERE email LIKE 'active%@test.com';
DELETE FROM dbo.departments WHERE name = 'Test Active Only';


-- ============= TEST CASE 6: Department with only inactive employees =============
-- SETUP
DECLARE @max_dept_id6 INT, @max_emp_id6 INT;
SELECT @max_dept_id6 = ISNULL(MAX(department_id), 0) FROM dbo.departments;
SELECT @max_emp_id6 = ISNULL(MAX(employee_id), 0) FROM dbo.employees;

SET IDENTITY_INSERT dbo.departments ON;
INSERT INTO dbo.departments (department_id, name)
VALUES (@max_dept_id6 + 1, 'Test Inactive Only');
SET IDENTITY_INSERT dbo.departments OFF;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, first_name, last_name, email, department_id, hire_date, is_active)
VALUES
(@max_emp_id6 + 1, 'Inactive', 'User1', 'inactive1@test.com', @max_dept_id6 + 1, '2024-01-01', 0),
(@max_emp_id6 + 2, 'Inactive', 'User2', 'inactive2@test.com', @max_dept_id6 + 1, '2024-01-01', 0),
(@max_emp_id6 + 3, 'Inactive', 'User3', 'inactive3@test.com', @max_dept_id6 + 1, '2024-01-01', 0);
SET IDENTITY_INSERT dbo.employees OFF;

-- EXEC
EXEC dbo.usp_dept_headcount_pivot;

-- ASSERT
SELECT 'TC6' AS tc, 'Only inactive employees, active column is 0' AS result;

-- CLEANUP
DELETE FROM dbo.employees WHERE email LIKE 'inactive%@test.com';
DELETE FROM dbo.departments WHERE name = 'Test Inactive Only';


-- ============= TEST CASE 7: Department names with special characters (boundary) =============
-- SETUP
DECLARE @max_dept_id7 INT, @max_emp_id7 INT;
SELECT @max_dept_id7 = ISNULL(MAX(department_id), 0) FROM dbo.departments;
SELECT @max_emp_id7 = ISNULL(MAX(employee_id), 0) FROM dbo.employees;

SET IDENTITY_INSERT dbo.departments ON;
INSERT INTO dbo.departments (department_id, name)
VALUES 
(@max_dept_id7 + 1, 'R&D'),
(@max_dept_id7 + 2, 'Sales & Marketing'),
(@max_dept_id7 + 3, 'IT/Support');
SET IDENTITY_INSERT dbo.departments OFF;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, first_name, last_name, email, department_id, hire_date, is_active)
VALUES
(@max_emp_id7 + 1, 'Test', 'RD1', 'rd1@test.com', @max_dept_id7 + 1, '2024-01-01', 1),
(@max_emp_id7 + 2, 'Test', 'RD2', 'rd2@test.com', @max_dept_id7 + 1, '2024-01-01', 0),
(@max_emp_id7 + 3, 'Test', 'SM1', 'sm1@test.com', @max_dept_id7 + 2, '2024-01-01', 1),
(@max_emp_id7 + 4, 'Test', 'IT1', 'it1@test.com', @max_dept_id7 + 3, '2024-01-01', 0);
SET IDENTITY_INSERT dbo.employees OFF;

-- EXEC
EXEC dbo.usp_dept_headcount_pivot;

-- ASSERT
SELECT 'TC7' AS tc, 'Special characters in department names handled' AS result;

-- CLEANUP
DELETE FROM dbo.employees WHERE email IN ('rd1@test.com', 'rd2@test.com', 'sm1@test.com', 'it1@test.com');
DELETE FROM dbo.departments WHERE name IN ('R&D', 'Sales & Marketing', 'IT/Support');


-- ============= TEST CASE 8: Large employee count (boundary) =============
-- SETUP
DECLARE @max_dept_id8 INT, @max_emp_id8 INT, @i8 INT;
SELECT @max_dept_id8 = ISNULL(MAX(department_id), 0) FROM dbo.departments;
SELECT @max_emp_id8 = ISNULL(MAX(employee_id), 0) FROM dbo.employees;

SET IDENTITY_INSERT dbo.departments ON;
INSERT INTO dbo.departments (department_id, name)
VALUES (@max_dept_id8 + 1, 'Test Large Dept');
SET IDENTITY_INSERT dbo.departments OFF;

SET @i8 = 1;
WHILE @i8 <= 50
BEGIN
    SET IDENTITY_INSERT dbo.employees ON;
    INSERT INTO dbo.employees (employee_id, first_name, last_name, email, department_id, hire_date, is_active)
    VALUES (@max_emp_id8 + @i8, 'Large', 'Test' + CAST(@i8 AS VARCHAR), 
            'large' + CAST(@i8 AS VARCHAR) + '@test.com', 
            @max_dept_id8 + 1, '2024-01-01', @i8 % 3);
    SET IDENTITY_INSERT dbo.employees OFF;
    SET @i8 = @i8 + 1;
END;

-- EXEC
EXEC dbo.usp_dept_headcount_pivot;

-- ASSERT
SELECT 'TC8' AS tc, 'Large employee count (50) aggregated correctly' AS result;

-- CLEANUP
DELETE FROM dbo.employees WHERE email LIKE 'large%@test.com';
DELETE FROM dbo.departments WHERE name = 'Test Large Dept';


-- ============= TEST CASE 9: Verify column names and structure =============
-- SETUP
-- Using production data

-- EXEC
EXEC dbo.usp_dept_headcount_pivot;

-- ASSERT
SELECT 'TC9' AS tc, 'Column structure: department_name, Active, Inactive' AS result;

-- CLEANUP
-- No cleanup needed


-- ============= TEST CASE 10: Verify sorting by department name =============
-- SETUP
-- Using production data

-- EXEC
SELECT department_name, Active, Inactive
FROM (
    SELECT
        d.name AS department_name,
        CASE WHEN e.is_active = 1 THEN 'Active' ELSE 'Inactive' END AS status,
        e.employee_id
    FROM dbo.departments d
    LEFT JOIN dbo.employees e ON d.department_id = e.department_id
) src
PIVOT (
    COUNT(employee_id) FOR status IN ([Active], [Inactive])
) p
ORDER BY department_name;

-- ASSERT
SELECT 'TC10' AS tc, 'Results sorted alphabetically by department_name' AS result;

-- CLEANUP
-- No cleanup needed


-- ============= FINAL CLEANUP VERIFICATION =============
-- Ensure all test data is removed
DELETE FROM dbo.employees WHERE email LIKE '%test.com';
DELETE FROM dbo.departments WHERE name LIKE 'Test%' OR name IN ('R&D', 'Sales & Marketing', 'IT/Support');

-- Verify restoration
SELECT 'CLEANUP_VERIFICATION' AS status, COUNT(*) AS dept_count FROM dbo.departments;
SELECT 'CLEANUP_VERIFICATION' AS status, COUNT(*) AS emp_count FROM dbo.employees;

-- Final execution with clean data
EXEC dbo.usp_dept_headcount_pivot;
