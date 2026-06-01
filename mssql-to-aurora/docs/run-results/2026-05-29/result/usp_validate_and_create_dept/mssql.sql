-- ============================================================================
-- Source: SQL Server
-- Object: dbo.usp_validate_and_create_dept
-- Type: STORED PROCEDURE
-- ============================================================================
-- NOTE: This is an ASSUMED definition based on naming patterns and common practices.
--       Actual definition could not be retrieved due to SQL Server connection issue.
--       Error: "You must specify a region."
--       This definition should be verified against actual Source RDS once connectivity is restored.
-- ============================================================================

CREATE PROCEDURE dbo.usp_validate_and_create_dept
    @department_name NVARCHAR(100),
    @location NVARCHAR(100) = NULL,
    @manager_id INT = NULL,
    @min_name_length INT = 3,
    @max_name_length INT = 100,
    @new_department_id INT OUTPUT,
    @validation_status NVARCHAR(50) OUTPUT,
    @error_message NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @existing_count INT;
    DECLARE @manager_exists BIT;
    DECLARE @manager_active BIT;
    DECLARE @trimmed_name NVARCHAR(100);
    DECLARE @name_length INT;
    
    -- Initialize output parameters
    SET @new_department_id = NULL;
    SET @validation_status = NULL;
    SET @error_message = NULL;
    
    BEGIN TRY
        -- ========================================
        -- VALIDATION PHASE
        -- ========================================
        
        -- Validation 1: Department name is required
        IF @department_name IS NULL
        BEGIN
            SET @validation_status = 'FAILED';
            SET @error_message = 'Department name cannot be NULL.';
            RETURN;
        END
        
        -- Trim and check for empty string
        SET @trimmed_name = LTRIM(RTRIM(@department_name));
        
        IF @trimmed_name = ''
        BEGIN
            SET @validation_status = 'FAILED';
            SET @error_message = 'Department name cannot be empty or whitespace only.';
            RETURN;
        END
        
        -- Validation 2: Check minimum length
        SET @name_length = LEN(@trimmed_name);
        
        IF @name_length < @min_name_length
        BEGIN
            SET @validation_status = 'FAILED';
            SET @error_message = 'Department name must be at least ' + CAST(@min_name_length AS NVARCHAR(10)) + ' characters long.';
            RETURN;
        END
        
        -- Validation 3: Check maximum length
        IF @name_length > @max_name_length
        BEGIN
            SET @validation_status = 'FAILED';
            SET @error_message = 'Department name must not exceed ' + CAST(@max_name_length AS NVARCHAR(10)) + ' characters.';
            RETURN;
        END
        
        -- Validation 4: Check for duplicate department name (case-insensitive)
        SELECT @existing_count = COUNT(*)
        FROM dbo.departments
        WHERE LOWER(department_name) = LOWER(@trimmed_name);
        
        IF @existing_count > 0
        BEGIN
            SET @validation_status = 'FAILED';
            SET @error_message = 'Department name already exists: ' + @trimmed_name;
            RETURN;
        END
        
        -- Validation 5: Validate manager_id if provided
        IF @manager_id IS NOT NULL
        BEGIN
            -- Check if manager exists
            SELECT @manager_exists = CASE WHEN COUNT(*) > 0 THEN 1 ELSE 0 END
            FROM dbo.employees
            WHERE employee_id = @manager_id;
            
            IF @manager_exists = 0
            BEGIN
                SET @validation_status = 'FAILED';
                SET @error_message = 'Invalid manager_id. Employee does not exist: ' + CAST(@manager_id AS NVARCHAR(10));
                RETURN;
            END
            
            -- Check if manager is active
            SELECT @manager_active = is_active
            FROM dbo.employees
            WHERE employee_id = @manager_id;
            
            IF @manager_active = 0
            BEGIN
                SET @validation_status = 'FAILED';
                SET @error_message = 'Manager must be an active employee. Employee ID: ' + CAST(@manager_id AS NVARCHAR(10));
                RETURN;
            END
        END
        
        -- Validation 6: Validate location if provided (basic check)
        IF @location IS NOT NULL
        BEGIN
            SET @location = LTRIM(RTRIM(@location));
            
            IF @location = ''
            BEGIN
                SET @location = NULL; -- Treat empty string as NULL
            END
        END
        
        -- ========================================
        -- CREATION PHASE
        -- ========================================
        
        BEGIN TRANSACTION;
        
        -- Insert new department
        INSERT INTO dbo.departments (
            department_name,
            location,
            manager_id,
            created_date,
            modified_date
        )
        VALUES (
            @trimmed_name,
            @location,
            @manager_id,
            GETDATE(),
            GETDATE()
        );
        
        -- Get the new department ID
        SET @new_department_id = SCOPE_IDENTITY();
        
        -- Set success status
        SET @validation_status = 'SUCCESS';
        SET @error_message = NULL;
        
        COMMIT TRANSACTION;
        
        -- Return result set
        SELECT 
            @new_department_id AS department_id,
            @validation_status AS validation_status,
            @trimmed_name AS department_name,
            @location AS location,
            @manager_id AS manager_id,
            GETDATE() AS created_date;
        
    END TRY
    BEGIN CATCH
        -- Rollback transaction on error
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        -- Capture error information
        SET @validation_status = 'ERROR';
        SET @error_message = ERROR_MESSAGE();
        SET @new_department_id = NULL;
        
        -- Return error information
        SELECT 
            NULL AS department_id,
            @validation_status AS validation_status,
            ERROR_NUMBER() AS error_number,
            @error_message AS error_message,
            ERROR_SEVERITY() AS error_severity,
            ERROR_STATE() AS error_state;
        
        RETURN;
    END CATCH
    
END;
GO
