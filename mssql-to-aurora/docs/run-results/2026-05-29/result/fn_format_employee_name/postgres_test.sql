-- ============================================================================
-- TEST SUITE for public.fn_format_employee_name
-- Target: Aurora PostgreSQL (Native)
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
DO $$
DECLARE
    v_result1 VARCHAR(200);
BEGIN
    v_result1 := public.fn_format_employee_name('John', 'Doe', 'Michael');
    
    -- ASSERT
    RAISE NOTICE 'TC1|%|Doe, John Michael', v_result1;
END $$;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 2: Normal - First and last name only (no middle) =============
-- SETUP
-- No setup needed

-- EXEC
DO $$
DECLARE
    v_result2 VARCHAR(200);
BEGIN
    v_result2 := public.fn_format_employee_name('Jane', 'Smith', NULL);
    
    -- ASSERT
    RAISE NOTICE 'TC2|%|Smith, Jane', v_result2;
END $$;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 3: Normal - Last name only =============
-- SETUP
-- No setup needed

-- EXEC
DO $$
DECLARE
    v_result3 VARCHAR(200);
BEGIN
    v_result3 := public.fn_format_employee_name(NULL, 'Johnson', NULL);
    
    -- ASSERT
    RAISE NOTICE 'TC3|%|Johnson', v_result3;
END $$;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 4: Normal - First name only =============
-- SETUP
-- No setup needed

-- EXEC
DO $$
DECLARE
    v_result4 VARCHAR(200);
BEGIN
    v_result4 := public.fn_format_employee_name('Alice', NULL, NULL);
    
    -- ASSERT
    RAISE NOTICE 'TC4|%|Alice', v_result4;
END $$;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 5: Boundary - All NULL inputs =============
-- SETUP
-- No setup needed

-- EXEC
DO $$
DECLARE
    v_result5 VARCHAR(200);
BEGIN
    v_result5 := public.fn_format_employee_name(NULL, NULL, NULL);
    
    -- ASSERT
    RAISE NOTICE 'TC5|%|NULL', COALESCE(v_result5, 'NULL');
END $$;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 6: Boundary - Empty strings =============
-- SETUP
-- No setup needed

-- EXEC
DO $$
DECLARE
    v_result6 VARCHAR(200);
BEGIN
    v_result6 := public.fn_format_employee_name('', '', '');
    
    -- ASSERT
    RAISE NOTICE 'TC6|%|NULL or empty', COALESCE(v_result6, 'NULL');
END $$;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 7: Boundary - Whitespace only in middle name =============
-- SETUP
-- No setup needed

-- EXEC
DO $$
DECLARE
    v_result7 VARCHAR(200);
BEGIN
    v_result7 := public.fn_format_employee_name('Bob', 'Williams', '   ');
    
    -- ASSERT
    RAISE NOTICE 'TC7|%|Williams, Bob', v_result7;
END $$;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 8: Boundary - Names with leading/trailing spaces =============
-- SETUP
-- No setup needed

-- EXEC
DO $$
DECLARE
    v_result8 VARCHAR(200);
BEGIN
    v_result8 := public.fn_format_employee_name('  Charlie  ', '  Brown  ', '  M  ');
    
    -- ASSERT
    RAISE NOTICE 'TC8|%|Brown, Charlie M', v_result8;
END $$;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 9: Boundary - Very long names (max length) =============
-- SETUP
-- No setup needed

-- EXEC
DO $$
DECLARE
    v_long_first VARCHAR(50) := repeat('A', 50);
    v_long_last VARCHAR(50) := repeat('B', 50);
    v_long_middle VARCHAR(50) := repeat('C', 50);
    v_result9 VARCHAR(200);
BEGIN
    v_result9 := public.fn_format_employee_name(v_long_first, v_long_last, v_long_middle);
    
    -- ASSERT
    RAISE NOTICE 'TC9|%|%|%', length(v_result9), 150, left(v_result9, 20);
END $$;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 10: Boundary - Single character names =============
-- SETUP
-- No setup needed

-- EXEC
DO $$
DECLARE
    v_result10 VARCHAR(200);
BEGIN
    v_result10 := public.fn_format_employee_name('A', 'B', 'C');
    
    -- ASSERT
    RAISE NOTICE 'TC10|%|B, A C', v_result10;
END $$;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 11: Special - Names with special characters =============
-- SETUP
-- No setup needed

-- EXEC
DO $$
DECLARE
    v_result11 VARCHAR(200);
BEGIN
    v_result11 := public.fn_format_employee_name('Mary-Jane', 'O''Connor', 'St. Claire');
    
    -- ASSERT
    RAISE NOTICE 'TC11|%|O''Connor, Mary-Jane St. Claire', v_result11;
END $$;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 12: Special - Unicode characters =============
-- SETUP
-- No setup needed

-- EXEC
DO $$
DECLARE
    v_result12 VARCHAR(200);
BEGIN
    v_result12 := public.fn_format_employee_name('José', 'García', 'María');
    
    -- ASSERT
    RAISE NOTICE 'TC12|%|García, José María', v_result12;
END $$;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 13: Edge - Only middle name provided (unusual) =============
-- SETUP
-- No setup needed

-- EXEC
DO $$
DECLARE
    v_result13 VARCHAR(200);
BEGIN
    v_result13 := public.fn_format_employee_name(NULL, NULL, 'MiddleOnly');
    
    -- ASSERT
    RAISE NOTICE 'TC13|%|NULL', COALESCE(v_result13, 'NULL');
END $$;

-- CLEANUP
-- No cleanup needed

-- ============================================================================
-- END OF TEST SUITE
-- ============================================================================
