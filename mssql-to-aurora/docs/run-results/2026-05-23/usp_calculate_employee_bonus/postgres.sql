-- ================================================================================
-- Target: Aurora PostgreSQL (Native)
-- Object: usp_calculate_employee_bonus
-- Type: STORED PROCEDURE
-- Converted from: T-SQL (SQL Server)
-- ================================================================================

CREATE OR REPLACE PROCEDURE public.usp_calculate_employee_bonus(
    IN p_employee_id INT,
    IN p_fiscal_year INT,
    INOUT p_bonus NUMERIC(19,4)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_base NUMERIC(19,4);
    v_years INT;
    v_hire_date DATE;
    v_fiscal_end DATE;
BEGIN
    -- Input validation: fiscal_year must be positive to match SQL Server behavior
    IF p_fiscal_year < 1 OR p_fiscal_year > 9999 THEN
        RAISE EXCEPTION 'Cannot construct data type date, some of the arguments have values which are not valid.';
    END IF;

    -- Get the latest base salary for the employee
    SELECT base_salary INTO v_base
    FROM public.salaries
    WHERE employee_id = p_employee_id
    ORDER BY effective_from DESC
    LIMIT 1;

    -- If no salary record found, set bonus to 0 and return
    IF v_base IS NULL THEN
        p_bonus := 0;
        RETURN;
    END IF;

    -- Calculate years of service
    -- DATEFROMPARTS(@fiscal_year, 12, 31) -> make_date(p_fiscal_year, 12, 31)
    v_fiscal_end := make_date(p_fiscal_year, 12, 31);
    
    SELECT hire_date INTO v_hire_date
    FROM public.employees
    WHERE employee_id = p_employee_id;

    -- DATEDIFF(yy, hire_date, fiscal_end) -> extract year difference
    -- PostgreSQL: extract(year from age(end, start)) gives year difference
    v_years := extract(year from age(v_fiscal_end, v_hire_date));

    -- Calculate bonus: base * 10% * (1 + years * 5%)
    -- ISNULL(@years, 0) -> COALESCE(v_years, 0)
    p_bonus := v_base * 0.10 * (1 + COALESCE(v_years, 0) * 0.05);

    -- UPSERT: INSERT ... ON CONFLICT DO UPDATE
    INSERT INTO public.bonuses(employee_id, fiscal_year, bonus_amount)
    VALUES(p_employee_id, p_fiscal_year, p_bonus)
    ON CONFLICT (employee_id, fiscal_year)
    DO UPDATE SET bonus_amount = EXCLUDED.bonus_amount;

END;
$$;
