-- ============================================================================
-- TEST SUITE FOR dbo.usp_dynamic_count_with_output
-- ============================================================================
-- This stored procedure uses dynamic SQL to count rows in a specified table
-- where a specified column matches a specified value.
-- It returns the count via an OUTPUT parameter.
-- ============================================================================

-- ============= TEST CASE 1: Normal case - exact match with multiple rows =============
-- SETUP
CREATE TABLE #test_products (
    product_id INT PRIMARY KEY,
    category NVARCHAR(50),
    product_name NVARCHAR(100)
);

INSERT INTO #test_products (product_id, category, product_name) VALUES
(1, N'Electronics', N'Laptop'),
(2, N'Electronics', N'Mouse'),
(3, N'Electronics', N'Keyboard'),
(4, N'Furniture', N'Chair'),
(5, N'Furniture', N'Desk');

-- EXEC
DECLARE @count1 INT;
EXEC dbo.usp_dynamic_count_with_output 
    @table_name = N'#test_products',
    @filter_column = N'category',
    @filter_value = N'Electronics',
    @row_count = @count1 OUTPUT;

-- ASSERT
SELECT 'TC1' AS tc, @count1 AS result, 'Expected: 3 Electronics items' AS description;

-- CLEANUP
DROP TABLE #test_products;

-- ============= TEST CASE 2: Normal case - single row match =============
-- SETUP
CREATE TABLE #test_employees (
    emp_id INT PRIMARY KEY,
    dept_name NVARCHAR(50),
    emp_name NVARCHAR(100)
);

INSERT INTO #test_employees (emp_id, dept_name, emp_name) VALUES
(1, N'IT', N'Alice'),
(2, N'HR', N'Bob'),
(3, N'IT', N'Charlie');

-- EXEC
DECLARE @count2 INT;
EXEC dbo.usp_dynamic_count_with_output 
    @table_name = N'#test_employees',
    @filter_column = N'dept_name',
    @filter_value = N'HR',
    @row_count = @count2 OUTPUT;

-- ASSERT
SELECT 'TC2' AS tc, @count2 AS result, 'Expected: 1 HR employee' AS description;

-- CLEANUP
DROP TABLE #test_employees;

-- ============= TEST CASE 3: Boundary - no matching rows =============
-- SETUP
CREATE TABLE #test_orders (
    order_id INT PRIMARY KEY,
    status NVARCHAR(50)
);

INSERT INTO #test_orders (order_id, status) VALUES
(1, N'Completed'),
(2, N'Completed'),
(3, N'Shipped');

-- EXEC
DECLARE @count3 INT;
EXEC dbo.usp_dynamic_count_with_output 
    @table_name = N'#test_orders',
    @filter_column = N'status',
    @filter_value = N'Pending',
    @row_count = @count3 OUTPUT;

-- ASSERT
SELECT 'TC3' AS tc, @count3 AS result, 'Expected: 0 (no Pending orders)' AS description;

-- CLEANUP
DROP TABLE #test_orders;

-- ============= TEST CASE 4: Boundary - empty table =============
-- SETUP
CREATE TABLE #test_empty (
    id INT PRIMARY KEY,
    name NVARCHAR(50)
);

-- EXEC
DECLARE @count4 INT;
EXEC dbo.usp_dynamic_count_with_output 
    @table_name = N'#test_empty',
    @filter_column = N'name',
    @filter_value = N'AnyValue',
    @row_count = @count4 OUTPUT;

-- ASSERT
SELECT 'TC4' AS tc, @count4 AS result, 'Expected: 0 (empty table)' AS description;

-- CLEANUP
DROP TABLE #test_empty;

-- ============= TEST CASE 5: Boundary - NULL filter value (no match expected) =============
-- SETUP
CREATE TABLE #test_nulls (
    id INT PRIMARY KEY,
    status NVARCHAR(50)
);

INSERT INTO #test_nulls (id, status) VALUES
(1, N'Active'),
(2, NULL),
(3, N'Inactive');

-- EXEC
DECLARE @count5 INT;
EXEC dbo.usp_dynamic_count_with_output 
    @table_name = N'#test_nulls',
    @filter_column = N'status',
    @filter_value = NULL,
    @row_count = @count5 OUTPUT;

-- ASSERT
SELECT 'TC5' AS tc, @count5 AS result, 'Expected: 0 (NULL = NULL is UNKNOWN in SQL)' AS description;

-- CLEANUP
DROP TABLE #test_nulls;

-- ============= TEST CASE 6: Normal - numeric column filter =============
-- SETUP
CREATE TABLE #test_numeric (
    id INT PRIMARY KEY,
    quantity INT,
    product NVARCHAR(50)
);

INSERT INTO #test_numeric (id, quantity, product) VALUES
(1, 100, N'Item A'),
(2, 200, N'Item B'),
(3, 100, N'Item C'),
(4, 100, N'Item D');

-- EXEC
DECLARE @count6 INT;
EXEC dbo.usp_dynamic_count_with_output 
    @table_name = N'#test_numeric',
    @filter_column = N'quantity',
    @filter_value = N'100',
    @row_count = @count6 OUTPUT;

-- ASSERT
SELECT 'TC6' AS tc, @count6 AS result, 'Expected: 3 (quantity=100)' AS description;

-- CLEANUP
DROP TABLE #test_numeric;

-- ============= TEST CASE 7: Boundary - all rows match =============
-- SETUP
CREATE TABLE #test_all_match (
    id INT PRIMARY KEY,
    type NVARCHAR(50)
);

INSERT INTO #test_all_match (id, type) VALUES
(1, N'TypeA'),
(2, N'TypeA'),
(3, N'TypeA'),
(4, N'TypeA');

-- EXEC
DECLARE @count7 INT;
EXEC dbo.usp_dynamic_count_with_output 
    @table_name = N'#test_all_match',
    @filter_column = N'type',
    @filter_value = N'TypeA',
    @row_count = @count7 OUTPUT;

-- ASSERT
SELECT 'TC7' AS tc, @count7 AS result, 'Expected: 4 (all rows match)' AS description;

-- CLEANUP
DROP TABLE #test_all_match;

-- ============= TEST CASE 8: Exception - invalid table name =============
-- SETUP
-- No setup needed

-- EXEC & ASSERT
BEGIN TRY
    DECLARE @count8 INT;
    EXEC dbo.usp_dynamic_count_with_output 
        @table_name = N'NonExistentTable',
        @filter_column = N'column1',
        @filter_value = N'value1',
        @row_count = @count8 OUTPUT;
    SELECT 'TC8' AS tc, 'NO_ERROR' AS result;
END TRY
BEGIN CATCH
    SELECT 'TC8' AS tc, ERROR_MESSAGE() AS result;
END CATCH

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 9: Exception - invalid column name =============
-- SETUP
CREATE TABLE #test_invalid_col (
    id INT PRIMARY KEY,
    valid_column NVARCHAR(50)
);

INSERT INTO #test_invalid_col (id, valid_column) VALUES (1, N'Value1');

-- EXEC & ASSERT
BEGIN TRY
    DECLARE @count9 INT;
    EXEC dbo.usp_dynamic_count_with_output 
        @table_name = N'#test_invalid_col',
        @filter_column = N'invalid_column',
        @filter_value = N'Value1',
        @row_count = @count9 OUTPUT;
    SELECT 'TC9' AS tc, 'NO_ERROR' AS result;
END TRY
BEGIN CATCH
    SELECT 'TC9' AS tc, ERROR_MESSAGE() AS result;
END CATCH

-- CLEANUP
DROP TABLE #test_invalid_col;

-- ============= TEST CASE 10: Normal - special characters in filter value =============
-- SETUP
CREATE TABLE #test_special (
    id INT PRIMARY KEY,
    description NVARCHAR(200)
);

INSERT INTO #test_special (id, description) VALUES
(1, N'Item with ''quotes'''),
(2, N'Normal item'),
(3, N'Item with ''quotes''');

-- EXEC
DECLARE @count10 INT;
EXEC dbo.usp_dynamic_count_with_output 
    @table_name = N'#test_special',
    @filter_column = N'description',
    @filter_value = N'Item with ''quotes''',
    @row_count = @count10 OUTPUT;

-- ASSERT
SELECT 'TC10' AS tc, @count10 AS result, 'Expected: 2 (items with quotes)' AS description;

-- CLEANUP
DROP TABLE #test_special;

-- ============= TEST CASE 11: Boundary - empty string filter value =============
-- SETUP
CREATE TABLE #test_empty_string (
    id INT PRIMARY KEY,
    code NVARCHAR(50)
);

INSERT INTO #test_empty_string (id, code) VALUES
(1, N''),
(2, N'ABC'),
(3, N''),
(4, N'XYZ');

-- EXEC
DECLARE @count11 INT;
EXEC dbo.usp_dynamic_count_with_output 
    @table_name = N'#test_empty_string',
    @filter_column = N'code',
    @filter_value = N'',
    @row_count = @count11 OUTPUT;

-- ASSERT
SELECT 'TC11' AS tc, @count11 AS result, 'Expected: 2 (empty string codes)' AS description;

-- CLEANUP
DROP TABLE #test_empty_string;

-- ============= TEST CASE 12: Normal - case sensitivity test =============
-- SETUP
CREATE TABLE #test_case (
    id INT PRIMARY KEY,
    status NVARCHAR(50)
);

INSERT INTO #test_case (id, status) VALUES
(1, N'Active'),
(2, N'ACTIVE'),
(3, N'active'),
(4, N'Inactive');

-- EXEC (depends on collation - typically case-insensitive in SQL Server)
DECLARE @count12 INT;
EXEC dbo.usp_dynamic_count_with_output 
    @table_name = N'#test_case',
    @filter_column = N'status',
    @filter_value = N'Active',
    @row_count = @count12 OUTPUT;

-- ASSERT
SELECT 'TC12' AS tc, @count12 AS result, 'Expected: 3 (case-insensitive match)' AS description;

-- CLEANUP
DROP TABLE #test_case;

-- ============================================================================
-- END OF TEST SUITE
-- ============================================================================
