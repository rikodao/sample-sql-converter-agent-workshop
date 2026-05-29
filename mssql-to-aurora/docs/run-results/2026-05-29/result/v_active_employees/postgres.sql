-- ============================================================
-- VIEW: public.v_active_employees
-- Target: Aurora PostgreSQL (Native)
-- Converted from: SQL Server dbo.v_active_employees
-- ============================================================
-- Conversion Notes:
-- 1. Schema: dbo → public
-- 2. Identifiers: Lowercase (PostgreSQL convention)
-- 3. BIT type (is_active): Converted to BOOLEAN in base table assumption
-- 4. No GETDATE() in this VIEW, but pattern comments reference it
-- ============================================================

CREATE OR REPLACE VIEW public.v_active_employees
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
FROM public.employees e
LEFT JOIN public.departments d ON e.department_id = d.department_id
WHERE e.status = 'Active'
    OR (e.termination_date IS NULL AND e.is_active = true);

-- ============================================================
-- CONVERSION DETAILS
-- ============================================================
-- T-SQL → PostgreSQL Changes:
--
-- 1. Schema Mapping:
--    - dbo.v_active_employees → public.v_active_employees
--    - dbo.employees → public.employees
--    - dbo.departments → public.departments
--
-- 2. Data Type Assumptions:
--    - e.is_active: BIT (SQL Server) → BOOLEAN (PostgreSQL)
--      * T-SQL: is_active = 1
--      * PG:    is_active = true
--
-- 3. Syntax Compatibility:
--    - LEFT JOIN: Identical syntax
--    - WHERE with OR: Identical logic
--    - NULL handling: Identical behavior
--
-- 4. Collation:
--    - T-SQL default: Case-insensitive (CI_AS)
--    - PostgreSQL default: Case-sensitive
--    - Impact: e.status = 'Active' will NOT match 'active' or 'ACTIVE'
--    - Solution (if needed): Use LOWER(e.status) = 'active' or COLLATE
--
-- 5. Alternative Patterns (from original comments):
--    - Pattern 4 referenced GETDATE() → would become now() or CURRENT_DATE
--    - Example: WHERE e.end_date IS NULL OR e.end_date > CURRENT_DATE
--
-- ============================================================
-- DEPENDENCIES
-- ============================================================
-- Required base tables:
-- - public.employees (employee_id, first_name, last_name, email, 
--                     phone_number, hire_date, job_id, salary, 
--                     commission_pct, manager_id, department_id,
--                     status, termination_date, is_active)
-- - public.departments (department_id, department_name, location_id)
--
-- ============================================================
-- TESTING NOTES
-- ============================================================
-- Test cases to verify:
-- 1. Active employees with status = 'Active' are included
-- 2. Employees with NULL termination_date AND is_active = true are included
-- 3. Inactive employees (status != 'Active' AND (termination_date NOT NULL OR is_active = false)) are excluded
-- 4. LEFT JOIN preserves employees without department assignment
-- 5. Case sensitivity: 'Active' vs 'active' vs 'ACTIVE'
--
-- ============================================================
