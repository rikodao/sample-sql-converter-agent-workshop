-- ============================================================================
-- Test Suite for: public.usp_search_employees_paged
-- Purpose: Comprehensive testing of paged employee search functionality
-- Target: Aurora PostgreSQL (Native)
-- ============================================================================

-- ============= TEST CASE 1: Basic pagination - First page =============
-- SETUP
-- No setup needed

-- EXEC & ASSERT
DO $$
DECLARE
    v_total_count INT;
    v_rec RECORD;
    v_row_count INT := 0;
BEGIN
    FOR v_rec IN 
        SELECT * FROM public.usp_search_employees_paged(
            p_search_term := NULL,
            p_department_id := NULL,
            p_is_active := NULL,
            p_page_number := 1,
            p_page_size := 5,
            p_sort_column := 'employee_id',
            p_sort_direction := 'ASC'
        )
    LOOP
        v_total_count := v_rec.total_count;
        v_row_count := v_row_count + 1;
    END LOOP;
    
    RAISE NOTICE 'TC1|%|First page with page_size=5|rows=%', v_total_count, v_row_count;
END $$;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 2: Second page pagination =============
-- SETUP
-- No setup needed

-- EXEC & ASSERT
DO $$
DECLARE
    v_total_count INT;
    v_rec RECORD;
    v_row_count INT := 0;
BEGIN
    FOR v_rec IN 
        SELECT * FROM public.usp_search_employees_paged(
            p_search_term := NULL,
            p_department_id := NULL,
            p_is_active := NULL,
            p_page_number := 2,
            p_page_size := 5,
            p_sort_column := 'employee_id',
            p_sort_direction := 'ASC'
        )
    LOOP
        v_total_count := v_rec.total_count;
        v_row_count := v_row_count + 1;
    END LOOP;
    
    RAISE NOTICE 'TC2|%|Second page with page_size=5|rows=%', v_total_count, v_row_count;
END $$;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 3: Search by name pattern =============
-- SETUP
-- No setup needed

-- EXEC & ASSERT
DO $$
DECLARE
    v_total_count INT;
    v_rec RECORD;
    v_row_count INT := 0;
BEGIN
    FOR v_rec IN 
        SELECT * FROM public.usp_search_employees_paged(
            p_search_term := 'John',
            p_department_id := NULL,
            p_is_active := NULL,
            p_page_number := 1,
            p_page_size := 10,
            p_sort_column := 'last_name',
            p_sort_direction := 'ASC'
        )
    LOOP
        v_total_count := v_rec.total_count;
        v_row_count := v_row_count + 1;
    END LOOP;
    
    RAISE NOTICE 'TC3|%|Search for John|rows=%', v_total_count, v_row_count;
END $$;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 4: Filter by department =============
-- SETUP & EXEC & ASSERT
DO $$
DECLARE
    v_dept_id INT;
    v_total_count INT;
    v_rec RECORD;
    v_row_count INT := 0;
BEGIN
    SELECT department_id INTO v_dept_id FROM public.departments ORDER BY department_id LIMIT 1;
    
    FOR v_rec IN 
        SELECT * FROM public.usp_search_employees_paged(
            p_search_term := NULL,
            p_department_id := v_dept_id,
            p_is_active := NULL,
            p_page_number := 1,
            p_page_size := 10,
            p_sort_column := 'employee_id',
            p_sort_direction := 'ASC'
        )
    LOOP
        v_total_count := v_rec.total_count;
        v_row_count := v_row_count + 1;
    END LOOP;
    
    RAISE NOTICE 'TC4|dept=%|%|Filter by first department|rows=%', v_dept_id, v_total_count, v_row_count;
END $$;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 5: Filter by active status =============
-- SETUP
-- No setup needed

-- EXEC & ASSERT
DO $$
DECLARE
    v_total_count INT;
    v_rec RECORD;
    v_row_count INT := 0;
BEGIN
    FOR v_rec IN 
        SELECT * FROM public.usp_search_employees_paged(
            p_search_term := NULL,
            p_department_id := NULL,
            p_is_active := TRUE,
            p_page_number := 1,
            p_page_size := 10,
            p_sort_column := 'employee_id',
            p_sort_direction := 'ASC'
        )
    LOOP
        v_total_count := v_rec.total_count;
        v_row_count := v_row_count + 1;
    END LOOP;
    
    RAISE NOTICE 'TC5|%|Active employees only|rows=%', v_total_count, v_row_count;
END $$;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 6: Sort by different column (salary DESC) =============
-- SETUP
-- No setup needed

-- EXEC & ASSERT
DO $$
DECLARE
    v_total_count INT;
    v_rec RECORD;
    v_row_count INT := 0;
BEGIN
    FOR v_rec IN 
        SELECT * FROM public.usp_search_employees_paged(
            p_search_term := NULL,
            p_department_id := NULL,
            p_is_active := NULL,
            p_page_number := 1,
            p_page_size := 3,
            p_sort_column := 'salary',
            p_sort_direction := 'DESC'
        )
    LOOP
        v_total_count := v_rec.total_count;
        v_row_count := v_row_count + 1;
    END LOOP;
    
    RAISE NOTICE 'TC6|%|Sort by salary DESC, top 3|rows=%', v_total_count, v_row_count;
END $$;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 7: Sort by hire_date ASC =============
-- SETUP
-- No setup needed

-- EXEC & ASSERT
DO $$
DECLARE
    v_total_count INT;
    v_rec RECORD;
    v_row_count INT := 0;
BEGIN
    FOR v_rec IN 
        SELECT * FROM public.usp_search_employees_paged(
            p_search_term := NULL,
            p_department_id := NULL,
            p_is_active := NULL,
            p_page_number := 1,
            p_page_size := 5,
            p_sort_column := 'hire_date',
            p_sort_direction := 'ASC'
        )
    LOOP
        v_total_count := v_rec.total_count;
        v_row_count := v_row_count + 1;
    END LOOP;
    
    RAISE NOTICE 'TC7|%|Sort by hire_date ASC|rows=%', v_total_count, v_row_count;
END $$;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 8: Combined filters (search + department + active) =============
-- SETUP & EXEC & ASSERT
DO $$
DECLARE
    v_dept_id INT;
    v_total_count INT;
    v_rec RECORD;
    v_row_count INT := 0;
BEGIN
    SELECT department_id INTO v_dept_id FROM public.departments ORDER BY department_id LIMIT 1;
    
    FOR v_rec IN 
        SELECT * FROM public.usp_search_employees_paged(
            p_search_term := 'a',
            p_department_id := v_dept_id,
            p_is_active := TRUE,
            p_page_number := 1,
            p_page_size := 10,
            p_sort_column := 'last_name',
            p_sort_direction := 'ASC'
        )
    LOOP
        v_total_count := v_rec.total_count;
        v_row_count := v_row_count + 1;
    END LOOP;
    
    RAISE NOTICE 'TC8|dept=%|%|Combined filters|rows=%', v_dept_id, v_total_count, v_row_count;
END $$;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 9: Page beyond total records =============
-- SETUP
-- No setup needed

-- EXEC & ASSERT
DO $$
DECLARE
    v_total_count INT;
    v_rec RECORD;
    v_row_count INT := 0;
BEGIN
    FOR v_rec IN 
        SELECT * FROM public.usp_search_employees_paged(
            p_search_term := NULL,
            p_department_id := NULL,
            p_is_active := NULL,
            p_page_number := 9999,
            p_page_size := 10,
            p_sort_column := 'employee_id',
            p_sort_direction := 'ASC'
        )
    LOOP
        v_total_count := v_rec.total_count;
        v_row_count := v_row_count + 1;
    END LOOP;
    
    RAISE NOTICE 'TC9|%|Page beyond total (should return 0 rows)|rows=%', COALESCE(v_total_count, 0), v_row_count;
END $$;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 10: Large page size =============
-- SETUP
-- No setup needed

-- EXEC & ASSERT
DO $$
DECLARE
    v_total_count INT;
    v_rec RECORD;
    v_row_count INT := 0;
BEGIN
    FOR v_rec IN 
        SELECT * FROM public.usp_search_employees_paged(
            p_search_term := NULL,
            p_department_id := NULL,
            p_is_active := NULL,
            p_page_number := 1,
            p_page_size := 100,
            p_sort_column := 'employee_id',
            p_sort_direction := 'ASC'
        )
    LOOP
        v_total_count := v_rec.total_count;
        v_row_count := v_row_count + 1;
    END LOOP;
    
    RAISE NOTICE 'TC10|%|Large page size (100)|rows=%', v_total_count, v_row_count;
END $$;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 11: Invalid page number (0) - Exception expected =============
-- SETUP
-- No setup needed

-- EXEC & ASSERT
DO $$
DECLARE
    v_rec RECORD;
    v_error_msg TEXT;
BEGIN
    BEGIN
        FOR v_rec IN 
            SELECT * FROM public.usp_search_employees_paged(
                p_search_term := NULL,
                p_department_id := NULL,
                p_is_active := NULL,
                p_page_number := 0,
                p_page_size := 10,
                p_sort_column := 'employee_id',
                p_sort_direction := 'ASC'
            )
        LOOP
            NULL;
        END LOOP;
        RAISE NOTICE 'TC11|NO_ERROR|Should have raised error for page_number=0';
    EXCEPTION
        WHEN OTHERS THEN
            v_error_msg := SQLERRM;
            RAISE NOTICE 'TC11|%|Expected error for page_number=0', v_error_msg;
    END;
END $$;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 12: Invalid page size (0) - Exception expected =============
-- SETUP
-- No setup needed

-- EXEC & ASSERT
DO $$
DECLARE
    v_rec RECORD;
    v_error_msg TEXT;
BEGIN
    BEGIN
        FOR v_rec IN 
            SELECT * FROM public.usp_search_employees_paged(
                p_search_term := NULL,
                p_department_id := NULL,
                p_is_active := NULL,
                p_page_number := 1,
                p_page_size := 0,
                p_sort_column := 'employee_id',
                p_sort_direction := 'ASC'
            )
        LOOP
            NULL;
        END LOOP;
        RAISE NOTICE 'TC12|NO_ERROR|Should have raised error for page_size=0';
    EXCEPTION
        WHEN OTHERS THEN
            v_error_msg := SQLERRM;
            RAISE NOTICE 'TC12|%|Expected error for page_size=0', v_error_msg;
    END;
END $$;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 13: Invalid page size (>1000) - Exception expected =============
-- SETUP
-- No setup needed

-- EXEC & ASSERT
DO $$
DECLARE
    v_rec RECORD;
    v_error_msg TEXT;
BEGIN
    BEGIN
        FOR v_rec IN 
            SELECT * FROM public.usp_search_employees_paged(
                p_search_term := NULL,
                p_department_id := NULL,
                p_is_active := NULL,
                p_page_number := 1,
                p_page_size := 1001,
                p_sort_column := 'employee_id',
                p_sort_direction := 'ASC'
            )
        LOOP
            NULL;
        END LOOP;
        RAISE NOTICE 'TC13|NO_ERROR|Should have raised error for page_size>1000';
    EXCEPTION
        WHEN OTHERS THEN
            v_error_msg := SQLERRM;
            RAISE NOTICE 'TC13|%|Expected error for page_size>1000', v_error_msg;
    END;
END $$;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 14: Invalid sort direction - Exception expected =============
-- SETUP
-- No setup needed

-- EXEC & ASSERT
DO $$
DECLARE
    v_rec RECORD;
    v_error_msg TEXT;
BEGIN
    BEGIN
        FOR v_rec IN 
            SELECT * FROM public.usp_search_employees_paged(
                p_search_term := NULL,
                p_department_id := NULL,
                p_is_active := NULL,
                p_page_number := 1,
                p_page_size := 10,
                p_sort_column := 'employee_id',
                p_sort_direction := 'INVALID'
            )
        LOOP
            NULL;
        END LOOP;
        RAISE NOTICE 'TC14|NO_ERROR|Should have raised error for invalid sort_direction';
    EXCEPTION
        WHEN OTHERS THEN
            v_error_msg := SQLERRM;
            RAISE NOTICE 'TC14|%|Expected error for invalid sort_direction', v_error_msg;
    END;
END $$;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 15: Invalid sort column - Exception expected =============
-- SETUP
-- No setup needed

-- EXEC & ASSERT
DO $$
DECLARE
    v_rec RECORD;
    v_error_msg TEXT;
BEGIN
    BEGIN
        FOR v_rec IN 
            SELECT * FROM public.usp_search_employees_paged(
                p_search_term := NULL,
                p_department_id := NULL,
                p_is_active := NULL,
                p_page_number := 1,
                p_page_size := 10,
                p_sort_column := 'invalid_column',
                p_sort_direction := 'ASC'
            )
        LOOP
            NULL;
        END LOOP;
        RAISE NOTICE 'TC15|NO_ERROR|Should have raised error for invalid sort_column';
    EXCEPTION
        WHEN OTHERS THEN
            v_error_msg := SQLERRM;
            RAISE NOTICE 'TC15|%|Expected error for invalid sort_column', v_error_msg;
    END;
END $$;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 16: Empty search term (should return all) =============
-- SETUP
-- No setup needed

-- EXEC & ASSERT
DO $$
DECLARE
    v_total_count INT;
    v_rec RECORD;
    v_row_count INT := 0;
BEGIN
    FOR v_rec IN 
        SELECT * FROM public.usp_search_employees_paged(
            p_search_term := '',
            p_department_id := NULL,
            p_is_active := NULL,
            p_page_number := 1,
            p_page_size := 10,
            p_sort_column := 'employee_id',
            p_sort_direction := 'ASC'
        )
    LOOP
        v_total_count := v_rec.total_count;
        v_row_count := v_row_count + 1;
    END LOOP;
    
    RAISE NOTICE 'TC16|%|Empty search term (should return all)|rows=%', v_total_count, v_row_count;
END $$;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 17: Search term with no matches =============
-- SETUP
-- No setup needed

-- EXEC & ASSERT
DO $$
DECLARE
    v_total_count INT;
    v_rec RECORD;
    v_row_count INT := 0;
BEGIN
    FOR v_rec IN 
        SELECT * FROM public.usp_search_employees_paged(
            p_search_term := 'ZZZZZZZZZ_NO_MATCH',
            p_department_id := NULL,
            p_is_active := NULL,
            p_page_number := 1,
            p_page_size := 10,
            p_sort_column := 'employee_id',
            p_sort_direction := 'ASC'
        )
    LOOP
        v_total_count := v_rec.total_count;
        v_row_count := v_row_count + 1;
    END LOOP;
    
    RAISE NOTICE 'TC17|%|Search with no matches (should return 0)|rows=%', COALESCE(v_total_count, 0), v_row_count;
END $$;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 18: Filter by inactive employees =============
-- SETUP
-- No setup needed

-- EXEC & ASSERT
DO $$
DECLARE
    v_total_count INT;
    v_rec RECORD;
    v_row_count INT := 0;
BEGIN
    FOR v_rec IN 
        SELECT * FROM public.usp_search_employees_paged(
            p_search_term := NULL,
            p_department_id := NULL,
            p_is_active := FALSE,
            p_page_number := 1,
            p_page_size := 10,
            p_sort_column := 'employee_id',
            p_sort_direction := 'ASC'
        )
    LOOP
        v_total_count := v_rec.total_count;
        v_row_count := v_row_count + 1;
    END LOOP;
    
    RAISE NOTICE 'TC18|%|Inactive employees only|rows=%', COALESCE(v_total_count, 0), v_row_count;
END $$;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 19: Non-existent department_id =============
-- SETUP
-- No setup needed

-- EXEC & ASSERT
DO $$
DECLARE
    v_total_count INT;
    v_rec RECORD;
    v_row_count INT := 0;
BEGIN
    FOR v_rec IN 
        SELECT * FROM public.usp_search_employees_paged(
            p_search_term := NULL,
            p_department_id := 99999,
            p_is_active := NULL,
            p_page_number := 1,
            p_page_size := 10,
            p_sort_column := 'employee_id',
            p_sort_direction := 'ASC'
        )
    LOOP
        v_total_count := v_rec.total_count;
        v_row_count := v_row_count + 1;
    END LOOP;
    
    RAISE NOTICE 'TC19|%|Non-existent department (should return 0)|rows=%', COALESCE(v_total_count, 0), v_row_count;
END $$;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 20: Sort by last_name DESC =============
-- SETUP
-- No setup needed

-- EXEC & ASSERT
DO $$
DECLARE
    v_total_count INT;
    v_rec RECORD;
    v_row_count INT := 0;
BEGIN
    FOR v_rec IN 
        SELECT * FROM public.usp_search_employees_paged(
            p_search_term := NULL,
            p_department_id := NULL,
            p_is_active := NULL,
            p_page_number := 1,
            p_page_size := 5,
            p_sort_column := 'last_name',
            p_sort_direction := 'DESC'
        )
    LOOP
        v_total_count := v_rec.total_count;
        v_row_count := v_row_count + 1;
    END LOOP;
    
    RAISE NOTICE 'TC20|%|Sort by last_name DESC|rows=%', v_total_count, v_row_count;
END $$;

-- CLEANUP
-- No cleanup needed

-- ============================================================================
-- End of Test Suite
-- ============================================================================
