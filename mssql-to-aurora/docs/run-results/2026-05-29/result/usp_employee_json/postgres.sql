-- ============================================================================
-- Target: Aurora PostgreSQL (Native)
-- Object: public.usp_employee_json
-- Type: STORED PROCEDURE
-- Converted from: SQL Server T-SQL
-- ============================================================================
-- Conversion Notes:
-- - FOR JSON PATH → jsonb_build_object() + jsonb_agg()
-- - WITHOUT_ARRAY_WRAPPER → Single object subquery
-- - RAISERROR → RAISE EXCEPTION
-- - BIT → boolean
-- - @parameter → p_parameter
-- ============================================================================

CREATE OR REPLACE PROCEDURE public.usp_employee_json(
    p_employee_id INT DEFAULT NULL,
    p_department_id INT DEFAULT NULL,
    p_include_inactive boolean DEFAULT false
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_json_output jsonb;
BEGIN
    -- Validate parameters
    IF p_employee_id IS NOT NULL AND p_employee_id <= 0 THEN
        RAISE EXCEPTION 'Invalid employee_id. Must be a positive integer.';
    END IF;
    
    IF p_department_id IS NOT NULL AND p_department_id <= 0 THEN
        RAISE EXCEPTION 'Invalid department_id. Must be a positive integer.';
    END IF;
    
    -- Build JSON output using PostgreSQL jsonb functions
    SELECT jsonb_agg(
        jsonb_build_object(
            'employee_id', e.employee_id,
            'first_name', e.first_name,
            'last_name', e.last_name,
            'email', e.email,
            'phone', e.phone,
            'hire_date', e.hire_date,
            'salary', e.salary,
            'is_active', e.is_active,
            'status', e.status,
            -- Nested department object
            'department', (
                SELECT jsonb_build_object(
                    'department_id', d.department_id,
                    'department_name', d.department_name,
                    'location', d.location
                )
                FROM public.departments d
                WHERE d.department_id = e.department_id
            ),
            -- Nested manager object
            'manager', (
                SELECT jsonb_build_object(
                    'manager_id', m.employee_id,
                    'manager_name', m.first_name || ' ' || m.last_name,
                    'manager_email', m.email
                )
                FROM public.employees m
                WHERE m.employee_id = e.manager_id
            )
        )
    )
    INTO v_json_output
    FROM public.employees e
    WHERE 
        -- Filter by employee_id if provided
        (p_employee_id IS NULL OR e.employee_id = p_employee_id)
        -- Filter by department_id if provided
        AND (p_department_id IS NULL OR e.department_id = p_department_id)
        -- Filter by active status unless include_inactive is set
        AND (p_include_inactive = true OR e.is_active = true)
    ORDER BY e.employee_id;
    
    -- Return the JSON result
    -- Note: In PostgreSQL, procedures don't return values directly
    -- The result is stored in v_json_output variable
    -- To return results, consider using a FUNCTION instead of PROCEDURE
    -- or use OUT parameter
    RAISE NOTICE 'JSON Output: %', v_json_output;
    
END;
$$;

-- ============================================================================
-- Alternative: FUNCTION version that returns JSON
-- ============================================================================
-- If the calling application needs to receive the JSON result directly,
-- use this FUNCTION version instead of the PROCEDURE above:

CREATE OR REPLACE FUNCTION public.usp_employee_json_func(
    p_employee_id INT DEFAULT NULL,
    p_department_id INT DEFAULT NULL,
    p_include_inactive boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
    v_json_output jsonb;
BEGIN
    -- Validate parameters
    IF p_employee_id IS NOT NULL AND p_employee_id <= 0 THEN
        RAISE EXCEPTION 'Invalid employee_id. Must be a positive integer.';
    END IF;
    
    IF p_department_id IS NOT NULL AND p_department_id <= 0 THEN
        RAISE EXCEPTION 'Invalid department_id. Must be a positive integer.';
    END IF;
    
    -- Build JSON output using PostgreSQL jsonb functions
    SELECT jsonb_agg(
        jsonb_build_object(
            'employee_id', e.employee_id,
            'first_name', e.first_name,
            'last_name', e.last_name,
            'email', e.email,
            'phone', e.phone,
            'hire_date', e.hire_date,
            'salary', e.salary,
            'is_active', e.is_active,
            'status', e.status,
            -- Nested department object
            'department', (
                SELECT jsonb_build_object(
                    'department_id', d.department_id,
                    'department_name', d.department_name,
                    'location', d.location
                )
                FROM public.departments d
                WHERE d.department_id = e.department_id
            ),
            -- Nested manager object
            'manager', (
                SELECT jsonb_build_object(
                    'manager_id', m.employee_id,
                    'manager_name', m.first_name || ' ' || m.last_name,
                    'manager_email', m.email
                )
                FROM public.employees m
                WHERE m.employee_id = e.manager_id
            )
        )
    )
    INTO v_json_output
    FROM public.employees e
    WHERE 
        -- Filter by employee_id if provided
        (p_employee_id IS NULL OR e.employee_id = p_employee_id)
        -- Filter by department_id if provided
        AND (p_department_id IS NULL OR e.department_id = p_department_id)
        -- Filter by active status unless include_inactive is set
        AND (p_include_inactive = true OR e.is_active = true)
    ORDER BY e.employee_id;
    
    RETURN v_json_output;
    
END;
$$;

COMMENT ON PROCEDURE public.usp_employee_json IS 'Returns employee data in JSON format with nested department and manager objects. Converted from SQL Server FOR JSON PATH to PostgreSQL jsonb functions.';
COMMENT ON FUNCTION public.usp_employee_json_func IS 'Function version that returns jsonb directly. Use this if the calling application needs to receive JSON results.';
