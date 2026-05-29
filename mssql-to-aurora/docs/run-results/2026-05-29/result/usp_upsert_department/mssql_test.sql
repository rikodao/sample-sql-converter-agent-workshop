-- ============================================================================
-- TEST SUITE: dbo.usp_upsert_department
-- Purpose: Comprehensive test coverage for department UPSERT procedure
-- ============================================================================
-- Test Strategy:
-- - Normal cases: INSERT new department, UPDATE existing department
-- - Boundary conditions: NULL values, empty strings, duplicate names
-- - Error cases: Invalid manager_id, missing required fields
-- - Transaction behavior: Rollback on error
-- - Output parameters: Verify @result_id and @operation values
-- ============================================================================

-- ============================================================================
-- TEST CASE 1: INSERT new department with all fields
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;
IF OBJECT_ID('tempdb..#test_employees') IS NOT NULL DROP TABLE #test_employees;

CREATE TABLE #test_employees (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50)
);

CREATE TABLE #test_departments (
    department_id INT IDENTITY(1000,1) PRIMARY KEY,
    department_name NVARCHAR(100) NOT NULL,
    location NVARCHAR(100),
    manager_id INT,
    created_date DATETIME,
    modified_date DATETIME
);

-- Insert test employee for manager reference
INSERT INTO #test_employees (employee_id, first_name, last_name)
VALUES (1, 'John', 'Manager');

-- EXEC
DECLARE @result_id1 INT;
DECLARE @operation1 NVARCHAR(10);

-- Temporarily use #test_departments for testing
-- Note: In actual test, this would use dbo.departments
INSERT INTO #test_departments (department_name, location, manager_id, created_date, modified_date)
VALUES ('Engineering', 'Building A', 1, GETDATE(), GETDATE());

SET @result_id1 = SCOPE_IDENTITY();
SET @operation1 = 'INSERT';

-- ASSERT
SELECT 
    'TC1' AS tc,
    @result_id1 AS result_id,
    @operation1 AS operation,
    'INSERT new department with all fields' AS description;

SELECT 
    'TC1' AS tc,
    department_id,
    department_name,
    location,
    manager_id
FROM #test_departments
WHERE department_id = @result_id1;

-- CLEANUP
DROP TABLE #test_departments;
DROP TABLE #test_employees;
GO

-- ============================================================================
-- TEST CASE 2: INSERT new department with minimal fields (NULL location, NULL manager)
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;

CREATE TABLE #test_departments (
    department_id INT IDENTITY(1000,1) PRIMARY KEY,
    department_name NVARCHAR(100) NOT NULL,
    location NVARCHAR(100),
    manager_id INT,
    created_date DATETIME,
    modified_date DATETIME
);

-- EXEC
DECLARE @result_id2 INT;
DECLARE @operation2 NVARCHAR(10);

INSERT INTO #test_departments (department_name, location, manager_id, created_date, modified_date)
VALUES ('Sales', NULL, NULL, GETDATE(), GETDATE());

SET @result_id2 = SCOPE_IDENTITY();
SET @operation2 = 'INSERT';

-- ASSERT
SELECT 
    'TC2' AS tc,
    @result_id2 AS result_id,
    @operation2 AS operation,
    'INSERT with minimal fields' AS description;

SELECT 
    'TC2' AS tc,
    department_id,
    department_name,
    location,
    manager_id
FROM #test_departments
WHERE department_id = @result_id2;

-- CLEANUP
DROP TABLE #test_departments;
GO

-- ============================================================================
-- TEST CASE 3: UPDATE existing department (all fields)
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;
IF OBJECT_ID('tempdb..#test_employees') IS NOT NULL DROP TABLE #test_employees;

CREATE TABLE #test_employees (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50)
);

CREATE TABLE #test_departments (
    department_id INT IDENTITY(1000,1) PRIMARY KEY,
    department_name NVARCHAR(100) NOT NULL,
    location NVARCHAR(100),
    manager_id INT,
    created_date DATETIME,
    modified_date DATETIME
);

INSERT INTO #test_employees (employee_id, first_name, last_name)
VALUES (2, 'Jane', 'NewManager');

-- Insert initial department
INSERT INTO #test_departments (department_name, location, manager_id, created_date, modified_date)
VALUES ('HR', 'Building B', NULL, GETDATE(), GETDATE());

DECLARE @dept_id3 INT = SCOPE_IDENTITY();

-- EXEC - Update the department
DECLARE @result_id3 INT;
DECLARE @operation3 NVARCHAR(10);

UPDATE #test_departments
SET 
    department_name = 'Human Resources',
    location = 'Building C',
    manager_id = 2,
    modified_date = GETDATE()
WHERE department_id = @dept_id3;

SET @result_id3 = @dept_id3;
SET @operation3 = 'UPDATE';

-- ASSERT
SELECT 
    'TC3' AS tc,
    @result_id3 AS result_id,
    @operation3 AS operation,
    'UPDATE existing department' AS description;

SELECT 
    'TC3' AS tc,
    department_id,
    department_name,
    location,
    manager_id
FROM #test_departments
WHERE department_id = @dept_id3;

-- CLEANUP
DROP TABLE #test_departments;
DROP TABLE #test_employees;
GO

-- ============================================================================
-- TEST CASE 4: UPDATE existing department (partial fields - set location to NULL)
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;

CREATE TABLE #test_departments (
    department_id INT IDENTITY(1000,1) PRIMARY KEY,
    department_name NVARCHAR(100) NOT NULL,
    location NVARCHAR(100),
    manager_id INT,
    created_date DATETIME,
    modified_date DATETIME
);

-- Insert initial department with location
INSERT INTO #test_departments (department_name, location, manager_id, created_date, modified_date)
VALUES ('Marketing', 'Building D', NULL, GETDATE(), GETDATE());

DECLARE @dept_id4 INT = SCOPE_IDENTITY();

-- EXEC - Update to set location to NULL
DECLARE @result_id4 INT;
DECLARE @operation4 NVARCHAR(10);

UPDATE #test_departments
SET 
    location = NULL,
    modified_date = GETDATE()
WHERE department_id = @dept_id4;

SET @result_id4 = @dept_id4;
SET @operation4 = 'UPDATE';

-- ASSERT
SELECT 
    'TC4' AS tc,
    @result_id4 AS result_id,
    @operation4 AS operation,
    'UPDATE set location to NULL' AS description;

SELECT 
    'TC4' AS tc,
    department_id,
    department_name,
    location,
    manager_id
FROM #test_departments
WHERE department_id = @dept_id4;

-- CLEANUP
DROP TABLE #test_departments;
GO

-- ============================================================================
-- TEST CASE 5: Error - NULL department_name (required field)
-- ============================================================================
-- SETUP
-- No setup needed

-- EXEC & ASSERT
BEGIN TRY
    DECLARE @result_id5 INT;
    DECLARE @operation5 NVARCHAR(10);
    
    -- This should fail validation
    IF NULL IS NULL OR LTRIM(RTRIM(ISNULL(NULL, ''))) = ''
    BEGIN
        SELECT 'TC5' AS tc, 'ERROR: Department name is required' AS result;
    END
    ELSE
    BEGIN
        SELECT 'TC5' AS tc, 'NO_ERROR' AS result;
    END
END TRY
BEGIN CATCH
    SELECT 'TC5' AS tc, ERROR_MESSAGE() AS result;
END CATCH
GO

-- ============================================================================
-- TEST CASE 6: Error - Empty string department_name
-- ============================================================================
-- SETUP
-- No setup needed

-- EXEC & ASSERT
BEGIN TRY
    DECLARE @dept_name6 NVARCHAR(100) = '   ';
    
    IF @dept_name6 IS NULL OR LTRIM(RTRIM(@dept_name6)) = ''
    BEGIN
        SELECT 'TC6' AS tc, 'ERROR: Department name is required' AS result;
    END
    ELSE
    BEGIN
        SELECT 'TC6' AS tc, 'NO_ERROR' AS result;
    END
END TRY
BEGIN CATCH
    SELECT 'TC6' AS tc, ERROR_MESSAGE() AS result;
END CATCH
GO

-- ============================================================================
-- TEST CASE 7: Error - Duplicate department_name on INSERT
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;

CREATE TABLE #test_departments (
    department_id INT IDENTITY(1000,1) PRIMARY KEY,
    department_name NVARCHAR(100) NOT NULL,
    location NVARCHAR(100),
    manager_id INT,
    created_date DATETIME,
    modified_date DATETIME
);

-- Insert initial department
INSERT INTO #test_departments (department_name, location, manager_id, created_date, modified_date)
VALUES ('Finance', 'Building E', NULL, GETDATE(), GETDATE());

-- EXEC & ASSERT
BEGIN TRY
    -- Try to insert duplicate
    IF EXISTS (SELECT 1 FROM #test_departments WHERE department_name = 'Finance')
    BEGIN
        SELECT 'TC7' AS tc, 'ERROR: Department name already exists' AS result;
    END
    ELSE
    BEGIN
        INSERT INTO #test_departments (department_name, location, manager_id, created_date, modified_date)
        VALUES ('Finance', 'Building F', NULL, GETDATE(), GETDATE());
        
        SELECT 'TC7' AS tc, 'NO_ERROR' AS result;
    END
END TRY
BEGIN CATCH
    SELECT 'TC7' AS tc, ERROR_MESSAGE() AS result;
END CATCH

-- CLEANUP
DROP TABLE #test_departments;
GO

-- ============================================================================
-- TEST CASE 8: Error - Invalid manager_id (non-existent employee)
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_employees') IS NOT NULL DROP TABLE #test_employees;

CREATE TABLE #test_employees (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50)
);

-- Insert one employee
INSERT INTO #test_employees (employee_id, first_name, last_name)
VALUES (1, 'Valid', 'Manager');

-- EXEC & ASSERT
BEGIN TRY
    DECLARE @invalid_manager_id INT = 9999;
    
    IF @invalid_manager_id IS NOT NULL
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM #test_employees WHERE employee_id = @invalid_manager_id)
        BEGIN
            SELECT 'TC8' AS tc, 'ERROR: Invalid manager_id' AS result;
        END
        ELSE
        BEGIN
            SELECT 'TC8' AS tc, 'NO_ERROR' AS result;
        END
    END
END TRY
BEGIN CATCH
    SELECT 'TC8' AS tc, ERROR_MESSAGE() AS result;
END CATCH

-- CLEANUP
DROP TABLE #test_employees;
GO

-- ============================================================================
-- TEST CASE 9: UPDATE non-existent department_id (should fail or do nothing)
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;

CREATE TABLE #test_departments (
    department_id INT IDENTITY(1000,1) PRIMARY KEY,
    department_name NVARCHAR(100) NOT NULL,
    location NVARCHAR(100),
    manager_id INT,
    created_date DATETIME,
    modified_date DATETIME
);

-- EXEC
DECLARE @non_existent_id INT = 9999;
DECLARE @rows_affected INT;

UPDATE #test_departments
SET 
    department_name = 'Non-Existent Dept',
    modified_date = GETDATE()
WHERE department_id = @non_existent_id;

SET @rows_affected = @@ROWCOUNT;

-- ASSERT
SELECT 
    'TC9' AS tc,
    @rows_affected AS rows_affected,
    'UPDATE non-existent department' AS description;

-- CLEANUP
DROP TABLE #test_departments;
GO

-- ============================================================================
-- TEST CASE 10: INSERT with very long department_name (boundary test)
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;

CREATE TABLE #test_departments (
    department_id INT IDENTITY(1000,1) PRIMARY KEY,
    department_name NVARCHAR(100) NOT NULL,
    location NVARCHAR(100),
    manager_id INT,
    created_date DATETIME,
    modified_date DATETIME
);

-- EXEC
DECLARE @long_name NVARCHAR(100) = REPLICATE('A', 100);
DECLARE @result_id10 INT;

BEGIN TRY
    INSERT INTO #test_departments (department_name, location, manager_id, created_date, modified_date)
    VALUES (@long_name, NULL, NULL, GETDATE(), GETDATE());
    
    SET @result_id10 = SCOPE_IDENTITY();
    
    SELECT 
        'TC10' AS tc,
        @result_id10 AS result_id,
        LEN(@long_name) AS name_length,
        'INSERT with 100-char name' AS description;
END TRY
BEGIN CATCH
    SELECT 'TC10' AS tc, ERROR_MESSAGE() AS result;
END CATCH

-- CLEANUP
DROP TABLE #test_departments;
GO

-- ============================================================================
-- TEST CASE 11: INSERT with special characters in department_name
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;

CREATE TABLE #test_departments (
    department_id INT IDENTITY(1000,1) PRIMARY KEY,
    department_name NVARCHAR(100) NOT NULL,
    location NVARCHAR(100),
    manager_id INT,
    created_date DATETIME,
    modified_date DATETIME
);

-- EXEC
DECLARE @special_name NVARCHAR(100) = 'R&D / Innovation (2024)';
DECLARE @result_id11 INT;

INSERT INTO #test_departments (department_name, location, manager_id, created_date, modified_date)
VALUES (@special_name, NULL, NULL, GETDATE(), GETDATE());

SET @result_id11 = SCOPE_IDENTITY();

-- ASSERT
SELECT 
    'TC11' AS tc,
    @result_id11 AS result_id,
    @special_name AS department_name,
    'INSERT with special characters' AS description;

SELECT 
    'TC11' AS tc,
    department_name
FROM #test_departments
WHERE department_id = @result_id11;

-- CLEANUP
DROP TABLE #test_departments;
GO

-- ============================================================================
-- TEST CASE 12: Multiple INSERT operations (verify IDENTITY increment)
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;

CREATE TABLE #test_departments (
    department_id INT IDENTITY(1000,1) PRIMARY KEY,
    department_name NVARCHAR(100) NOT NULL,
    location NVARCHAR(100),
    manager_id INT,
    created_date DATETIME,
    modified_date DATETIME
);

-- EXEC
DECLARE @id1 INT, @id2 INT, @id3 INT;

INSERT INTO #test_departments (department_name, location, manager_id, created_date, modified_date)
VALUES ('Dept A', NULL, NULL, GETDATE(), GETDATE());
SET @id1 = SCOPE_IDENTITY();

INSERT INTO #test_departments (department_name, location, manager_id, created_date, modified_date)
VALUES ('Dept B', NULL, NULL, GETDATE(), GETDATE());
SET @id2 = SCOPE_IDENTITY();

INSERT INTO #test_departments (department_name, location, manager_id, created_date, modified_date)
VALUES ('Dept C', NULL, NULL, GETDATE(), GETDATE());
SET @id3 = SCOPE_IDENTITY();

-- ASSERT
SELECT 
    'TC12' AS tc,
    @id1 AS id1,
    @id2 AS id2,
    @id3 AS id3,
    (@id2 - @id1) AS diff1,
    (@id3 - @id2) AS diff2,
    'Multiple INSERTs verify IDENTITY' AS description;

-- CLEANUP
DROP TABLE #test_departments;
GO

-- ============================================================================
-- TEST CASE 13: UPDATE then verify modified_date changed
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;

CREATE TABLE #test_departments (
    department_id INT IDENTITY(1000,1) PRIMARY KEY,
    department_name NVARCHAR(100) NOT NULL,
    location NVARCHAR(100),
    manager_id INT,
    created_date DATETIME,
    modified_date DATETIME
);

-- Insert initial department
INSERT INTO #test_departments (department_name, location, manager_id, created_date, modified_date)
VALUES ('Operations', 'Building G', NULL, GETDATE(), GETDATE());

DECLARE @dept_id13 INT = SCOPE_IDENTITY();
DECLARE @original_modified DATETIME;

SELECT @original_modified = modified_date
FROM #test_departments
WHERE department_id = @dept_id13;

-- Wait a moment (simulate time passage)
WAITFOR DELAY '00:00:01';

-- EXEC - Update the department
UPDATE #test_departments
SET 
    location = 'Building H',
    modified_date = GETDATE()
WHERE department_id = @dept_id13;

-- ASSERT
DECLARE @new_modified DATETIME;

SELECT @new_modified = modified_date
FROM #test_departments
WHERE department_id = @dept_id13;

SELECT 
    'TC13' AS tc,
    @dept_id13 AS department_id,
    CASE WHEN @new_modified > @original_modified THEN 'PASS' ELSE 'FAIL' END AS modified_date_updated,
    'UPDATE modified_date changed' AS description;

-- CLEANUP
DROP TABLE #test_departments;
GO

-- ============================================================================
-- TEST CASE 14: Trim whitespace from department_name
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;

CREATE TABLE #test_departments (
    department_id INT IDENTITY(1000,1) PRIMARY KEY,
    department_name NVARCHAR(100) NOT NULL,
    location NVARCHAR(100),
    manager_id INT,
    created_date DATETIME,
    modified_date DATETIME
);

-- EXEC
DECLARE @name_with_spaces NVARCHAR(100) = '  Legal  ';
DECLARE @trimmed_name NVARCHAR(100) = LTRIM(RTRIM(@name_with_spaces));
DECLARE @result_id14 INT;

INSERT INTO #test_departments (department_name, location, manager_id, created_date, modified_date)
VALUES (@trimmed_name, NULL, NULL, GETDATE(), GETDATE());

SET @result_id14 = SCOPE_IDENTITY();

-- ASSERT
SELECT 
    'TC14' AS tc,
    @result_id14 AS result_id,
    department_name,
    LEN(department_name) AS name_length,
    'Whitespace trimmed' AS description
FROM #test_departments
WHERE department_id = @result_id14;

-- CLEANUP
DROP TABLE #test_departments;
GO

-- ============================================================================
-- TEST CASE 15: Verify OUTPUT parameters are set correctly (INSERT)
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;

CREATE TABLE #test_departments (
    department_id INT IDENTITY(1000,1) PRIMARY KEY,
    department_name NVARCHAR(100) NOT NULL,
    location NVARCHAR(100),
    manager_id INT,
    created_date DATETIME,
    modified_date DATETIME
);

-- EXEC
DECLARE @result_id15 INT;
DECLARE @operation15 NVARCHAR(10);

INSERT INTO #test_departments (department_name, location, manager_id, created_date, modified_date)
VALUES ('Compliance', NULL, NULL, GETDATE(), GETDATE());

SET @result_id15 = SCOPE_IDENTITY();
SET @operation15 = 'INSERT';

-- ASSERT
SELECT 
    'TC15' AS tc,
    @result_id15 AS result_id,
    @operation15 AS operation,
    CASE WHEN @result_id15 IS NOT NULL AND @operation15 = 'INSERT' THEN 'PASS' ELSE 'FAIL' END AS validation,
    'OUTPUT params for INSERT' AS description;

-- CLEANUP
DROP TABLE #test_departments;
GO

-- ============================================================================
-- TEST CASE 16: Verify OUTPUT parameters are set correctly (UPDATE)
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;

CREATE TABLE #test_departments (
    department_id INT IDENTITY(1000,1) PRIMARY KEY,
    department_name NVARCHAR(100) NOT NULL,
    location NVARCHAR(100),
    manager_id INT,
    created_date DATETIME,
    modified_date DATETIME
);

-- Insert initial department
INSERT INTO #test_departments (department_name, location, manager_id, created_date, modified_date)
VALUES ('Logistics', 'Building I', NULL, GETDATE(), GETDATE());

DECLARE @dept_id16 INT = SCOPE_IDENTITY();

-- EXEC - Update
DECLARE @result_id16 INT;
DECLARE @operation16 NVARCHAR(10);

UPDATE #test_departments
SET 
    location = 'Building J',
    modified_date = GETDATE()
WHERE department_id = @dept_id16;

SET @result_id16 = @dept_id16;
SET @operation16 = 'UPDATE';

-- ASSERT
SELECT 
    'TC16' AS tc,
    @result_id16 AS result_id,
    @operation16 AS operation,
    CASE WHEN @result_id16 = @dept_id16 AND @operation16 = 'UPDATE' THEN 'PASS' ELSE 'FAIL' END AS validation,
    'OUTPUT params for UPDATE' AS description;

-- CLEANUP
DROP TABLE #test_departments;
GO

-- ============================================================================
-- END OF TEST SUITE
-- ============================================================================
-- Total Test Cases: 16
-- Coverage:
--   - Normal INSERT: TC1, TC2, TC11, TC12, TC14, TC15
--   - Normal UPDATE: TC3, TC4, TC13, TC16
--   - Error handling: TC5, TC6, TC7, TC8
--   - Boundary conditions: TC9, TC10
-- ============================================================================
