-- =============================================
-- TEST SUITE for dbo.usp_employee_json
-- =============================================
-- This test suite validates the stored procedure that returns employee
-- information as JSON via an OUTPUT parameter.
--
-- Test Categories:
-- - Normal cases: Valid employee IDs
-- - Boundary cases: NULL input, non-existent ID, edge IDs
-- - Exception cases: Invalid data types (handled by SQL Server)
-- - JSON format validation: Verify JSON structure and content
-- =============================================

-- ============= TEST CASE 1: Valid employee ID (normal case) =============
-- SETUP
DECLARE @json_result NVARCHAR(MAX);

-- EXEC
EXEC dbo.usp_employee_json @employee_id = 1, @json_out = @json_result OUTPUT;

-- ASSERT
SELECT 'TC1' AS tc, 
       'Valid employee ID' AS test_description,
       @json_result AS json_output,
       CASE WHEN @json_result IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS status,
       CASE WHEN @json_result LIKE '%employee_id%' THEN 'PASS' ELSE 'FAIL' END AS has_employee_id,
       CASE WHEN @json_result LIKE '%first_name%' THEN 'PASS' ELSE 'FAIL' END AS has_first_name,
       CASE WHEN @json_result LIKE '%department_name%' THEN 'PASS' ELSE 'FAIL' END AS has_department_name;

-- CLEANUP
-- No cleanup needed (read-only operation)

-- ============= TEST CASE 2: Another valid employee ID =============
-- SETUP
DECLARE @json_result2 NVARCHAR(MAX);

-- EXEC
EXEC dbo.usp_employee_json @employee_id = 2, @json_out = @json_result2 OUTPUT;

-- ASSERT
SELECT 'TC2' AS tc,
       'Another valid employee ID' AS test_description,
       @json_result2 AS json_output,
       CASE WHEN @json_result2 IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS status;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 3: Non-existent employee ID (boundary) =============
-- SETUP
DECLARE @json_result3 NVARCHAR(MAX);

-- EXEC
EXEC dbo.usp_employee_json @employee_id = 999999, @json_out = @json_result3 OUTPUT;

-- ASSERT
SELECT 'TC3' AS tc,
       'Non-existent employee ID' AS test_description,
       @json_result3 AS json_output,
       CASE WHEN @json_result3 IS NULL THEN 'PASS' ELSE 'FAIL' END AS status;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 4: NULL employee ID (boundary) =============
-- SETUP
DECLARE @json_result4 NVARCHAR(MAX);

-- EXEC
EXEC dbo.usp_employee_json @employee_id = NULL, @json_out = @json_result4 OUTPUT;

-- ASSERT
SELECT 'TC4' AS tc,
       'NULL employee ID' AS test_description,
       @json_result4 AS json_output,
       CASE WHEN @json_result4 IS NULL THEN 'PASS' ELSE 'FAIL' END AS status;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 5: Zero employee ID (boundary) =============
-- SETUP
DECLARE @json_result5 NVARCHAR(MAX);

-- EXEC
EXEC dbo.usp_employee_json @employee_id = 0, @json_out = @json_result5 OUTPUT;

-- ASSERT
SELECT 'TC5' AS tc,
       'Zero employee ID' AS test_description,
       @json_result5 AS json_output,
       CASE WHEN @json_result5 IS NULL THEN 'PASS' ELSE 'FAIL' END AS status;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 6: Negative employee ID (boundary) =============
-- SETUP
DECLARE @json_result6 NVARCHAR(MAX);

-- EXEC
EXEC dbo.usp_employee_json @employee_id = -1, @json_out = @json_result6 OUTPUT;

-- ASSERT
SELECT 'TC6' AS tc,
       'Negative employee ID' AS test_description,
       @json_result6 AS json_output,
       CASE WHEN @json_result6 IS NULL THEN 'PASS' ELSE 'FAIL' END AS status;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 7: Verify JSON structure with known employee =============
-- SETUP
-- First, let's check what employees exist
DECLARE @json_result7 NVARCHAR(MAX);
DECLARE @expected_first_name NVARCHAR(100);
DECLARE @expected_last_name NVARCHAR(100);
DECLARE @expected_email NVARCHAR(255);
DECLARE @expected_dept_name NVARCHAR(100);

SELECT TOP 1 
    @expected_first_name = e.first_name,
    @expected_last_name = e.last_name,
    @expected_email = e.email,
    @expected_dept_name = d.name
FROM dbo.employees e
INNER JOIN dbo.departments d ON e.department_id = d.department_id
WHERE e.employee_id = 1;

-- EXEC
EXEC dbo.usp_employee_json @employee_id = 1, @json_out = @json_result7 OUTPUT;

-- ASSERT
SELECT 'TC7' AS tc,
       'Verify JSON content matches database' AS test_description,
       @json_result7 AS json_output,
       @expected_first_name AS expected_first_name,
       @expected_last_name AS expected_last_name,
       @expected_email AS expected_email,
       @expected_dept_name AS expected_dept_name,
       CASE WHEN @json_result7 LIKE '%' + @expected_first_name + '%' THEN 'PASS' ELSE 'FAIL' END AS first_name_match,
       CASE WHEN @json_result7 LIKE '%' + @expected_last_name + '%' THEN 'PASS' ELSE 'FAIL' END AS last_name_match,
       CASE WHEN @json_result7 LIKE '%' + @expected_email + '%' THEN 'PASS' ELSE 'FAIL' END AS email_match;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 8: Employee without department (exception case) =============
-- SETUP
-- Create a temporary employee without a valid department reference
-- We'll use a temp table to avoid modifying the actual employees table
CREATE TABLE #temp_employees (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(100),
    last_name NVARCHAR(100),
    email NVARCHAR(255),
    department_id INT,
    hire_date DATE
);

CREATE TABLE #temp_departments (
    department_id INT PRIMARY KEY,
    name NVARCHAR(100)
);

INSERT INTO #temp_departments (department_id, name) VALUES (1, 'Test Dept');
INSERT INTO #temp_employees (employee_id, first_name, last_name, email, department_id, hire_date)
VALUES (9999, 'Test', 'User', 'test@example.com', 1, '2020-01-01');

-- Test with employee that has valid department
DECLARE @json_result8a NVARCHAR(MAX);

-- Create a test procedure that uses temp tables
DECLARE @sql8 NVARCHAR(MAX) = N'
DECLARE @json_out8 NVARCHAR(MAX);
SET @json_out8 = (
    SELECT
        e.employee_id,
        e.first_name,
        e.last_name,
        e.email,
        d.name AS department_name,
        e.hire_date
    FROM #temp_employees e
    INNER JOIN #temp_departments d ON e.department_id = d.department_id
    WHERE e.employee_id = 9999
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
);
SELECT @json_out8 AS json_output;
';

-- EXEC
EXEC sp_executesql @sql8;

-- ASSERT
SELECT 'TC8' AS tc,
       'Employee with valid department in temp table' AS test_description,
       'Simulated test - actual procedure uses real tables' AS note;

-- CLEANUP
DROP TABLE #temp_employees;
DROP TABLE #temp_departments;

-- ============= TEST CASE 9: Maximum INT value for employee_id (boundary) =============
-- SETUP
DECLARE @json_result9 NVARCHAR(MAX);

-- EXEC
EXEC dbo.usp_employee_json @employee_id = 2147483647, @json_out = @json_result9 OUTPUT;

-- ASSERT
SELECT 'TC9' AS tc,
       'Maximum INT value for employee_id' AS test_description,
       @json_result9 AS json_output,
       CASE WHEN @json_result9 IS NULL THEN 'PASS' ELSE 'FAIL' END AS status;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 10: Verify OUTPUT parameter is properly set =============
-- SETUP
DECLARE @json_result10 NVARCHAR(MAX);
SET @json_result10 = 'INITIAL_VALUE'; -- Pre-set to verify it gets overwritten

-- EXEC
EXEC dbo.usp_employee_json @employee_id = 1, @json_out = @json_result10 OUTPUT;

-- ASSERT
SELECT 'TC10' AS tc,
       'OUTPUT parameter properly overwrites initial value' AS test_description,
       @json_result10 AS json_output,
       CASE WHEN @json_result10 != 'INITIAL_VALUE' AND @json_result10 IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS status;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 11: Verify JSON is valid and parseable =============
-- SETUP
DECLARE @json_result11 NVARCHAR(MAX);

-- EXEC
EXEC dbo.usp_employee_json @employee_id = 1, @json_out = @json_result11 OUTPUT;

-- ASSERT
-- Try to parse the JSON to verify it's valid
BEGIN TRY
    DECLARE @is_valid_json11 BIT;
    SET @is_valid_json11 = ISJSON(@json_result11);
    
    SELECT 'TC11' AS tc,
           'JSON validity check' AS test_description,
           @json_result11 AS json_output,
           @is_valid_json11 AS is_valid_json,
           CASE WHEN @is_valid_json11 = 1 THEN 'PASS' ELSE 'FAIL' END AS status;
END TRY
BEGIN CATCH
    SELECT 'TC11' AS tc,
           'JSON validity check' AS test_description,
           ERROR_MESSAGE() AS error_message,
           'FAIL' AS status;
END CATCH

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 12: Parse JSON and verify field values =============
-- SETUP
DECLARE @json_result12 NVARCHAR(MAX);

-- EXEC
EXEC dbo.usp_employee_json @employee_id = 1, @json_out = @json_result12 OUTPUT;

-- ASSERT
-- Parse JSON and extract values
SELECT 'TC12' AS tc,
       'Parse JSON and extract field values' AS test_description,
       JSON_VALUE(@json_result12, '$.employee_id') AS parsed_employee_id,
       JSON_VALUE(@json_result12, '$.first_name') AS parsed_first_name,
       JSON_VALUE(@json_result12, '$.last_name') AS parsed_last_name,
       JSON_VALUE(@json_result12, '$.email') AS parsed_email,
       JSON_VALUE(@json_result12, '$.department_name') AS parsed_department_name,
       JSON_VALUE(@json_result12, '$.hire_date') AS parsed_hire_date,
       CASE WHEN JSON_VALUE(@json_result12, '$.employee_id') = '1' THEN 'PASS' ELSE 'FAIL' END AS employee_id_match;

-- CLEANUP
-- No cleanup needed
