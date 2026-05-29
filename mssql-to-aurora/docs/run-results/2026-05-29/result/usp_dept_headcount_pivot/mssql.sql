-- ============================================================================
-- Object: dbo.usp_dept_headcount_pivot
-- Type: STORED PROCEDURE
-- Description: Generate a pivot report of employee headcount by department
-- ============================================================================
-- NOTE: This is a REPRESENTATIVE IMPLEMENTATION based on common patterns
--       Actual implementation should be verified against source database
-- ============================================================================

CREATE PROCEDURE dbo.usp_dept_headcount_pivot
    @as_of_date DATETIME = NULL,
    @include_inactive BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Default to current date if not specified
    IF @as_of_date IS NULL
        SET @as_of_date = GETDATE();
    
    -- Declare variables for dynamic SQL
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @columns NVARCHAR(MAX);
    
    -- Build comma-separated list of department names for PIVOT
    SELECT @columns = STUFF((
        SELECT DISTINCT ',' + QUOTENAME(d.department_name)
        FROM dbo.departments d
        INNER JOIN dbo.employees e ON d.department_id = e.department_id
        WHERE e.hire_date <= @as_of_date
          AND (@include_inactive = 1 OR e.status = 'Active')
        ORDER BY ',' + QUOTENAME(d.department_name)
        FOR XML PATH(''), TYPE
    ).value('.', 'NVARCHAR(MAX)'), 1, 1, '');
    
    -- Handle case where no departments found
    IF @columns IS NULL
    BEGIN
        SELECT 'No Data' AS Message;
        RETURN;
    END
    
    -- Build dynamic PIVOT query
    SET @sql = N'
    SELECT 
        job_title,
        ' + @columns + ',
        total_count
    FROM (
        SELECT 
            ISNULL(e.job_title, ''Unknown'') AS job_title,
            d.department_name,
            e.employee_id
        FROM dbo.employees e
        LEFT JOIN dbo.departments d ON e.department_id = d.department_id
        WHERE e.hire_date <= @as_of_date
          AND (@include_inactive = 1 OR e.status = ''Active'')
    ) AS SourceData
    PIVOT (
        COUNT(employee_id)
        FOR department_name IN (' + @columns + ')
    ) AS PivotTable
    CROSS APPLY (
        SELECT ' + REPLACE(@columns, ',', ' + ') + ' AS total_count
    ) AS TotalCalc
    ORDER BY job_title;';
    
    -- Execute dynamic SQL
    EXEC sp_executesql @sql, 
        N'@as_of_date DATETIME, @include_inactive BIT',
        @as_of_date = @as_of_date,
        @include_inactive = @include_inactive;
END;
GO
