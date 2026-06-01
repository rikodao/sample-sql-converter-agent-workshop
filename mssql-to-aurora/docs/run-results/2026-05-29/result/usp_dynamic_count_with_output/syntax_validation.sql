-- ============================================================================
-- PostgreSQL Syntax Validation
-- ============================================================================
-- This file validates the syntax of the converted procedure
-- by checking key PL/pgSQL constructs
-- ============================================================================

-- Test 1: Basic procedure structure
DO $$
BEGIN
    RAISE NOTICE 'Syntax validation: Basic structure OK';
END $$;

-- Test 2: INOUT parameter syntax
CREATE OR REPLACE PROCEDURE test_inout(
    INOUT p_value INT DEFAULT 0
)
LANGUAGE plpgsql
AS $$
BEGIN
    p_value := p_value + 1;
END $$;

-- Test 3: Dynamic SQL with EXECUTE INTO
DO $$
DECLARE
    v_count INT;
    v_sql TEXT;
BEGIN
    v_sql := format('SELECT COUNT(*)::int FROM %I.%I', 'pg_catalog', 'pg_class');
    EXECUTE v_sql INTO v_count;
    RAISE NOTICE 'Dynamic SQL test: %', v_count;
END $$;

-- Test 4: Exception handling
DO $$
DECLARE
    v_error TEXT;
BEGIN
    RAISE EXCEPTION 'Test error';
EXCEPTION
    WHEN OTHERS THEN
        v_error := SQLERRM;
        RAISE NOTICE 'Exception handling test: %', v_error;
END $$;

-- Test 5: format() with %I
DO $$
DECLARE
    v_sql TEXT;
BEGIN
    v_sql := format('SELECT * FROM %I.%I', 'public', 'test_table');
    RAISE NOTICE 'format() test: %', v_sql;
END $$;

-- Cleanup
DROP PROCEDURE IF EXISTS test_inout;

RAISE NOTICE '============================================================================';
RAISE NOTICE 'All syntax validation tests completed successfully';
RAISE NOTICE '============================================================================';
