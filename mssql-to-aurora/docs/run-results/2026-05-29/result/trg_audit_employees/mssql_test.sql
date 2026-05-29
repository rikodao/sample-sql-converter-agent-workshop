-- ============================================================================
-- TEST SUITE: dbo.trg_audit_employees
-- Type: TRIGGER (AFTER INSERT, UPDATE, DELETE)
-- Target Table: dbo.employees
-- Audit Table: dbo.employee_audit
-- ============================================================================
-- Test Strategy:
-- - Normal cases: INSERT, UPDATE, DELETE operations trigger audit logging
-- - Boundary cases: NULL values, multiple rows, no changes
-- - Exception cases: N/A (triggers don't throw errors in this pattern)
-- - Side effects: Verify audit records are created correctly
-- - Transaction cases: Rollback should also rollback audit entries
-- ============================================================================

-- ============================================================================
-- TEST CASE 1: INSERT - Single employee insert triggers audit log
-- ============================================================================
-- SETUP
BEGIN TRANSACTION;

-- Clear any existing test data
DELETE FROM dbo.employee_audit WHERE employee_id >= 90000;
DELETE FROM dbo.employees WHERE employee_id >= 90000;

-- EXEC
-- Insert a new employee (trigger should fire)
SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, first_name, last_name, email, department_id, salary, hire_date, is_active)
VALUES (90001, 'John', 'Doe', 'john.doe@test.com', 1, 50000.00, '2024-01-15', 1);
SET IDENTITY_INSERT dbo.employees OFF;

-- ASSERT
SELECT 
    'TC1' AS test_case,
    COUNT(*) AS audit_record_count,
    MAX(operation_type) AS operation_type,
    MAX(new_first_name) AS new_first_name,
    MAX(new_last_name) AS new_last_name,
    MAX(new_salary) AS new_salary,
    CASE WHEN MAX(old_first_name) IS NULL THEN 'NULL' ELSE 'NOT_NULL' END AS old_values_null
FROM dbo.employee_audit
WHERE employee_id = 90001;

-- CLEANUP
ROLLBACK TRANSACTION;

-- ============================================================================
-- TEST CASE 2: UPDATE - Single employee update triggers audit log
-- ============================================================================
-- SETUP
BEGIN TRANSACTION;

-- Clear any existing test data
DELETE FROM dbo.employee_audit WHERE employee_id >= 90000;
DELETE FROM dbo.employees WHERE employee_id >= 90000;

-- Insert test employee
SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, first_name, last_name, email, department_id, salary, hire_date, is_active)
VALUES (90002, 'Jane', 'Smith', 'jane.smith@test.com', 2, 60000.00, '2024-01-15', 1);
SET IDENTITY_INSERT dbo.employees OFF;

-- Clear audit log from INSERT
DELETE FROM dbo.employee_audit WHERE employee_id = 90002;

-- EXEC
-- Update the employee (trigger should fire)
UPDATE dbo.employees
SET salary = 65000.00, last_name = 'Smith-Jones'
WHERE employee_id = 90002;

-- ASSERT
SELECT 
    'TC2' AS test_case,
    COUNT(*) AS audit_record_count,
    MAX(operation_type) AS operation_type,
    MAX(old_last_name) AS old_last_name,
    MAX(new_last_name) AS new_last_name,
    MAX(old_salary) AS old_salary,
    MAX(new_salary) AS new_salary
FROM dbo.employee_audit
WHERE employee_id = 90002;

-- CLEANUP
ROLLBACK TRANSACTION;

-- ============================================================================
-- TEST CASE 3: DELETE - Single employee delete triggers audit log
-- ============================================================================
-- SETUP
BEGIN TRANSACTION;

-- Clear any existing test data
DELETE FROM dbo.employee_audit WHERE employee_id >= 90000;
DELETE FROM dbo.employees WHERE employee_id >= 90000;

-- Insert test employee
SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, first_name, last_name, email, department_id, salary, hire_date, is_active)
VALUES (90003, 'Bob', 'Johnson', 'bob.johnson@test.com', 3, 55000.00, '2024-01-15', 1);
SET IDENTITY_INSERT dbo.employees OFF;

-- Clear audit log from INSERT
DELETE FROM dbo.employee_audit WHERE employee_id = 90003;

-- EXEC
-- Delete the employee (trigger should fire)
DELETE FROM dbo.employees WHERE employee_id = 90003;

-- ASSERT
SELECT 
    'TC3' AS test_case,
    COUNT(*) AS audit_record_count,
    MAX(operation_type) AS operation_type,
    MAX(old_first_name) AS old_first_name,
    MAX(old_last_name) AS old_last_name,
    MAX(old_salary) AS old_salary,
    CASE WHEN MAX(new_first_name) IS NULL THEN 'NULL' ELSE 'NOT_NULL' END AS new_values_null
FROM dbo.employee_audit
WHERE employee_id = 90003;

-- CLEANUP
ROLLBACK TRANSACTION;

-- ============================================================================
-- TEST CASE 4: Multiple INSERT - Batch insert triggers multiple audit logs
-- ============================================================================
-- SETUP
BEGIN TRANSACTION;

-- Clear any existing test data
DELETE FROM dbo.employee_audit WHERE employee_id >= 90000;
DELETE FROM dbo.employees WHERE employee_id >= 90000;

-- EXEC
-- Insert multiple employees (trigger should fire once for all)
SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, first_name, last_name, email, department_id, salary, hire_date, is_active)
VALUES 
    (90004, 'Alice', 'Brown', 'alice.brown@test.com', 1, 52000.00, '2024-01-15', 1),
    (90005, 'Charlie', 'Davis', 'charlie.davis@test.com', 2, 58000.00, '2024-01-15', 1),
    (90006, 'Diana', 'Evans', 'diana.evans@test.com', 3, 61000.00, '2024-01-15', 1);
SET IDENTITY_INSERT dbo.employees OFF;

-- ASSERT
SELECT 
    'TC4' AS test_case,
    COUNT(*) AS audit_record_count,
    MIN(employee_id) AS min_employee_id,
    MAX(employee_id) AS max_employee_id,
    COUNT(DISTINCT operation_type) AS distinct_operations,
    MAX(operation_type) AS operation_type
FROM dbo.employee_audit
WHERE employee_id BETWEEN 90004 AND 90006;

-- CLEANUP
ROLLBACK TRANSACTION;

-- ============================================================================
-- TEST CASE 5: Multiple UPDATE - Batch update triggers multiple audit logs
-- ============================================================================
-- SETUP
BEGIN TRANSACTION;

-- Clear any existing test data
DELETE FROM dbo.employee_audit WHERE employee_id >= 90000;
DELETE FROM dbo.employees WHERE employee_id >= 90000;

-- Insert test employees
SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, first_name, last_name, email, department_id, salary, hire_date, is_active)
VALUES 
    (90007, 'Frank', 'Green', 'frank.green@test.com', 1, 50000.00, '2024-01-15', 1),
    (90008, 'Grace', 'Harris', 'grace.harris@test.com', 2, 55000.00, '2024-01-15', 1);
SET IDENTITY_INSERT dbo.employees OFF;

-- Clear audit log from INSERT
DELETE FROM dbo.employee_audit WHERE employee_id BETWEEN 90007 AND 90008;

-- EXEC
-- Update multiple employees (trigger should fire once for all)
UPDATE dbo.employees
SET salary = salary * 1.10
WHERE employee_id BETWEEN 90007 AND 90008;

-- ASSERT
SELECT 
    'TC5' AS test_case,
    COUNT(*) AS audit_record_count,
    MAX(operation_type) AS operation_type,
    SUM(CASE WHEN old_salary < new_salary THEN 1 ELSE 0 END) AS salary_increased_count
FROM dbo.employee_audit
WHERE employee_id BETWEEN 90007 AND 90008;

-- CLEANUP
ROLLBACK TRANSACTION;

-- ============================================================================
-- TEST CASE 6: UPDATE with NULL values - Handles NULL in old/new values
-- ============================================================================
-- SETUP
BEGIN TRANSACTION;

-- Clear any existing test data
DELETE FROM dbo.employee_audit WHERE employee_id >= 90000;
DELETE FROM dbo.employees WHERE employee_id >= 90000;

-- Insert test employee with some NULL values
SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, first_name, last_name, email, department_id, salary, hire_date, is_active)
VALUES (90009, 'Henry', 'Iverson', 'henry.iverson@test.com', NULL, 50000.00, '2024-01-15', 1);
SET IDENTITY_INSERT dbo.employees OFF;

-- Clear audit log from INSERT
DELETE FROM dbo.employee_audit WHERE employee_id = 90009;

-- EXEC
-- Update from NULL to value
UPDATE dbo.employees
SET department_id = 1
WHERE employee_id = 90009;

-- ASSERT
SELECT 
    'TC6' AS test_case,
    COUNT(*) AS audit_record_count,
    MAX(operation_type) AS operation_type,
    CASE WHEN MAX(old_department_id) IS NULL THEN 'NULL' ELSE CAST(MAX(old_department_id) AS VARCHAR) END AS old_dept,
    CASE WHEN MAX(new_department_id) IS NULL THEN 'NULL' ELSE CAST(MAX(new_department_id) AS VARCHAR) END AS new_dept
FROM dbo.employee_audit
WHERE employee_id = 90009;

-- CLEANUP
ROLLBACK TRANSACTION;

-- ============================================================================
-- TEST CASE 7: Transaction ROLLBACK - Audit entries rolled back with transaction
-- ============================================================================
-- SETUP
BEGIN TRANSACTION;

-- Clear any existing test data
DELETE FROM dbo.employee_audit WHERE employee_id >= 90000;
DELETE FROM dbo.employees WHERE employee_id >= 90000;

-- EXEC
-- Insert employee and then rollback
SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, first_name, last_name, email, department_id, salary, hire_date, is_active)
VALUES (90010, 'Iris', 'Jackson', 'iris.jackson@test.com', 1, 50000.00, '2024-01-15', 1);
SET IDENTITY_INSERT dbo.employees OFF;

-- Rollback the transaction
ROLLBACK TRANSACTION;

-- ASSERT (in new transaction)
BEGIN TRANSACTION;
SELECT 
    'TC7' AS test_case,
    COUNT(*) AS audit_record_count_after_rollback,
    COUNT(*) AS employee_record_count_after_rollback
FROM dbo.employee_audit
WHERE employee_id = 90010;

-- CLEANUP
ROLLBACK TRANSACTION;

-- ============================================================================
-- TEST CASE 8: UPDATE with no actual change - Trigger fires even if values unchanged
-- ============================================================================
-- SETUP
BEGIN TRANSACTION;

-- Clear any existing test data
DELETE FROM dbo.employee_audit WHERE employee_id >= 90000;
DELETE FROM dbo.employees WHERE employee_id >= 90000;

-- Insert test employee
SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, first_name, last_name, email, department_id, salary, hire_date, is_active)
VALUES (90011, 'Jack', 'Kelly', 'jack.kelly@test.com', 1, 50000.00, '2024-01-15', 1);
SET IDENTITY_INSERT dbo.employees OFF;

-- Clear audit log from INSERT
DELETE FROM dbo.employee_audit WHERE employee_id = 90011;

-- EXEC
-- Update with same values (trigger should still fire)
UPDATE dbo.employees
SET salary = 50000.00
WHERE employee_id = 90011;

-- ASSERT
SELECT 
    'TC8' AS test_case,
    COUNT(*) AS audit_record_count,
    MAX(operation_type) AS operation_type,
    MAX(old_salary) AS old_salary,
    MAX(new_salary) AS new_salary,
    CASE WHEN MAX(old_salary) = MAX(new_salary) THEN 'SAME' ELSE 'DIFFERENT' END AS value_comparison
FROM dbo.employee_audit
WHERE employee_id = 90011;

-- CLEANUP
ROLLBACK TRANSACTION;

-- ============================================================================
-- TEST CASE 9: Audit metadata - Verify operation_date and operation_user are populated
-- ============================================================================
-- SETUP
BEGIN TRANSACTION;

-- Clear any existing test data
DELETE FROM dbo.employee_audit WHERE employee_id >= 90000;
DELETE FROM dbo.employees WHERE employee_id >= 90000;

-- EXEC
-- Insert a new employee
SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, first_name, last_name, email, department_id, salary, hire_date, is_active)
VALUES (90012, 'Karen', 'Lopez', 'karen.lopez@test.com', 1, 50000.00, '2024-01-15', 1);
SET IDENTITY_INSERT dbo.employees OFF;

-- ASSERT
SELECT 
    'TC9' AS test_case,
    COUNT(*) AS audit_record_count,
    CASE WHEN MAX(operation_date) IS NULL THEN 'NULL' ELSE 'NOT_NULL' END AS operation_date_populated,
    CASE WHEN MAX(operation_user) IS NULL THEN 'NULL' ELSE 'NOT_NULL' END AS operation_user_populated,
    CASE WHEN MAX(operation_date) > DATEADD(MINUTE, -5, GETDATE()) THEN 'RECENT' ELSE 'OLD' END AS timestamp_check
FROM dbo.employee_audit
WHERE employee_id = 90012;

-- CLEANUP
ROLLBACK TRANSACTION;

-- ============================================================================
-- TEST CASE 10: Multiple DELETE - Batch delete triggers multiple audit logs
-- ============================================================================
-- SETUP
BEGIN TRANSACTION;

-- Clear any existing test data
DELETE FROM dbo.employee_audit WHERE employee_id >= 90000;
DELETE FROM dbo.employees WHERE employee_id >= 90000;

-- Insert test employees
SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, first_name, last_name, email, department_id, salary, hire_date, is_active)
VALUES 
    (90013, 'Larry', 'Martin', 'larry.martin@test.com', 1, 50000.00, '2024-01-15', 1),
    (90014, 'Mary', 'Nelson', 'mary.nelson@test.com', 2, 55000.00, '2024-01-15', 1),
    (90015, 'Nancy', 'Owens', 'nancy.owens@test.com', 3, 60000.00, '2024-01-15', 1);
SET IDENTITY_INSERT dbo.employees OFF;

-- Clear audit log from INSERT
DELETE FROM dbo.employee_audit WHERE employee_id BETWEEN 90013 AND 90015;

-- EXEC
-- Delete multiple employees (trigger should fire once for all)
DELETE FROM dbo.employees WHERE employee_id BETWEEN 90013 AND 90015;

-- ASSERT
SELECT 
    'TC10' AS test_case,
    COUNT(*) AS audit_record_count,
    MAX(operation_type) AS operation_type,
    COUNT(DISTINCT employee_id) AS distinct_employees,
    SUM(CASE WHEN old_first_name IS NOT NULL THEN 1 ELSE 0 END) AS old_values_populated,
    SUM(CASE WHEN new_first_name IS NOT NULL THEN 1 ELSE 0 END) AS new_values_populated
FROM dbo.employee_audit
WHERE employee_id BETWEEN 90013 AND 90015;

-- CLEANUP
ROLLBACK TRANSACTION;

-- ============================================================================
-- END OF TEST SUITE
-- ============================================================================
