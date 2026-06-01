-- ============================================================================
-- TEST SUITE FOR dbo.fn_format_employee_name
-- ============================================================================
-- Object Type: SCALAR FUNCTION
-- Parameters: @first NVARCHAR(50), @last NVARCHAR(50)
-- Returns: NVARCHAR(105) - formatted name as "Last, First"
-- ============================================================================

-- ============= TEST CASE 1: Normal input with typical names =============
-- SETUP
-- (No setup required for scalar function)

-- EXEC & ASSERT
SELECT 'TC1' AS tc, dbo.fn_format_employee_name(N'John', N'Doe') AS result;

-- CLEANUP
-- (No cleanup required)

-- ============= TEST CASE 2: Normal input with Unicode characters =============
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC2' AS tc, dbo.fn_format_employee_name(N'太郎', N'山田') AS result;

-- CLEANUP
-- (No cleanup required)

-- ============= TEST CASE 3: Normal input with special characters =============
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC3' AS tc, dbo.fn_format_employee_name(N'Mary-Jane', N'O''Brien') AS result;

-- CLEANUP
-- (No cleanup required)

-- ============= TEST CASE 4: Boundary - NULL first name =============
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC4' AS tc, dbo.fn_format_employee_name(NULL, N'Smith') AS result;

-- CLEANUP
-- (No cleanup required)

-- ============= TEST CASE 5: Boundary - NULL last name =============
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC5' AS tc, dbo.fn_format_employee_name(N'Jane', NULL) AS result;

-- CLEANUP
-- (No cleanup required)

-- ============= TEST CASE 6: Boundary - Both NULL =============
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC6' AS tc, dbo.fn_format_employee_name(NULL, NULL) AS result;

-- CLEANUP
-- (No cleanup required)

-- ============= TEST CASE 7: Boundary - Empty string first name =============
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC7' AS tc, dbo.fn_format_employee_name(N'', N'Johnson') AS result;

-- CLEANUP
-- (No cleanup required)

-- ============= TEST CASE 8: Boundary - Empty string last name =============
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC8' AS tc, dbo.fn_format_employee_name(N'Bob', N'') AS result;

-- CLEANUP
-- (No cleanup required)

-- ============= TEST CASE 9: Boundary - Both empty strings =============
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC9' AS tc, dbo.fn_format_employee_name(N'', N'') AS result;

-- CLEANUP
-- (No cleanup required)

-- ============= TEST CASE 10: Boundary - Single character names =============
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC10' AS tc, dbo.fn_format_employee_name(N'A', N'B') AS result;

-- CLEANUP
-- (No cleanup required)

-- ============= TEST CASE 11: Boundary - Maximum length names (50 chars each) =============
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC11' AS tc, 
       dbo.fn_format_employee_name(
           N'12345678901234567890123456789012345678901234567890',
           N'ABCDEFGHIJABCDEFGHIJABCDEFGHIJABCDEFGHIJABCDEFGHIJ'
       ) AS result;

-- CLEANUP
-- (No cleanup required)

-- ============= TEST CASE 12: Boundary - Names with leading/trailing spaces =============
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC12' AS tc, dbo.fn_format_employee_name(N'  John  ', N'  Doe  ') AS result;

-- CLEANUP
-- (No cleanup required)

-- ============= TEST CASE 13: Edge case - Names with only spaces =============
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC13' AS tc, dbo.fn_format_employee_name(N'   ', N'   ') AS result;

-- CLEANUP
-- (No cleanup required)

-- ============= TEST CASE 14: Edge case - Names with newline characters =============
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC14' AS tc, dbo.fn_format_employee_name(N'John' + CHAR(10), N'Doe' + CHAR(13)) AS result;

-- CLEANUP
-- (No cleanup required)

-- ============= TEST CASE 15: Verify return type length (NVARCHAR(105)) =============
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
-- Result should be exactly 105 characters when both inputs are 50 chars + 2 for ', '
SELECT 'TC15' AS tc, 
       LEN(dbo.fn_format_employee_name(
           N'12345678901234567890123456789012345678901234567890',
           N'ABCDEFGHIJABCDEFGHIJABCDEFGHIJABCDEFGHIJABCDEFGHIJ'
       )) AS result_length,
       dbo.fn_format_employee_name(
           N'12345678901234567890123456789012345678901234567890',
           N'ABCDEFGHIJABCDEFGHIJABCDEFGHIJABCDEFGHIJABCDEFGHIJ'
       ) AS result_value;

-- CLEANUP
-- (No cleanup required)

-- ============================================================================
-- END OF TEST SUITE
-- ============================================================================
