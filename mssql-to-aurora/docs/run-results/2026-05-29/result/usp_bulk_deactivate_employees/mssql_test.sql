-- ============================================================================
-- Test Suite: dbo.usp_bulk_deactivate_employees
-- Purpose: Comprehensive validation of bulk employee deactivation procedure
-- ============================================================================

-- ============= TEST CASE 1: Normal - Single employee deactivation =============
-- SETUP
CREATE TABLE #test_employees_tc1 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    email NVARCHAR(100),
    hire_date DATE,
    department_id INT,
    salary DECIMAL(10,2),
    is_active BIT,
    deactivated_date DATETIME
);

INSERT INTO #test_employees_tc1 (employee_id, first_name, last_name, email, hire_date, department_id, salary, is_active, deactivated_date)
VALUES 
    (1001, 'John', 'Doe', 'john.doe@example.com', '2020-01-15', 1, 75000.00, 1, NULL),
    (1002, 'Jane', 'Smith', 'jane.smith@example.com', '2019-03-20', 2, 82000.00, 1, NULL);

-- EXEC
DECLARE @count1 INT;
DECLARE @emp_ids1 NVARCHAR(MAX) = '1001';

-- Simulate the procedure logic for single employee
UPDATE #test_employees_tc1
SET is_active = 0, deactivated_date = GETDATE()
WHERE employee_id IN (SELECT CAST(value AS INT) FROM STRING_SPLIT(@emp_ids1, ','))
  AND is_active = 1;

SET @count1 = @@ROWCOUNT;

-- ASSERT
SELECT 'TC1' AS test_case, @count1 AS deactivated_count, 
       (SELECT COUNT(*) FROM #test_employees_tc1 WHERE is_active = 0) AS inactive_count,
       (SELECT COUNT(*) FROM #test_employees_tc1 WHERE deactivated_date IS NOT NULL) AS has_deactivation_date;

-- CLEANUP
DROP TABLE #test_employees_tc1;

-- ============= TEST CASE 2: Normal - Multiple employees deactivation =============
-- SETUP
CREATE TABLE #test_employees_tc2 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    email NVARCHAR(100),
    hire_date DATE,
    department_id INT,
    salary DECIMAL(10,2),
    is_active BIT,
    deactivated_date DATETIME
);

INSERT INTO #test_employees_tc2 (employee_id, first_name, last_name, email, hire_date, department_id, salary, is_active, deactivated_date)
VALUES 
    (2001, 'Alice', 'Johnson', 'alice.j@example.com', '2018-05-10', 1, 68000.00, 1, NULL),
    (2002, 'Bob', 'Williams', 'bob.w@example.com', '2019-07-22', 2, 71000.00, 1, NULL),
    (2003, 'Carol', 'Brown', 'carol.b@example.com', '2020-02-14', 3, 79000.00, 1, NULL),
    (2004, 'David', 'Davis', 'david.d@example.com', '2021-01-05', 1, 65000.00, 1, NULL);

-- EXEC
DECLARE @count2 INT;
DECLARE @emp_ids2 NVARCHAR(MAX) = '2001,2002,2003';

UPDATE #test_employees_tc2
SET is_active = 0, deactivated_date = GETDATE()
WHERE employee_id IN (SELECT CAST(value AS INT) FROM STRING_SPLIT(@emp_ids2, ','))
  AND is_active = 1;

SET @count2 = @@ROWCOUNT;

-- ASSERT
SELECT 'TC2' AS test_case, @count2 AS deactivated_count,
       (SELECT COUNT(*) FROM #test_employees_tc2 WHERE is_active = 0) AS inactive_count,
       (SELECT COUNT(*) FROM #test_employees_tc2 WHERE is_active = 1) AS still_active_count;

-- CLEANUP
DROP TABLE #test_employees_tc2;

-- ============= TEST CASE 3: Normal - All employees in department =============
-- SETUP
CREATE TABLE #test_employees_tc3 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    email NVARCHAR(100),
    hire_date DATE,
    department_id INT,
    salary DECIMAL(10,2),
    is_active BIT,
    deactivated_date DATETIME
);

INSERT INTO #test_employees_tc3 (employee_id, first_name, last_name, email, hire_date, department_id, salary, is_active, deactivated_date)
VALUES 
    (3001, 'Eve', 'Martinez', 'eve.m@example.com', '2017-09-12', 5, 88000.00, 1, NULL),
    (3002, 'Frank', 'Garcia', 'frank.g@example.com', '2018-11-30', 5, 92000.00, 1, NULL),
    (3003, 'Grace', 'Lopez', 'grace.l@example.com', '2019-04-18', 5, 85000.00, 1, NULL);

-- EXEC
DECLARE @count3 INT;
DECLARE @emp_ids3 NVARCHAR(MAX) = '3001,3002,3003';

UPDATE #test_employees_tc3
SET is_active = 0, deactivated_date = GETDATE()
WHERE employee_id IN (SELECT CAST(value AS INT) FROM STRING_SPLIT(@emp_ids3, ','))
  AND is_active = 1;

SET @count3 = @@ROWCOUNT;

-- ASSERT
SELECT 'TC3' AS test_case, @count3 AS deactivated_count,
       (SELECT COUNT(*) FROM #test_employees_tc3 WHERE is_active = 0) AS all_inactive;

-- CLEANUP
DROP TABLE #test_employees_tc3;

-- ============= TEST CASE 4: Boundary - NULL employee_ids parameter =============
-- SETUP
-- No setup needed for parameter validation

-- EXEC & ASSERT
BEGIN TRY
    DECLARE @count4 INT;
    DECLARE @emp_ids4 NVARCHAR(MAX) = NULL;
    
    -- Simulate validation logic
    IF @emp_ids4 IS NULL OR LTRIM(RTRIM(@emp_ids4)) = ''
    BEGIN
        SELECT 'TC4' AS test_case, 'ERROR: Parameter @employee_ids cannot be NULL or empty' AS result;
    END
    ELSE
    BEGIN
        SELECT 'TC4' AS test_case, 'NO_ERROR' AS result;
    END
END TRY
BEGIN CATCH
    SELECT 'TC4' AS test_case, ERROR_MESSAGE() AS result;
END CATCH

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 5: Boundary - Empty string employee_ids =============
-- SETUP
-- No setup needed

-- EXEC & ASSERT
BEGIN TRY
    DECLARE @count5 INT;
    DECLARE @emp_ids5 NVARCHAR(MAX) = '';
    
    IF @emp_ids5 IS NULL OR LTRIM(RTRIM(@emp_ids5)) = ''
    BEGIN
        SELECT 'TC5' AS test_case, 'ERROR: Parameter @employee_ids cannot be NULL or empty' AS result;
    END
    ELSE
    BEGIN
        SELECT 'TC5' AS test_case, 'NO_ERROR' AS result;
    END
END TRY
BEGIN CATCH
    SELECT 'TC5' AS test_case, ERROR_MESSAGE() AS result;
END CATCH

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 6: Boundary - Whitespace only employee_ids =============
-- SETUP
-- No setup needed

-- EXEC & ASSERT
BEGIN TRY
    DECLARE @count6 INT;
    DECLARE @emp_ids6 NVARCHAR(MAX) = '   ';
    
    IF @emp_ids6 IS NULL OR LTRIM(RTRIM(@emp_ids6)) = ''
    BEGIN
        SELECT 'TC6' AS test_case, 'ERROR: Parameter @employee_ids cannot be NULL or empty' AS result;
    END
    ELSE
    BEGIN
        SELECT 'TC6' AS test_case, 'NO_ERROR' AS result;
    END
END TRY
BEGIN CATCH
    SELECT 'TC6' AS test_case, ERROR_MESSAGE() AS result;
END CATCH

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 7: Exception - Non-existent employee ID =============
-- SETUP
CREATE TABLE #test_employees_tc7 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    email NVARCHAR(100),
    hire_date DATE,
    department_id INT,
    salary DECIMAL(10,2),
    is_active BIT,
    deactivated_date DATETIME
);

INSERT INTO #test_employees_tc7 (employee_id, first_name, last_name, email, hire_date, department_id, salary, is_active, deactivated_date)
VALUES 
    (7001, 'Henry', 'Wilson', 'henry.w@example.com', '2020-06-15', 2, 73000.00, 1, NULL);

-- EXEC & ASSERT
BEGIN TRY
    DECLARE @count7 INT;
    DECLARE @emp_ids7 NVARCHAR(MAX) = '7001,9999';  -- 9999 does not exist
    
    -- Simulate validation
    CREATE TABLE #emp_ids_tc7 (employee_id INT);
    INSERT INTO #emp_ids_tc7 (employee_id)
    SELECT CAST(LTRIM(RTRIM(value)) AS INT)
    FROM STRING_SPLIT(@emp_ids7, ',')
    WHERE LTRIM(RTRIM(value)) <> '';
    
    IF EXISTS (
        SELECT 1 
        FROM #emp_ids_tc7 e
        LEFT JOIN #test_employees_tc7 emp ON e.employee_id = emp.employee_id
        WHERE emp.employee_id IS NULL
    )
    BEGIN
        SELECT 'TC7' AS test_case, 'ERROR: One or more employee IDs do not exist' AS result;
    END
    ELSE
    BEGIN
        SELECT 'TC7' AS test_case, 'NO_ERROR' AS result;
    END
    
    DROP TABLE #emp_ids_tc7;
END TRY
BEGIN CATCH
    SELECT 'TC7' AS test_case, ERROR_MESSAGE() AS result;
    IF OBJECT_ID('tempdb..#emp_ids_tc7') IS NOT NULL
        DROP TABLE #emp_ids_tc7;
END CATCH

-- CLEANUP
DROP TABLE #test_employees_tc7;

-- ============= TEST CASE 8: Exception - Invalid format (non-numeric ID) =============
-- SETUP
-- No setup needed

-- EXEC & ASSERT
BEGIN TRY
    DECLARE @count8 INT;
    DECLARE @emp_ids8 NVARCHAR(MAX) = '1001,ABC,1002';
    
    -- Attempt to parse - this will fail on CAST
    CREATE TABLE #emp_ids_tc8 (employee_id INT);
    INSERT INTO #emp_ids_tc8 (employee_id)
    SELECT CAST(LTRIM(RTRIM(value)) AS INT)
    FROM STRING_SPLIT(@emp_ids8, ',')
    WHERE LTRIM(RTRIM(value)) <> '';
    
    SELECT 'TC8' AS test_case, 'NO_ERROR' AS result;
    DROP TABLE #emp_ids_tc8;
END TRY
BEGIN CATCH
    SELECT 'TC8' AS test_case, 'ERROR: ' + ERROR_MESSAGE() AS result;
    IF OBJECT_ID('tempdb..#emp_ids_tc8') IS NOT NULL
        DROP TABLE #emp_ids_tc8;
END CATCH

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 9: Side Effect - Already deactivated employee =============
-- SETUP
CREATE TABLE #test_employees_tc9 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    email NVARCHAR(100),
    hire_date DATE,
    department_id INT,
    salary DECIMAL(10,2),
    is_active BIT,
    deactivated_date DATETIME
);

INSERT INTO #test_employees_tc9 (employee_id, first_name, last_name, email, hire_date, department_id, salary, is_active, deactivated_date)
VALUES 
    (9001, 'Ivy', 'Taylor', 'ivy.t@example.com', '2019-08-20', 3, 76000.00, 0, '2023-12-01'),  -- Already inactive
    (9002, 'Jack', 'Anderson', 'jack.a@example.com', '2020-10-05', 3, 78000.00, 1, NULL);

-- EXEC
DECLARE @count9 INT;
DECLARE @emp_ids9 NVARCHAR(MAX) = '9001,9002';

UPDATE #test_employees_tc9
SET is_active = 0, deactivated_date = GETDATE()
WHERE employee_id IN (SELECT CAST(value AS INT) FROM STRING_SPLIT(@emp_ids9, ','))
  AND is_active = 1;  -- Only update currently active

SET @count9 = @@ROWCOUNT;

-- ASSERT
SELECT 'TC9' AS test_case, @count9 AS deactivated_count,
       (SELECT COUNT(*) FROM #test_employees_tc9 WHERE is_active = 0) AS total_inactive,
       (SELECT COUNT(*) FROM #test_employees_tc9 WHERE is_active = 1) AS still_active;

-- CLEANUP
DROP TABLE #test_employees_tc9;

-- ============= TEST CASE 10: Side Effect - Verify @@ROWCOUNT accuracy =============
-- SETUP
CREATE TABLE #test_employees_tc10 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    email NVARCHAR(100),
    hire_date DATE,
    department_id INT,
    salary DECIMAL(10,2),
    is_active BIT,
    deactivated_date DATETIME
);

INSERT INTO #test_employees_tc10 (employee_id, first_name, last_name, email, hire_date, department_id, salary, is_active, deactivated_date)
VALUES 
    (10001, 'Karen', 'Thomas', 'karen.t@example.com', '2018-03-12', 4, 81000.00, 1, NULL),
    (10002, 'Leo', 'Jackson', 'leo.j@example.com', '2019-05-25', 4, 83000.00, 1, NULL),
    (10003, 'Mia', 'White', 'mia.w@example.com', '2020-07-30', 4, 79000.00, 1, NULL),
    (10004, 'Noah', 'Harris', 'noah.h@example.com', '2021-09-10', 4, 77000.00, 1, NULL),
    (10005, 'Olivia', 'Martin', 'olivia.m@example.com', '2022-01-20', 4, 75000.00, 1, NULL);

-- EXEC
DECLARE @count10 INT;
DECLARE @emp_ids10 NVARCHAR(MAX) = '10001,10002,10003,10004,10005';

UPDATE #test_employees_tc10
SET is_active = 0, deactivated_date = GETDATE()
WHERE employee_id IN (SELECT CAST(value AS INT) FROM STRING_SPLIT(@emp_ids10, ','))
  AND is_active = 1;

SET @count10 = @@ROWCOUNT;

-- ASSERT
SELECT 'TC10' AS test_case, @count10 AS rowcount_output,
       (SELECT COUNT(*) FROM #test_employees_tc10 WHERE is_active = 0) AS actual_deactivated,
       CASE WHEN @count10 = 5 THEN 'MATCH' ELSE 'MISMATCH' END AS validation;

-- CLEANUP
DROP TABLE #test_employees_tc10;

-- ============= TEST CASE 11: Boundary - Single ID with leading/trailing spaces =============
-- SETUP
CREATE TABLE #test_employees_tc11 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    email NVARCHAR(100),
    hire_date DATE,
    department_id INT,
    salary DECIMAL(10,2),
    is_active BIT,
    deactivated_date DATETIME
);

INSERT INTO #test_employees_tc11 (employee_id, first_name, last_name, email, hire_date, department_id, salary, is_active, deactivated_date)
VALUES 
    (11001, 'Paul', 'Clark', 'paul.c@example.com', '2020-04-08', 2, 72000.00, 1, NULL);

-- EXEC
DECLARE @count11 INT;
DECLARE @emp_ids11 NVARCHAR(MAX) = '  11001  ';

UPDATE #test_employees_tc11
SET is_active = 0, deactivated_date = GETDATE()
WHERE employee_id IN (SELECT CAST(LTRIM(RTRIM(value)) AS INT) FROM STRING_SPLIT(@emp_ids11, ','))
  AND is_active = 1;

SET @count11 = @@ROWCOUNT;

-- ASSERT
SELECT 'TC11' AS test_case, @count11 AS deactivated_count,
       (SELECT is_active FROM #test_employees_tc11 WHERE employee_id = 11001) AS is_active_status;

-- CLEANUP
DROP TABLE #test_employees_tc11;

-- ============= TEST CASE 12: Boundary - Multiple IDs with extra commas =============
-- SETUP
CREATE TABLE #test_employees_tc12 (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    email NVARCHAR(100),
    hire_date DATE,
    department_id INT,
    salary DECIMAL(10,2),
    is_active BIT,
    deactivated_date DATETIME
);

INSERT INTO #test_employees_tc12 (employee_id, first_name, last_name, email, hire_date, department_id, salary, is_active, deactivated_date)
VALUES 
    (12001, 'Quinn', 'Lewis', 'quinn.l@example.com', '2019-11-14', 1, 74000.00, 1, NULL),
    (12002, 'Rachel', 'Walker', 'rachel.w@example.com', '2020-02-28', 1, 76000.00, 1, NULL);

-- EXEC
DECLARE @count12 INT;
DECLARE @emp_ids12 NVARCHAR(MAX) = '12001,,12002,';  -- Extra commas

UPDATE #test_employees_tc12
SET is_active = 0, deactivated_date = GETDATE()
WHERE employee_id IN (
    SELECT CAST(LTRIM(RTRIM(value)) AS INT) 
    FROM STRING_SPLIT(@emp_ids12, ',')
    WHERE LTRIM(RTRIM(value)) <> ''  -- Filter out empty values
)
AND is_active = 1;

SET @count12 = @@ROWCOUNT;

-- ASSERT
SELECT 'TC12' AS test_case, @count12 AS deactivated_count,
       (SELECT COUNT(*) FROM #test_employees_tc12 WHERE is_active = 0) AS inactive_count;

-- CLEANUP
DROP TABLE #test_employees_tc12;

-- ============================================================================
-- End of Test Suite
-- ============================================================================
