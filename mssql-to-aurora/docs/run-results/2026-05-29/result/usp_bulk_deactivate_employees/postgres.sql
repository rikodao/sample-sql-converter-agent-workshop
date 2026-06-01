-- ============================================================================
-- Target: Aurora PostgreSQL (Native)
-- Object: public.usp_bulk_deactivate_employees
-- Type: STORED PROCEDURE
-- Converted from: T-SQL (SQL Server)
-- ============================================================================
-- Conversion Notes:
-- - OUTPUT parameter converted to INOUT
-- - TRY-CATCH converted to EXCEPTION block
-- - Temp table (#emp_ids) converted to TEMP TABLE
-- - STRING_SPLIT converted to string_to_array + unnest
-- - @@ROWCOUNT converted to GET DIAGNOSTICS
-- - GETDATE() converted to now()
-- - RAISERROR converted to RAISE EXCEPTION
-- - ERROR_MESSAGE() converted to SQLERRM
-- - is_active BIT (0/1) converted to boolean (false/true)
-- ============================================================================

CREATE OR REPLACE PROCEDURE public.usp_bulk_deactivate_employees(
    p_employee_ids VARCHAR,
    p_deactivation_reason VARCHAR(500) DEFAULT NULL,
    INOUT p_deactivated_count INT DEFAULT 0
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_error_message TEXT;
    v_row_count INT;
BEGIN
    -- Initialize output parameter
    p_deactivated_count := 0;
    
    -- Validate input parameter
    IF p_employee_ids IS NULL OR TRIM(p_employee_ids) = '' THEN
        RAISE EXCEPTION 'Parameter @employee_ids cannot be NULL or empty';
    END IF;
    
    -- Create temp table to hold parsed employee IDs
    -- Using ON COMMIT DELETE ROWS to clear data after each transaction
    -- but keep table structure for potential reuse in same session
    CREATE TEMP TABLE IF NOT EXISTS emp_ids_temp (
        employee_id INT
    ) ON COMMIT DELETE ROWS;
    
    -- Parse comma-separated employee IDs
    -- Convert string to array, unnest, trim, and cast to INT
    INSERT INTO emp_ids_temp (employee_id)
    SELECT CAST(TRIM(value) AS INT)
    FROM unnest(string_to_array(p_employee_ids, ',')) AS value
    WHERE TRIM(value) <> '';
    
    -- Validate that all employee IDs exist
    IF EXISTS (
        SELECT 1 
        FROM emp_ids_temp e
        LEFT JOIN public.employees emp ON e.employee_id = emp.employee_id
        WHERE emp.employee_id IS NULL
    ) THEN
        RAISE EXCEPTION 'One or more employee IDs do not exist';
    END IF;
    
    -- Update employees to deactivated status
    UPDATE public.employees e
    SET 
        is_active = false,
        deactivated_date = now()
    FROM emp_ids_temp tmp
    WHERE e.employee_id = tmp.employee_id
      AND e.is_active = true;  -- Only deactivate currently active employees
    
    -- Get count of deactivated records
    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    p_deactivated_count := v_row_count;
    
    -- Commit transaction
    COMMIT;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Rollback transaction on error
        ROLLBACK;
        
        -- Capture error information
        v_error_message := SQLERRM;
        
        -- Re-raise the error with original message
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
--     CALL public.usp_bulk_deactivate_employees(
--         p_employee_ids := '1001,1002,1003',
--         p_deactivation_reason := 'Layoff',
--         p_deactivated_count := v_count
--     );
--     RAISE NOTICE 'Deactivated count: %', v_count;
-- END $$;
-- ============================================================================

-- ============================================================================
-- Conversion Details:
-- ============================================================================
-- 
-- 1. Parameter Mapping:
--    T-SQL: @employee_ids NVARCHAR(MAX)
--    PG:    p_employee_ids VARCHAR (no MAX, unlimited by default)
--
--    T-SQL: @deactivation_reason NVARCHAR(500) = NULL
--    PG:    p_deactivation_reason VARCHAR(500) DEFAULT NULL
--
--    T-SQL: @deactivated_count INT OUTPUT
--    PG:    INOUT p_deactivated_count INT DEFAULT 0
--
-- 2. String Parsing:
--    T-SQL: STRING_SPLIT(@employee_ids, ',')
--    PG:    unnest(string_to_array(p_employee_ids, ','))
--
-- 3. String Trimming:
--    T-SQL: LTRIM(RTRIM(value))
--    PG:    TRIM(value)
--
-- 4. Row Count:
--    T-SQL: SET @deactivated_count = @@ROWCOUNT
--    PG:    GET DIAGNOSTICS v_row_count = ROW_COUNT;
--           p_deactivated_count := v_row_count;
--
-- 5. Date/Time:
--    T-SQL: GETDATE()
--    PG:    now()
--
-- 6. Boolean Values:
--    T-SQL: is_active = 0 (BIT type, 0 = false, 1 = true)
--    PG:    is_active = false (boolean type)
--
-- 7. Error Handling:
--    T-SQL: BEGIN TRY ... END TRY BEGIN CATCH ... END CATCH
--    PG:    BEGIN ... EXCEPTION WHEN OTHERS THEN ... END
--
--    T-SQL: ERROR_MESSAGE(), ERROR_SEVERITY(), ERROR_STATE()
--    PG:    SQLERRM (only message available, severity/state not directly accessible)
--
-- 8. Transaction Control:
--    T-SQL: BEGIN TRANSACTION ... COMMIT TRANSACTION ... ROLLBACK TRANSACTION
--    PG:    (implicit BEGIN in PROCEDURE) ... COMMIT ... ROLLBACK
--
-- 9. Temp Table:
--    T-SQL: CREATE TABLE #emp_ids (...); DROP TABLE #emp_ids;
--    PG:    CREATE TEMP TABLE emp_ids_temp (...) ON COMMIT DELETE ROWS;
--           (no explicit DROP needed, auto-cleaned)
--
-- 10. Schema:
--     T-SQL: dbo.employees
--     PG:    public.employees
--
-- ============================================================================
