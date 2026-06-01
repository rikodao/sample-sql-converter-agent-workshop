-- ============================================================
-- TEST SUITE: dbo.usp_bulk_deactivate_employees
-- Description: Bulk deactivate employees using table-valued parameter
-- ============================================================

-- ============= TEST CASE 1: Normal - Deactivate single active employee =============
-- SETUP
DECLARE @test_ids1 dbo.EmployeeIdList;
DECLARE @count1 INT;

-- Create test employee
SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES (99901, 1, 'Test', 'User1', '2020-01-01', 1, 'test1@example.com', '2020-01-01 00:00:00');
SET IDENTITY_INSERT dbo.employees OFF;

-- EXEC
INSERT INTO @test_ids1 (employee_id) VALUES (99901);
EXEC dbo.usp_bulk_deactivate_employees @employee_ids = @test_ids1, @deactivated_count = @count1 OUTPUT;

-- ASSERT
SELECT 'TC1' AS tc, @count1 AS deactivated_count, is_active 
FROM dbo.employees 
WHERE employee_id = 99901;

-- CLEANUP
DELETE FROM dbo.employees WHERE employee_id = 99901;

-- ============= TEST CASE 2: Normal - Deactivate multiple active employees =============
-- SETUP
DECLARE @test_ids2 dbo.EmployeeIdList;
DECLARE @count2 INT;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES 
    (99902, 1, 'Test', 'User2', '2020-01-01', 1, 'test2@example.com', '2020-01-01 00:00:00'),
    (99903, 2, 'Test', 'User3', '2020-01-01', 1, 'test3@example.com', '2020-01-01 00:00:00'),
    (99904, 3, 'Test', 'User4', '2020-01-01', 1, 'test4@example.com', '2020-01-01 00:00:00');
SET IDENTITY_INSERT dbo.employees OFF;

-- EXEC
INSERT INTO @test_ids2 (employee_id) VALUES (99902), (99903), (99904);
EXEC dbo.usp_bulk_deactivate_employees @employee_ids = @test_ids2, @deactivated_count = @count2 OUTPUT;

-- ASSERT
SELECT 'TC2' AS tc, @count2 AS deactivated_count;
SELECT 'TC2' AS tc, employee_id, is_active 
FROM dbo.employees 
WHERE employee_id IN (99902, 99903, 99904)
ORDER BY employee_id;

-- CLEANUP
DELETE FROM dbo.employees WHERE employee_id IN (99902, 99903, 99904);

-- ============= TEST CASE 3: Normal - Partial match (some IDs exist, some don't) =============
-- SETUP
DECLARE @test_ids3 dbo.EmployeeIdList;
DECLARE @count3 INT;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES 
    (99905, 1, 'Test', 'User5', '2020-01-01', 1, 'test5@example.com', '2020-01-01 00:00:00'),
    (99906, 2, 'Test', 'User6', '2020-01-01', 1, 'test6@example.com', '2020-01-01 00:00:00');
SET IDENTITY_INSERT dbo.employees OFF;

-- EXEC
INSERT INTO @test_ids3 (employee_id) VALUES (99905), (99906), (99999); -- 99999 doesn't exist
EXEC dbo.usp_bulk_deactivate_employees @employee_ids = @test_ids3, @deactivated_count = @count3 OUTPUT;

-- ASSERT
SELECT 'TC3' AS tc, @count3 AS deactivated_count;
SELECT 'TC3' AS tc, employee_id, is_active 
FROM dbo.employees 
WHERE employee_id IN (99905, 99906)
ORDER BY employee_id;

-- CLEANUP
DELETE FROM dbo.employees WHERE employee_id IN (99905, 99906);

-- ============= TEST CASE 4: Boundary - Empty input list =============
-- SETUP
DECLARE @test_ids4 dbo.EmployeeIdList;
DECLARE @count4 INT;

-- EXEC
EXEC dbo.usp_bulk_deactivate_employees @employee_ids = @test_ids4, @deactivated_count = @count4 OUTPUT;

-- ASSERT
SELECT 'TC4' AS tc, @count4 AS deactivated_count;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 5: Boundary - Deactivate already inactive employee =============
-- SETUP
DECLARE @test_ids5 dbo.EmployeeIdList;
DECLARE @count5 INT;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES (99907, 1, 'Test', 'User7', '2020-01-01', 0, 'test7@example.com', '2020-01-01 00:00:00');
SET IDENTITY_INSERT dbo.employees OFF;

-- EXEC
INSERT INTO @test_ids5 (employee_id) VALUES (99907);
EXEC dbo.usp_bulk_deactivate_employees @employee_ids = @test_ids5, @deactivated_count = @count5 OUTPUT;

-- ASSERT
SELECT 'TC5' AS tc, @count5 AS deactivated_count, is_active 
FROM dbo.employees 
WHERE employee_id = 99907;

-- CLEANUP
DELETE FROM dbo.employees WHERE employee_id = 99907;

-- ============= TEST CASE 6: Boundary - Non-existent employee IDs only =============
-- SETUP
DECLARE @test_ids6 dbo.EmployeeIdList;
DECLARE @count6 INT;

-- EXEC
INSERT INTO @test_ids6 (employee_id) VALUES (88888), (88889);
EXEC dbo.usp_bulk_deactivate_employees @employee_ids = @test_ids6, @deactivated_count = @count6 OUTPUT;

-- ASSERT
SELECT 'TC6' AS tc, @count6 AS deactivated_count;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 7: Boundary - Large batch (10 employees) =============
-- SETUP
DECLARE @test_ids7 dbo.EmployeeIdList;
DECLARE @count7 INT;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES 
    (99910, 1, 'Test', 'User10', '2020-01-01', 1, 'test10@example.com', '2020-01-01 00:00:00'),
    (99911, 1, 'Test', 'User11', '2020-01-01', 1, 'test11@example.com', '2020-01-01 00:00:00'),
    (99912, 1, 'Test', 'User12', '2020-01-01', 1, 'test12@example.com', '2020-01-01 00:00:00'),
    (99913, 1, 'Test', 'User13', '2020-01-01', 1, 'test13@example.com', '2020-01-01 00:00:00'),
    (99914, 1, 'Test', 'User14', '2020-01-01', 1, 'test14@example.com', '2020-01-01 00:00:00'),
    (99915, 1, 'Test', 'User15', '2020-01-01', 1, 'test15@example.com', '2020-01-01 00:00:00'),
    (99916, 1, 'Test', 'User16', '2020-01-01', 1, 'test16@example.com', '2020-01-01 00:00:00'),
    (99917, 1, 'Test', 'User17', '2020-01-01', 1, 'test17@example.com', '2020-01-01 00:00:00'),
    (99918, 1, 'Test', 'User18', '2020-01-01', 1, 'test18@example.com', '2020-01-01 00:00:00'),
    (99919, 1, 'Test', 'User19', '2020-01-01', 1, 'test19@example.com', '2020-01-01 00:00:00');
SET IDENTITY_INSERT dbo.employees OFF;

-- EXEC
INSERT INTO @test_ids7 (employee_id) 
VALUES (99910), (99911), (99912), (99913), (99914), (99915), (99916), (99917), (99918), (99919);
EXEC dbo.usp_bulk_deactivate_employees @employee_ids = @test_ids7, @deactivated_count = @count7 OUTPUT;

-- ASSERT
SELECT 'TC7' AS tc, @count7 AS deactivated_count;
SELECT 'TC7' AS tc, COUNT(*) AS inactive_count 
FROM dbo.employees 
WHERE employee_id BETWEEN 99910 AND 99919 AND is_active = 0;

-- CLEANUP
DELETE FROM dbo.employees WHERE employee_id BETWEEN 99910 AND 99919;

-- ============= TEST CASE 8: Side Effect - Mixed active and inactive employees =============
-- SETUP
DECLARE @test_ids8 dbo.EmployeeIdList;
DECLARE @count8 INT;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES 
    (99920, 1, 'Test', 'User20', '2020-01-01', 1, 'test20@example.com', '2020-01-01 00:00:00'),
    (99921, 2, 'Test', 'User21', '2020-01-01', 0, 'test21@example.com', '2020-01-01 00:00:00'),
    (99922, 3, 'Test', 'User22', '2020-01-01', 1, 'test22@example.com', '2020-01-01 00:00:00');
SET IDENTITY_INSERT dbo.employees OFF;

-- EXEC
INSERT INTO @test_ids8 (employee_id) VALUES (99920), (99921), (99922);
EXEC dbo.usp_bulk_deactivate_employees @employee_ids = @test_ids8, @deactivated_count = @count8 OUTPUT;

-- ASSERT
SELECT 'TC8' AS tc, @count8 AS deactivated_count;
SELECT 'TC8' AS tc, employee_id, is_active 
FROM dbo.employees 
WHERE employee_id IN (99920, 99921, 99922)
ORDER BY employee_id;

-- CLEANUP
DELETE FROM dbo.employees WHERE employee_id IN (99920, 99921, 99922);

-- ============= TEST CASE 9: Side Effect - Verify other columns unchanged =============
-- SETUP
DECLARE @test_ids9 dbo.EmployeeIdList;
DECLARE @count9 INT;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES (99923, 5, 'Original', 'Name', '2019-06-15', 1, 'original@example.com', '2019-06-15 10:30:00');
SET IDENTITY_INSERT dbo.employees OFF;

-- EXEC
INSERT INTO @test_ids9 (employee_id) VALUES (99923);
EXEC dbo.usp_bulk_deactivate_employees @employee_ids = @test_ids9, @deactivated_count = @count9 OUTPUT;

-- ASSERT
SELECT 'TC9' AS tc, @count9 AS deactivated_count;
SELECT 'TC9' AS tc, employee_id, department_id, first_name, last_name, hire_date, is_active, email
FROM dbo.employees 
WHERE employee_id = 99923;

-- CLEANUP
DELETE FROM dbo.employees WHERE employee_id = 99923;

-- ============= TEST CASE 10: Transaction - Verify UPDATE is atomic =============
-- SETUP
DECLARE @test_ids10 dbo.EmployeeIdList;
DECLARE @count10 INT;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES 
    (99924, 1, 'Test', 'User24', '2020-01-01', 1, 'test24@example.com', '2020-01-01 00:00:00'),
    (99925, 2, 'Test', 'User25', '2020-01-01', 1, 'test25@example.com', '2020-01-01 00:00:00');
SET IDENTITY_INSERT dbo.employees OFF;

-- EXEC within transaction and rollback
BEGIN TRANSACTION;
INSERT INTO @test_ids10 (employee_id) VALUES (99924), (99925);
EXEC dbo.usp_bulk_deactivate_employees @employee_ids = @test_ids10, @deactivated_count = @count10 OUTPUT;

-- ASSERT (within transaction)
SELECT 'TC10' AS tc, @count10 AS deactivated_count;
SELECT 'TC10' AS tc, 'BEFORE_ROLLBACK' AS status, employee_id, is_active 
FROM dbo.employees 
WHERE employee_id IN (99924, 99925)
ORDER BY employee_id;

ROLLBACK TRANSACTION;

-- ASSERT (after rollback)
SELECT 'TC10' AS tc, 'AFTER_ROLLBACK' AS status, employee_id, is_active 
FROM dbo.employees 
WHERE employee_id IN (99924, 99925)
ORDER BY employee_id;

-- CLEANUP
DELETE FROM dbo.employees WHERE employee_id IN (99924, 99925);
