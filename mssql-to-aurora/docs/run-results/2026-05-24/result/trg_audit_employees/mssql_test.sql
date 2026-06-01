-- =============================================
-- TEST SUITE: dbo.trg_audit_employees
-- Description: Comprehensive test cases for audit trigger on employees table
-- Tests: INSERT, UPDATE, DELETE operations with single and multiple rows
-- Note: employee_id is IDENTITY column, so we don't specify it in INSERTs
-- =============================================

-- ============= TEST CASE 1: Single INSERT operation =============
-- SETUP
DECLARE @tc1_id INT;

-- EXEC
INSERT INTO dbo.employees (department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES (1, 'John', 'Doe', '2026-01-15', 1, 'john.doe@test.com', '2026-01-15 10:00:00');
SET @tc1_id = SCOPE_IDENTITY();

-- ASSERT
SELECT 
    'TC1' AS tc,
    'audit_count' AS metric,
    COUNT(*) AS result
FROM dbo.audit_log 
WHERE table_name = 'employees' AND operation = 'INSERT' AND primary_key = @tc1_id;

SELECT 
    'TC1' AS tc,
    'audit_details' AS metric,
    table_name,
    operation,
    primary_key
FROM dbo.audit_log 
WHERE table_name = 'employees' AND primary_key = @tc1_id
ORDER BY audit_id;

-- CLEANUP
DELETE FROM dbo.employees WHERE employee_id = @tc1_id;
DELETE FROM dbo.audit_log WHERE table_name = 'employees' AND primary_key = @tc1_id;

-- ============= TEST CASE 2: Multiple INSERT operations (batch) =============
-- SETUP
DECLARE @tc2_id1 INT, @tc2_id2 INT, @tc2_id3 INT;

-- EXEC
INSERT INTO dbo.employees (department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES (1, 'Alice', 'Smith', '2026-02-01', 1, 'alice@test.com', '2026-02-01 10:00:00');
SET @tc2_id1 = SCOPE_IDENTITY();

INSERT INTO dbo.employees (department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES (2, 'Bob', 'Johnson', '2026-02-02', 1, 'bob@test.com', '2026-02-02 10:00:00');
SET @tc2_id2 = SCOPE_IDENTITY();

INSERT INTO dbo.employees (department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES (3, 'Carol', 'Williams', '2026-02-03', 0, 'carol@test.com', '2026-02-03 10:00:00');
SET @tc2_id3 = SCOPE_IDENTITY();

-- ASSERT
SELECT 
    'TC2' AS tc,
    'batch_insert_count' AS metric,
    COUNT(*) AS result
FROM dbo.audit_log 
WHERE table_name = 'employees' AND operation = 'INSERT' AND primary_key IN (@tc2_id1, @tc2_id2, @tc2_id3);

SELECT 
    'TC2' AS tc,
    'batch_details' AS metric,
    primary_key,
    operation
FROM dbo.audit_log 
WHERE table_name = 'employees' AND primary_key IN (@tc2_id1, @tc2_id2, @tc2_id3)
ORDER BY primary_key;

-- CLEANUP
DELETE FROM dbo.employees WHERE employee_id IN (@tc2_id1, @tc2_id2, @tc2_id3);
DELETE FROM dbo.audit_log WHERE table_name = 'employees' AND primary_key IN (@tc2_id1, @tc2_id2, @tc2_id3);

-- ============= TEST CASE 3: Single UPDATE operation =============
-- SETUP
DECLARE @tc3_id INT;
INSERT INTO dbo.employees (department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES (1, 'David', 'Brown', '2026-03-01', 1, 'david@test.com', '2026-03-01 10:00:00');
SET @tc3_id = SCOPE_IDENTITY();
DELETE FROM dbo.audit_log WHERE table_name = 'employees' AND primary_key = @tc3_id; -- Clear INSERT audit

-- EXEC
UPDATE dbo.employees 
SET first_name = 'Dave', is_active = 0
WHERE employee_id = @tc3_id;

-- ASSERT
SELECT 
    'TC3' AS tc,
    'update_count' AS metric,
    COUNT(*) AS result
FROM dbo.audit_log 
WHERE table_name = 'employees' AND operation = 'UPDATE' AND primary_key = @tc3_id;

SELECT 
    'TC3' AS tc,
    'update_details' AS metric,
    table_name,
    operation,
    primary_key
FROM dbo.audit_log 
WHERE table_name = 'employees' AND operation = 'UPDATE' AND primary_key = @tc3_id;

-- CLEANUP
DELETE FROM dbo.employees WHERE employee_id = @tc3_id;
DELETE FROM dbo.audit_log WHERE table_name = 'employees' AND primary_key = @tc3_id;

-- ============= TEST CASE 4: Multiple UPDATE operations (batch) =============
-- SETUP
DECLARE @tc4_id1 INT, @tc4_id2 INT, @tc4_id3 INT;
INSERT INTO dbo.employees (department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES (1, 'Eve', 'Davis', '2026-04-01', 1, 'eve@test.com', '2026-04-01 10:00:00');
SET @tc4_id1 = SCOPE_IDENTITY();

INSERT INTO dbo.employees (department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES (2, 'Frank', 'Miller', '2026-04-02', 1, 'frank@test.com', '2026-04-02 10:00:00');
SET @tc4_id2 = SCOPE_IDENTITY();

INSERT INTO dbo.employees (department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES (3, 'Grace', 'Wilson', '2026-04-03', 1, 'grace@test.com', '2026-04-03 10:00:00');
SET @tc4_id3 = SCOPE_IDENTITY();

DELETE FROM dbo.audit_log WHERE table_name = 'employees' AND primary_key IN (@tc4_id1, @tc4_id2, @tc4_id3); -- Clear INSERT audits

-- EXEC
UPDATE dbo.employees 
SET is_active = 0
WHERE employee_id IN (@tc4_id1, @tc4_id2, @tc4_id3);

-- ASSERT
SELECT 
    'TC4' AS tc,
    'batch_update_count' AS metric,
    COUNT(*) AS result
FROM dbo.audit_log 
WHERE table_name = 'employees' AND operation = 'UPDATE' AND primary_key IN (@tc4_id1, @tc4_id2, @tc4_id3);

SELECT 
    'TC4' AS tc,
    'batch_update_details' AS metric,
    primary_key,
    operation
FROM dbo.audit_log 
WHERE table_name = 'employees' AND operation = 'UPDATE' AND primary_key IN (@tc4_id1, @tc4_id2, @tc4_id3)
ORDER BY primary_key;

-- CLEANUP
DELETE FROM dbo.employees WHERE employee_id IN (@tc4_id1, @tc4_id2, @tc4_id3);
DELETE FROM dbo.audit_log WHERE table_name = 'employees' AND primary_key IN (@tc4_id1, @tc4_id2, @tc4_id3);

-- ============= TEST CASE 5: Single DELETE operation =============
-- SETUP
DECLARE @tc5_id INT;
INSERT INTO dbo.employees (department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES (1, 'Henry', 'Moore', '2026-05-01', 1, 'henry@test.com', '2026-05-01 10:00:00');
SET @tc5_id = SCOPE_IDENTITY();
DELETE FROM dbo.audit_log WHERE table_name = 'employees' AND primary_key = @tc5_id; -- Clear INSERT audit

-- EXEC
DELETE FROM dbo.employees WHERE employee_id = @tc5_id;

-- ASSERT
SELECT 
    'TC5' AS tc,
    'delete_count' AS metric,
    COUNT(*) AS result
FROM dbo.audit_log 
WHERE table_name = 'employees' AND operation = 'DELETE' AND primary_key = @tc5_id;

SELECT 
    'TC5' AS tc,
    'delete_details' AS metric,
    table_name,
    operation,
    primary_key
FROM dbo.audit_log 
WHERE table_name = 'employees' AND operation = 'DELETE' AND primary_key = @tc5_id;

-- CLEANUP
DELETE FROM dbo.audit_log WHERE table_name = 'employees' AND primary_key = @tc5_id;

-- ============= TEST CASE 6: Multiple DELETE operations (batch) =============
-- SETUP
DECLARE @tc6_id1 INT, @tc6_id2 INT, @tc6_id3 INT;
INSERT INTO dbo.employees (department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES (1, 'Ivy', 'Taylor', '2026-06-01', 1, 'ivy@test.com', '2026-06-01 10:00:00');
SET @tc6_id1 = SCOPE_IDENTITY();

INSERT INTO dbo.employees (department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES (2, 'Jack', 'Anderson', '2026-06-02', 1, 'jack@test.com', '2026-06-02 10:00:00');
SET @tc6_id2 = SCOPE_IDENTITY();

INSERT INTO dbo.employees (department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES (3, 'Kate', 'Thomas', '2026-06-03', 1, 'kate@test.com', '2026-06-03 10:00:00');
SET @tc6_id3 = SCOPE_IDENTITY();

DELETE FROM dbo.audit_log WHERE table_name = 'employees' AND primary_key IN (@tc6_id1, @tc6_id2, @tc6_id3); -- Clear INSERT audits

-- EXEC
DELETE FROM dbo.employees WHERE employee_id IN (@tc6_id1, @tc6_id2, @tc6_id3);

-- ASSERT
SELECT 
    'TC6' AS tc,
    'batch_delete_count' AS metric,
    COUNT(*) AS result
FROM dbo.audit_log 
WHERE table_name = 'employees' AND operation = 'DELETE' AND primary_key IN (@tc6_id1, @tc6_id2, @tc6_id3);

SELECT 
    'TC6' AS tc,
    'batch_delete_details' AS metric,
    primary_key,
    operation
FROM dbo.audit_log 
WHERE table_name = 'employees' AND operation = 'DELETE' AND primary_key IN (@tc6_id1, @tc6_id2, @tc6_id3)
ORDER BY primary_key;

-- CLEANUP
DELETE FROM dbo.audit_log WHERE table_name = 'employees' AND primary_key IN (@tc6_id1, @tc6_id2, @tc6_id3);

-- ============= TEST CASE 7: INSERT with NULL email (boundary) =============
-- SETUP
DECLARE @tc7_id INT;

-- EXEC
INSERT INTO dbo.employees (department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES (1, 'Laura', 'Jackson', '2026-07-01', 1, NULL, '2026-07-01 10:00:00');
SET @tc7_id = SCOPE_IDENTITY();

-- ASSERT
SELECT 
    'TC7' AS tc,
    'null_email_audit' AS metric,
    COUNT(*) AS result
FROM dbo.audit_log 
WHERE table_name = 'employees' AND operation = 'INSERT' AND primary_key = @tc7_id;

-- CLEANUP
DELETE FROM dbo.employees WHERE employee_id = @tc7_id;
DELETE FROM dbo.audit_log WHERE table_name = 'employees' AND primary_key = @tc7_id;

-- ============= TEST CASE 8: UPDATE with no actual change (boundary) =============
-- SETUP
DECLARE @tc8_id INT;
INSERT INTO dbo.employees (department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES (1, 'Mike', 'White', '2026-08-01', 1, 'mike@test.com', '2026-08-01 10:00:00');
SET @tc8_id = SCOPE_IDENTITY();
DELETE FROM dbo.audit_log WHERE table_name = 'employees' AND primary_key = @tc8_id; -- Clear INSERT audit

-- EXEC
UPDATE dbo.employees 
SET first_name = 'Mike' -- Same value, no actual change
WHERE employee_id = @tc8_id;

-- ASSERT
SELECT 
    'TC8' AS tc,
    'no_change_update_audit' AS metric,
    COUNT(*) AS result
FROM dbo.audit_log 
WHERE table_name = 'employees' AND operation = 'UPDATE' AND primary_key = @tc8_id;

-- CLEANUP
DELETE FROM dbo.employees WHERE employee_id = @tc8_id;
DELETE FROM dbo.audit_log WHERE table_name = 'employees' AND primary_key = @tc8_id;

-- ============= TEST CASE 9: Transaction ROLLBACK - no audit record =============
-- SETUP
DECLARE @tc9_id INT;

-- EXEC
BEGIN TRANSACTION;
INSERT INTO dbo.employees (department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES (1, 'Nancy', 'Harris', '2026-09-01', 1, 'nancy@test.com', '2026-09-01 10:00:00');
SET @tc9_id = SCOPE_IDENTITY();
ROLLBACK TRANSACTION;

-- ASSERT
SELECT 
    'TC9' AS tc,
    'rollback_no_audit' AS metric,
    COUNT(*) AS result
FROM dbo.audit_log 
WHERE table_name = 'employees' AND primary_key = @tc9_id;

SELECT 
    'TC9' AS tc,
    'rollback_no_employee' AS metric,
    COUNT(*) AS result
FROM dbo.employees 
WHERE employee_id = @tc9_id;

-- CLEANUP
-- Nothing to clean up (transaction was rolled back)

-- ============= TEST CASE 10: Transaction COMMIT - audit record persists =============
-- SETUP
DECLARE @tc10_id INT;

-- EXEC
BEGIN TRANSACTION;
INSERT INTO dbo.employees (department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES (1, 'Oscar', 'Martin', '2026-10-01', 1, 'oscar@test.com', '2026-10-01 10:00:00');
SET @tc10_id = SCOPE_IDENTITY();
COMMIT TRANSACTION;

-- ASSERT
SELECT 
    'TC10' AS tc,
    'commit_audit_exists' AS metric,
    COUNT(*) AS result
FROM dbo.audit_log 
WHERE table_name = 'employees' AND operation = 'INSERT' AND primary_key = @tc10_id;

SELECT 
    'TC10' AS tc,
    'commit_employee_exists' AS metric,
    COUNT(*) AS result
FROM dbo.employees 
WHERE employee_id = @tc10_id;

-- CLEANUP
DELETE FROM dbo.employees WHERE employee_id = @tc10_id;
DELETE FROM dbo.audit_log WHERE table_name = 'employees' AND primary_key = @tc10_id;

-- ============= TEST CASE 11: UPDATE affecting 0 rows (boundary) =============
-- SETUP
-- No setup needed

-- EXEC
UPDATE dbo.employees 
SET first_name = 'NonExistent'
WHERE employee_id = 999999; -- This employee doesn't exist

-- ASSERT
SELECT 
    'TC11' AS tc,
    'zero_row_update_audit' AS metric,
    COUNT(*) AS result
FROM dbo.audit_log 
WHERE table_name = 'employees' AND primary_key = 999999;

-- CLEANUP
-- Nothing to clean up (no rows affected)

-- ============= TEST CASE 12: Verify audit_log columns are populated correctly =============
-- SETUP
DECLARE @tc12_id INT;

-- EXEC
INSERT INTO dbo.employees (department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES (1, 'Paula', 'Garcia', '2026-11-01', 1, 'paula@test.com', '2026-11-01 10:00:00');
SET @tc12_id = SCOPE_IDENTITY();

-- ASSERT
SELECT 
    'TC12' AS tc,
    'audit_columns' AS metric,
    table_name,
    operation,
    primary_key,
    CASE WHEN changed_at IS NOT NULL THEN 'HAS_TIMESTAMP' ELSE 'NO_TIMESTAMP' END AS timestamp_check,
    CASE WHEN changed_by IS NOT NULL THEN 'HAS_USER' ELSE 'NO_USER' END AS user_check
FROM dbo.audit_log 
WHERE table_name = 'employees' AND primary_key = @tc12_id;

-- CLEANUP
DELETE FROM dbo.employees WHERE employee_id = @tc12_id;
DELETE FROM dbo.audit_log WHERE table_name = 'employees' AND primary_key = @tc12_id;
