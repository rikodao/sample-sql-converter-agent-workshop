-- ============================================================================
-- Test Suite for: public.usp_dynamic_count_with_output
-- Database: PostgreSQL
-- ============================================================================
-- This test suite covers:
-- - Normal cases: valid table names with/without WHERE clause
-- - Boundary cases: NULL inputs, empty strings, non-existent tables
-- - Exception cases: SQL injection attempts, invalid WHERE clauses
-- - OUTPUT parameter validation
-- ============================================================================

-- ============= SETUP: Create test tables =============
-- Create employees table for testing
CREATE TEMPORARY TABLE employees (
    employee_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    department_id INT,
    manager_id INT,
    salary NUMERIC(10,2),
    hire_date DATE,
    is_active BOOLEAN DEFAULT TRUE
);

-- Create departments table for testing
CREATE TEMPORARY TABLE departments (
    department_id SERIAL PRIMARY KEY,
    department_name VARCHAR(100)
);

-- Insert test data into employees
INSERT INTO employees (first_name, last_name, department_id, manager_id, salary, hire_date, is_active)
VALUES
    ('John', 'Doe', 1, NULL, 75000, '2019-01-15', TRUE),
    ('Jane', 'Smith', 1, 1, 65000, '2020-03-20', TRUE),
    ('Bob', 'Johnson', 2, 1, 55000, '2018-06-10', TRUE),
    ('Alice', 'Williams', 2, 1, 48000, '2021-09-05', FALSE),
    ('Charlie', 'Brown', 3, 1, 52000, '2020-11-12', TRUE),
    ('David', 'Jones', 1, 2, 60000, '2022-02-28', TRUE),
    ('Emma', 'Davis', 3, 1, 45000, '2019-07-18', TRUE),
    ('Frank', 'Miller', 2, 3, 51000, '2021-04-22', TRUE),
    ('Grace', 'Wilson', 1, 2, 70000, '2017-12-01', TRUE),
    ('Henry', 'Moore', 3, 1, 49000, '2020-08-15', FALSE);

-- Insert test data into departments
INSERT INTO departments (department_name)
VALUES
    ('Engineering'),
    ('Sales'),
    ('Marketing');

-- ============================================================================


-- ============= TEST CASE 1: Count all records from employees table =============
-- EXEC
DO $$
DECLARE
    v_count1 INT := 0;
BEGIN
    CALL public.usp_dynamic_count_with_output(
        p_table_name := 'employees',
        p_where_clause := NULL,
        p_record_count := v_count1
    );
    
    -- ASSERT
    RAISE NOTICE 'TC1|%|Count all employees', v_count1;
END $$;


-- ============= TEST CASE 2: Count with WHERE clause (active employees) =============
-- EXEC
DO $$
DECLARE
    v_count2 INT := 0;
BEGIN
    CALL public.usp_dynamic_count_with_output(
        p_table_name := 'employees',
        p_where_clause := 'is_active = TRUE',
        p_record_count := v_count2
    );
    
    -- ASSERT
    RAISE NOTICE 'TC2|%|Count active employees', v_count2;
END $$;


-- ============= TEST CASE 3: Count from departments table =============
-- EXEC
DO $$
DECLARE
    v_count3 INT := 0;
BEGIN
    CALL public.usp_dynamic_count_with_output(
        p_table_name := 'departments',
        p_where_clause := NULL,
        p_record_count := v_count3
    );
    
    -- ASSERT
    RAISE NOTICE 'TC3|%|Count all departments', v_count3;
END $$;


-- ============= TEST CASE 4: Count with complex WHERE clause =============
-- EXEC
DO $$
DECLARE
    v_count4 INT := 0;
BEGIN
    CALL public.usp_dynamic_count_with_output(
        p_table_name := 'employees',
        p_where_clause := 'salary > 50000 AND department_id = 1',
        p_record_count := v_count4
    );
    
    -- ASSERT
    RAISE NOTICE 'TC4|%|Count employees with salary > 50000 in dept 1', v_count4;
END $$;


-- ============= TEST CASE 5: NULL table name (should raise error) =============
-- EXEC & ASSERT
DO $$
DECLARE
    v_count5 INT := 0;
    v_error_msg TEXT;
BEGIN
    BEGIN
        CALL public.usp_dynamic_count_with_output(
            p_table_name := NULL,
            p_where_clause := NULL,
            p_record_count := v_count5
        );
        RAISE NOTICE 'TC5|NO_ERROR|%', v_count5;
    EXCEPTION
        WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS v_error_msg = MESSAGE_TEXT;
            RAISE NOTICE 'TC5|ERROR_CAUGHT|%', v_error_msg;
    END;
END $$;


-- ============= TEST CASE 6: Empty string table name (should raise error) =============
-- EXEC & ASSERT
DO $$
DECLARE
    v_count6 INT := 0;
    v_error_msg TEXT;
BEGIN
    BEGIN
        CALL public.usp_dynamic_count_with_output(
            p_table_name := '',
            p_where_clause := NULL,
            p_record_count := v_count6
        );
        RAISE NOTICE 'TC6|NO_ERROR|%', v_count6;
    EXCEPTION
        WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS v_error_msg = MESSAGE_TEXT;
            RAISE NOTICE 'TC6|ERROR_CAUGHT|%', v_error_msg;
    END;
END $$;


-- ============= TEST CASE 7: Non-existent table (should raise error) =============
-- EXEC & ASSERT
DO $$
DECLARE
    v_count7 INT := 0;
    v_error_msg TEXT;
BEGIN
    BEGIN
        CALL public.usp_dynamic_count_with_output(
            p_table_name := 'non_existent_table_xyz',
            p_where_clause := NULL,
            p_record_count := v_count7
        );
        RAISE NOTICE 'TC7|NO_ERROR|%', v_count7;
    EXCEPTION
        WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS v_error_msg = MESSAGE_TEXT;
            RAISE NOTICE 'TC7|ERROR_CAUGHT|%', v_error_msg;
    END;
END $$;


-- ============= TEST CASE 8: Whitespace-only table name (should raise error) =============
-- EXEC & ASSERT
DO $$
DECLARE
    v_count8 INT := 0;
    v_error_msg TEXT;
BEGIN
    BEGIN
        CALL public.usp_dynamic_count_with_output(
            p_table_name := '   ',
            p_where_clause := NULL,
            p_record_count := v_count8
        );
        RAISE NOTICE 'TC8|NO_ERROR|%', v_count8;
    EXCEPTION
        WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS v_error_msg = MESSAGE_TEXT;
            RAISE NOTICE 'TC8|ERROR_CAUGHT|%', v_error_msg;
    END;
END $$;


-- ============= TEST CASE 9: Table name with leading/trailing spaces =============
-- EXEC
DO $$
DECLARE
    v_count9 INT := 0;
BEGIN
    CALL public.usp_dynamic_count_with_output(
        p_table_name := '  employees  ',
        p_where_clause := NULL,
        p_record_count := v_count9
    );
    
    -- ASSERT
    RAISE NOTICE 'TC9|%|Table name with spaces should be trimmed', v_count9;
END $$;


-- ============= TEST CASE 10: Empty WHERE clause (should count all) =============
-- EXEC
DO $$
DECLARE
    v_count10 INT := 0;
BEGIN
    CALL public.usp_dynamic_count_with_output(
        p_table_name := 'employees',
        p_where_clause := '',
        p_record_count := v_count10
    );
    
    -- ASSERT
    RAISE NOTICE 'TC10|%|Empty WHERE clause should count all', v_count10;
END $$;


-- ============= TEST CASE 11: WHERE clause with no matching records =============
-- EXEC
DO $$
DECLARE
    v_count11 INT := 0;
BEGIN
    CALL public.usp_dynamic_count_with_output(
        p_table_name := 'employees',
        p_where_clause := 'employee_id = -999999',
        p_record_count := v_count11
    );
    
    -- ASSERT
    RAISE NOTICE 'TC11|%|No matching records should return 0', v_count11;
END $$;


-- ============= TEST CASE 12: Invalid WHERE clause syntax (should raise error) =============
-- EXEC & ASSERT
DO $$
DECLARE
    v_count12 INT := 0;
    v_error_msg TEXT;
BEGIN
    BEGIN
        CALL public.usp_dynamic_count_with_output(
            p_table_name := 'employees',
            p_where_clause := 'invalid syntax here @#$',
            p_record_count := v_count12
        );
        RAISE NOTICE 'TC12|NO_ERROR|%', v_count12;
    EXCEPTION
        WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS v_error_msg = MESSAGE_TEXT;
            RAISE NOTICE 'TC12|ERROR_CAUGHT|%', v_error_msg;
    END;
END $$;


-- ============= TEST CASE 13: SQL injection attempt in table name (should be prevented) =============
-- EXEC & ASSERT
DO $$
DECLARE
    v_count13 INT := 0;
    v_error_msg TEXT;
BEGIN
    BEGIN
        CALL public.usp_dynamic_count_with_output(
            p_table_name := 'employees; DROP TABLE employees; --',
            p_where_clause := NULL,
            p_record_count := v_count13
        );
        RAISE NOTICE 'TC13|NO_ERROR|%', v_count13;
    EXCEPTION
        WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS v_error_msg = MESSAGE_TEXT;
            RAISE NOTICE 'TC13|ERROR_CAUGHT|%', v_error_msg;
    END;
END $$;


-- ============= TEST CASE 14: Count with IS NULL condition =============
-- EXEC
DO $$
DECLARE
    v_count14 INT := 0;
BEGIN
    CALL public.usp_dynamic_count_with_output(
        p_table_name := 'employees',
        p_where_clause := 'manager_id IS NULL',
        p_record_count := v_count14
    );
    
    -- ASSERT
    RAISE NOTICE 'TC14|%|Count employees with NULL manager_id', v_count14;
END $$;


-- ============= TEST CASE 15: Count with date comparison =============
-- EXEC
DO $$
DECLARE
    v_count15 INT := 0;
BEGIN
    CALL public.usp_dynamic_count_with_output(
        p_table_name := 'employees',
        p_where_clause := 'hire_date >= ''2020-01-01''',
        p_record_count := v_count15
    );
    
    -- ASSERT
    RAISE NOTICE 'TC15|%|Count employees hired since 2020', v_count15;
END $$;


-- ============= TEST CASE 16: Verify OUTPUT parameter is set to -1 on error =============
-- EXEC & ASSERT
DO $$
DECLARE
    v_count16 INT := 999; -- Initialize to non-zero value
    v_error_msg TEXT;
BEGIN
    BEGIN
        CALL public.usp_dynamic_count_with_output(
            p_table_name := 'non_existent_table',
            p_where_clause := NULL,
            p_record_count := v_count16
        );
        RAISE NOTICE 'TC16|%|Should be -1 on error', v_count16;
    EXCEPTION
        WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS v_error_msg = MESSAGE_TEXT;
            RAISE NOTICE 'TC16|%|Error caught, output should be -1', v_count16;
    END;
END $$;


-- ============= TEST CASE 17: Count with LIKE pattern =============
-- EXEC
DO $$
DECLARE
    v_count17 INT := 0;
BEGIN
    CALL public.usp_dynamic_count_with_output(
        p_table_name := 'employees',
        p_where_clause := 'first_name LIKE ''J%''',
        p_record_count := v_count17
    );
    
    -- ASSERT
    RAISE NOTICE 'TC17|%|Count employees with first name starting with J', v_count17;
END $$;


-- ============= TEST CASE 18: Count with IN clause =============
-- EXEC
DO $$
DECLARE
    v_count18 INT := 0;
BEGIN
    CALL public.usp_dynamic_count_with_output(
        p_table_name := 'employees',
        p_where_clause := 'department_id IN (1, 2, 3)',
        p_record_count := v_count18
    );
    
    -- ASSERT
    RAISE NOTICE 'TC18|%|Count employees in departments 1, 2, 3', v_count18;
END $$;


-- ============================================================================
-- CLEANUP: Drop test tables
-- ============================================================================
DROP TABLE IF EXISTS employees CASCADE;
DROP TABLE IF EXISTS departments CASCADE;

-- ============================================================================
-- End of Test Suite
-- ============================================================================
