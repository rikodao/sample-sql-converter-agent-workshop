-- ============================================================================
-- Object: public.usp_dept_with_cumulative_metrics
-- Type: FUNCTION (PostgreSQL PL/pgSQL)
-- Description: Calculate cumulative metrics by department over time
-- ============================================================================
-- Converted from T-SQL PROCEDURE to PL/pgSQL FUNCTION
-- Note: T-SQL procedures can return result sets directly, but PostgreSQL
--       requires FUNCTION with RETURNS TABLE for this pattern
-- ============================================================================

CREATE OR REPLACE FUNCTION public.usp_dept_with_cumulative_metrics(
    p_start_date TIMESTAMP DEFAULT NULL,
    p_end_date TIMESTAMP DEFAULT NULL,
    p_department_id INT DEFAULT NULL
)
RETURNS TABLE (
    department_id INT,
    department_name VARCHAR,
    location VARCHAR,
    hire_date TIMESTAMP,
    employee_id INT,
    employee_name VARCHAR,
    salary NUMERIC,
    cumulative_employee_count BIGINT,
    cumulative_salary_total NUMERIC,
    cumulative_salary_avg DECIMAL(10,2),
    hire_date_rank BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_start_date TIMESTAMP;
    v_end_date TIMESTAMP;
BEGIN
    -- Default date range to last 12 months if not specified
    IF p_start_date IS NULL THEN
        v_start_date := now() - interval '1 year';
    ELSE
        v_start_date := p_start_date;
    END IF;
    
    IF p_end_date IS NULL THEN
        v_end_date := now();
    ELSE
        v_end_date := p_end_date;
    END IF;
    
    -- Validate date range
    IF v_start_date > v_end_date THEN
        RAISE EXCEPTION 'Start date cannot be after end date';
    END IF;
    
    -- Main query with cumulative metrics
    RETURN QUERY
    WITH EmployeeHires AS (
        SELECT 
            e.employee_id,
            e.first_name,
            e.last_name,
            e.hire_date,
            e.salary,
            e.department_id,
            d.department_name,
            d.location
        FROM public.employees e
        INNER JOIN public.departments d ON e.department_id = d.department_id
        WHERE e.hire_date BETWEEN v_start_date AND v_end_date
          AND (p_department_id IS NULL OR e.department_id = p_department_id)
          AND e.status = 'Active'
    ),
    CumulativeMetrics AS (
        SELECT 
            eh.department_id,
            eh.department_name,
            eh.location,
            eh.hire_date,
            eh.employee_id,
            eh.first_name,
            eh.last_name,
            eh.salary,
            -- Cumulative count of employees hired
            ROW_NUMBER() OVER (
                PARTITION BY eh.department_id 
                ORDER BY eh.hire_date, eh.employee_id
            ) AS cumulative_employee_count,
            -- Running total of salaries
            SUM(eh.salary) OVER (
                PARTITION BY eh.department_id 
                ORDER BY eh.hire_date, eh.employee_id
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) AS cumulative_salary_total,
            -- Running average of salaries
            AVG(eh.salary) OVER (
                PARTITION BY eh.department_id 
                ORDER BY eh.hire_date, eh.employee_id
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) AS cumulative_salary_avg,
            -- Department rank by hire date
            DENSE_RANK() OVER (
                ORDER BY eh.hire_date
            ) AS hire_date_rank
        FROM EmployeeHires eh
    )
    SELECT 
        cm.department_id,
        cm.department_name,
        cm.location,
        cm.hire_date,
        cm.employee_id,
        cm.first_name || ' ' || cm.last_name AS employee_name,
        cm.salary,
        cm.cumulative_employee_count,
        cm.cumulative_salary_total,
        CAST(cm.cumulative_salary_avg AS DECIMAL(10,2)) AS cumulative_salary_avg,
        cm.hire_date_rank
    FROM CumulativeMetrics cm
    ORDER BY 
        cm.department_id,
        cm.hire_date,
        cm.employee_id;
END;
$$;

-- Add comment for documentation
COMMENT ON FUNCTION public.usp_dept_with_cumulative_metrics IS 
'Calculate cumulative metrics by department over time. Converted from T-SQL PROCEDURE to PL/pgSQL FUNCTION to support result set returns.';
