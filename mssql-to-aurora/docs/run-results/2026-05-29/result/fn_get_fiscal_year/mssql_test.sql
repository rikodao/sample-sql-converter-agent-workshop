-- ============================================================================
-- TEST SUITE for dbo.fn_get_fiscal_year
-- ============================================================================
-- Fiscal year calculation function test cases
-- Assumes fiscal year starts in April (month 4)
-- ============================================================================

-- ============= TEST CASE 1: Normal case - Date in fiscal year start month (April) =============
-- SETUP
-- (No setup needed for scalar function)

-- EXEC
DECLARE @result1 INT;
SET @result1 = dbo.fn_get_fiscal_year('2023-04-01');

-- ASSERT
SELECT 'TC1' AS test_case, @result1 AS result, 2023 AS expected;

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 2: Normal case - Date after fiscal year start =============
-- SETUP
-- (No setup needed)

-- EXEC
DECLARE @result2 INT;
SET @result2 = dbo.fn_get_fiscal_year('2023-12-31');

-- ASSERT
SELECT 'TC2' AS test_case, @result2 AS result, 2023 AS expected;

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 3: Normal case - Date before fiscal year start (Jan-Mar) =============
-- SETUP
-- (No setup needed)

-- EXEC
DECLARE @result3 INT;
SET @result3 = dbo.fn_get_fiscal_year('2023-03-31');

-- ASSERT
SELECT 'TC3' AS test_case, @result3 AS result, 2022 AS expected;

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 4: Boundary - First day of fiscal year =============
-- SETUP
-- (No setup needed)

-- EXEC
DECLARE @result4 INT;
SET @result4 = dbo.fn_get_fiscal_year('2024-04-01');

-- ASSERT
SELECT 'TC4' AS test_case, @result4 AS result, 2024 AS expected;

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 5: Boundary - Last day before fiscal year start =============
-- SETUP
-- (No setup needed)

-- EXEC
DECLARE @result5 INT;
SET @result5 = dbo.fn_get_fiscal_year('2024-03-31');

-- ASSERT
SELECT 'TC5' AS test_case, @result5 AS result, 2023 AS expected;

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 6: Boundary - January 1st (New Year) =============
-- SETUP
-- (No setup needed)

-- EXEC
DECLARE @result6 INT;
SET @result6 = dbo.fn_get_fiscal_year('2023-01-01');

-- ASSERT
SELECT 'TC6' AS test_case, @result6 AS result, 2022 AS expected;

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 7: Boundary - December 31st (Year end) =============
-- SETUP
-- (No setup needed)

-- EXEC
DECLARE @result7 INT;
SET @result7 = dbo.fn_get_fiscal_year('2023-12-31');

-- ASSERT
SELECT 'TC7' AS test_case, @result7 AS result, 2023 AS expected;

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 8: Boundary - Leap year date (Feb 29) =============
-- SETUP
-- (No setup needed)

-- EXEC
DECLARE @result8 INT;
SET @result8 = dbo.fn_get_fiscal_year('2024-02-29');

-- ASSERT
SELECT 'TC8' AS test_case, @result8 AS result, 2023 AS expected;

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 9: Exception - NULL input =============
-- SETUP
-- (No setup needed)

-- EXEC & ASSERT
BEGIN TRY
    DECLARE @result9 INT;
    SET @result9 = dbo.fn_get_fiscal_year(NULL);
    SELECT 'TC9' AS test_case, 'NO_ERROR' AS result, @result9 AS returned_value;
END TRY
BEGIN CATCH
    SELECT 'TC9' AS test_case, 'ERROR' AS result, ERROR_MESSAGE() AS error_message;
END CATCH

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 10: Edge case - Very old date (year 1900) =============
-- SETUP
-- (No setup needed)

-- EXEC
DECLARE @result10 INT;
SET @result10 = dbo.fn_get_fiscal_year('1900-05-15');

-- ASSERT
SELECT 'TC10' AS test_case, @result10 AS result, 1900 AS expected;

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 11: Edge case - Far future date (year 2099) =============
-- SETUP
-- (No setup needed)

-- EXEC
DECLARE @result11 INT;
SET @result11 = dbo.fn_get_fiscal_year('2099-06-30');

-- ASSERT
SELECT 'TC11' AS test_case, @result11 AS result, 2099 AS expected;

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 12: Multiple calls with different months =============
-- SETUP
-- (No setup needed)

-- EXEC & ASSERT
SELECT 
    'TC12' AS test_case,
    dbo.fn_get_fiscal_year('2023-01-15') AS jan_result,
    dbo.fn_get_fiscal_year('2023-02-15') AS feb_result,
    dbo.fn_get_fiscal_year('2023-03-15') AS mar_result,
    dbo.fn_get_fiscal_year('2023-04-15') AS apr_result,
    dbo.fn_get_fiscal_year('2023-05-15') AS may_result,
    dbo.fn_get_fiscal_year('2023-06-15') AS jun_result,
    dbo.fn_get_fiscal_year('2023-07-15') AS jul_result,
    dbo.fn_get_fiscal_year('2023-08-15') AS aug_result,
    dbo.fn_get_fiscal_year('2023-09-15') AS sep_result,
    dbo.fn_get_fiscal_year('2023-10-15') AS oct_result,
    dbo.fn_get_fiscal_year('2023-11-15') AS nov_result,
    dbo.fn_get_fiscal_year('2023-12-15') AS dec_result;

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 13: Integration - Use in WHERE clause =============
-- SETUP
CREATE TABLE #test_dates (
    id INT IDENTITY(1,1) PRIMARY KEY,
    event_date DATE,
    description VARCHAR(50)
);

INSERT INTO #test_dates (event_date, description) VALUES
('2022-03-15', 'Q4 FY2021'),
('2022-04-01', 'Q1 FY2022'),
('2022-06-30', 'Q1 FY2022'),
('2022-12-31', 'Q3 FY2022'),
('2023-01-15', 'Q4 FY2022'),
('2023-04-01', 'Q1 FY2023');

-- EXEC & ASSERT
SELECT 
    'TC13' AS test_case,
    COUNT(*) AS fy2022_count
FROM #test_dates
WHERE dbo.fn_get_fiscal_year(event_date) = 2022;

-- CLEANUP
DROP TABLE #test_dates;


-- ============= TEST CASE 14: Integration - Use in ORDER BY =============
-- SETUP
CREATE TABLE #test_events (
    id INT IDENTITY(1,1) PRIMARY KEY,
    event_date DATE,
    amount DECIMAL(10,2)
);

INSERT INTO #test_events (event_date, amount) VALUES
('2023-01-15', 100.00),
('2022-05-20', 200.00),
('2023-06-10', 150.00),
('2022-12-31', 300.00);

-- EXEC & ASSERT
SELECT 
    'TC14' AS test_case,
    event_date,
    dbo.fn_get_fiscal_year(event_date) AS fiscal_year,
    amount
FROM #test_events
ORDER BY dbo.fn_get_fiscal_year(event_date), event_date;

-- CLEANUP
DROP TABLE #test_events;


-- ============= TEST CASE 15: Integration - Use in GROUP BY =============
-- SETUP
CREATE TABLE #sales_data (
    id INT IDENTITY(1,1) PRIMARY KEY,
    sale_date DATE,
    amount DECIMAL(10,2)
);

INSERT INTO #sales_data (sale_date, amount) VALUES
('2022-03-15', 1000.00),
('2022-04-10', 1500.00),
('2022-05-20', 2000.00),
('2023-01-15', 1200.00),
('2023-04-05', 1800.00);

-- EXEC & ASSERT
SELECT 
    'TC15' AS test_case,
    dbo.fn_get_fiscal_year(sale_date) AS fiscal_year,
    COUNT(*) AS transaction_count,
    SUM(amount) AS total_amount
FROM #sales_data
GROUP BY dbo.fn_get_fiscal_year(sale_date)
ORDER BY fiscal_year;

-- CLEANUP
DROP TABLE #sales_data;

-- ============================================================================
-- END OF TEST SUITE
-- ============================================================================
