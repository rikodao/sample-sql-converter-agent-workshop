-- ============================================================================
-- Target: Aurora PostgreSQL (Native)
-- Object: public.usp_propagate_salary_raise
-- Type: STORED PROCEDURE
-- Converted from: T-SQL (SQL Server)
-- ============================================================================

CREATE OR REPLACE PROCEDURE public.usp_propagate_salary_raise(
    p_department_id INT DEFAULT NULL,
    p_raise_percentage NUMERIC(5,2) DEFAULT NULL,
    p_raise_amount NUMERIC(18,2) DEFAULT NULL,
    p_effective_date DATE DEFAULT NULL,
    p_reason VARCHAR(200) DEFAULT NULL,
    INOUT p_affected_count INT DEFAULT 0,
    INOUT p_total_increase NUMERIC(18,2) DEFAULT 0.00
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_error_message TEXT;
    v_max_raise_percentage NUMERIC(5,2) := 20.00;
    v_min_days_since_last_raise INT := 180; -- 6 months
    v_effective_date DATE;
    v_reason VARCHAR(200);
    v_table_exists BOOLEAN;
    v_row_count INT;
BEGIN
    -- Initialize output parameters
    p_affected_count := 0;
    p_total_increase := 0.00;
    
    -- Validate inputs
    IF p_raise_percentage IS NULL AND p_raise_amount IS NULL THEN
        RAISE EXCEPTION 'Either raise_percentage or raise_amount must be specified.';
    END IF;
    
    IF p_raise_percentage IS NOT NULL AND p_raise_amount IS NOT NULL THEN
        RAISE EXCEPTION 'Cannot specify both raise_percentage and raise_amount.';
    END IF;
    
    IF p_raise_percentage IS NOT NULL AND (p_raise_percentage <= 0 OR p_raise_percentage > v_max_raise_percentage) THEN
        RAISE EXCEPTION 'Raise percentage must be between 0 and 20.';
    END IF;
    
    IF p_raise_amount IS NOT NULL AND p_raise_amount <= 0 THEN
        RAISE EXCEPTION 'Raise amount must be greater than 0.';
    END IF;
    
    -- Default effective date to today if not provided
    v_effective_date := COALESCE(p_effective_date, CURRENT_DATE);
    
    -- Default reason if not provided
    v_reason := COALESCE(p_reason, 'Annual salary adjustment');
    
    -- Create temp table to hold raise calculations
    -- Note: In PostgreSQL procedures, temp tables persist within the session
    -- We use DROP TABLE IF EXISTS to ensure clean state
    DROP TABLE IF EXISTS raise_calc;
    
    CREATE TEMP TABLE raise_calc (
        employee_id INT,
        old_salary NUMERIC(18,2),
        new_salary NUMERIC(18,2),
        raise_amount NUMERIC(18,2),
        days_since_last_raise INT
    );
    
    -- Calculate raises for eligible employees
    INSERT INTO raise_calc (
        employee_id,
        old_salary,
        new_salary,
        raise_amount,
        days_since_last_raise
    )
    SELECT 
        e.employee_id,
        e.salary AS old_salary,
        CASE 
            WHEN p_raise_percentage IS NOT NULL THEN 
                e.salary * (1 + p_raise_percentage / 100.0)
            ELSE 
                e.salary + p_raise_amount
        END AS new_salary,
        CASE 
            WHEN p_raise_percentage IS NOT NULL THEN 
                e.salary * (p_raise_percentage / 100.0)
            ELSE 
                p_raise_amount
        END AS raise_amount,
        CURRENT_DATE - COALESCE(e.last_raise_date, e.hire_date) AS days_since_last_raise
    FROM public.employees e
    WHERE 
        -- Filter by department if provided
        (p_department_id IS NULL OR e.department_id = p_department_id)
        -- Only active employees
        AND COALESCE(e.is_active, true) = true
        -- Valid salary
        AND e.salary > 0
        -- Minimum time since last raise
        AND (CURRENT_DATE - COALESCE(e.last_raise_date, e.hire_date)) >= v_min_days_since_last_raise;
    
    -- Update employees table with new salaries
    UPDATE public.employees e
    SET 
        salary = rc.new_salary,
        last_raise_date = v_effective_date
    FROM raise_calc rc
    WHERE e.employee_id = rc.employee_id;
    
    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    
    -- Check if salary_history table exists
    SELECT EXISTS (
        SELECT 1 
        FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'salary_history'
    ) INTO v_table_exists;
    
    -- Insert audit records into salary_history (if table exists)
    IF v_table_exists THEN
        INSERT INTO public.salary_history (
            employee_id,
            old_salary,
            new_salary,
            change_date,
            reason
        )
        SELECT 
            rc.employee_id,
            rc.old_salary,
            rc.new_salary,
            v_effective_date,
            v_reason
        FROM raise_calc rc;
    END IF;
    
    -- Get count and total increase
    SELECT 
        COUNT(*)::INT,
        COALESCE(SUM(raise_amount), 0.00)
    INTO 
        p_affected_count,
        p_total_increase
    FROM raise_calc;
    
    -- Clean up temp table
    DROP TABLE IF EXISTS raise_calc;
    
    -- Return summary result set (using RAISE NOTICE for informational output)
    -- Note: PostgreSQL procedures cannot return result sets like SQL Server
    -- The summary information is available through OUTPUT parameters
    RAISE NOTICE 'Employees affected: %, Total salary increase: %, Effective date: %, Reason: %, Processed date: %',
        p_affected_count, p_total_increase, v_effective_date, v_reason, CURRENT_TIMESTAMP;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Capture error information
        GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
        
        -- Clean up temp table if it exists
        DROP TABLE IF EXISTS raise_calc;
        
        -- Re-raise the error with context
        RAISE EXCEPTION 'Error in usp_propagate_salary_raise: %', v_error_message;
END;
$$;

-- ============================================================================
-- CONVERSION NOTES:
-- ============================================================================
-- 1. OUTPUT parameters converted to INOUT parameters
--    - @affected_count -> p_affected_count (INOUT INT)
--    - @total_increase -> p_total_increase (INOUT NUMERIC(18,2))
--
-- 2. SET NOCOUNT ON removed (not needed in PostgreSQL)
--
-- 3. Transaction management:
--    - BEGIN TRANSACTION/COMMIT removed
--    - PostgreSQL procedures run in implicit transaction
--    - Automatic rollback on exception
--    - @@TRANCOUNT check removed (not needed)
--
-- 4. Error handling:
--    - TRY-CATCH converted to EXCEPTION block
--    - RAISERROR converted to RAISE EXCEPTION
--    - ERROR_MESSAGE() -> GET STACKED DIAGNOSTICS MESSAGE_TEXT
--    - ERROR_SEVERITY() and ERROR_STATE() not directly available in PostgreSQL
--
-- 5. Temporary table:
--    - #raise_calc converted to TEMP TABLE raise_calc
--    - Removed ON COMMIT DROP (explicit DROP in cleanup)
--    - Added DROP TABLE IF EXISTS at start for clean state
--
-- 6. Date/Time functions:
--    - GETDATE() -> CURRENT_DATE (for date) / CURRENT_TIMESTAMP (for timestamp)
--    - DATEDIFF(DAY, a, b) -> (b::date - a::date)
--    - CAST(GETDATE() AS DATE) -> CURRENT_DATE
--
-- 7. NULL handling:
--    - ISNULL(a, b) -> COALESCE(a, b)
--
-- 8. Object existence check:
--    - OBJECT_ID('dbo.salary_history', 'U') IS NOT NULL
--      -> EXISTS (SELECT 1 FROM information_schema.tables WHERE ...)
--
-- 9. UPDATE FROM syntax:
--    - T-SQL: UPDATE e SET ... FROM employees e INNER JOIN #raise_calc rc ON ...
--    - PostgreSQL: UPDATE employees e SET ... FROM raise_calc rc WHERE e.id = rc.id
--
-- 10. Row count:
--     - @@ROWCOUNT not used in original, but available via GET DIAGNOSTICS
--
-- 11. Result set:
--     - Final SELECT statement converted to RAISE NOTICE
--     - PostgreSQL procedures cannot return result sets
--     - Use OUTPUT parameters (p_affected_count, p_total_increase) instead
--     - Alternative: Convert to FUNCTION RETURNS TABLE if result set is required
--
-- 12. Data types:
--     - NVARCHAR(n) -> VARCHAR(n) (PostgreSQL uses UTF-8 by default)
--     - DECIMAL(p,s) -> NUMERIC(p,s) (same in PostgreSQL)
--     - INT -> INT (same)
--     - DATE -> DATE (same)
--
-- 13. Boolean values:
--     - T-SQL: ISNULL(e.is_active, 1) = 1
--     - PostgreSQL: COALESCE(e.is_active, true) = true
--
-- 14. Schema names:
--     - dbo -> public (default schema in PostgreSQL)
--
-- 15. Variable naming:
--     - T-SQL: @variable
--     - PostgreSQL: v_variable (for local vars), p_variable (for parameters)
--
-- ============================================================================
-- USAGE EXAMPLE:
-- ============================================================================
-- DECLARE
--     v_affected INT := 0;
--     v_total NUMERIC(18,2) := 0.00;
-- BEGIN
--     CALL public.usp_propagate_salary_raise(
--         p_department_id := 10,
--         p_raise_percentage := 5.00,
--         p_raise_amount := NULL,
--         p_effective_date := '2024-01-01',
--         p_reason := 'Annual raise 2024',
--         p_affected_count := v_affected,
--         p_total_increase := v_total
--     );
--     RAISE NOTICE 'Result: % employees, $ % total', v_affected, v_total;
-- END;
-- ============================================================================
