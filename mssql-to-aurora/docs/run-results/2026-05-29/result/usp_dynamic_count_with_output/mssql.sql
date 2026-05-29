-- ============================================================================
-- Source: SQL Server
-- Object: dbo.usp_dynamic_count_with_output
-- Type: STORED PROCEDURE
-- ============================================================================
-- NOTE: This is an ASSUMED definition based on the procedure name pattern.
--       Actual definition should be retrieved from Source RDS once connectivity is restored.
-- ============================================================================

CREATE PROCEDURE dbo.usp_dynamic_count_with_output
    @table_name NVARCHAR(128),
    @where_clause NVARCHAR(MAX) = NULL,
    @record_count INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @params NVARCHAR(MAX);
    DECLARE @error_message NVARCHAR(4000);
    DECLARE @quoted_table_name NVARCHAR(258);
    
    -- Initialize output parameter
    SET @record_count = 0;
    
    BEGIN TRY
        -- Validate input: table_name cannot be NULL or empty
        IF @table_name IS NULL OR LTRIM(RTRIM(@table_name)) = ''
        BEGIN
            RAISERROR('Table name cannot be NULL or empty.', 16, 1);
            RETURN;
        END
        
        -- Remove leading/trailing whitespace
        SET @table_name = LTRIM(RTRIM(@table_name));
        
        -- Check if table exists in dbo schema
        IF NOT EXISTS (
            SELECT 1 
            FROM sys.objects 
            WHERE object_id = OBJECT_ID('dbo.' + @table_name) 
            AND type IN ('U', 'V')  -- User table or view
        )
        BEGIN
            SET @error_message = 'Table or view [dbo].[' + @table_name + '] does not exist.';
            RAISERROR(@error_message, 16, 1);
            RETURN;
        END
        
        -- Use QUOTENAME to prevent SQL injection
        SET @quoted_table_name = QUOTENAME('dbo') + '.' + QUOTENAME(@table_name);
        
        -- Build dynamic SQL
        SET @sql = N'SELECT @count_out = COUNT(*) FROM ' + @quoted_table_name;
        
        -- Add WHERE clause if provided
        IF @where_clause IS NOT NULL AND LTRIM(RTRIM(@where_clause)) <> ''
        BEGIN
            SET @sql = @sql + N' WHERE ' + @where_clause;
        END
        
        -- Define parameter for sp_executesql
        SET @params = N'@count_out INT OUTPUT';
        
        -- Execute dynamic SQL
        EXEC sp_executesql 
            @sql, 
            @params, 
            @count_out = @record_count OUTPUT;
        
        -- Return success indicator
        SELECT 
            @table_name AS table_name,
            @record_count AS record_count,
            CASE 
                WHEN @where_clause IS NULL THEN 'No filter'
                ELSE @where_clause 
            END AS where_clause,
            'SUCCESS' AS status;
            
    END TRY
    BEGIN CATCH
        -- Capture error information
        SET @error_message = ERROR_MESSAGE();
        
        -- Set output to -1 to indicate error
        SET @record_count = -1;
        
        -- Return error information
        SELECT 
            @table_name AS table_name,
            @record_count AS record_count,
            @where_clause AS where_clause,
            'ERROR' AS status,
            @error_message AS error_message;
        
        -- Re-raise error for caller
        RAISERROR(@error_message, 16, 1);
        RETURN;
    END CATCH
    
END;
GO
