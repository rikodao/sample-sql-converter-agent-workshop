-- =============================================
-- Test Suite for dbo.usp_propagate_salary_raise
-- Babelfish Version (minimal modifications from MSSQL)
-- =============================================

-- ============= TEST CASE 1: Normal 5% raise for eligible employees =============
-- SETUP
BEGIN TRANSACTION;

-- Create test employees
SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES 
    (9001, 1, 'Alice', 'TestRaise', '2020-01-01', 1, 'alice@test.com', GETDATE()),
    (9002, 1, 'Bob', 'TestRaise', '2021-01-01', 1, 'bob@test.com', GETDATE());
SET IDENTITY_INSERT dbo.employees OFF;

-- Create current salary records
SET IDENTITY_INSERT dbo.salaries ON;
INSERT INTO dbo.salaries (salary_id, employee_id, base_salary, effective_from, effective_to)
VALUES 
    (90001, 9001, 50000.00, '2020-01-01', NULL),
    (90002, 9002, 60000.00, '2021-01-01', NULL);
SET IDENTITY_INSERT dbo.salaries OFF;

-- EXEC
EXEC dbo.usp_propagate_salary_raise @raise_pct = 5.00, @min_years_of_service = 3;

-- ASSERT
-- Check that old salary records are closed
SELECT 'TC1' AS tc, 'old_records_closed' AS check_type, 
       COUNT(*) AS count
FROM dbo.salaries
WHERE employee_id IN (9001, 9002)
  AND effective_to IS NOT NULL;

-- Check that new salary records are created
SELECT 'TC1' AS tc, 'new_records_created' AS check_type,
       COUNT(*) AS count
FROM dbo.salaries
WHERE employee_id IN (9001, 9002)
  AND effective_to IS NULL;

-- Check new salary amounts (should be 5% higher)
SELECT 'TC1' AS tc, 'salary_amounts' AS check_type,
       employee_id, base_salary, 
       CAST(base_salary AS DECIMAL(10,2)) AS salary_rounded
FROM dbo.salaries
WHERE employee_id IN (9001, 9002)
  AND effective_to IS NULL
ORDER BY employee_id;

-- CLEANUP
ROLLBACK TRANSACTION;

-- ============= TEST CASE 2: 10% raise with custom min_years_of_service =============
-- SETUP
BEGIN TRANSACTION;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES 
    (9003, 1, 'Charlie', 'TestRaise', '2022-01-01', 1, 'charlie@test.com', GETDATE()),
    (9004, 1, 'Diana', 'TestRaise', '2023-01-01', 1, 'diana@test.com', GETDATE());
SET IDENTITY_INSERT dbo.employees OFF;

SET IDENTITY_INSERT dbo.salaries ON;
INSERT INTO dbo.salaries (salary_id, employee_id, base_salary, effective_from, effective_to)
VALUES 
    (90003, 9003, 45000.00, '2022-01-01', NULL),
    (90004, 9004, 40000.00, '2023-01-01', NULL);
SET IDENTITY_INSERT dbo.salaries OFF;

-- EXEC
-- Charlie has 2+ years, Diana has 1+ year. With min_years = 2, both should get raise
EXEC dbo.usp_propagate_salary_raise @raise_pct = 10.00, @min_years_of_service = 2;

-- ASSERT
SELECT 'TC2' AS tc, 'eligible_count' AS check_type,
       COUNT(*) AS count
FROM dbo.salaries
WHERE employee_id IN (9003, 9004)
  AND effective_to IS NULL;

-- Check salary amounts (should be 10% higher)
SELECT 'TC2' AS tc, 'salary_amounts' AS check_type,
       employee_id, 
       CAST(base_salary AS DECIMAL(10,2)) AS salary_rounded
FROM dbo.salaries
WHERE employee_id IN (9003, 9004)
  AND effective_to IS NULL
ORDER BY employee_id;

-- CLEANUP
ROLLBACK TRANSACTION;

-- ============= TEST CASE 3: Zero percent raise (no change in amount) =============
-- SETUP
BEGIN TRANSACTION;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES 
    (9005, 1, 'Eve', 'TestRaise', '2020-06-01', 1, 'eve@test.com', GETDATE());
SET IDENTITY_INSERT dbo.employees OFF;

SET IDENTITY_INSERT dbo.salaries ON;
INSERT INTO dbo.salaries (salary_id, employee_id, base_salary, effective_from, effective_to)
VALUES 
    (90005, 9005, 55000.00, '2020-06-01', NULL);
SET IDENTITY_INSERT dbo.salaries OFF;

-- EXEC
EXEC dbo.usp_propagate_salary_raise @raise_pct = 0.00, @min_years_of_service = 3;

-- ASSERT
-- Should still create new record even with 0% raise
SELECT 'TC3' AS tc, 'records_created' AS check_type,
       COUNT(*) AS count
FROM dbo.salaries
WHERE employee_id = 9005
  AND effective_to IS NULL;

SELECT 'TC3' AS tc, 'salary_unchanged' AS check_type,
       employee_id,
       CAST(base_salary AS DECIMAL(10,2)) AS salary_rounded
FROM dbo.salaries
WHERE employee_id = 9005
  AND effective_to IS NULL;

-- CLEANUP
ROLLBACK TRANSACTION;

-- ============= TEST CASE 4: Inactive employee should not get raise =============
-- SETUP
BEGIN TRANSACTION;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES 
    (9006, 1, 'Frank', 'TestRaise', '2019-01-01', 0, 'frank@test.com', GETDATE());
SET IDENTITY_INSERT dbo.employees OFF;

SET IDENTITY_INSERT dbo.salaries ON;
INSERT INTO dbo.salaries (salary_id, employee_id, base_salary, effective_from, effective_to)
VALUES 
    (90006, 9006, 70000.00, '2019-01-01', NULL);
SET IDENTITY_INSERT dbo.salaries OFF;

-- EXEC
EXEC dbo.usp_propagate_salary_raise @raise_pct = 5.00, @min_years_of_service = 3;

-- ASSERT
-- Should have only 1 salary record (original), no new record
SELECT 'TC4' AS tc, 'inactive_no_raise' AS check_type,
       COUNT(*) AS total_records,
       SUM(CASE WHEN effective_to IS NULL THEN 1 ELSE 0 END) AS open_records
FROM dbo.salaries
WHERE employee_id = 9006;

-- CLEANUP
ROLLBACK TRANSACTION;

-- ============= TEST CASE 5: Employee with insufficient years of service =============
-- SETUP
BEGIN TRANSACTION;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES 
    (9007, 1, 'Grace', 'TestRaise', DATEADD(yy, -2, GETDATE()), 1, 'grace@test.com', GETDATE());
SET IDENTITY_INSERT dbo.employees OFF;

SET IDENTITY_INSERT dbo.salaries ON;
INSERT INTO dbo.salaries (salary_id, employee_id, base_salary, effective_from, effective_to)
VALUES 
    (90007, 9007, 48000.00, DATEADD(yy, -2, GETDATE()), NULL);
SET IDENTITY_INSERT dbo.salaries OFF;

-- EXEC
-- Grace has only 2 years, min is 3, should not get raise
EXEC dbo.usp_propagate_salary_raise @raise_pct = 5.00, @min_years_of_service = 3;

-- ASSERT
SELECT 'TC5' AS tc, 'insufficient_years' AS check_type,
       COUNT(*) AS total_records,
       SUM(CASE WHEN effective_to IS NULL THEN 1 ELSE 0 END) AS open_records
FROM dbo.salaries
WHERE employee_id = 9007;

-- CLEANUP
ROLLBACK TRANSACTION;

-- ============= TEST CASE 6: Employee with no salary history =============
-- SETUP
BEGIN TRANSACTION;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES 
    (9008, 1, 'Henry', 'TestRaise', '2019-01-01', 1, 'henry@test.com', GETDATE());
SET IDENTITY_INSERT dbo.employees OFF;

-- No salary record for Henry

-- EXEC
EXEC dbo.usp_propagate_salary_raise @raise_pct = 5.00, @min_years_of_service = 3;

-- ASSERT
-- Should have no salary records
SELECT 'TC6' AS tc, 'no_salary_history' AS check_type,
       COUNT(*) AS salary_records
FROM dbo.salaries
WHERE employee_id = 9008;

-- CLEANUP
ROLLBACK TRANSACTION;

-- ============= TEST CASE 7: Large raise percentage (50%) =============
-- SETUP
BEGIN TRANSACTION;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES 
    (9009, 1, 'Ivy', 'TestRaise', '2018-01-01', 1, 'ivy@test.com', GETDATE());
SET IDENTITY_INSERT dbo.employees OFF;

SET IDENTITY_INSERT dbo.salaries ON;
INSERT INTO dbo.salaries (salary_id, employee_id, base_salary, effective_from, effective_to)
VALUES 
    (90009, 9009, 40000.00, '2018-01-01', NULL);
SET IDENTITY_INSERT dbo.salaries OFF;

-- EXEC
EXEC dbo.usp_propagate_salary_raise @raise_pct = 50.00, @min_years_of_service = 3;

-- ASSERT
SELECT 'TC7' AS tc, 'large_raise' AS check_type,
       employee_id,
       CAST(base_salary AS DECIMAL(10,2)) AS salary_rounded
FROM dbo.salaries
WHERE employee_id = 9009
  AND effective_to IS NULL;

-- CLEANUP
ROLLBACK TRANSACTION;

-- ============= TEST CASE 8: Negative raise percentage (salary decrease) =============
-- SETUP
BEGIN TRANSACTION;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES 
    (9010, 1, 'Jack', 'TestRaise', '2019-01-01', 1, 'jack@test.com', GETDATE());
SET IDENTITY_INSERT dbo.employees OFF;

SET IDENTITY_INSERT dbo.salaries ON;
INSERT INTO dbo.salaries (salary_id, employee_id, base_salary, effective_from, effective_to)
VALUES 
    (90010, 9010, 50000.00, '2019-01-01', NULL);
SET IDENTITY_INSERT dbo.salaries OFF;

-- EXEC
-- -10% should result in 90% of original salary
EXEC dbo.usp_propagate_salary_raise @raise_pct = -10.00, @min_years_of_service = 3;

-- ASSERT
SELECT 'TC8' AS tc, 'negative_raise' AS check_type,
       employee_id,
       CAST(base_salary AS DECIMAL(10,2)) AS salary_rounded
FROM dbo.salaries
WHERE employee_id = 9010
  AND effective_to IS NULL;

-- CLEANUP
ROLLBACK TRANSACTION;

-- ============= TEST CASE 9: Multiple salary history records (only latest should be used) =============
-- SETUP
BEGIN TRANSACTION;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES 
    (9011, 1, 'Karen', 'TestRaise', '2018-01-01', 1, 'karen@test.com', GETDATE());
SET IDENTITY_INSERT dbo.employees OFF;

SET IDENTITY_INSERT dbo.salaries ON;
INSERT INTO dbo.salaries (salary_id, employee_id, base_salary, effective_from, effective_to)
VALUES 
    (90011, 9011, 40000.00, '2018-01-01', '2019-12-31'),
    (90012, 9011, 45000.00, '2020-01-01', '2021-12-31'),
    (90013, 9011, 50000.00, '2022-01-01', NULL);
SET IDENTITY_INSERT dbo.salaries OFF;

-- EXEC
EXEC dbo.usp_propagate_salary_raise @raise_pct = 10.00, @min_years_of_service = 3;

-- ASSERT
-- Should use latest salary (50000) and create new record with 55000
SELECT 'TC9' AS tc, 'multiple_history' AS check_type,
       COUNT(*) AS total_records,
       SUM(CASE WHEN effective_to IS NULL THEN 1 ELSE 0 END) AS open_records
FROM dbo.salaries
WHERE employee_id = 9011;

SELECT 'TC9' AS tc, 'latest_salary' AS check_type,
       CAST(base_salary AS DECIMAL(10,2)) AS salary_rounded
FROM dbo.salaries
WHERE employee_id = 9011
  AND effective_to IS NULL;

-- CLEANUP
ROLLBACK TRANSACTION;

-- ============= TEST CASE 10: Exactly at minimum years threshold =============
-- SETUP
BEGIN TRANSACTION;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES 
    (9012, 1, 'Larry', 'TestRaise', DATEADD(yy, -3, GETDATE()), 1, 'larry@test.com', GETDATE());
SET IDENTITY_INSERT dbo.employees OFF;

SET IDENTITY_INSERT dbo.salaries ON;
INSERT INTO dbo.salaries (salary_id, employee_id, base_salary, effective_from, effective_to)
VALUES 
    (90014, 9012, 52000.00, DATEADD(yy, -3, GETDATE()), NULL);
SET IDENTITY_INSERT dbo.salaries OFF;

-- EXEC
-- Larry has exactly 3 years, should be eligible
EXEC dbo.usp_propagate_salary_raise @raise_pct = 5.00, @min_years_of_service = 3;

-- ASSERT
SELECT 'TC10' AS tc, 'exactly_threshold' AS check_type,
       COUNT(*) AS new_records
FROM dbo.salaries
WHERE employee_id = 9012
  AND effective_to IS NULL;

SELECT 'TC10' AS tc, 'salary_amount' AS check_type,
       CAST(base_salary AS DECIMAL(10,2)) AS salary_rounded
FROM dbo.salaries
WHERE employee_id = 9012
  AND effective_to IS NULL;

-- CLEANUP
ROLLBACK TRANSACTION;

-- ============= TEST CASE 11: Very small raise (0.01%) =============
-- SETUP
BEGIN TRANSACTION;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES 
    (9013, 1, 'Mary', 'TestRaise', '2019-01-01', 1, 'mary@test.com', GETDATE());
SET IDENTITY_INSERT dbo.employees OFF;

SET IDENTITY_INSERT dbo.salaries ON;
INSERT INTO dbo.salaries (salary_id, employee_id, base_salary, effective_from, effective_to)
VALUES 
    (90015, 9013, 100000.00, '2019-01-01', NULL);
SET IDENTITY_INSERT dbo.salaries OFF;

-- EXEC
EXEC dbo.usp_propagate_salary_raise @raise_pct = 0.01, @min_years_of_service = 3;

-- ASSERT
SELECT 'TC11' AS tc, 'tiny_raise' AS check_type,
       employee_id,
       CAST(base_salary AS DECIMAL(10,2)) AS salary_rounded
FROM dbo.salaries
WHERE employee_id = 9013
  AND effective_to IS NULL;

-- CLEANUP
ROLLBACK TRANSACTION;

-- ============= TEST CASE 12: Min years of service = 0 (all active with salary eligible) =============
-- SETUP
BEGIN TRANSACTION;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES 
    (9014, 1, 'Nancy', 'TestRaise', DATEADD(mm, -6, GETDATE()), 1, 'nancy@test.com', GETDATE());
SET IDENTITY_INSERT dbo.employees OFF;

SET IDENTITY_INSERT dbo.salaries ON;
INSERT INTO dbo.salaries (salary_id, employee_id, base_salary, effective_from, effective_to)
VALUES 
    (90016, 9014, 35000.00, DATEADD(mm, -6, GETDATE()), NULL);
SET IDENTITY_INSERT dbo.salaries OFF;

-- EXEC
-- Nancy has only 6 months, but min_years = 0 should include her
EXEC dbo.usp_propagate_salary_raise @raise_pct = 5.00, @min_years_of_service = 0;

-- ASSERT
SELECT 'TC12' AS tc, 'zero_min_years' AS check_type,
       COUNT(*) AS new_records
FROM dbo.salaries
WHERE employee_id = 9014
  AND effective_to IS NULL;

SELECT 'TC12' AS tc, 'salary_amount' AS check_type,
       CAST(base_salary AS DECIMAL(10,2)) AS salary_rounded
FROM dbo.salaries
WHERE employee_id = 9014
  AND effective_to IS NULL;

-- CLEANUP
ROLLBACK TRANSACTION;

-- ============= TEST CASE 13: Verify effective_to date is set correctly =============
-- SETUP
BEGIN TRANSACTION;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES 
    (9015, 1, 'Oscar', 'TestRaise', '2019-01-01', 1, 'oscar@test.com', GETDATE());
SET IDENTITY_INSERT dbo.employees OFF;

SET IDENTITY_INSERT dbo.salaries ON;
INSERT INTO dbo.salaries (salary_id, employee_id, base_salary, effective_from, effective_to)
VALUES 
    (90017, 9015, 60000.00, '2019-01-01', NULL);
SET IDENTITY_INSERT dbo.salaries OFF;

-- EXEC
EXEC dbo.usp_propagate_salary_raise @raise_pct = 5.00, @min_years_of_service = 3;

-- ASSERT
-- Old record should have effective_to = today - 1 day
SELECT 'TC13' AS tc, 'old_record_closed' AS check_type,
       employee_id,
       CASE 
           WHEN effective_to = DATEADD(dd, -1, CAST(GETDATE() AS DATE)) THEN 'CORRECT'
           ELSE 'INCORRECT'
       END AS effective_to_check
FROM dbo.salaries
WHERE employee_id = 9015
  AND effective_to IS NOT NULL;

-- New record should have effective_from = today
SELECT 'TC13' AS tc, 'new_record_date' AS check_type,
       employee_id,
       CASE 
           WHEN effective_from = CAST(GETDATE() AS DATE) THEN 'CORRECT'
           ELSE 'INCORRECT'
       END AS effective_from_check
FROM dbo.salaries
WHERE employee_id = 9015
  AND effective_to IS NULL
  AND salary_id > 90017;

-- CLEANUP
ROLLBACK TRANSACTION;

-- ============= TEST CASE 14: Multiple eligible employees processed in one call =============
-- SETUP
BEGIN TRANSACTION;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES 
    (9016, 1, 'Paul', 'TestRaise', '2019-01-01', 1, 'paul@test.com', GETDATE()),
    (9017, 1, 'Quinn', 'TestRaise', '2020-01-01', 1, 'quinn@test.com', GETDATE()),
    (9018, 1, 'Rachel', 'TestRaise', '2021-01-01', 1, 'rachel@test.com', GETDATE());
SET IDENTITY_INSERT dbo.employees OFF;

SET IDENTITY_INSERT dbo.salaries ON;
INSERT INTO dbo.salaries (salary_id, employee_id, base_salary, effective_from, effective_to)
VALUES 
    (90018, 9016, 50000.00, '2019-01-01', NULL),
    (90019, 9017, 55000.00, '2020-01-01', NULL),
    (90020, 9018, 60000.00, '2021-01-01', NULL);
SET IDENTITY_INSERT dbo.salaries OFF;

-- EXEC
EXEC dbo.usp_propagate_salary_raise @raise_pct = 8.00, @min_years_of_service = 3;

-- ASSERT
-- All three should get raises
SELECT 'TC14' AS tc, 'multiple_employees' AS check_type,
       COUNT(*) AS employees_with_new_salary
FROM dbo.salaries
WHERE employee_id IN (9016, 9017, 9018)
  AND effective_to IS NULL
  AND salary_id > 90020;

SELECT 'TC14' AS tc, 'salary_details' AS check_type,
       employee_id,
       CAST(base_salary AS DECIMAL(10,2)) AS salary_rounded
FROM dbo.salaries
WHERE employee_id IN (9016, 9017, 9018)
  AND effective_to IS NULL
ORDER BY employee_id;

-- CLEANUP
ROLLBACK TRANSACTION;

-- =============================================
-- END OF TEST SUITE
-- =============================================
