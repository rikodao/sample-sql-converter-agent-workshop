-- ============================================================================
-- TEST SUITE: dbo.fn_split_csv
-- Description: Table-Valued Function that splits CSV string by separator
-- ============================================================================

-- ============= TEST CASE 1: Normal CSV with comma separator =============
-- SETUP
-- (No setup needed)

-- EXEC & ASSERT
SELECT 'TC1' AS test_case, idx, value
FROM dbo.fn_split_csv('apple,banana,cherry', ',')
ORDER BY idx;

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 2: Single element (no separator) =============
-- SETUP
-- (No setup needed)

-- EXEC & ASSERT
SELECT 'TC2' AS test_case, idx, value
FROM dbo.fn_split_csv('single', ',')
ORDER BY idx;

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 3: Multiple elements with pipe separator =============
-- SETUP
-- (No setup needed)

-- EXEC & ASSERT
SELECT 'TC3' AS test_case, idx, value
FROM dbo.fn_split_csv('red|green|blue|yellow', '|')
ORDER BY idx;

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 4: NULL input (boundary) =============
-- SETUP
-- (No setup needed)

-- EXEC & ASSERT
SELECT 'TC4' AS test_case, COUNT(*) AS row_count
FROM dbo.fn_split_csv(NULL, ',');

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 5: Empty string (boundary) =============
-- SETUP
-- (No setup needed)

-- EXEC & ASSERT
SELECT 'TC5' AS test_case, COUNT(*) AS row_count
FROM dbo.fn_split_csv('', ',');

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 6: Leading separator (boundary) =============
-- SETUP
-- (No setup needed)

-- EXEC & ASSERT
SELECT 'TC6' AS test_case, idx, value, LEN(value) AS value_length
FROM dbo.fn_split_csv(',apple,banana', ',')
ORDER BY idx;

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 7: Trailing separator (boundary) =============
-- SETUP
-- (No setup needed)

-- EXEC & ASSERT
SELECT 'TC7' AS test_case, idx, value, LEN(value) AS value_length
FROM dbo.fn_split_csv('apple,banana,', ',')
ORDER BY idx;

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 8: Consecutive separators (boundary) =============
-- SETUP
-- (No setup needed)

-- EXEC & ASSERT
SELECT 'TC8' AS test_case, idx, value, LEN(value) AS value_length
FROM dbo.fn_split_csv('apple,,banana,,,cherry', ',')
ORDER BY idx;

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 9: Only separators (boundary) =============
-- SETUP
-- (No setup needed)

-- EXEC & ASSERT
SELECT 'TC9' AS test_case, idx, value, LEN(value) AS value_length
FROM dbo.fn_split_csv(',,,', ',')
ORDER BY idx;

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 10: Long string with many elements =============
-- SETUP
-- (No setup needed)

-- EXEC & ASSERT
SELECT 'TC10' AS test_case, COUNT(*) AS element_count, MIN(idx) AS min_idx, MAX(idx) AS max_idx
FROM dbo.fn_split_csv('a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z', ',');

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 11: Special characters in values =============
-- SETUP
-- (No setup needed)

-- EXEC & ASSERT
SELECT 'TC11' AS test_case, idx, value
FROM dbo.fn_split_csv('hello world,test@email.com,price=$100', ',')
ORDER BY idx;

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 12: Unicode characters =============
-- SETUP
-- (No setup needed)

-- EXEC & ASSERT
SELECT 'TC12' AS test_case, idx, value
FROM dbo.fn_split_csv(N'日本語,한국어,中文', ',')
ORDER BY idx;

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 13: Semicolon separator =============
-- SETUP
-- (No setup needed)

-- EXEC & ASSERT
SELECT 'TC13' AS test_case, idx, value
FROM dbo.fn_split_csv('first;second;third', ';')
ORDER BY idx;

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 14: Tab separator =============
-- SETUP
-- (No setup needed)

-- EXEC & ASSERT
SELECT 'TC14' AS test_case, idx, value
FROM dbo.fn_split_csv('col1	col2	col3', '	')
ORDER BY idx;

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 15: Single character string =============
-- SETUP
-- (No setup needed)

-- EXEC & ASSERT
SELECT 'TC15' AS test_case, idx, value
FROM dbo.fn_split_csv('x', ',')
ORDER BY idx;

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 16: Whitespace handling =============
-- SETUP
-- (No setup needed)

-- EXEC & ASSERT
SELECT 'TC16' AS test_case, idx, value, LEN(value) AS value_length
FROM dbo.fn_split_csv(' apple , banana , cherry ', ',')
ORDER BY idx;

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 17: Numbers as strings =============
-- SETUP
-- (No setup needed)

-- EXEC & ASSERT
SELECT 'TC17' AS test_case, idx, value
FROM dbo.fn_split_csv('100,200,300,400', ',')
ORDER BY idx;

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 18: Mixed content =============
-- SETUP
-- (No setup needed)

-- EXEC & ASSERT
SELECT 'TC18' AS test_case, idx, value
FROM dbo.fn_split_csv('text,123,true,2023-01-01', ',')
ORDER BY idx;

-- CLEANUP
-- (No cleanup needed)
