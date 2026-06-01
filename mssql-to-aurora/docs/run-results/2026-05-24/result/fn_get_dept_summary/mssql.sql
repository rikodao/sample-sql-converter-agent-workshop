CREATE FUNCTION dbo.fn_get_dept_summary(@as_of DATE)
RETURNS @summary TABLE (
    department_id INT,
    department_name NVARCHAR(100),
    headcount INT,
    avg_salary MONEY,
    total_payroll MONEY
)
AS
BEGIN
    INSERT INTO @summary(department_id, department_name, headcount, avg_salary, total_payroll)
    SELECT
        d.department_id,
        d.name,
        COUNT(DISTINCT e.employee_id) AS headcount,
        AVG(s.base_salary) AS avg_salary,
        SUM(s.base_salary) AS total_payroll
    FROM dbo.departments d
    LEFT JOIN dbo.employees e ON d.department_id = e.department_id AND e.is_active = 1
    OUTER APPLY (
        SELECT TOP 1 base_salary
        FROM dbo.salaries
        WHERE employee_id = e.employee_id
          AND effective_from <= @as_of
          AND (effective_to IS NULL OR effective_to >= @as_of)
        ORDER BY effective_from DESC
    ) s
    GROUP BY d.department_id, d.name;
    RETURN;
END
