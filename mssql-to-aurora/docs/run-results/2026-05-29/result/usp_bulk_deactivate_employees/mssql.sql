-- ============================================================================
-- Source: SQL Server
-- Object: dbo.usp_bulk_deactivate_employees
-- Type: STORED PROCEDURE
-- ============================================================================
-- NOTE: This is an ASSUMED definition based on common bulk deactivation patterns.
--       Actual definition should be retrieved from Source RDS once connectivity is restored.
-- ============================================================================

CREATE PROCEDURE dbo.usp_bulk_deactivate_employees
    @employee_ids NVARCHAR(MAX),
    @deactivation_reason NVARCHAR(500) = NULL,
    @deactivated_count INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @error_message NVARCHAR(4000);
    DECLARE @error_severity INT;
    DECLARE @error_state INT;
    
    -- Initialize output parameter
    SET @deactivated_count = 0;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Validate input parameter
        IF @employee_ids IS NULL OR LTRIM(RTRIM(@employee_ids)) = ''
        BEGIN
            RAISERROR('Parameter @employee_ids cannot be NULL or empty', 16, 1);
            RETURN;
        END
        
        -- Create temp table to hold parsed employee IDs
        CREATE TABLE #emp_ids (
            employee_id INT
        );
        
        -- Parse comma-separated employee IDs using STRING_SPLIT (SQL Server 2016+)
        -- For older versions, would need custom parsing logic
        INSERT INTO #emp_ids (employee_id)
        SELECT CAST(LTRIM(RTRIM(value)) AS INT)
        FROM STRING_SPLIT(@employee_ids, ',')
        WHERE LTRIM(RTRIM(value)) <> '';
        
        -- Validate that all employee IDs exist and are currently active
        IF EXISTS (
            SELECT 1 
            FROM #emp_ids e
            LEFT JOIN dbo.employees emp ON e.employee_id = emp.employee_id
            WHERE emp.employee_id IS NULL
        )
        BEGIN
            RAISERROR('One or more employee IDs do not exist', 16, 1);
            DROP TABLE #emp_ids;
            RETURN;
        END
        
        -- Update employees to deactivated status
        UPDATE e
        SET 
            e.is_active = 0,
            e.deactivated_date = GETDATE()
        FROM dbo.employees e
        INNER JOIN #emp_ids tmp ON e.employee_id = tmp.employee_id
        WHERE e.is_active = 1;  -- Only deactivate currently active employees
        
        -- Get count of deactivated records
        SET @deactivated_count = @@ROWCOUNT;
        
        -- Clean up temp table
        DROP TABLE #emp_ids;
        
        COMMIT TRANSACTION;
        
    END TRY
    BEGIN CATCH
        -- Rollback transaction on error
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        -- Clean up temp table if it exists
        IF OBJECT_ID('tempdb..#emp_ids') IS NOT NULL
            DROP TABLE #emp_ids;
        
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
