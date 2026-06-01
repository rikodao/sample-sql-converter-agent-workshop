-- ============================================================================
-- Object: public.usp_dept_headcount_pivot
-- Type: STORED PROCEDURE (PostgreSQL Native)
-- Description: Generate a pivot report of employee headcount by department
-- ============================================================================
-- Converted from T-SQL to PL/pgSQL for Aurora PostgreSQL
-- Original: dbo.usp_dept_headcount_pivot
-- ============================================================================

CREATE OR REPLACE PROCEDURE public.usp_dept_headcount_pivot(
    p_as_of_date TIMESTAMP DEFAULT NULL,
    p_include_inactive BOOLEAN DEFAULT FALSE
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql TEXT;
    v_pivot_columns TEXT;
    v_total_expr TEXT;
    v_as_of_date TIMESTAMP;
    v_dept_name TEXT;
    v_first BOOLEAN;
BEGIN
    -- Default to current timestamp if not specified
    v_as_of_date := COALESCE(p_as_of_date, now());
    
    -- Initialize variables
    v_pivot_columns := '';
    v_total_expr := '';
    v_first := TRUE;
    
    -- Generate CASE expressions for each department
    FOR v_dept_name IN (
        SELECT DISTINCT d.department_name
        FROM public.departments d
        INNER JOIN public.employees e ON d.department_id = e.department_id
        WHERE e.hire_date <= v_as_of_date
          AND (p_include_inactive = TRUE OR e.status = 'Active')
        ORDER BY d.department_name
    ) LOOP
        IF NOT v_first THEN
            v_pivot_columns := v_pivot_columns || ', ';
            v_total_expr := v_total_expr || ' + ';
        END IF;
        v_first := FALSE;
        
        -- Build CASE expression for this department
        v_pivot_columns := v_pivot_columns || 
            'SUM(CASE WHEN department_name = ' || quote_literal(v_dept_name) || 
            ' THEN 1 ELSE 0 END) AS ' || quote_ident(v_dept_name);
        
        -- Add to total expression
        v_total_expr := v_total_expr || 'COALESCE(' || quote_ident(v_dept_name) || ', 0)';
    END LOOP;
    
    -- Handle case where no departments found
    IF v_pivot_columns = '' THEN
        -- Return a result set with a message
        RAISE NOTICE 'No Data';
        RETURN;
    END IF;
    
    -- Build dynamic PIVOT query
    -- T-SQL PIVOT → PostgreSQL CASE expressions with GROUP BY
    v_sql := 'SELECT 
        job_title,
        ' || v_pivot_columns || ',
        ' || v_total_expr || ' AS total_count
    FROM (
        SELECT 
            COALESCE(e.job_title, ''Unknown'') AS job_title,
            d.department_name,
            e.employee_id
        FROM public.employees e
        LEFT JOIN public.departments d ON e.department_id = d.department_id
        WHERE e.hire_date <= $1
          AND ($2 = TRUE OR e.status = ''Active'')
    ) AS source_data
    GROUP BY job_title
    ORDER BY job_title';
    
    -- Execute dynamic SQL
    -- T-SQL: EXEC sp_executesql @sql, N'@as_of_date DATETIME, @include_inactive BIT', ...
    -- PG: EXECUTE ... USING ...
    EXECUTE v_sql USING v_as_of_date, p_include_inactive;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error in usp_dept_headcount_pivot: %', SQLERRM;
        RAISE;
END;
$$;

-- ============================================================================
-- NOTES ON CONVERSION:
-- ============================================================================
-- 1. T-SQL PIVOT operator → PostgreSQL CASE expressions with SUM/GROUP BY
--    - PIVOT is not natively supported in PostgreSQL
--    - Alternative: crosstab() from tablefunc extension (requires pre-defined columns)
--    - Chosen approach: Dynamic CASE expressions for flexibility
--    - Each department becomes: SUM(CASE WHEN department_name = 'X' THEN 1 ELSE 0 END) AS "X"
--
-- 2. FOR XML PATH('') with STUFF → FOR loop with string concatenation
--    - T-SQL: STUFF((SELECT ... FOR XML PATH('')), 1, 1, '')
--    - PG: FOR loop iterating over departments and building strings
--    - Alternative: string_agg() could be used but loop gives more control for complex expressions
--
-- 3. QUOTENAME() → quote_ident()
--    - Both functions quote identifiers for safe use in dynamic SQL
--    - Handles special characters and reserved words
--
-- 4. quote_literal() for string values in dynamic SQL
--    - Ensures proper escaping of department names in CASE expressions
--    - Prevents SQL injection
--
-- 5. sp_executesql → EXECUTE ... USING
--    - Parameter placeholders: @param → $1, $2, ...
--    - Parameter declaration: N'@x INT' → USING x
--    - More secure than string concatenation
--
-- 6. GETDATE() → now()
--    - Both return current timestamp
--    - now() is transaction-start time (stable within transaction)
--    - Alternative: clock_timestamp() for actual current time
--
-- 7. BIT → BOOLEAN
--    - T-SQL BIT (0/1) → PostgreSQL BOOLEAN (TRUE/FALSE)
--    - Comparison: @include_inactive = 1 → p_include_inactive = TRUE
--
-- 8. ISNULL() → COALESCE()
--    - Functionally equivalent
--    - COALESCE is SQL standard
--
-- 9. SET NOCOUNT ON
--    - Not needed in PostgreSQL (no row count messages by default)
--    - PostgreSQL doesn't send "X rows affected" to client automatically
--
-- 10. Result Set Return from PROCEDURE
--     - T-SQL: Procedures can return result sets via SELECT
--     - PG: Procedures can execute queries that return results to client
--     - EXECUTE statement will return results directly to calling client
--     - Note: Cannot capture results in variable without INTO clause
--
-- 11. CROSS APPLY for total calculation
--     - T-SQL: CROSS APPLY (SELECT col1 + col2 + ... AS total_count)
--     - PG: Direct arithmetic in SELECT list
--     - Used COALESCE to handle potential NULLs in sum
--
-- 12. LEFT JOIN behavior
--     - Same in both T-SQL and PostgreSQL
--     - Handles NULL department_id cases (employees without department)
--
-- 13. Dynamic SQL construction
--     - Built incrementally in loop
--     - Separates pivot columns from total expression
--     - Maintains order by department_name
--
-- 14. Error handling
--     - T-SQL: Would use TRY-CATCH if present
--     - PG: EXCEPTION block catches all errors
--     - RAISE NOTICE for logging, then RAISE to re-throw
--
-- 15. Parameter naming convention
--     - T-SQL: @parameter_name
--     - PG: p_parameter_name (p_ prefix for parameters)
--     - PG: v_ prefix for local variables
-- ============================================================================

-- ============================================================================
-- USAGE EXAMPLE:
-- ============================================================================
-- -- Call with default parameters (current date, active employees only)
-- CALL public.usp_dept_headcount_pivot();
--
-- -- Call with specific date
-- CALL public.usp_dept_headcount_pivot('2024-01-01'::TIMESTAMP);
--
-- -- Call with specific date and include inactive employees
-- CALL public.usp_dept_headcount_pivot('2024-01-01'::TIMESTAMP, TRUE);
--
-- -- Call with NULL date (uses current timestamp) and include inactive
-- CALL public.usp_dept_headcount_pivot(NULL, TRUE);
-- ============================================================================
