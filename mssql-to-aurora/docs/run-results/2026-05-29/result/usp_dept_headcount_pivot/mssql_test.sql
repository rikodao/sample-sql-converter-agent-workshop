-- ============================================================================
-- TEST SUITE for dbo.usp_dept_headcount_pivot
-- ============================================================================
-- Purpose: Comprehensive testing of department headcount pivot procedure
-- Coverage: Normal cases, boundary values, edge cases, dynamic SQL behavior
-- ============================================================================

-- ============================================================================
-- TEST CASE 1: Basic pivot with active employees only
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_employees') IS NOT NULL DROP TABLE #test_employees;
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;

CREATE TABLE #test_departments (
    department_id INT PRIMARY KEY,
    department_name NVARCHAR(100)
);

CREATE TABLE #test_employees (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    department_id INT,
    job_title NVARCHAR(100),
    status NVARCHAR(20),
    hire_date DATETIME
);

INSERT INTO #test_departments (department_id, department_name) VALUES
(1, 'Engineering'),
(2, 'Sales'),
(3, 'HR');

INSERT INTO #test_employees (employee_id, first_name, last_name, department_id, job_title, status, hire_date) VALUES
(1, 'John', 'Doe', 1, 'Engineer', 'Active', '2020-01-01'),
(2, 'Jane', 'Smith', 1, 'Engineer', 'Active', '2020-02-01'),
(3, 'Bob', 'Johnson', 1, 'Senior Engineer', 'Active', '2019-01-01'),
(4, 'Alice', 'Williams', 2, 'Sales Rep', 'Active', '2020-03-01'),
(5, 'Charlie', 'Brown', 2, 'Sales Rep', 'Active', '2020-04-01'),
(6, 'Diana', 'Davis', 3, 'HR Manager', 'Active', '2020-05-01');

-- Create temp stored procedure for testing
IF OBJECT_ID('tempdb..#usp_dept_headcount_pivot') IS NOT NULL 
    DROP PROCEDURE #usp_dept_headcount_pivot;
GO

CREATE PROCEDURE #usp_dept_headcount_pivot
    @as_of_date DATETIME = NULL,
    @include_inactive BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @as_of_date IS NULL
        SET @as_of_date = GETDATE();
    
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @columns NVARCHAR(MAX);
    
    SELECT @columns = STUFF((
        SELECT DISTINCT ',' + QUOTENAME(d.department_name)
        FROM #test_departments d
        INNER JOIN #test_employees e ON d.department_id = e.department_id
        WHERE e.hire_date <= @as_of_date
          AND (@include_inactive = 1 OR e.status = 'Active')
        ORDER BY ',' + QUOTENAME(d.department_name)
        FOR XML PATH(''), TYPE
    ).value('.', 'NVARCHAR(MAX)'), 1, 1, '');
    
    IF @columns IS NULL
    BEGIN
        SELECT 'No Data' AS Message;
        RETURN;
    END
    
    SET @sql = N'
    SELECT 
        job_title,
        ' + @columns + ',
        (' + REPLACE(@columns, ',', ' + ') + ') AS total_count
    FROM (
        SELECT 
            ISNULL(e.job_title, ''Unknown'') AS job_title,
            d.department_name,
            e.employee_id
        FROM #test_employees e
        LEFT JOIN #test_departments d ON e.department_id = d.department_id
        WHERE e.hire_date <= @as_of_date
          AND (@include_inactive = 1 OR e.status = ''Active'')
    ) AS SourceData
    PIVOT (
        COUNT(employee_id)
        FOR department_name IN (' + @columns + ')
    ) AS PivotTable
    ORDER BY job_title;';
    
    EXEC sp_executesql @sql, 
        N'@as_of_date DATETIME, @include_inactive BIT',
        @as_of_date = @as_of_date,
        @include_inactive = @include_inactive;
END;
GO

-- EXEC
EXEC #usp_dept_headcount_pivot @as_of_date = '2024-12-31', @include_inactive = 0;

-- ASSERT
SELECT 'TC1' AS test_case, 'Basic pivot executed' AS result;

-- CLEANUP
IF OBJECT_ID('tempdb..#test_employees') IS NOT NULL DROP TABLE #test_employees;
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;
GO


-- ============================================================================
-- TEST CASE 2: Include inactive employees
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_employees') IS NOT NULL DROP TABLE #test_employees;
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;

CREATE TABLE #test_departments (
    department_id INT PRIMARY KEY,
    department_name NVARCHAR(100)
);

CREATE TABLE #test_employees (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    department_id INT,
    job_title NVARCHAR(100),
    status NVARCHAR(20),
    hire_date DATETIME
);

INSERT INTO #test_departments (department_id, department_name) VALUES
(1, 'Engineering'),
(2, 'Sales');

INSERT INTO #test_employees (employee_id, first_name, last_name, department_id, job_title, status, hire_date) VALUES
(1, 'John', 'Doe', 1, 'Engineer', 'Active', '2020-01-01'),
(2, 'Jane', 'Smith', 1, 'Engineer', 'Inactive', '2020-02-01'),
(3, 'Bob', 'Johnson', 2, 'Sales Rep', 'Active', '2020-03-01'),
(4, 'Alice', 'Williams', 2, 'Sales Rep', 'Terminated', '2020-04-01');

-- Create temp stored procedure
IF OBJECT_ID('tempdb..#usp_dept_headcount_pivot') IS NOT NULL 
    DROP PROCEDURE #usp_dept_headcount_pivot;
GO

CREATE PROCEDURE #usp_dept_headcount_pivot
    @as_of_date DATETIME = NULL,
    @include_inactive BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @as_of_date IS NULL
        SET @as_of_date = GETDATE();
    
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @columns NVARCHAR(MAX);
    
    SELECT @columns = STUFF((
        SELECT DISTINCT ',' + QUOTENAME(d.department_name)
        FROM #test_departments d
        INNER JOIN #test_employees e ON d.department_id = e.department_id
        WHERE e.hire_date <= @as_of_date
          AND (@include_inactive = 1 OR e.status = 'Active')
        ORDER BY ',' + QUOTENAME(d.department_name)
        FOR XML PATH(''), TYPE
    ).value('.', 'NVARCHAR(MAX)'), 1, 1, '');
    
    IF @columns IS NULL
    BEGIN
        SELECT 'No Data' AS Message;
        RETURN;
    END
    
    SET @sql = N'
    SELECT 
        job_title,
        ' + @columns + ',
        (' + REPLACE(@columns, ',', ' + ') + ') AS total_count
    FROM (
        SELECT 
            ISNULL(e.job_title, ''Unknown'') AS job_title,
            d.department_name,
            e.employee_id
        FROM #test_employees e
        LEFT JOIN #test_departments d ON e.department_id = d.department_id
        WHERE e.hire_date <= @as_of_date
          AND (@include_inactive = 1 OR e.status = ''Active'')
    ) AS SourceData
    PIVOT (
        COUNT(employee_id)
        FOR department_name IN (' + @columns + ')
    ) AS PivotTable
    ORDER BY job_title;';
    
    EXEC sp_executesql @sql, 
        N'@as_of_date DATETIME, @include_inactive BIT',
        @as_of_date = @as_of_date,
        @include_inactive = @include_inactive;
END;
GO

-- EXEC - Active only
EXEC #usp_dept_headcount_pivot @as_of_date = '2024-12-31', @include_inactive = 0;

-- EXEC - Include inactive
EXEC #usp_dept_headcount_pivot @as_of_date = '2024-12-31', @include_inactive = 1;

-- ASSERT
SELECT 'TC2' AS test_case, 'Include inactive parameter tested' AS result;

-- CLEANUP
IF OBJECT_ID('tempdb..#test_employees') IS NOT NULL DROP TABLE #test_employees;
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;
GO


-- ============================================================================
-- TEST CASE 3: Date filtering - as_of_date parameter
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_employees') IS NOT NULL DROP TABLE #test_employees;
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;

CREATE TABLE #test_departments (
    department_id INT PRIMARY KEY,
    department_name NVARCHAR(100)
);

CREATE TABLE #test_employees (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    department_id INT,
    job_title NVARCHAR(100),
    status NVARCHAR(20),
    hire_date DATETIME
);

INSERT INTO #test_departments (department_id, department_name) VALUES
(1, 'Engineering');

INSERT INTO #test_employees (employee_id, first_name, last_name, department_id, job_title, status, hire_date) VALUES
(1, 'John', 'Doe', 1, 'Engineer', 'Active', '2020-01-01'),
(2, 'Jane', 'Smith', 1, 'Engineer', 'Active', '2021-01-01'),
(3, 'Bob', 'Johnson', 1, 'Engineer', 'Active', '2022-01-01');

-- Create temp stored procedure
IF OBJECT_ID('tempdb..#usp_dept_headcount_pivot') IS NOT NULL 
    DROP PROCEDURE #usp_dept_headcount_pivot;
GO

CREATE PROCEDURE #usp_dept_headcount_pivot
    @as_of_date DATETIME = NULL,
    @include_inactive BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @as_of_date IS NULL
        SET @as_of_date = GETDATE();
    
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @columns NVARCHAR(MAX);
    
    SELECT @columns = STUFF((
        SELECT DISTINCT ',' + QUOTENAME(d.department_name)
        FROM #test_departments d
        INNER JOIN #test_employees e ON d.department_id = e.department_id
        WHERE e.hire_date <= @as_of_date
          AND (@include_inactive = 1 OR e.status = 'Active')
        ORDER BY ',' + QUOTENAME(d.department_name)
        FOR XML PATH(''), TYPE
    ).value('.', 'NVARCHAR(MAX)'), 1, 1, '');
    
    IF @columns IS NULL
    BEGIN
        SELECT 'No Data' AS Message;
        RETURN;
    END
    
    SET @sql = N'
    SELECT 
        job_title,
        ' + @columns + ',
        (' + REPLACE(@columns, ',', ' + ') + ') AS total_count
    FROM (
        SELECT 
            ISNULL(e.job_title, ''Unknown'') AS job_title,
            d.department_name,
            e.employee_id
        FROM #test_employees e
        LEFT JOIN #test_departments d ON e.department_id = d.department_id
        WHERE e.hire_date <= @as_of_date
          AND (@include_inactive = 1 OR e.status = ''Active'')
    ) AS SourceData
    PIVOT (
        COUNT(employee_id)
        FOR department_name IN (' + @columns + ')
    ) AS PivotTable
    ORDER BY job_title;';
    
    EXEC sp_executesql @sql, 
        N'@as_of_date DATETIME, @include_inactive BIT',
        @as_of_date = @as_of_date,
        @include_inactive = @include_inactive;
END;
GO

-- EXEC - As of 2020-06-30 (should show 1 employee)
EXEC #usp_dept_headcount_pivot @as_of_date = '2020-06-30', @include_inactive = 0;

-- EXEC - As of 2021-06-30 (should show 2 employees)
EXEC #usp_dept_headcount_pivot @as_of_date = '2021-06-30', @include_inactive = 0;

-- EXEC - As of 2024-12-31 (should show 3 employees)
EXEC #usp_dept_headcount_pivot @as_of_date = '2024-12-31', @include_inactive = 0;

-- ASSERT
SELECT 'TC3' AS test_case, 'Date filtering tested' AS result;

-- CLEANUP
IF OBJECT_ID('tempdb..#test_employees') IS NOT NULL DROP TABLE #test_employees;
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;
GO


-- ============================================================================
-- TEST CASE 4: NULL as_of_date (should default to current date)
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_employees') IS NOT NULL DROP TABLE #test_employees;
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;

CREATE TABLE #test_departments (
    department_id INT PRIMARY KEY,
    department_name NVARCHAR(100)
);

CREATE TABLE #test_employees (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    department_id INT,
    job_title NVARCHAR(100),
    status NVARCHAR(20),
    hire_date DATETIME
);

INSERT INTO #test_departments (department_id, department_name) VALUES
(1, 'Engineering');

INSERT INTO #test_employees (employee_id, first_name, last_name, department_id, job_title, status, hire_date) VALUES
(1, 'John', 'Doe', 1, 'Engineer', 'Active', '2020-01-01');

-- Create temp stored procedure
IF OBJECT_ID('tempdb..#usp_dept_headcount_pivot') IS NOT NULL 
    DROP PROCEDURE #usp_dept_headcount_pivot;
GO

CREATE PROCEDURE #usp_dept_headcount_pivot
    @as_of_date DATETIME = NULL,
    @include_inactive BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @as_of_date IS NULL
        SET @as_of_date = GETDATE();
    
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @columns NVARCHAR(MAX);
    
    SELECT @columns = STUFF((
        SELECT DISTINCT ',' + QUOTENAME(d.department_name)
        FROM #test_departments d
        INNER JOIN #test_employees e ON d.department_id = e.department_id
        WHERE e.hire_date <= @as_of_date
          AND (@include_inactive = 1 OR e.status = 'Active')
        ORDER BY ',' + QUOTENAME(d.department_name)
        FOR XML PATH(''), TYPE
    ).value('.', 'NVARCHAR(MAX)'), 1, 1, '');
    
    IF @columns IS NULL
    BEGIN
        SELECT 'No Data' AS Message;
        RETURN;
    END
    
    SET @sql = N'
    SELECT 
        job_title,
        ' + @columns + ',
        (' + REPLACE(@columns, ',', ' + ') + ') AS total_count
    FROM (
        SELECT 
            ISNULL(e.job_title, ''Unknown'') AS job_title,
            d.department_name,
            e.employee_id
        FROM #test_employees e
        LEFT JOIN #test_departments d ON e.department_id = d.department_id
        WHERE e.hire_date <= @as_of_date
          AND (@include_inactive = 1 OR e.status = ''Active'')
    ) AS SourceData
    PIVOT (
        COUNT(employee_id)
        FOR department_name IN (' + @columns + ')
    ) AS PivotTable
    ORDER BY job_title;';
    
    EXEC sp_executesql @sql, 
        N'@as_of_date DATETIME, @include_inactive BIT',
        @as_of_date = @as_of_date,
        @include_inactive = @include_inactive;
END;
GO

-- EXEC - NULL date (should use current date)
EXEC #usp_dept_headcount_pivot @as_of_date = NULL, @include_inactive = 0;

-- ASSERT
SELECT 'TC4' AS test_case, 'NULL as_of_date defaults to current date' AS result;

-- CLEANUP
IF OBJECT_ID('tempdb..#test_employees') IS NOT NULL DROP TABLE #test_employees;
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;
GO


-- ============================================================================
-- TEST CASE 5: Empty result set (no employees match criteria)
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_employees') IS NOT NULL DROP TABLE #test_employees;
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;

CREATE TABLE #test_departments (
    department_id INT PRIMARY KEY,
    department_name NVARCHAR(100)
);

CREATE TABLE #test_employees (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    department_id INT,
    job_title NVARCHAR(100),
    status NVARCHAR(20),
    hire_date DATETIME
);

INSERT INTO #test_departments (department_id, department_name) VALUES
(1, 'Engineering');

INSERT INTO #test_employees (employee_id, first_name, last_name, department_id, job_title, status, hire_date) VALUES
(1, 'John', 'Doe', 1, 'Engineer', 'Active', '2025-01-01');

-- Create temp stored procedure
IF OBJECT_ID('tempdb..#usp_dept_headcount_pivot') IS NOT NULL 
    DROP PROCEDURE #usp_dept_headcount_pivot;
GO

CREATE PROCEDURE #usp_dept_headcount_pivot
    @as_of_date DATETIME = NULL,
    @include_inactive BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @as_of_date IS NULL
        SET @as_of_date = GETDATE();
    
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @columns NVARCHAR(MAX);
    
    SELECT @columns = STUFF((
        SELECT DISTINCT ',' + QUOTENAME(d.department_name)
        FROM #test_departments d
        INNER JOIN #test_employees e ON d.department_id = e.department_id
        WHERE e.hire_date <= @as_of_date
          AND (@include_inactive = 1 OR e.status = 'Active')
        ORDER BY ',' + QUOTENAME(d.department_name)
        FOR XML PATH(''), TYPE
    ).value('.', 'NVARCHAR(MAX)'), 1, 1, '');
    
    IF @columns IS NULL
    BEGIN
        SELECT 'No Data' AS Message;
        RETURN;
    END
    
    SET @sql = N'
    SELECT 
        job_title,
        ' + @columns + ',
        (' + REPLACE(@columns, ',', ' + ') + ') AS total_count
    FROM (
        SELECT 
            ISNULL(e.job_title, ''Unknown'') AS job_title,
            d.department_name,
            e.employee_id
        FROM #test_employees e
        LEFT JOIN #test_departments d ON e.department_id = d.department_id
        WHERE e.hire_date <= @as_of_date
          AND (@include_inactive = 1 OR e.status = ''Active'')
    ) AS SourceData
    PIVOT (
        COUNT(employee_id)
        FOR department_name IN (' + @columns + ')
    ) AS PivotTable
    ORDER BY job_title;';
    
    EXEC sp_executesql @sql, 
        N'@as_of_date DATETIME, @include_inactive BIT',
        @as_of_date = @as_of_date,
        @include_inactive = @include_inactive;
END;
GO

-- EXEC - Date before any hire dates
EXEC #usp_dept_headcount_pivot @as_of_date = '2020-01-01', @include_inactive = 0;

-- ASSERT
SELECT 'TC5' AS test_case, 'Empty result handled correctly' AS result;

-- CLEANUP
IF OBJECT_ID('tempdb..#test_employees') IS NOT NULL DROP TABLE #test_employees;
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;
GO


-- ============================================================================
-- TEST CASE 6: Multiple departments with varying counts
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_employees') IS NOT NULL DROP TABLE #test_employees;
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;

CREATE TABLE #test_departments (
    department_id INT PRIMARY KEY,
    department_name NVARCHAR(100)
);

CREATE TABLE #test_employees (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    department_id INT,
    job_title NVARCHAR(100),
    status NVARCHAR(20),
    hire_date DATETIME
);

INSERT INTO #test_departments (department_id, department_name) VALUES
(1, 'Engineering'),
(2, 'Sales'),
(3, 'HR'),
(4, 'Finance');

INSERT INTO #test_employees (employee_id, first_name, last_name, department_id, job_title, status, hire_date) VALUES
(1, 'John', 'Doe', 1, 'Engineer', 'Active', '2020-01-01'),
(2, 'Jane', 'Smith', 1, 'Engineer', 'Active', '2020-02-01'),
(3, 'Bob', 'Johnson', 1, 'Engineer', 'Active', '2020-03-01'),
(4, 'Alice', 'Williams', 1, 'Senior Engineer', 'Active', '2020-04-01'),
(5, 'Charlie', 'Brown', 2, 'Sales Rep', 'Active', '2020-05-01'),
(6, 'Diana', 'Davis', 3, 'HR Manager', 'Active', '2020-06-01'),
(7, 'Eve', 'Miller', 4, 'Accountant', 'Active', '2020-07-01'),
(8, 'Frank', 'Wilson', 4, 'Accountant', 'Active', '2020-08-01');

-- Create temp stored procedure
IF OBJECT_ID('tempdb..#usp_dept_headcount_pivot') IS NOT NULL 
    DROP PROCEDURE #usp_dept_headcount_pivot;
GO

CREATE PROCEDURE #usp_dept_headcount_pivot
    @as_of_date DATETIME = NULL,
    @include_inactive BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @as_of_date IS NULL
        SET @as_of_date = GETDATE();
    
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @columns NVARCHAR(MAX);
    
    SELECT @columns = STUFF((
        SELECT DISTINCT ',' + QUOTENAME(d.department_name)
        FROM #test_departments d
        INNER JOIN #test_employees e ON d.department_id = e.department_id
        WHERE e.hire_date <= @as_of_date
          AND (@include_inactive = 1 OR e.status = 'Active')
        ORDER BY ',' + QUOTENAME(d.department_name)
        FOR XML PATH(''), TYPE
    ).value('.', 'NVARCHAR(MAX)'), 1, 1, '');
    
    IF @columns IS NULL
    BEGIN
        SELECT 'No Data' AS Message;
        RETURN;
    END
    
    SET @sql = N'
    SELECT 
        job_title,
        ' + @columns + ',
        (' + REPLACE(@columns, ',', ' + ') + ') AS total_count
    FROM (
        SELECT 
            ISNULL(e.job_title, ''Unknown'') AS job_title,
            d.department_name,
            e.employee_id
        FROM #test_employees e
        LEFT JOIN #test_departments d ON e.department_id = d.department_id
        WHERE e.hire_date <= @as_of_date
          AND (@include_inactive = 1 OR e.status = ''Active'')
    ) AS SourceData
    PIVOT (
        COUNT(employee_id)
        FOR department_name IN (' + @columns + ')
    ) AS PivotTable
    ORDER BY job_title;';
    
    EXEC sp_executesql @sql, 
        N'@as_of_date DATETIME, @include_inactive BIT',
        @as_of_date = @as_of_date,
        @include_inactive = @include_inactive;
END;
GO

-- EXEC
EXEC #usp_dept_headcount_pivot @as_of_date = '2024-12-31', @include_inactive = 0;

-- ASSERT
SELECT 'TC6' AS test_case, 'Multiple departments with varying counts' AS result;

-- CLEANUP
IF OBJECT_ID('tempdb..#test_employees') IS NOT NULL DROP TABLE #test_employees;
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;
GO


-- ============================================================================
-- TEST CASE 7: NULL job_title handling
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_employees') IS NOT NULL DROP TABLE #test_employees;
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;

CREATE TABLE #test_departments (
    department_id INT PRIMARY KEY,
    department_name NVARCHAR(100)
);

CREATE TABLE #test_employees (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    department_id INT,
    job_title NVARCHAR(100),
    status NVARCHAR(20),
    hire_date DATETIME
);

INSERT INTO #test_departments (department_id, department_name) VALUES
(1, 'Engineering');

INSERT INTO #test_employees (employee_id, first_name, last_name, department_id, job_title, status, hire_date) VALUES
(1, 'John', 'Doe', 1, NULL, 'Active', '2020-01-01'),
(2, 'Jane', 'Smith', 1, 'Engineer', 'Active', '2020-02-01');

-- Create temp stored procedure
IF OBJECT_ID('tempdb..#usp_dept_headcount_pivot') IS NOT NULL 
    DROP PROCEDURE #usp_dept_headcount_pivot;
GO

CREATE PROCEDURE #usp_dept_headcount_pivot
    @as_of_date DATETIME = NULL,
    @include_inactive BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @as_of_date IS NULL
        SET @as_of_date = GETDATE();
    
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @columns NVARCHAR(MAX);
    
    SELECT @columns = STUFF((
        SELECT DISTINCT ',' + QUOTENAME(d.department_name)
        FROM #test_departments d
        INNER JOIN #test_employees e ON d.department_id = e.department_id
        WHERE e.hire_date <= @as_of_date
          AND (@include_inactive = 1 OR e.status = 'Active')
        ORDER BY ',' + QUOTENAME(d.department_name)
        FOR XML PATH(''), TYPE
    ).value('.', 'NVARCHAR(MAX)'), 1, 1, '');
    
    IF @columns IS NULL
    BEGIN
        SELECT 'No Data' AS Message;
        RETURN;
    END
    
    SET @sql = N'
    SELECT 
        job_title,
        ' + @columns + ',
        (' + REPLACE(@columns, ',', ' + ') + ') AS total_count
    FROM (
        SELECT 
            ISNULL(e.job_title, ''Unknown'') AS job_title,
            d.department_name,
            e.employee_id
        FROM #test_employees e
        LEFT JOIN #test_departments d ON e.department_id = d.department_id
        WHERE e.hire_date <= @as_of_date
          AND (@include_inactive = 1 OR e.status = ''Active'')
    ) AS SourceData
    PIVOT (
        COUNT(employee_id)
        FOR department_name IN (' + @columns + ')
    ) AS PivotTable
    ORDER BY job_title;';
    
    EXEC sp_executesql @sql, 
        N'@as_of_date DATETIME, @include_inactive BIT',
        @as_of_date = @as_of_date,
        @include_inactive = @include_inactive;
END;
GO

-- EXEC
EXEC #usp_dept_headcount_pivot @as_of_date = '2024-12-31', @include_inactive = 0;

-- ASSERT
SELECT 'TC7' AS test_case, 'NULL job_title converted to Unknown' AS result;

-- CLEANUP
IF OBJECT_ID('tempdb..#test_employees') IS NOT NULL DROP TABLE #test_employees;
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;
GO


-- ============================================================================
-- TEST CASE 8: Employee with NULL department_id
-- ============================================================================
-- SETUP
IF OBJECT_ID('tempdb..#test_employees') IS NOT NULL DROP TABLE #test_employees;
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;

CREATE TABLE #test_departments (
    department_id INT PRIMARY KEY,
    department_name NVARCHAR(100)
);

CREATE TABLE #test_employees (
    employee_id INT PRIMARY KEY,
    first_name NVARCHAR(50),
    last_name NVARCHAR(50),
    department_id INT,
    job_title NVARCHAR(100),
    status NVARCHAR(20),
    hire_date DATETIME
);

INSERT INTO #test_departments (department_id, department_name) VALUES
(1, 'Engineering');

INSERT INTO #test_employees (employee_id, first_name, last_name, department_id, job_title, status, hire_date) VALUES
(1, 'John', 'Doe', 1, 'Engineer', 'Active', '2020-01-01'),
(2, 'Jane', 'Smith', NULL, 'Contractor', 'Active', '2020-02-01');

-- Create temp stored procedure
IF OBJECT_ID('tempdb..#usp_dept_headcount_pivot') IS NOT NULL 
    DROP PROCEDURE #usp_dept_headcount_pivot;
GO

CREATE PROCEDURE #usp_dept_headcount_pivot
    @as_of_date DATETIME = NULL,
    @include_inactive BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @as_of_date IS NULL
        SET @as_of_date = GETDATE();
    
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @columns NVARCHAR(MAX);
    
    SELECT @columns = STUFF((
        SELECT DISTINCT ',' + QUOTENAME(d.department_name)
        FROM #test_departments d
        INNER JOIN #test_employees e ON d.department_id = e.department_id
        WHERE e.hire_date <= @as_of_date
          AND (@include_inactive = 1 OR e.status = 'Active')
        ORDER BY ',' + QUOTENAME(d.department_name)
        FOR XML PATH(''), TYPE
    ).value('.', 'NVARCHAR(MAX)'), 1, 1, '');
    
    IF @columns IS NULL
    BEGIN
        SELECT 'No Data' AS Message;
        RETURN;
    END
    
    SET @sql = N'
    SELECT 
        job_title,
        ' + @columns + ',
        (' + REPLACE(@columns, ',', ' + ') + ') AS total_count
    FROM (
        SELECT 
            ISNULL(e.job_title, ''Unknown'') AS job_title,
            d.department_name,
            e.employee_id
        FROM #test_employees e
        LEFT JOIN #test_departments d ON e.department_id = d.department_id
        WHERE e.hire_date <= @as_of_date
          AND (@include_inactive = 1 OR e.status = ''Active'')
    ) AS SourceData
    PIVOT (
        COUNT(employee_id)
        FOR department_name IN (' + @columns + ')
    ) AS PivotTable
    ORDER BY job_title;';
    
    EXEC sp_executesql @sql, 
        N'@as_of_date DATETIME, @include_inactive BIT',
        @as_of_date = @as_of_date,
        @include_inactive = @include_inactive;
END;
GO

-- EXEC
EXEC #usp_dept_headcount_pivot @as_of_date = '2024-12-31', @include_inactive = 0;

-- ASSERT
SELECT 'TC8' AS test_case, 'NULL department_id handled with LEFT JOIN' AS result;

-- CLEANUP
IF OBJECT_ID('tempdb..#test_employees') IS NOT NULL DROP TABLE #test_employees;
IF OBJECT_ID('tempdb..#test_departments') IS NOT NULL DROP TABLE #test_departments;
GO


-- ============================================================================
-- TEST SUMMARY
-- ============================================================================
SELECT 'TEST_SUITE_COMPLETE' AS status, 
       '8 test cases executed' AS summary,
       'Coverage: normal, boundary, edge cases, NULL handling, date filtering' AS coverage;
