-- =============================================
-- TEST SUITE: dbo.usp_dept_with_cumulative_metrics
-- =============================================
-- This procedure returns department hierarchy with metrics:
-- - depth: hierarchy level (0 = root)
-- - department_name: name of department
-- - active_headcount: count of active employees
-- - total_salary: sum of latest base_salary for active employees
--
-- Test Strategy:
-- - Normal cases: various hierarchy structures
-- - Boundary cases: empty departments, no employees, no salaries, NULL parent_id
-- - Edge cases: inactive employees, multiple salary records, deep hierarchy
-- =============================================

-- ============= TEST CASE 1: Simple hierarchy with active employees =============
-- SETUP
SET IDENTITY_INSERT dbo.departments ON;
INSERT INTO dbo.departments (department_id, name, parent_id, created_at)
VALUES 
    (9001, N'TC1_Root', NULL, '2026-01-01'),
    (9002, N'TC1_Child1', 9001, '2026-01-01'),
    (9003, N'TC1_Child2', 9001, '2026-01-01');
SET IDENTITY_INSERT dbo.departments OFF;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, created_at)
VALUES 
    (90001, 9001, N'Alice', N'Root', '2026-01-01', 1, '2026-01-01'),
    (90002, 9002, N'Bob', N'Child1', '2026-01-01', 1, '2026-01-01'),
    (90003, 9003, N'Carol', N'Child2', '2026-01-01', 1, '2026-01-01');
SET IDENTITY_INSERT dbo.employees OFF;

SET IDENTITY_INSERT dbo.salaries ON;
INSERT INTO dbo.salaries (salary_id, employee_id, base_salary, effective_from, effective_to)
VALUES 
    (90001, 90001, 100000.00, '2026-01-01', NULL),
    (90002, 90002, 80000.00, '2026-01-01', NULL),
    (90003, 90003, 90000.00, '2026-01-01', NULL);
SET IDENTITY_INSERT dbo.salaries OFF;

-- EXEC
EXEC dbo.usp_dept_with_cumulative_metrics;

-- ASSERT
SELECT 'TC1' AS tc, 'Executed successfully' AS result;

-- CLEANUP
DELETE FROM dbo.salaries WHERE salary_id BETWEEN 90001 AND 90003;
DELETE FROM dbo.employees WHERE employee_id BETWEEN 90001 AND 90003;
DELETE FROM dbo.departments WHERE department_id BETWEEN 9001 AND 9003;


-- ============= TEST CASE 2: Department with no employees =============
-- SETUP
SET IDENTITY_INSERT dbo.departments ON;
INSERT INTO dbo.departments (department_id, name, parent_id, created_at)
VALUES 
    (9004, N'TC2_Empty', NULL, '2026-01-01');
SET IDENTITY_INSERT dbo.departments OFF;

-- EXEC
EXEC dbo.usp_dept_with_cumulative_metrics;

-- ASSERT
SELECT 'TC2' AS tc, 'Department with no employees should show 0 headcount and salary' AS result;

-- CLEANUP
DELETE FROM dbo.departments WHERE department_id = 9004;


-- ============= TEST CASE 3: Employees with no salary records =============
-- SETUP
SET IDENTITY_INSERT dbo.departments ON;
INSERT INTO dbo.departments (department_id, name, parent_id, created_at)
VALUES 
    (9005, N'TC3_NoSalary', NULL, '2026-01-01');
SET IDENTITY_INSERT dbo.departments OFF;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, created_at)
VALUES 
    (90004, 9005, N'Dave', N'NoSalary', '2026-01-01', 1, '2026-01-01');
SET IDENTITY_INSERT dbo.employees OFF;

-- EXEC
EXEC dbo.usp_dept_with_cumulative_metrics;

-- ASSERT
SELECT 'TC3' AS tc, 'Employee without salary should show headcount but 0 total_salary' AS result;

-- CLEANUP
DELETE FROM dbo.employees WHERE employee_id = 90004;
DELETE FROM dbo.departments WHERE department_id = 9005;


-- ============= TEST CASE 4: Inactive employees should be excluded =============
-- SETUP
SET IDENTITY_INSERT dbo.departments ON;
INSERT INTO dbo.departments (department_id, name, parent_id, created_at)
VALUES 
    (9006, N'TC4_Inactive', NULL, '2026-01-01');
SET IDENTITY_INSERT dbo.departments OFF;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, created_at)
VALUES 
    (90005, 9006, N'Eve', N'Active', '2026-01-01', 1, '2026-01-01'),
    (90006, 9006, N'Frank', N'Inactive', '2026-01-01', 0, '2026-01-01');
SET IDENTITY_INSERT dbo.employees OFF;

SET IDENTITY_INSERT dbo.salaries ON;
INSERT INTO dbo.salaries (salary_id, employee_id, base_salary, effective_from, effective_to)
VALUES 
    (90004, 90005, 50000.00, '2026-01-01', NULL),
    (90005, 90006, 60000.00, '2026-01-01', NULL);
SET IDENTITY_INSERT dbo.salaries OFF;

-- EXEC
EXEC dbo.usp_dept_with_cumulative_metrics;

-- ASSERT
SELECT 'TC4' AS tc, 'Only active employee should be counted' AS result;

-- CLEANUP
DELETE FROM dbo.salaries WHERE salary_id BETWEEN 90004 AND 90005;
DELETE FROM dbo.employees WHERE employee_id BETWEEN 90005 AND 90006;
DELETE FROM dbo.departments WHERE department_id = 9006;


-- ============= TEST CASE 5: Multiple salary records - latest should be used =============
-- SETUP
SET IDENTITY_INSERT dbo.departments ON;
INSERT INTO dbo.departments (department_id, name, parent_id, created_at)
VALUES 
    (9007, N'TC5_MultiSalary', NULL, '2026-01-01');
SET IDENTITY_INSERT dbo.departments OFF;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, created_at)
VALUES 
    (90007, 9007, N'Grace', N'MultiSalary', '2026-01-01', 1, '2026-01-01');
SET IDENTITY_INSERT dbo.employees OFF;

SET IDENTITY_INSERT dbo.salaries ON;
INSERT INTO dbo.salaries (salary_id, employee_id, base_salary, effective_from, effective_to)
VALUES 
    (90006, 90007, 70000.00, '2026-01-01', '2026-06-30'),
    (90007, 90007, 80000.00, '2026-07-01', '2026-12-31'),
    (90008, 90007, 90000.00, '2027-01-01', NULL);
SET IDENTITY_INSERT dbo.salaries OFF;

-- EXEC
EXEC dbo.usp_dept_with_cumulative_metrics;

-- ASSERT
SELECT 'TC5' AS tc, 'Latest salary (90000) should be used' AS result;

-- CLEANUP
DELETE FROM dbo.salaries WHERE salary_id BETWEEN 90006 AND 90008;
DELETE FROM dbo.employees WHERE employee_id = 90007;
DELETE FROM dbo.departments WHERE department_id = 9007;


-- ============= TEST CASE 6: Deep hierarchy (3 levels) =============
-- SETUP
SET IDENTITY_INSERT dbo.departments ON;
INSERT INTO dbo.departments (department_id, name, parent_id, created_at)
VALUES 
    (9008, N'TC6_L0', NULL, '2026-01-01'),
    (9009, N'TC6_L1', 9008, '2026-01-01'),
    (9010, N'TC6_L2', 9009, '2026-01-01');
SET IDENTITY_INSERT dbo.departments OFF;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, created_at)
VALUES 
    (90008, 9008, N'Henry', N'L0', '2026-01-01', 1, '2026-01-01'),
    (90009, 9009, N'Ivy', N'L1', '2026-01-01', 1, '2026-01-01'),
    (90010, 9010, N'Jack', N'L2', '2026-01-01', 1, '2026-01-01');
SET IDENTITY_INSERT dbo.employees OFF;

SET IDENTITY_INSERT dbo.salaries ON;
INSERT INTO dbo.salaries (salary_id, employee_id, base_salary, effective_from, effective_to)
VALUES 
    (90009, 90008, 120000.00, '2026-01-01', NULL),
    (90010, 90009, 100000.00, '2026-01-01', NULL),
    (90011, 90010, 80000.00, '2026-01-01', NULL);
SET IDENTITY_INSERT dbo.salaries OFF;

-- EXEC
EXEC dbo.usp_dept_with_cumulative_metrics;

-- ASSERT
SELECT 'TC6' AS tc, 'Three levels should show depth 0, 1, 2' AS result;

-- CLEANUP
DELETE FROM dbo.salaries WHERE salary_id BETWEEN 90009 AND 90011;
DELETE FROM dbo.employees WHERE employee_id BETWEEN 90008 AND 90010;
DELETE FROM dbo.departments WHERE department_id BETWEEN 9008 AND 9010;


-- ============= TEST CASE 7: Multiple departments at same level =============
-- SETUP
SET IDENTITY_INSERT dbo.departments ON;
INSERT INTO dbo.departments (department_id, name, parent_id, created_at)
VALUES 
    (9011, N'TC7_Root', NULL, '2026-01-01'),
    (9012, N'TC7_A', 9011, '2026-01-01'),
    (9013, N'TC7_B', 9011, '2026-01-01'),
    (9014, N'TC7_C', 9011, '2026-01-01');
SET IDENTITY_INSERT dbo.departments OFF;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, created_at)
VALUES 
    (90011, 9012, N'Kate', N'A', '2026-01-01', 1, '2026-01-01'),
    (90012, 9013, N'Leo', N'B', '2026-01-01', 1, '2026-01-01'),
    (90013, 9014, N'Mia', N'C', '2026-01-01', 1, '2026-01-01');
SET IDENTITY_INSERT dbo.employees OFF;

SET IDENTITY_INSERT dbo.salaries ON;
INSERT INTO dbo.salaries (salary_id, employee_id, base_salary, effective_from, effective_to)
VALUES 
    (90012, 90011, 75000.00, '2026-01-01', NULL),
    (90013, 90012, 85000.00, '2026-01-01', NULL),
    (90014, 90013, 95000.00, '2026-01-01', NULL);
SET IDENTITY_INSERT dbo.salaries OFF;

-- EXEC
EXEC dbo.usp_dept_with_cumulative_metrics;

-- ASSERT
SELECT 'TC7' AS tc, 'Departments at same level should be ordered by name' AS result;

-- CLEANUP
DELETE FROM dbo.salaries WHERE salary_id BETWEEN 90012 AND 90014;
DELETE FROM dbo.employees WHERE employee_id BETWEEN 90011 AND 90013;
DELETE FROM dbo.departments WHERE department_id BETWEEN 9011 AND 9014;


-- ============= TEST CASE 8: Department with multiple employees =============
-- SETUP
SET IDENTITY_INSERT dbo.departments ON;
INSERT INTO dbo.departments (department_id, name, parent_id, created_at)
VALUES 
    (9015, N'TC8_Multi', NULL, '2026-01-01');
SET IDENTITY_INSERT dbo.departments OFF;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, created_at)
VALUES 
    (90014, 9015, N'Nina', N'E1', '2026-01-01', 1, '2026-01-01'),
    (90015, 9015, N'Oscar', N'E2', '2026-01-01', 1, '2026-01-01'),
    (90016, 9015, N'Paul', N'E3', '2026-01-01', 1, '2026-01-01');
SET IDENTITY_INSERT dbo.employees OFF;

SET IDENTITY_INSERT dbo.salaries ON;
INSERT INTO dbo.salaries (salary_id, employee_id, base_salary, effective_from, effective_to)
VALUES 
    (90015, 90014, 60000.00, '2026-01-01', NULL),
    (90016, 90015, 65000.00, '2026-01-01', NULL),
    (90017, 90016, 70000.00, '2026-01-01', NULL);
SET IDENTITY_INSERT dbo.salaries OFF;

-- EXEC
EXEC dbo.usp_dept_with_cumulative_metrics;

-- ASSERT
SELECT 'TC8' AS tc, 'Headcount should be 3, total_salary should be 195000' AS result;

-- CLEANUP
DELETE FROM dbo.salaries WHERE salary_id BETWEEN 90015 AND 90017;
DELETE FROM dbo.employees WHERE employee_id BETWEEN 90014 AND 90016;
DELETE FROM dbo.departments WHERE department_id = 9015;


-- ============= TEST CASE 9: Zero salary value =============
-- SETUP
SET IDENTITY_INSERT dbo.departments ON;
INSERT INTO dbo.departments (department_id, name, parent_id, created_at)
VALUES 
    (9016, N'TC9_ZeroSalary', NULL, '2026-01-01');
SET IDENTITY_INSERT dbo.departments OFF;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, created_at)
VALUES 
    (90017, 9016, N'Quinn', N'Zero', '2026-01-01', 1, '2026-01-01');
SET IDENTITY_INSERT dbo.employees OFF;

SET IDENTITY_INSERT dbo.salaries ON;
INSERT INTO dbo.salaries (salary_id, employee_id, base_salary, effective_from, effective_to)
VALUES 
    (90018, 90017, 0.00, '2026-01-01', NULL);
SET IDENTITY_INSERT dbo.salaries OFF;

-- EXEC
EXEC dbo.usp_dept_with_cumulative_metrics;

-- ASSERT
SELECT 'TC9' AS tc, 'Zero salary should be included in calculation' AS result;

-- CLEANUP
DELETE FROM dbo.salaries WHERE salary_id = 90018;
DELETE FROM dbo.employees WHERE employee_id = 90017;
DELETE FROM dbo.departments WHERE department_id = 9016;


-- ============= TEST CASE 10: Mixed active and inactive with complex hierarchy =============
-- SETUP
SET IDENTITY_INSERT dbo.departments ON;
INSERT INTO dbo.departments (department_id, name, parent_id, created_at)
VALUES 
    (9017, N'TC10_Root', NULL, '2026-01-01'),
    (9018, N'TC10_Child', 9017, '2026-01-01');
SET IDENTITY_INSERT dbo.departments OFF;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, created_at)
VALUES 
    (90018, 9017, N'Rachel', N'Active1', '2026-01-01', 1, '2026-01-01'),
    (90019, 9017, N'Sam', N'Inactive1', '2026-01-01', 0, '2026-01-01'),
    (90020, 9018, N'Tina', N'Active2', '2026-01-01', 1, '2026-01-01'),
    (90021, 9018, N'Uma', N'Inactive2', '2026-01-01', 0, '2026-01-01');
SET IDENTITY_INSERT dbo.employees OFF;

SET IDENTITY_INSERT dbo.salaries ON;
INSERT INTO dbo.salaries (salary_id, employee_id, base_salary, effective_from, effective_to)
VALUES 
    (90019, 90018, 110000.00, '2026-01-01', NULL),
    (90020, 90019, 120000.00, '2026-01-01', NULL),
    (90021, 90020, 90000.00, '2026-01-01', NULL),
    (90022, 90021, 100000.00, '2026-01-01', NULL);
SET IDENTITY_INSERT dbo.salaries OFF;

-- EXEC
EXEC dbo.usp_dept_with_cumulative_metrics;

-- ASSERT
SELECT 'TC10' AS tc, 'Only active employees should be counted in each department' AS result;

-- CLEANUP
DELETE FROM dbo.salaries WHERE salary_id BETWEEN 90019 AND 90022;
DELETE FROM dbo.employees WHERE employee_id BETWEEN 90018 AND 90021;
DELETE FROM dbo.departments WHERE department_id BETWEEN 9017 AND 9018;
