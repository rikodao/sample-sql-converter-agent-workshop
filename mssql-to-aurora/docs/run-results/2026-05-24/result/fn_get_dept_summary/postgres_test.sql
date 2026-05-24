-- ============================================================================
-- TEST SUITE: public.fn_get_dept_summary
-- Description: Table-Valued Function that returns department summary statistics
-- Note: Uses actual public.fn_get_dept_summary function with real tables
-- ============================================================================

-- ============= TEST CASE 1: Normal case with active employees and current salaries =============
-- SETUP
DELETE FROM public.salaries WHERE employee_id >= 9001 AND employee_id <= 9003;
DELETE FROM public.employees WHERE employee_id >= 9001 AND employee_id <= 9003;
DELETE FROM public.departments WHERE department_id = 1001;

INSERT INTO public.departments (department_id, name, parent_id, created_at)
VALUES (1001, 'Test Engineering', NULL, '2020-01-01');

INSERT INTO public.employees (employee_id, first_name, last_name, department_id, hire_date, is_active)
VALUES 
    (9001, 'Alice', 'Smith', 1001, '2020-01-15', TRUE),
    (9002, 'Bob', 'Jones', 1001, '2020-02-01', TRUE),
    (9003, 'Carol', 'White', 1001, '2020-03-01', TRUE);

INSERT INTO public.salaries (employee_id, base_salary, effective_from)
VALUES 
    (9001, 60000.00, '2020-01-15'),
    (9002, 70000.00, '2020-02-01'),
    (9003, 80000.00, '2020-03-01');

-- EXEC & ASSERT
SELECT 'TC1' AS tc, department_id, department_name, headcount, avg_salary, total_payroll
FROM public.fn_get_dept_summary('2024-01-01'::DATE)
WHERE department_id = 1001
ORDER BY department_id;

-- CLEANUP
DELETE FROM public.salaries WHERE employee_id >= 9001 AND employee_id <= 9003;
DELETE FROM public.employees WHERE employee_id >= 9001 AND employee_id <= 9003;
DELETE FROM public.departments WHERE department_id = 1001;

-- ============= TEST CASE 2: Department with no employees =============
-- SETUP
DELETE FROM public.departments WHERE department_id = 1002;

INSERT INTO public.departments (department_id, name, parent_id, created_at)
VALUES (1002, 'Empty Department', NULL, '2020-01-01');

-- EXEC & ASSERT
SELECT 'TC2' AS tc, department_id, department_name, headcount, avg_salary, total_payroll
FROM public.fn_get_dept_summary('2024-01-01'::DATE)
WHERE department_id = 1002
ORDER BY department_id;

-- CLEANUP
DELETE FROM public.departments WHERE department_id = 1002;

-- ============= TEST CASE 3: Department with inactive employees only =============
-- SETUP
DELETE FROM public.salaries WHERE employee_id >= 9004 AND employee_id <= 9005;
DELETE FROM public.employees WHERE employee_id >= 9004 AND employee_id <= 9005;
DELETE FROM public.departments WHERE department_id = 1003;

INSERT INTO public.departments (department_id, name, parent_id, created_at)
VALUES (1003, 'Inactive Dept', NULL, '2020-01-01');

INSERT INTO public.employees (employee_id, first_name, last_name, department_id, hire_date, is_active)
VALUES 
    (9004, 'Dave', 'Brown', 1003, '2020-01-15', FALSE),
    (9005, 'Eve', 'Green', 1003, '2020-02-01', FALSE);

INSERT INTO public.salaries (employee_id, base_salary, effective_from)
VALUES 
    (9004, 50000.00, '2020-01-15'),
    (9005, 55000.00, '2020-02-01');

-- EXEC & ASSERT
SELECT 'TC3' AS tc, department_id, department_name, headcount, avg_salary, total_payroll
FROM public.fn_get_dept_summary('2024-01-01'::DATE)
WHERE department_id = 1003
ORDER BY department_id;

-- CLEANUP
DELETE FROM public.salaries WHERE employee_id >= 9004 AND employee_id <= 9005;
DELETE FROM public.employees WHERE employee_id >= 9004 AND employee_id <= 9005;
DELETE FROM public.departments WHERE department_id = 1003;

-- ============= TEST CASE 4: Historical salary lookup (as_of date in the past) =============
-- SETUP
DELETE FROM public.salaries WHERE employee_id = 9006;
DELETE FROM public.employees WHERE employee_id = 9006;
DELETE FROM public.departments WHERE department_id = 1004;

INSERT INTO public.departments (department_id, name, parent_id, created_at)
VALUES (1004, 'Historical Dept', NULL, '2020-01-01');

INSERT INTO public.employees (employee_id, first_name, last_name, department_id, hire_date, is_active)
VALUES (9006, 'Frank', 'Black', 1004, '2020-01-15', TRUE);

INSERT INTO public.salaries (employee_id, base_salary, effective_from)
VALUES 
    (9006, 40000.00, '2020-01-15'),
    (9006, 50000.00, '2022-01-01'),
    (9006, 60000.00, '2024-01-01');

-- EXEC & ASSERT - Check salary as of 2021-06-01 (should be 40000)
SELECT 'TC4' AS tc, department_id, department_name, headcount, avg_salary, total_payroll
FROM public.fn_get_dept_summary('2021-06-01'::DATE)
WHERE department_id = 1004
ORDER BY department_id;

-- CLEANUP
DELETE FROM public.salaries WHERE employee_id = 9006;
DELETE FROM public.employees WHERE employee_id = 9006;
DELETE FROM public.departments WHERE department_id = 1004;

-- ============= TEST CASE 5: Multiple departments with varying employee counts =============
-- SETUP
DELETE FROM public.salaries WHERE employee_id >= 9007 AND employee_id <= 9010;
DELETE FROM public.employees WHERE employee_id >= 9007 AND employee_id <= 9010;
DELETE FROM public.departments WHERE department_id IN (1005, 1006, 1007);

INSERT INTO public.departments (department_id, name, parent_id, created_at)
VALUES 
    (1005, 'Dept A', NULL, '2020-01-01'),
    (1006, 'Dept B', NULL, '2020-01-01'),
    (1007, 'Dept C', NULL, '2020-01-01');

INSERT INTO public.employees (employee_id, first_name, last_name, department_id, hire_date, is_active)
VALUES 
    (9007, 'George', 'Red', 1005, '2020-01-15', TRUE),
    (9008, 'Helen', 'Blue', 1006, '2020-02-01', TRUE),
    (9009, 'Ivan', 'Yellow', 1006, '2020-03-01', TRUE),
    (9010, 'Jane', 'Purple', 1006, '2020-04-01', TRUE);

INSERT INTO public.salaries (employee_id, base_salary, effective_from)
VALUES 
    (9007, 100000.00, '2020-01-15'),
    (9008, 60000.00, '2020-02-01'),
    (9009, 70000.00, '2020-03-01'),
    (9010, 80000.00, '2020-04-01');

-- EXEC & ASSERT
SELECT 'TC5' AS tc, department_id, department_name, headcount, avg_salary, total_payroll
FROM public.fn_get_dept_summary('2024-01-01'::DATE)
WHERE department_id IN (1005, 1006, 1007)
ORDER BY department_id;

-- CLEANUP
DELETE FROM public.salaries WHERE employee_id >= 9007 AND employee_id <= 9010;
DELETE FROM public.employees WHERE employee_id >= 9007 AND employee_id <= 9010;
DELETE FROM public.departments WHERE department_id IN (1005, 1006, 1007);

-- ============= TEST CASE 6: NULL as_of date (boundary test) =============
-- SETUP
DELETE FROM public.salaries WHERE employee_id = 9011;
DELETE FROM public.employees WHERE employee_id = 9011;
DELETE FROM public.departments WHERE department_id = 1008;

INSERT INTO public.departments (department_id, name, parent_id, created_at)
VALUES (1008, 'Null Test Dept', NULL, '2020-01-01');

INSERT INTO public.employees (employee_id, first_name, last_name, department_id, hire_date, is_active)
VALUES (9011, 'Kevin', 'Orange', 1008, '2020-01-15', TRUE);

INSERT INTO public.salaries (employee_id, base_salary, effective_from)
VALUES (9011, 75000.00, '2020-01-15');

-- EXEC & ASSERT
SELECT 'TC6' AS tc, department_id, department_name, headcount, avg_salary, total_payroll
FROM public.fn_get_dept_summary(NULL)
WHERE department_id = 1008
ORDER BY department_id;

-- CLEANUP
DELETE FROM public.salaries WHERE employee_id = 9011;
DELETE FROM public.employees WHERE employee_id = 9011;
DELETE FROM public.departments WHERE department_id = 1008;

-- ============= TEST CASE 7: Future as_of date (no salary records yet) =============
-- SETUP
DELETE FROM public.salaries WHERE employee_id = 9012;
DELETE FROM public.employees WHERE employee_id = 9012;
DELETE FROM public.departments WHERE department_id = 1009;

INSERT INTO public.departments (department_id, name, parent_id, created_at)
VALUES (1009, 'Future Dept', NULL, '2020-01-01');

INSERT INTO public.employees (employee_id, first_name, last_name, department_id, hire_date, is_active)
VALUES (9012, 'Laura', 'Pink', 1009, '2025-01-15', TRUE);

INSERT INTO public.salaries (employee_id, base_salary, effective_from)
VALUES (9012, 85000.00, '2025-01-15');

-- EXEC & ASSERT - Query as of 2020-01-01 (before employee hire date)
SELECT 'TC7' AS tc, department_id, department_name, headcount, avg_salary, total_payroll
FROM public.fn_get_dept_summary('2020-01-01'::DATE)
WHERE department_id = 1009
ORDER BY department_id;

-- CLEANUP
DELETE FROM public.salaries WHERE employee_id = 9012;
DELETE FROM public.employees WHERE employee_id = 9012;
DELETE FROM public.departments WHERE department_id = 1009;

-- ============= TEST CASE 8: Employee with no salary record =============
-- SETUP
DELETE FROM public.salaries WHERE employee_id >= 9013 AND employee_id <= 9014;
DELETE FROM public.employees WHERE employee_id >= 9013 AND employee_id <= 9014;
DELETE FROM public.departments WHERE department_id = 1010;

INSERT INTO public.departments (department_id, name, parent_id, created_at)
VALUES (1010, 'No Salary Dept', NULL, '2020-01-01');

INSERT INTO public.employees (employee_id, first_name, last_name, department_id, hire_date, is_active)
VALUES 
    (9013, 'Mike', 'Gray', 1010, '2020-01-15', TRUE),
    (9014, 'Nancy', 'Silver', 1010, '2020-02-01', TRUE);

INSERT INTO public.salaries (employee_id, base_salary, effective_from)
VALUES (9013, 90000.00, '2020-01-15');
-- Note: 9014 has no salary record

-- EXEC & ASSERT
SELECT 'TC8' AS tc, department_id, department_name, headcount, avg_salary, total_payroll
FROM public.fn_get_dept_summary('2024-01-01'::DATE)
WHERE department_id = 1010
ORDER BY department_id;

-- CLEANUP
DELETE FROM public.salaries WHERE employee_id >= 9013 AND employee_id <= 9014;
DELETE FROM public.employees WHERE employee_id >= 9013 AND employee_id <= 9014;
DELETE FROM public.departments WHERE department_id = 1010;

-- ============= TEST CASE 9: Salary with zero value (boundary test) =============
-- SETUP
DELETE FROM public.salaries WHERE employee_id = 9015;
DELETE FROM public.employees WHERE employee_id = 9015;
DELETE FROM public.departments WHERE department_id = 1011;

INSERT INTO public.departments (department_id, name, parent_id, created_at)
VALUES (1011, 'Zero Salary Dept', NULL, '2020-01-01');

INSERT INTO public.employees (employee_id, first_name, last_name, department_id, hire_date, is_active)
VALUES (9015, 'Oscar', 'Gold', 1011, '2020-01-15', TRUE);

INSERT INTO public.salaries (employee_id, base_salary, effective_from)
VALUES (9015, 0.00, '2020-01-15');

-- EXEC & ASSERT
SELECT 'TC9' AS tc, department_id, department_name, headcount, avg_salary, total_payroll
FROM public.fn_get_dept_summary('2024-01-01'::DATE)
WHERE department_id = 1011
ORDER BY department_id;

-- CLEANUP
DELETE FROM public.salaries WHERE employee_id = 9015;
DELETE FROM public.employees WHERE employee_id = 9015;
DELETE FROM public.departments WHERE department_id = 1011;

-- ============= TEST CASE 10: Mixed active and inactive employees =============
-- SETUP
DELETE FROM public.salaries WHERE employee_id >= 9016 AND employee_id <= 9018;
DELETE FROM public.employees WHERE employee_id >= 9016 AND employee_id <= 9018;
DELETE FROM public.departments WHERE department_id = 1012;

INSERT INTO public.departments (department_id, name, parent_id, created_at)
VALUES (1012, 'Mixed Status Dept', NULL, '2020-01-01');

INSERT INTO public.employees (employee_id, first_name, last_name, department_id, hire_date, is_active)
VALUES 
    (9016, 'Paul', 'Bronze', 1012, '2020-01-15', TRUE),
    (9017, 'Quinn', 'Copper', 1012, '2020-02-01', FALSE),
    (9018, 'Rachel', 'Platinum', 1012, '2020-03-01', TRUE);

INSERT INTO public.salaries (employee_id, base_salary, effective_from)
VALUES 
    (9016, 65000.00, '2020-01-15'),
    (9017, 70000.00, '2020-02-01'),
    (9018, 75000.00, '2020-03-01');

-- EXEC & ASSERT - Should only count active employees (9016 and 9018)
SELECT 'TC10' AS tc, department_id, department_name, headcount, avg_salary, total_payroll
FROM public.fn_get_dept_summary('2024-01-01'::DATE)
WHERE department_id = 1012
ORDER BY department_id;

-- CLEANUP
DELETE FROM public.salaries WHERE employee_id >= 9016 AND employee_id <= 9018;
DELETE FROM public.employees WHERE employee_id >= 9016 AND employee_id <= 9018;
DELETE FROM public.departments WHERE department_id = 1012;

-- ============= TEST CASE 11: Salary effective_to boundary test =============
-- SETUP
DELETE FROM public.salaries WHERE employee_id = 9019;
DELETE FROM public.employees WHERE employee_id = 9019;
DELETE FROM public.departments WHERE department_id = 1013;

INSERT INTO public.departments (department_id, name, parent_id, created_at)
VALUES (1013, 'Boundary Test Dept', NULL, '2020-01-01');

INSERT INTO public.employees (employee_id, first_name, last_name, department_id, hire_date, is_active)
VALUES (9019, 'Sam', 'Diamond', 1013, '2020-01-15', TRUE);

INSERT INTO public.salaries (employee_id, base_salary, effective_from)
VALUES 
    (9019, 50000.00, '2020-01-15'),
    (9019, 60000.00, '2023-01-01');

-- EXEC & ASSERT - Test on the exact boundary date (2022-12-31)
SELECT 'TC11' AS tc, department_id, department_name, headcount, avg_salary, total_payroll
FROM public.fn_get_dept_summary('2022-12-31'::DATE)
WHERE department_id = 1013
ORDER BY department_id;

-- CLEANUP
DELETE FROM public.salaries WHERE employee_id = 9019;
DELETE FROM public.employees WHERE employee_id = 9019;
DELETE FROM public.departments WHERE department_id = 1013;
