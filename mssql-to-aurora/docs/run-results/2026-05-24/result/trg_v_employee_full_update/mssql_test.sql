-- ============================================================
-- TEST CASES for TRIGGER: dbo.trg_v_employee_full_update
-- ============================================================
-- This trigger is an INSTEAD OF UPDATE trigger on view dbo.v_employee_full
-- It updates the underlying dbo.employees table when the view is updated
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
BEGIN TRANSACTION;

-- Insert test employee
INSERT INTO dbo.employees (first_name, last_name, email, hire_date, department_id, is_active)
VALUES ('TestFirst1', 'TestLast1', 'test1@example.com', '2024-01-01', 1, 1);

DECLARE @test_emp_id1 INT = SCOPE_IDENTITY();

-- EXEC
-- Update via the view (trigger will fire)
UPDATE dbo.v_employee_full
SET first_name = 'UpdatedFirst1',
    last_name = 'UpdatedLast1',
    email = 'updated1@example.com',
    is_active = 0
WHERE employee_id = @test_emp_id1;

-- ASSERT
SELECT 'TC1' AS tc, 
       first_name, 
       last_name, 
       email, 
       is_active,
       'Single row updated successfully' AS description
FROM dbo.employees
WHERE employee_id = @test_emp_id1;

-- CLEANUP
ROLLBACK TRANSACTION;

-- ============= TEST CASE 2: Multiple Rows Update =============
-- SETUP
BEGIN TRANSACTION;

-- Insert multiple test employees
INSERT INTO dbo.employees (first_name, last_name, email, hire_date, department_id, is_active)
VALUES 
    ('TestFirst2A', 'TestLast2A', 'test2a@example.com', '2024-01-01', 1, 1),
    ('TestFirst2B', 'TestLast2B', 'test2b@example.com', '2024-01-01', 1, 1),
    ('TestFirst2C', 'TestLast2C', 'test2c@example.com', '2024-01-01', 1, 1);

DECLARE @test_emp_id2a INT = SCOPE_IDENTITY() - 2;
DECLARE @test_emp_id2b INT = SCOPE_IDENTITY() - 1;
DECLARE @test_emp_id2c INT = SCOPE_IDENTITY();

-- EXEC
-- Update multiple rows via the view
UPDATE dbo.v_employee_full
SET is_active = 0
WHERE employee_id IN (@test_emp_id2a, @test_emp_id2b, @test_emp_id2c);

-- ASSERT
SELECT 'TC2' AS tc,
       COUNT(*) AS updated_count,
       SUM(CASE WHEN is_active = 0 THEN 1 ELSE 0 END) AS inactive_count,
       'Multiple rows updated' AS description
FROM dbo.employees
WHERE employee_id IN (@test_emp_id2a, @test_emp_id2b, @test_emp_id2c);

-- CLEANUP
ROLLBACK TRANSACTION;

-- ============= TEST CASE 3: Update with NULL email (Boundary) =============
-- SETUP
BEGIN TRANSACTION;

INSERT INTO dbo.employees (first_name, last_name, email, hire_date, department_id, is_active)
VALUES ('TestFirst3', 'TestLast3', 'test3@example.com', '2024-01-01', 1, 1);

DECLARE @test_emp_id3 INT = SCOPE_IDENTITY();

-- EXEC
-- Update email to NULL via view
UPDATE dbo.v_employee_full
SET email = NULL
WHERE employee_id = @test_emp_id3;

-- ASSERT
SELECT 'TC3' AS tc,
       first_name,
       last_name,
       CASE WHEN email IS NULL THEN 'NULL' ELSE email END AS email,
       'Email set to NULL' AS description
FROM dbo.employees
WHERE employee_id = @test_emp_id3;

-- CLEANUP
ROLLBACK TRANSACTION;

-- ============= TEST CASE 4: Update with Empty String (Boundary) =============
-- SETUP
BEGIN TRANSACTION;

INSERT INTO dbo.employees (first_name, last_name, email, hire_date, department_id, is_active)
VALUES ('TestFirst4', 'TestLast4', 'test4@example.com', '2024-01-01', 1, 1);

DECLARE @test_emp_id4 INT = SCOPE_IDENTITY();

-- EXEC
-- Update first_name to empty string via view
UPDATE dbo.v_employee_full
SET first_name = '',
    last_name = ''
WHERE employee_id = @test_emp_id4;

-- ASSERT
SELECT 'TC4' AS tc,
       CASE WHEN first_name = '' THEN 'EMPTY' ELSE first_name END AS first_name,
       CASE WHEN last_name = '' THEN 'EMPTY' ELSE last_name END AS last_name,
       email,
       'Names set to empty string' AS description
FROM dbo.employees
WHERE employee_id = @test_emp_id4;

-- CLEANUP
ROLLBACK TRANSACTION;

-- ============= TEST CASE 5: Toggle is_active Flag (Boundary) =============
-- SETUP
BEGIN TRANSACTION;

INSERT INTO dbo.employees (first_name, last_name, email, hire_date, department_id, is_active)
VALUES ('TestFirst5', 'TestLast5', 'test5@example.com', '2024-01-01', 1, 1);

DECLARE @test_emp_id5 INT = SCOPE_IDENTITY();

-- EXEC
-- Toggle is_active from 1 to 0
UPDATE dbo.v_employee_full
SET is_active = 0
WHERE employee_id = @test_emp_id5;

-- ASSERT (First check)
SELECT 'TC5_Step1' AS tc,
       is_active,
       'After first toggle (1->0)' AS description
FROM dbo.employees
WHERE employee_id = @test_emp_id5;

-- Toggle back from 0 to 1
UPDATE dbo.v_employee_full
SET is_active = 1
WHERE employee_id = @test_emp_id5;

-- ASSERT (Second check)
SELECT 'TC5_Step2' AS tc,
       is_active,
       'After second toggle (0->1)' AS description
FROM dbo.employees
WHERE employee_id = @test_emp_id5;

-- CLEANUP
ROLLBACK TRANSACTION;

-- ============= TEST CASE 6: Update Non-Existent Employee (Edge Case) =============
-- SETUP
BEGIN TRANSACTION;

-- Find a non-existent employee_id
DECLARE @non_existent_id INT = 999999;

-- EXEC
-- Try to update non-existent employee via view
UPDATE dbo.v_employee_full
SET first_name = 'NonExistent'
WHERE employee_id = @non_existent_id;

-- ASSERT
SELECT 'TC6' AS tc,
       @@ROWCOUNT AS rows_affected,
       'No rows should be affected' AS description;

-- CLEANUP
ROLLBACK TRANSACTION;

-- ============= TEST CASE 7: Update with WHERE Clause Matching No Rows =============
-- SETUP
BEGIN TRANSACTION;

INSERT INTO dbo.employees (first_name, last_name, email, hire_date, department_id, is_active)
VALUES ('TestFirst7', 'TestLast7', 'test7@example.com', '2024-01-01', 1, 1);

DECLARE @test_emp_id7 INT = SCOPE_IDENTITY();

-- EXEC
-- Update with WHERE clause that matches no rows
UPDATE dbo.v_employee_full
SET first_name = 'ShouldNotUpdate'
WHERE employee_id = @test_emp_id7 AND first_name = 'NonMatchingName';

-- ASSERT
SELECT 'TC7' AS tc,
       first_name,
       'Original name should remain' AS description
FROM dbo.employees
WHERE employee_id = @test_emp_id7;

-- CLEANUP
ROLLBACK TRANSACTION;

-- ============= TEST CASE 8: Verify @@ROWCOUNT After Update (Side Effect) =============
-- SETUP
BEGIN TRANSACTION;

INSERT INTO dbo.employees (first_name, last_name, email, hire_date, department_id, is_active)
VALUES 
    ('TestFirst8A', 'TestLast8A', 'test8a@example.com', '2024-01-01', 1, 1),
    ('TestFirst8B', 'TestLast8B', 'test8b@example.com', '2024-01-01', 1, 1);

DECLARE @test_emp_id8a INT = SCOPE_IDENTITY() - 1;
DECLARE @test_emp_id8b INT = SCOPE_IDENTITY();

-- EXEC
UPDATE dbo.v_employee_full
SET email = 'updated8@example.com'
WHERE employee_id IN (@test_emp_id8a, @test_emp_id8b);

DECLARE @rowcount_result INT = @@ROWCOUNT;

-- ASSERT
SELECT 'TC8' AS tc,
       @rowcount_result AS row_count,
       'Should be 2' AS description;

-- CLEANUP
ROLLBACK TRANSACTION;

-- ============= TEST CASE 9: Transaction Rollback Behavior =============
-- SETUP
BEGIN TRANSACTION;

INSERT INTO dbo.employees (first_name, last_name, email, hire_date, department_id, is_active)
VALUES ('TestFirst9', 'TestLast9', 'test9@example.com', '2024-01-01', 1, 1);

DECLARE @test_emp_id9 INT = SCOPE_IDENTITY();

-- Store original values
DECLARE @original_first_name NVARCHAR(50);
SELECT @original_first_name = first_name FROM dbo.employees WHERE employee_id = @test_emp_id9;

-- EXEC
-- Update via view
UPDATE dbo.v_employee_full
SET first_name = 'RolledBackName'
WHERE employee_id = @test_emp_id9;

-- Verify update happened
DECLARE @updated_name NVARCHAR(50);
SELECT @updated_name = first_name FROM dbo.employees WHERE employee_id = @test_emp_id9;

-- CLEANUP (Rollback)
ROLLBACK TRANSACTION;

-- ASSERT (After rollback - in new transaction to check)
BEGIN TRANSACTION;
SELECT 'TC9' AS tc,
       CASE 
           WHEN @original_first_name = 'TestFirst9' THEN 'ORIGINAL'
           ELSE 'UNEXPECTED'
       END AS original_value,
       CASE 
           WHEN @updated_name = 'RolledBackName' THEN 'UPDATED'
           ELSE 'NOT_UPDATED'
       END AS during_transaction,
       'Rollback should revert changes' AS description;
ROLLBACK TRANSACTION;

-- ============= TEST CASE 10: Update All Columns Simultaneously =============
-- SETUP
BEGIN TRANSACTION;

INSERT INTO dbo.employees (first_name, last_name, email, hire_date, department_id, is_active)
VALUES ('TestFirst10', 'TestLast10', 'test10@example.com', '2024-01-01', 1, 1);

DECLARE @test_emp_id10 INT = SCOPE_IDENTITY();

-- EXEC
-- Update all updatable columns at once
UPDATE dbo.v_employee_full
SET first_name = 'AllUpdatedFirst',
    last_name = 'AllUpdatedLast',
    email = 'allupdated@example.com',
    is_active = 0
WHERE employee_id = @test_emp_id10;

-- ASSERT
SELECT 'TC10' AS tc,
       first_name,
       last_name,
       email,
       is_active,
       'All columns updated' AS description
FROM dbo.employees
WHERE employee_id = @test_emp_id10;

-- CLEANUP
ROLLBACK TRANSACTION;

-- ============= TEST CASE 11: Partial Column Update =============
-- SETUP
BEGIN TRANSACTION;

INSERT INTO dbo.employees (first_name, last_name, email, hire_date, department_id, is_active)
VALUES ('TestFirst11', 'TestLast11', 'test11@example.com', '2024-01-01', 1, 1);

DECLARE @test_emp_id11 INT = SCOPE_IDENTITY();

-- EXEC
-- Update only email column
UPDATE dbo.v_employee_full
SET email = 'partial11@example.com'
WHERE employee_id = @test_emp_id11;

-- ASSERT
SELECT 'TC11' AS tc,
       first_name,
       last_name,
       email,
       is_active,
       'Only email should change' AS description
FROM dbo.employees
WHERE employee_id = @test_emp_id11;

-- CLEANUP
ROLLBACK TRANSACTION;

-- ============= TEST CASE 12: Update with Special Characters in Strings =============
-- SETUP
BEGIN TRANSACTION;

INSERT INTO dbo.employees (first_name, last_name, email, hire_date, department_id, is_active)
VALUES ('TestFirst12', 'TestLast12', 'test12@example.com', '2024-01-01', 1, 1);

DECLARE @test_emp_id12 INT = SCOPE_IDENTITY();

-- EXEC
-- Update with special characters
UPDATE dbo.v_employee_full
SET first_name = 'O''Brien',
    last_name = 'Test-Last',
    email = 'test+special@example.com'
WHERE employee_id = @test_emp_id12;

-- ASSERT
SELECT 'TC12' AS tc,
       first_name,
       last_name,
       email,
       'Special characters handled' AS description
FROM dbo.employees
WHERE employee_id = @test_emp_id12;

-- CLEANUP
ROLLBACK TRANSACTION;
