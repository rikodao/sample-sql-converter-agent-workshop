-- ============================================================================
-- TEST SUITE: dbo.usp_search_employees_paged (Babelfish)
-- ============================================================================
-- This test suite validates the paginated employee search stored procedure
-- covering normal cases, boundary conditions, and edge cases.
-- ============================================================================

-- ============= TEST CASE 1: Normal search with default pagination =============
-- SETUP
CREATE TABLE #tc1_result (
    employee_id INT,
    full_name NVARCHAR(200),
    department_name NVARCHAR(100),
    email NVARCHAR(100),
    row_num BIGINT
);

DECLARE @tc1_total INT;

-- EXEC
INSERT INTO #tc1_result
EXEC dbo.usp_search_employees_paged 
    @search_term = N'John',
    @page_no = 1,
    @page_size = 20,
    @total_rows = @tc1_total OUTPUT;

-- ASSERT
SELECT 'TC1' AS tc, 'total_rows' AS metric, @tc1_total AS result;
SELECT 'TC1' AS tc, 'result_count' AS metric, COUNT(*) AS result FROM #tc1_result;
SELECT 'TC1' AS tc, employee_id, full_name, department_name, email, row_num 
FROM #tc1_result 
ORDER BY row_num;

-- CLEANUP
DROP TABLE #tc1_result;
GO

-- ============= TEST CASE 2: Search with custom page size =============
-- SETUP
CREATE TABLE #tc2_result (
    employee_id INT,
    full_name NVARCHAR(200),
    department_name NVARCHAR(100),
    email NVARCHAR(100),
    row_num BIGINT
);

DECLARE @tc2_total INT;

-- EXEC
INSERT INTO #tc2_result
EXEC dbo.usp_search_employees_paged 
    @search_term = N'a',
    @page_no = 1,
    @page_size = 5,
    @total_rows = @tc2_total OUTPUT;

-- ASSERT
SELECT 'TC2' AS tc, 'total_rows' AS metric, @tc2_total AS result;
SELECT 'TC2' AS tc, 'result_count' AS metric, COUNT(*) AS result FROM #tc2_result;
SELECT 'TC2' AS tc, 'max_row_num' AS metric, MAX(row_num) AS result FROM #tc2_result;
SELECT 'TC2' AS tc, employee_id, full_name, department_name, email, row_num 
FROM #tc2_result 
ORDER BY row_num;

-- CLEANUP
DROP TABLE #tc2_result;
GO

-- ============= TEST CASE 3: Second page navigation =============
-- SETUP
CREATE TABLE #tc3_result (
    employee_id INT,
    full_name NVARCHAR(200),
    department_name NVARCHAR(100),
    email NVARCHAR(100),
    row_num BIGINT
);

DECLARE @tc3_total INT;

-- EXEC
INSERT INTO #tc3_result
EXEC dbo.usp_search_employees_paged 
    @search_term = N'a',
    @page_no = 2,
    @page_size = 3,
    @total_rows = @tc3_total OUTPUT;

-- ASSERT
SELECT 'TC3' AS tc, 'total_rows' AS metric, @tc3_total AS result;
SELECT 'TC3' AS tc, 'result_count' AS metric, COUNT(*) AS result FROM #tc3_result;
SELECT 'TC3' AS tc, 'min_row_num' AS metric, MIN(row_num) AS result FROM #tc3_result;
SELECT 'TC3' AS tc, employee_id, full_name, department_name, email, row_num 
FROM #tc3_result 
ORDER BY row_num;

-- CLEANUP
DROP TABLE #tc3_result;
GO

-- ============= TEST CASE 4: Search by email pattern =============
-- SETUP
CREATE TABLE #tc4_result (
    employee_id INT,
    full_name NVARCHAR(200),
    department_name NVARCHAR(100),
    email NVARCHAR(100),
    row_num BIGINT
);

DECLARE @tc4_total INT;

-- EXEC
INSERT INTO #tc4_result
EXEC dbo.usp_search_employees_paged 
    @search_term = N'@example.com',
    @page_no = 1,
    @page_size = 10,
    @total_rows = @tc4_total OUTPUT;

-- ASSERT
SELECT 'TC4' AS tc, 'total_rows' AS metric, @tc4_total AS result;
SELECT 'TC4' AS tc, 'result_count' AS metric, COUNT(*) AS result FROM #tc4_result;
SELECT 'TC4' AS tc, employee_id, full_name, department_name, email, row_num 
FROM #tc4_result 
ORDER BY row_num;

-- CLEANUP
DROP TABLE #tc4_result;
GO

-- ============= TEST CASE 5: Empty search term (matches all) =============
-- SETUP
CREATE TABLE #tc5_result (
    employee_id INT,
    full_name NVARCHAR(200),
    department_name NVARCHAR(100),
    email NVARCHAR(100),
    row_num BIGINT
);

DECLARE @tc5_total INT;

-- EXEC
INSERT INTO #tc5_result
EXEC dbo.usp_search_employees_paged 
    @search_term = N'',
    @page_no = 1,
    @page_size = 5,
    @total_rows = @tc5_total OUTPUT;

-- ASSERT
SELECT 'TC5' AS tc, 'total_rows' AS metric, @tc5_total AS result;
SELECT 'TC5' AS tc, 'result_count' AS metric, COUNT(*) AS result FROM #tc5_result;
SELECT 'TC5' AS tc, employee_id, full_name, department_name, email, row_num 
FROM #tc5_result 
ORDER BY row_num;

-- CLEANUP
DROP TABLE #tc5_result;
GO

-- ============= TEST CASE 6: No matches found =============
-- SETUP
CREATE TABLE #tc6_result (
    employee_id INT,
    full_name NVARCHAR(200),
    department_name NVARCHAR(100),
    email NVARCHAR(100),
    row_num BIGINT
);

DECLARE @tc6_total INT;

-- EXEC
INSERT INTO #tc6_result
EXEC dbo.usp_search_employees_paged 
    @search_term = N'ZZZZNONEXISTENT999',
    @page_no = 1,
    @page_size = 20,
    @total_rows = @tc6_total OUTPUT;

-- ASSERT
SELECT 'TC6' AS tc, 'total_rows' AS metric, @tc6_total AS result;
SELECT 'TC6' AS tc, 'result_count' AS metric, COUNT(*) AS result FROM #tc6_result;

-- CLEANUP
DROP TABLE #tc6_result;
GO

-- ============= TEST CASE 7: Page number beyond available pages =============
-- SETUP
CREATE TABLE #tc7_result (
    employee_id INT,
    full_name NVARCHAR(200),
    department_name NVARCHAR(100),
    email NVARCHAR(100),
    row_num BIGINT
);

DECLARE @tc7_total INT;

-- EXEC
INSERT INTO #tc7_result
EXEC dbo.usp_search_employees_paged 
    @search_term = N'John',
    @page_no = 999,
    @page_size = 20,
    @total_rows = @tc7_total OUTPUT;

-- ASSERT
SELECT 'TC7' AS tc, 'total_rows' AS metric, @tc7_total AS result;
SELECT 'TC7' AS tc, 'result_count' AS metric, COUNT(*) AS result FROM #tc7_result;

-- CLEANUP
DROP TABLE #tc7_result;
GO

-- ============= TEST CASE 8: Page size of 1 (minimum pagination) =============
-- SETUP
CREATE TABLE #tc8_result (
    employee_id INT,
    full_name NVARCHAR(200),
    department_name NVARCHAR(100),
    email NVARCHAR(100),
    row_num BIGINT
);

DECLARE @tc8_total INT;

-- EXEC
INSERT INTO #tc8_result
EXEC dbo.usp_search_employees_paged 
    @search_term = N'a',
    @page_no = 1,
    @page_size = 1,
    @total_rows = @tc8_total OUTPUT;

-- ASSERT
SELECT 'TC8' AS tc, 'total_rows' AS metric, @tc8_total AS result;
SELECT 'TC8' AS tc, 'result_count' AS metric, COUNT(*) AS result FROM #tc8_result;
SELECT 'TC8' AS tc, employee_id, full_name, department_name, email, row_num 
FROM #tc8_result;

-- CLEANUP
DROP TABLE #tc8_result;
GO

-- ============= TEST CASE 9: Large page size (exceeds total rows) =============
-- SETUP
CREATE TABLE #tc9_result (
    employee_id INT,
    full_name NVARCHAR(200),
    department_name NVARCHAR(100),
    email NVARCHAR(100),
    row_num BIGINT
);

DECLARE @tc9_total INT;

-- EXEC
INSERT INTO #tc9_result
EXEC dbo.usp_search_employees_paged 
    @search_term = N'John',
    @page_no = 1,
    @page_size = 1000,
    @total_rows = @tc9_total OUTPUT;

-- ASSERT
SELECT 'TC9' AS tc, 'total_rows' AS metric, @tc9_total AS result;
SELECT 'TC9' AS tc, 'result_count' AS metric, COUNT(*) AS result FROM #tc9_result;
SELECT 'TC9' AS tc, 'matches_total' AS metric, 
    CASE WHEN COUNT(*) = @tc9_total THEN 1 ELSE 0 END AS result 
FROM #tc9_result;

-- CLEANUP
DROP TABLE #tc9_result;
GO

-- ============= TEST CASE 10: Case-insensitive search =============
-- SETUP
CREATE TABLE #tc10_result (
    employee_id INT,
    full_name NVARCHAR(200),
    department_name NVARCHAR(100),
    email NVARCHAR(100),
    row_num BIGINT
);

DECLARE @tc10_total INT;

-- EXEC (search with lowercase)
INSERT INTO #tc10_result
EXEC dbo.usp_search_employees_paged 
    @search_term = N'john',
    @page_no = 1,
    @page_size = 20,
    @total_rows = @tc10_total OUTPUT;

-- ASSERT
SELECT 'TC10' AS tc, 'total_rows' AS metric, @tc10_total AS result;
SELECT 'TC10' AS tc, 'result_count' AS metric, COUNT(*) AS result FROM #tc10_result;
SELECT 'TC10' AS tc, employee_id, full_name, department_name, email, row_num 
FROM #tc10_result 
ORDER BY row_num;

-- CLEANUP
DROP TABLE #tc10_result;
GO

-- ============= TEST CASE 11: Search with special characters =============
-- SETUP
CREATE TABLE #tc11_result (
    employee_id INT,
    full_name NVARCHAR(200),
    department_name NVARCHAR(100),
    email NVARCHAR(100),
    row_num BIGINT
);

DECLARE @tc11_total INT;

-- EXEC
INSERT INTO #tc11_result
EXEC dbo.usp_search_employees_paged 
    @search_term = N'%',
    @page_no = 1,
    @page_size = 5,
    @total_rows = @tc11_total OUTPUT;

-- ASSERT
SELECT 'TC11' AS tc, 'total_rows' AS metric, @tc11_total AS result;
SELECT 'TC11' AS tc, 'result_count' AS metric, COUNT(*) AS result FROM #tc11_result;

-- CLEANUP
DROP TABLE #tc11_result;
GO

-- ============= TEST CASE 12: Zero page number (boundary) =============
-- SETUP
CREATE TABLE #tc12_result (
    employee_id INT,
    full_name NVARCHAR(200),
    department_name NVARCHAR(100),
    email NVARCHAR(100),
    row_num BIGINT
);

DECLARE @tc12_total INT;

-- EXEC
BEGIN TRY
    INSERT INTO #tc12_result
    EXEC dbo.usp_search_employees_paged 
        @search_term = N'a',
        @page_no = 0,
        @page_size = 5,
        @total_rows = @tc12_total OUTPUT;
    
    SELECT 'TC12' AS tc, 'error' AS metric, 'NO_ERROR' AS result;
    SELECT 'TC12' AS tc, 'total_rows' AS metric, @tc12_total AS result;
    SELECT 'TC12' AS tc, 'result_count' AS metric, COUNT(*) AS result FROM #tc12_result;
END TRY
BEGIN CATCH
    SELECT 'TC12' AS tc, 'error' AS metric, ERROR_MESSAGE() AS result;
END CATCH

-- CLEANUP
DROP TABLE #tc12_result;
GO

-- ============= TEST CASE 13: Negative page number (exception) =============
-- SETUP
CREATE TABLE #tc13_result (
    employee_id INT,
    full_name NVARCHAR(200),
    department_name NVARCHAR(100),
    email NVARCHAR(100),
    row_num BIGINT
);

DECLARE @tc13_total INT;

-- EXEC
BEGIN TRY
    INSERT INTO #tc13_result
    EXEC dbo.usp_search_employees_paged 
        @search_term = N'a',
        @page_no = -1,
        @page_size = 5,
        @total_rows = @tc13_total OUTPUT;
    
    SELECT 'TC13' AS tc, 'error' AS metric, 'NO_ERROR' AS result;
    SELECT 'TC13' AS tc, 'total_rows' AS metric, @tc13_total AS result;
    SELECT 'TC13' AS tc, 'result_count' AS metric, COUNT(*) AS result FROM #tc13_result;
END TRY
BEGIN CATCH
    SELECT 'TC13' AS tc, 'error' AS metric, ERROR_MESSAGE() AS result;
END CATCH

-- CLEANUP
DROP TABLE #tc13_result;
GO

-- ============= TEST CASE 14: NULL search term (exception expected) =============
-- SETUP
CREATE TABLE #tc14_result (
    employee_id INT,
    full_name NVARCHAR(200),
    department_name NVARCHAR(100),
    email NVARCHAR(100),
    row_num BIGINT
);

DECLARE @tc14_total INT;

-- EXEC
BEGIN TRY
    INSERT INTO #tc14_result
    EXEC dbo.usp_search_employees_paged 
        @search_term = NULL,
        @page_no = 1,
        @page_size = 5,
        @total_rows = @tc14_total OUTPUT;
    
    SELECT 'TC14' AS tc, 'error' AS metric, 'NO_ERROR' AS result;
    SELECT 'TC14' AS tc, 'total_rows' AS metric, ISNULL(@tc14_total, -1) AS result;
    SELECT 'TC14' AS tc, 'result_count' AS metric, COUNT(*) AS result FROM #tc14_result;
END TRY
BEGIN CATCH
    SELECT 'TC14' AS tc, 'error' AS metric, ERROR_MESSAGE() AS result;
END CATCH

-- CLEANUP
DROP TABLE #tc14_result;
GO

-- ============= TEST CASE 15: Verify row_num ordering consistency =============
-- SETUP
CREATE TABLE #tc15_result (
    employee_id INT,
    full_name NVARCHAR(200),
    department_name NVARCHAR(100),
    email NVARCHAR(100),
    row_num BIGINT
);

DECLARE @tc15_total INT;

-- EXEC (get first page)
INSERT INTO #tc15_result
EXEC dbo.usp_search_employees_paged 
    @search_term = N'a',
    @page_no = 1,
    @page_size = 3,
    @total_rows = @tc15_total OUTPUT;

-- ASSERT (verify row_num starts at 1 and is sequential)
SELECT 'TC15' AS tc, 'min_row_num' AS metric, MIN(row_num) AS result FROM #tc15_result;
SELECT 'TC15' AS tc, 'max_row_num' AS metric, MAX(row_num) AS result FROM #tc15_result;
SELECT 'TC15' AS tc, 'is_sequential' AS metric, 
    CASE WHEN MAX(row_num) - MIN(row_num) + 1 = COUNT(*) THEN 1 ELSE 0 END AS result 
FROM #tc15_result;

-- CLEANUP
DROP TABLE #tc15_result;
GO
