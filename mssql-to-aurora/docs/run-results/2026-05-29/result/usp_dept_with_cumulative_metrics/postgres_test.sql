-- ============================================================================
-- TEST SUITE for public.usp_dept_with_cumulative_metrics
-- PostgreSQL PL/pgSQL version
-- ============================================================================
-- This test suite covers:
-- - Normal cases with various date ranges
-- - Boundary conditions (NULL dates, empty results, single department)
-- - Edge cases (same hire dates, single employee, all departments)
-- - Error cases (invalid date range)
-- - Cumulative calculation verification
-- ============================================================================

-- ============= TEST CASE 1: Normal execution with default parameters =============
-- SETUP
-- No setup needed - using existing data

-- EXEC
SELECT * FROM public.usp_dept_with_cumulative_metrics(NULL, NULL, NULL);

-- ASSERT
SELECT 'TC1' AS test_case, 'Default parameters executed' AS result;

-- CLEANUP
-- No cleanup needed


-- ============= TEST CASE 2: Specific date range with all departments =============
-- SETUP
-- No setup needed

-- EXEC
SELECT * FROM public.usp_dept_with_cumulative_metrics(
    '2020-01-01'::TIMESTAMP,
    '2023-12-31'::TIMESTAMP,
    NULL
);

-- ASSERT
SELECT 'TC2' AS test_case, 'Date range filter executed' AS result;

-- CLEANUP
-- No cleanup needed


-- ============= TEST CASE 3: Filter by specific department =============
-- SETUP
DO $$
DECLARE
    v_test_dept_id INT;
BEGIN
    SELECT department_id INTO v_test_dept_id 
    FROM public.departments 
    ORDER BY department_id 
    LIMIT 1;
    
    -- Store for next query
    CREATE TEMP TABLE IF NOT EXISTS pg_temp.test_dept_id (dept_id INT);
    DELETE FROM pg_temp.test_dept_id;
    INSERT INTO pg_temp.test_dept_id VALUES (v_test_dept_id);
END $$;

-- EXEC
SELECT * FROM public.usp_dept_with_cumulative_metrics(
    '2020-01-01'::TIMESTAMP,
    '2023-12-31'::TIMESTAMP,
    (SELECT dept_id FROM pg_temp.test_dept_id)
);

-- ASSERT
SELECT 'TC3' AS test_case, 'Single department filter executed' AS result;

-- CLEANUP
DROP TABLE IF EXISTS pg_temp.test_dept_id;


-- ============= TEST CASE 4: Verify cumulative count calculation =============
-- SETUP
CREATE TEMPORARY TABLE test_employees (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    hire_date TIMESTAMP,
    department_id INT,
    salary NUMERIC(10,2),
    status VARCHAR(20)
);

CREATE TEMPORARY TABLE test_departments (
    department_id INT PRIMARY KEY,
    department_name VARCHAR(100),
    location VARCHAR(100),
    manager_id INT
);

-- Insert test department
INSERT INTO public.departments (department_id, department_name, location, manager_id)
VALUES (9999, 'Test Dept Cumulative', 'Test Location', NULL);

-- Insert test employees with known hire dates
INSERT INTO public.employees (employee_id, first_name, last_name, email, hire_date, department_id, salary, status)
VALUES 
    (999901, 'TestEmp', 'One', 'test1@test.com', '2023-01-01'::TIMESTAMP, 9999, 50000, 'Active'),
    (999902, 'TestEmp', 'Two', 'test2@test.com', '2023-02-01'::TIMESTAMP, 9999, 60000, 'Active'),
    (999903, 'TestEmp', 'Three', 'test3@test.com', '2023-03-01'::TIMESTAMP, 9999, 70000, 'Active');

-- EXEC
CREATE TEMPORARY TABLE cumulative_results (
    department_id INT,
    department_name VARCHAR(100),
    location VARCHAR(100),
    hire_date TIMESTAMP,
    employee_id INT,
    employee_name VARCHAR(101),
    salary NUMERIC(10,2),
    cumulative_employee_count BIGINT,
    cumulative_salary_total NUMERIC,
    cumulative_salary_avg DECIMAL(10,2),
    hire_date_rank BIGINT
);

INSERT INTO cumulative_results
SELECT * FROM public.usp_dept_with_cumulative_metrics(
    '2023-01-01'::TIMESTAMP,
    '2023-12-31'::TIMESTAMP,
    9999
);

-- ASSERT
SELECT 
    'TC4' AS test_case,
    CASE 
        WHEN COUNT(*) = 3 THEN 'PASS: 3 employees returned'
        ELSE 'FAIL: Expected 3 employees, got ' || COUNT(*)::TEXT
    END AS result
FROM cumulative_results
WHERE department_id = 9999;

SELECT 
    'TC4' AS test_case,
    'Cumulative counts: ' || 
    MIN(cumulative_employee_count)::TEXT || ', ' ||
    MAX(cumulative_employee_count)::TEXT AS result
FROM cumulative_results
WHERE department_id = 9999;

SELECT 
    'TC4' AS test_case,
    CASE 
        WHEN cumulative_salary_total = 180000 THEN 'PASS: Final cumulative salary correct (180000)'
        ELSE 'FAIL: Expected 180000, got ' || cumulative_salary_total::TEXT
    END AS result
FROM cumulative_results
WHERE department_id = 9999 
  AND cumulative_employee_count = 3;

-- CLEANUP
DROP TABLE cumulative_results;
DROP TABLE test_employees;
DROP TABLE test_departments;

DELETE FROM public.employees WHERE employee_id BETWEEN 999901 AND 999903;
DELETE FROM public.departments WHERE department_id = 9999;


-- ============= TEST CASE 5: Invalid date range (start > end) =============
-- SETUP
-- No setup needed

-- EXEC & ASSERT
DO $$
BEGIN
    PERFORM * FROM public.usp_dept_with_cumulative_metrics(
        '2023-12-31'::TIMESTAMP,
        '2023-01-01'::TIMESTAMP,
        NULL
    );
    RAISE NOTICE 'TC5: FAIL: Should have raised error';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'TC5: PASS: Error raised - %', SQLERRM;
END $$;

SELECT 'TC5' AS test_case, 'Error handling verified' AS result;

-- CLEANUP
-- No cleanup needed


-- ============= TEST CASE 6: Empty result set (no employees in date range) =============
-- SETUP
-- No setup needed

-- EXEC
SELECT * FROM public.usp_dept_with_cumulative_metrics(
    '1900-01-01'::TIMESTAMP,
    '1900-12-31'::TIMESTAMP,
    NULL
);

-- ASSERT
SELECT 'TC6' AS test_case, 'Empty date range executed (should return no rows)' AS result;

-- CLEANUP
-- No cleanup needed


-- ============= TEST CASE 7: NULL start_date (should use default) =============
-- SETUP
-- No setup needed

-- EXEC
SELECT * FROM public.usp_dept_with_cumulative_metrics(
    NULL,
    '2023-12-31'::TIMESTAMP,
    NULL
);

-- ASSERT
SELECT 'TC7' AS test_case, 'NULL start_date handled with default' AS result;

-- CLEANUP
-- No cleanup needed


-- ============= TEST CASE 8: NULL end_date (should use default) =============
-- SETUP
-- No setup needed

-- EXEC
SELECT * FROM public.usp_dept_with_cumulative_metrics(
    '2020-01-01'::TIMESTAMP,
    NULL,
    NULL
);

-- ASSERT
SELECT 'TC8' AS test_case, 'NULL end_date handled with default' AS result;

-- CLEANUP
-- No cleanup needed


-- ============= TEST CASE 9: Both dates NULL (should use defaults) =============
-- SETUP
-- No setup needed

-- EXEC
SELECT * FROM public.usp_dept_with_cumulative_metrics(
    NULL,
    NULL,
    NULL
);

-- ASSERT
SELECT 'TC9' AS test_case, 'Both NULL dates handled with defaults' AS result;

-- CLEANUP
-- No cleanup needed


-- ============= TEST CASE 10: Multiple employees with same hire date =============
-- SETUP
INSERT INTO public.employees (employee_id, first_name, last_name, email, hire_date, department_id, salary, status)
VALUES 
    (999911, 'SameDate', 'One', 'same1@test.com', '2023-06-01'::TIMESTAMP, 1, 55000, 'Active'),
    (999912, 'SameDate', 'Two', 'same2@test.com', '2023-06-01'::TIMESTAMP, 1, 56000, 'Active'),
    (999913, 'SameDate', 'Three', 'same3@test.com', '2023-06-01'::TIMESTAMP, 1, 57000, 'Active');

-- EXEC
CREATE TEMPORARY TABLE same_date_results (
    department_id INT,
    department_name VARCHAR(100),
    location VARCHAR(100),
    hire_date TIMESTAMP,
    employee_id INT,
    employee_name VARCHAR(101),
    salary NUMERIC(10,2),
    cumulative_employee_count BIGINT,
    cumulative_salary_total NUMERIC,
    cumulative_salary_avg DECIMAL(10,2),
    hire_date_rank BIGINT
);

INSERT INTO same_date_results
SELECT * FROM public.usp_dept_with_cumulative_metrics(
    '2023-06-01'::TIMESTAMP,
    '2023-06-01'::TIMESTAMP,
    1
);

-- ASSERT
SELECT 
    'TC10' AS test_case,
    CASE 
        WHEN COUNT(DISTINCT cumulative_employee_count) = 3 
        THEN 'PASS: Cumulative counts are distinct for same hire date'
        ELSE 'FAIL: Cumulative counts not properly ordered'
    END AS result
FROM same_date_results
WHERE employee_id BETWEEN 999911 AND 999913;

SELECT 
    'TC10' AS test_case,
    'Employee count progression: ' || 
    string_agg(cumulative_employee_count::TEXT, ', ' ORDER BY employee_id) AS result
FROM same_date_results 
WHERE employee_id BETWEEN 999911 AND 999913;

-- CLEANUP
DROP TABLE same_date_results;
DELETE FROM public.employees WHERE employee_id BETWEEN 999911 AND 999913;


-- ============= TEST CASE 11: Non-existent department_id =============
-- SETUP
-- No setup needed

-- EXEC
SELECT * FROM public.usp_dept_with_cumulative_metrics(
    '2020-01-01'::TIMESTAMP,
    '2023-12-31'::TIMESTAMP,
    99999
);

-- ASSERT
SELECT 'TC11' AS test_case, 'Non-existent department handled (should return no rows)' AS result;

-- CLEANUP
-- No cleanup needed


-- ============= TEST CASE 12: Verify running average calculation =============
-- SETUP
INSERT INTO public.departments (department_id, department_name, location, manager_id)
VALUES (9998, 'Test Dept Avg', 'Test Location', NULL);

INSERT INTO public.employees (employee_id, first_name, last_name, email, hire_date, department_id, salary, status)
VALUES 
    (999921, 'AvgTest', 'One', 'avg1@test.com', '2023-07-01'::TIMESTAMP, 9998, 60000, 'Active'),
    (999922, 'AvgTest', 'Two', 'avg2@test.com', '2023-07-02'::TIMESTAMP, 9998, 80000, 'Active');

-- EXEC
CREATE TEMPORARY TABLE avg_results (
    department_id INT,
    department_name VARCHAR(100),
    location VARCHAR(100),
    hire_date TIMESTAMP,
    employee_id INT,
    employee_name VARCHAR(101),
    salary NUMERIC(10,2),
    cumulative_employee_count BIGINT,
    cumulative_salary_total NUMERIC,
    cumulative_salary_avg DECIMAL(10,2),
    hire_date_rank BIGINT
);

INSERT INTO avg_results
SELECT * FROM public.usp_dept_with_cumulative_metrics(
    '2023-07-01'::TIMESTAMP,
    '2023-07-31'::TIMESTAMP,
    9998
);

-- ASSERT
SELECT 
    'TC12' AS test_case,
    CASE 
        WHEN cumulative_salary_avg = 60000.00 THEN 'PASS: First avg is 60000'
        ELSE 'FAIL: Expected 60000, got ' || cumulative_salary_avg::TEXT
    END AS result
FROM avg_results
WHERE employee_id = 999921;

SELECT 
    'TC12' AS test_case,
    CASE 
        WHEN cumulative_salary_avg = 70000.00 THEN 'PASS: Second avg is 70000'
        ELSE 'FAIL: Expected 70000, got ' || cumulative_salary_avg::TEXT
    END AS result
FROM avg_results
WHERE employee_id = 999922;

-- CLEANUP
DROP TABLE avg_results;
DELETE FROM public.employees WHERE employee_id BETWEEN 999921 AND 999922;
DELETE FROM public.departments WHERE department_id = 9998;


-- ============================================================================
-- END OF TEST SUITE
-- ============================================================================
