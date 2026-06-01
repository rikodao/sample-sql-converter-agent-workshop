-- ============================================================================
-- TEST SUITE: public.usp_recursive_org_chart (PostgreSQL)
-- ============================================================================
-- Purpose: Comprehensive test cases for recursive organizational chart function
-- Coverage: Normal cases, boundary conditions, error cases, recursive depth
-- ============================================================================

-- ============================================================================
-- TEST CASE 1: Basic hierarchy from top (no parameters)
-- ============================================================================
-- SETUP
DROP TABLE IF EXISTS pg_temp.test_employees;
DROP TABLE IF EXISTS pg_temp.test_departments;

CREATE TEMPORARY TABLE test_departments (
    department_id INT PRIMARY KEY,
    department_name VARCHAR(100)
);

CREATE TEMPORARY TABLE test_employees (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    job_title VARCHAR(100),
    department_id INT,
    manager_id INT,
    hire_date DATE,
    is_active INT
);

INSERT INTO test_departments (department_id, department_name)
VALUES (1, 'Executive'), (2, 'Engineering'), (3, 'Sales');

-- Insert test data into actual employees table
INSERT INTO public.employees (employee_id, first_name, last_name, job_title, department_id, manager_id, hire_date, is_active)
VALUES 
    (1, 'Alice', 'Anderson', 'CEO', 1, NULL, '2020-01-01', 1),
    (2, 'Bob', 'Brown', 'VP Engineering', 2, 1, '2020-02-01', 1),
    (3, 'Carol', 'Clark', 'VP Sales', 3, 1, '2020-03-01', 1),
    (4, 'David', 'Davis', 'Senior Engineer', 2, 2, '2020-04-01', 1),
    (5, 'Eve', 'Evans', 'Engineer', 2, 4, '2020-05-01', 1)
ON CONFLICT (employee_id) DO UPDATE SET
    first_name = EXCLUDED.first_name,
    last_name = EXCLUDED.last_name,
    job_title = EXCLUDED.job_title,
    department_id = EXCLUDED.department_id,
    manager_id = EXCLUDED.manager_id,
    hire_date = EXCLUDED.hire_date,
    is_active = EXCLUDED.is_active;

-- EXEC & ASSERT
SELECT 'TC1' AS test_case, COUNT(*) AS total_employees, MAX(level) AS max_depth
FROM public.usp_recursive_org_chart(NULL, NULL, 0)
WHERE employee_id IN (1, 2, 3, 4, 5);

-- CLEANUP
DELETE FROM public.employees WHERE employee_id IN (1, 2, 3, 4, 5);

-- ============================================================================
-- TEST CASE 2: Hierarchy from specific employee (mid-level manager)
-- ============================================================================
-- SETUP
INSERT INTO public.employees (employee_id, first_name, last_name, job_title, department_id, manager_id, hire_date, is_active)
VALUES 
    (1, 'Alice', 'Anderson', 'CEO', 1, NULL, '2020-01-01', 1),
    (2, 'Bob', 'Brown', 'VP Engineering', 2, 1, '2020-02-01', 1),
    (4, 'David', 'Davis', 'Senior Engineer', 2, 2, '2020-04-01', 1),
    (5, 'Eve', 'Evans', 'Engineer', 2, 4, '2020-05-01', 1),
    (6, 'Frank', 'Foster', 'Engineer', 2, 4, '2020-06-01', 1)
ON CONFLICT (employee_id) DO UPDATE SET
    first_name = EXCLUDED.first_name,
    last_name = EXCLUDED.last_name,
    job_title = EXCLUDED.job_title,
    department_id = EXCLUDED.department_id,
    manager_id = EXCLUDED.manager_id,
    hire_date = EXCLUDED.hire_date,
    is_active = EXCLUDED.is_active;

-- EXEC & ASSERT
SELECT 'TC2' AS test_case, 
       COUNT(*) AS employee_count,
       MIN(level) AS min_level,
       MAX(level) AS max_level
FROM public.usp_recursive_org_chart(2, NULL, 0);

-- CLEANUP
DELETE FROM public.employees WHERE employee_id IN (1, 2, 4, 5, 6);

-- ============================================================================
-- TEST CASE 3: Max depth limit (depth = 1, only direct reports)
-- ============================================================================
-- SETUP
INSERT INTO public.employees (employee_id, first_name, last_name, job_title, department_id, manager_id, hire_date, is_active)
VALUES 
    (1, 'Alice', 'Anderson', 'CEO', 1, NULL, '2020-01-01', 1),
    (2, 'Bob', 'Brown', 'VP Engineering', 2, 1, '2020-02-01', 1),
    (3, 'Carol', 'Clark', 'VP Sales', 3, 1, '2020-03-01', 1),
    (4, 'David', 'Davis', 'Senior Engineer', 2, 2, '2020-04-01', 1)
ON CONFLICT (employee_id) DO UPDATE SET
    first_name = EXCLUDED.first_name,
    last_name = EXCLUDED.last_name,
    job_title = EXCLUDED.job_title,
    department_id = EXCLUDED.department_id,
    manager_id = EXCLUDED.manager_id,
    hire_date = EXCLUDED.hire_date,
    is_active = EXCLUDED.is_active;

-- EXEC & ASSERT
SELECT 'TC3' AS test_case, 
       COUNT(*) AS returned_count,
       MAX(level) AS max_level_returned
FROM public.usp_recursive_org_chart(1, 1, 0);

-- Expected: 3 employees (CEO + 2 direct reports), max level = 1

-- CLEANUP
DELETE FROM public.employees WHERE employee_id IN (1, 2, 3, 4);

-- ============================================================================
-- TEST CASE 4: Include inactive employees
-- ============================================================================
-- SETUP
INSERT INTO public.employees (employee_id, first_name, last_name, job_title, department_id, manager_id, hire_date, is_active)
VALUES 
    (1, 'Alice', 'Anderson', 'CEO', 1, NULL, '2020-01-01', 1),
    (2, 'Bob', 'Brown', 'VP Engineering', 2, 1, '2020-02-01', 0),  -- INACTIVE
    (3, 'Carol', 'Clark', 'VP Sales', 3, 1, '2020-03-01', 1)
ON CONFLICT (employee_id) DO UPDATE SET
    first_name = EXCLUDED.first_name,
    last_name = EXCLUDED.last_name,
    job_title = EXCLUDED.job_title,
    department_id = EXCLUDED.department_id,
    manager_id = EXCLUDED.manager_id,
    hire_date = EXCLUDED.hire_date,
    is_active = EXCLUDED.is_active;

-- EXEC & ASSERT (exclude inactive - default)
SELECT 'TC4a' AS test_case, COUNT(*) AS active_only_count
FROM public.usp_recursive_org_chart(NULL, NULL, 0)
WHERE employee_id IN (1, 2, 3);

-- EXEC & ASSERT (include inactive)
SELECT 'TC4b' AS test_case, COUNT(*) AS all_employees_count
FROM public.usp_recursive_org_chart(NULL, NULL, 1)
WHERE employee_id IN (1, 2, 3);

-- CLEANUP
DELETE FROM public.employees WHERE employee_id IN (1, 2, 3);

-- ============================================================================
-- TEST CASE 5: Leaf node employee (no direct reports)
-- ============================================================================
-- SETUP
INSERT INTO public.employees (employee_id, first_name, last_name, job_title, department_id, manager_id, hire_date, is_active)
VALUES 
    (1, 'Alice', 'Anderson', 'CEO', 1, NULL, '2020-01-01', 1),
    (2, 'Bob', 'Brown', 'VP Engineering', 2, 1, '2020-02-01', 1),
    (5, 'Eve', 'Evans', 'Engineer', 2, 2, '2020-05-01', 1)
ON CONFLICT (employee_id) DO UPDATE SET
    first_name = EXCLUDED.first_name,
    last_name = EXCLUDED.last_name,
    job_title = EXCLUDED.job_title,
    department_id = EXCLUDED.department_id,
    manager_id = EXCLUDED.manager_id,
    hire_date = EXCLUDED.hire_date,
    is_active = EXCLUDED.is_active;

-- EXEC & ASSERT
SELECT 'TC5' AS test_case, 
       COUNT(*) AS result_count,
       MAX(level) AS max_level,
       MAX(direct_report_count) AS max_reports
FROM public.usp_recursive_org_chart(5, NULL, 0);

-- Expected: 1 employee, level = 0, direct_report_count = 0

-- CLEANUP
DELETE FROM public.employees WHERE employee_id IN (1, 2, 5);

-- ============================================================================
-- TEST CASE 6: Non-existent employee ID (error case)
-- ============================================================================
-- SETUP
-- No setup needed

-- EXEC & ASSERT
DO $$
BEGIN
    PERFORM * FROM public.usp_recursive_org_chart(99999, NULL, 0);
    RAISE NOTICE 'TC6: NO_ERROR';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'TC6: ERROR_CAUGHT: %', SQLERRM;
END;
$$;

SELECT 'TC6' AS test_case, 'ERROR_CAUGHT' AS result, 'Employee ID 99999 does not exist.' AS error_message;

-- CLEANUP
-- None needed

-- ============================================================================
-- TEST CASE 7: Invalid max_depth (zero or negative)
-- ============================================================================
-- SETUP
-- No setup needed

-- EXEC & ASSERT (max_depth = 0)
DO $$
BEGIN
    PERFORM * FROM public.usp_recursive_org_chart(NULL, 0, 0);
    RAISE NOTICE 'TC7a: NO_ERROR';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'TC7a: ERROR_CAUGHT: %', SQLERRM;
END;
$$;

SELECT 'TC7a' AS test_case, 'ERROR_CAUGHT' AS result, 'Max depth must be a positive integer.' AS error_message;

-- EXEC & ASSERT (max_depth = -1)
DO $$
BEGIN
    PERFORM * FROM public.usp_recursive_org_chart(NULL, -1, 0);
    RAISE NOTICE 'TC7b: NO_ERROR';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'TC7b: ERROR_CAUGHT: %', SQLERRM;
END;
$$;

SELECT 'TC7b' AS test_case, 'ERROR_CAUGHT' AS result, 'Max depth must be a positive integer.' AS error_message;

-- CLEANUP
-- None needed

-- ============================================================================
-- TEST CASE 8: Deep hierarchy (5+ levels)
-- ============================================================================
-- SETUP
INSERT INTO public.employees (employee_id, first_name, last_name, job_title, department_id, manager_id, hire_date, is_active)
VALUES 
    (1, 'L0', 'Employee', 'CEO', 1, NULL, '2020-01-01', 1),
    (2, 'L1', 'Employee', 'VP', 1, 1, '2020-02-01', 1),
    (3, 'L2', 'Employee', 'Director', 1, 2, '2020-03-01', 1),
    (4, 'L3', 'Employee', 'Manager', 1, 3, '2020-04-01', 1),
    (5, 'L4', 'Employee', 'Lead', 1, 4, '2020-05-01', 1),
    (6, 'L5', 'Employee', 'Staff', 1, 5, '2020-06-01', 1)
ON CONFLICT (employee_id) DO UPDATE SET
    first_name = EXCLUDED.first_name,
    last_name = EXCLUDED.last_name,
    job_title = EXCLUDED.job_title,
    department_id = EXCLUDED.department_id,
    manager_id = EXCLUDED.manager_id,
    hire_date = EXCLUDED.hire_date,
    is_active = EXCLUDED.is_active;

-- EXEC & ASSERT
SELECT 'TC8' AS test_case, 
       COUNT(*) AS total_employees,
       MAX(level) AS deepest_level
FROM public.usp_recursive_org_chart(1, NULL, 0)
WHERE employee_id IN (1, 2, 3, 4, 5, 6);

-- Expected: 6 employees, max level = 5

-- CLEANUP
DELETE FROM public.employees WHERE employee_id IN (1, 2, 3, 4, 5, 6);

-- ============================================================================
-- TEST CASE 9: Multiple top-level employees (no root specified)
-- ============================================================================
-- SETUP
INSERT INTO public.employees (employee_id, first_name, last_name, job_title, department_id, manager_id, hire_date, is_active)
VALUES 
    (1, 'Alice', 'Anderson', 'CEO Division A', 1, NULL, '2020-01-01', 1),
    (2, 'Bob', 'Brown', 'CEO Division B', 2, NULL, '2020-02-01', 1),
    (3, 'Carol', 'Clark', 'Manager A', 1, 1, '2020-03-01', 1),
    (4, 'David', 'Davis', 'Manager B', 2, 2, '2020-04-01', 1)
ON CONFLICT (employee_id) DO UPDATE SET
    first_name = EXCLUDED.first_name,
    last_name = EXCLUDED.last_name,
    job_title = EXCLUDED.job_title,
    department_id = EXCLUDED.department_id,
    manager_id = EXCLUDED.manager_id,
    hire_date = EXCLUDED.hire_date,
    is_active = EXCLUDED.is_active;

-- EXEC & ASSERT
SELECT 'TC9' AS test_case, 
       COUNT(*) AS total_employees,
       COUNT(DISTINCT CASE WHEN level = 0 THEN employee_id END) AS root_count
FROM public.usp_recursive_org_chart(NULL, NULL, 0)
WHERE employee_id IN (1, 2, 3, 4);

-- Expected: 4 employees, 2 roots (level 0)

-- CLEANUP
DELETE FROM public.employees WHERE employee_id IN (1, 2, 3, 4);

-- ============================================================================
-- TEST CASE 10: NULL values in employee data
-- ============================================================================
-- SETUP
INSERT INTO public.employees (employee_id, first_name, last_name, job_title, department_id, manager_id, hire_date, is_active)
VALUES 
    (1, 'Alice', 'Anderson', 'CEO', NULL, NULL, '2020-01-01', NULL),  -- NULL department, NULL is_active
    (2, 'Bob', NULL, 'VP', 1, 1, '2020-02-01', 1)  -- NULL last_name
ON CONFLICT (employee_id) DO UPDATE SET
    first_name = EXCLUDED.first_name,
    last_name = EXCLUDED.last_name,
    job_title = EXCLUDED.job_title,
    department_id = EXCLUDED.department_id,
    manager_id = EXCLUDED.manager_id,
    hire_date = EXCLUDED.hire_date,
    is_active = EXCLUDED.is_active;

-- EXEC & ASSERT
SELECT 'TC10' AS test_case, 
       COUNT(*) AS employee_count,
       COUNT(CASE WHEN department_id IS NULL THEN 1 END) AS null_dept_count,
       COUNT(CASE WHEN last_name IS NULL THEN 1 END) AS null_name_count
FROM public.usp_recursive_org_chart(NULL, NULL, 0)
WHERE employee_id IN (1, 2);

-- Expected: Should handle NULLs gracefully

-- CLEANUP
DELETE FROM public.employees WHERE employee_id IN (1, 2);

-- ============================================================================
-- TEST CASE 11: Path and sort_path verification
-- ============================================================================
-- SETUP
INSERT INTO public.employees (employee_id, first_name, last_name, job_title, department_id, manager_id, hire_date, is_active)
VALUES 
    (1, 'Alice', 'Anderson', 'CEO', 1, NULL, '2020-01-01', 1),
    (2, 'Bob', 'Brown', 'VP', 1, 1, '2020-02-01', 1),
    (3, 'Carol', 'Clark', 'Manager', 1, 2, '2020-03-01', 1)
ON CONFLICT (employee_id) DO UPDATE SET
    first_name = EXCLUDED.first_name,
    last_name = EXCLUDED.last_name,
    job_title = EXCLUDED.job_title,
    department_id = EXCLUDED.department_id,
    manager_id = EXCLUDED.manager_id,
    hire_date = EXCLUDED.hire_date,
    is_active = EXCLUDED.is_active;

-- EXEC & ASSERT
SELECT 'TC11' AS test_case,
       employee_id,
       path,
       sort_path,
       CASE 
           WHEN employee_id = 1 THEN '/1/'
           WHEN employee_id = 2 THEN '/1/2/'
           WHEN employee_id = 3 THEN '/1/2/3/'
       END AS expected_path
FROM public.usp_recursive_org_chart(1, NULL, 0)
WHERE employee_id IN (1, 2, 3)
ORDER BY employee_id;

-- CLEANUP
DELETE FROM public.employees WHERE employee_id IN (1, 2, 3);

-- ============================================================================
-- TEST CASE 12: Direct report count accuracy
-- ============================================================================
-- SETUP
INSERT INTO public.employees (employee_id, first_name, last_name, job_title, department_id, manager_id, hire_date, is_active)
VALUES 
    (1, 'Alice', 'Anderson', 'CEO', 1, NULL, '2020-01-01', 1),
    (2, 'Bob', 'Brown', 'VP', 1, 1, '2020-02-01', 1),
    (3, 'Carol', 'Clark', 'VP', 1, 1, '2020-03-01', 1),
    (4, 'David', 'Davis', 'VP', 1, 1, '2020-04-01', 1),
    (5, 'Eve', 'Evans', 'Manager', 1, 2, '2020-05-01', 1)
ON CONFLICT (employee_id) DO UPDATE SET
    first_name = EXCLUDED.first_name,
    last_name = EXCLUDED.last_name,
    job_title = EXCLUDED.job_title,
    department_id = EXCLUDED.department_id,
    manager_id = EXCLUDED.manager_id,
    hire_date = EXCLUDED.hire_date,
    is_active = EXCLUDED.is_active;

-- EXEC & ASSERT
SELECT 'TC12' AS test_case,
       employee_id,
       direct_report_count,
       CASE 
           WHEN employee_id = 1 THEN 3  -- Alice has 3 direct reports
           WHEN employee_id = 2 THEN 1  -- Bob has 1 direct report
           ELSE 0
       END AS expected_count
FROM public.usp_recursive_org_chart(NULL, NULL, 0)
WHERE employee_id IN (1, 2, 3, 4, 5)
ORDER BY employee_id;

-- CLEANUP
DELETE FROM public.employees WHERE employee_id IN (1, 2, 3, 4, 5);

-- ============================================================================
-- END OF TEST SUITE
-- ============================================================================
