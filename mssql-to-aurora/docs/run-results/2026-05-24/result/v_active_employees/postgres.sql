-- ============================================================================
-- PostgreSQL Native Conversion - VIEW v_active_employees
-- Converted from T-SQL to PL/pgSQL compatible syntax
-- ============================================================================

CREATE OR REPLACE VIEW public.v_active_employees AS
SELECT
    e.employee_id,
    public.fn_format_employee_name(e.first_name, e.last_name) AS full_name,
    d.name AS department_name,
    e.hire_date,
    s.base_salary,
    EXTRACT(year FROM age(CURRENT_TIMESTAMP, e.hire_date))::INT AS years_of_service
FROM public.employees e
INNER JOIN public.departments d ON e.department_id = d.department_id
LEFT JOIN LATERAL (
    SELECT base_salary
    FROM public.salaries
    WHERE employee_id = e.employee_id
    ORDER BY effective_from DESC
    LIMIT 1
) s ON true
WHERE e.is_active = true;

-- ============================================================================
-- Conversion Notes:
-- ============================================================================
-- 1. Schema: dbo → public
-- 2. OUTER APPLY → LEFT JOIN LATERAL ... ON true
-- 3. TOP 1 → LIMIT 1
-- 4. DATEDIFF(yy, hire_date, GETDATE()) → EXTRACT(year FROM age(CURRENT_TIMESTAMP, hire_date))::INT
-- 5. GETDATE() → CURRENT_TIMESTAMP
-- 6. d.name remains as d.name (column exists in PostgreSQL native environment)
-- 7. is_active = 1 → is_active = true (BIT → boolean)
-- 8. Function call: dbo.fn_format_employee_name → public.fn_format_employee_name
-- ============================================================================
