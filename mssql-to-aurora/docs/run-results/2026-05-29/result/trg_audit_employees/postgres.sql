-- ============================================================================
-- Target: Aurora PostgreSQL (Native)
-- Object: public.trg_audit_employees
-- Type: TRIGGER
-- Converted from: T-SQL AFTER TRIGGER
-- ============================================================================
-- Conversion Notes:
-- 1. T-SQL AFTER trigger → PostgreSQL trigger function + trigger
-- 2. inserted/deleted pseudo-tables → NEW/OLD records (row-level)
-- 3. SYSTEM_USER → session_user
-- 4. GETDATE() → current_timestamp
-- 5. NEWID() → gen_random_uuid()
-- 6. Operation type determined by TG_OP variable
-- 7. FOR EACH ROW ensures multi-row operations are handled correctly
-- ============================================================================

-- Create the trigger function
CREATE OR REPLACE FUNCTION public.trg_audit_employees_func()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_operation_type VARCHAR(10);
    v_current_user VARCHAR(128);
    v_current_time TIMESTAMP;
BEGIN
    -- Initialize variables
    v_current_user := session_user;
    v_current_time := current_timestamp;
    v_operation_type := TG_OP;
    
    -- Log DELETE operations (capture old values)
    IF TG_OP = 'DELETE' THEN
        INSERT INTO public.employee_audit (
            audit_id,
            employee_id,
            operation_type,
            operation_date,
            operation_user,
            old_first_name,
            old_last_name,
            old_email,
            old_department_id,
            old_salary,
            old_hire_date,
            old_is_active,
            new_first_name,
            new_last_name,
            new_email,
            new_department_id,
            new_salary,
            new_hire_date,
            new_is_active
        )
        VALUES (
            gen_random_uuid(),
            OLD.employee_id,
            v_operation_type,
            v_current_time,
            v_current_user,
            OLD.first_name,
            OLD.last_name,
            OLD.email,
            OLD.department_id,
            OLD.salary,
            OLD.hire_date,
            OLD.is_active,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL
        );
        RETURN OLD;
    END IF;
    
    -- Log INSERT operations (capture new values)
    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.employee_audit (
            audit_id,
            employee_id,
            operation_type,
            operation_date,
            operation_user,
            old_first_name,
            old_last_name,
            old_email,
            old_department_id,
            old_salary,
            old_hire_date,
            old_is_active,
            new_first_name,
            new_last_name,
            new_email,
            new_department_id,
            new_salary,
            new_hire_date,
            new_is_active
        )
        VALUES (
            gen_random_uuid(),
            NEW.employee_id,
            v_operation_type,
            v_current_time,
            v_current_user,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            NEW.first_name,
            NEW.last_name,
            NEW.email,
            NEW.department_id,
            NEW.salary,
            NEW.hire_date,
            NEW.is_active
        );
        RETURN NEW;
    END IF;
    
    -- Log UPDATE operations (capture both old and new values)
    IF TG_OP = 'UPDATE' THEN
        INSERT INTO public.employee_audit (
            audit_id,
            employee_id,
            operation_type,
            operation_date,
            operation_user,
            old_first_name,
            old_last_name,
            old_email,
            old_department_id,
            old_salary,
            old_hire_date,
            old_is_active,
            new_first_name,
            new_last_name,
            new_email,
            new_department_id,
            new_salary,
            new_hire_date,
            new_is_active
        )
        VALUES (
            gen_random_uuid(),
            NEW.employee_id,
            v_operation_type,
            v_current_time,
            v_current_user,
            OLD.first_name,
            OLD.last_name,
            OLD.email,
            OLD.department_id,
            OLD.salary,
            OLD.hire_date,
            OLD.is_active,
            NEW.first_name,
            NEW.last_name,
            NEW.email,
            NEW.department_id,
            NEW.salary,
            NEW.hire_date,
            NEW.is_active
        );
        RETURN NEW;
    END IF;
    
    -- Default return (should not reach here)
    RETURN NEW;
END;
$$;

-- Create the trigger
CREATE TRIGGER trg_audit_employees
AFTER INSERT OR UPDATE OR DELETE
ON public.employees
FOR EACH ROW
EXECUTE FUNCTION public.trg_audit_employees_func();

-- Add comment
COMMENT ON FUNCTION public.trg_audit_employees_func() IS 'Audit trigger function for employees table - logs INSERT, UPDATE, DELETE operations';
COMMENT ON TRIGGER trg_audit_employees ON public.employees IS 'Audit trigger for employees table - converted from T-SQL AFTER trigger';
