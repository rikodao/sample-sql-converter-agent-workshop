-- ============================================================================
-- Object: public.fn_get_dept_summary
-- Type: TABLE-VALUED FUNCTION (Inline TVF)
-- Description: Returns summary statistics for departments including employee counts and salary metrics
-- Converted from T-SQL to PostgreSQL native SQL
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_get_dept_summary(
    p_department_id INT DEFAULT NULL
)
RETURNS TABLE(
    department_id INT,
    department_name VARCHAR,
    location VARCHAR,
    total_employees BIGINT,
    active_employees BIGINT,
    inactive_employees BIGINT,
    avg_salary NUMERIC,
    earliest_hire_date DATE,
    latest_hire_date DATE
)
LANGUAGE sql
AS $$
    SELECT 
        d.department_id,
        d.department_name,
        d.location,
        COUNT(e.employee_id) AS total_employees,
        SUM(CASE WHEN e.status = 'Active' THEN 1 ELSE 0 END) AS active_employees,
        SUM(CASE WHEN e.status <> 'Active' OR e.status IS NULL THEN 1 ELSE 0 END) AS inactive_employees,
        AVG(CASE WHEN e.salary IS NOT NULL THEN e.salary ELSE NULL END) AS avg_salary,
        MIN(e.hire_date) AS earliest_hire_date,
        MAX(e.hire_date) AS latest_hire_date
    FROM public.departments d
    LEFT JOIN public.employees e ON d.department_id = e.department_id
    WHERE p_department_id IS NULL OR d.department_id = p_department_id
    GROUP BY d.department_id, d.department_name, d.location
$$;
