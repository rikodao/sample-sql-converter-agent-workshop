-- ============================================================
-- TEST CASES for TRIGGER: public.trg_v_employee_full_update
-- PostgreSQL Native Version
-- ============================================================
-- This trigger is an INSTEAD OF UPDATE trigger on view public.v_employee_full
-- It updates the underlying public.employees table when the view is updated
--
-- Test Coverage:
-- - Normal UPDATE operations (single and multiple rows)
-- - Boundary values (NULL, empty strings, boolean toggles)
-- - Edge cases (non-existent employee_id, no matching rows)
-- - Transaction behavior (ROLLBACK scenarios)
-- - Side effects (verify actual table updates)
-- ============================================================

-- ============= TEST CASE 1: Single Row Update - Normal Case =============
-- SETUP
BEGIN;

-- Insert test employee
INSERT INTO public.employees (first_name, last_name, email, hire_date, department_id, is_active)
VALUES ('TestFirst1', 'TestLast1', 'test1@example.com', '2024-01-01', 1, 1);

-- Get the inserted employee_id
DO $$
DECLARE
    test_emp_id1 INT;
BEGIN
    SELECT employee_id INTO test_emp_id1 
    FROM public.employees 
    WHERE email = 'test1@example.com' 
    ORDER BY employee_id DESC LIMIT 1;
    
    -- Store in temp table for later use
    CREATE TEMP TABLE IF NOT EXISTS temp_test_ids (
        test_case VARCHAR(10),
        emp_id INT
    );
    INSERT INTO temp_test_ids VALUES ('TC1', test_emp_id1);
END $$;

-- EXEC
-- Update via the view (trigger will fire)
UPDATE public.v_employee_full
SET first_name = 'UpdatedFirst1',
    last_name = 'UpdatedLast1',
    email = 'updated1@example.com',
    is_active = 0
WHERE employee_id = (SELECT emp_id FROM temp_test_ids WHERE test_case = 'TC1');

-- ASSERT
SELECT 'TC1' AS tc, 
       first_name, 
       last_name, 
       email, 
       is_active,
       'Single row updated successfully' AS description
FROM public.employees
WHERE employee_id = (SELECT emp_id FROM temp_test_ids WHERE test_case = 'TC1');

-- CLEANUP
ROLLBACK;
DROP TABLE IF EXISTS temp_test_ids;

-- ============= TEST CASE 2: Multiple Rows Update =============
-- SETUP
BEGIN;

-- Insert multiple test employees
INSERT INTO public.employees (first_name, last_name, email, hire_date, department_id, is_active)
VALUES 
    ('TestFirst2A', 'TestLast2A', 'test2a@example.com', '2024-01-01', 1, 1),
    ('TestFirst2B', 'TestLast2B', 'test2b@example.com', '2024-01-01', 1, 1),
    ('TestFirst2C', 'TestLast2C', 'test2c@example.com', '2024-01-01', 1, 1);

-- Store IDs
CREATE TEMP TABLE temp_test_ids2 AS
SELECT employee_id 
FROM public.employees 
WHERE email IN ('test2a@example.com', 'test2b@example.com', 'test2c@example.com')
ORDER BY employee_id;

-- EXEC
-- Update multiple rows via the view
UPDATE public.v_employee_full
SET is_active = 0
WHERE employee_id IN (SELECT employee_id FROM temp_test_ids2);

-- ASSERT
SELECT 'TC2' AS tc,
       COUNT(*) AS updated_count,
       SUM(CASE WHEN is_active = 0 THEN 1 ELSE 0 END) AS inactive_count,
       'Multiple rows updated' AS description
FROM public.employees
WHERE employee_id IN (SELECT employee_id FROM temp_test_ids2);

-- CLEANUP
ROLLBACK;
DROP TABLE IF EXISTS temp_test_ids2;

-- ============= TEST CASE 3: Update with NULL email (Boundary) =============
-- SETUP
BEGIN;

INSERT INTO public.employees (first_name, last_name, email, hire_date, department_id, is_active)
VALUES ('TestFirst3', 'TestLast3', 'test3@example.com', '2024-01-01', 1, 1);

CREATE TEMP TABLE temp_test_ids3 AS
SELECT employee_id 
FROM public.employees 
WHERE email = 'test3@example.com'
ORDER BY employee_id DESC LIMIT 1;

-- EXEC
-- Update email to NULL via view
UPDATE public.v_employee_full
SET email = NULL
WHERE employee_id = (SELECT employee_id FROM temp_test_ids3);

-- ASSERT
SELECT 'TC3' AS tc,
       first_name,
       last_name,
       CASE WHEN email IS NULL THEN 'NULL' ELSE email END AS email,
       'Email set to NULL' AS description
FROM public.employees
WHERE employee_id = (SELECT employee_id FROM temp_test_ids3);

-- CLEANUP
ROLLBACK;
DROP TABLE IF EXISTS temp_test_ids3;

-- ============= TEST CASE 4: Update with Empty String (Boundary) =============
-- SETUP
BEGIN;

INSERT INTO public.employees (first_name, last_name, email, hire_date, department_id, is_active)
VALUES ('TestFirst4', 'TestLast4', 'test4@example.com', '2024-01-01', 1, 1);

CREATE TEMP TABLE temp_test_ids4 AS
SELECT employee_id 
FROM public.employees 
WHERE email = 'test4@example.com'
ORDER BY employee_id DESC LIMIT 1;

-- EXEC
-- Update first_name to empty string via view
UPDATE public.v_employee_full
SET first_name = '',
    last_name = ''
WHERE employee_id = (SELECT employee_id FROM temp_test_ids4);

-- ASSERT
SELECT 'TC4' AS tc,
       CASE WHEN first_name = '' THEN 'EMPTY' ELSE first_name END AS first_name,
       CASE WHEN last_name = '' THEN 'EMPTY' ELSE last_name END AS last_name,
       email,
       'Names set to empty string' AS description
FROM public.employees
WHERE employee_id = (SELECT employee_id FROM temp_test_ids4);

-- CLEANUP
ROLLBACK;
DROP TABLE IF EXISTS temp_test_ids4;

-- ============= TEST CASE 5: Toggle is_active Flag (Boundary) =============
-- SETUP
BEGIN;

INSERT INTO public.employees (first_name, last_name, email, hire_date, department_id, is_active)
VALUES ('TestFirst5', 'TestLast5', 'test5@example.com', '2024-01-01', 1, 1);

CREATE TEMP TABLE temp_test_ids5 AS
SELECT employee_id 
FROM public.employees 
WHERE email = 'test5@example.com'
ORDER BY employee_id DESC LIMIT 1;

-- EXEC
-- Toggle is_active from 1 to 0
UPDATE public.v_employee_full
SET is_active = 0
WHERE employee_id = (SELECT employee_id FROM temp_test_ids5);

-- ASSERT (First check)
SELECT 'TC5_Step1' AS tc,
       is_active,
       'After first toggle (1->0)' AS description
FROM public.employees
WHERE employee_id = (SELECT employee_id FROM temp_test_ids5);

-- Toggle back from 0 to 1
UPDATE public.v_employee_full
SET is_active = 1
WHERE employee_id = (SELECT employee_id FROM temp_test_ids5);

-- ASSERT (Second check)
SELECT 'TC5_Step2' AS tc,
       is_active,
       'After second toggle (0->1)' AS description
FROM public.employees
WHERE employee_id = (SELECT employee_id FROM temp_test_ids5);

-- CLEANUP
ROLLBACK;
DROP TABLE IF EXISTS temp_test_ids5;

-- ============= TEST CASE 6: Update Non-Existent Employee (Edge Case) =============
-- SETUP
BEGIN;

-- Find a non-existent employee_id
DO $$
DECLARE
    non_existent_id INT := 999999;
    rows_affected INT;
BEGIN
    -- Try to update non-existent employee via view
    UPDATE public.v_employee_full
    SET first_name = 'NonExistent'
    WHERE employee_id = non_existent_id;
    
    GET DIAGNOSTICS rows_affected = ROW_COUNT;
    
    -- Store result in temp table
    CREATE TEMP TABLE IF NOT EXISTS temp_tc6_result (
        tc VARCHAR(10),
        rows_affected INT,
        description TEXT
    );
    INSERT INTO temp_tc6_result VALUES ('TC6', rows_affected, 'No rows should be affected');
END $$;

-- ASSERT
SELECT tc, rows_affected, description
FROM temp_tc6_result;

-- CLEANUP
ROLLBACK;
DROP TABLE IF EXISTS temp_tc6_result;

-- ============= TEST CASE 7: Update with WHERE Clause Matching No Rows =============
-- SETUP
BEGIN;

INSERT INTO public.employees (first_name, last_name, email, hire_date, department_id, is_active)
VALUES ('TestFirst7', 'TestLast7', 'test7@example.com', '2024-01-01', 1, 1);

CREATE TEMP TABLE temp_test_ids7 AS
SELECT employee_id 
FROM public.employees 
WHERE email = 'test7@example.com'
ORDER BY employee_id DESC LIMIT 1;

-- EXEC
-- Update with WHERE clause that matches no rows
UPDATE public.v_employee_full
SET first_name = 'ShouldNotUpdate'
WHERE employee_id = (SELECT employee_id FROM temp_test_ids7) 
  AND first_name = 'NonMatchingName';

-- ASSERT
SELECT 'TC7' AS tc,
       first_name,
       'Original name should remain' AS description
FROM public.employees
WHERE employee_id = (SELECT employee_id FROM temp_test_ids7);

-- CLEANUP
ROLLBACK;
DROP TABLE IF EXISTS temp_test_ids7;

-- ============= TEST CASE 8: Verify ROW_COUNT After Update (Side Effect) =============
-- SETUP
BEGIN;

INSERT INTO public.employees (first_name, last_name, email, hire_date, department_id, is_active)
VALUES 
    ('TestFirst8A', 'TestLast8A', 'test8a@example.com', '2024-01-01', 1, 1),
    ('TestFirst8B', 'TestLast8B', 'test8b@example.com', '2024-01-01', 1, 1);

CREATE TEMP TABLE temp_test_ids8 AS
SELECT employee_id 
FROM public.employees 
WHERE email IN ('test8a@example.com', 'test8b@example.com')
ORDER BY employee_id;

-- EXEC
DO $$
DECLARE
    rowcount_result INT;
BEGIN
    UPDATE public.v_employee_full
    SET email = 'updated8@example.com'
    WHERE employee_id IN (SELECT employee_id FROM temp_test_ids8);
    
    GET DIAGNOSTICS rowcount_result = ROW_COUNT;
    
    CREATE TEMP TABLE IF NOT EXISTS temp_tc8_result (
        tc VARCHAR(10),
        row_count INT,
        description TEXT
    );
    INSERT INTO temp_tc8_result VALUES ('TC8', rowcount_result, 'Should be 2');
END $$;

-- ASSERT
SELECT tc, row_count, description
FROM temp_tc8_result;

-- CLEANUP
ROLLBACK;
DROP TABLE IF EXISTS temp_test_ids8;
DROP TABLE IF EXISTS temp_tc8_result;

-- ============= TEST CASE 9: Transaction Rollback Behavior =============
-- SETUP
BEGIN;

INSERT INTO public.employees (first_name, last_name, email, hire_date, department_id, is_active)
VALUES ('TestFirst9', 'TestLast9', 'test9@example.com', '2024-01-01', 1, 1);

CREATE TEMP TABLE temp_test_ids9 AS
SELECT employee_id 
FROM public.employees 
WHERE email = 'test9@example.com'
ORDER BY employee_id DESC LIMIT 1;

-- Store original values
DO $$
DECLARE
    original_first_name VARCHAR(50);
    updated_name VARCHAR(50);
    test_emp_id9 INT;
BEGIN
    SELECT employee_id INTO test_emp_id9 FROM temp_test_ids9;
    SELECT first_name INTO original_first_name FROM public.employees WHERE employee_id = test_emp_id9;
    
    -- EXEC: Update via view
    UPDATE public.v_employee_full
    SET first_name = 'RolledBackName'
    WHERE employee_id = test_emp_id9;
    
    -- Verify update happened
    SELECT first_name INTO updated_name FROM public.employees WHERE employee_id = test_emp_id9;
    
    -- Store results
    CREATE TEMP TABLE IF NOT EXISTS temp_tc9_result (
        tc VARCHAR(10),
        original_value TEXT,
        during_transaction TEXT,
        description TEXT
    );
    INSERT INTO temp_tc9_result VALUES (
        'TC9',
        CASE WHEN original_first_name = 'TestFirst9' THEN 'ORIGINAL' ELSE 'UNEXPECTED' END,
        CASE WHEN updated_name = 'RolledBackName' THEN 'UPDATED' ELSE 'NOT_UPDATED' END,
        'Rollback should revert changes'
    );
END $$;

-- ASSERT
SELECT tc, original_value, during_transaction, description
FROM temp_tc9_result;

-- CLEANUP (Rollback)
ROLLBACK;
DROP TABLE IF EXISTS temp_test_ids9;
DROP TABLE IF EXISTS temp_tc9_result;

-- ============= TEST CASE 10: Update All Columns Simultaneously =============
-- SETUP
BEGIN;

INSERT INTO public.employees (first_name, last_name, email, hire_date, department_id, is_active)
VALUES ('TestFirst10', 'TestLast10', 'test10@example.com', '2024-01-01', 1, 1);

CREATE TEMP TABLE temp_test_ids10 AS
SELECT employee_id 
FROM public.employees 
WHERE email = 'test10@example.com'
ORDER BY employee_id DESC LIMIT 1;

-- EXEC
-- Update all updatable columns at once
UPDATE public.v_employee_full
SET first_name = 'AllUpdatedFirst',
    last_name = 'AllUpdatedLast',
    email = 'allupdated@example.com',
    is_active = 0
WHERE employee_id = (SELECT employee_id FROM temp_test_ids10);

-- ASSERT
SELECT 'TC10' AS tc,
       first_name,
       last_name,
       email,
       is_active,
       'All columns updated' AS description
FROM public.employees
WHERE employee_id = (SELECT employee_id FROM temp_test_ids10);

-- CLEANUP
ROLLBACK;
DROP TABLE IF EXISTS temp_test_ids10;

-- ============= TEST CASE 11: Partial Column Update =============
-- SETUP
BEGIN;

INSERT INTO public.employees (first_name, last_name, email, hire_date, department_id, is_active)
VALUES ('TestFirst11', 'TestLast11', 'test11@example.com', '2024-01-01', 1, 1);

CREATE TEMP TABLE temp_test_ids11 AS
SELECT employee_id 
FROM public.employees 
WHERE email = 'test11@example.com'
ORDER BY employee_id DESC LIMIT 1;

-- EXEC
-- Update only email column
UPDATE public.v_employee_full
SET email = 'partial11@example.com'
WHERE employee_id = (SELECT employee_id FROM temp_test_ids11);

-- ASSERT
SELECT 'TC11' AS tc,
       first_name,
       last_name,
       email,
       is_active,
       'Only email should change' AS description
FROM public.employees
WHERE employee_id = (SELECT employee_id FROM temp_test_ids11);

-- CLEANUP
ROLLBACK;
DROP TABLE IF EXISTS temp_test_ids11;

-- ============= TEST CASE 12: Update with Special Characters in Strings =============
-- SETUP
BEGIN;

INSERT INTO public.employees (first_name, last_name, email, hire_date, department_id, is_active)
VALUES ('TestFirst12', 'TestLast12', 'test12@example.com', '2024-01-01', 1, 1);

CREATE TEMP TABLE temp_test_ids12 AS
SELECT employee_id 
FROM public.employees 
WHERE email = 'test12@example.com'
ORDER BY employee_id DESC LIMIT 1;

-- EXEC
-- Update with special characters
UPDATE public.v_employee_full
SET first_name = 'O''Brien',
    last_name = 'Test-Last',
    email = 'test+special@example.com'
WHERE employee_id = (SELECT employee_id FROM temp_test_ids12);

-- ASSERT
SELECT 'TC12' AS tc,
       first_name,
       last_name,
       email,
       'Special characters handled' AS description
FROM public.employees
WHERE employee_id = (SELECT employee_id FROM temp_test_ids12);

-- CLEANUP
ROLLBACK;
DROP TABLE IF EXISTS temp_test_ids12;
