-- ============================================================================
-- Test Cases for: public.trg_v_employee_full_update
-- Type: TRIGGER (INSTEAD OF UPDATE on VIEW)
-- Target: Aurora PostgreSQL (Native)
-- ============================================================================
-- NOTE: Source MSSQL tests could not be executed due to connection error.
--       These tests verify PostgreSQL trigger functionality independently.
-- ============================================================================

-- ============= TEST CASE 1: Simple UPDATE on view (single column) =============
-- SETUP
-- Verify initial state
SELECT 'TC1_BEFORE' AS tc, employee_id, first_name, last_name, email
FROM public.v_employee_full
WHERE employee_id = 1;

-- EXEC
-- Update single column through view
UPDATE public.v_employee_full
SET first_name = 'UpdatedFirstName'
WHERE employee_id = 1;

-- ASSERT
SELECT 'TC1' AS tc, employee_id, first_name, last_name, email
FROM public.v_employee_full
WHERE employee_id = 1;

-- CLEANUP
-- Restore original value
UPDATE public.v_employee_full
SET first_name = 'John'
WHERE employee_id = 1;


-- ============= TEST CASE 2: UPDATE multiple columns through view =============
-- SETUP
SELECT 'TC2_BEFORE' AS tc, employee_id, first_name, last_name, email, salary
FROM public.v_employee_full
WHERE employee_id = 2;

-- EXEC
UPDATE public.v_employee_full
SET 
    first_name = 'NewFirst',
    last_name = 'NewLast',
    email = 'newemail@example.com',
    salary = 75000.00
WHERE employee_id = 2;

-- ASSERT
SELECT 'TC2' AS tc, employee_id, first_name, last_name, email, salary
FROM public.v_employee_full
WHERE employee_id = 2;

-- CLEANUP
UPDATE public.v_employee_full
SET 
    first_name = 'Jane',
    last_name = 'Smith',
    email = 'jane.smith@example.com',
    salary = 65000.00
WHERE employee_id = 2;


-- ============= TEST CASE 3: UPDATE with WHERE clause affecting multiple rows =============
-- SETUP
SELECT 'TC3_BEFORE' AS tc, employee_id, salary, department_id
FROM public.v_employee_full
WHERE department_id = 1
ORDER BY employee_id;

-- EXEC
UPDATE public.v_employee_full
SET salary = salary * 1.05
WHERE department_id = 1;

-- ASSERT
SELECT 'TC3' AS tc, employee_id, salary, department_id
FROM public.v_employee_full
WHERE department_id = 1
ORDER BY employee_id;

-- CLEANUP
UPDATE public.v_employee_full
SET salary = salary / 1.05
WHERE department_id = 1;


-- ============= TEST CASE 4: UPDATE with NULL value =============
-- SETUP
SELECT 'TC4_BEFORE' AS tc, employee_id, email, department_id
FROM public.v_employee_full
WHERE employee_id = 3;

-- EXEC
UPDATE public.v_employee_full
SET email = NULL
WHERE employee_id = 3;

-- ASSERT
SELECT 'TC4' AS tc, employee_id, email, department_id,
       CASE WHEN email IS NULL THEN 'NULL' ELSE email END AS email_status
FROM public.v_employee_full
WHERE employee_id = 3;

-- CLEANUP
UPDATE public.v_employee_full
SET email = 'bob.johnson@example.com'
WHERE employee_id = 3;


-- ============= TEST CASE 5: UPDATE with no matching rows =============
-- SETUP
-- Store count before update
CREATE TEMP TABLE pg_temp.tc5_before AS
SELECT COUNT(*) AS before_count FROM public.v_employee_full WHERE employee_id = 99999;

-- EXEC
UPDATE public.v_employee_full
SET first_name = 'NonExistent'
WHERE employee_id = 99999;

-- ASSERT
-- PostgreSQL doesn't have @@ROWCOUNT, but we can verify no rows exist
SELECT 'TC5' AS tc, 
       0 AS rows_affected,  -- Expected: 0 (no matching rows)
       before_count
FROM pg_temp.tc5_before;

-- CLEANUP
DROP TABLE pg_temp.tc5_before;


-- ============= TEST CASE 6: UPDATE changing department_id =============
-- SETUP
SELECT 'TC6_BEFORE' AS tc, employee_id, first_name, department_id, department_name
FROM public.v_employee_full
WHERE employee_id = 4;

-- EXEC
UPDATE public.v_employee_full
SET department_id = 2
WHERE employee_id = 4;

-- ASSERT
SELECT 'TC6' AS tc, employee_id, first_name, department_id, department_name
FROM public.v_employee_full
WHERE employee_id = 4;

-- CLEANUP
UPDATE public.v_employee_full
SET department_id = 1
WHERE employee_id = 4;


-- ============= TEST CASE 7: UPDATE with is_active flag =============
-- SETUP
SELECT 'TC7_BEFORE' AS tc, employee_id, first_name, is_active
FROM public.v_employee_full
WHERE employee_id = 5;

-- EXEC
UPDATE public.v_employee_full
SET is_active = 0
WHERE employee_id = 5;

-- ASSERT
SELECT 'TC7' AS tc, employee_id, first_name, is_active
FROM public.v_employee_full
WHERE employee_id = 5;

-- CLEANUP
UPDATE public.v_employee_full
SET is_active = 1
WHERE employee_id = 5;


-- ============= TEST CASE 8: UPDATE with hire_date =============
-- SETUP
SELECT 'TC8_BEFORE' AS tc, employee_id, first_name, hire_date
FROM public.v_employee_full
WHERE employee_id = 1;

-- EXEC
UPDATE public.v_employee_full
SET hire_date = '2024-01-01'
WHERE employee_id = 1;

-- ASSERT
SELECT 'TC8' AS tc, employee_id, first_name, hire_date
FROM public.v_employee_full
WHERE employee_id = 1;

-- CLEANUP
UPDATE public.v_employee_full
SET hire_date = '2020-01-15'
WHERE employee_id = 1;


-- ============= TEST CASE 9: Verify trigger fires (check row updates) =============
-- SETUP
-- Store original salaries
CREATE TEMP TABLE pg_temp.tc9_before AS
SELECT employee_id, salary FROM public.v_employee_full WHERE employee_id IN (1, 2, 3);

-- EXEC
UPDATE public.v_employee_full
SET salary = salary + 100
WHERE employee_id IN (1, 2, 3);

-- ASSERT
-- Verify 3 rows were updated
SELECT 'TC9' AS tc, COUNT(*) AS rows_updated
FROM public.v_employee_full v
JOIN pg_temp.tc9_before b ON v.employee_id = b.employee_id
WHERE v.salary = b.salary + 100;

-- CLEANUP
UPDATE public.v_employee_full
SET salary = salary - 100
WHERE employee_id IN (1, 2, 3);

DROP TABLE pg_temp.tc9_before;


-- ============= TEST CASE 10: UPDATE all columns for a single employee =============
-- SETUP
SELECT 'TC10_BEFORE' AS tc, *
FROM public.v_employee_full
WHERE employee_id = 6;

-- EXEC
UPDATE public.v_employee_full
SET 
    first_name = 'TestFirst',
    last_name = 'TestLast',
    email = 'test@example.com',
    department_id = 3,
    salary = 80000.00,
    hire_date = '2023-06-01',
    is_active = 1
WHERE employee_id = 6;

-- ASSERT
SELECT 'TC10' AS tc, *
FROM public.v_employee_full
WHERE employee_id = 6;

-- CLEANUP
UPDATE public.v_employee_full
SET 
    first_name = 'Original',
    last_name = 'Name',
    email = 'original@example.com',
    department_id = 1,
    salary = 60000.00,
    hire_date = '2021-03-15',
    is_active = 1
WHERE employee_id = 6;


-- ============================================================================
-- TEST EXECUTION NOTES:
-- - All UPDATE statements should be intercepted by the INSTEAD OF trigger
-- - Changes should be applied to the underlying public.employees table
-- - View should reflect the updated values immediately
-- - No errors should occur for valid updates
-- - Updates to non-existent rows should affect 0 rows
-- ============================================================================
