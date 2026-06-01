-- ============================================================================
-- TEST SUITE: dbo.fn_get_dept_summary
-- Description: Table-Valued Function that returns department summary statistics
-- Note: Uses actual dbo.fn_get_dept_summary function with real tables
-- ============================================================================

-- ============= TEST CASE 1: Normal case with active employees and current salaries =============
-- SETUP
DELETE FROM dbo.salaries WHERE employee_id >= 9001 AND employee_id <= 9003;
DELETE FROM dbo.employees WHERE employee_id >= 9001 AND employee_id <= 9003;
DELETE FROM dbo.departments WHERE department_id = 1001;

SET IDENTITY_INSERT dbo.departments ON;
INSERT INTO dbo.departments (department_id, name, parent_id, created_at)
VALUES (1001, N'Test Engineering', NULL, '2020-01-01');
SET IDENTITY_INSERT dbo.departments OFF;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES 
    (9001, 1001, N'Alice', N'Smith', '2020-01-15', 1, N'alice@test.com', '2020-01-15'),
    (9002, 1001, N'Bob', N'Jones', '2020-02-01', 1, N'bob@test.com', '2020-02-01'),
    (9003, 1001, N'Carol', N'White', '2020-03-01', 1, N'carol@test.com', '2020-03-01');
SET IDENTITY_INSERT dbo.employees OFF;

INSERT INTO dbo.salaries (employee_id, base_salary, effective_from, effective_to)
VALUES 
    (9001, 60000.00, '2020-01-15', NULL),
    (9002, 70000.00, '2020-02-01', NULL),
    (9003, 80000.00, '2020-03-01', NULL);

-- EXEC & ASSERT
SELECT 'TC1' AS tc, department_id, department_name, headcount, avg_salary, total_payroll
FROM dbo.fn_get_dept_summary('2024-01-01')
WHERE department_id = 1001
ORDER BY department_id;

-- CLEANUP
DELETE FROM dbo.salaries WHERE employee_id >= 9001 AND employee_id <= 9003;
DELETE FROM dbo.employees WHERE employee_id >= 9001 AND employee_id <= 9003;
DELETE FROM dbo.departments WHERE department_id = 1001;

-- ============= TEST CASE 2: Department with no employees =============
-- SETUP
DELETE FROM dbo.departments WHERE department_id = 1002;

SET IDENTITY_INSERT dbo.departments ON;
INSERT INTO dbo.departments (department_id, name, parent_id, created_at)
VALUES (1002, N'Empty Department', NULL, '2020-01-01');
SET IDENTITY_INSERT dbo.departments OFF;

-- EXEC & ASSERT
SELECT 'TC2' AS tc, department_id, department_name, headcount, avg_salary, total_payroll
FROM dbo.fn_get_dept_summary('2024-01-01')
WHERE department_id = 1002
ORDER BY department_id;

-- CLEANUP
DELETE FROM dbo.departments WHERE department_id = 1002;

-- ============= TEST CASE 3: Department with inactive employees only =============
-- SETUP
DELETE FROM dbo.salaries WHERE employee_id >= 9004 AND employee_id <= 9005;
DELETE FROM dbo.employees WHERE employee_id >= 9004 AND employee_id <= 9005;
DELETE FROM dbo.departments WHERE department_id = 1003;

SET IDENTITY_INSERT dbo.departments ON;
INSERT INTO dbo.departments (department_id, name, parent_id, created_at)
VALUES (1003, N'Inactive Dept', NULL, '2020-01-01');
SET IDENTITY_INSERT dbo.departments OFF;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES 
    (9004, 1003, N'Dave', N'Brown', '2020-01-15', 0, N'dave@test.com', '2020-01-15'),
    (9005, 1003, N'Eve', N'Green', '2020-02-01', 0, N'eve@test.com', '2020-02-01');
SET IDENTITY_INSERT dbo.employees OFF;

INSERT INTO dbo.salaries (employee_id, base_salary, effective_from, effective_to)
VALUES 
    (9004, 50000.00, '2020-01-15', NULL),
    (9005, 55000.00, '2020-02-01', NULL);

-- EXEC & ASSERT
SELECT 'TC3' AS tc, department_id, department_name, headcount, avg_salary, total_payroll
FROM dbo.fn_get_dept_summary('2024-01-01')
WHERE department_id = 1003
ORDER BY department_id;

-- CLEANUP
DELETE FROM dbo.salaries WHERE employee_id >= 9004 AND employee_id <= 9005;
DELETE FROM dbo.employees WHERE employee_id >= 9004 AND employee_id <= 9005;
DELETE FROM dbo.departments WHERE department_id = 1003;

-- ============= TEST CASE 4: Historical salary lookup (as_of date in the past) =============
-- SETUP
DELETE FROM dbo.salaries WHERE employee_id = 9006;
DELETE FROM dbo.employees WHERE employee_id = 9006;
DELETE FROM dbo.departments WHERE department_id = 1004;

SET IDENTITY_INSERT dbo.departments ON;
INSERT INTO dbo.departments (department_id, name, parent_id, created_at)
VALUES (1004, N'Historical Dept', NULL, '2020-01-01');
SET IDENTITY_INSERT dbo.departments OFF;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES (9006, 1004, N'Frank', N'Black', '2020-01-15', 1, N'frank@test.com', '2020-01-15');
SET IDENTITY_INSERT dbo.employees OFF;

INSERT INTO dbo.salaries (employee_id, base_salary, effective_from, effective_to)
VALUES 
    (9006, 40000.00, '2020-01-15', '2021-12-31'),
    (9006, 50000.00, '2022-01-01', '2023-12-31'),
    (9006, 60000.00, '2024-01-01', NULL);

-- EXEC & ASSERT - Check salary as of 2021-06-01 (should be 40000)
SELECT 'TC4' AS tc, department_id, department_name, headcount, avg_salary, total_payroll
FROM dbo.fn_get_dept_summary('2021-06-01')
WHERE department_id = 1004
ORDER BY department_id;

-- CLEANUP
DELETE FROM dbo.salaries WHERE employee_id = 9006;
DELETE FROM dbo.employees WHERE employee_id = 9006;
DELETE FROM dbo.departments WHERE department_id = 1004;

-- ============= TEST CASE 5: Multiple departments with varying employee counts =============
-- SETUP
DELETE FROM dbo.salaries WHERE employee_id >= 9007 AND employee_id <= 9010;
DELETE FROM dbo.employees WHERE employee_id >= 9007 AND employee_id <= 9010;
DELETE FROM dbo.departments WHERE department_id IN (1005, 1006, 1007);

SET IDENTITY_INSERT dbo.departments ON;
INSERT INTO dbo.departments (department_id, name, parent_id, created_at)
VALUES 
    (1005, N'Dept A', NULL, '2020-01-01'),
    (1006, N'Dept B', NULL, '2020-01-01'),
    (1007, N'Dept C', NULL, '2020-01-01');
SET IDENTITY_INSERT dbo.departments OFF;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES 
    (9007, 1005, N'George', N'Red', '2020-01-15', 1, N'george@test.com', '2020-01-15'),
    (9008, 1006, N'Helen', N'Blue', '2020-02-01', 1, N'helen@test.com', '2020-02-01'),
    (9009, 1006, N'Ivan', N'Yellow', '2020-03-01', 1, N'ivan@test.com', '2020-03-01'),
    (9010, 1006, N'Jane', N'Purple', '2020-04-01', 1, N'jane@test.com', '2020-04-01');
SET IDENTITY_INSERT dbo.employees OFF;

INSERT INTO dbo.salaries (employee_id, base_salary, effective_from, effective_to)
VALUES 
    (9007, 100000.00, '2020-01-15', NULL),
    (9008, 60000.00, '2020-02-01', NULL),
    (9009, 70000.00, '2020-03-01', NULL),
    (9010, 80000.00, '2020-04-01', NULL);

-- EXEC & ASSERT
SELECT 'TC5' AS tc, department_id, department_name, headcount, avg_salary, total_payroll
FROM dbo.fn_get_dept_summary('2024-01-01')
WHERE department_id IN (1005, 1006, 1007)
ORDER BY department_id;

-- CLEANUP
DELETE FROM dbo.salaries WHERE employee_id >= 9007 AND employee_id <= 9010;
DELETE FROM dbo.employees WHERE employee_id >= 9007 AND employee_id <= 9010;
DELETE FROM dbo.departments WHERE department_id IN (1005, 1006, 1007);

-- ============= TEST CASE 6: NULL as_of date (boundary test) =============
-- SETUP
DELETE FROM dbo.salaries WHERE employee_id = 9011;
DELETE FROM dbo.employees WHERE employee_id = 9011;
DELETE FROM dbo.departments WHERE department_id = 1008;

SET IDENTITY_INSERT dbo.departments ON;
INSERT INTO dbo.departments (department_id, name, parent_id, created_at)
VALUES (1008, N'Null Test Dept', NULL, '2020-01-01');
SET IDENTITY_INSERT dbo.departments OFF;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES (9011, 1008, N'Kevin', N'Orange', '2020-01-15', 1, N'kevin@test.com', '2020-01-15');
SET IDENTITY_INSERT dbo.employees OFF;

INSERT INTO dbo.salaries (employee_id, base_salary, effective_from, effective_to)
VALUES (9011, 75000.00, '2020-01-15', NULL);

-- EXEC & ASSERT
BEGIN TRY
    SELECT 'TC6' AS tc, department_id, department_name, headcount, avg_salary, total_payroll
    FROM dbo.fn_get_dept_summary(NULL)
    WHERE department_id = 1008
    ORDER BY department_id;
END TRY
BEGIN CATCH
    SELECT 'TC6' AS tc, ERROR_MESSAGE() AS error_message;
END CATCH

-- CLEANUP
DELETE FROM dbo.salaries WHERE employee_id = 9011;
DELETE FROM dbo.employees WHERE employee_id = 9011;
DELETE FROM dbo.departments WHERE department_id = 1008;

-- ============= TEST CASE 7: Future as_of date (no salary records yet) =============
-- SETUP
DELETE FROM dbo.salaries WHERE employee_id = 9012;
DELETE FROM dbo.employees WHERE employee_id = 9012;
DELETE FROM dbo.departments WHERE department_id = 1009;

SET IDENTITY_INSERT dbo.departments ON;
INSERT INTO dbo.departments (department_id, name, parent_id, created_at)
VALUES (1009, N'Future Dept', NULL, '2020-01-01');
SET IDENTITY_INSERT dbo.departments OFF;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES (9012, 1009, N'Laura', N'Pink', '2025-01-15', 1, N'laura@test.com', '2025-01-15');
SET IDENTITY_INSERT dbo.employees OFF;

INSERT INTO dbo.salaries (employee_id, base_salary, effective_from, effective_to)
VALUES (9012, 85000.00, '2025-01-15', NULL);

-- EXEC & ASSERT - Query as of 2020-01-01 (before employee hire date)
SELECT 'TC7' AS tc, department_id, department_name, headcount, avg_salary, total_payroll
FROM dbo.fn_get_dept_summary('2020-01-01')
WHERE department_id = 1009
ORDER BY department_id;

-- CLEANUP
DELETE FROM dbo.salaries WHERE employee_id = 9012;
DELETE FROM dbo.employees WHERE employee_id = 9012;
DELETE FROM dbo.departments WHERE department_id = 1009;

-- ============= TEST CASE 8: Employee with no salary record =============
-- SETUP
DELETE FROM dbo.salaries WHERE employee_id >= 9013 AND employee_id <= 9014;
DELETE FROM dbo.employees WHERE employee_id >= 9013 AND employee_id <= 9014;
DELETE FROM dbo.departments WHERE department_id = 1010;

SET IDENTITY_INSERT dbo.departments ON;
INSERT INTO dbo.departments (department_id, name, parent_id, created_at)
VALUES (1010, N'No Salary Dept', NULL, '2020-01-01');
SET IDENTITY_INSERT dbo.departments OFF;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES 
    (9013, 1010, N'Mike', N'Gray', '2020-01-15', 1, N'mike@test.com', '2020-01-15'),
    (9014, 1010, N'Nancy', N'Silver', '2020-02-01', 1, N'nancy@test.com', '2020-02-01');
SET IDENTITY_INSERT dbo.employees OFF;

INSERT INTO dbo.salaries (employee_id, base_salary, effective_from, effective_to)
VALUES (9013, 90000.00, '2020-01-15', NULL);
-- Note: 9014 has no salary record

-- EXEC & ASSERT
SELECT 'TC8' AS tc, department_id, department_name, headcount, avg_salary, total_payroll
FROM dbo.fn_get_dept_summary('2024-01-01')
WHERE department_id = 1010
ORDER BY department_id;

-- CLEANUP
DELETE FROM dbo.salaries WHERE employee_id >= 9013 AND employee_id <= 9014;
DELETE FROM dbo.employees WHERE employee_id >= 9013 AND employee_id <= 9014;
DELETE FROM dbo.departments WHERE department_id = 1010;

-- ============= TEST CASE 9: Salary with zero value (boundary test) =============
-- SETUP
DELETE FROM dbo.salaries WHERE employee_id = 9015;
DELETE FROM dbo.employees WHERE employee_id = 9015;
DELETE FROM dbo.departments WHERE department_id = 1011;

SET IDENTITY_INSERT dbo.departments ON;
INSERT INTO dbo.departments (department_id, name, parent_id, created_at)
VALUES (1011, N'Zero Salary Dept', NULL, '2020-01-01');
SET IDENTITY_INSERT dbo.departments OFF;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES (9015, 1011, N'Oscar', N'Gold', '2020-01-15', 1, N'oscar@test.com', '2020-01-15');
SET IDENTITY_INSERT dbo.employees OFF;

INSERT INTO dbo.salaries (employee_id, base_salary, effective_from, effective_to)
VALUES (9015, 0.00, '2020-01-15', NULL);

-- EXEC & ASSERT
SELECT 'TC9' AS tc, department_id, department_name, headcount, avg_salary, total_payroll
FROM dbo.fn_get_dept_summary('2024-01-01')
WHERE department_id = 1011
ORDER BY department_id;

-- CLEANUP
DELETE FROM dbo.salaries WHERE employee_id = 9015;
DELETE FROM dbo.employees WHERE employee_id = 9015;
DELETE FROM dbo.departments WHERE department_id = 1011;

-- ============= TEST CASE 10: Mixed active and inactive employees =============
-- SETUP
DELETE FROM dbo.salaries WHERE employee_id >= 9016 AND employee_id <= 9018;
DELETE FROM dbo.employees WHERE employee_id >= 9016 AND employee_id <= 9018;
DELETE FROM dbo.departments WHERE department_id = 1012;

SET IDENTITY_INSERT dbo.departments ON;
INSERT INTO dbo.departments (department_id, name, parent_id, created_at)
VALUES (1012, N'Mixed Status Dept', NULL, '2020-01-01');
SET IDENTITY_INSERT dbo.departments OFF;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES 
    (9016, 1012, N'Paul', N'Bronze', '2020-01-15', 1, N'paul@test.com', '2020-01-15'),
    (9017, 1012, N'Quinn', N'Copper', '2020-02-01', 0, N'quinn@test.com', '2020-02-01'),
    (9018, 1012, N'Rachel', N'Platinum', '2020-03-01', 1, N'rachel@test.com', '2020-03-01');
SET IDENTITY_INSERT dbo.employees OFF;

INSERT INTO dbo.salaries (employee_id, base_salary, effective_from, effective_to)
VALUES 
    (9016, 65000.00, '2020-01-15', NULL),
    (9017, 70000.00, '2020-02-01', NULL),
    (9018, 75000.00, '2020-03-01', NULL);

-- EXEC & ASSERT - Should only count active employees (9016 and 9018)
SELECT 'TC10' AS tc, department_id, department_name, headcount, avg_salary, total_payroll
FROM dbo.fn_get_dept_summary('2024-01-01')
WHERE department_id = 1012
ORDER BY department_id;

-- CLEANUP
DELETE FROM dbo.salaries WHERE employee_id >= 9016 AND employee_id <= 9018;
DELETE FROM dbo.employees WHERE employee_id >= 9016 AND employee_id <= 9018;
DELETE FROM dbo.departments WHERE department_id = 1012;

-- ============= TEST CASE 11: Salary effective_to boundary test =============
-- SETUP
DELETE FROM dbo.salaries WHERE employee_id = 9019;
DELETE FROM dbo.employees WHERE employee_id = 9019;
DELETE FROM dbo.departments WHERE department_id = 1013;

SET IDENTITY_INSERT dbo.departments ON;
INSERT INTO dbo.departments (department_id, name, parent_id, created_at)
VALUES (1013, N'Boundary Test Dept', NULL, '2020-01-01');
SET IDENTITY_INSERT dbo.departments OFF;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES (9019, 1013, N'Sam', N'Diamond', '2020-01-15', 1, N'sam@test.com', '2020-01-15');
SET IDENTITY_INSERT dbo.employees OFF;

INSERT INTO dbo.salaries (employee_id, base_salary, effective_from, effective_to)
VALUES 
    (9019, 50000.00, '2020-01-15', '2022-12-31'),
    (9019, 60000.00, '2023-01-01', NULL);

-- EXEC & ASSERT - Test on the exact boundary date (2022-12-31)
SELECT 'TC11' AS tc, department_id, department_name, headcount, avg_salary, total_payroll
FROM dbo.fn_get_dept_summary('2022-12-31')
WHERE department_id = 1013
ORDER BY department_id;

-- CLEANUP
DELETE FROM dbo.salaries WHERE employee_id = 9019;
DELETE FROM dbo.employees WHERE employee_id = 9019;
DELETE FROM dbo.departments WHERE department_id = 1013;
