-- ============================================================================
-- Source: SQL Server
-- Object: dbo.usp_upsert_department
-- Type: STORED PROCEDURE
-- ============================================================================
-- NOTE: This is an ASSUMED definition based on common UPSERT patterns.
--       Actual definition should be retrieved from Source RDS once connectivity is restored.
-- ============================================================================

CREATE PROCEDURE dbo.usp_upsert_department
    @department_id INT = NULL,
    @department_name NVARCHAR(100),
    @location NVARCHAR(100) = NULL,
    @manager_id INT = NULL,
    @result_id INT OUTPUT,
    @operation NVARCHAR(10) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @error_message NVARCHAR(4000);
    DECLARE @error_severity INT;
    DECLARE @error_state INT;
    DECLARE @existing_id INT;
    
    -- Initialize output parameters
    SET @result_id = NULL;
    SET @operation = NULL;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Validate required parameters
        IF @department_name IS NULL OR LTRIM(RTRIM(@department_name)) = ''
        BEGIN
            RAISERROR('Department name is required and cannot be empty.', 16, 1);
            RETURN;
        END
        
        -- Trim department name
        SET @department_name = LTRIM(RTRIM(@department_name));
        
        -- Validate manager_id if provided
        IF @manager_id IS NOT NULL
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.employees WHERE employee_id = @manager_id)
            BEGIN
                RAISERROR('Invalid manager_id. Employee does not exist.', 16, 1);
                RETURN;
            END
        END
        
        -- Check if department_id is provided and exists
        IF @department_id IS NOT NULL
        BEGIN
            SELECT @existing_id = department_id 
            FROM dbo.departments 
            WHERE department_id = @department_id;
        END
        
        -- UPSERT logic
        IF @existing_id IS NOT NULL
        BEGIN
            -- UPDATE existing department
            UPDATE dbo.departments
            SET 
                department_name = @department_name,
                location = @location,
                manager_id = @manager_id,
                modified_date = GETDATE()
            WHERE department_id = @department_id;
            
            SET @result_id = @department_id;
            SET @operation = 'UPDATE';
        END
        ELSE
        BEGIN
            -- Check for duplicate department name
            IF EXISTS (SELECT 1 FROM dbo.departments WHERE department_name = @department_name)
            BEGIN
                RAISERROR('Department name already exists.', 16, 1);
                RETURN;
            END
            
            -- INSERT new department
            INSERT INTO dbo.departments (
                department_name,
                location,
                manager_id,
                created_date,
                modified_date
            )
            VALUES (
                @department_name,
                @location,
                @manager_id,
                GETDATE(),
                GETDATE()
            );
            
            SET @result_id = SCOPE_IDENTITY();
            SET @operation = 'INSERT';
        END
        
        COMMIT TRANSACTION;
        
        -- Return result set
        SELECT 
            @result_id AS department_id,
            @operation AS operation,
            @department_name AS department_name,
            @location AS location,
            @manager_id AS manager_id,
            GETDATE() AS processed_date;
        
    END TRY
    BEGIN CATCH
        -- Rollback transaction on error
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        -- Capture error information
        SELECT 
            @error_message = ERROR_MESSAGE(),
            @error_severity = ERROR_SEVERITY(),
            @error_state = ERROR_STATE();
        
        -- Re-raise the error
        RAISERROR(@error_message, @error_severity, @error_state);
        
        RETURN;
    END CATCH
    
END;
GO
