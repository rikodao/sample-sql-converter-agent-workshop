-- ============================================================================
-- Target: Aurora PostgreSQL (Native)
-- Object: public.usp_recursive_org_chart
-- Type: FUNCTION (returns TABLE)
-- Converted from: SQL Server dbo.usp_recursive_org_chart (PROCEDURE)
-- ============================================================================
-- Purpose: Retrieve organizational hierarchy starting from a given employee
--          or from top-level management, showing reporting relationships
-- ============================================================================
-- NOTE: Converted from PROCEDURE to FUNCTION because PostgreSQL procedures
--       cannot return result sets directly. Use FUNCTION with RETURNS TABLE.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.usp_recursive_org_chart(
    p_root_employee_id INT DEFAULT NULL,
    p_max_depth INT DEFAULT NULL,
    p_include_inactive INT DEFAULT 0
)
RETURNS TABLE (
    employee_id INT,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    full_name VARCHAR(1000),
    job_title VARCHAR(100),
    department_id INT,
    department_name VARCHAR(100),
    manager_id INT,
    manager_first_name VARCHAR(100),
    manager_last_name VARCHAR(100),
    manager_full_name VARCHAR(200),
    hire_date DATE,
    is_active INT,
    level INT,
    path VARCHAR(1000),
    sort_path VARCHAR(1000),
    direct_report_count BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_error_message TEXT;
BEGIN
    -- Validate inputs
    IF p_root_employee_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM public.employees WHERE employees.employee_id = p_root_employee_id
    )
    THEN
        RAISE EXCEPTION 'Employee ID % does not exist.', p_root_employee_id;
    END IF;
    
    -- Default max depth to unlimited (NULL means no limit)
    -- If specified, must be positive
    IF p_max_depth IS NOT NULL AND p_max_depth <= 0
    THEN
        RAISE EXCEPTION 'Max depth must be a positive integer.';
    END IF;
    
    -- Recursive CTE to build organizational hierarchy
    -- Return the complete hierarchy
    RETURN QUERY
    WITH RECURSIVE OrgHierarchy AS (
        -- Anchor: Start with root employee(s)
        SELECT 
            e.employee_id,
            e.first_name,
            e.last_name,
            e.job_title,
            e.department_id,
            e.manager_id,
            e.hire_date,
            e.is_active,
            CAST(e.last_name || ', ' || e.first_name AS VARCHAR(1000)) AS full_name,
            0 AS level,
            CAST('/' || CAST(e.employee_id AS VARCHAR(10)) || '/' AS VARCHAR(1000)) AS path,
            CAST(e.last_name || ', ' || e.first_name AS VARCHAR(1000)) AS sort_path
        FROM public.employees e
        WHERE 
            -- If root_employee_id specified, start there
            -- Otherwise, start with top-level (manager_id IS NULL)
            (
                (p_root_employee_id IS NOT NULL AND e.employee_id = p_root_employee_id)
                OR
                (p_root_employee_id IS NULL AND e.manager_id IS NULL)
            )
            -- Filter by active status if requested
            AND (
                p_include_inactive = 1 
                OR COALESCE(e.is_active, 1) = 1
            )
        
        UNION ALL
        
        -- Recursive: Get direct reports
        SELECT 
            e.employee_id,
            e.first_name,
            e.last_name,
            e.job_title,
            e.department_id,
            e.manager_id,
            e.hire_date,
            e.is_active,
            CAST(e.last_name || ', ' || e.first_name AS VARCHAR(1000)) AS full_name,
            oh.level + 1 AS level,
            CAST(oh.path || CAST(e.employee_id AS VARCHAR(10)) || '/' AS VARCHAR(1000)) AS path,
            CAST(oh.sort_path || ' > ' || e.last_name || ', ' || e.first_name AS VARCHAR(1000)) AS sort_path
        FROM public.employees e
        INNER JOIN OrgHierarchy oh ON e.manager_id = oh.employee_id
        WHERE 
            -- Respect max_depth if specified
            (p_max_depth IS NULL OR oh.level < p_max_depth)
            -- Filter by active status if requested
            AND (
                p_include_inactive = 1 
                OR COALESCE(e.is_active, 1) = 1
            )
    )
    -- Return the complete hierarchy
    SELECT 
        oh.employee_id,
        oh.first_name,
        oh.last_name,
        oh.full_name,
        oh.job_title,
        oh.department_id,
        d.department_name,
        oh.manager_id,
        m.first_name AS manager_first_name,
        m.last_name AS manager_last_name,
        CAST(m.last_name || ', ' || m.first_name AS VARCHAR(200)) AS manager_full_name,
        oh.hire_date,
        oh.is_active,
        oh.level,
        oh.path,
        oh.sort_path,
        -- Calculate direct report count
        (
            SELECT COUNT(*) 
            FROM public.employees e2 
            WHERE e2.manager_id = oh.employee_id
            AND (p_include_inactive = 1 OR COALESCE(e2.is_active, 1) = 1)
        ) AS direct_report_count
    FROM OrgHierarchy oh
    LEFT JOIN public.employees m ON oh.manager_id = m.employee_id
    LEFT JOIN public.departments d ON oh.department_id = d.department_id
    ORDER BY oh.sort_path;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Capture error information
        v_error_message := SQLERRM;
        
        -- Re-raise the error
        RAISE EXCEPTION '%', v_error_message;
END;
$$;

-- ============================================================================
-- Usage Example:
-- ============================================================================
-- In T-SQL, you would call:
--   EXEC dbo.usp_recursive_org_chart @root_employee_id = 5, @max_depth = 2
--
-- In PostgreSQL, you call it as a function:
--   SELECT * FROM public.usp_recursive_org_chart(5, 2, 0);
--
-- Or with named parameters:
--   SELECT * FROM public.usp_recursive_org_chart(
--       p_root_employee_id := 5,
--       p_max_depth := 2,
--       p_include_inactive := 0
--   );
-- ============================================================================

-- ============================================================================
-- Conversion Notes:
-- ============================================================================
-- 1. Changed from PROCEDURE to FUNCTION with RETURNS TABLE
--    - PostgreSQL procedures cannot return result sets directly
--    - Functions with RETURNS TABLE are the equivalent pattern
--    - Calling syntax changes from EXEC to SELECT * FROM function()
--
-- 2. Changed parameter names: @param → p_param (PostgreSQL convention)
--
-- 3. Changed BIT type to INT (0/1) for p_include_inactive
--    - PostgreSQL has BOOLEAN, but using INT for compatibility with T-SQL logic
--
-- 4. Removed SET NOCOUNT ON (not needed in PostgreSQL)
--
-- 5. Changed RAISERROR → RAISE EXCEPTION
--    - PostgreSQL uses RAISE EXCEPTION for errors
--    - Format string uses % instead of %d
--
-- 6. Changed ISNULL() → COALESCE()
--    - COALESCE is SQL standard and works identically
--
-- 7. Changed string concatenation: + → ||
--    - PostgreSQL uses || for string concatenation
--
-- 8. Changed NVARCHAR → VARCHAR
--    - PostgreSQL uses UTF-8 by default, no need for NVARCHAR
--
-- 9. Changed TRY-CATCH → EXCEPTION WHEN OTHERS
--    - PostgreSQL exception handling syntax
--
-- 10. Changed ERROR_MESSAGE() → SQLERRM
--     - PostgreSQL's equivalent for error message
--     - ERROR_SEVERITY() and ERROR_STATE() not available in PostgreSQL
--
-- 11. Changed schema: dbo → public
--     - Default schema in PostgreSQL is public
--
-- 12. Used RETURN QUERY for result set
--     - Standard pattern for table-returning functions in PostgreSQL
--
-- 13. Removed explicit RETURN statements after RAISERROR
--     - RAISE EXCEPTION automatically exits the function
--
-- 14. Added explicit column list in RETURNS TABLE
--     - Required in PostgreSQL to define the output structure
--     - Column types must match the SELECT output
--
-- 15. Qualified table references in EXISTS subquery
--     - Added table alias to avoid ambiguity with RETURNS TABLE columns
-- ============================================================================
