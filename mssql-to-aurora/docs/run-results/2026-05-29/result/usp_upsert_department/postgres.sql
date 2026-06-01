-- ============================================================================
-- Target: Aurora PostgreSQL (Native)
-- Object: public.usp_upsert_department
-- Type: STORED PROCEDURE
-- Converted from: SQL Server T-SQL
-- ============================================================================

CREATE OR REPLACE PROCEDURE public.usp_upsert_department(
    p_department_id INT DEFAULT NULL,
    p_department_name VARCHAR(100) DEFAULT NULL,
    p_location VARCHAR(100) DEFAULT NULL,
    p_manager_id INT DEFAULT NULL,
    INOUT p_result_id INT DEFAULT NULL,
    INOUT p_operation VARCHAR(10) DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_error_message TEXT;
    v_existing_id INT;
    v_employee_exists BOOLEAN;
    v_duplicate_exists BOOLEAN;
BEGIN
    -- Initialize output parameters
    p_result_id := NULL;
    p_operation := NULL;
    
    -- Validate required parameters
    IF p_department_name IS NULL OR btrim(p_department_name) = '' THEN
        RAISE EXCEPTION 'Department name is required and cannot be empty.';
    END IF;
    
    -- Trim department name
    p_department_name := btrim(p_department_name);
    
    -- Validate manager_id if provided
    IF p_manager_id IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1 FROM public.employees WHERE employee_id = p_manager_id
        ) INTO v_employee_exists;
        
        IF NOT v_employee_exists THEN
            RAISE EXCEPTION 'Invalid manager_id. Employee does not exist.';
        END IF;
    END IF;
    
    -- Check if department_id is provided and exists
    v_existing_id := NULL;
    IF p_department_id IS NOT NULL THEN
        SELECT department_id INTO v_existing_id
        FROM public.departments 
        WHERE department_id = p_department_id;
    END IF;
    
    -- UPSERT logic
    IF v_existing_id IS NOT NULL THEN
        -- UPDATE existing department
        UPDATE public.departments
        SET 
            department_name = p_department_name,
            location = p_location,
            manager_id = p_manager_id,
            modified_date = CURRENT_TIMESTAMP
        WHERE department_id = p_department_id;
        
        p_result_id := p_department_id;
        p_operation := 'UPDATE';
    ELSE
        -- Check for duplicate department name
        SELECT EXISTS (
            SELECT 1 FROM public.departments WHERE department_name = p_department_name
        ) INTO v_duplicate_exists;
        
        IF v_duplicate_exists THEN
            RAISE EXCEPTION 'Department name already exists.';
        END IF;
        
        -- INSERT new department
        INSERT INTO public.departments (
            department_name,
            location,
            manager_id,
            created_date,
            modified_date
        )
        VALUES (
            p_department_name,
            p_location,
            p_manager_id,
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP
        )
        RETURNING department_id INTO p_result_id;
        
        p_operation := 'INSERT';
    END IF;
    
    -- Return result set (using RAISE NOTICE for informational output)
    -- Note: PostgreSQL procedures cannot return result sets directly
    -- This information is available through the INOUT parameters
    RAISE NOTICE 'department_id: %, operation: %, department_name: %, location: %, manager_id: %, processed_date: %',
        p_result_id, p_operation, p_department_name, p_location, p_manager_id, CURRENT_TIMESTAMP;
    
    -- Commit is implicit in PostgreSQL procedures
    COMMIT;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Rollback on error (implicit in PostgreSQL)
        ROLLBACK;
        
        -- Capture error information
        v_error_message := SQLERRM;
        
        -- Re-raise the error
        RAISE EXCEPTION '%', v_error_message;
END;
$$;

-- ============================================================================
-- CONVERSION NOTES:
-- ============================================================================
-- 1. OUTPUT parameters converted to INOUT parameters
--    - p_result_id: Returns the department_id (new or updated)
--    - p_operation: Returns 'INSERT' or 'UPDATE'
--
-- 2. Variable naming conventions:
--    - p_ prefix: procedure parameters
--    - v_ prefix: local variables
--
-- 3. T-SQL to PL/pgSQL mappings:
--    - SET NOCOUNT ON → removed (not needed in PostgreSQL)
--    - BEGIN TRANSACTION/COMMIT → explicit COMMIT in procedure
--    - TRY-CATCH → EXCEPTION WHEN OTHERS block
--    - RAISERROR → RAISE EXCEPTION
--    - SCOPE_IDENTITY() → RETURNING clause
--    - @@TRANCOUNT → handled by explicit COMMIT/ROLLBACK
--    - GETDATE() → CURRENT_TIMESTAMP
--    - LTRIM(RTRIM()) → btrim()
--    - ERROR_MESSAGE() → SQLERRM
--    - NVARCHAR → VARCHAR (PostgreSQL handles Unicode natively)
--    - dbo schema → public schema
--
-- 4. Result set handling:
--    - Original T-SQL returns a result set with SELECT statement
--    - PostgreSQL procedures cannot return result sets
--    - Converted to RAISE NOTICE for logging
--    - Actual results available through INOUT parameters
--
-- 5. Error handling differences:
--    - ERROR_SEVERITY() and ERROR_STATE() not available in PostgreSQL
--    - Only SQLERRM (error message) is captured
--    - Error is re-raised with RAISE EXCEPTION
--
-- 6. Transaction control:
--    - PostgreSQL procedures support explicit COMMIT/ROLLBACK (PG 11+)
--    - EXCEPTION block automatically rolls back on error
--    - Explicit ROLLBACK in EXCEPTION block for clarity
--
-- 7. Validation logic:
--    - EXISTS checks converted to SELECT EXISTS(...) INTO boolean
--    - Maintains same validation order and error messages
--
-- 8. UPSERT implementation:
--    - Maintains same logic: check existence, then UPDATE or INSERT
--    - Could be optimized with INSERT ... ON CONFLICT, but kept
--      original logic for behavioral equivalence
--
-- ============================================================================
-- USAGE EXAMPLE:
-- ============================================================================
-- DO $$
-- DECLARE
--     v_result_id INT;
--     v_operation VARCHAR(10);
-- BEGIN
--     CALL public.usp_upsert_department(
--         p_department_id := NULL,
--         p_department_name := 'Engineering',
--         p_location := 'Building A',
--         p_manager_id := 1001,
--         p_result_id := v_result_id,
--         p_operation := v_operation
--     );
--     RAISE NOTICE 'Result: ID=%, Operation=%', v_result_id, v_operation;
-- END $$;
-- ============================================================================
