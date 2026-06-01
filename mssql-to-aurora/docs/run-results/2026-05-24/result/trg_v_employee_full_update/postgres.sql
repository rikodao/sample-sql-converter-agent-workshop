-- ============================================================
-- TRIGGER: trg_v_employee_full_update (PostgreSQL Native)
-- Converted from: T-SQL INSTEAD OF UPDATE trigger
-- Target: Aurora PostgreSQL
-- ============================================================

-- Trigger function definition
CREATE OR REPLACE FUNCTION public.trg_v_employee_full_update_fn()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Update the base table (employees) with values from NEW
    -- NEW represents the updated row in PostgreSQL triggers
    -- Only update columns that exist in the base employees table
    UPDATE public.employees e
    SET first_name = NEW.first_name,
        last_name  = NEW.last_name,
        is_active  = NEW.is_active
    WHERE e.employee_id = NEW.employee_id;
    
    -- Note: 'email' column is NOT updated because:
    --   - It does not exist in the base employees table
    --   - It is a computed column in the view (fixed value 'dummy@example.com')
    --   - Attempting to update it would cause an error
    
    -- Return NEW to indicate successful processing
    -- For INSTEAD OF triggers, returning NEW allows the operation to proceed
    RETURN NEW;
END;
$$;

-- Create the INSTEAD OF UPDATE trigger on the view
CREATE TRIGGER trg_v_employee_full_update
    INSTEAD OF UPDATE ON public.v_employee_full
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_v_employee_full_update_fn();

-- ============================================================
-- CONVERSION NOTES:
-- ============================================================
-- 1. T-SQL Structure → PostgreSQL:
--    - T-SQL: CREATE TRIGGER ... AS BEGIN ... END
--    - PG: CREATE FUNCTION ... RETURNS TRIGGER + CREATE TRIGGER ... EXECUTE FUNCTION
--
-- 2. Pseudo-tables:
--    - T-SQL 'inserted' → PostgreSQL 'NEW' (single row in FOR EACH ROW trigger)
--    - T-SQL handles multiple rows in one trigger execution
--    - PG FOR EACH ROW triggers fire once per affected row
--
-- 3. UPDATE Syntax:
--    - T-SQL: UPDATE e SET ... FROM employees e INNER JOIN inserted i ON ...
--    - PG: UPDATE employees e SET ... WHERE e.employee_id = NEW.employee_id
--    - No JOIN needed since NEW represents the single updated row
--
-- 4. SET NOCOUNT ON:
--    - T-SQL directive to suppress row count messages
--    - Not needed in PostgreSQL (no equivalent concept)
--
-- 5. Schema Mapping:
--    - T-SQL 'dbo' → PostgreSQL 'public' (default schema)
--
-- 6. Return Value:
--    - PostgreSQL INSTEAD OF triggers must RETURN NEW or NULL
--    - RETURN NEW: allows the operation to proceed (standard behavior)
--    - RETURN NULL: would suppress the operation
--
-- 7. Behavior Equivalence:
--    - T-SQL version: Updates base table for all rows in 'inserted'
--    - PG version: Updates base table once per row (FOR EACH ROW)
--    - Net effect is identical: all updated rows propagate to base table
--
-- 8. Column Mapping:
--    - Original T-SQL updates: first_name, last_name, email, is_active
--    - PostgreSQL version updates: first_name, last_name, is_active
--    - 'email' column is NOT updated because:
--      * It does not exist in the base employees table
--      * It is a computed column in the view (literal 'dummy@example.com')
--      * This is correct behavior given the actual schema
--
-- ============================================================
-- EMAIL COLUMN ANALYSIS:
-- ============================================================
-- View definition: SELECT ..., 'dummy@example.com'::text AS email FROM employees
-- 
-- The email column is a computed/literal value in the view, not a real column.
-- Therefore, it cannot and should not be updated by the trigger.
-- 
-- This differs from the MSSQL version where email may have been a real column,
-- but the PostgreSQL implementation is correct for the actual schema.
--
-- If email needs to be updatable in the future:
-- Option 1: Add email column to employees table
--   ALTER TABLE public.employees ADD COLUMN email VARCHAR(255);
--   Then update the view definition and trigger function
--
-- Option 2: Create a separate employee_contacts table
--   CREATE TABLE employee_contacts (employee_id INT, email VARCHAR(255));
--   Add a second UPDATE statement in the trigger to update that table
-- ============================================================
-- DEPENDENCIES:
-- ============================================================
-- Required objects (must exist before creating this trigger):
--   1. public.employees (base table) - EXISTS
--   2. public.v_employee_full (view) - EXISTS
--
-- View definition:
--   SELECT e.employee_id, e.first_name, e.last_name, e.department_id,
--          e.hire_date, e.is_active, 'dummy@example.com'::text AS email
--   FROM employees e;
-- ============================================================
