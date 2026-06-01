-- ============================================================================
-- Test Suite for dbo.usp_calculate_employee_bonus
-- ============================================================================
-- Test Strategy:
--   - Normal cases: Various employee scenarios with different tenure
--   - Boundary cases: NULL handling, zero values, edge dates
--   - Exception cases: Non-existent employee, missing salary
--   - Side effects: INSERT and UPDATE behavior in bonuses table
-- ============================================================================

-- ============================================================================
-- SETUP: Prepare test data
-- ============================================================================

-- Insert test employees with IDENTITY_INSERT
SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES 
    (9001, 1, 'Test', 'Employee1', '2020-01-01', 1, 'test1@example.com', GETDATE()),
    (9002, 1, 'Test', 'Employee2', '2015-06-15', 1, 'test2@example.com', GETDATE()),
    (9003, 1, 'Test', 'Employee3', '2023-12-31', 1, 'test3@example.com', GETDATE()),
    (9004, 1, 'Test', 'Employee4', '2010-03-20', 1, 'test4@example.com', GETDATE()),
    (9005, 1, 'Test', 'NoSalary', '2020-01-01', 1, 'test5@example.com', GETDATE());
SET IDENTITY_INSERT dbo.employees OFF;

-- Insert test salaries
SET IDENTITY_INSERT dbo.salaries ON;
INSERT INTO dbo.salaries (salary_id, employee_id, base_salary, effective_from, effective_to)
VALUES 
    (9001, 9001, 50000.00, '2020-01-01', NULL),
    (9002, 9002, 60000.00, '2015-06-15', '2020-12-31'),
    (9003, 9002, 75000.00, '2021-01-01', NULL),  -- Employee 9002 has salary history
    (9004, 9003, 40000.00, '2023-12-31', NULL),
    (9005, 9004, 100000.00, '2010-03-20', NULL);
-- Employee 9005 has NO salary record
SET IDENTITY_INSERT dbo.salaries OFF;

SELECT 'SETUP COMPLETED' AS status;

-- ============================================================================
-- EXEC: Execute test cases
-- ============================================================================

-- TEST CASE 1: Normal case - Employee with 4 years tenure
-- Employee 9001: hired 2020-01-01, fiscal_year 2024
-- Years = DATEDIFF(yy, '2020-01-01', '2024-12-31') = 4
-- Bonus = 50000 * 0.10 * (1 + 4 * 0.05) = 5000 * 1.20 = 6000.00
DECLARE @bonus1 MONEY;
EXEC dbo.usp_calculate_employee_bonus @employee_id = 9001, @fiscal_year = 2024, @bonus = @bonus1 OUTPUT;
SELECT 
    test_case = 1,
    description = 'Normal: 4 years tenure',
    employee_id = 9001,
    fiscal_year = 2024,
    bonus_output = @bonus1,
    expected_bonus = 6000.00,
    result = CASE WHEN ABS(@bonus1 - 6000.00) < 0.01 THEN 'PASS' ELSE 'FAIL' END;

-- TEST CASE 2: Normal case - Employee with salary history (latest salary)
-- Employee 9002: hired 2015-06-15, fiscal_year 2024, latest salary 75000
-- Years = DATEDIFF(yy, '2015-06-15', '2024-12-31') = 9
-- Bonus = 75000 * 0.10 * (1 + 9 * 0.05) = 7500 * 1.45 = 10875.00
DECLARE @bonus2 MONEY;
EXEC dbo.usp_calculate_employee_bonus @employee_id = 9002, @fiscal_year = 2024, @bonus = @bonus2 OUTPUT;
SELECT 
    test_case = 2,
    description = 'Normal: Multiple salaries, use latest',
    employee_id = 9002,
    fiscal_year = 2024,
    bonus_output = @bonus2,
    expected_bonus = 10875.00,
    result = CASE WHEN ABS(@bonus2 - 10875.00) < 0.01 THEN 'PASS' ELSE 'FAIL' END;

-- TEST CASE 3: Normal case - Long tenure employee (14 years)
-- Employee 9004: hired 2010-03-20, fiscal_year 2024
-- Years = DATEDIFF(yy, '2010-03-20', '2024-12-31') = 14
-- Bonus = 100000 * 0.10 * (1 + 14 * 0.05) = 10000 * 1.70 = 17000.00
DECLARE @bonus3 MONEY;
EXEC dbo.usp_calculate_employee_bonus @employee_id = 9004, @fiscal_year = 2024, @bonus = @bonus3 OUTPUT;
SELECT 
    test_case = 3,
    description = 'Normal: Long tenure (14 years)',
    employee_id = 9004,
    fiscal_year = 2024,
    bonus_output = @bonus3,
    expected_bonus = 17000.00,
    result = CASE WHEN ABS(@bonus3 - 17000.00) < 0.01 THEN 'PASS' ELSE 'FAIL' END;

-- TEST CASE 4: Boundary - New hire (hired on Dec 31 of fiscal year)
-- Employee 9003: hired 2023-12-31, fiscal_year 2024
-- Years = DATEDIFF(yy, '2023-12-31', '2024-12-31') = 1
-- Bonus = 40000 * 0.10 * (1 + 1 * 0.05) = 4000 * 1.05 = 4200.00
DECLARE @bonus4 MONEY;
EXEC dbo.usp_calculate_employee_bonus @employee_id = 9003, @fiscal_year = 2024, @bonus = @bonus4 OUTPUT;
SELECT 
    test_case = 4,
    description = 'Boundary: New hire (1 year)',
    employee_id = 9003,
    fiscal_year = 2024,
    bonus_output = @bonus4,
    expected_bonus = 4200.00,
    result = CASE WHEN ABS(@bonus4 - 4200.00) < 0.01 THEN 'PASS' ELSE 'FAIL' END;

-- TEST CASE 5: Boundary - Same year hire and fiscal year
-- Employee 9001: hired 2020-01-01, fiscal_year 2020
-- Years = DATEDIFF(yy, '2020-01-01', '2020-12-31') = 0
-- Bonus = 50000 * 0.10 * (1 + 0 * 0.05) = 5000 * 1.00 = 5000.00
DECLARE @bonus5 MONEY;
EXEC dbo.usp_calculate_employee_bonus @employee_id = 9001, @fiscal_year = 2020, @bonus = @bonus5 OUTPUT;
SELECT 
    test_case = 5,
    description = 'Boundary: Zero years tenure',
    employee_id = 9001,
    fiscal_year = 2020,
    bonus_output = @bonus5,
    expected_bonus = 5000.00,
    result = CASE WHEN ABS(@bonus5 - 5000.00) < 0.01 THEN 'PASS' ELSE 'FAIL' END;

-- TEST CASE 6: Boundary - Employee with no salary record
-- Employee 9005: No salary record
-- Expected: @bonus = 0
DECLARE @bonus6 MONEY;
EXEC dbo.usp_calculate_employee_bonus @employee_id = 9005, @fiscal_year = 2024, @bonus = @bonus6 OUTPUT;
SELECT 
    test_case = 6,
    description = 'Boundary: No salary record',
    employee_id = 9005,
    fiscal_year = 2024,
    bonus_output = @bonus6,
    expected_bonus = 0.00,
    result = CASE WHEN @bonus6 = 0.00 THEN 'PASS' ELSE 'FAIL' END;

-- TEST CASE 7: Exception - Non-existent employee
-- Employee 99999: Does not exist
-- Expected: @bonus = 0 (no salary found)
DECLARE @bonus7 MONEY;
EXEC dbo.usp_calculate_employee_bonus @employee_id = 99999, @fiscal_year = 2024, @bonus = @bonus7 OUTPUT;
SELECT 
    test_case = 7,
    description = 'Exception: Non-existent employee',
    employee_id = 99999,
    fiscal_year = 2024,
    bonus_output = @bonus7,
    expected_bonus = 0.00,
    result = CASE WHEN @bonus7 = 0.00 THEN 'PASS' ELSE 'FAIL' END;

-- TEST CASE 8: Exception - NULL fiscal_year (should cause error)
DECLARE @bonus8 MONEY;
DECLARE @error8 NVARCHAR(500) = 'No error';

BEGIN TRY
    EXEC dbo.usp_calculate_employee_bonus @employee_id = 9001, @fiscal_year = NULL, @bonus = @bonus8 OUTPUT;
    SET @error8 = 'No error occurred';
END TRY
BEGIN CATCH
    SET @error8 = ERROR_MESSAGE();
END CATCH

SELECT 
    test_case = 8, 
    description = 'Exception: NULL fiscal_year', 
    error_message = @error8,
    result = CASE WHEN @error8 LIKE '%NULL%' OR @error8 LIKE '%null%' THEN 'PASS' ELSE 'FAIL' END;

-- TEST CASE 9: Side Effect - INSERT new bonus record
-- Delete any existing bonus for this test
DELETE FROM dbo.bonuses WHERE employee_id = 9001 AND fiscal_year = 2026;

DECLARE @bonus9 MONEY;
DECLARE @count_before9 INT, @count_after9 INT;

SELECT @count_before9 = COUNT(*) FROM dbo.bonuses WHERE employee_id = 9001 AND fiscal_year = 2026;
EXEC dbo.usp_calculate_employee_bonus @employee_id = 9001, @fiscal_year = 2026, @bonus = @bonus9 OUTPUT;
SELECT @count_after9 = COUNT(*) FROM dbo.bonuses WHERE employee_id = 9001 AND fiscal_year = 2026;

SELECT 
    test_case = 9,
    description = 'Side Effect: INSERT new bonus',
    count_before = @count_before9,
    count_after = @count_after9,
    bonus_calculated = @bonus9,
    result = CASE WHEN @count_before9 = 0 AND @count_after9 = 1 THEN 'PASS' ELSE 'FAIL' END;

-- TEST CASE 10: Side Effect - UPDATE existing bonus record
-- First insert a bonus with different amount
DELETE FROM dbo.bonuses WHERE employee_id = 9002 AND fiscal_year = 2026;

SET IDENTITY_INSERT dbo.bonuses ON;
INSERT INTO dbo.bonuses (bonus_id, employee_id, fiscal_year, bonus_amount, awarded_at)
VALUES (99998, 9002, 2026, 1000.00, GETDATE());
SET IDENTITY_INSERT dbo.bonuses OFF;

DECLARE @bonus10 MONEY;
DECLARE @amount_before10 MONEY, @amount_after10 MONEY;

SELECT @amount_before10 = bonus_amount FROM dbo.bonuses WHERE employee_id = 9002 AND fiscal_year = 2026;
EXEC dbo.usp_calculate_employee_bonus @employee_id = 9002, @fiscal_year = 2026, @bonus = @bonus10 OUTPUT;
SELECT @amount_after10 = bonus_amount FROM dbo.bonuses WHERE employee_id = 9002 AND fiscal_year = 2026;

SELECT 
    test_case = 10,
    description = 'Side Effect: UPDATE existing bonus',
    amount_before = @amount_before10,
    amount_after = @amount_after10,
    bonus_calculated = @bonus10,
    result = CASE WHEN @amount_before10 = 1000.00 AND @amount_after10 = @bonus10 THEN 'PASS' ELSE 'FAIL' END;

-- TEST CASE 11: Boundary - Future fiscal year
-- Employee 9001: hired 2020-01-01, fiscal_year 2030
-- Years = DATEDIFF(yy, '2020-01-01', '2030-12-31') = 10
-- Bonus = 50000 * 0.10 * (1 + 10 * 0.05) = 5000 * 1.50 = 7500.00
DECLARE @bonus11 MONEY;
EXEC dbo.usp_calculate_employee_bonus @employee_id = 9001, @fiscal_year = 2030, @bonus = @bonus11 OUTPUT;
SELECT 
    test_case = 11,
    description = 'Boundary: Future fiscal year',
    employee_id = 9001,
    fiscal_year = 2030,
    bonus_output = @bonus11,
    expected_bonus = 7500.00,
    result = CASE WHEN ABS(@bonus11 - 7500.00) < 0.01 THEN 'PASS' ELSE 'FAIL' END;

-- ============================================================================
-- ASSERT: Verify bonuses table state
-- ============================================================================
SELECT 
    'Bonuses Table Verification' AS section,
    employee_id, 
    fiscal_year, 
    bonus_amount 
FROM dbo.bonuses 
WHERE employee_id IN (9001, 9002) AND fiscal_year IN (2024, 2026, 2030)
ORDER BY employee_id, fiscal_year;

-- ============================================================================
-- CLEANUP: Remove test data
-- ============================================================================

-- Delete test bonuses
DELETE FROM dbo.bonuses WHERE employee_id >= 9001 AND employee_id <= 9005;

-- Delete test salaries
DELETE FROM dbo.salaries WHERE employee_id >= 9001 AND employee_id <= 9005;

-- Delete test employees
DELETE FROM dbo.employees WHERE employee_id >= 9001 AND employee_id <= 9005;

SELECT 'CLEANUP COMPLETED' AS status;
