-- ============================================================================
-- Object: dbo.fn_get_dept_summary
-- Type: TABLE-VALUED FUNCTION
-- Description: Returns summary statistics for departments including employee counts and salary metrics
-- ============================================================================
-- NOTE: This is a REPRESENTATIVE IMPLEMENTATION based on common patterns
--       Actual implementation should be verified against source database
-- ============================================================================

CREATE FUNCTION dbo.fn_get_dept_summary
(
    @department_id INT = NULL
)
RETURNS TABLE
AS
RETURN
(
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
    FROM dbo.departments d
    LEFT JOIN dbo.employees e ON d.department_id = e.department_id
    WHERE @department_id IS NULL OR d.department_id = @department_id
    GROUP BY d.department_id, d.department_name, d.location
);
GO
