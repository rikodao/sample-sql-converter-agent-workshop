-- ================================================================
-- TEST SUITE: dbo.fn_get_fiscal_year
-- Target: Source RDS for SQL Server
-- Purpose: Validate fiscal year calculation (April-based)
-- ================================================================

-- ============= TEST CASE 1: Normal - Mid fiscal year (July) =============
-- SETUP
-- (No setup required for scalar function)

-- EXEC & ASSERT
SELECT 'TC1' AS tc, dbo.fn_get_fiscal_year('2023-07-15') AS result;

-- CLEANUP
-- (No cleanup required)


-- ============= TEST CASE 2: Normal - Start of fiscal year (April 1st) =============
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC2' AS tc, dbo.fn_get_fiscal_year('2023-04-01') AS result;

-- CLEANUP
-- (No cleanup required)


-- ============= TEST CASE 3: Normal - End of fiscal year (March 31st) =============
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC3' AS tc, dbo.fn_get_fiscal_year('2023-03-31') AS result;

-- CLEANUP
-- (No cleanup required)


-- ============= TEST CASE 4: Boundary - January (Q4 of previous fiscal year) =============
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC4' AS tc, dbo.fn_get_fiscal_year('2023-01-15') AS result;

-- CLEANUP
-- (No cleanup required)


-- ============= TEST CASE 5: Boundary - February (Q4 of previous fiscal year) =============
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC5' AS tc, dbo.fn_get_fiscal_year('2023-02-28') AS result;

-- CLEANUP
-- (No cleanup required)


-- ============= TEST CASE 6: Boundary - March (last month of fiscal year) =============
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC6' AS tc, dbo.fn_get_fiscal_year('2023-03-01') AS result;

-- CLEANUP
-- (No cleanup required)


-- ============= TEST CASE 7: Boundary - December (Q3 of fiscal year) =============
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC7' AS tc, dbo.fn_get_fiscal_year('2023-12-31') AS result;

-- CLEANUP
-- (No cleanup required)


-- ============= TEST CASE 8: Boundary - NULL input =============
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC8' AS tc, dbo.fn_get_fiscal_year(NULL) AS result;

-- CLEANUP
-- (No cleanup required)


-- ============= TEST CASE 9: Boundary - Leap year February 29th =============
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC9' AS tc, dbo.fn_get_fiscal_year('2024-02-29') AS result;

-- CLEANUP
-- (No cleanup required)


-- ============= TEST CASE 10: Edge - Very old date (year 1900) =============
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC10' AS tc, dbo.fn_get_fiscal_year('1900-01-01') AS result;

-- CLEANUP
-- (No cleanup required)


-- ============= TEST CASE 11: Edge - Future date (year 2100) =============
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC11' AS tc, dbo.fn_get_fiscal_year('2100-12-31') AS result;

-- CLEANUP
-- (No cleanup required)


-- ============= TEST CASE 12: Boundary - April 30th (end of first month) =============
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC12' AS tc, dbo.fn_get_fiscal_year('2023-04-30') AS result;

-- CLEANUP
-- (No cleanup required)


-- ============= TEST CASE 13: Boundary - May 1st (second month of fiscal year) =============
-- SETUP
-- (No setup required)

-- EXEC & ASSERT
SELECT 'TC13' AS tc, dbo.fn_get_fiscal_year('2023-05-01') AS result;

-- CLEANUP
-- (No cleanup required)
