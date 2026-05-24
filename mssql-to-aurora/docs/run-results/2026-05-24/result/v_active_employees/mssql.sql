CREATE VIEW dbo.v_active_employees AS
SELECT
    e.employee_id,
    dbo.fn_format_employee_name(e.first_name, e.last_name) AS full_name,
    d.name AS department_name,
    e.hire_date,
    s.base_salary,
    DATEDIFF(yy, e.hire_date, GETDATE()) AS years_of_service
FROM dbo.employees e
INNER JOIN dbo.departments d ON e.department_id = d.department_id
OUTER APPLY (
    SELECT TOP 1 base_salary
    FROM dbo.salaries
    WHERE employee_id = e.employee_id
    ORDER BY effective_from DESC
) s
WHERE e.is_active = 1;
