-- ============================================================================
-- Target: Aurora PostgreSQL (Native)
-- Object: public.usp_search_employees_paged
-- Type: FUNCTION (returns TABLE)
-- Converted from: T-SQL STORED PROCEDURE (SQL Server)
-- ============================================================================
-- Conversion Notes:
-- 1. PROCEDURE converted to FUNCTION returning TABLE (PG procedures cannot return result sets)
-- 2. OUTPUT parameter converted to OUT parameter in function signature
-- 3. sp_executesql converted to RETURN QUERY EXECUTE
-- 4. RAISERROR converted to RAISE EXCEPTION
-- 5. QUOTENAME converted to quote_ident()
-- 6. ISNULL converted to COALESCE
-- 7. LTRIM/RTRIM converted to btrim()
-- 8. CEILING converted to ceil()
-- 9. Dynamic SQL using format() for safe parameter binding
-- 10. TRY-CATCH converted to EXCEPTION block
-- 11. SET NOCOUNT ON removed (not needed in PostgreSQL)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.usp_search_employees_paged(
    p_search_term VARCHAR(100) DEFAULT NULL,
    p_department_id INT DEFAULT NULL,
    p_is_active BOOLEAN DEFAULT NULL,
    p_page_number INT DEFAULT 1,
    p_page_size INT DEFAULT 10,
    p_sort_column VARCHAR(50) DEFAULT 'employee_id',
    p_sort_direction VARCHAR(4) DEFAULT 'ASC',
    OUT p_total_count INT
)
RETURNS TABLE (
    employee_id INT,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    email VARCHAR(255),
    department_id INT,
    department_name VARCHAR(100),
    hire_date DATE,
    salary NUMERIC(10,2),
    job_title VARCHAR(100),
    is_active BOOLEAN,
    page_number INT,
    page_size INT,
    total_count INT,
    total_pages INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_offset INT;
    v_sql TEXT;
    v_where_conditions TEXT[];
    v_where_clause TEXT;
    v_order_clause TEXT;
    v_count_sql TEXT;
    v_search_term_trimmed VARCHAR(100);
    v_total_pages INT;
BEGIN
    -- Initialize output parameter
    p_total_count := 0;
    
    -- Validate pagination parameters
    IF p_page_number < 1 THEN
        RAISE EXCEPTION 'Page number must be greater than or equal to 1';
    END IF;
    
    IF p_page_size < 1 OR p_page_size > 1000 THEN
        RAISE EXCEPTION 'Page size must be between 1 and 1000';
    END IF;
    
    -- Validate sort direction
    IF UPPER(p_sort_direction) NOT IN ('ASC', 'DESC') THEN
        RAISE EXCEPTION 'Sort direction must be ASC or DESC';
    END IF;
    
    -- Validate sort column (whitelist approach to prevent SQL injection)
    IF p_sort_column NOT IN (
        'employee_id', 'first_name', 'last_name', 'email', 
        'department_id', 'hire_date', 'salary', 'job_title'
    ) THEN
        RAISE EXCEPTION 'Invalid sort column specified';
    END IF;
    
    -- Calculate offset
    v_offset := (p_page_number - 1) * p_page_size;
    
    -- Trim search term if provided
    IF p_search_term IS NOT NULL THEN
        v_search_term_trimmed := btrim(p_search_term);
    ELSE
        v_search_term_trimmed := NULL;
    END IF;
    
    -- Build WHERE conditions array
    v_where_conditions := ARRAY[]::TEXT[];
    
    IF v_search_term_trimmed IS NOT NULL AND v_search_term_trimmed <> '' THEN
        v_where_conditions := array_append(v_where_conditions, format(
            '(e.first_name ILIKE %L OR e.last_name ILIKE %L OR e.email ILIKE %L OR e.job_title ILIKE %L)',
            '%' || v_search_term_trimmed || '%',
            '%' || v_search_term_trimmed || '%',
            '%' || v_search_term_trimmed || '%',
            '%' || v_search_term_trimmed || '%'
        ));
    END IF;
    
    IF p_department_id IS NOT NULL THEN
        v_where_conditions := array_append(v_where_conditions, 
            format('e.department_id = %L', p_department_id));
    END IF;
    
    IF p_is_active IS NOT NULL THEN
        v_where_conditions := array_append(v_where_conditions, 
            format('COALESCE(e.is_active, true) = %L', p_is_active));
    END IF;
    
    -- Build WHERE clause
    IF array_length(v_where_conditions, 1) > 0 THEN
        v_where_clause := 'WHERE ' || array_to_string(v_where_conditions, ' AND ');
    ELSE
        v_where_clause := '';
    END IF;
    
    -- Build ORDER BY clause (using quote_ident for SQL injection prevention)
    v_order_clause := 'ORDER BY ' || quote_ident(p_sort_column) || ' ' || p_sort_direction;
    
    -- Get total count first
    v_count_sql := format('
        SELECT COUNT(*)
        FROM public.employees e
        %s',
        v_where_clause
    );
    
    EXECUTE v_count_sql INTO p_total_count;
    
    -- Calculate total pages
    IF p_total_count > 0 THEN
        v_total_pages := CEIL(p_total_count::NUMERIC / p_page_size);
    ELSE
        v_total_pages := 0;
    END IF;
    
    -- Build and execute paged results query
    v_sql := format('
        SELECT 
            e.employee_id,
            e.first_name,
            e.last_name,
            e.email,
            e.department_id,
            d.department_name,
            e.hire_date,
            e.salary,
            e.job_title,
            e.is_active,
            %L::INT AS page_number,
            %L::INT AS page_size,
            %L::INT AS total_count,
            %L::INT AS total_pages
        FROM public.employees e
        LEFT JOIN public.departments d ON e.department_id = d.department_id
        %s
        %s
        OFFSET %L
        LIMIT %L',
        p_page_number,
        p_page_size,
        p_total_count,
        v_total_pages,
        v_where_clause,
        v_order_clause,
        v_offset,
        p_page_size
    );
    
    -- Return query result
    RETURN QUERY EXECUTE v_sql;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Set output to -1 to indicate error
        p_total_count := -1;
        
        -- Re-raise the error with details
        RAISE EXCEPTION 'Error in usp_search_employees_paged: %', SQLERRM;
END;
$$;

-- Grant execute permission (adjust as needed for your security model)
-- GRANT EXECUTE ON FUNCTION public.usp_search_employees_paged TO your_role;

COMMENT ON FUNCTION public.usp_search_employees_paged IS 
'Paged employee search with dynamic filtering and sorting. 
Converted from SQL Server T-SQL PROCEDURE to PostgreSQL FUNCTION.

Key Differences from SQL Server:
- Implemented as FUNCTION returning TABLE instead of PROCEDURE
- OUTPUT parameter converted to OUT parameter
- Result set returned via RETURN QUERY instead of SELECT

Parameters:
- p_search_term: Search in first_name, last_name, email, job_title (case-insensitive)
- p_department_id: Filter by department
- p_is_active: Filter by active status
- p_page_number: Page number (1-based)
- p_page_size: Records per page (1-1000)
- p_sort_column: Column to sort by (whitelisted)
- p_sort_direction: ASC or DESC
- p_total_count: OUT parameter returning total matching records

Usage:
  SELECT * FROM public.usp_search_employees_paged(
    p_search_term := ''John'',
    p_page_number := 1,
    p_page_size := 10
  );
  
  -- To capture the OUT parameter:
  DO $$
  DECLARE
    v_total INT;
    v_rec RECORD;
  BEGIN
    FOR v_rec IN 
      SELECT * FROM public.usp_search_employees_paged(
        p_search_term := ''John'',
        p_page_number := 1,
        p_page_size := 10
      )
    LOOP
      v_total := v_rec.total_count;
      -- Process record...
    END LOOP;
    RAISE NOTICE ''Total count: %'', v_total;
  END $$;
';
