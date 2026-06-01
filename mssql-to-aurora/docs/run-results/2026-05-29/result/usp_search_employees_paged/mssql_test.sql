-- ============================================================================
-- Test Suite for: dbo.usp_search_employees_paged
-- Purpose: Comprehensive testing of paged employee search functionality
-- ============================================================================

-- ============= TEST CASE 1: Basic pagination - First page =============
-- SETUP
DECLARE @total_count1 INT;

-- EXEC
EXEC dbo.usp_search_employees_paged
    @search_term = NULL,
    @department_id = NULL,
    @is_active = NULL,
    @page_number = 1,
    @page_size = 5,
    @sort_column = 'employee_id',
    @sort_direction = 'ASC',
    @total_count = @total_count1 OUTPUT;

-- ASSERT
SELECT 'TC1' AS test_case, @total_count1 AS total_count, 'First page with page_size=5' AS description;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 2: Second page pagination =============
-- SETUP
DECLARE @total_count2 INT;

-- EXEC
EXEC dbo.usp_search_employees_paged
    @search_term = NULL,
    @department_id = NULL,
    @is_active = NULL,
    @page_number = 2,
    @page_size = 5,
    @sort_column = 'employee_id',
    @sort_direction = 'ASC',
    @total_count = @total_count2 OUTPUT;

-- ASSERT
SELECT 'TC2' AS test_case, @total_count2 AS total_count, 'Second page with page_size=5' AS description;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 3: Search by name pattern =============
-- SETUP
DECLARE @total_count3 INT;

-- EXEC
EXEC dbo.usp_search_employees_paged
    @search_term = 'John',
    @department_id = NULL,
    @is_active = NULL,
    @page_number = 1,
    @page_size = 10,
    @sort_column = 'last_name',
    @sort_direction = 'ASC',
    @total_count = @total_count3 OUTPUT;

-- ASSERT
SELECT 'TC3' AS test_case, @total_count3 AS total_count, 'Search for John' AS description;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 4: Filter by department =============
-- SETUP
DECLARE @total_count4 INT;
DECLARE @dept_id INT;
SELECT TOP 1 @dept_id = department_id FROM dbo.departments ORDER BY department_id;

-- EXEC
EXEC dbo.usp_search_employees_paged
    @search_term = NULL,
    @department_id = @dept_id,
    @is_active = NULL,
    @page_number = 1,
    @page_size = 10,
    @sort_column = 'employee_id',
    @sort_direction = 'ASC',
    @total_count = @total_count4 OUTPUT;

-- ASSERT
SELECT 'TC4' AS test_case, @dept_id AS department_id, @total_count4 AS total_count, 'Filter by first department' AS description;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 5: Filter by active status =============
-- SETUP
DECLARE @total_count5 INT;

-- EXEC
EXEC dbo.usp_search_employees_paged
    @search_term = NULL,
    @department_id = NULL,
    @is_active = 1,
    @page_number = 1,
    @page_size = 10,
    @sort_column = 'employee_id',
    @sort_direction = 'ASC',
    @total_count = @total_count5 OUTPUT;

-- ASSERT
SELECT 'TC5' AS test_case, @total_count5 AS total_count, 'Active employees only' AS description;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 6: Sort by different column (salary DESC) =============
-- SETUP
DECLARE @total_count6 INT;

-- EXEC
EXEC dbo.usp_search_employees_paged
    @search_term = NULL,
    @department_id = NULL,
    @is_active = NULL,
    @page_number = 1,
    @page_size = 3,
    @sort_column = 'salary',
    @sort_direction = 'DESC',
    @total_count = @total_count6 OUTPUT;

-- ASSERT
SELECT 'TC6' AS test_case, @total_count6 AS total_count, 'Sort by salary DESC, top 3' AS description;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 7: Sort by hire_date ASC =============
-- SETUP
DECLARE @total_count7 INT;

-- EXEC
EXEC dbo.usp_search_employees_paged
    @search_term = NULL,
    @department_id = NULL,
    @is_active = NULL,
    @page_number = 1,
    @page_size = 5,
    @sort_column = 'hire_date',
    @sort_direction = 'ASC',
    @total_count = @total_count7 OUTPUT;

-- ASSERT
SELECT 'TC7' AS test_case, @total_count7 AS total_count, 'Sort by hire_date ASC' AS description;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 8: Combined filters (search + department + active) =============
-- SETUP
DECLARE @total_count8 INT;
DECLARE @dept_id8 INT;
SELECT TOP 1 @dept_id8 = department_id FROM dbo.departments ORDER BY department_id;

-- EXEC
EXEC dbo.usp_search_employees_paged
    @search_term = 'a',
    @department_id = @dept_id8,
    @is_active = 1,
    @page_number = 1,
    @page_size = 10,
    @sort_column = 'last_name',
    @sort_direction = 'ASC',
    @total_count = @total_count8 OUTPUT;

-- ASSERT
SELECT 'TC8' AS test_case, @dept_id8 AS department_id, @total_count8 AS total_count, 'Combined filters' AS description;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 9: Page beyond total records =============
-- SETUP
DECLARE @total_count9 INT;

-- EXEC
EXEC dbo.usp_search_employees_paged
    @search_term = NULL,
    @department_id = NULL,
    @is_active = NULL,
    @page_number = 9999,
    @page_size = 10,
    @sort_column = 'employee_id',
    @sort_direction = 'ASC',
    @total_count = @total_count9 OUTPUT;

-- ASSERT
SELECT 'TC9' AS test_case, @total_count9 AS total_count, 'Page beyond total (should return 0 rows)' AS description;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 10: Large page size =============
-- SETUP
DECLARE @total_count10 INT;

-- EXEC
EXEC dbo.usp_search_employees_paged
    @search_term = NULL,
    @department_id = NULL,
    @is_active = NULL,
    @page_number = 1,
    @page_size = 100,
    @sort_column = 'employee_id',
    @sort_direction = 'ASC',
    @total_count = @total_count10 OUTPUT;

-- ASSERT
SELECT 'TC10' AS test_case, @total_count10 AS total_count, 'Large page size (100)' AS description;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 11: Invalid page number (0) - Exception expected =============
-- SETUP
DECLARE @total_count11 INT;

-- EXEC & ASSERT
BEGIN TRY
    EXEC dbo.usp_search_employees_paged
        @search_term = NULL,
        @department_id = NULL,
        @is_active = NULL,
        @page_number = 0,
        @page_size = 10,
        @sort_column = 'employee_id',
        @sort_direction = 'ASC',
        @total_count = @total_count11 OUTPUT;
    SELECT 'TC11' AS test_case, 'NO_ERROR' AS result, 'Should have raised error for page_number=0' AS description;
END TRY
BEGIN CATCH
    SELECT 'TC11' AS test_case, ERROR_MESSAGE() AS result, 'Expected error for page_number=0' AS description;
END CATCH

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 12: Invalid page size (0) - Exception expected =============
-- SETUP
DECLARE @total_count12 INT;

-- EXEC & ASSERT
BEGIN TRY
    EXEC dbo.usp_search_employees_paged
        @search_term = NULL,
        @department_id = NULL,
        @is_active = NULL,
        @page_number = 1,
        @page_size = 0,
        @sort_column = 'employee_id',
        @sort_direction = 'ASC',
        @total_count = @total_count12 OUTPUT;
    SELECT 'TC12' AS test_case, 'NO_ERROR' AS result, 'Should have raised error for page_size=0' AS description;
END TRY
BEGIN CATCH
    SELECT 'TC12' AS test_case, ERROR_MESSAGE() AS result, 'Expected error for page_size=0' AS description;
END CATCH

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 13: Invalid page size (>1000) - Exception expected =============
-- SETUP
DECLARE @total_count13 INT;

-- EXEC & ASSERT
BEGIN TRY
    EXEC dbo.usp_search_employees_paged
        @search_term = NULL,
        @department_id = NULL,
        @is_active = NULL,
        @page_number = 1,
        @page_size = 1001,
        @sort_column = 'employee_id',
        @sort_direction = 'ASC',
        @total_count = @total_count13 OUTPUT;
    SELECT 'TC13' AS test_case, 'NO_ERROR' AS result, 'Should have raised error for page_size>1000' AS description;
END TRY
BEGIN CATCH
    SELECT 'TC13' AS test_case, ERROR_MESSAGE() AS result, 'Expected error for page_size>1000' AS description;
END CATCH

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 14: Invalid sort direction - Exception expected =============
-- SETUP
DECLARE @total_count14 INT;

-- EXEC & ASSERT
BEGIN TRY
    EXEC dbo.usp_search_employees_paged
        @search_term = NULL,
        @department_id = NULL,
        @is_active = NULL,
        @page_number = 1,
        @page_size = 10,
        @sort_column = 'employee_id',
        @sort_direction = 'INVALID',
        @total_count = @total_count14 OUTPUT;
    SELECT 'TC14' AS test_case, 'NO_ERROR' AS result, 'Should have raised error for invalid sort_direction' AS description;
END TRY
BEGIN CATCH
    SELECT 'TC14' AS test_case, ERROR_MESSAGE() AS result, 'Expected error for invalid sort_direction' AS description;
END CATCH

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 15: Invalid sort column - Exception expected =============
-- SETUP
DECLARE @total_count15 INT;

-- EXEC & ASSERT
BEGIN TRY
    EXEC dbo.usp_search_employees_paged
        @search_term = NULL,
        @department_id = NULL,
        @is_active = NULL,
        @page_number = 1,
        @page_size = 10,
        @sort_column = 'invalid_column',
        @sort_direction = 'ASC',
        @total_count = @total_count15 OUTPUT;
    SELECT 'TC15' AS test_case, 'NO_ERROR' AS result, 'Should have raised error for invalid sort_column' AS description;
END TRY
BEGIN CATCH
    SELECT 'TC15' AS test_case, ERROR_MESSAGE() AS result, 'Expected error for invalid sort_column' AS description;
END CATCH

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 16: Empty search term (should return all) =============
-- SETUP
DECLARE @total_count16 INT;

-- EXEC
EXEC dbo.usp_search_employees_paged
    @search_term = '',
    @department_id = NULL,
    @is_active = NULL,
    @page_number = 1,
    @page_size = 10,
    @sort_column = 'employee_id',
    @sort_direction = 'ASC',
    @total_count = @total_count16 OUTPUT;

-- ASSERT
SELECT 'TC16' AS test_case, @total_count16 AS total_count, 'Empty search term (should return all)' AS description;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 17: Search term with no matches =============
-- SETUP
DECLARE @total_count17 INT;

-- EXEC
EXEC dbo.usp_search_employees_paged
    @search_term = 'ZZZZZZZZZ_NO_MATCH',
    @department_id = NULL,
    @is_active = NULL,
    @page_number = 1,
    @page_size = 10,
    @sort_column = 'employee_id',
    @sort_direction = 'ASC',
    @total_count = @total_count17 OUTPUT;

-- ASSERT
SELECT 'TC17' AS test_case, @total_count17 AS total_count, 'Search with no matches (should return 0)' AS description;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 18: Filter by inactive employees =============
-- SETUP
DECLARE @total_count18 INT;

-- EXEC
EXEC dbo.usp_search_employees_paged
    @search_term = NULL,
    @department_id = NULL,
    @is_active = 0,
    @page_number = 1,
    @page_size = 10,
    @sort_column = 'employee_id',
    @sort_direction = 'ASC',
    @total_count = @total_count18 OUTPUT;

-- ASSERT
SELECT 'TC18' AS test_case, @total_count18 AS total_count, 'Inactive employees only' AS description;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 19: Non-existent department_id =============
-- SETUP
DECLARE @total_count19 INT;

-- EXEC
EXEC dbo.usp_search_employees_paged
    @search_term = NULL,
    @department_id = 99999,
    @is_active = NULL,
    @page_number = 1,
    @page_size = 10,
    @sort_column = 'employee_id',
    @sort_direction = 'ASC',
    @total_count = @total_count19 OUTPUT;

-- ASSERT
SELECT 'TC19' AS test_case, @total_count19 AS total_count, 'Non-existent department (should return 0)' AS description;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 20: Sort by last_name DESC =============
-- SETUP
DECLARE @total_count20 INT;

-- EXEC
EXEC dbo.usp_search_employees_paged
    @search_term = NULL,
    @department_id = NULL,
    @is_active = NULL,
    @page_number = 1,
    @page_size = 5,
    @sort_column = 'last_name',
    @sort_direction = 'DESC',
    @total_count = @total_count20 OUTPUT;

-- ASSERT
SELECT 'TC20' AS test_case, @total_count20 AS total_count, 'Sort by last_name DESC' AS description;

-- CLEANUP
-- No cleanup needed

-- ============================================================================
-- End of Test Suite
-- ============================================================================
