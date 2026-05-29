-- ============================================================================
-- Test Suite for: public.v_employee_full (PostgreSQL)
-- ============================================================================
-- Purpose: Comprehensive test coverage for employee full information view
-- Test Categories:
--   - Normal cases (basic SELECT, JOIN behavior)
--   - Boundary cases (NULL department_id, empty results)
--   - Edge cases (multiple departments, ordering)
--   - JOIN behavior (LEFT JOIN with NULL values)
--   - Data integrity (column presence, data types)
-- ============================================================================

-- ============= TEST CASE 1: Basic SELECT - Retrieve all columns =============
-- SETUP
-- No setup needed - using existing data

-- EXEC
-- ASSERT
SELECT 'TC1' AS tc, 
       COUNT(*) AS total_rows,
       COUNT(DISTINCT employee_id) AS distinct_employees,
       COUNT(DISTINCT department_id) AS distinct_departments
FROM public.v_employee_full;

-- CLEANUP
-- No cleanup needed


-- ============= TEST CASE 2: SELECT specific employee with department =============
-- SETUP
-- Ensure test employee exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.employees WHERE employee_id = 1) THEN
        INSERT INTO public.employees (employee_id, first_name, last_name, email, hire_date, salary, is_active, department_id)
        VALUES (1, 'TestUser1', 'TestLast1', 'test1@example.com', '2020-01-01', 50000, true, 1);
    END IF;
END $$;

-- EXEC & ASSERT
SELECT 'TC2' AS tc,
       employee_id,
       first_name,
       last_name,
       email,
       department_id,
       department_name,
       location
FROM public.v_employee_full
WHERE employee_id = 1;

-- CLEANUP
-- Keep test data for other tests


-- ============= TEST CASE 3: LEFT JOIN behavior - Employee with NULL department_id =============
-- SETUP
-- Create temporary employee with NULL department_id
INSERT INTO public.employees (employee_id, first_name, last_name, email, hire_date, salary, is_active, department_id)
VALUES (99901, 'NoDepEmployee', 'TestLast', 'nodept@example.com', '2023-01-01', 45000, true, NULL);

-- EXEC & ASSERT
SELECT 'TC3' AS tc,
       employee_id,
       first_name,
       last_name,
       department_id,
       department_name,
       location,
       CASE WHEN department_name IS NULL THEN 'NULL' ELSE 'NOT_NULL' END AS dept_name_status
FROM public.v_employee_full
WHERE employee_id = 99901;

-- CLEANUP
DELETE FROM public.employees WHERE employee_id = 99901;


-- ============= TEST CASE 4: Multiple employees in same department =============
-- SETUP
-- Ensure department exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.departments WHERE department_id = 1) THEN
        INSERT INTO public.departments (department_id, department_name, location)
        VALUES (1, 'Engineering', 'Building A');
    END IF;
END $$;

-- Create test employees in same department
INSERT INTO public.employees (employee_id, first_name, last_name, email, hire_date, salary, is_active, department_id)
VALUES 
    (99902, 'Emp1', 'Dept1', 'emp1@example.com', '2023-01-01', 50000, true, 1),
    (99903, 'Emp2', 'Dept1', 'emp2@example.com', '2023-01-01', 55000, true, 1),
    (99904, 'Emp3', 'Dept1', 'emp3@example.com', '2023-01-01', 60000, true, 1);

-- EXEC & ASSERT
SELECT 'TC4' AS tc,
       COUNT(*) AS employee_count,
       department_id,
       department_name
FROM public.v_employee_full
WHERE employee_id IN (99902, 99903, 99904)
GROUP BY department_id, department_name;

-- CLEANUP
DELETE FROM public.employees WHERE employee_id IN (99902, 99903, 99904);


-- ============= TEST CASE 5: All employee columns present =============
-- SETUP
-- Create test employee with all columns populated
INSERT INTO public.employees (
    employee_id, first_name, last_name, email, phone_number,
    hire_date, job_id, salary, commission_pct, manager_id, department_id,
    status, termination_date, is_active, performance_rating, 
    bonus_amount, last_bonus_date, bonus_fiscal_year
)
VALUES (
    99905, 'FullData', 'Employee', 'fulldata@example.com', '555-1234',
    '2022-01-01', 'IT_PROG', 75000.00, 0.10, 1, 1,
    'Active', NULL, true, 4,
    5000.00, '2023-12-31', 2023
);

-- EXEC & ASSERT
SELECT 'TC5' AS tc,
       employee_id,
       first_name,
       last_name,
       email,
       phone_number,
       hire_date,
       job_id,
       salary,
       commission_pct,
       manager_id,
       department_id,
       status,
       termination_date,
       is_active,
       performance_rating,
       bonus_amount,
       last_bonus_date,
       bonus_fiscal_year,
       department_name,
       location
FROM public.v_employee_full
WHERE employee_id = 99905;

-- CLEANUP
DELETE FROM public.employees WHERE employee_id = 99905;


-- ============= TEST CASE 6: ORDER BY employee_id =============
-- SETUP
-- Create test employees with specific IDs
INSERT INTO public.employees (employee_id, first_name, last_name, email, hire_date, salary, is_active, department_id)
VALUES 
    (99910, 'ZLast', 'Employee', 'zlast@example.com', '2023-01-01', 50000, true, 1),
    (99906, 'AFirst', 'Employee', 'afirst@example.com', '2023-01-01', 50000, true, 1),
    (99908, 'MMiddle', 'Employee', 'mmiddle@example.com', '2023-01-01', 50000, true, 1);

-- EXEC & ASSERT
SELECT 'TC6' AS tc,
       employee_id,
       first_name,
       ROW_NUMBER() OVER (ORDER BY employee_id) AS row_num
FROM public.v_employee_full
WHERE employee_id IN (99906, 99908, 99910)
ORDER BY employee_id;

-- CLEANUP
DELETE FROM public.employees WHERE employee_id IN (99906, 99908, 99910);


-- ============= TEST CASE 7: Filter by department_name =============
-- SETUP
-- Ensure test department exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.departments WHERE department_id = 2) THEN
        INSERT INTO public.departments (department_id, department_name, location)
        VALUES (2, 'Sales', 'Building B');
    END IF;
END $$;

-- Create test employees in Sales department
INSERT INTO public.employees (employee_id, first_name, last_name, email, hire_date, salary, is_active, department_id)
VALUES 
    (99911, 'SalesEmp1', 'Test', 'sales1@example.com', '2023-01-01', 50000, true, 2),
    (99912, 'SalesEmp2', 'Test', 'sales2@example.com', '2023-01-01', 55000, true, 2);

-- EXEC & ASSERT
SELECT 'TC7' AS tc,
       COUNT(*) AS sales_employee_count,
       department_name
FROM public.v_employee_full
WHERE employee_id IN (99911, 99912) AND department_name = 'Sales'
GROUP BY department_name;

-- CLEANUP
DELETE FROM public.employees WHERE employee_id IN (99911, 99912);


-- ============= TEST CASE 8: Boundary - Empty result set =============
-- SETUP
-- No setup needed

-- EXEC & ASSERT
SELECT 'TC8' AS tc,
       COUNT(*) AS row_count
FROM public.v_employee_full
WHERE employee_id = 999999;

-- CLEANUP
-- No cleanup needed


-- ============= TEST CASE 9: NULL handling in various columns =============
-- SETUP
-- Create employee with multiple NULL values
INSERT INTO public.employees (
    employee_id, first_name, last_name, email, phone_number,
    hire_date, job_id, salary, commission_pct, manager_id, department_id,
    status, termination_date, is_active
)
VALUES (
    99913, 'NullTest', 'Employee', 'nulltest@example.com', NULL,
    '2023-01-01', NULL, 50000.00, NULL, NULL, NULL,
    'Active', NULL, true
);

-- EXEC & ASSERT
SELECT 'TC9' AS tc,
       employee_id,
       first_name,
       CASE WHEN phone_number IS NULL THEN 'NULL' ELSE phone_number END AS phone_status,
       CASE WHEN job_id IS NULL THEN 'NULL' ELSE job_id END AS job_status,
       CASE WHEN commission_pct IS NULL THEN 'NULL' ELSE CAST(commission_pct AS VARCHAR) END AS commission_status,
       CASE WHEN manager_id IS NULL THEN 'NULL' ELSE CAST(manager_id AS VARCHAR) END AS manager_status,
       CASE WHEN department_id IS NULL THEN 'NULL' ELSE CAST(department_id AS VARCHAR) END AS dept_status,
       CASE WHEN department_name IS NULL THEN 'NULL' ELSE department_name END AS dept_name_status
FROM public.v_employee_full
WHERE employee_id = 99913;

-- CLEANUP
DELETE FROM public.employees WHERE employee_id = 99913;


-- ============= TEST CASE 10: Aggregate functions on view =============
-- SETUP
-- Create test employees with varying salaries
INSERT INTO public.employees (employee_id, first_name, last_name, email, hire_date, salary, is_active, department_id)
VALUES 
    (99914, 'AggTest1', 'Employee', 'agg1@example.com', '2023-01-01', 50000, true, 1),
    (99915, 'AggTest2', 'Employee', 'agg2@example.com', '2023-01-01', 60000, true, 1),
    (99916, 'AggTest3', 'Employee', 'agg3@example.com', '2023-01-01', 70000, true, 1);

-- EXEC & ASSERT
SELECT 'TC10' AS tc,
       COUNT(*) AS employee_count,
       MIN(salary) AS min_salary,
       MAX(salary) AS max_salary,
       AVG(salary) AS avg_salary,
       SUM(salary) AS total_salary
FROM public.v_employee_full
WHERE employee_id IN (99914, 99915, 99916);

-- CLEANUP
DELETE FROM public.employees WHERE employee_id IN (99914, 99915, 99916);


-- ============================================================================
-- End of Test Suite
-- ============================================================================
-- Total Test Cases: 10
-- Coverage:
--   - Normal SELECT: TC1, TC2, TC5
--   - LEFT JOIN behavior: TC3, TC4
--   - Filtering and ordering: TC6, TC7, TC8
--   - NULL handling: TC9
--   - Aggregate functions: TC10
-- ============================================================================
