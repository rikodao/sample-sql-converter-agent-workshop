-- ============================================================================
-- Target: Aurora PostgreSQL (Native PL/pgSQL)
-- Object: public.usp_validate_and_create_dept
-- Type: STORED PROCEDURE
-- Converted from: SQL Server T-SQL
-- ============================================================================

CREATE OR REPLACE PROCEDURE public.usp_validate_and_create_dept(
    p_department_name VARCHAR(100),
    p_location VARCHAR(100) DEFAULT NULL,
    p_manager_id INT DEFAULT NULL,
    p_min_name_length INT DEFAULT 3,
    p_max_name_length INT DEFAULT 100,
    INOUT p_new_department_id INT DEFAULT NULL,
    INOUT p_validation_status VARCHAR(50) DEFAULT NULL,
    INOUT p_error_message VARCHAR(500) DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_existing_count INT;
    v_manager_exists BOOLEAN;
    v_manager_active BOOLEAN;
    v_trimmed_name VARCHAR(100);
    v_name_length INT;
    v_error_number TEXT;
    v_error_severity TEXT;
    v_error_state TEXT;
BEGIN
    -- Initialize output parameters
    p_new_department_id := NULL;
    p_validation_status := NULL;
    p_error_message := NULL;
    
    -- ========================================
    -- VALIDATION PHASE
    -- ========================================
    
    -- Validation 1: Department name is required
    IF p_department_name IS NULL THEN
        p_validation_status := 'FAILED';
        p_error_message := 'Department name cannot be NULL.';
        RETURN;
    END IF;
    
    -- Trim and check for empty string
    v_trimmed_name := LTRIM(RTRIM(p_department_name));
    
    IF v_trimmed_name = '' THEN
        p_validation_status := 'FAILED';
        p_error_message := 'Department name cannot be empty or whitespace only.';
        RETURN;
    END IF;
    
    -- Validation 2: Check minimum length
    v_name_length := LENGTH(v_trimmed_name);
    
    IF v_name_length < p_min_name_length THEN
        p_validation_status := 'FAILED';
        p_error_message := 'Department name must be at least ' || p_min_name_length::VARCHAR(10) || ' characters long.';
        RETURN;
    END IF;
    
    -- Validation 3: Check maximum length
    IF v_name_length > p_max_name_length THEN
        p_validation_status := 'FAILED';
        p_error_message := 'Department name must not exceed ' || p_max_name_length::VARCHAR(10) || ' characters.';
        RETURN;
    END IF;
    
    -- Validation 4: Check for duplicate department name (case-insensitive)
    SELECT COUNT(*)
    INTO v_existing_count
    FROM public.departments
    WHERE LOWER(department_name) = LOWER(v_trimmed_name);
    
    IF v_existing_count > 0 THEN
        p_validation_status := 'FAILED';
        p_error_message := 'Department name already exists: ' || v_trimmed_name;
        RETURN;
    END IF;
    
    -- Validation 5: Validate manager_id if provided
    IF p_manager_id IS NOT NULL THEN
        -- Check if manager exists
        SELECT CASE WHEN COUNT(*) > 0 THEN TRUE ELSE FALSE END
        INTO v_manager_exists
        FROM public.employees
        WHERE employee_id = p_manager_id;
        
        IF v_manager_exists = FALSE THEN
            p_validation_status := 'FAILED';
            p_error_message := 'Invalid manager_id. Employee does not exist: ' || p_manager_id::VARCHAR(10);
            RETURN;
        END IF;
        
        -- Check if manager is active
        SELECT is_active
        INTO v_manager_active
        FROM public.employees
        WHERE employee_id = p_manager_id;
        
        IF v_manager_active = FALSE THEN
            p_validation_status := 'FAILED';
            p_error_message := 'Manager must be an active employee. Employee ID: ' || p_manager_id::VARCHAR(10);
            RETURN;
        END IF;
    END IF;
    
    -- Validation 6: Validate location if provided (basic check)
    IF p_location IS NOT NULL THEN
        p_location := LTRIM(RTRIM(p_location));
        
        IF p_location = '' THEN
            p_location := NULL; -- Treat empty string as NULL
        END IF;
    END IF;
    
    -- ========================================
    -- CREATION PHASE
    -- ========================================
    
    BEGIN
        -- Insert new department and get the new department ID
        INSERT INTO public.departments (
            department_name,
            location,
            manager_id,
            created_date,
            modified_date
        )
        VALUES (
            v_trimmed_name,
            p_location,
            p_manager_id,
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP
        )
        RETURNING department_id INTO p_new_department_id;
        
        -- Set success status
        p_validation_status := 'SUCCESS';
        p_error_message := NULL;
        
        COMMIT;
        
        -- Return result set (using RAISE NOTICE for informational output)
        -- Note: PostgreSQL procedures cannot return result sets directly
        -- This would need to be handled by a function or by the calling application
        RAISE NOTICE 'Department created successfully: ID=%, Name=%, Location=%, Manager=%', 
            p_new_department_id, v_trimmed_name, p_location, p_manager_id;
        
    EXCEPTION
        WHEN OTHERS THEN
            -- Rollback transaction on error (automatic in PostgreSQL)
            ROLLBACK;
            
            -- Capture error information
            p_validation_status := 'ERROR';
            p_error_message := SQLERRM;
            p_new_department_id := NULL;
            
            -- Get additional error details
            GET STACKED DIAGNOSTICS
                v_error_number = RETURNED_SQLSTATE;
            
            -- Log error information (using RAISE NOTICE)
            RAISE NOTICE 'Error occurred: SQLSTATE=%, Message=%', v_error_number, SQLERRM;
            
            RETURN;
    END;
    
END;
$$;

-- ============================================================================
-- CONVERSION NOTES:
-- ============================================================================
-- 1. Parameter names: Changed from @param to p_param (PostgreSQL convention)
-- 2. OUTPUT parameters: Changed to INOUT parameters with DEFAULT NULL
-- 3. Variable declarations: Changed from @var to v_var, BIT to BOOLEAN
-- 4. String concatenation: Changed from + to ||
-- 5. Type casting: Changed from CAST(x AS type) to x::type
-- 6. String functions: LTRIM, RTRIM work the same; LEN changed to LENGTH
-- 7. GETDATE(): Changed to CURRENT_TIMESTAMP
-- 8. SCOPE_IDENTITY(): Changed to RETURNING clause in INSERT
-- 9. Transaction management: BEGIN/COMMIT/ROLLBACK work in procedures
-- 10. Error handling: TRY-CATCH changed to BEGIN-EXCEPTION block
-- 11. ERROR_MESSAGE(): Changed to SQLERRM
-- 12. ERROR_NUMBER(): Changed to RETURNED_SQLSTATE (via GET STACKED DIAGNOSTICS)
-- 13. ERROR_SEVERITY(), ERROR_STATE(): Not directly available in PostgreSQL
-- 14. Result set return: PostgreSQL procedures cannot return result sets
--     Changed to RAISE NOTICE for informational output
--     Calling application should use OUTPUT parameters instead
-- 15. SET NOCOUNT ON: Not needed in PostgreSQL (no row count messages)
-- 16. Schema: Changed from dbo to public
-- 17. GO batch separator: Removed (not needed in PostgreSQL)
-- ============================================================================
