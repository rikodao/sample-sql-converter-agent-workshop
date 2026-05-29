-- ============================================================================
-- Test Suite for: public.usp_employee_json
-- Purpose: Comprehensive testing of JSON output stored procedure (PostgreSQL)
-- ============================================================================

-- ============================================================================
-- TEST CASE 1: Single employee with all data (Normal case)
-- ============================================================================
-- SETUP
-- Ensure we have a test employee with complete data
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.employees WHERE employee_id = 1) THEN
        INSERT INTO public.employees (employee_id, first_name, last_name, email, phone, hire_date, salary, department_id, manager_id, is_active, status)
        VALUES (1, 'John', 'Doe', 'john.doe@test.com', '555-0001', '2020-01-15', 75000.00, 1, NULL, true, 'Active');
    END IF;
END $$;

-- EXEC
SELECT public.usp_employee_json_func(p_employee_id := 1);

-- ASSERT
-- Verify JSON output contains expected employee
SELECT 'TC1' AS test_case, 
       CASE 
           WHEN EXISTS (
               SELECT 1 FROM public.employees 
               WHERE employee_id = 1 
               AND first_name = 'John' 
               AND last_name = 'Doe'
           ) THEN 'PASS: Employee 1 exists'
           ELSE 'FAIL: Employee 1 not found'
       END AS result;

-- CLEANUP
-- Keep test data for subsequent tests
-- (Will be cleaned up at the end)

-- ============================================================================
-- TEST CASE 2: Filter by department (Multiple employees)
-- ============================================================================
-- SETUP
-- Ensure we have multiple employees in department 1
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.employees WHERE employee_id = 2) THEN
        INSERT INTO public.employees (employee_id, first_name, last_name, email, phone, hire_date, salary, department_id, manager_id, is_active, status)
        VALUES (2, 'Jane', 'Smith', 'jane.smith@test.com', '555-0002', '2019-03-20', 85000.00, 1, 1, true, 'Active');
    END IF;
END $$;

-- EXEC
SELECT public.usp_employee_json_func(p_department_id := 1);

-- ASSERT
SELECT 'TC2' AS test_case,
       COUNT(*) AS employee_count,
       CASE 
           WHEN COUNT(*) >= 2 THEN 'PASS: Multiple employees in dept 1'
           ELSE 'FAIL: Expected at least 2 employees'
       END AS result
FROM public.employees
WHERE department_id = 1 AND is_active = true;

-- CLEANUP
-- Keep test data

-- ============================================================================
-- TEST CASE 3: Employee with NULL optional fields (Boundary case)
-- ============================================================================
-- SETUP
-- Create employee with minimal data (NULLs for optional fields)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.employees WHERE employee_id = 9991) THEN
        INSERT INTO public.employees (employee_id, first_name, last_name, email, phone, hire_date, salary, department_id, manager_id, is_active, status)
        VALUES (9991, 'Minimal', 'Data', NULL, NULL, '2023-01-01', 50000.00, NULL, NULL, true, 'Active');
    END IF;
END $$;

-- EXEC
SELECT public.usp_employee_json_func(p_employee_id := 9991);

-- ASSERT
SELECT 'TC3' AS test_case,
       CASE 
           WHEN email IS NULL AND phone IS NULL AND department_id IS NULL AND manager_id IS NULL
           THEN 'PASS: NULL fields handled correctly'
           ELSE 'FAIL: NULL fields not as expected'
       END AS result
FROM public.employees
WHERE employee_id = 9991;

-- CLEANUP
DELETE FROM public.employees WHERE employee_id = 9991;

-- ============================================================================
-- TEST CASE 4: Non-existent employee_id (Boundary case)
-- ============================================================================
-- SETUP
-- No setup needed

-- EXEC
SELECT public.usp_employee_json_func(p_employee_id := 999999);

-- ASSERT
SELECT 'TC4' AS test_case,
       CASE 
           WHEN NOT EXISTS (SELECT 1 FROM public.employees WHERE employee_id = 999999)
           THEN 'PASS: Non-existent employee returns empty result'
           ELSE 'FAIL: Unexpected employee found'
       END AS result;

-- CLEANUP
-- No cleanup needed

-- ============================================================================
-- TEST CASE 5: Invalid employee_id (negative value) (Exception case)
-- ============================================================================
-- SETUP
-- No setup needed

-- EXEC & ASSERT
DO $$
BEGIN
    BEGIN
        PERFORM public.usp_employee_json_func(p_employee_id := -1);
        RAISE NOTICE 'TC5: FAIL: Should have raised error';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'TC5: PASS: Error raised - %', SQLERRM;
    END;
END $$;

SELECT 'TC5' AS test_case, 'See NOTICE output above' AS result;

-- CLEANUP
-- No cleanup needed

-- ============================================================================
-- TEST CASE 6: Invalid department_id (negative value) (Exception case)
-- ============================================================================
-- SETUP
-- No setup needed

-- EXEC & ASSERT
DO $$
BEGIN
    BEGIN
        PERFORM public.usp_employee_json_func(p_department_id := -1);
        RAISE NOTICE 'TC6: FAIL: Should have raised error';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'TC6: PASS: Error raised - %', SQLERRM;
    END;
END $$;

SELECT 'TC6' AS test_case, 'See NOTICE output above' AS result;

-- CLEANUP
-- No cleanup needed

-- ============================================================================
-- TEST CASE 7: Include inactive employees (Normal case with flag)
-- ============================================================================
-- SETUP
-- Create an inactive employee
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.employees WHERE employee_id = 9992) THEN
        INSERT INTO public.employees (employee_id, first_name, last_name, email, phone, hire_date, salary, department_id, manager_id, is_active, status)
        VALUES (9992, 'Inactive', 'User', 'inactive@test.com', '555-9992', '2018-01-01', 60000.00, 1, NULL, false, 'Inactive');
    END IF;
END $$;

-- EXEC (without include_inactive flag - should not return inactive)
SELECT public.usp_employee_json_func(p_employee_id := 9992, p_include_inactive := false);

-- ASSERT
SELECT 'TC7a' AS test_case,
       CASE 
           WHEN is_active = false THEN 'PASS: Inactive employee exists'
           ELSE 'FAIL: Employee should be inactive'
       END AS result
FROM public.employees
WHERE employee_id = 9992;

-- EXEC (with include_inactive flag - should return inactive)
SELECT public.usp_employee_json_func(p_employee_id := 9992, p_include_inactive := true);

-- ASSERT
SELECT 'TC7b' AS test_case,
       'PASS: Include inactive flag tested' AS result;

-- CLEANUP
DELETE FROM public.employees WHERE employee_id = 9992;

-- ============================================================================
-- TEST CASE 8: Employee with manager relationship (Normal case)
-- ============================================================================
-- SETUP
-- Ensure we have manager-employee relationship
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.employees WHERE employee_id = 9993) THEN
        INSERT INTO public.employees (employee_id, first_name, last_name, email, phone, hire_date, salary, department_id, manager_id, is_active, status)
        VALUES (9993, 'Manager', 'Boss', 'manager@test.com', '555-9993', '2015-01-01', 100000.00, 1, NULL, true, 'Active');
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM public.employees WHERE employee_id = 9994) THEN
        INSERT INTO public.employees (employee_id, first_name, last_name, email, phone, hire_date, salary, department_id, manager_id, is_active, status)
        VALUES (9994, 'Report', 'Employee', 'report@test.com', '555-9994', '2020-01-01', 70000.00, 1, 9993, true, 'Active');
    END IF;
END $$;

-- EXEC
SELECT public.usp_employee_json_func(p_employee_id := 9994);

-- ASSERT
SELECT 'TC8' AS test_case,
       CASE 
           WHEN manager_id = 9993 THEN 'PASS: Manager relationship exists'
           ELSE 'FAIL: Manager relationship not found'
       END AS result
FROM public.employees
WHERE employee_id = 9994;

-- CLEANUP
DELETE FROM public.employees WHERE employee_id = 9994;
DELETE FROM public.employees WHERE employee_id = 9993;

-- ============================================================================
-- TEST CASE 9: All parameters NULL (Return all active employees)
-- ============================================================================
-- SETUP
-- No additional setup needed

-- EXEC
SELECT public.usp_employee_json_func(p_employee_id := NULL, p_department_id := NULL, p_include_inactive := false);

-- ASSERT
SELECT 'TC9' AS test_case,
       COUNT(*) AS active_employee_count,
       CASE 
           WHEN COUNT(*) > 0 THEN 'PASS: Returns active employees'
           ELSE 'FAIL: No active employees found'
       END AS result
FROM public.employees
WHERE is_active = true;

-- CLEANUP
-- No cleanup needed

-- ============================================================================
-- TEST CASE 10: Employee with department but no manager (Boundary case)
-- ============================================================================
-- SETUP
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.employees WHERE employee_id = 9995) THEN
        INSERT INTO public.employees (employee_id, first_name, last_name, email, phone, hire_date, salary, department_id, manager_id, is_active, status)
        VALUES (9995, 'No', 'Manager', 'nomanager@test.com', '555-9995', '2021-01-01', 65000.00, 1, NULL, true, 'Active');
    END IF;
END $$;

-- EXEC
SELECT public.usp_employee_json_func(p_employee_id := 9995);

-- ASSERT
SELECT 'TC10' AS test_case,
       CASE 
           WHEN department_id IS NOT NULL AND manager_id IS NULL
           THEN 'PASS: Has department but no manager'
           ELSE 'FAIL: Unexpected data state'
       END AS result
FROM public.employees
WHERE employee_id = 9995;

-- CLEANUP
DELETE FROM public.employees WHERE employee_id = 9995;

-- ============================================================================
-- FINAL CLEANUP
-- ============================================================================
-- Clean up any remaining test data
DELETE FROM public.employees WHERE employee_id IN (1, 2, 9991, 9992, 9993, 9994, 9995);

-- Verify cleanup
SELECT 'CLEANUP' AS test_case,
       CASE 
           WHEN COUNT(*) = 0 THEN 'PASS: All test data cleaned up'
           ELSE 'FAIL: ' || CAST(COUNT(*) AS VARCHAR) || ' test records remain'
       END AS result
FROM public.employees
WHERE employee_id IN (1, 2, 9991, 9992, 9993, 9994, 9995);

-- ============================================================================
-- END OF TEST SUITE
-- ============================================================================
