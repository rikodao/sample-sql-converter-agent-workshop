-- ============================================================================
-- Target: Aurora PostgreSQL (Native)
-- Object: public.usp_dynamic_count_with_output
-- Type: STORED PROCEDURE
-- Converted from: SQL Server T-SQL
-- ============================================================================
-- Conversion Notes:
-- 1. sp_executesql with OUTPUT → EXECUTE ... INTO
-- 2. QUOTENAME() → format() with %I (identifier quoting)
-- 3. sys.objects → information_schema.tables
-- 4. RAISERROR → RAISE EXCEPTION
-- 5. TRY-CATCH → EXCEPTION WHEN OTHERS
-- 6. OUTPUT parameter → INOUT parameter
-- 7. SET NOCOUNT ON → (not needed in PG)
-- 8. Result set output → RAISE NOTICE (PG procedures cannot return result sets)
-- ============================================================================

CREATE OR REPLACE PROCEDURE public.usp_dynamic_count_with_output(
    p_table_name VARCHAR(128),
    p_where_clause TEXT DEFAULT NULL,
    INOUT p_record_count INT DEFAULT 0
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql TEXT;
    v_error_message TEXT;
    v_table_name VARCHAR(128);
    v_where_clause TEXT;
    v_table_exists BOOLEAN;
BEGIN
    -- Initialize output parameter
    p_record_count := 0;
    
    -- Validate input: table_name cannot be NULL or empty
    IF p_table_name IS NULL OR btrim(p_table_name) = '' THEN
        RAISE EXCEPTION 'Table name cannot be NULL or empty.';
    END IF;
    
    -- Remove leading/trailing whitespace
    v_table_name := btrim(p_table_name);
    v_where_clause := p_where_clause;
    
    -- Check if table exists in public schema (equivalent to dbo in SQL Server)
    SELECT EXISTS (
        SELECT 1 
        FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = lower(v_table_name)
        AND table_type IN ('BASE TABLE', 'VIEW')
    ) INTO v_table_exists;
    
    IF NOT v_table_exists THEN
        v_error_message := format('Table or view [public].[%s] does not exist.', v_table_name);
        RAISE EXCEPTION '%', v_error_message;
    END IF;
    
    -- Build dynamic SQL using format() with %I for safe identifier quoting
    -- %I automatically handles SQL injection prevention (like QUOTENAME)
    v_sql := format('SELECT COUNT(*)::int FROM %I.%I', 'public', v_table_name);
    
    -- Add WHERE clause if provided
    IF v_where_clause IS NOT NULL AND btrim(v_where_clause) <> '' THEN
        -- Note: WHERE clause is user-provided and should be validated by caller
        -- We concatenate it directly as in the original T-SQL
        v_sql := v_sql || ' WHERE ' || v_where_clause;
    END IF;
    
    -- Execute dynamic SQL and capture result into p_record_count
    EXECUTE v_sql INTO p_record_count;
    
    -- Return success indicator via RAISE NOTICE
    -- Note: PostgreSQL procedures cannot return result sets like SQL Server
    -- The original T-SQL returned a SELECT result set, but in PG we use RAISE NOTICE
    -- The actual count is returned via the INOUT parameter p_record_count
    RAISE NOTICE 'Table: %, Count: %, Where: %, Status: SUCCESS', 
        v_table_name, 
        p_record_count, 
        COALESCE(v_where_clause, 'No filter');
    
EXCEPTION
    WHEN OTHERS THEN
        -- Capture error information
        v_error_message := SQLERRM;
        
        -- Set output to -1 to indicate error
        p_record_count := -1;
        
        -- Log error information
        RAISE NOTICE 'Table: %, Count: %, Where: %, Status: ERROR, Message: %',
            COALESCE(v_table_name, p_table_name),
            p_record_count,
            COALESCE(v_where_clause, p_where_clause),
            v_error_message;
        
        -- Re-raise error for caller
        RAISE EXCEPTION '%', v_error_message;
END;
$$;

-- ============================================================================
-- Usage Example:
-- ============================================================================
-- DO $$
-- DECLARE
--     v_count INT := 0;
-- BEGIN
--     CALL public.usp_dynamic_count_with_output('my_table', 'id > 100', v_count);
--     RAISE NOTICE 'Record count: %', v_count;
-- END $$;
-- ============================================================================

COMMENT ON PROCEDURE public.usp_dynamic_count_with_output IS 
'Dynamically counts records in a specified table with optional WHERE clause. 
Converted from SQL Server stored procedure. 
Returns count via INOUT parameter p_record_count.
Returns -1 on error.';
