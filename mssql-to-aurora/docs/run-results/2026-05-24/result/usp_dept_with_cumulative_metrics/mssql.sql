-- =============================================
-- Object: dbo.usp_dept_with_cumulative_metrics
-- Type: STORED PROCEDURE
-- Source: SQL Server
-- =============================================

CREATE PROCEDURE dbo.usp_dept_with_cumulative_metrics
AS
BEGIN
    SET NOCOUNT ON;

    WITH
    dept_tree (department_id, name, parent_id, depth) AS (
        SELECT department_id, name, parent_id, 0
        FROM dbo.departments WHERE parent_id IS NULL
        UNION ALL
        SELECT d.department_id, d.name, d.parent_id, t.depth + 1
        FROM dbo.departments d
        INNER JOIN dept_tree t ON d.parent_id = t.department_id
    ),
    dept_employees AS (
        SELECT department_id, COUNT(*) AS cnt
        FROM dbo.employees WHERE is_active = 1
        GROUP BY department_id
    ),
    dept_payroll AS (
        SELECT e.department_id,
               SUM(s.base_salary) AS total_salary
        FROM dbo.employees e
        OUTER APPLY (
            SELECT TOP 1 base_salary FROM dbo.salaries
            WHERE employee_id = e.employee_id ORDER BY effective_from DESC
        ) s
        WHERE e.is_active = 1
        GROUP BY e.department_id
    )
    SELECT
        t.depth,
        t.name AS department_name,
        ISNULL(de.cnt, 0) AS active_headcount,
        ISNULL(dp.total_salary, 0) AS total_salary
    FROM dept_tree t
    LEFT JOIN dept_employees de ON t.department_id = de.department_id
    LEFT JOIN dept_payroll  dp ON t.department_id = dp.department_id
    ORDER BY t.depth, t.name;
END
