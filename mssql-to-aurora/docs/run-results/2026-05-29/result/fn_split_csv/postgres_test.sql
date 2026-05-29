-- ============================================================================
-- TEST SUITE: public.fn_split_csv
-- ============================================================================
-- Purpose: Comprehensive test coverage for CSV string splitting function
-- Target: Aurora PostgreSQL (Native)
-- Converted from: mssql_test.sql
-- ============================================================================

-- ============================================================================
-- TEST CASE 1: Simple CSV with 3 values
-- ============================================================================
-- SETUP
-- (No setup required - function is stateless)

-- EXEC
-- (Inline execution in ASSERT)

-- ASSERT
SELECT 'TC1' AS test_case, 'Simple_CSV' AS test_name, item_id, item_value
FROM public.fn_split_csv('A,B,C', ',')
ORDER BY item_id;

-- CLEANUP
-- (No cleanup required)


-- ============================================================================
-- TEST CASE 2: CSV with spaces around values
-- ============================================================================
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC2' AS test_case, 'CSV_With_Spaces' AS test_name, item_id, item_value
FROM public.fn_split_csv('Apple, Banana, Cherry', ',')
ORDER BY item_id;

-- CLEANUP
-- (No cleanup required)


-- ============================================================================
-- TEST CASE 3: Numeric CSV values
-- ============================================================================
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC3' AS test_case, 'Numeric_Values' AS test_name, item_id, item_value
FROM public.fn_split_csv('1,2,3,4,5', ',')
ORDER BY item_id;

-- CLEANUP
-- (No cleanup required)


-- ============================================================================
-- TEST CASE 4: NULL input (boundary case)
-- ============================================================================
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC4' AS test_case, 'NULL_Input' AS test_name, 
       COUNT(*) AS row_count,
       CAST(NULL AS BIGINT) AS item_id,
       CAST(NULL AS TEXT) AS item_value
FROM public.fn_split_csv(NULL, ',');

-- CLEANUP
-- (No cleanup required)


-- ============================================================================
-- TEST CASE 5: Empty string (boundary case)
-- ============================================================================
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC5' AS test_case, 'Empty_String' AS test_name, 
       COUNT(*) AS row_count,
       CAST(NULL AS BIGINT) AS item_id,
       CAST(NULL AS TEXT) AS item_value
FROM public.fn_split_csv('', ',');

-- CLEANUP
-- (No cleanup required)


-- ============================================================================
-- TEST CASE 6: Single value without delimiter (boundary case)
-- ============================================================================
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC6' AS test_case, 'Single_Value' AS test_name, item_id, item_value
FROM public.fn_split_csv('SingleValue', ',')
ORDER BY item_id;

-- CLEANUP
-- (No cleanup required)


-- ============================================================================
-- TEST CASE 7: Leading delimiter (boundary case)
-- ============================================================================
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC7' AS test_case, 'Leading_Delimiter' AS test_name, item_id, item_value
FROM public.fn_split_csv(',A,B,C', ',')
ORDER BY item_id;

-- CLEANUP
-- (No cleanup required)


-- ============================================================================
-- TEST CASE 8: Trailing delimiter (boundary case)
-- ============================================================================
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC8' AS test_case, 'Trailing_Delimiter' AS test_name, item_id, item_value
FROM public.fn_split_csv('A,B,C,', ',')
ORDER BY item_id;

-- CLEANUP
-- (No cleanup required)


-- ============================================================================
-- TEST CASE 9: Consecutive delimiters (boundary case)
-- ============================================================================
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC9' AS test_case, 'Consecutive_Delimiters' AS test_name, item_id, item_value
FROM public.fn_split_csv('A,,B,,,C', ',')
ORDER BY item_id;

-- CLEANUP
-- (No cleanup required)


-- ============================================================================
-- TEST CASE 10: Custom delimiter - Pipe (normal case)
-- ============================================================================
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC10' AS test_case, 'Pipe_Delimiter' AS test_name, item_id, item_value
FROM public.fn_split_csv('Red|Green|Blue', '|')
ORDER BY item_id;

-- CLEANUP
-- (No cleanup required)


-- ============================================================================
-- TEST CASE 11: Custom delimiter - Semicolon (normal case)
-- ============================================================================
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC11' AS test_case, 'Semicolon_Delimiter' AS test_name, item_id, item_value
FROM public.fn_split_csv('John;Jane;Jack', ';')
ORDER BY item_id;

-- CLEANUP
-- (No cleanup required)


-- ============================================================================
-- TEST CASE 12: Long CSV with many items (boundary case)
-- ============================================================================
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC12' AS test_case, 'Long_CSV' AS test_name, 
       COUNT(*) AS total_items,
       MIN(item_id) AS min_id,
       MAX(item_id) AS max_id
FROM public.fn_split_csv('1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20', ',');

-- CLEANUP
-- (No cleanup required)


-- ============================================================================
-- TEST CASE 13: Values with special characters (normal case)
-- ============================================================================
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC13' AS test_case, 'Special_Characters' AS test_name, item_id, item_value
FROM public.fn_split_csv('A&B,C#D,E@F', ',')
ORDER BY item_id;

-- CLEANUP
-- (No cleanup required)


-- ============================================================================
-- TEST CASE 14: Values with numbers and letters mixed (normal case)
-- ============================================================================
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC14' AS test_case, 'Mixed_Alphanumeric' AS test_name, item_id, item_value
FROM public.fn_split_csv('Item1,Item2,Item3,Item4', ',')
ORDER BY item_id;

-- CLEANUP
-- (No cleanup required)


-- ============================================================================
-- TEST CASE 15: Very long individual value (boundary case)
-- ============================================================================
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC15' AS test_case, 'Long_Individual_Value' AS test_name, 
       item_id, 
       LENGTH(item_value) AS value_length,
       LEFT(item_value, 50) AS value_preview
FROM public.fn_split_csv('ShortValue,' || REPEAT('X', 1000) || ',AnotherShort', ',')
ORDER BY item_id;

-- CLEANUP
-- (No cleanup required)


-- ============================================================================
-- TEST CASE 16: Single delimiter only (edge case)
-- ============================================================================
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC16' AS test_case, 'Single_Delimiter_Only' AS test_name, item_id, item_value
FROM public.fn_split_csv(',', ',')
ORDER BY item_id;

-- CLEANUP
-- (No cleanup required)


-- ============================================================================
-- TEST CASE 17: Multiple delimiters only (edge case)
-- ============================================================================
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC17' AS test_case, 'Multiple_Delimiters_Only' AS test_name, 
       COUNT(*) AS row_count,
       SUM(CASE WHEN LENGTH(item_value) = 0 THEN 1 ELSE 0 END) AS empty_count
FROM public.fn_split_csv(',,,', ',');

-- CLEANUP
-- (No cleanup required)


-- ============================================================================
-- TEST CASE 18: Whitespace-only values (boundary case)
-- ============================================================================
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC18' AS test_case, 'Whitespace_Values' AS test_name, 
       item_id, 
       item_value,
       LENGTH(item_value) AS value_length
FROM public.fn_split_csv('A,   ,B,	,C', ',')
ORDER BY item_id;

-- CLEANUP
-- (No cleanup required)


-- ============================================================================
-- TEST SUMMARY
-- ============================================================================
-- Total Test Cases: 18
-- Coverage:
--   - Normal cases: 6 (TC1, TC2, TC3, TC10, TC11, TC13, TC14)
--   - Boundary cases: 10 (TC4, TC5, TC6, TC7, TC8, TC9, TC12, TC15, TC16, TC18)
--   - Edge cases: 2 (TC16, TC17)
--   - Delimiter variations: 2 (TC10, TC11)
--   - Special characters: 1 (TC13)
-- ============================================================================
