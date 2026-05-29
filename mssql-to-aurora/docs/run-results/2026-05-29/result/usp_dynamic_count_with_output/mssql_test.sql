-- ============================================================================
-- Test Suite for: dbo.usp_dynamic_count_with_output
-- Database: SQL Server
-- ============================================================================
-- This test suite covers:
-- - Normal cases: valid table names with/without WHERE clause
-- - Boundary cases: NULL inputs, empty strings, non-existent tables
-- - Exception cases: SQL injection attempts, invalid WHERE clauses
-- - OUTPUT parameter validation
-- ============================================================================

-- ============= TEST CASE 1: Count all records from employees table =============
-- SETUP
-- (No setup needed - using existing employees table)

-- EXEC
DECLARE @count1 INT;
EXEC dbo.usp_dynamic_count_with_output 
    @table_name = 'employees',
    @where_clause = NULL,
    @record_count = @count1 OUTPUT;

-- ASSERT
SELECT 'TC1' AS tc, @count1 AS output_count, 'Count all employees' AS description;

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 2: Count with WHERE clause (active employees) =============
-- SETUP
-- (No setup needed)

-- EXEC
DECLARE @count2 INT;
EXEC dbo.usp_dynamic_count_with_output 
    @table_name = 'employees',
    @where_clause = 'is_active = 1',
    @record_count = @count2 OUTPUT;

-- ASSERT
SELECT 'TC2' AS tc, @count2 AS output_count, 'Count active employees' AS description;

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 3: Count from departments table =============
-- SETUP
-- (No setup needed)

-- EXEC
DECLARE @count3 INT;
EXEC dbo.usp_dynamic_count_with_output 
    @table_name = 'departments',
    @where_clause = NULL,
    @record_count = @count3 OUTPUT;

-- ASSERT
SELECT 'TC3' AS tc, @count3 AS output_count, 'Count all departments' AS description;

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 4: Count with complex WHERE clause =============
-- SETUP
-- (No setup needed)

-- EXEC
DECLARE @count4 INT;
EXEC dbo.usp_dynamic_count_with_output 
    @table_name = 'employees',
    @where_clause = 'salary > 50000 AND department_id = 1',
    @record_count = @count4 OUTPUT;

-- ASSERT
SELECT 'TC4' AS tc, @count4 AS output_count, 'Count employees with salary > 50000 in dept 1' AS description;

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 5: NULL table name (should raise error) =============
-- SETUP
-- (No setup needed)

-- EXEC & ASSERT
BEGIN TRY
    DECLARE @count5 INT;
    EXEC dbo.usp_dynamic_count_with_output 
        @table_name = NULL,
        @where_clause = NULL,
        @record_count = @count5 OUTPUT;
    SELECT 'TC5' AS tc, 'NO_ERROR' AS result, @count5 AS output_count;
END TRY
BEGIN CATCH
    SELECT 'TC5' AS tc, 'ERROR_CAUGHT' AS result, ERROR_MESSAGE() AS error_message;
END CATCH

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 6: Empty string table name (should raise error) =============
-- SETUP
-- (No setup needed)

-- EXEC & ASSERT
BEGIN TRY
    DECLARE @count6 INT;
    EXEC dbo.usp_dynamic_count_with_output 
        @table_name = '',
        @where_clause = NULL,
        @record_count = @count6 OUTPUT;
    SELECT 'TC6' AS tc, 'NO_ERROR' AS result, @count6 AS output_count;
END TRY
BEGIN CATCH
    SELECT 'TC6' AS tc, 'ERROR_CAUGHT' AS result, ERROR_MESSAGE() AS error_message;
END CATCH

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 7: Non-existent table (should raise error) =============
-- SETUP
-- (No setup needed)

-- EXEC & ASSERT
BEGIN TRY
    DECLARE @count7 INT;
    EXEC dbo.usp_dynamic_count_with_output 
        @table_name = 'non_existent_table_xyz',
        @where_clause = NULL,
        @record_count = @count7 OUTPUT;
    SELECT 'TC7' AS tc, 'NO_ERROR' AS result, @count7 AS output_count;
END TRY
BEGIN CATCH
    SELECT 'TC7' AS tc, 'ERROR_CAUGHT' AS result, ERROR_MESSAGE() AS error_message;
END CATCH

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 8: Whitespace-only table name (should raise error) =============
-- SETUP
-- (No setup needed)

-- EXEC & ASSERT
BEGIN TRY
    DECLARE @count8 INT;
    EXEC dbo.usp_dynamic_count_with_output 
        @table_name = '   ',
        @where_clause = NULL,
        @record_count = @count8 OUTPUT;
    SELECT 'TC8' AS tc, 'NO_ERROR' AS result, @count8 AS output_count;
END TRY
BEGIN CATCH
    SELECT 'TC8' AS tc, 'ERROR_CAUGHT' AS result, ERROR_MESSAGE() AS error_message;
END CATCH

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 9: Table name with leading/trailing spaces =============
-- SETUP
-- (No setup needed)

-- EXEC
DECLARE @count9 INT;
EXEC dbo.usp_dynamic_count_with_output 
    @table_name = '  employees  ',
    @where_clause = NULL,
    @record_count = @count9 OUTPUT;

-- ASSERT
SELECT 'TC9' AS tc, @count9 AS output_count, 'Table name with spaces should be trimmed' AS description;

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 10: Empty WHERE clause (should count all) =============
-- SETUP
-- (No setup needed)

-- EXEC
DECLARE @count10 INT;
EXEC dbo.usp_dynamic_count_with_output 
    @table_name = 'employees',
    @where_clause = '',
    @record_count = @count10 OUTPUT;

-- ASSERT
SELECT 'TC10' AS tc, @count10 AS output_count, 'Empty WHERE clause should count all' AS description;

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 11: WHERE clause with no matching records =============
-- SETUP
-- (No setup needed)

-- EXEC
DECLARE @count11 INT;
EXEC dbo.usp_dynamic_count_with_output 
    @table_name = 'employees',
    @where_clause = 'employee_id = -999999',
    @record_count = @count11 OUTPUT;

-- ASSERT
SELECT 'TC11' AS tc, @count11 AS output_count, 'No matching records should return 0' AS description;

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 12: Invalid WHERE clause syntax (should raise error) =============
-- SETUP
-- (No setup needed)

-- EXEC & ASSERT
BEGIN TRY
    DECLARE @count12 INT;
    EXEC dbo.usp_dynamic_count_with_output 
        @table_name = 'employees',
        @where_clause = 'invalid syntax here @#$',
        @record_count = @count12 OUTPUT;
    SELECT 'TC12' AS tc, 'NO_ERROR' AS result, @count12 AS output_count;
END TRY
BEGIN CATCH
    SELECT 'TC12' AS tc, 'ERROR_CAUGHT' AS result, ERROR_MESSAGE() AS error_message;
END CATCH

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 13: SQL injection attempt in table name (should be prevented) =============
-- SETUP
-- (No setup needed)

-- EXEC & ASSERT
BEGIN TRY
    DECLARE @count13 INT;
    EXEC dbo.usp_dynamic_count_with_output 
        @table_name = 'employees; DROP TABLE employees; --',
        @where_clause = NULL,
        @record_count = @count13 OUTPUT;
    SELECT 'TC13' AS tc, 'NO_ERROR' AS result, @count13 AS output_count;
END TRY
BEGIN CATCH
    SELECT 'TC13' AS tc, 'ERROR_CAUGHT' AS result, ERROR_MESSAGE() AS error_message;
END CATCH

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 14: Count with IS NULL condition =============
-- SETUP
-- (No setup needed)

-- EXEC
DECLARE @count14 INT;
EXEC dbo.usp_dynamic_count_with_output 
    @table_name = 'employees',
    @where_clause = 'manager_id IS NULL',
    @record_count = @count14 OUTPUT;

-- ASSERT
SELECT 'TC14' AS tc, @count14 AS output_count, 'Count employees with NULL manager_id' AS description;

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 15: Count with date comparison =============
-- SETUP
-- (No setup needed)

-- EXEC
DECLARE @count15 INT;
EXEC dbo.usp_dynamic_count_with_output 
    @table_name = 'employees',
    @where_clause = 'hire_date >= ''2020-01-01''',
    @record_count = @count15 OUTPUT;

-- ASSERT
SELECT 'TC15' AS tc, @count15 AS output_count, 'Count employees hired since 2020' AS description;

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 16: Verify OUTPUT parameter is set to -1 on error =============
-- SETUP
-- (No setup needed)

-- EXEC & ASSERT
BEGIN TRY
    DECLARE @count16 INT = 999; -- Initialize to non-zero value
    EXEC dbo.usp_dynamic_count_with_output 
        @table_name = 'non_existent_table',
        @where_clause = NULL,
        @record_count = @count16 OUTPUT;
    SELECT 'TC16' AS tc, @count16 AS output_count, 'Should be -1 on error' AS description;
END TRY
BEGIN CATCH
    SELECT 'TC16' AS tc, @count16 AS output_count, 'Error caught, output should be -1' AS description;
END CATCH

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 17: Count with LIKE pattern =============
-- SETUP
-- (No setup needed)

-- EXEC
DECLARE @count17 INT;
EXEC dbo.usp_dynamic_count_with_output 
    @table_name = 'employees',
    @where_clause = 'first_name LIKE ''J%''',
    @record_count = @count17 OUTPUT;

-- ASSERT
SELECT 'TC17' AS tc, @count17 AS output_count, 'Count employees with first name starting with J' AS description;

-- CLEANUP
-- (No cleanup needed)


-- ============= TEST CASE 18: Count with IN clause =============
-- SETUP
-- (No setup needed)

-- EXEC
DECLARE @count18 INT;
EXEC dbo.usp_dynamic_count_with_output 
    @table_name = 'employees',
    @where_clause = 'department_id IN (1, 2, 3)',
    @record_count = @count18 OUTPUT;

-- ASSERT
SELECT 'TC18' AS tc, @count18 AS output_count, 'Count employees in departments 1, 2, 3' AS description;

-- CLEANUP
-- (No cleanup needed)


-- ============================================================================
-- End of Test Suite
-- ============================================================================
