CREATE PROCEDURE dbo.usp_dept_headcount_pivot
AS
BEGIN
    SET NOCOUNT ON;
    SELECT *
    FROM (
        SELECT
            d.name AS department_name,
            CASE WHEN e.is_active = 1 THEN 'Active' ELSE 'Inactive' END AS status,
            e.employee_id
        FROM dbo.departments d
        LEFT JOIN dbo.employees e ON d.department_id = e.department_id
    ) src
    PIVOT (
        COUNT(employee_id) FOR status IN ([Active], [Inactive])
    ) p
    ORDER BY department_name;
END
