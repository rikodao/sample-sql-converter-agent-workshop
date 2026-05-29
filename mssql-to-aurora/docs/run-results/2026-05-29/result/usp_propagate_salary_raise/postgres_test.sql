-- ============================================================================
-- Test Suite for: public.usp_propagate_salary_raise (PostgreSQL)
-- ============================================================================
-- This test suite covers:
-- - Normal cases: percentage and fixed amount raises
-- - Boundary cases: NULL inputs, zero values, maximum percentages
-- - Exception cases: invalid inputs, constraint violations
-- - Transaction cases: rollback behavior
-- - Side effects: salary updates, audit trail, output parameters
-- ============================================================================

-- ============= TEST CASE 1: Normal - Percentage raise for all employees =============
-- SETUP
CREATE TEMPORARY TABLE test_employees_tc1 (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    department_id INT,
    salary NUMERIC(18,2),
    hire_date DATE,
    last_raise_date DATE,
    is_active BOOLEAN
);

INSERT INTO test_employees_tc1 (employee_id, first_name, last_name, department_id, salary, hire_date, last_raise_date, is_active)
VALUES 
    (1001, 'John', 'Doe', 10, 50000.00, '2020-01-01', '2023-01-01', true),
    (1002, 'Jane', 'Smith', 10, 60000.00, '2019-06-15', '2023-06-15', true),
    (1003, 'Bob', 'Johnson', 20, 55000.00, '2021-03-10', '2023-03-10', true);

-- Create employees table if not exists and populate with test data
DROP TABLE IF EXISTS public.employees CASCADE;
CREATE TABLE public.employees (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    department_id INT,
    salary NUMERIC(18,2),
    hire_date DATE,
    last_raise_date DATE,
    is_active BOOLEAN
);

INSERT INTO public.employees SELECT * FROM test_employees_tc1;

-- EXEC
DO $$
DECLARE
    v_count1 INT := 0;
    v_total1 NUMERIC(18,2) := 0.00;
BEGIN
    CALL public.usp_propagate_salary_raise(
        p_department_id := NULL,
        p_raise_percentage := 10.00,
        p_raise_amount := NULL,
        p_effective_date := '2024-01-01',
        p_reason := 'Annual raise 2024',
        p_affected_count := v_count1,
        p_total_increase := v_total1
    );
    
    -- Store results in temp table for assertion
    CREATE TEMP TABLE IF NOT EXISTS tc1_output (test_case TEXT, check_type TEXT, affected_count INT, total_increase NUMERIC(18,2));
    INSERT INTO tc1_output VALUES ('TC1', 'output_params', v_count1, v_total1);
END $$;

-- ASSERT
SELECT 'TC1' AS test_case, 'output_params' AS check_type, affected_count, total_increase FROM tc1_output;
SELECT 'TC1' AS test_case, 'salary_updates' AS check_type, employee_id, salary, last_raise_date 
FROM public.employees 
ORDER BY employee_id;

-- CLEANUP
DROP TABLE IF EXISTS tc1_output;
DROP TABLE IF EXISTS public.employees CASCADE;
DROP TABLE IF EXISTS test_employees_tc1;

-- ============= TEST CASE 2: Normal - Fixed amount raise for specific department =============
-- SETUP
CREATE TEMPORARY TABLE test_employees_tc2 (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    department_id INT,
    salary NUMERIC(18,2),
    hire_date DATE,
    last_raise_date DATE,
    is_active BOOLEAN
);

INSERT INTO test_employees_tc2 (employee_id, first_name, last_name, department_id, salary, hire_date, last_raise_date, is_active)
VALUES 
    (2001, 'Alice', 'Brown', 10, 45000.00, '2020-01-01', '2023-01-01', true),
    (2002, 'Charlie', 'Davis', 10, 48000.00, '2019-06-15', '2023-06-15', true),
    (2003, 'Diana', 'Evans', 20, 52000.00, '2021-03-10', '2023-03-10', true);

CREATE TABLE public.employees (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    department_id INT,
    salary NUMERIC(18,2),
    hire_date DATE,
    last_raise_date DATE,
    is_active BOOLEAN
);

INSERT INTO public.employees SELECT * FROM test_employees_tc2;

-- EXEC
DO $$
DECLARE
    v_count2 INT := 0;
    v_total2 NUMERIC(18,2) := 0.00;
BEGIN
    CALL public.usp_propagate_salary_raise(
        p_department_id := 10,
        p_raise_percentage := NULL,
        p_raise_amount := 5000.00,
        p_effective_date := '2024-02-01',
        p_reason := 'Department 10 adjustment',
        p_affected_count := v_count2,
        p_total_increase := v_total2
    );
    
    CREATE TEMP TABLE IF NOT EXISTS tc2_output (test_case TEXT, check_type TEXT, affected_count INT, total_increase NUMERIC(18,2));
    INSERT INTO tc2_output VALUES ('TC2', 'output_params', v_count2, v_total2);
END $$;

-- ASSERT
SELECT 'TC2' AS test_case, 'output_params' AS check_type, affected_count, total_increase FROM tc2_output;
SELECT 'TC2' AS test_case, 'salary_updates' AS check_type, employee_id, department_id, salary, last_raise_date 
FROM public.employees 
ORDER BY employee_id;

-- CLEANUP
DROP TABLE IF EXISTS tc2_output;
DROP TABLE IF EXISTS public.employees CASCADE;
DROP TABLE IF EXISTS test_employees_tc2;

-- ============= TEST CASE 3: Normal - Default effective date and reason =============
-- SETUP
CREATE TEMPORARY TABLE test_employees_tc3 (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    department_id INT,
    salary NUMERIC(18,2),
    hire_date DATE,
    last_raise_date DATE,
    is_active BOOLEAN
);

INSERT INTO test_employees_tc3 (employee_id, first_name, last_name, department_id, salary, hire_date, last_raise_date, is_active)
VALUES 
    (3001, 'Eve', 'Foster', 30, 70000.00, '2020-01-01', '2023-01-01', true);

CREATE TABLE public.employees (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    department_id INT,
    salary NUMERIC(18,2),
    hire_date DATE,
    last_raise_date DATE,
    is_active BOOLEAN
);

INSERT INTO public.employees SELECT * FROM test_employees_tc3;

-- EXEC
DO $$
DECLARE
    v_count3 INT := 0;
    v_total3 NUMERIC(18,2) := 0.00;
BEGIN
    CALL public.usp_propagate_salary_raise(
        p_department_id := NULL,
        p_raise_percentage := 5.00,
        p_raise_amount := NULL,
        p_effective_date := NULL,
        p_reason := NULL,
        p_affected_count := v_count3,
        p_total_increase := v_total3
    );
    
    CREATE TEMP TABLE IF NOT EXISTS tc3_output (test_case TEXT, check_type TEXT, affected_count INT, total_increase NUMERIC(18,2));
    INSERT INTO tc3_output VALUES ('TC3', 'output_params', v_count3, v_total3);
END $$;

-- ASSERT
SELECT 'TC3' AS test_case, 'output_params' AS check_type, affected_count, total_increase FROM tc3_output;
SELECT 'TC3' AS test_case, 'salary_check' AS check_type, employee_id, salary 
FROM public.employees;

-- CLEANUP
DROP TABLE IF EXISTS tc3_output;
DROP TABLE IF EXISTS public.employees CASCADE;
DROP TABLE IF EXISTS test_employees_tc3;

-- ============= TEST CASE 4: Boundary - Zero eligible employees (all recently raised) =============
-- SETUP
CREATE TEMPORARY TABLE test_employees_tc4 (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    department_id INT,
    salary NUMERIC(18,2),
    hire_date DATE,
    last_raise_date DATE,
    is_active BOOLEAN
);

INSERT INTO test_employees_tc4 (employee_id, first_name, last_name, department_id, salary, hire_date, last_raise_date, is_active)
VALUES 
    (4001, 'Frank', 'Green', 10, 50000.00, '2020-01-01', CURRENT_DATE, true);

CREATE TABLE public.employees (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    department_id INT,
    salary NUMERIC(18,2),
    hire_date DATE,
    last_raise_date DATE,
    is_active BOOLEAN
);

INSERT INTO public.employees SELECT * FROM test_employees_tc4;

-- EXEC
DO $$
DECLARE
    v_count4 INT := 0;
    v_total4 NUMERIC(18,2) := 0.00;
BEGIN
    CALL public.usp_propagate_salary_raise(
        p_department_id := NULL,
        p_raise_percentage := 10.00,
        p_raise_amount := NULL,
        p_effective_date := '2024-01-01',
        p_reason := 'Test recent raise',
        p_affected_count := v_count4,
        p_total_increase := v_total4
    );
    
    CREATE TEMP TABLE IF NOT EXISTS tc4_output (test_case TEXT, check_type TEXT, affected_count INT, total_increase NUMERIC(18,2));
    INSERT INTO tc4_output VALUES ('TC4', 'output_params', v_count4, v_total4);
END $$;

-- ASSERT
SELECT 'TC4' AS test_case, 'output_params' AS check_type, affected_count, total_increase FROM tc4_output;

-- CLEANUP
DROP TABLE IF EXISTS tc4_output;
DROP TABLE IF EXISTS public.employees CASCADE;
DROP TABLE IF EXISTS test_employees_tc4;

-- ============= TEST CASE 5: Boundary - Inactive employees excluded =============
-- SETUP
CREATE TEMPORARY TABLE test_employees_tc5 (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    department_id INT,
    salary NUMERIC(18,2),
    hire_date DATE,
    last_raise_date DATE,
    is_active BOOLEAN
);

INSERT INTO test_employees_tc5 (employee_id, first_name, last_name, department_id, salary, hire_date, last_raise_date, is_active)
VALUES 
    (5001, 'Grace', 'Hill', 10, 50000.00, '2020-01-01', '2023-01-01', true),
    (5002, 'Henry', 'Ivy', 10, 55000.00, '2019-06-15', '2023-06-15', false);

CREATE TABLE public.employees (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    department_id INT,
    salary NUMERIC(18,2),
    hire_date DATE,
    last_raise_date DATE,
    is_active BOOLEAN
);

INSERT INTO public.employees SELECT * FROM test_employees_tc5;

-- EXEC
DO $$
DECLARE
    v_count5 INT := 0;
    v_total5 NUMERIC(18,2) := 0.00;
BEGIN
    CALL public.usp_propagate_salary_raise(
        p_department_id := NULL,
        p_raise_percentage := 10.00,
        p_raise_amount := NULL,
        p_effective_date := '2024-01-01',
        p_reason := 'Active only test',
        p_affected_count := v_count5,
        p_total_increase := v_total5
    );
    
    CREATE TEMP TABLE IF NOT EXISTS tc5_output (test_case TEXT, check_type TEXT, affected_count INT, total_increase NUMERIC(18,2));
    INSERT INTO tc5_output VALUES ('TC5', 'output_params', v_count5, v_total5);
END $$;

-- ASSERT
SELECT 'TC5' AS test_case, 'output_params' AS check_type, affected_count, total_increase FROM tc5_output;
SELECT 'TC5' AS test_case, 'salary_check' AS check_type, employee_id, is_active, salary 
FROM public.employees 
ORDER BY employee_id;

-- CLEANUP
DROP TABLE IF EXISTS tc5_output;
DROP TABLE IF EXISTS public.employees CASCADE;
DROP TABLE IF EXISTS test_employees_tc5;

-- ============= TEST CASE 6: Boundary - Maximum raise percentage (20%) =============
-- SETUP
CREATE TEMPORARY TABLE test_employees_tc6 (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    department_id INT,
    salary NUMERIC(18,2),
    hire_date DATE,
    last_raise_date DATE,
    is_active BOOLEAN
);

INSERT INTO test_employees_tc6 (employee_id, first_name, last_name, department_id, salary, hire_date, last_raise_date, is_active)
VALUES 
    (6001, 'Ivy', 'Jones', 10, 100000.00, '2020-01-01', '2023-01-01', true);

CREATE TABLE public.employees (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    department_id INT,
    salary NUMERIC(18,2),
    hire_date DATE,
    last_raise_date DATE,
    is_active BOOLEAN
);

INSERT INTO public.employees SELECT * FROM test_employees_tc6;

-- EXEC
DO $$
DECLARE
    v_count6 INT := 0;
    v_total6 NUMERIC(18,2) := 0.00;
BEGIN
    CALL public.usp_propagate_salary_raise(
        p_department_id := NULL,
        p_raise_percentage := 20.00,
        p_raise_amount := NULL,
        p_effective_date := '2024-01-01',
        p_reason := 'Maximum raise test',
        p_affected_count := v_count6,
        p_total_increase := v_total6
    );
    
    CREATE TEMP TABLE IF NOT EXISTS tc6_output (test_case TEXT, check_type TEXT, affected_count INT, total_increase NUMERIC(18,2));
    INSERT INTO tc6_output VALUES ('TC6', 'output_params', v_count6, v_total6);
END $$;

-- ASSERT
SELECT 'TC6' AS test_case, 'output_params' AS check_type, affected_count, total_increase FROM tc6_output;
SELECT 'TC6' AS test_case, 'salary_check' AS check_type, employee_id, salary 
FROM public.employees;

-- CLEANUP
DROP TABLE IF EXISTS tc6_output;
DROP TABLE IF EXISTS public.employees CASCADE;
DROP TABLE IF EXISTS test_employees_tc6;

-- ============= TEST CASE 7: Exception - Neither percentage nor amount specified =============
-- SETUP
-- No setup needed for this test

-- EXEC & ASSERT
DO $$
DECLARE
    v_count7 INT := 0;
    v_total7 NUMERIC(18,2) := 0.00;
    v_error_message TEXT;
BEGIN
    BEGIN
        CALL public.usp_propagate_salary_raise(
            p_department_id := NULL,
            p_raise_percentage := NULL,
            p_raise_amount := NULL,
            p_effective_date := '2024-01-01',
            p_reason := 'Error test',
            p_affected_count := v_count7,
            p_total_increase := v_total7
        );
        
        CREATE TEMP TABLE IF NOT EXISTS tc7_output (test_case TEXT, result TEXT);
        INSERT INTO tc7_output VALUES ('TC7', 'NO_ERROR');
    EXCEPTION
        WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
            CREATE TEMP TABLE IF NOT EXISTS tc7_output (test_case TEXT, result TEXT);
            INSERT INTO tc7_output VALUES ('TC7', v_error_message);
    END;
END $$;

SELECT * FROM tc7_output;

-- CLEANUP
DROP TABLE IF EXISTS tc7_output;

-- ============= TEST CASE 8: Exception - Both percentage and amount specified =============
-- SETUP
-- No setup needed for this test

-- EXEC & ASSERT
DO $$
DECLARE
    v_count8 INT := 0;
    v_total8 NUMERIC(18,2) := 0.00;
    v_error_message TEXT;
BEGIN
    BEGIN
        CALL public.usp_propagate_salary_raise(
            p_department_id := NULL,
            p_raise_percentage := 10.00,
            p_raise_amount := 5000.00,
            p_effective_date := '2024-01-01',
            p_reason := 'Error test',
            p_affected_count := v_count8,
            p_total_increase := v_total8
        );
        
        CREATE TEMP TABLE IF NOT EXISTS tc8_output (test_case TEXT, result TEXT);
        INSERT INTO tc8_output VALUES ('TC8', 'NO_ERROR');
    EXCEPTION
        WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
            CREATE TEMP TABLE IF NOT EXISTS tc8_output (test_case TEXT, result TEXT);
            INSERT INTO tc8_output VALUES ('TC8', v_error_message);
    END;
END $$;

SELECT * FROM tc8_output;

-- CLEANUP
DROP TABLE IF EXISTS tc8_output;

-- ============= TEST CASE 9: Exception - Raise percentage exceeds maximum (>20%) =============
-- SETUP
-- No setup needed for this test

-- EXEC & ASSERT
DO $$
DECLARE
    v_count9 INT := 0;
    v_total9 NUMERIC(18,2) := 0.00;
    v_error_message TEXT;
BEGIN
    BEGIN
        CALL public.usp_propagate_salary_raise(
            p_department_id := NULL,
            p_raise_percentage := 25.00,
            p_raise_amount := NULL,
            p_effective_date := '2024-01-01',
            p_reason := 'Error test',
            p_affected_count := v_count9,
            p_total_increase := v_total9
        );
        
        CREATE TEMP TABLE IF NOT EXISTS tc9_output (test_case TEXT, result TEXT);
        INSERT INTO tc9_output VALUES ('TC9', 'NO_ERROR');
    EXCEPTION
        WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
            CREATE TEMP TABLE IF NOT EXISTS tc9_output (test_case TEXT, result TEXT);
            INSERT INTO tc9_output VALUES ('TC9', v_error_message);
    END;
END $$;

SELECT * FROM tc9_output;

-- CLEANUP
DROP TABLE IF EXISTS tc9_output;

-- ============= TEST CASE 10: Exception - Negative raise percentage =============
-- SETUP
-- No setup needed for this test

-- EXEC & ASSERT
DO $$
DECLARE
    v_count10 INT := 0;
    v_total10 NUMERIC(18,2) := 0.00;
    v_error_message TEXT;
BEGIN
    BEGIN
        CALL public.usp_propagate_salary_raise(
            p_department_id := NULL,
            p_raise_percentage := -5.00,
            p_raise_amount := NULL,
            p_effective_date := '2024-01-01',
            p_reason := 'Error test',
            p_affected_count := v_count10,
            p_total_increase := v_total10
        );
        
        CREATE TEMP TABLE IF NOT EXISTS tc10_output (test_case TEXT, result TEXT);
        INSERT INTO tc10_output VALUES ('TC10', 'NO_ERROR');
    EXCEPTION
        WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
            CREATE TEMP TABLE IF NOT EXISTS tc10_output (test_case TEXT, result TEXT);
            INSERT INTO tc10_output VALUES ('TC10', v_error_message);
    END;
END $$;

SELECT * FROM tc10_output;

-- CLEANUP
DROP TABLE IF EXISTS tc10_output;

-- ============= TEST CASE 11: Exception - Negative raise amount =============
-- SETUP
-- No setup needed for this test

-- EXEC & ASSERT
DO $$
DECLARE
    v_count11 INT := 0;
    v_total11 NUMERIC(18,2) := 0.00;
    v_error_message TEXT;
BEGIN
    BEGIN
        CALL public.usp_propagate_salary_raise(
            p_department_id := NULL,
            p_raise_percentage := NULL,
            p_raise_amount := -1000.00,
            p_effective_date := '2024-01-01',
            p_reason := 'Error test',
            p_affected_count := v_count11,
            p_total_increase := v_total11
        );
        
        CREATE TEMP TABLE IF NOT EXISTS tc11_output (test_case TEXT, result TEXT);
        INSERT INTO tc11_output VALUES ('TC11', 'NO_ERROR');
    EXCEPTION
        WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
            CREATE TEMP TABLE IF NOT EXISTS tc11_output (test_case TEXT, result TEXT);
            INSERT INTO tc11_output VALUES ('TC11', v_error_message);
    END;
END $$;

SELECT * FROM tc11_output;

-- CLEANUP
DROP TABLE IF EXISTS tc11_output;

-- ============= TEST CASE 12: Transaction - Verify rollback on error =============
-- SETUP
CREATE TEMPORARY TABLE test_employees_tc12 (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    department_id INT,
    salary NUMERIC(18,2),
    hire_date DATE,
    last_raise_date DATE,
    is_active BOOLEAN
);

INSERT INTO test_employees_tc12 (employee_id, first_name, last_name, department_id, salary, hire_date, last_raise_date, is_active)
VALUES 
    (12001, 'Jack', 'King', 10, 50000.00, '2020-01-01', '2023-01-01', true);

CREATE TABLE public.employees (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    department_id INT,
    salary NUMERIC(18,2),
    hire_date DATE,
    last_raise_date DATE,
    is_active BOOLEAN
);

INSERT INTO public.employees SELECT * FROM test_employees_tc12;

-- Record original salary
DO $$
DECLARE
    v_original_salary_tc12 NUMERIC(18,2);
    v_count12 INT := 0;
    v_total12 NUMERIC(18,2) := 0.00;
    v_current_salary NUMERIC(18,2);
    v_result TEXT;
BEGIN
    SELECT salary INTO v_original_salary_tc12 FROM public.employees WHERE employee_id = 12001;
    
    -- EXEC (this should fail due to invalid input)
    BEGIN
        CALL public.usp_propagate_salary_raise(
            p_department_id := NULL,
            p_raise_percentage := NULL,
            p_raise_amount := NULL,
            p_effective_date := '2024-01-01',
            p_reason := 'Rollback test',
            p_affected_count := v_count12,
            p_total_increase := v_total12
        );
    EXCEPTION
        WHEN OTHERS THEN
            -- Error expected, continue
            NULL;
    END;
    
    -- ASSERT - salary should remain unchanged
    SELECT salary INTO v_current_salary FROM public.employees WHERE employee_id = 12001;
    
    IF v_current_salary = v_original_salary_tc12 THEN
        v_result := 'ROLLBACK_SUCCESS';
    ELSE
        v_result := 'ROLLBACK_FAILED';
    END IF;
    
    CREATE TEMP TABLE IF NOT EXISTS tc12_output (test_case TEXT, result TEXT);
    INSERT INTO tc12_output VALUES ('TC12', v_result);
END $$;

-- ASSERT
SELECT * FROM tc12_output;

-- CLEANUP
DROP TABLE IF EXISTS tc12_output;
DROP TABLE IF EXISTS public.employees CASCADE;
DROP TABLE IF EXISTS test_employees_tc12;

-- ============================================================================
-- End of Test Suite
-- ============================================================================
