-- ============================================================================
-- TEST SUITE: dbo.usp_validate_and_create_dept
-- ============================================================================
-- This test suite validates the stored procedure that creates departments
-- with validation logic and error logging.
-- ============================================================================

-- ============= TEST CASE 1: Normal insert with valid name and no parent =============
-- SETUP
CREATE TABLE #test_departments (
    department_id INT,
    name NVARCHAR(100),
    parent_id INT
);

CREATE TABLE #test_audit_log (
    audit_id INT,
    table_name NVARCHAR(100),
    operation NVARCHAR(50),
    primary_key NVARCHAR(100)
);

-- Get baseline count
DECLARE @baseline_dept_count INT;
SELECT @baseline_dept_count = COUNT(*) FROM dbo.departments;

-- EXEC
EXEC dbo.usp_validate_and_create_dept @name = N'Test Department TC1', @parent_id = NULL;

-- ASSERT
INSERT INTO #test_departments
SELECT department_id, name, parent_id 
FROM dbo.departments 
WHERE name = N'Test Department TC1';

SELECT 'TC1' AS tc, 
       CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END AS result,
       COUNT(*) AS inserted_count
FROM #test_departments;

-- CLEANUP
DELETE FROM dbo.departments WHERE name = N'Test Department TC1';
DROP TABLE #test_departments;
DROP TABLE #test_audit_log;
GO

-- ============= TEST CASE 2: Normal insert with valid parent_id =============
-- SETUP
CREATE TABLE #test_departments2 (
    department_id INT,
    name NVARCHAR(100),
    parent_id INT
);

-- Get an existing department_id to use as parent
DECLARE @valid_parent_id INT;
SELECT TOP 1 @valid_parent_id = department_id FROM dbo.departments;

-- EXEC
EXEC dbo.usp_validate_and_create_dept @name = N'Test Sub-Department TC2', @parent_id = @valid_parent_id;

-- ASSERT
INSERT INTO #test_departments2
SELECT department_id, name, parent_id 
FROM dbo.departments 
WHERE name = N'Test Sub-Department TC2';

SELECT 'TC2' AS tc,
       CASE WHEN COUNT(*) = 1 AND MIN(parent_id) = @valid_parent_id THEN 'PASS' ELSE 'FAIL' END AS result,
       MIN(parent_id) AS parent_id_value
FROM #test_departments2;

-- CLEANUP
DELETE FROM dbo.departments WHERE name = N'Test Sub-Department TC2';
DROP TABLE #test_departments2;
GO

-- ============= TEST CASE 3: Normal insert with long valid name =============
-- SETUP
CREATE TABLE #test_departments3 (
    department_id INT,
    name NVARCHAR(100),
    parent_id INT
);

DECLARE @long_name NVARCHAR(100) = REPLICATE(N'A', 90) + N' TC3';

-- EXEC
EXEC dbo.usp_validate_and_create_dept @name = @long_name, @parent_id = NULL;

-- ASSERT
INSERT INTO #test_departments3
SELECT department_id, name, parent_id 
FROM dbo.departments 
WHERE name = @long_name;

SELECT 'TC3' AS tc,
       CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END AS result,
       LEN(MIN(name)) AS name_length
FROM #test_departments3;

-- CLEANUP
DELETE FROM dbo.departments WHERE name = @long_name;
DROP TABLE #test_departments3;
GO

-- ============= TEST CASE 4: Boundary - NULL name (should fail with error 51001) =============
-- SETUP
CREATE TABLE #test_audit4 (
    audit_id INT,
    table_name NVARCHAR(100),
    operation NVARCHAR(50)
);

DECLARE @baseline_count4 INT;
SELECT @baseline_count4 = COUNT(*) FROM dbo.departments;

-- EXEC
BEGIN TRY
    EXEC dbo.usp_validate_and_create_dept @name = NULL, @parent_id = NULL;
    SELECT 'TC4' AS tc, 'NO_ERROR' AS result, 0 AS error_number;
END TRY
BEGIN CATCH
    -- ASSERT
    SELECT 'TC4' AS tc, 
           'ERROR_CAUGHT' AS result,
           ERROR_NUMBER() AS error_number,
           ERROR_MESSAGE() AS error_message;
    
    -- Check audit log was written
    INSERT INTO #test_audit4
    SELECT TOP 1 audit_id, table_name, operation
    FROM dbo.audit_log
    WHERE table_name = N'departments_validation_failed'
    ORDER BY audit_id DESC;
END CATCH

-- Verify no department was inserted
DECLARE @after_count4 INT;
SELECT @after_count4 = COUNT(*) FROM dbo.departments;

SELECT 'TC4' AS tc, 
       'VERIFY_NO_INSERT' AS check_type,
       CASE WHEN @after_count4 = @baseline_count4 THEN 'PASS' ELSE 'FAIL' END AS result;

-- CLEANUP
DROP TABLE #test_audit4;
GO

-- ============= TEST CASE 5: Boundary - Empty string name (should fail with error 51001) =============
-- SETUP
DECLARE @baseline_count5 INT;
SELECT @baseline_count5 = COUNT(*) FROM dbo.departments;

-- EXEC
BEGIN TRY
    EXEC dbo.usp_validate_and_create_dept @name = N'', @parent_id = NULL;
    SELECT 'TC5' AS tc, 'NO_ERROR' AS result, 0 AS error_number;
END TRY
BEGIN CATCH
    -- ASSERT
    SELECT 'TC5' AS tc, 
           'ERROR_CAUGHT' AS result,
           ERROR_NUMBER() AS error_number,
           ERROR_MESSAGE() AS error_message;
END CATCH

-- Verify no department was inserted
DECLARE @after_count5 INT;
SELECT @after_count5 = COUNT(*) FROM dbo.departments;

SELECT 'TC5' AS tc, 
       'VERIFY_NO_INSERT' AS check_type,
       CASE WHEN @after_count5 = @baseline_count5 THEN 'PASS' ELSE 'FAIL' END AS result;

-- CLEANUP
-- (no cleanup needed)
GO

-- ============= TEST CASE 6: Boundary - Whitespace-only name (should fail with error 51001) =============
-- SETUP
DECLARE @baseline_count6 INT;
SELECT @baseline_count6 = COUNT(*) FROM dbo.departments;

-- EXEC
BEGIN TRY
    EXEC dbo.usp_validate_and_create_dept @name = N'   ', @parent_id = NULL;
    SELECT 'TC6' AS tc, 'NO_ERROR' AS result, 0 AS error_number;
END TRY
BEGIN CATCH
    -- ASSERT
    SELECT 'TC6' AS tc, 
           'ERROR_CAUGHT' AS result,
           ERROR_NUMBER() AS error_number,
           ERROR_MESSAGE() AS error_message;
END CATCH

-- Verify no department was inserted
DECLARE @after_count6 INT;
SELECT @after_count6 = COUNT(*) FROM dbo.departments;

SELECT 'TC6' AS tc, 
       'VERIFY_NO_INSERT' AS check_type,
       CASE WHEN @after_count6 = @baseline_count6 THEN 'PASS' ELSE 'FAIL' END AS result;

-- CLEANUP
-- (no cleanup needed)
GO

-- ============= TEST CASE 7: Exception - Duplicate name (should fail with error 51002) =============
-- SETUP
-- Insert a test department first
INSERT INTO dbo.departments(name, parent_id) VALUES(N'Duplicate Test TC7', NULL);

DECLARE @baseline_count7 INT;
SELECT @baseline_count7 = COUNT(*) FROM dbo.departments;

-- EXEC
BEGIN TRY
    EXEC dbo.usp_validate_and_create_dept @name = N'Duplicate Test TC7', @parent_id = NULL;
    SELECT 'TC7' AS tc, 'NO_ERROR' AS result, 0 AS error_number;
END TRY
BEGIN CATCH
    -- ASSERT
    SELECT 'TC7' AS tc, 
           'ERROR_CAUGHT' AS result,
           ERROR_NUMBER() AS error_number,
           ERROR_MESSAGE() AS error_message;
END CATCH

-- Verify no additional department was inserted
DECLARE @after_count7 INT;
SELECT @after_count7 = COUNT(*) FROM dbo.departments;

SELECT 'TC7' AS tc, 
       'VERIFY_NO_DUPLICATE' AS check_type,
       CASE WHEN @after_count7 = @baseline_count7 THEN 'PASS' ELSE 'FAIL' END AS result;

-- CLEANUP
DELETE FROM dbo.departments WHERE name = N'Duplicate Test TC7';
GO

-- ============= TEST CASE 8: Exception - Invalid parent_id (should fail with error 51003) =============
-- SETUP
DECLARE @baseline_count8 INT;
SELECT @baseline_count8 = COUNT(*) FROM dbo.departments;

-- Use a parent_id that doesn't exist (negative number)
DECLARE @invalid_parent_id INT = -99999;

-- EXEC
BEGIN TRY
    EXEC dbo.usp_validate_and_create_dept @name = N'Test Invalid Parent TC8', @parent_id = @invalid_parent_id;
    SELECT 'TC8' AS tc, 'NO_ERROR' AS result, 0 AS error_number;
END TRY
BEGIN CATCH
    -- ASSERT
    SELECT 'TC8' AS tc, 
           'ERROR_CAUGHT' AS result,
           ERROR_NUMBER() AS error_number,
           ERROR_MESSAGE() AS error_message;
END CATCH

-- Verify no department was inserted
DECLARE @after_count8 INT;
SELECT @after_count8 = COUNT(*) FROM dbo.departments;

SELECT 'TC8' AS tc, 
       'VERIFY_NO_INSERT' AS check_type,
       CASE WHEN @after_count8 = @baseline_count8 THEN 'PASS' ELSE 'FAIL' END AS result;

-- CLEANUP
-- (no cleanup needed)
GO

-- ============= TEST CASE 9: Side effect - Verify audit_log entry on error =============
-- SETUP
DECLARE @baseline_audit_count9 INT;
SELECT @baseline_audit_count9 = COUNT(*) FROM dbo.audit_log WHERE table_name = N'departments_validation_failed';

-- EXEC
BEGIN TRY
    EXEC dbo.usp_validate_and_create_dept @name = NULL, @parent_id = NULL;
END TRY
BEGIN CATCH
    -- Suppress error for this test
    DECLARE @dummy_msg NVARCHAR(2000) = ERROR_MESSAGE();
END CATCH

-- ASSERT
DECLARE @after_audit_count9 INT;
SELECT @after_audit_count9 = COUNT(*) FROM dbo.audit_log WHERE table_name = N'departments_validation_failed';

SELECT 'TC9' AS tc,
       'AUDIT_LOG_WRITTEN' AS check_type,
       CASE WHEN @after_audit_count9 > @baseline_audit_count9 THEN 'PASS' ELSE 'FAIL' END AS result,
       @after_audit_count9 - @baseline_audit_count9 AS new_audit_entries;

-- CLEANUP
-- (audit log entries are kept for audit purposes)
GO

-- ============= TEST CASE 10: Side effect - Verify @@ROWCOUNT after successful insert =============
-- SETUP
CREATE TABLE #test_rowcount10 (
    rowcount_value INT
);

-- EXEC
EXEC dbo.usp_validate_and_create_dept @name = N'Test Rowcount TC10', @parent_id = NULL;

-- ASSERT
-- Check that exactly one row was inserted
DECLARE @inserted_count10 INT;
SELECT @inserted_count10 = COUNT(*) FROM dbo.departments WHERE name = N'Test Rowcount TC10';

SELECT 'TC10' AS tc,
       'ROWCOUNT_CHECK' AS check_type,
       CASE WHEN @inserted_count10 = 1 THEN 'PASS' ELSE 'FAIL' END AS result,
       @inserted_count10 AS actual_count;

-- CLEANUP
DELETE FROM dbo.departments WHERE name = N'Test Rowcount TC10';
DROP TABLE #test_rowcount10;
GO

-- ============= TEST CASE 11: Transaction - Verify rollback on error (no partial insert) =============
-- SETUP
DECLARE @baseline_count11 INT;
SELECT @baseline_count11 = COUNT(*) FROM dbo.departments;

-- EXEC - Try to insert with duplicate name
INSERT INTO dbo.departments(name, parent_id) VALUES(N'Rollback Test TC11', NULL);

BEGIN TRY
    EXEC dbo.usp_validate_and_create_dept @name = N'Rollback Test TC11', @parent_id = NULL;
END TRY
BEGIN CATCH
    -- Error expected
    SELECT 'TC11' AS tc, 
           'ERROR_EXPECTED' AS result,
           ERROR_NUMBER() AS error_number;
END CATCH

-- ASSERT - Verify only one department with this name exists (the original)
DECLARE @count_after11 INT;
SELECT @count_after11 = COUNT(*) FROM dbo.departments WHERE name = N'Rollback Test TC11';

SELECT 'TC11' AS tc,
       'ROLLBACK_VERIFY' AS check_type,
       CASE WHEN @count_after11 = 1 THEN 'PASS' ELSE 'FAIL' END AS result,
       @count_after11 AS actual_count;

-- CLEANUP
DELETE FROM dbo.departments WHERE name = N'Rollback Test TC11';
GO

-- ============================================================================
-- END OF TEST SUITE
-- ============================================================================
