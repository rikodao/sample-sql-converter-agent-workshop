-- ============================================================================
-- Target: Aurora PostgreSQL (Native)
-- Object: public.fn_get_fiscal_year
-- Type: SCALAR FUNCTION
-- Converted from: T-SQL (SQL Server)
-- ============================================================================
-- Description: Calculates fiscal year based on input date
--              Fiscal year starts in April (month 4)
--              If month >= April, fiscal year = calendar year
--              Otherwise, fiscal year = calendar year - 1
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_get_fiscal_year(
    p_input_date DATE
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_fiscal_year INT;
    v_fiscal_start_month INT := 4; -- April start (common for many organizations)
BEGIN
    -- If month is >= fiscal start month, fiscal year = calendar year
    -- Otherwise, fiscal year = calendar year - 1
    IF EXTRACT(MONTH FROM p_input_date) >= v_fiscal_start_month THEN
        v_fiscal_year := EXTRACT(YEAR FROM p_input_date)::INT;
    ELSE
        v_fiscal_year := EXTRACT(YEAR FROM p_input_date)::INT - 1;
    END IF;
    
    RETURN v_fiscal_year;
END;
$$;

-- ============================================================================
-- Conversion Notes:
-- ============================================================================
-- 1. Changed schema from 'dbo' to 'public' (PostgreSQL default)
-- 2. Parameter renamed: @input_date → p_input_date (removed @, added p_ prefix)
-- 3. Variables renamed: @fiscal_year → v_fiscal_year, @fiscal_start_month → v_fiscal_start_month
-- 4. Variable initialization: = → := (PostgreSQL syntax)
-- 5. MONTH() function → EXTRACT(MONTH FROM ...) (PostgreSQL standard)
-- 6. YEAR() function → EXTRACT(YEAR FROM ...) (PostgreSQL standard)
-- 7. IF-ELSE-SET → IF-THEN-ELSE-END IF with := assignment
-- 8. Added explicit ::INT cast for EXTRACT results (returns numeric)
-- 9. Function delimiter: AS BEGIN...END → AS $$ BEGIN...END $$
-- 10. Added LANGUAGE plpgsql clause
-- 11. NULL handling: PostgreSQL handles NULL input same as T-SQL (returns NULL)
-- ============================================================================
