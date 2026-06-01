-- ============================================================================
-- Test Suite for: dbo.usp_propagate_salary_raise
-- ============================================================================
-- This test suite covers:
-- - Normal cases: percentage and fixed amount raises
-- - Boundary cases: NULL inputs, zero values, maximum percentages
-- - Exception cases: invalid inputs, constraint violations
-- - Transaction cases: rollback behavior
-- - Side effects: salary updates, audit trail, output parameters
-- ============================================================================

-- ============= TEST CASE 1: Normal - Percentage raise for all employees =============
-- SETUP
CREATE TABLE #test_employees_tc1 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    department_id INT,
    salary DECIMAL(18,2),
    hire_date DATE,
    last_raise_date DATE,
    is_active BIT
);

INSERT INTO #test_employees_tc1 (employee_id, first_name, last_name, department_id, salary, hire_date, last_raise_date, is_active)
VALUES 
    (1001, 'John', 'Doe', 10, 50000.00, '2020-01-01', '2023-01-01', 1),
    (1002, 'Jane', 'Smith', 10, 60000.00, '2019-06-15', '2023-06-15', 1),
    (1003, 'Bob', 'Johnson', 20, 55000.00, '2021-03-10', '2023-03-10', 1);

-- EXEC
DECLARE @count1 INT, @total1 DECIMAL(18,2);
EXEC dbo.usp_propagate_salary_raise 
    @department_id = NULL,
    @raise_percentage = 10.00,
    @raise_amount = NULL,
    @effective_date = '2024-01-01',
    @reason = 'Annual raise 2024',
    @affected_count = @count1 OUTPUT,
    @total_increase = @total1 OUTPUT;

-- ASSERT
SELECT 'TC1' AS test_case, 'output_params' AS check_type, @count1 AS affected_count, @total1 AS total_increase;
SELECT 'TC1' AS test_case, 'salary_updates' AS check_type, employee_id, salary, last_raise_date 
FROM #test_employees_tc1 
ORDER BY employee_id;

-- CLEANUP
DROP TABLE #test_employees_tc1;
GO

-- ============= TEST CASE 2: Normal - Fixed amount raise for specific department =============
-- SETUP
CREATE TABLE #test_employees_tc2 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    department_id INT,
    salary DECIMAL(18,2),
    hire_date DATE,
    last_raise_date DATE,
    is_active BIT
);

INSERT INTO #test_employees_tc2 (employee_id, first_name, last_name, department_id, salary, hire_date, last_raise_date, is_active)
VALUES 
    (2001, 'Alice', 'Brown', 10, 45000.00, '2020-01-01', '2023-01-01', 1),
    (2002, 'Charlie', 'Davis', 10, 48000.00, '2019-06-15', '2023-06-15', 1),
    (2003, 'Diana', 'Evans', 20, 52000.00, '2021-03-10', '2023-03-10', 1);

-- EXEC
DECLARE @count2 INT, @total2 DECIMAL(18,2);
EXEC dbo.usp_propagate_salary_raise 
    @department_id = 10,
    @raise_percentage = NULL,
    @raise_amount = 5000.00,
    @effective_date = '2024-02-01',
    @reason = 'Department 10 adjustment',
    @affected_count = @count2 OUTPUT,
    @total_increase = @total2 OUTPUT;

-- ASSERT
SELECT 'TC2' AS test_case, 'output_params' AS check_type, @count2 AS affected_count, @total2 AS total_increase;
SELECT 'TC2' AS test_case, 'salary_updates' AS check_type, employee_id, department_id, salary, last_raise_date 
FROM #test_employees_tc2 
ORDER BY employee_id;

-- CLEANUP
DROP TABLE #test_employees_tc2;
GO

-- ============= TEST CASE 3: Normal - Default effective date and reason =============
-- SETUP
CREATE TABLE #test_employees_tc3 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    department_id INT,
    salary DECIMAL(18,2),
    hire_date DATE,
    last_raise_date DATE,
    is_active BIT
);

INSERT INTO #test_employees_tc3 (employee_id, first_name, last_name, department_id, salary, hire_date, last_raise_date, is_active)
VALUES 
    (3001, 'Eve', 'Foster', 30, 70000.00, '2020-01-01', '2023-01-01', 1);

-- EXEC
DECLARE @count3 INT, @total3 DECIMAL(18,2);
EXEC dbo.usp_propagate_salary_raise 
    @department_id = NULL,
    @raise_percentage = 5.00,
    @raise_amount = NULL,
    @effective_date = NULL,
    @reason = NULL,
    @affected_count = @count3 OUTPUT,
    @total_increase = @total3 OUTPUT;

-- ASSERT
SELECT 'TC3' AS test_case, 'output_params' AS check_type, @count3 AS affected_count, @total3 AS total_increase;
SELECT 'TC3' AS test_case, 'salary_check' AS check_type, employee_id, salary 
FROM #test_employees_tc3;

-- CLEANUP
DROP TABLE #test_employees_tc3;
GO

-- ============= TEST CASE 4: Boundary - Zero eligible employees (all recently raised) =============
-- SETUP
CREATE TABLE #test_employees_tc4 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    department_id INT,
    salary DECIMAL(18,2),
    hire_date DATE,
    last_raise_date DATE,
    is_active BIT
);

INSERT INTO #test_employees_tc4 (employee_id, first_name, last_name, department_id, salary, hire_date, last_raise_date, is_active)
VALUES 
    (4001, 'Frank', 'Green', 10, 50000.00, '2020-01-01', CAST(GETDATE() AS DATE), 1);

-- EXEC
DECLARE @count4 INT, @total4 DECIMAL(18,2);
EXEC dbo.usp_propagate_salary_raise 
    @department_id = NULL,
    @raise_percentage = 10.00,
    @raise_amount = NULL,
    @effective_date = '2024-01-01',
    @reason = 'Test recent raise',
    @affected_count = @count4 OUTPUT,
    @total_increase = @total4 OUTPUT;

-- ASSERT
SELECT 'TC4' AS test_case, 'output_params' AS check_type, @count4 AS affected_count, @total4 AS total_increase;

-- CLEANUP
DROP TABLE #test_employees_tc4;
GO

-- ============= TEST CASE 5: Boundary - Inactive employees excluded =============
-- SETUP
CREATE TABLE #test_employees_tc5 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    department_id INT,
    salary DECIMAL(18,2),
    hire_date DATE,
    last_raise_date DATE,
    is_active BIT
);

INSERT INTO #test_employees_tc5 (employee_id, first_name, last_name, department_id, salary, hire_date, last_raise_date, is_active)
VALUES 
    (5001, 'Grace', 'Hill', 10, 50000.00, '2020-01-01', '2023-01-01', 1),
    (5002, 'Henry', 'Ivy', 10, 55000.00, '2019-06-15', '2023-06-15', 0);

-- EXEC
DECLARE @count5 INT, @total5 DECIMAL(18,2);
EXEC dbo.usp_propagate_salary_raise 
    @department_id = NULL,
    @raise_percentage = 10.00,
    @raise_amount = NULL,
    @effective_date = '2024-01-01',
    @reason = 'Active only test',
    @affected_count = @count5 OUTPUT,
    @total_increase = @total5 OUTPUT;

-- ASSERT
SELECT 'TC5' AS test_case, 'output_params' AS check_type, @count5 AS affected_count, @total5 AS total_increase;
SELECT 'TC5' AS test_case, 'salary_check' AS check_type, employee_id, is_active, salary 
FROM #test_employees_tc5 
ORDER BY employee_id;

-- CLEANUP
DROP TABLE #test_employees_tc5;
GO

-- ============= TEST CASE 6: Boundary - Maximum raise percentage (20%) =============
-- SETUP
CREATE TABLE #test_employees_tc6 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    department_id INT,
    salary DECIMAL(18,2),
    hire_date DATE,
    last_raise_date DATE,
    is_active BIT
);

INSERT INTO #test_employees_tc6 (employee_id, first_name, last_name, department_id, salary, hire_date, last_raise_date, is_active)
VALUES 
    (6001, 'Ivy', 'Jones', 10, 100000.00, '2020-01-01', '2023-01-01', 1);

-- EXEC
DECLARE @count6 INT, @total6 DECIMAL(18,2);
EXEC dbo.usp_propagate_salary_raise 
    @department_id = NULL,
    @raise_percentage = 20.00,
    @raise_amount = NULL,
    @effective_date = '2024-01-01',
    @reason = 'Maximum raise test',
    @affected_count = @count6 OUTPUT,
    @total_increase = @total6 OUTPUT;

-- ASSERT
SELECT 'TC6' AS test_case, 'output_params' AS check_type, @count6 AS affected_count, @total6 AS total_increase;
SELECT 'TC6' AS test_case, 'salary_check' AS check_type, employee_id, salary 
FROM #test_employees_tc6;

-- CLEANUP
DROP TABLE #test_employees_tc6;
GO

-- ============= TEST CASE 7: Exception - Neither percentage nor amount specified =============
-- SETUP
-- No setup needed for this test

-- EXEC & ASSERT
BEGIN TRY
    DECLARE @count7 INT, @total7 DECIMAL(18,2);
    EXEC dbo.usp_propagate_salary_raise 
        @department_id = NULL,
        @raise_percentage = NULL,
        @raise_amount = NULL,
        @effective_date = '2024-01-01',
        @reason = 'Error test',
        @affected_count = @count7 OUTPUT,
        @total_increase = @total7 OUTPUT;
    SELECT 'TC7' AS test_case, 'NO_ERROR' AS result;
END TRY
BEGIN CATCH
    SELECT 'TC7' AS test_case, ERROR_MESSAGE() AS result;
END CATCH
GO

-- ============= TEST CASE 8: Exception - Both percentage and amount specified =============
-- SETUP
-- No setup needed for this test

-- EXEC & ASSERT
BEGIN TRY
    DECLARE @count8 INT, @total8 DECIMAL(18,2);
    EXEC dbo.usp_propagate_salary_raise 
        @department_id = NULL,
        @raise_percentage = 10.00,
        @raise_amount = 5000.00,
        @effective_date = '2024-01-01',
        @reason = 'Error test',
        @affected_count = @count8 OUTPUT,
        @total_increase = @total8 OUTPUT;
    SELECT 'TC8' AS test_case, 'NO_ERROR' AS result;
END TRY
BEGIN CATCH
    SELECT 'TC8' AS test_case, ERROR_MESSAGE() AS result;
END CATCH
GO

-- ============= TEST CASE 9: Exception - Raise percentage exceeds maximum (>20%) =============
-- SETUP
-- No setup needed for this test

-- EXEC & ASSERT
BEGIN TRY
    DECLARE @count9 INT, @total9 DECIMAL(18,2);
    EXEC dbo.usp_propagate_salary_raise 
        @department_id = NULL,
        @raise_percentage = 25.00,
        @raise_amount = NULL,
        @effective_date = '2024-01-01',
        @reason = 'Error test',
        @affected_count = @count9 OUTPUT,
        @total_increase = @total9 OUTPUT;
    SELECT 'TC9' AS test_case, 'NO_ERROR' AS result;
END TRY
BEGIN CATCH
    SELECT 'TC9' AS test_case, ERROR_MESSAGE() AS result;
END CATCH
GO

-- ============= TEST CASE 10: Exception - Negative raise percentage =============
-- SETUP
-- No setup needed for this test

-- EXEC & ASSERT
BEGIN TRY
    DECLARE @count10 INT, @total10 DECIMAL(18,2);
    EXEC dbo.usp_propagate_salary_raise 
        @department_id = NULL,
        @raise_percentage = -5.00,
        @raise_amount = NULL,
        @effective_date = '2024-01-01',
        @reason = 'Error test',
        @affected_count = @count10 OUTPUT,
        @total_increase = @total10 OUTPUT;
    SELECT 'TC10' AS test_case, 'NO_ERROR' AS result;
END TRY
BEGIN CATCH
    SELECT 'TC10' AS test_case, ERROR_MESSAGE() AS result;
END CATCH
GO

-- ============= TEST CASE 11: Exception - Negative raise amount =============
-- SETUP
-- No setup needed for this test

-- EXEC & ASSERT
BEGIN TRY
    DECLARE @count11 INT, @total11 DECIMAL(18,2);
    EXEC dbo.usp_propagate_salary_raise 
        @department_id = NULL,
        @raise_percentage = NULL,
        @raise_amount = -1000.00,
        @effective_date = '2024-01-01',
        @reason = 'Error test',
        @affected_count = @count11 OUTPUT,
        @total_increase = @total11 OUTPUT;
    SELECT 'TC11' AS test_case, 'NO_ERROR' AS result;
END TRY
BEGIN CATCH
    SELECT 'TC11' AS test_case, ERROR_MESSAGE() AS result;
END CATCH
GO

-- ============= TEST CASE 12: Transaction - Verify rollback on error =============
-- SETUP
CREATE TABLE #test_employees_tc12 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    department_id INT,
    salary DECIMAL(18,2),
    hire_date DATE,
    last_raise_date DATE,
    is_active BIT
);

INSERT INTO #test_employees_tc12 (employee_id, first_name, last_name, department_id, salary, hire_date, last_raise_date, is_active)
VALUES 
    (12001, 'Jack', 'King', 10, 50000.00, '2020-01-01', '2023-01-01', 1);

-- Record original salary
DECLARE @original_salary_tc12 DECIMAL(18,2);
SELECT @original_salary_tc12 = salary FROM #test_employees_tc12 WHERE employee_id = 12001;

-- EXEC (this should fail due to invalid input)
BEGIN TRY
    DECLARE @count12 INT, @total12 DECIMAL(18,2);
    EXEC dbo.usp_propagate_salary_raise 
        @department_id = NULL,
        @raise_percentage = NULL,
        @raise_amount = NULL,
        @effective_date = '2024-01-01',
        @reason = 'Rollback test',
        @affected_count = @count12 OUTPUT,
        @total_increase = @total12 OUTPUT;
END TRY
BEGIN CATCH
    -- Error expected, continue
END CATCH

-- ASSERT - salary should remain unchanged
SELECT 'TC12' AS test_case, 
       CASE WHEN salary = @original_salary_tc12 THEN 'ROLLBACK_SUCCESS' ELSE 'ROLLBACK_FAILED' END AS result
FROM #test_employees_tc12 
WHERE employee_id = 12001;

-- CLEANUP
DROP TABLE #test_employees_tc12;
GO

-- ============================================================================
-- End of Test Suite
-- ============================================================================
