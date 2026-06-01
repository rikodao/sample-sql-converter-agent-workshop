-- ============================================================================
-- Source: SQL Server
-- Object: dbo.usp_search_employees_paged
-- Type: STORED PROCEDURE
-- ============================================================================
-- NOTE: This is an ASSUMED definition based on common paged search patterns.
--       Actual definition should be retrieved from Source RDS once connectivity is restored.
-- ============================================================================

CREATE PROCEDURE dbo.usp_search_employees_paged
    @search_term NVARCHAR(100) = NULL,
    @department_id INT = NULL,
    @is_active BIT = NULL,
    @page_number INT = 1,
    @page_size INT = 10,
    @sort_column NVARCHAR(50) = 'employee_id',
    @sort_direction NVARCHAR(4) = 'ASC',
    @total_count INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @error_message NVARCHAR(4000);
    DECLARE @error_severity INT;
    DECLARE @error_state INT;
    DECLARE @offset INT;
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @params NVARCHAR(MAX);
    DECLARE @where_clause NVARCHAR(MAX);
    DECLARE @order_clause NVARCHAR(200);
    
    -- Initialize output parameter
    SET @total_count = 0;
    
    BEGIN TRY
        -- Validate pagination parameters
        IF @page_number < 1
        BEGIN
            RAISERROR('Page number must be greater than or equal to 1', 16, 1);
            RETURN;
        END
        
        IF @page_size < 1 OR @page_size > 1000
        BEGIN
            RAISERROR('Page size must be between 1 and 1000', 16, 1);
            RETURN;
        END
        
        -- Validate sort direction
        IF UPPER(@sort_direction) NOT IN ('ASC', 'DESC')
        BEGIN
            RAISERROR('Sort direction must be ASC or DESC', 16, 1);
            RETURN;
        END
        
        -- Validate sort column (whitelist approach to prevent SQL injection)
        IF @sort_column NOT IN (
            'employee_id', 'first_name', 'last_name', 'email', 
            'department_id', 'hire_date', 'salary', 'job_title'
        )
        BEGIN
            RAISERROR('Invalid sort column specified', 16, 1);
            RETURN;
        END
        
        -- Calculate offset
        SET @offset = (@page_number - 1) * @page_size;
        
        -- Build WHERE clause dynamically
        SET @where_clause = N'WHERE 1=1';
        
        IF @search_term IS NOT NULL AND LTRIM(RTRIM(@search_term)) <> ''
        BEGIN
            SET @where_clause = @where_clause + N'
                AND (
                    e.first_name LIKE ''%'' + @search_term_param + ''%''
                    OR e.last_name LIKE ''%'' + @search_term_param + ''%''
                    OR e.email LIKE ''%'' + @search_term_param + ''%''
                    OR e.job_title LIKE ''%'' + @search_term_param + ''%''
                )';
        END
        
        IF @department_id IS NOT NULL
        BEGIN
            SET @where_clause = @where_clause + N'
                AND e.department_id = @department_id_param';
        END
        
        IF @is_active IS NOT NULL
        BEGIN
            SET @where_clause = @where_clause + N'
                AND ISNULL(e.is_active, 1) = @is_active_param';
        END
        
        -- Build ORDER BY clause
        SET @order_clause = N'ORDER BY ' + QUOTENAME(@sort_column) + N' ' + @sort_direction;
        
        -- Get total count first
        SET @sql = N'
            SELECT @total_out = COUNT(*)
            FROM dbo.employees e
            ' + @where_clause;
        
        SET @params = N'
            @search_term_param NVARCHAR(100),
            @department_id_param INT,
            @is_active_param BIT,
            @total_out INT OUTPUT';
        
        EXEC sp_executesql 
            @sql,
            @params,
            @search_term_param = @search_term,
            @department_id_param = @department_id,
            @is_active_param = @is_active,
            @total_out = @total_count OUTPUT;
        
        -- Get paged results
        SET @sql = N'
            SELECT 
                e.employee_id,
                e.first_name,
                e.last_name,
                e.email,
                e.department_id,
                d.department_name,
                e.hire_date,
                e.salary,
                e.job_title,
                e.is_active,
                @page_num AS page_number,
                @page_sz AS page_size,
                @total_cnt AS total_count,
                CEILING(CAST(@total_cnt AS FLOAT) / @page_sz) AS total_pages
            FROM dbo.employees e
            LEFT JOIN dbo.departments d ON e.department_id = d.department_id
            ' + @where_clause + N'
            ' + @order_clause + N'
            OFFSET @offset_param ROWS
            FETCH NEXT @page_sz ROWS ONLY';
        
        SET @params = N'
            @search_term_param NVARCHAR(100),
            @department_id_param INT,
            @is_active_param BIT,
            @offset_param INT,
            @page_num INT,
            @page_sz INT,
            @total_cnt INT';
        
        EXEC sp_executesql 
            @sql,
            @params,
            @search_term_param = @search_term,
            @department_id_param = @department_id,
            @is_active_param = @is_active,
            @offset_param = @offset,
            @page_num = @page_number,
            @page_sz = @page_size,
            @total_cnt = @total_count;
        
    END TRY
    BEGIN CATCH
        -- Capture error information
        SELECT 
            @error_message = ERROR_MESSAGE(),
            @error_severity = ERROR_SEVERITY(),
            @error_state = ERROR_STATE();
        
        -- Set output to -1 to indicate error
        SET @total_count = -1;
        
        -- Re-raise the error
        RAISERROR(@error_message, @error_severity, @error_state);
        
        RETURN;
    END CATCH
    
END;
GO
