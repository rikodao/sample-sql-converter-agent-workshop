-- =============================================
-- TEST CASES for dbo.usp_calculate_employee_bonus
-- Babelfish Compatible Version
-- =============================================
-- This procedure calculates employee bonus based on:
--   - Latest base_salary from salaries table
--   - Years of service (hire_date to fiscal_year end)
--   - Formula: base * 0.10 * (1 + years * 0.05)
--   - UPSERT into bonuses table
--   - Returns @bonus as OUTPUT parameter
-- =============================================

-- ============= TEST CASE 1: Normal employee bonus calculation (INSERT) =============
-- SETUP
IF OBJECT_ID('tempdb..#tc1_employees') IS NOT NULL DROP TABLE #tc1_employees;
IF OBJECT_ID('tempdb..#tc1_salaries') IS NOT NULL DROP TABLE #tc1_salaries;
IF OBJECT_ID('tempdb..#tc1_bonuses') IS NOT NULL DROP TABLE #tc1_bonuses;

CREATE TABLE #tc1_employees (employee_id INT, hire_date DATE);
CREATE TABLE #tc1_salaries (employee_id INT, base_salary MONEY, effective_from DATE);
CREATE TABLE #tc1_bonuses (employee_id INT, fiscal_year INT, bonus_amount MONEY);

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees(employee_id, first_name, last_name, hire_date, department_id)
VALUES (9001, 'Test', 'User1', '2020-01-01', 1);
SET IDENTITY_INSERT dbo.employees OFF;

INSERT INTO dbo.salaries(employee_id, base_salary, effective_from)
VALUES (9001, 50000.00, '2020-01-01');

-- EXEC
DECLARE @bonus1 MONEY;
EXEC dbo.usp_calculate_employee_bonus @employee_id = 9001, @fiscal_year = 2024, @bonus = @bonus1 OUTPUT;

-- ASSERT
SELECT 'TC1' AS tc, @bonus1 AS output_bonus;
SELECT 'TC1' AS tc, employee_id, fiscal_year, bonus_amount 
FROM dbo.bonuses WHERE employee_id = 9001 AND fiscal_year = 2024;

-- CLEANUP
DELETE FROM dbo.bonuses WHERE employee_id = 9001;
DELETE FROM dbo.salaries WHERE employee_id = 9001;
DELETE FROM dbo.employees WHERE employee_id = 9001;
DROP TABLE #tc1_employees;
DROP TABLE #tc1_salaries;
DROP TABLE #tc1_bonuses;

-- ============= TEST CASE 2: Update existing bonus record (UPDATE) =============
-- SETUP
SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees(employee_id, first_name, last_name, hire_date, department_id)
VALUES (9002, 'Test', 'User2', '2019-06-15', 1);
SET IDENTITY_INSERT dbo.employees OFF;

INSERT INTO dbo.salaries(employee_id, base_salary, effective_from)
VALUES (9002, 60000.00, '2019-06-15');

INSERT INTO dbo.bonuses(employee_id, fiscal_year, bonus_amount)
VALUES (9002, 2024, 1000.00);

-- EXEC
DECLARE @bonus2 MONEY;
EXEC dbo.usp_calculate_employee_bonus @employee_id = 9002, @fiscal_year = 2024, @bonus = @bonus2 OUTPUT;

-- ASSERT
SELECT 'TC2' AS tc, @bonus2 AS output_bonus;
SELECT 'TC2' AS tc, employee_id, fiscal_year, bonus_amount, 
       (SELECT COUNT(*) FROM dbo.bonuses WHERE employee_id = 9002 AND fiscal_year = 2024) AS record_count
FROM dbo.bonuses WHERE employee_id = 9002 AND fiscal_year = 2024;

-- CLEANUP
DELETE FROM dbo.bonuses WHERE employee_id = 9002;
DELETE FROM dbo.salaries WHERE employee_id = 9002;
DELETE FROM dbo.employees WHERE employee_id = 9002;

-- ============= TEST CASE 3: Long-tenured employee (high multiplier) =============
-- SETUP
SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees(employee_id, first_name, last_name, hire_date, department_id)
VALUES (9003, 'Test', 'User3', '2000-01-01', 1);
SET IDENTITY_INSERT dbo.employees OFF;

INSERT INTO dbo.salaries(employee_id, base_salary, effective_from)
VALUES (9003, 80000.00, '2000-01-01');

-- EXEC
DECLARE @bonus3 MONEY;
EXEC dbo.usp_calculate_employee_bonus @employee_id = 9003, @fiscal_year = 2024, @bonus = @bonus3 OUTPUT;

-- ASSERT
-- Years: 2024 - 2000 = 24 years
-- Bonus: 80000 * 0.10 * (1 + 24 * 0.05) = 8000 * 2.2 = 17600
SELECT 'TC3' AS tc, @bonus3 AS output_bonus, 
       DATEDIFF(yy, '2000-01-01', DATEFROMPARTS(2024, 12, 31)) AS years_of_service;
SELECT 'TC3' AS tc, employee_id, fiscal_year, bonus_amount 
FROM dbo.bonuses WHERE employee_id = 9003 AND fiscal_year = 2024;

-- CLEANUP
DELETE FROM dbo.bonuses WHERE employee_id = 9003;
DELETE FROM dbo.salaries WHERE employee_id = 9003;
DELETE FROM dbo.employees WHERE employee_id = 9003;

-- ============= TEST CASE 4: Employee with no salary record (bonus = 0) =============
-- SETUP
SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees(employee_id, first_name, last_name, hire_date, department_id)
VALUES (9004, 'Test', 'User4', '2023-01-01', 1);
SET IDENTITY_INSERT dbo.employees OFF;

-- No salary record inserted

-- EXEC
DECLARE @bonus4 MONEY;
EXEC dbo.usp_calculate_employee_bonus @employee_id = 9004, @fiscal_year = 2024, @bonus = @bonus4 OUTPUT;

-- ASSERT
SELECT 'TC4' AS tc, @bonus4 AS output_bonus;
SELECT 'TC4' AS tc, COUNT(*) AS bonus_records_inserted 
FROM dbo.bonuses WHERE employee_id = 9004 AND fiscal_year = 2024;

-- CLEANUP
DELETE FROM dbo.bonuses WHERE employee_id = 9004;
DELETE FROM dbo.employees WHERE employee_id = 9004;

-- ============= TEST CASE 5: Zero years of service (hired at fiscal year end) =============
-- SETUP
SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees(employee_id, first_name, last_name, hire_date, department_id)
VALUES (9005, 'Test', 'User5', '2024-12-31', 1);
SET IDENTITY_INSERT dbo.employees OFF;

INSERT INTO dbo.salaries(employee_id, base_salary, effective_from)
VALUES (9005, 40000.00, '2024-12-31');

-- EXEC
DECLARE @bonus5 MONEY;
EXEC dbo.usp_calculate_employee_bonus @employee_id = 9005, @fiscal_year = 2024, @bonus = @bonus5 OUTPUT;

-- ASSERT
-- Years: 0, Bonus: 40000 * 0.10 * (1 + 0 * 0.05) = 4000
SELECT 'TC5' AS tc, @bonus5 AS output_bonus;
SELECT 'TC5' AS tc, employee_id, fiscal_year, bonus_amount 
FROM dbo.bonuses WHERE employee_id = 9005 AND fiscal_year = 2024;

-- CLEANUP
DELETE FROM dbo.bonuses WHERE employee_id = 9005;
DELETE FROM dbo.salaries WHERE employee_id = 9005;
DELETE FROM dbo.employees WHERE employee_id = 9005;

-- ============= TEST CASE 6: Non-existent employee_id =============
-- SETUP
-- No employee created

-- EXEC
DECLARE @bonus6 MONEY;
BEGIN TRY
    EXEC dbo.usp_calculate_employee_bonus @employee_id = 99999, @fiscal_year = 2024, @bonus = @bonus6 OUTPUT;
    SELECT 'TC6' AS tc, 'NO_ERROR' AS result, @bonus6 AS output_bonus;
END TRY
BEGIN CATCH
    SELECT 'TC6' AS tc, ERROR_MESSAGE() AS result;
END CATCH

-- ASSERT
SELECT 'TC6' AS tc, COUNT(*) AS bonus_records_inserted 
FROM dbo.bonuses WHERE employee_id = 99999 AND fiscal_year = 2024;

-- CLEANUP
DELETE FROM dbo.bonuses WHERE employee_id = 99999;

-- ============= TEST CASE 7: NULL employee_id (exception expected) =============
-- SETUP
-- No setup needed

-- EXEC
DECLARE @bonus7 MONEY;
BEGIN TRY
    EXEC dbo.usp_calculate_employee_bonus @employee_id = NULL, @fiscal_year = 2024, @bonus = @bonus7 OUTPUT;
    SELECT 'TC7' AS tc, 'NO_ERROR' AS result, @bonus7 AS output_bonus;
END TRY
BEGIN CATCH
    SELECT 'TC7' AS tc, ERROR_MESSAGE() AS result;
END CATCH

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 8: Multiple salary records - uses latest =============
-- SETUP
SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees(employee_id, first_name, last_name, hire_date, department_id)
VALUES (9008, 'Test', 'User8', '2020-01-01', 1);
SET IDENTITY_INSERT dbo.employees OFF;

INSERT INTO dbo.salaries(employee_id, base_salary, effective_from)
VALUES (9008, 50000.00, '2020-01-01'),
       (9008, 55000.00, '2022-01-01'),
       (9008, 60000.00, '2024-01-01');

-- EXEC
DECLARE @bonus8 MONEY;
EXEC dbo.usp_calculate_employee_bonus @employee_id = 9008, @fiscal_year = 2024, @bonus = @bonus8 OUTPUT;

-- ASSERT
-- Should use 60000 (latest salary)
-- Years: 4, Bonus: 60000 * 0.10 * (1 + 4 * 0.05) = 6000 * 1.2 = 7200
SELECT 'TC8' AS tc, @bonus8 AS output_bonus;
SELECT 'TC8' AS tc, employee_id, fiscal_year, bonus_amount 
FROM dbo.bonuses WHERE employee_id = 9008 AND fiscal_year = 2024;

-- CLEANUP
DELETE FROM dbo.bonuses WHERE employee_id = 9008;
DELETE FROM dbo.salaries WHERE employee_id = 9008;
DELETE FROM dbo.employees WHERE employee_id = 9008;

-- ============= TEST CASE 9: Side effect verification - UPSERT behavior =============
-- SETUP
SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees(employee_id, first_name, last_name, hire_date, department_id)
VALUES (9009, 'Test', 'User9', '2021-01-01', 1);
SET IDENTITY_INSERT dbo.employees OFF;

INSERT INTO dbo.salaries(employee_id, base_salary, effective_from)
VALUES (9009, 70000.00, '2021-01-01');

-- EXEC (first time - INSERT)
DECLARE @bonus9a MONEY;
EXEC dbo.usp_calculate_employee_bonus @employee_id = 9009, @fiscal_year = 2024, @bonus = @bonus9a OUTPUT;

-- ASSERT (after first execution)
SELECT 'TC9a' AS tc, @bonus9a AS output_bonus, 
       (SELECT COUNT(*) FROM dbo.bonuses WHERE employee_id = 9009 AND fiscal_year = 2024) AS record_count;

-- Update salary and re-execute (should UPDATE)
UPDATE dbo.salaries SET base_salary = 75000.00 WHERE employee_id = 9009;

DECLARE @bonus9b MONEY;
EXEC dbo.usp_calculate_employee_bonus @employee_id = 9009, @fiscal_year = 2024, @bonus = @bonus9b OUTPUT;

-- ASSERT (after second execution)
SELECT 'TC9b' AS tc, @bonus9b AS output_bonus, 
       (SELECT COUNT(*) FROM dbo.bonuses WHERE employee_id = 9009 AND fiscal_year = 2024) AS record_count;
SELECT 'TC9b' AS tc, employee_id, fiscal_year, bonus_amount 
FROM dbo.bonuses WHERE employee_id = 9009 AND fiscal_year = 2024;

-- CLEANUP
DELETE FROM dbo.bonuses WHERE employee_id = 9009;
DELETE FROM dbo.salaries WHERE employee_id = 9009;
DELETE FROM dbo.employees WHERE employee_id = 9009;

-- ============= TEST CASE 10: Negative fiscal year (boundary) =============
-- SETUP
SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees(employee_id, first_name, last_name, hire_date, department_id)
VALUES (9010, 'Test', 'User10', '2020-01-01', 1);
SET IDENTITY_INSERT dbo.employees OFF;

INSERT INTO dbo.salaries(employee_id, base_salary, effective_from)
VALUES (9010, 45000.00, '2020-01-01');

-- EXEC
DECLARE @bonus10 MONEY;
BEGIN TRY
    EXEC dbo.usp_calculate_employee_bonus @employee_id = 9010, @fiscal_year = -1, @bonus = @bonus10 OUTPUT;
    SELECT 'TC10' AS tc, 'NO_ERROR' AS result, @bonus10 AS output_bonus;
END TRY
BEGIN CATCH
    SELECT 'TC10' AS tc, ERROR_MESSAGE() AS result;
END CATCH

-- CLEANUP
DELETE FROM dbo.bonuses WHERE employee_id = 9010;
DELETE FROM dbo.salaries WHERE employee_id = 9010;
DELETE FROM dbo.employees WHERE employee_id = 9010;
