-- ============================================================================
-- TEST SUITE: dbo.usp_validate_and_create_dept
-- Source: SQL Server
-- Purpose: Comprehensive validation and creation testing
-- ============================================================================

-- ============================================================================
-- TEST CASE 1: Normal creation with all parameters
-- ============================================================================
-- SETUP
DECLARE @tc1_dept_id INT;
DECLARE @tc1_status NVARCHAR(50);
DECLARE @tc1_error NVARCHAR(500);
DECLARE @tc1_manager_id INT;

-- Get a valid manager ID
SELECT TOP 1 @tc1_manager_id = employee_id 
FROM dbo.employees 
WHERE is_active = 1
ORDER BY employee_id;

-- EXEC
EXEC dbo.usp_validate_and_create_dept
    @department_name = 'Test Department TC1',
    @location = 'New York',
    @manager_id = @tc1_manager_id,
    @min_name_length = 3,
    @max_name_length = 100,
    @new_department_id = @tc1_dept_id OUTPUT,
    @validation_status = @tc1_status OUTPUT,
    @error_message = @tc1_error OUTPUT;

-- ASSERT
SELECT 
    'TC1' AS test_case,
    'Normal creation with all parameters' AS description,
    @tc1_status AS validation_status,
    CASE WHEN @tc1_dept_id IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS dept_id_check,
    CASE WHEN @tc1_error IS NULL THEN 'PASS' ELSE 'FAIL' END AS error_check,
    @tc1_error AS error_message;

-- CLEANUP
IF @tc1_dept_id IS NOT NULL
BEGIN
    DELETE FROM dbo.departments WHERE department_id = @tc1_dept_id;
END
GO

-- ============================================================================
-- TEST CASE 2: Normal creation with minimal parameters (no manager, no location)
-- ============================================================================
-- SETUP
DECLARE @tc2_dept_id INT;
DECLARE @tc2_status NVARCHAR(50);
DECLARE @tc2_error NVARCHAR(500);

-- EXEC
EXEC dbo.usp_validate_and_create_dept
    @department_name = 'Test Department TC2',
    @location = NULL,
    @manager_id = NULL,
    @min_name_length = 3,
    @max_name_length = 100,
    @new_department_id = @tc2_dept_id OUTPUT,
    @validation_status = @tc2_status OUTPUT,
    @error_message = @tc2_error OUTPUT;

-- ASSERT
SELECT 
    'TC2' AS test_case,
    'Minimal parameters (no manager, no location)' AS description,
    @tc2_status AS validation_status,
    CASE WHEN @tc2_dept_id IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS dept_id_check,
    CASE WHEN @tc2_error IS NULL THEN 'PASS' ELSE 'FAIL' END AS error_check;

-- CLEANUP
IF @tc2_dept_id IS NOT NULL
BEGIN
    DELETE FROM dbo.departments WHERE department_id = @tc2_dept_id;
END
GO

-- ============================================================================
-- TEST CASE 3: Normal creation with default validation thresholds
-- ============================================================================
-- SETUP
DECLARE @tc3_dept_id INT;
DECLARE @tc3_status NVARCHAR(50);
DECLARE @tc3_error NVARCHAR(500);

-- EXEC (using default min/max values)
EXEC dbo.usp_validate_and_create_dept
    @department_name = 'Test Department TC3',
    @location = 'Boston',
    @manager_id = NULL,
    @new_department_id = @tc3_dept_id OUTPUT,
    @validation_status = @tc3_status OUTPUT,
    @error_message = @tc3_error OUTPUT;

-- ASSERT
SELECT 
    'TC3' AS test_case,
    'Default validation thresholds' AS description,
    @tc3_status AS validation_status,
    CASE WHEN @tc3_dept_id IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS dept_id_check;

-- CLEANUP
IF @tc3_dept_id IS NOT NULL
BEGIN
    DELETE FROM dbo.departments WHERE department_id = @tc3_dept_id;
END
GO

-- ============================================================================
-- TEST CASE 4: Boundary - Minimum length name (exactly 3 characters)
-- ============================================================================
-- SETUP
DECLARE @tc4_dept_id INT;
DECLARE @tc4_status NVARCHAR(50);
DECLARE @tc4_error NVARCHAR(500);

-- EXEC
EXEC dbo.usp_validate_and_create_dept
    @department_name = 'ABC',
    @location = NULL,
    @manager_id = NULL,
    @min_name_length = 3,
    @max_name_length = 100,
    @new_department_id = @tc4_dept_id OUTPUT,
    @validation_status = @tc4_status OUTPUT,
    @error_message = @tc4_error OUTPUT;

-- ASSERT
SELECT 
    'TC4' AS test_case,
    'Minimum length (3 chars)' AS description,
    @tc4_status AS validation_status,
    CASE WHEN @tc4_dept_id IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS dept_id_check,
    @tc4_error AS error_message;

-- CLEANUP
IF @tc4_dept_id IS NOT NULL
BEGIN
    DELETE FROM dbo.departments WHERE department_id = @tc4_dept_id;
END
GO

-- ============================================================================
-- TEST CASE 5: Boundary - Below minimum length (2 characters)
-- ============================================================================
-- SETUP
DECLARE @tc5_dept_id INT;
DECLARE @tc5_status NVARCHAR(50);
DECLARE @tc5_error NVARCHAR(500);

-- EXEC
EXEC dbo.usp_validate_and_create_dept
    @department_name = 'AB',
    @location = NULL,
    @manager_id = NULL,
    @min_name_length = 3,
    @max_name_length = 100,
    @new_department_id = @tc5_dept_id OUTPUT,
    @validation_status = @tc5_status OUTPUT,
    @error_message = @tc5_error OUTPUT;

-- ASSERT
SELECT 
    'TC5' AS test_case,
    'Below minimum length (2 chars)' AS description,
    @tc5_status AS validation_status,
    CASE WHEN @tc5_dept_id IS NULL THEN 'PASS' ELSE 'FAIL' END AS dept_id_null_check,
    CASE WHEN @tc5_error LIKE '%at least%' THEN 'PASS' ELSE 'FAIL' END AS error_message_check,
    @tc5_error AS error_message;

-- CLEANUP (none needed - should not have created)
GO

-- ============================================================================
-- TEST CASE 6: Boundary - Maximum length name (exactly 100 characters)
-- ============================================================================
-- SETUP
DECLARE @tc6_dept_id INT;
DECLARE @tc6_status NVARCHAR(50);
DECLARE @tc6_error NVARCHAR(500);
DECLARE @tc6_long_name NVARCHAR(100);

SET @tc6_long_name = REPLICATE('A', 100);

-- EXEC
EXEC dbo.usp_validate_and_create_dept
    @department_name = @tc6_long_name,
    @location = NULL,
    @manager_id = NULL,
    @min_name_length = 3,
    @max_name_length = 100,
    @new_department_id = @tc6_dept_id OUTPUT,
    @validation_status = @tc6_status OUTPUT,
    @error_message = @tc6_error OUTPUT;

-- ASSERT
SELECT 
    'TC6' AS test_case,
    'Maximum length (100 chars)' AS description,
    @tc6_status AS validation_status,
    CASE WHEN @tc6_dept_id IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS dept_id_check,
    LEN(@tc6_long_name) AS name_length;

-- CLEANUP
IF @tc6_dept_id IS NOT NULL
BEGIN
    DELETE FROM dbo.departments WHERE department_id = @tc6_dept_id;
END
GO

-- ============================================================================
-- TEST CASE 7: Boundary - Above maximum length (101 characters)
-- ============================================================================
-- SETUP
DECLARE @tc7_dept_id INT;
DECLARE @tc7_status NVARCHAR(50);
DECLARE @tc7_error NVARCHAR(500);
DECLARE @tc7_long_name NVARCHAR(110);

SET @tc7_long_name = REPLICATE('B', 101);

-- EXEC
EXEC dbo.usp_validate_and_create_dept
    @department_name = @tc7_long_name,
    @location = NULL,
    @manager_id = NULL,
    @min_name_length = 3,
    @max_name_length = 100,
    @new_department_id = @tc7_dept_id OUTPUT,
    @validation_status = @tc7_status OUTPUT,
    @error_message = @tc7_error OUTPUT;

-- ASSERT
SELECT 
    'TC7' AS test_case,
    'Above maximum length (101 chars)' AS description,
    @tc7_status AS validation_status,
    CASE WHEN @tc7_dept_id IS NULL THEN 'PASS' ELSE 'FAIL' END AS dept_id_null_check,
    CASE WHEN @tc7_error LIKE '%not exceed%' THEN 'PASS' ELSE 'FAIL' END AS error_message_check,
    @tc7_error AS error_message;

-- CLEANUP (none needed - should not have created)
GO

-- ============================================================================
-- TEST CASE 8: Exception - NULL department name
-- ============================================================================
-- SETUP
DECLARE @tc8_dept_id INT;
DECLARE @tc8_status NVARCHAR(50);
DECLARE @tc8_error NVARCHAR(500);

-- EXEC
EXEC dbo.usp_validate_and_create_dept
    @department_name = NULL,
    @location = 'Chicago',
    @manager_id = NULL,
    @min_name_length = 3,
    @max_name_length = 100,
    @new_department_id = @tc8_dept_id OUTPUT,
    @validation_status = @tc8_status OUTPUT,
    @error_message = @tc8_error OUTPUT;

-- ASSERT
SELECT 
    'TC8' AS test_case,
    'NULL department name' AS description,
    @tc8_status AS validation_status,
    CASE WHEN @tc8_dept_id IS NULL THEN 'PASS' ELSE 'FAIL' END AS dept_id_null_check,
    CASE WHEN @tc8_error LIKE '%NULL%' THEN 'PASS' ELSE 'FAIL' END AS error_message_check,
    @tc8_error AS error_message;

-- CLEANUP (none needed)
GO

-- ============================================================================
-- TEST CASE 9: Exception - Empty string department name
-- ============================================================================
-- SETUP
DECLARE @tc9_dept_id INT;
DECLARE @tc9_status NVARCHAR(50);
DECLARE @tc9_error NVARCHAR(500);

-- EXEC
EXEC dbo.usp_validate_and_create_dept
    @department_name = '',
    @location = 'Seattle',
    @manager_id = NULL,
    @min_name_length = 3,
    @max_name_length = 100,
    @new_department_id = @tc9_dept_id OUTPUT,
    @validation_status = @tc9_status OUTPUT,
    @error_message = @tc9_error OUTPUT;

-- ASSERT
SELECT 
    'TC9' AS test_case,
    'Empty string department name' AS description,
    @tc9_status AS validation_status,
    CASE WHEN @tc9_dept_id IS NULL THEN 'PASS' ELSE 'FAIL' END AS dept_id_null_check,
    CASE WHEN @tc9_error LIKE '%empty%' THEN 'PASS' ELSE 'FAIL' END AS error_message_check,
    @tc9_error AS error_message;

-- CLEANUP (none needed)
GO

-- ============================================================================
-- TEST CASE 10: Exception - Whitespace only department name
-- ============================================================================
-- SETUP
DECLARE @tc10_dept_id INT;
DECLARE @tc10_status NVARCHAR(50);
DECLARE @tc10_error NVARCHAR(500);

-- EXEC
EXEC dbo.usp_validate_and_create_dept
    @department_name = '     ',
    @location = 'Portland',
    @manager_id = NULL,
    @min_name_length = 3,
    @max_name_length = 100,
    @new_department_id = @tc10_dept_id OUTPUT,
    @validation_status = @tc10_status OUTPUT,
    @error_message = @tc10_error OUTPUT;

-- ASSERT
SELECT 
    'TC10' AS test_case,
    'Whitespace only department name' AS description,
    @tc10_status AS validation_status,
    CASE WHEN @tc10_dept_id IS NULL THEN 'PASS' ELSE 'FAIL' END AS dept_id_null_check,
    CASE WHEN @tc10_error LIKE '%empty%whitespace%' THEN 'PASS' ELSE 'FAIL' END AS error_message_check,
    @tc10_error AS error_message;

-- CLEANUP (none needed)
GO

-- ============================================================================
-- TEST CASE 11: Exception - Duplicate department name
-- ============================================================================
-- SETUP
DECLARE @tc11_dept_id1 INT;
DECLARE @tc11_dept_id2 INT;
DECLARE @tc11_status1 NVARCHAR(50);
DECLARE @tc11_status2 NVARCHAR(50);
DECLARE @tc11_error1 NVARCHAR(500);
DECLARE @tc11_error2 NVARCHAR(500);

-- Create first department
EXEC dbo.usp_validate_and_create_dept
    @department_name = 'Duplicate Test Dept',
    @location = 'Miami',
    @manager_id = NULL,
    @min_name_length = 3,
    @max_name_length = 100,
    @new_department_id = @tc11_dept_id1 OUTPUT,
    @validation_status = @tc11_status1 OUTPUT,
    @error_message = @tc11_error1 OUTPUT;

-- EXEC - Try to create duplicate
EXEC dbo.usp_validate_and_create_dept
    @department_name = 'Duplicate Test Dept',
    @location = 'Dallas',
    @manager_id = NULL,
    @min_name_length = 3,
    @max_name_length = 100,
    @new_department_id = @tc11_dept_id2 OUTPUT,
    @validation_status = @tc11_status2 OUTPUT,
    @error_message = @tc11_error2 OUTPUT;

-- ASSERT
SELECT 
    'TC11' AS test_case,
    'Duplicate department name' AS description,
    @tc11_status2 AS validation_status,
    CASE WHEN @tc11_dept_id2 IS NULL THEN 'PASS' ELSE 'FAIL' END AS dept_id_null_check,
    CASE WHEN @tc11_error2 LIKE '%already exists%' THEN 'PASS' ELSE 'FAIL' END AS error_message_check,
    @tc11_error2 AS error_message;

-- CLEANUP
IF @tc11_dept_id1 IS NOT NULL
BEGIN
    DELETE FROM dbo.departments WHERE department_id = @tc11_dept_id1;
END
GO

-- ============================================================================
-- TEST CASE 12: Exception - Duplicate department name (case-insensitive)
-- ============================================================================
-- SETUP
DECLARE @tc12_dept_id1 INT;
DECLARE @tc12_dept_id2 INT;
DECLARE @tc12_status1 NVARCHAR(50);
DECLARE @tc12_status2 NVARCHAR(50);
DECLARE @tc12_error1 NVARCHAR(500);
DECLARE @tc12_error2 NVARCHAR(500);

-- Create first department
EXEC dbo.usp_validate_and_create_dept
    @department_name = 'Case Test Dept',
    @location = 'Austin',
    @manager_id = NULL,
    @min_name_length = 3,
    @max_name_length = 100,
    @new_department_id = @tc12_dept_id1 OUTPUT,
    @validation_status = @tc12_status1 OUTPUT,
    @error_message = @tc12_error1 OUTPUT;

-- EXEC - Try to create with different case
EXEC dbo.usp_validate_and_create_dept
    @department_name = 'CASE TEST DEPT',
    @location = 'Denver',
    @manager_id = NULL,
    @min_name_length = 3,
    @max_name_length = 100,
    @new_department_id = @tc12_dept_id2 OUTPUT,
    @validation_status = @tc12_status2 OUTPUT,
    @error_message = @tc12_error2 OUTPUT;

-- ASSERT
SELECT 
    'TC12' AS test_case,
    'Duplicate name (case-insensitive)' AS description,
    @tc12_status2 AS validation_status,
    CASE WHEN @tc12_dept_id2 IS NULL THEN 'PASS' ELSE 'FAIL' END AS dept_id_null_check,
    CASE WHEN @tc12_error2 LIKE '%already exists%' THEN 'PASS' ELSE 'FAIL' END AS error_message_check;

-- CLEANUP
IF @tc12_dept_id1 IS NOT NULL
BEGIN
    DELETE FROM dbo.departments WHERE department_id = @tc12_dept_id1;
END
GO

-- ============================================================================
-- TEST CASE 13: Exception - Invalid manager_id (non-existent)
-- ============================================================================
-- SETUP
DECLARE @tc13_dept_id INT;
DECLARE @tc13_status NVARCHAR(50);
DECLARE @tc13_error NVARCHAR(500);
DECLARE @tc13_invalid_manager INT;

-- Get a non-existent employee ID
SELECT @tc13_invalid_manager = MAX(employee_id) + 9999 FROM dbo.employees;

-- EXEC
EXEC dbo.usp_validate_and_create_dept
    @department_name = 'Test Dept TC13',
    @location = 'Phoenix',
    @manager_id = @tc13_invalid_manager,
    @min_name_length = 3,
    @max_name_length = 100,
    @new_department_id = @tc13_dept_id OUTPUT,
    @validation_status = @tc13_status OUTPUT,
    @error_message = @tc13_error OUTPUT;

-- ASSERT
SELECT 
    'TC13' AS test_case,
    'Invalid manager_id (non-existent)' AS description,
    @tc13_status AS validation_status,
    CASE WHEN @tc13_dept_id IS NULL THEN 'PASS' ELSE 'FAIL' END AS dept_id_null_check,
    CASE WHEN @tc13_error LIKE '%Invalid manager%does not exist%' THEN 'PASS' ELSE 'FAIL' END AS error_message_check,
    @tc13_error AS error_message;

-- CLEANUP (none needed)
GO

-- ============================================================================
-- TEST CASE 14: Exception - Inactive manager
-- ============================================================================
-- SETUP
DECLARE @tc14_dept_id INT;
DECLARE @tc14_status NVARCHAR(50);
DECLARE @tc14_error NVARCHAR(500);
DECLARE @tc14_inactive_manager INT;

-- Get an inactive employee ID (or create one temporarily)
SELECT TOP 1 @tc14_inactive_manager = employee_id 
FROM dbo.employees 
WHERE is_active = 0
ORDER BY employee_id;

-- If no inactive employee exists, skip this test
IF @tc14_inactive_manager IS NOT NULL
BEGIN
    -- EXEC
    EXEC dbo.usp_validate_and_create_dept
        @department_name = 'Test Dept TC14',
        @location = 'Las Vegas',
        @manager_id = @tc14_inactive_manager,
        @min_name_length = 3,
        @max_name_length = 100,
        @new_department_id = @tc14_dept_id OUTPUT,
        @validation_status = @tc14_status OUTPUT,
        @error_message = @tc14_error OUTPUT;

    -- ASSERT
    SELECT 
        'TC14' AS test_case,
        'Inactive manager' AS description,
        @tc14_status AS validation_status,
        CASE WHEN @tc14_dept_id IS NULL THEN 'PASS' ELSE 'FAIL' END AS dept_id_null_check,
        CASE WHEN @tc14_error LIKE '%active employee%' THEN 'PASS' ELSE 'FAIL' END AS error_message_check,
        @tc14_error AS error_message;
END
ELSE
BEGIN
    -- ASSERT - Test skipped
    SELECT 
        'TC14' AS test_case,
        'Inactive manager' AS description,
        'SKIPPED' AS validation_status,
        'N/A' AS dept_id_null_check,
        'N/A' AS error_message_check,
        'No inactive employees available for testing' AS error_message;
END

-- CLEANUP (none needed)
GO

-- ============================================================================
-- TEST CASE 15: Boundary - Name with leading/trailing spaces (should be trimmed)
-- ============================================================================
-- SETUP
DECLARE @tc15_dept_id INT;
DECLARE @tc15_status NVARCHAR(50);
DECLARE @tc15_error NVARCHAR(500);

-- EXEC
EXEC dbo.usp_validate_and_create_dept
    @department_name = '   Trimmed Dept TC15   ',
    @location = 'Atlanta',
    @manager_id = NULL,
    @min_name_length = 3,
    @max_name_length = 100,
    @new_department_id = @tc15_dept_id OUTPUT,
    @validation_status = @tc15_status OUTPUT,
    @error_message = @tc15_error OUTPUT;

-- ASSERT
SELECT 
    'TC15' AS test_case,
    'Name with leading/trailing spaces' AS description,
    @tc15_status AS validation_status,
    CASE WHEN @tc15_dept_id IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS dept_id_check,
    department_name,
    CASE WHEN department_name = 'Trimmed Dept TC15' THEN 'PASS' ELSE 'FAIL' END AS trim_check
FROM dbo.departments
WHERE department_id = @tc15_dept_id;

-- CLEANUP
IF @tc15_dept_id IS NOT NULL
BEGIN
    DELETE FROM dbo.departments WHERE department_id = @tc15_dept_id;
END
GO

-- ============================================================================
-- TEST CASE 16: Boundary - Empty location string (should be treated as NULL)
-- ============================================================================
-- SETUP
DECLARE @tc16_dept_id INT;
DECLARE @tc16_status NVARCHAR(50);
DECLARE @tc16_error NVARCHAR(500);

-- EXEC
EXEC dbo.usp_validate_and_create_dept
    @department_name = 'Test Dept TC16',
    @location = '',
    @manager_id = NULL,
    @min_name_length = 3,
    @max_name_length = 100,
    @new_department_id = @tc16_dept_id OUTPUT,
    @validation_status = @tc16_status OUTPUT,
    @error_message = @tc16_error OUTPUT;

-- ASSERT
SELECT 
    'TC16' AS test_case,
    'Empty location string' AS description,
    @tc16_status AS validation_status,
    CASE WHEN @tc16_dept_id IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS dept_id_check,
    location,
    CASE WHEN location IS NULL THEN 'PASS' ELSE 'FAIL' END AS location_null_check
FROM dbo.departments
WHERE department_id = @tc16_dept_id;

-- CLEANUP
IF @tc16_dept_id IS NOT NULL
BEGIN
    DELETE FROM dbo.departments WHERE department_id = @tc16_dept_id;
END
GO

-- ============================================================================
-- TEST CASE 17: Transaction - Verify rollback on error
-- ============================================================================
-- SETUP
DECLARE @tc17_dept_id INT;
DECLARE @tc17_status NVARCHAR(50);
DECLARE @tc17_error NVARCHAR(500);
DECLARE @tc17_count_before INT;
DECLARE @tc17_count_after INT;

SELECT @tc17_count_before = COUNT(*) FROM dbo.departments;

-- EXEC - Try to create with invalid manager (should rollback)
EXEC dbo.usp_validate_and_create_dept
    @department_name = 'Test Dept TC17',
    @location = 'Houston',
    @manager_id = 999999,
    @min_name_length = 3,
    @max_name_length = 100,
    @new_department_id = @tc17_dept_id OUTPUT,
    @validation_status = @tc17_status OUTPUT,
    @error_message = @tc17_error OUTPUT;

SELECT @tc17_count_after = COUNT(*) FROM dbo.departments;

-- ASSERT
SELECT 
    'TC17' AS test_case,
    'Transaction rollback on error' AS description,
    @tc17_status AS validation_status,
    @tc17_count_before AS count_before,
    @tc17_count_after AS count_after,
    CASE WHEN @tc17_count_before = @tc17_count_after THEN 'PASS' ELSE 'FAIL' END AS rollback_check,
    CASE WHEN @tc17_dept_id IS NULL THEN 'PASS' ELSE 'FAIL' END AS dept_id_null_check;

-- CLEANUP (none needed - should have rolled back)
GO

-- ============================================================================
-- TEST CASE 18: Side effect - Verify created_date and modified_date are set
-- ============================================================================
-- SETUP
DECLARE @tc18_dept_id INT;
DECLARE @tc18_status NVARCHAR(50);
DECLARE @tc18_error NVARCHAR(500);

-- EXEC
EXEC dbo.usp_validate_and_create_dept
    @department_name = 'Test Dept TC18',
    @location = 'San Francisco',
    @manager_id = NULL,
    @min_name_length = 3,
    @max_name_length = 100,
    @new_department_id = @tc18_dept_id OUTPUT,
    @validation_status = @tc18_status OUTPUT,
    @error_message = @tc18_error OUTPUT;

-- ASSERT
SELECT 
    'TC18' AS test_case,
    'Verify created_date and modified_date' AS description,
    @tc18_status AS validation_status,
    CASE WHEN created_date IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS created_date_check,
    CASE WHEN modified_date IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS modified_date_check,
    CASE WHEN created_date = modified_date THEN 'PASS' ELSE 'FAIL' END AS dates_equal_check,
    DATEDIFF(SECOND, created_date, GETDATE()) AS seconds_since_creation
FROM dbo.departments
WHERE department_id = @tc18_dept_id;

-- CLEANUP
IF @tc18_dept_id IS NOT NULL
BEGIN
    DELETE FROM dbo.departments WHERE department_id = @tc18_dept_id;
END
GO

-- ============================================================================
-- TEST CASE 19: Side effect - Verify OUTPUT parameters are set correctly
-- ============================================================================
-- SETUP
DECLARE @tc19_dept_id INT;
DECLARE @tc19_status NVARCHAR(50);
DECLARE @tc19_error NVARCHAR(500);

-- EXEC
EXEC dbo.usp_validate_and_create_dept
    @department_name = 'Test Dept TC19',
    @location = 'San Diego',
    @manager_id = NULL,
    @min_name_length = 3,
    @max_name_length = 100,
    @new_department_id = @tc19_dept_id OUTPUT,
    @validation_status = @tc19_status OUTPUT,
    @error_message = @tc19_error OUTPUT;

-- ASSERT
SELECT 
    'TC19' AS test_case,
    'Verify OUTPUT parameters' AS description,
    @tc19_dept_id AS output_dept_id,
    @tc19_status AS output_status,
    @tc19_error AS output_error,
    CASE WHEN @tc19_dept_id IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS dept_id_set_check,
    CASE WHEN @tc19_status = 'SUCCESS' THEN 'PASS' ELSE 'FAIL' END AS status_check,
    CASE WHEN @tc19_error IS NULL THEN 'PASS' ELSE 'FAIL' END AS error_null_check;

-- CLEANUP
IF @tc19_dept_id IS NOT NULL
BEGIN
    DELETE FROM dbo.departments WHERE department_id = @tc19_dept_id;
END
GO

-- ============================================================================
-- TEST CASE 20: Side effect - Verify OUTPUT parameters on validation failure
-- ============================================================================
-- SETUP
DECLARE @tc20_dept_id INT;
DECLARE @tc20_status NVARCHAR(50);
DECLARE @tc20_error NVARCHAR(500);

-- EXEC - Validation should fail (NULL name)
EXEC dbo.usp_validate_and_create_dept
    @department_name = NULL,
    @location = 'Philadelphia',
    @manager_id = NULL,
    @min_name_length = 3,
    @max_name_length = 100,
    @new_department_id = @tc20_dept_id OUTPUT,
    @validation_status = @tc20_status OUTPUT,
    @error_message = @tc20_error OUTPUT;

-- ASSERT
SELECT 
    'TC20' AS test_case,
    'OUTPUT parameters on validation failure' AS description,
    @tc20_dept_id AS output_dept_id,
    @tc20_status AS output_status,
    @tc20_error AS output_error,
    CASE WHEN @tc20_dept_id IS NULL THEN 'PASS' ELSE 'FAIL' END AS dept_id_null_check,
    CASE WHEN @tc20_status = 'FAILED' THEN 'PASS' ELSE 'FAIL' END AS status_failed_check,
    CASE WHEN @tc20_error IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS error_set_check;

-- CLEANUP (none needed)
GO

-- ============================================================================
-- END OF TEST SUITE
-- ============================================================================
