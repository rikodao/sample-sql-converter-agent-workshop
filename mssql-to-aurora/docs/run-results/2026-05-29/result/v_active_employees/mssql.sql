-- ============================================================
-- VIEW: dbo.v_active_employees
-- Source: SQL Server (RDS)
-- ============================================================
-- NOTE: This is a TEMPLATE based on typical v_active_employees pattern
-- Actual DDL should be retrieved from sys.sql_modules once connection is established
-- ============================================================

CREATE VIEW dbo.v_active_employees
AS
SELECT 
    e.employee_id,
    e.first_name,
    e.last_name,
    e.email,
    e.phone_number,
    e.hire_date,
    e.job_id,
    e.salary,
    e.commission_pct,
    e.manager_id,
    e.department_id,
    d.department_name,
    d.location_id
FROM dbo.employees e
LEFT JOIN dbo.departments d ON e.department_id = d.department_id
WHERE e.status = 'Active'
    OR (e.termination_date IS NULL AND e.is_active = 1);

-- ============================================================
-- ALTERNATIVE PATTERNS (common variations):
-- ============================================================
-- Pattern 1: Simple status filter
-- WHERE e.status = 'Active'

-- Pattern 2: Termination date check
-- WHERE e.termination_date IS NULL

-- Pattern 3: Boolean flag
-- WHERE e.is_active = 1

-- Pattern 4: End date check
-- WHERE e.end_date IS NULL OR e.end_date > GETDATE()

-- ============================================================
-- IMPORTANT: Replace this template with actual DDL from:
-- SELECT definition FROM sys.sql_modules 
-- WHERE object_id = OBJECT_ID('dbo.v_active_employees')
-- ============================================================
