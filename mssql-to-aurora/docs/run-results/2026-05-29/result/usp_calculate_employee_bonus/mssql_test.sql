-- ============================================================================
-- Test Suite for: dbo.usp_calculate_employee_bonus
-- ============================================================================
-- Purpose: Comprehensive test coverage for employee bonus calculation procedure
-- Test Categories:
--   - Normal cases (various performance ratings)
--   - Boundary cases (NULL values, zero salary, minimum employment)
--   - Exception cases (invalid parameters, no eligible employees)
--   - Transaction behavior (rollback on error)
--   - Side effects (UPDATE counts, OUTPUT parameters)
-- ============================================================================

-- ============================================================================
-- TEST CASE 1: Normal case - Calculate bonus for employee with rating 5
-- ============================================================================
-- SETUP
CREATE TABLE #test_employees_tc1 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    salary DECIMAL(18,2),
    performance_rating INT,
    hire_date DATE,
    is_active BIT,
    bonus_amount DECIMAL(18,2),
    last_bonus_date DATETIME,
    bonus_fiscal_year INT
);

INSERT INTO #test_employees_tc1 (employee_id, first_name, last_name, salary, performance_rating, hire_date, is_active, bonus_amount, last_bonus_date, bonus_fiscal_year)
VALUES (1001, 'John', 'Doe', 100000.00, 5, '2023-01-01', 1, 0.00, NULL, NULL);

-- EXEC
DECLARE @count1 INT, @total1 DECIMAL(18,2);
EXEC dbo.usp_calculate_employee_bonus 
    @employee_id = 1001,
    @fiscal_year = 2024,
    @calculated_count = @count1 OUTPUT,
    @total_bonus_amount = @total1 OUTPUT;

-- ASSERT
SELECT 'TC1' AS test_case, 
       @count1 AS calculated_count,
       @total1 AS total_bonus_amount,
       (SELECT bonus_amount FROM #test_employees_tc1 WHERE employee_id = 1001) AS employee_bonus,
       CASE WHEN @total1 = 15000.00 THEN 'PASS' ELSE 'FAIL' END AS result;

-- CLEANUP
DROP TABLE #test_employees_tc1;

-- ============================================================================
-- TEST CASE 2: Normal case - Calculate bonus for employee with rating 4
-- ============================================================================
-- SETUP
CREATE TABLE #test_employees_tc2 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    salary DECIMAL(18,2),
    performance_rating INT,
    hire_date DATE,
    is_active BIT,
    bonus_amount DECIMAL(18,2),
    last_bonus_date DATETIME,
    bonus_fiscal_year INT
);

INSERT INTO #test_employees_tc2 (employee_id, first_name, last_name, salary, performance_rating, hire_date, is_active, bonus_amount, last_bonus_date, bonus_fiscal_year)
VALUES (1002, 'Jane', 'Smith', 80000.00, 4, '2023-01-01', 1, 0.00, NULL, NULL);

-- EXEC
DECLARE @count2 INT, @total2 DECIMAL(18,2);
EXEC dbo.usp_calculate_employee_bonus 
    @employee_id = 1002,
    @fiscal_year = 2024,
    @calculated_count = @count2 OUTPUT,
    @total_bonus_amount = @total2 OUTPUT;

-- ASSERT
SELECT 'TC2' AS test_case,
       @count2 AS calculated_count,
       @total2 AS total_bonus_amount,
       (SELECT bonus_amount FROM #test_employees_tc2 WHERE employee_id = 1002) AS employee_bonus,
       CASE WHEN @total2 = 8000.00 THEN 'PASS' ELSE 'FAIL' END AS result;

-- CLEANUP
DROP TABLE #test_employees_tc2;

-- ============================================================================
-- TEST CASE 3: Normal case - Calculate bonus for employee with rating 3
-- ============================================================================
-- SETUP
CREATE TABLE #test_employees_tc3 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    salary DECIMAL(18,2),
    performance_rating INT,
    hire_date DATE,
    is_active BIT,
    bonus_amount DECIMAL(18,2),
    last_bonus_date DATETIME,
    bonus_fiscal_year INT
);

INSERT INTO #test_employees_tc3 (employee_id, first_name, last_name, salary, performance_rating, hire_date, is_active, bonus_amount, last_bonus_date, bonus_fiscal_year)
VALUES (1003, 'Bob', 'Johnson', 60000.00, 3, '2023-01-01', 1, 0.00, NULL, NULL);

-- EXEC
DECLARE @count3 INT, @total3 DECIMAL(18,2);
EXEC dbo.usp_calculate_employee_bonus 
    @employee_id = 1003,
    @fiscal_year = 2024,
    @calculated_count = @count3 OUTPUT,
    @total_bonus_amount = @total3 OUTPUT;

-- ASSERT
SELECT 'TC3' AS test_case,
       @count3 AS calculated_count,
       @total3 AS total_bonus_amount,
       (SELECT bonus_amount FROM #test_employees_tc3 WHERE employee_id = 1003) AS employee_bonus,
       CASE WHEN @total3 = 3000.00 THEN 'PASS' ELSE 'FAIL' END AS result;

-- CLEANUP
DROP TABLE #test_employees_tc3;

-- ============================================================================
-- TEST CASE 4: Boundary case - NULL performance rating (should default to 0)
-- ============================================================================
-- SETUP
CREATE TABLE #test_employees_tc4 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    salary DECIMAL(18,2),
    performance_rating INT,
    hire_date DATE,
    is_active BIT,
    bonus_amount DECIMAL(18,2),
    last_bonus_date DATETIME,
    bonus_fiscal_year INT
);

INSERT INTO #test_employees_tc4 (employee_id, first_name, last_name, salary, performance_rating, hire_date, is_active, bonus_amount, last_bonus_date, bonus_fiscal_year)
VALUES (1004, 'Alice', 'Williams', 70000.00, NULL, '2023-01-01', 1, 0.00, NULL, NULL);

-- EXEC
DECLARE @count4 INT, @total4 DECIMAL(18,2);
EXEC dbo.usp_calculate_employee_bonus 
    @employee_id = 1004,
    @fiscal_year = 2024,
    @calculated_count = @count4 OUTPUT,
    @total_bonus_amount = @total4 OUTPUT;

-- ASSERT
SELECT 'TC4' AS test_case,
       @count4 AS calculated_count,
       @total4 AS total_bonus_amount,
       CASE WHEN @total4 = 0.00 THEN 'PASS' ELSE 'FAIL' END AS result;

-- CLEANUP
DROP TABLE #test_employees_tc4;

-- ============================================================================
-- TEST CASE 5: Boundary case - Rating 2 (minimal bonus)
-- ============================================================================
-- SETUP
CREATE TABLE #test_employees_tc5 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    salary DECIMAL(18,2),
    performance_rating INT,
    hire_date DATE,
    is_active BIT,
    bonus_amount DECIMAL(18,2),
    last_bonus_date DATETIME,
    bonus_fiscal_year INT
);

INSERT INTO #test_employees_tc5 (employee_id, first_name, last_name, salary, performance_rating, hire_date, is_active, bonus_amount, last_bonus_date, bonus_fiscal_year)
VALUES (1005, 'Charlie', 'Brown', 50000.00, 2, '2023-01-01', 1, 0.00, NULL, NULL);

-- EXEC
DECLARE @count5 INT, @total5 DECIMAL(18,2);
EXEC dbo.usp_calculate_employee_bonus 
    @employee_id = 1005,
    @fiscal_year = 2024,
    @calculated_count = @count5 OUTPUT,
    @total_bonus_amount = @total5 OUTPUT;

-- ASSERT
SELECT 'TC5' AS test_case,
       @count5 AS calculated_count,
       @total5 AS total_bonus_amount,
       CASE WHEN @total5 = 1000.00 THEN 'PASS' ELSE 'FAIL' END AS result;

-- CLEANUP
DROP TABLE #test_employees_tc5;

-- ============================================================================
-- TEST CASE 6: Boundary case - Rating 1 (no bonus)
-- ============================================================================
-- SETUP
CREATE TABLE #test_employees_tc6 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    salary DECIMAL(18,2),
    performance_rating INT,
    hire_date DATE,
    is_active BIT,
    bonus_amount DECIMAL(18,2),
    last_bonus_date DATETIME,
    bonus_fiscal_year INT
);

INSERT INTO #test_employees_tc6 (employee_id, first_name, last_name, salary, performance_rating, hire_date, is_active, bonus_amount, last_bonus_date, bonus_fiscal_year)
VALUES (1006, 'David', 'Davis', 55000.00, 1, '2023-01-01', 1, 0.00, NULL, NULL);

-- EXEC
DECLARE @count6 INT, @total6 DECIMAL(18,2);
EXEC dbo.usp_calculate_employee_bonus 
    @employee_id = 1006,
    @fiscal_year = 2024,
    @calculated_count = @count6 OUTPUT,
    @total_bonus_amount = @total6 OUTPUT;

-- ASSERT
SELECT 'TC6' AS test_case,
       @count6 AS calculated_count,
       @total6 AS total_bonus_amount,
       CASE WHEN @total6 = 0.00 THEN 'PASS' ELSE 'FAIL' END AS result;

-- CLEANUP
DROP TABLE #test_employees_tc6;

-- ============================================================================
-- TEST CASE 7: Boundary case - Employee hired less than 6 months ago (ineligible)
-- ============================================================================
-- SETUP
CREATE TABLE #test_employees_tc7 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    salary DECIMAL(18,2),
    performance_rating INT,
    hire_date DATE,
    is_active BIT,
    bonus_amount DECIMAL(18,2),
    last_bonus_date DATETIME,
    bonus_fiscal_year INT
);

INSERT INTO #test_employees_tc7 (employee_id, first_name, last_name, salary, performance_rating, hire_date, is_active, bonus_amount, last_bonus_date, bonus_fiscal_year)
VALUES (1007, 'Eve', 'Miller', 65000.00, 4, DATEADD(DAY, -100, GETDATE()), 1, 0.00, NULL, NULL);

-- EXEC
DECLARE @count7 INT, @total7 DECIMAL(18,2);
EXEC dbo.usp_calculate_employee_bonus 
    @employee_id = 1007,
    @fiscal_year = 2024,
    @calculated_count = @count7 OUTPUT,
    @total_bonus_amount = @total7 OUTPUT;

-- ASSERT
SELECT 'TC7' AS test_case,
       @count7 AS calculated_count,
       @total7 AS total_bonus_amount,
       CASE WHEN @count7 = 0 THEN 'PASS' ELSE 'FAIL' END AS result;

-- CLEANUP
DROP TABLE #test_employees_tc7;

-- ============================================================================
-- TEST CASE 8: Boundary case - Inactive employee (should be excluded)
-- ============================================================================
-- SETUP
CREATE TABLE #test_employees_tc8 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    salary DECIMAL(18,2),
    performance_rating INT,
    hire_date DATE,
    is_active BIT,
    bonus_amount DECIMAL(18,2),
    last_bonus_date DATETIME,
    bonus_fiscal_year INT
);

INSERT INTO #test_employees_tc8 (employee_id, first_name, last_name, salary, performance_rating, hire_date, is_active, bonus_amount, last_bonus_date, bonus_fiscal_year)
VALUES (1008, 'Frank', 'Wilson', 75000.00, 5, '2023-01-01', 0, 0.00, NULL, NULL);

-- EXEC
DECLARE @count8 INT, @total8 DECIMAL(18,2);
EXEC dbo.usp_calculate_employee_bonus 
    @employee_id = 1008,
    @fiscal_year = 2024,
    @calculated_count = @count8 OUTPUT,
    @total_bonus_amount = @total8 OUTPUT;

-- ASSERT
SELECT 'TC8' AS test_case,
       @count8 AS calculated_count,
       @total8 AS total_bonus_amount,
       CASE WHEN @count8 = 0 THEN 'PASS' ELSE 'FAIL' END AS result;

-- CLEANUP
DROP TABLE #test_employees_tc8;

-- ============================================================================
-- TEST CASE 9: Exception case - Invalid fiscal year (too old)
-- ============================================================================
-- SETUP
CREATE TABLE #test_employees_tc9 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    salary DECIMAL(18,2),
    performance_rating INT,
    hire_date DATE,
    is_active BIT,
    bonus_amount DECIMAL(18,2),
    last_bonus_date DATETIME,
    bonus_fiscal_year INT
);

INSERT INTO #test_employees_tc9 (employee_id, first_name, last_name, salary, performance_rating, hire_date, is_active, bonus_amount, last_bonus_date, bonus_fiscal_year)
VALUES (1009, 'Grace', 'Moore', 85000.00, 4, '2023-01-01', 1, 0.00, NULL, NULL);

-- EXEC
BEGIN TRY
    DECLARE @count9 INT, @total9 DECIMAL(18,2);
    EXEC dbo.usp_calculate_employee_bonus 
        @employee_id = 1009,
        @fiscal_year = 1999,
        @calculated_count = @count9 OUTPUT,
        @total_bonus_amount = @total9 OUTPUT;
    
    -- ASSERT
    SELECT 'TC9' AS test_case, 'NO_ERROR' AS result;
END TRY
BEGIN CATCH
    -- ASSERT
    SELECT 'TC9' AS test_case, 
           CASE WHEN ERROR_MESSAGE() LIKE '%Invalid fiscal year%' THEN 'PASS' ELSE 'FAIL' END AS result,
           ERROR_MESSAGE() AS error_message;
END CATCH

-- CLEANUP
DROP TABLE #test_employees_tc9;

-- ============================================================================
-- TEST CASE 10: Exception case - Invalid fiscal year (too far in future)
-- ============================================================================
-- SETUP
CREATE TABLE #test_employees_tc10 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    salary DECIMAL(18,2),
    performance_rating INT,
    hire_date DATE,
    is_active BIT,
    bonus_amount DECIMAL(18,2),
    last_bonus_date DATETIME,
    bonus_fiscal_year INT
);

INSERT INTO #test_employees_tc10 (employee_id, first_name, last_name, salary, performance_rating, hire_date, is_active, bonus_amount, last_bonus_date, bonus_fiscal_year)
VALUES (1010, 'Henry', 'Taylor', 90000.00, 5, '2023-01-01', 1, 0.00, NULL, NULL);

-- EXEC
BEGIN TRY
    DECLARE @count10 INT, @total10 DECIMAL(18,2);
    EXEC dbo.usp_calculate_employee_bonus 
        @employee_id = 1010,
        @fiscal_year = 2050,
        @calculated_count = @count10 OUTPUT,
        @total_bonus_amount = @total10 OUTPUT;
    
    -- ASSERT
    SELECT 'TC10' AS test_case, 'NO_ERROR' AS result;
END TRY
BEGIN CATCH
    -- ASSERT
    SELECT 'TC10' AS test_case,
           CASE WHEN ERROR_MESSAGE() LIKE '%Invalid fiscal year%' THEN 'PASS' ELSE 'FAIL' END AS result,
           ERROR_MESSAGE() AS error_message;
END CATCH

-- CLEANUP
DROP TABLE #test_employees_tc10;

-- ============================================================================
-- TEST CASE 11: Normal case - Calculate for all employees (NULL employee_id)
-- ============================================================================
-- SETUP
CREATE TABLE #test_employees_tc11 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    salary DECIMAL(18,2),
    performance_rating INT,
    hire_date DATE,
    is_active BIT,
    bonus_amount DECIMAL(18,2),
    last_bonus_date DATETIME,
    bonus_fiscal_year INT
);

INSERT INTO #test_employees_tc11 (employee_id, first_name, last_name, salary, performance_rating, hire_date, is_active, bonus_amount, last_bonus_date, bonus_fiscal_year)
VALUES 
    (2001, 'User1', 'Test1', 100000.00, 5, '2023-01-01', 1, 0.00, NULL, NULL),
    (2002, 'User2', 'Test2', 80000.00, 4, '2023-01-01', 1, 0.00, NULL, NULL),
    (2003, 'User3', 'Test3', 60000.00, 3, '2023-01-01', 1, 0.00, NULL, NULL);

-- EXEC
DECLARE @count11 INT, @total11 DECIMAL(18,2);
EXEC dbo.usp_calculate_employee_bonus 
    @employee_id = NULL,
    @fiscal_year = 2024,
    @calculated_count = @count11 OUTPUT,
    @total_bonus_amount = @total11 OUTPUT;

-- ASSERT
SELECT 'TC11' AS test_case,
       @count11 AS calculated_count,
       @total11 AS total_bonus_amount,
       CASE WHEN @count11 = 3 AND @total11 = 26000.00 THEN 'PASS' ELSE 'FAIL' END AS result;

-- CLEANUP
DROP TABLE #test_employees_tc11;

-- ============================================================================
-- TEST CASE 12: Boundary case - Zero salary (should be excluded)
-- ============================================================================
-- SETUP
CREATE TABLE #test_employees_tc12 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    salary DECIMAL(18,2),
    performance_rating INT,
    hire_date DATE,
    is_active BIT,
    bonus_amount DECIMAL(18,2),
    last_bonus_date DATETIME,
    bonus_fiscal_year INT
);

INSERT INTO #test_employees_tc12 (employee_id, first_name, last_name, salary, performance_rating, hire_date, is_active, bonus_amount, last_bonus_date, bonus_fiscal_year)
VALUES (1012, 'Ivy', 'Anderson', 0.00, 5, '2023-01-01', 1, 0.00, NULL, NULL);

-- EXEC
DECLARE @count12 INT, @total12 DECIMAL(18,2);
EXEC dbo.usp_calculate_employee_bonus 
    @employee_id = 1012,
    @fiscal_year = 2024,
    @calculated_count = @count12 OUTPUT,
    @total_bonus_amount = @total12 OUTPUT;

-- ASSERT
SELECT 'TC12' AS test_case,
       @count12 AS calculated_count,
       @total12 AS total_bonus_amount,
       CASE WHEN @count12 = 0 THEN 'PASS' ELSE 'FAIL' END AS result;

-- CLEANUP
DROP TABLE #test_employees_tc12;

-- ============================================================================
-- TEST CASE 13: Normal case - Default fiscal year (NULL parameter)
-- ============================================================================
-- SETUP
CREATE TABLE #test_employees_tc13 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    salary DECIMAL(18,2),
    performance_rating INT,
    hire_date DATE,
    is_active BIT,
    bonus_amount DECIMAL(18,2),
    last_bonus_date DATETIME,
    bonus_fiscal_year INT
);

INSERT INTO #test_employees_tc13 (employee_id, first_name, last_name, salary, performance_rating, hire_date, is_active, bonus_amount, last_bonus_date, bonus_fiscal_year)
VALUES (1013, 'Jack', 'Thomas', 95000.00, 4, '2023-01-01', 1, 0.00, NULL, NULL);

-- EXEC
DECLARE @count13 INT, @total13 DECIMAL(18,2);
EXEC dbo.usp_calculate_employee_bonus 
    @employee_id = 1013,
    @fiscal_year = NULL,
    @calculated_count = @count13 OUTPUT,
    @total_bonus_amount = @total13 OUTPUT;

-- ASSERT
SELECT 'TC13' AS test_case,
       @count13 AS calculated_count,
       @total13 AS total_bonus_amount,
       (SELECT bonus_fiscal_year FROM #test_employees_tc13 WHERE employee_id = 1013) AS fiscal_year,
       CASE WHEN @total13 = 9500.00 THEN 'PASS' ELSE 'FAIL' END AS result;

-- CLEANUP
DROP TABLE #test_employees_tc13;

-- ============================================================================
-- End of Test Suite
-- ============================================================================
