-- ============================================================================
-- TEST SUITE for public.fn_get_fiscal_year
-- Target: Aurora PostgreSQL (Native)
-- ============================================================================
-- Fiscal year calculation function test cases
-- Assumes fiscal year starts in April (month 4)
-- ============================================================================

-- ============= TEST CASE 1: Normal case - Date in fiscal year start month (April) =============
-- SETUP
-- (No setup needed for scalar function)

-- EXEC
DO $$
DECLARE
    v_result1 INT;
BEGIN
    v_result1 := public.fn_get_fiscal_year('2023-04-01'::DATE);
    
    -- ASSERT
    RAISE NOTICE 'TC1|%|2023', v_result1;
END $$;


-- ============= TEST CASE 2: Normal case - Date after fiscal year start =============
-- SETUP
-- (No setup needed)

-- EXEC
DO $$
DECLARE
    v_result2 INT;
BEGIN
    v_result2 := public.fn_get_fiscal_year('2023-12-31'::DATE);
    
    -- ASSERT
    RAISE NOTICE 'TC2|%|2023', v_result2;
END $$;


-- ============= TEST CASE 3: Normal case - Date before fiscal year start (Jan-Mar) =============
-- SETUP
-- (No setup needed)

-- EXEC
DO $$
DECLARE
    v_result3 INT;
BEGIN
    v_result3 := public.fn_get_fiscal_year('2023-03-31'::DATE);
    
    -- ASSERT
    RAISE NOTICE 'TC3|%|2022', v_result3;
END $$;


-- ============= TEST CASE 4: Boundary - First day of fiscal year =============
-- SETUP
-- (No setup needed)

-- EXEC
DO $$
DECLARE
    v_result4 INT;
BEGIN
    v_result4 := public.fn_get_fiscal_year('2024-04-01'::DATE);
    
    -- ASSERT
    RAISE NOTICE 'TC4|%|2024', v_result4;
END $$;


-- ============= TEST CASE 5: Boundary - Last day before fiscal year start =============
-- SETUP
-- (No setup needed)

-- EXEC
DO $$
DECLARE
    v_result5 INT;
BEGIN
    v_result5 := public.fn_get_fiscal_year('2024-03-31'::DATE);
    
    -- ASSERT
    RAISE NOTICE 'TC5|%|2023', v_result5;
END $$;


-- ============= TEST CASE 6: Boundary - January 1st (New Year) =============
-- SETUP
-- (No setup needed)

-- EXEC
DO $$
DECLARE
    v_result6 INT;
BEGIN
    v_result6 := public.fn_get_fiscal_year('2023-01-01'::DATE);
    
    -- ASSERT
    RAISE NOTICE 'TC6|%|2022', v_result6;
END $$;


-- ============= TEST CASE 7: Boundary - December 31st (Year end) =============
-- SETUP
-- (No setup needed)

-- EXEC
DO $$
DECLARE
    v_result7 INT;
BEGIN
    v_result7 := public.fn_get_fiscal_year('2023-12-31'::DATE);
    
    -- ASSERT
    RAISE NOTICE 'TC7|%|2023', v_result7;
END $$;


-- ============= TEST CASE 8: Boundary - Leap year date (Feb 29) =============
-- SETUP
-- (No setup needed)

-- EXEC
DO $$
DECLARE
    v_result8 INT;
BEGIN
    v_result8 := public.fn_get_fiscal_year('2024-02-29'::DATE);
    
    -- ASSERT
    RAISE NOTICE 'TC8|%|2023', v_result8;
END $$;


-- ============= TEST CASE 9: Exception - NULL input =============
-- SETUP
-- (No setup needed)

-- EXEC & ASSERT
DO $$
DECLARE
    v_result9 INT;
BEGIN
    BEGIN
        v_result9 := public.fn_get_fiscal_year(NULL);
        RAISE NOTICE 'TC9|NO_ERROR|%', COALESCE(v_result9::TEXT, 'NULL');
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'TC9|ERROR|%', SQLERRM;
    END;
END $$;


-- ============= TEST CASE 10: Edge case - Very old date (year 1900) =============
-- SETUP
-- (No setup needed)

-- EXEC
DO $$
DECLARE
    v_result10 INT;
BEGIN
    v_result10 := public.fn_get_fiscal_year('1900-05-15'::DATE);
    
    -- ASSERT
    RAISE NOTICE 'TC10|%|1900', v_result10;
END $$;


-- ============= TEST CASE 11: Edge case - Far future date (year 2099) =============
-- SETUP
-- (No setup needed)

-- EXEC
DO $$
DECLARE
    v_result11 INT;
BEGIN
    v_result11 := public.fn_get_fiscal_year('2099-06-30'::DATE);
    
    -- ASSERT
    RAISE NOTICE 'TC11|%|2099', v_result11;
END $$;


-- ============= TEST CASE 12: Multiple calls with different months =============
-- SETUP
-- (No setup needed)

-- EXEC & ASSERT
SELECT 
    'TC12' AS test_case,
    public.fn_get_fiscal_year('2023-01-15'::DATE) AS jan_result,
    public.fn_get_fiscal_year('2023-02-15'::DATE) AS feb_result,
    public.fn_get_fiscal_year('2023-03-15'::DATE) AS mar_result,
    public.fn_get_fiscal_year('2023-04-15'::DATE) AS apr_result,
    public.fn_get_fiscal_year('2023-05-15'::DATE) AS may_result,
    public.fn_get_fiscal_year('2023-06-15'::DATE) AS jun_result,
    public.fn_get_fiscal_year('2023-07-15'::DATE) AS jul_result,
    public.fn_get_fiscal_year('2023-08-15'::DATE) AS aug_result,
    public.fn_get_fiscal_year('2023-09-15'::DATE) AS sep_result,
    public.fn_get_fiscal_year('2023-10-15'::DATE) AS oct_result,
    public.fn_get_fiscal_year('2023-11-15'::DATE) AS nov_result,
    public.fn_get_fiscal_year('2023-12-15'::DATE) AS dec_result;


-- ============= TEST CASE 13: Integration - Use in WHERE clause =============
-- SETUP
CREATE TEMPORARY TABLE tmp_test_dates (
    id SERIAL PRIMARY KEY,
    event_date DATE,
    description VARCHAR(50)
);

INSERT INTO tmp_test_dates (event_date, description) VALUES
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
FROM tmp_test_dates
WHERE public.fn_get_fiscal_year(event_date) = 2022;

-- CLEANUP
DROP TABLE tmp_test_dates;


-- ============= TEST CASE 14: Integration - Use in ORDER BY =============
-- SETUP
CREATE TEMPORARY TABLE tmp_test_events (
    id SERIAL PRIMARY KEY,
    event_date DATE,
    amount DECIMAL(10,2)
);

INSERT INTO tmp_test_events (event_date, amount) VALUES
('2023-01-15', 100.00),
('2022-05-20', 200.00),
('2023-06-10', 150.00),
('2022-12-31', 300.00);

-- EXEC & ASSERT
SELECT 
    'TC14' AS test_case,
    event_date,
    public.fn_get_fiscal_year(event_date) AS fiscal_year,
    amount
FROM tmp_test_events
ORDER BY public.fn_get_fiscal_year(event_date), event_date;

-- CLEANUP
DROP TABLE tmp_test_events;


-- ============= TEST CASE 15: Integration - Use in GROUP BY =============
-- SETUP
CREATE TEMPORARY TABLE tmp_sales_data (
    id SERIAL PRIMARY KEY,
    sale_date DATE,
    amount DECIMAL(10,2)
);

INSERT INTO tmp_sales_data (sale_date, amount) VALUES
('2022-03-15', 1000.00),
('2022-04-10', 1500.00),
('2022-05-20', 2000.00),
('2023-01-15', 1200.00),
('2023-04-05', 1800.00);

-- EXEC & ASSERT
SELECT 
    'TC15' AS test_case,
    public.fn_get_fiscal_year(sale_date) AS fiscal_year,
    COUNT(*) AS transaction_count,
    SUM(amount) AS total_amount
FROM tmp_sales_data
GROUP BY public.fn_get_fiscal_year(sale_date)
ORDER BY fiscal_year;

-- CLEANUP
DROP TABLE tmp_sales_data;

-- ============================================================================
-- END OF TEST SUITE
-- ============================================================================
