-- =============================================
-- Object: public.usp_employee_json
-- Type: STORED PROCEDURE (PL/pgSQL)
-- Description: Retrieves employee information as JSON via INOUT parameter
-- Converted from T-SQL to PL/pgSQL for Aurora PostgreSQL
-- =============================================

CREATE OR REPLACE PROCEDURE public.usp_employee_json(
    p_employee_id INT,
    INOUT p_json_out TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Build JSON output using PostgreSQL's json_build_object
    -- This is equivalent to T-SQL's FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    SELECT json_build_object(
        'employee_id', e.employee_id,
        'first_name', e.first_name,
        'last_name', e.last_name,
        'email', e.email,
        'department_name', d.name,
        'hire_date', e.hire_date
    )::text
    INTO p_json_out
    FROM public.employees e
    INNER JOIN public.departments d ON e.department_id = d.department_id
    WHERE e.employee_id = p_employee_id;
    
    -- If no record found, p_json_out will be NULL (same behavior as T-SQL)
END;
$$;

-- =============================================
-- CONVERSION NOTES:
-- =============================================
-- 1. @employee_id → p_employee_id (parameter naming convention)
-- 2. @json_out NVARCHAR(MAX) OUTPUT → INOUT p_json_out TEXT
-- 3. SET NOCOUNT ON → Not needed in PostgreSQL (no row count messages)
-- 4. FOR JSON PATH, WITHOUT_ARRAY_WRAPPER → json_build_object()
--    - WITHOUT_ARRAY_WRAPPER means single object, not array
--    - json_build_object creates a single JSON object
-- 5. dbo schema → public schema
-- 6. SELECT ... INTO variable syntax is the same in PL/pgSQL
-- 7. INNER JOIN syntax is identical
-- 8. Cast to ::text for TEXT output (json type would also work)
-- 9. All fields from original T-SQL version preserved: employee_id, first_name, last_name, email, department_name, hire_date
--
-- USAGE EXAMPLE:
-- DO $$
-- DECLARE
--     v_json_result TEXT;
-- BEGIN
--     CALL public.usp_employee_json(1, v_json_result);
--     RAISE NOTICE 'JSON Result: %', v_json_result;
-- END $$;
--
-- ALTERNATIVE: Return as result set (more PostgreSQL-idiomatic)
-- If the calling application can be modified, consider:
-- CREATE OR REPLACE FUNCTION public.fn_employee_json(p_employee_id INT)
-- RETURNS TABLE(json_output TEXT) AS $$
-- BEGIN
--     RETURN QUERY
--     SELECT json_build_object(...)::text FROM ...;
-- END $$ LANGUAGE plpgsql;
