-- ============================================================================
-- TEST SUITE for dbo.fn_format_employee_name
-- ============================================================================
-- This test suite covers:
-- - Normal cases (3+ cases)
-- - Boundary cases (NULL, empty, whitespace) (3+ cases)
-- - Exception cases (2+ cases)
-- ============================================================================

-- ============= TEST CASE 1: Normal - Full name with all components =============
-- SETUP
-- No setup needed for scalar function test

-- EXEC
DECLARE @result1 NVARCHAR(200);
SET @result1 = dbo.fn_format_employee_name('John', 'Doe', 'Michael');

-- ASSERT
SELECT 'TC1' AS tc, @result1 AS result, 'Doe, John Michael' AS expected;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 2: Normal - First and last name only (no middle) =============
-- SETUP
-- No setup needed

-- EXEC
DECLARE @result2 NVARCHAR(200);
SET @result2 = dbo.fn_format_employee_name('Jane', 'Smith', NULL);

-- ASSERT
SELECT 'TC2' AS tc, @result2 AS result, 'Smith, Jane' AS expected;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 3: Normal - Last name only =============
-- SETUP
-- No setup needed

-- EXEC
DECLARE @result3 NVARCHAR(200);
SET @result3 = dbo.fn_format_employee_name(NULL, 'Johnson', NULL);

-- ASSERT
SELECT 'TC3' AS tc, @result3 AS result, 'Johnson' AS expected;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 4: Normal - First name only =============
-- SETUP
-- No setup needed

-- EXEC
DECLARE @result4 NVARCHAR(200);
SET @result4 = dbo.fn_format_employee_name('Alice', NULL, NULL);

-- ASSERT
SELECT 'TC4' AS tc, @result4 AS result, 'Alice' AS expected;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 5: Boundary - All NULL inputs =============
-- SETUP
-- No setup needed

-- EXEC
DECLARE @result5 NVARCHAR(200);
SET @result5 = dbo.fn_format_employee_name(NULL, NULL, NULL);

-- ASSERT
SELECT 'TC5' AS tc, @result5 AS result, 'NULL' AS expected;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 6: Boundary - Empty strings =============
-- SETUP
-- No setup needed

-- EXEC
DECLARE @result6 NVARCHAR(200);
SET @result6 = dbo.fn_format_employee_name('', '', '');

-- ASSERT
SELECT 'TC6' AS tc, @result6 AS result, 'NULL or empty' AS expected;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 7: Boundary - Whitespace only in middle name =============
-- SETUP
-- No setup needed

-- EXEC
DECLARE @result7 NVARCHAR(200);
SET @result7 = dbo.fn_format_employee_name('Bob', 'Williams', '   ');

-- ASSERT
SELECT 'TC7' AS tc, @result7 AS result, 'Williams, Bob' AS expected;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 8: Boundary - Names with leading/trailing spaces =============
-- SETUP
-- No setup needed

-- EXEC
DECLARE @result8 NVARCHAR(200);
SET @result8 = dbo.fn_format_employee_name('  Charlie  ', '  Brown  ', '  M  ');

-- ASSERT
SELECT 'TC8' AS tc, @result8 AS result, 'Brown, Charlie M' AS expected_trimmed;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 9: Boundary - Very long names (max length) =============
-- SETUP
DECLARE @long_first NVARCHAR(50) = REPLICATE('A', 50);
DECLARE @long_last NVARCHAR(50) = REPLICATE('B', 50);
DECLARE @long_middle NVARCHAR(50) = REPLICATE('C', 50);

-- EXEC
DECLARE @result9 NVARCHAR(200);
SET @result9 = dbo.fn_format_employee_name(@long_first, @long_last, @long_middle);

-- ASSERT
SELECT 'TC9' AS tc, 
       LEN(@result9) AS result_length, 
       150 AS expected_length_with_separators,
       LEFT(@result9, 20) AS result_prefix;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 10: Boundary - Single character names =============
-- SETUP
-- No setup needed

-- EXEC
DECLARE @result10 NVARCHAR(200);
SET @result10 = dbo.fn_format_employee_name('A', 'B', 'C');

-- ASSERT
SELECT 'TC10' AS tc, @result10 AS result, 'B, A C' AS expected;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 11: Special - Names with special characters =============
-- SETUP
-- No setup needed

-- EXEC
DECLARE @result11 NVARCHAR(200);
SET @result11 = dbo.fn_format_employee_name('Mary-Jane', 'O''Connor', 'St. Claire');

-- ASSERT
SELECT 'TC11' AS tc, @result11 AS result, 'O''Connor, Mary-Jane St. Claire' AS expected;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 12: Special - Unicode characters =============
-- SETUP
-- No setup needed

-- EXEC
DECLARE @result12 NVARCHAR(200);
SET @result12 = dbo.fn_format_employee_name(N'José', N'García', N'María');

-- ASSERT
SELECT 'TC12' AS tc, @result12 AS result, N'García, José María' AS expected;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 13: Edge - Only middle name provided (unusual) =============
-- SETUP
-- No setup needed

-- EXEC
DECLARE @result13 NVARCHAR(200);
SET @result13 = dbo.fn_format_employee_name(NULL, NULL, 'MiddleOnly');

-- ASSERT
SELECT 'TC13' AS tc, @result13 AS result, 'NULL' AS expected;

-- CLEANUP
-- No cleanup needed

-- ============================================================================
-- END OF TEST SUITE
-- ============================================================================
