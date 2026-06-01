-- ============================================================================
-- Target: Aurora PostgreSQL (Native)
-- Object: trg_v_employee_full_update
-- Type: TRIGGER (INSTEAD OF UPDATE on VIEW)
-- Converted from: T-SQL INSTEAD OF UPDATE trigger
-- ============================================================================
-- CONVERSION NOTES:
-- 1. T-SQL INSTEAD OF triggers use inserted/deleted pseudo-tables
--    PG uses NEW/OLD records (FOR EACH ROW) or transition tables (FOR EACH STATEMENT)
-- 2. T-SQL pattern: UPDATE base FROM base JOIN inserted
--    PG pattern: UPDATE base SET ... WHERE base.pk = NEW.pk (in row-level trigger)
-- 3. SET NOCOUNT ON is not needed in PG
-- 4. Trigger function must RETURN NEW/OLD/NULL for row-level triggers
-- 5. Schema: dbo -> public
-- ============================================================================

-- Create the trigger function
CREATE OR REPLACE FUNCTION public.trg_v_employee_full_update_fn()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Update employees table with values from the NEW record
    -- This executes for each row being updated in the view
    UPDATE public.employees e
    SET 
        first_name = NEW.first_name,
        last_name = NEW.last_name,
        email = NEW.email,
        department_id = NEW.department_id,
        salary = NEW.salary,
        hire_date = NEW.hire_date,
        is_active = NEW.is_active
    WHERE e.employee_id = NEW.employee_id;
    
    -- Return NEW to indicate successful processing
    -- (Though for INSTEAD OF triggers, the return value is typically ignored)
    RETURN NEW;
END;
$$;

-- Create the INSTEAD OF UPDATE trigger on the view
CREATE TRIGGER trg_v_employee_full_update
    INSTEAD OF UPDATE ON public.v_employee_full
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_v_employee_full_update_fn();

-- ============================================================================
-- CONVERSION DETAILS:
-- ============================================================================
-- T-SQL Pattern:
--   CREATE TRIGGER dbo.trg_v_employee_full_update
--   ON dbo.v_employee_full
--   INSTEAD OF UPDATE
--   AS
--   BEGIN
--       UPDATE e SET ... FROM dbo.employees e INNER JOIN inserted i ON e.employee_id = i.employee_id
--   END
--
-- PL/pgSQL Pattern:
--   CREATE FUNCTION trg_fn() RETURNS TRIGGER AS $$
--   BEGIN
--       UPDATE employees SET ... WHERE employee_id = NEW.employee_id;
--       RETURN NEW;
--   END $$ LANGUAGE plpgsql;
--   
--   CREATE TRIGGER trg INSTEAD OF UPDATE ON view
--   FOR EACH ROW EXECUTE FUNCTION trg_fn();
--
-- Key Differences:
-- 1. T-SQL: Statement-level trigger with inserted/deleted tables
--    PG: Row-level trigger with NEW/OLD records (more common for INSTEAD OF)
-- 2. T-SQL: No explicit RETURN
--    PG: Must RETURN NEW/OLD/NULL
-- 3. T-SQL: JOIN with inserted table
--    PG: Direct reference to NEW record
-- 4. Both: INSTEAD OF triggers prevent the original operation and execute custom logic
-- ============================================================================
