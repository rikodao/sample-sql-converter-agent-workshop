-- ============================================================================
-- Target: Aurora PostgreSQL (Native)
-- Object: public.usp_calculate_employee_bonus
-- Type: STORED PROCEDURE
-- Converted from: T-SQL (SQL Server)
-- ============================================================================
-- Conversion Notes:
-- - OUTPUT parameters converted to INOUT
-- - Temp table syntax adjusted to PostgreSQL (ON COMMIT DROP)
-- - TRY-CATCH converted to EXCEPTION block
-- - RAISERROR converted to RAISE EXCEPTION
-- - GETDATE() converted to now()
-- - DATEDIFF(DAY, ...) converted to date subtraction
-- - ISNULL() converted to COALESCE()
-- - @@TRANCOUNT handling removed (implicit in PROCEDURE)
-- - ERROR_MESSAGE() converted to SQLERRM
-- - UPDATE FROM JOIN syntax adjusted to PostgreSQL style
-- - Result set (SELECT) converted to RAISE NOTICE (PG procedures can't return result sets)
-- - Transaction management is implicit in PostgreSQL procedures
-- ============================================================================

CREATE OR REPLACE PROCEDURE public.usp_calculate_employee_bonus(
    p_employee_id INT DEFAULT NULL,
    p_fiscal_year INT DEFAULT NULL,
    INOUT p_calculated_count INT DEFAULT 0,
    INOUT p_total_bonus_amount NUMERIC(18,2) DEFAULT 0.00
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_error_message TEXT;
    v_min_employment_days INT := 180; -- 6 months minimum
    v_fiscal_year INT;
BEGIN
    -- Initialize output parameters
    p_calculated_count := 0;
    p_total_bonus_amount := 0.00;
    
    -- Default fiscal year to current year if not provided
    IF p_fiscal_year IS NULL THEN
        v_fiscal_year := EXTRACT(YEAR FROM now())::INT;
    ELSE
        v_fiscal_year := p_fiscal_year;
    END IF;
    
    -- Validate fiscal year
    IF v_fiscal_year < 2000 OR v_fiscal_year > EXTRACT(YEAR FROM now())::INT + 1 THEN
        RAISE EXCEPTION 'Invalid fiscal year. Must be between 2000 and next year.';
    END IF;
    
    -- Create temp table to hold bonus calculations
    -- Note: ON COMMIT DROP ensures cleanup even if procedure exits early
    CREATE TEMP TABLE IF NOT EXISTS bonus_calc (
        employee_id INT,
        salary NUMERIC(18,2),
        performance_rating INT,
        employment_days INT,
        bonus_percentage NUMERIC(5,2),
        bonus_amount NUMERIC(18,2)
    ) ON COMMIT DROP;
    
    -- Clear temp table in case it exists from previous call in same transaction
    DELETE FROM bonus_calc;
    
    -- Calculate bonuses for eligible employees
    INSERT INTO bonus_calc (
        employee_id,
        salary,
        performance_rating,
        employment_days,
        bonus_percentage,
        bonus_amount
    )
    SELECT 
        e.employee_id,
        e.salary,
        COALESCE(e.performance_rating, 0) AS performance_rating,
        (CURRENT_DATE - e.hire_date::date) AS employment_days,
        CASE 
            WHEN COALESCE(e.performance_rating, 0) = 5 THEN 15.00
            WHEN COALESCE(e.performance_rating, 0) = 4 THEN 10.00
            WHEN COALESCE(e.performance_rating, 0) = 3 THEN 5.00
            WHEN COALESCE(e.performance_rating, 0) = 2 THEN 2.00
            ELSE 0.00
        END AS bonus_percentage,
        CASE 
            WHEN COALESCE(e.performance_rating, 0) = 5 THEN e.salary * 0.15
            WHEN COALESCE(e.performance_rating, 0) = 4 THEN e.salary * 0.10
            WHEN COALESCE(e.performance_rating, 0) = 3 THEN e.salary * 0.05
            WHEN COALESCE(e.performance_rating, 0) = 2 THEN e.salary * 0.02
            ELSE 0.00
        END AS bonus_amount
    FROM public.employees e
    WHERE 
        -- Filter by employee_id if provided
        (p_employee_id IS NULL OR e.employee_id = p_employee_id)
        -- Only active employees (handle both boolean and integer representations)
        AND COALESCE(e.is_active::boolean, true) = true
        -- Minimum employment period
        AND (CURRENT_DATE - e.hire_date::date) >= v_min_employment_days
        -- Valid salary
        AND e.salary > 0;
    
    -- Update employees table with calculated bonuses
    UPDATE public.employees e
    SET 
        bonus_amount = bc.bonus_amount,
        last_bonus_date = CURRENT_TIMESTAMP,
        bonus_fiscal_year = v_fiscal_year
    FROM bonus_calc bc
    WHERE e.employee_id = bc.employee_id;
    
    -- Get count and total
    SELECT 
        COUNT(*)::INT,
        COALESCE(SUM(bonus_amount), 0.00)
    INTO 
        p_calculated_count,
        p_total_bonus_amount
    FROM bonus_calc;
    
    -- Log summary (PostgreSQL procedures cannot return result sets like T-SQL)
    -- Clients should check the INOUT parameters for results
    RAISE NOTICE 'Bonus calculation completed - Employees: %, Total: $%, Fiscal Year: %, Date: %',
        p_calculated_count, 
        p_total_bonus_amount, 
        v_fiscal_year, 
        CURRENT_TIMESTAMP;
    
    -- Temp table will be automatically dropped on commit (ON COMMIT DROP)
    
EXCEPTION
    WHEN OTHERS THEN
        -- Capture error information
        v_error_message := SQLERRM;
        
        -- Log error details
        RAISE NOTICE 'Error in usp_calculate_employee_bonus: %', v_error_message;
        
        -- Re-raise the error to caller
        RAISE;
END;
$$;

-- ============================================================================
-- Grant permissions (adjust as needed for your security model)
-- ============================================================================
-- GRANT EXECUTE ON PROCEDURE public.usp_calculate_employee_bonus TO your_role;

-- ============================================================================
-- Usage Examples:
-- ============================================================================
-- Example 1: Calculate bonus for specific employee
-- DO $$
-- DECLARE
--     v_count INT := 0;
--     v_total NUMERIC(18,2) := 0.00;
-- BEGIN
--     CALL public.usp_calculate_employee_bonus(
--         p_employee_id := 1001,
--         p_fiscal_year := 2024,
--         p_calculated_count := v_count,
--         p_total_bonus_amount := v_total
--     );
--     RAISE NOTICE 'Result: Count=%, Total=%', v_count, v_total;
-- END $$;
--
-- Example 2: Calculate bonuses for all eligible employees
-- DO $$
-- DECLARE
--     v_count INT := 0;
--     v_total NUMERIC(18,2) := 0.00;
-- BEGIN
--     CALL public.usp_calculate_employee_bonus(
--         p_employee_id := NULL,
--         p_fiscal_year := 2024,
--         p_calculated_count := v_count,
--         p_total_bonus_amount := v_total
--     );
--     RAISE NOTICE 'Result: Count=%, Total=%', v_count, v_total;
-- END $$;
--
-- Example 3: Use default fiscal year (current year)
-- DO $$
-- DECLARE
--     v_count INT := 0;
--     v_total NUMERIC(18,2) := 0.00;
-- BEGIN
--     CALL public.usp_calculate_employee_bonus(
--         p_employee_id := NULL,
--         p_fiscal_year := NULL,
--         p_calculated_count := v_count,
--         p_total_bonus_amount := v_total
--     );
--     RAISE NOTICE 'Result: Count=%, Total=%', v_count, v_total;
-- END $$;
-- ============================================================================

-- ============================================================================
-- Key Differences from T-SQL Version:
-- ============================================================================
-- 1. INOUT parameters instead of OUTPUT (PostgreSQL syntax)
-- 2. No explicit BEGIN TRANSACTION / COMMIT (implicit in procedures)
-- 3. Temp table uses ON COMMIT DROP for automatic cleanup
-- 4. CURRENT_DATE and CURRENT_TIMESTAMP instead of GETDATE()
-- 5. Date arithmetic uses native date subtraction
-- 6. EXCEPTION block instead of TRY-CATCH
-- 7. RAISE EXCEPTION instead of RAISERROR
-- 8. RAISE NOTICE for logging instead of PRINT
-- 9. No result set return (use INOUT parameters instead)
-- 10. SQLERRM instead of ERROR_MESSAGE()
-- ============================================================================
