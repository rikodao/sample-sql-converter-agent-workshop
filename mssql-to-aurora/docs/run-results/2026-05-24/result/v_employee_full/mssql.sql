-- ============================================
-- VIEW: dbo.v_employee_full
-- Description: Full employee information with department details
-- Dependencies: dbo.employees, dbo.departments
-- ============================================

CREATE VIEW dbo.v_employee_full AS
SELECT
    e.employee_id,
    e.first_name,
    e.last_name,
    e.email,
    e.is_active,
    d.department_id,
    d.name AS department_name
FROM dbo.employees e
INNER JOIN dbo.departments d ON e.department_id = d.department_id;
