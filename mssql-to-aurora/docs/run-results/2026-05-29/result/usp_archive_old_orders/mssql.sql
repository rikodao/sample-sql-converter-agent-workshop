-- ============================================================================
-- Source: SQL Server
-- Object: dbo.usp_archive_old_orders
-- Type: STORED PROCEDURE
-- ============================================================================
-- NOTE: This is an ASSUMED definition based on common archive procedure patterns.
--       Actual definition should be retrieved from Source RDS once connectivity is restored.
-- ============================================================================

CREATE PROCEDURE dbo.usp_archive_old_orders
    @cutoff_date DATETIME,
    @archived_count INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @error_message NVARCHAR(4000);
    DECLARE @error_severity INT;
    DECLARE @error_state INT;
    
    -- Initialize output parameter
    SET @archived_count = 0;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Validate input parameter
        IF @cutoff_date IS NULL
        BEGIN
            RAISERROR('Parameter @cutoff_date cannot be NULL', 16, 1);
            RETURN;
        END
        
        -- Insert old orders into archive table
        INSERT INTO dbo.orders_archive (
            order_id,
            order_date,
            customer_id,
            total_amount,
            status,
            archived_date
        )
        SELECT 
            order_id,
            order_date,
            customer_id,
            total_amount,
            status,
            GETDATE() AS archived_date
        FROM dbo.orders
        WHERE order_date < @cutoff_date;
        
        -- Get count of archived records
        SET @archived_count = @@ROWCOUNT;
        
        -- Delete archived records from active table
        DELETE FROM dbo.orders
        WHERE order_date < @cutoff_date;
        
        COMMIT TRANSACTION;
        
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
