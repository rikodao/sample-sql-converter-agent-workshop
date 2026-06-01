-- ============================================================
-- VIEW: dbo.v_employee_full
-- Source: SQL Server (RDS)
-- ============================================================
-- NOTE: This DDL is INFERRED from related objects due to connection issue
-- Actual DDL should be retrieved from sys.sql_modules once connection is established
-- ============================================================
-- Inference based on:
-- 1. trg_v_employee_full_update test cases (shows columns used in UPDATE)
-- 2. Related table structures (employees, departments)
-- 3. Common patterns for employee-department views
-- ============================================================

CREATE VIEW dbo.v_employee_full
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
    e.status,
    e.termination_date,
    e.is_active,
    e.performance_rating,
    e.bonus_amount,
    e.last_bonus_date,
    e.bonus_fiscal_year,
    d.department_name,
    d.location,
    d.manager_id AS dept_manager_id
FROM dbo.employees e
LEFT JOIN dbo.departments d ON e.department_id = d.department_id;

-- ============================================================
-- COLUMN MAPPING:
-- ============================================================
-- From employees table:
--   - employee_id (PK)
--   - first_name, last_name, email, phone_number
--   - hire_date, job_id, salary, commission_pct
--   - manager_id, department_id (FK to departments)
--   - status, termination_date, is_active
--   - performance_rating, bonus_amount, last_bonus_date, bonus_fiscal_year
--
-- From departments table:
--   - department_name
--   - location
--   - manager_id (aliased as dept_manager_id to avoid conflict)
--
-- JOIN TYPE: LEFT JOIN
--   - Ensures all employees are shown even if department_id is NULL
--   - department_name and location will be NULL for unassigned employees
-- ============================================================

-- ============================================================
-- USAGE:
-- ============================================================
-- This view is used by:
-- 1. trg_v_employee_full_update (INSTEAD OF UPDATE trigger)
--    - Allows updates through the view
--    - Decomposes updates to underlying employees table
--
-- 2. Application queries requiring full employee information
--    - Combines employee and department data in single query
--    - Simplifies client-side code
-- ============================================================

-- ============================================================
-- IMPORTANT: Replace this inferred DDL with actual DDL from:
-- SELECT definition FROM sys.sql_modules 
-- WHERE object_id = OBJECT_ID('dbo.v_employee_full')
-- ============================================================
