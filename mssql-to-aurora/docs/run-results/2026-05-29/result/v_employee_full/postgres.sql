-- ============================================================
-- VIEW: public.v_employee_full
-- Target: Aurora PostgreSQL (Native)
-- Converted from: SQL Server VIEW dbo.v_employee_full
-- ============================================================
-- CONVERSION NOTES:
-- 1. Schema: dbo → public
-- 2. Syntax: Standard SQL-92 VIEW syntax (no changes needed)
-- 3. LEFT JOIN: Fully compatible with PostgreSQL
-- 4. Column aliasing: dept_manager_id - no changes needed
-- 5. No T-SQL specific features used in original VIEW
-- ============================================================

CREATE OR REPLACE VIEW public.v_employee_full
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
FROM public.employees e
LEFT JOIN public.departments d ON e.department_id = d.department_id;

-- ============================================================
-- COLUMN MAPPING (unchanged from T-SQL):
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
-- POSTGRESQL COMPATIBILITY:
-- ============================================================
-- ✓ Standard SQL-92 VIEW syntax
-- ✓ LEFT JOIN fully supported
-- ✓ Column aliasing fully supported
-- ✓ No proprietary T-SQL features
-- ✓ No conversion required beyond schema name change
-- ============================================================
