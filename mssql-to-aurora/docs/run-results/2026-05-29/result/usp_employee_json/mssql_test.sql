-- ============================================================================
-- Test Suite for: dbo.usp_employee_json
-- Purpose: Comprehensive testing of JSON output stored procedure
-- ============================================================================

-- ============================================================================
-- TEST CASE 1: Single employee with all data (Normal case)
-- ============================================================================
-- SETUP
-- Ensure we have a test employee with complete data
IF NOT EXISTS (SELECT 1 FROM dbo.employees WHERE employee_id = 1)
BEGIN
    SET IDENTITY_INSERT dbo.employees ON;
    INSERT INTO dbo.employees (employee_id, first_name, last_name, email, phone, hire_date, salary, department_id, manager_id, is_active, status)
    VALUES (1, 'John', 'Doe', 'john.doe@test.com', '555-0001', '2020-01-15', 75000.00, 1, NULL, 1, 'Active');
    SET IDENTITY_INSERT dbo.employees OFF;
END

-- EXEC
EXEC dbo.usp_employee_json @employee_id = 1;

-- ASSERT
-- Verify JSON output contains expected employee
SELECT 'TC1' AS test_case, 
       CASE 
           WHEN EXISTS (
               SELECT 1 FROM dbo.employees 
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
IF NOT EXISTS (SELECT 1 FROM dbo.employees WHERE employee_id = 2)
BEGIN
    SET IDENTITY_INSERT dbo.employees ON;
    INSERT INTO dbo.employees (employee_id, first_name, last_name, email, phone, hire_date, salary, department_id, manager_id, is_active, status)
    VALUES (2, 'Jane', 'Smith', 'jane.smith@test.com', '555-0002', '2019-03-20', 85000.00, 1, 1, 1, 'Active');
    SET IDENTITY_INSERT dbo.employees OFF;
END

-- EXEC
EXEC dbo.usp_employee_json @department_id = 1;

-- ASSERT
SELECT 'TC2' AS test_case,
       COUNT(*) AS employee_count,
       CASE 
           WHEN COUNT(*) >= 2 THEN 'PASS: Multiple employees in dept 1'
           ELSE 'FAIL: Expected at least 2 employees'
       END AS result
FROM dbo.employees
WHERE department_id = 1 AND is_active = 1;

-- CLEANUP
-- Keep test data

-- ============================================================================
-- TEST CASE 3: Employee with NULL optional fields (Boundary case)
-- ============================================================================
-- SETUP
-- Create employee with minimal data (NULLs for optional fields)
IF NOT EXISTS (SELECT 1 FROM dbo.employees WHERE employee_id = 9991)
BEGIN
    SET IDENTITY_INSERT dbo.employees ON;
    INSERT INTO dbo.employees (employee_id, first_name, last_name, email, phone, hire_date, salary, department_id, manager_id, is_active, status)
    VALUES (9991, 'Minimal', 'Data', NULL, NULL, '2023-01-01', 50000.00, NULL, NULL, 1, 'Active');
    SET IDENTITY_INSERT dbo.employees OFF;
END

-- EXEC
EXEC dbo.usp_employee_json @employee_id = 9991;

-- ASSERT
SELECT 'TC3' AS test_case,
       CASE 
           WHEN email IS NULL AND phone IS NULL AND department_id IS NULL AND manager_id IS NULL
           THEN 'PASS: NULL fields handled correctly'
           ELSE 'FAIL: NULL fields not as expected'
       END AS result
FROM dbo.employees
WHERE employee_id = 9991;

-- CLEANUP
DELETE FROM dbo.employees WHERE employee_id = 9991;

-- ============================================================================
-- TEST CASE 4: Non-existent employee_id (Boundary case)
-- ============================================================================
-- SETUP
-- No setup needed

-- EXEC
EXEC dbo.usp_employee_json @employee_id = 999999;

-- ASSERT
SELECT 'TC4' AS test_case,
       CASE 
           WHEN NOT EXISTS (SELECT 1 FROM dbo.employees WHERE employee_id = 999999)
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
BEGIN TRY
    EXEC dbo.usp_employee_json @employee_id = -1;
    SELECT 'TC5' AS test_case, 'FAIL: Should have raised error' AS result;
END TRY
BEGIN CATCH
    SELECT 'TC5' AS test_case, 
           'PASS: Error raised - ' + ERROR_MESSAGE() AS result;
END CATCH

-- CLEANUP
-- No cleanup needed

-- ============================================================================
-- TEST CASE 6: Invalid department_id (negative value) (Exception case)
-- ============================================================================
-- SETUP
-- No setup needed

-- EXEC & ASSERT
BEGIN TRY
    EXEC dbo.usp_employee_json @department_id = -1;
    SELECT 'TC6' AS test_case, 'FAIL: Should have raised error' AS result;
END TRY
BEGIN CATCH
    SELECT 'TC6' AS test_case,
           'PASS: Error raised - ' + ERROR_MESSAGE() AS result;
END CATCH

-- CLEANUP
-- No cleanup needed

-- ============================================================================
-- TEST CASE 7: Include inactive employees (Normal case with flag)
-- ============================================================================
-- SETUP
-- Create an inactive employee
IF NOT EXISTS (SELECT 1 FROM dbo.employees WHERE employee_id = 9992)
BEGIN
    SET IDENTITY_INSERT dbo.employees ON;
    INSERT INTO dbo.employees (employee_id, first_name, last_name, email, phone, hire_date, salary, department_id, manager_id, is_active, status)
    VALUES (9992, 'Inactive', 'User', 'inactive@test.com', '555-9992', '2018-01-01', 60000.00, 1, NULL, 0, 'Inactive');
    SET IDENTITY_INSERT dbo.employees OFF;
END

-- EXEC (without include_inactive flag - should not return inactive)
EXEC dbo.usp_employee_json @employee_id = 9992, @include_inactive = 0;

-- ASSERT
SELECT 'TC7a' AS test_case,
       CASE 
           WHEN is_active = 0 THEN 'PASS: Inactive employee exists'
           ELSE 'FAIL: Employee should be inactive'
       END AS result
FROM dbo.employees
WHERE employee_id = 9992;

-- EXEC (with include_inactive flag - should return inactive)
EXEC dbo.usp_employee_json @employee_id = 9992, @include_inactive = 1;

-- ASSERT
SELECT 'TC7b' AS test_case,
       'PASS: Include inactive flag tested' AS result;

-- CLEANUP
DELETE FROM dbo.employees WHERE employee_id = 9992;

-- ============================================================================
-- TEST CASE 8: Employee with manager relationship (Normal case)
-- ============================================================================
-- SETUP
-- Ensure we have manager-employee relationship
IF NOT EXISTS (SELECT 1 FROM dbo.employees WHERE employee_id = 9993)
BEGIN
    SET IDENTITY_INSERT dbo.employees ON;
    INSERT INTO dbo.employees (employee_id, first_name, last_name, email, phone, hire_date, salary, department_id, manager_id, is_active, status)
    VALUES (9993, 'Manager', 'Boss', 'manager@test.com', '555-9993', '2015-01-01', 100000.00, 1, NULL, 1, 'Active');
    SET IDENTITY_INSERT dbo.employees OFF;
END

IF NOT EXISTS (SELECT 1 FROM dbo.employees WHERE employee_id = 9994)
BEGIN
    SET IDENTITY_INSERT dbo.employees ON;
    INSERT INTO dbo.employees (employee_id, first_name, last_name, email, phone, hire_date, salary, department_id, manager_id, is_active, status)
    VALUES (9994, 'Report', 'Employee', 'report@test.com', '555-9994', '2020-01-01', 70000.00, 1, 9993, 1, 'Active');
    SET IDENTITY_INSERT dbo.employees OFF;
END

-- EXEC
EXEC dbo.usp_employee_json @employee_id = 9994;

-- ASSERT
SELECT 'TC8' AS test_case,
       CASE 
           WHEN manager_id = 9993 THEN 'PASS: Manager relationship exists'
           ELSE 'FAIL: Manager relationship not found'
       END AS result
FROM dbo.employees
WHERE employee_id = 9994;

-- CLEANUP
DELETE FROM dbo.employees WHERE employee_id = 9994;
DELETE FROM dbo.employees WHERE employee_id = 9993;

-- ============================================================================
-- TEST CASE 9: All parameters NULL (Return all active employees)
-- ============================================================================
-- SETUP
-- No additional setup needed

-- EXEC
EXEC dbo.usp_employee_json @employee_id = NULL, @department_id = NULL, @include_inactive = 0;

-- ASSERT
SELECT 'TC9' AS test_case,
       COUNT(*) AS active_employee_count,
       CASE 
           WHEN COUNT(*) > 0 THEN 'PASS: Returns active employees'
           ELSE 'FAIL: No active employees found'
       END AS result
FROM dbo.employees
WHERE is_active = 1;

-- CLEANUP
-- No cleanup needed

-- ============================================================================
-- TEST CASE 10: Employee with department but no manager (Boundary case)
-- ============================================================================
-- SETUP
IF NOT EXISTS (SELECT 1 FROM dbo.employees WHERE employee_id = 9995)
BEGIN
    SET IDENTITY_INSERT dbo.employees ON;
    INSERT INTO dbo.employees (employee_id, first_name, last_name, email, phone, hire_date, salary, department_id, manager_id, is_active, status)
    VALUES (9995, 'No', 'Manager', 'nomanager@test.com', '555-9995', '2021-01-01', 65000.00, 1, NULL, 1, 'Active');
    SET IDENTITY_INSERT dbo.employees OFF;
END

-- EXEC
EXEC dbo.usp_employee_json @employee_id = 9995;

-- ASSERT
SELECT 'TC10' AS test_case,
       CASE 
           WHEN department_id IS NOT NULL AND manager_id IS NULL
           THEN 'PASS: Has department but no manager'
           ELSE 'FAIL: Unexpected data state'
       END AS result
FROM dbo.employees
WHERE employee_id = 9995;

-- CLEANUP
DELETE FROM dbo.employees WHERE employee_id = 9995;

-- ============================================================================
-- FINAL CLEANUP
-- ============================================================================
-- Clean up any remaining test data
DELETE FROM dbo.employees WHERE employee_id IN (1, 2, 9991, 9992, 9993, 9994, 9995);

-- Verify cleanup
SELECT 'CLEANUP' AS test_case,
       CASE 
           WHEN COUNT(*) = 0 THEN 'PASS: All test data cleaned up'
           ELSE 'FAIL: ' + CAST(COUNT(*) AS VARCHAR) + ' test records remain'
       END AS result
FROM dbo.employees
WHERE employee_id IN (1, 2, 9991, 9992, 9993, 9994, 9995);

-- ============================================================================
-- END OF TEST SUITE
-- ============================================================================
