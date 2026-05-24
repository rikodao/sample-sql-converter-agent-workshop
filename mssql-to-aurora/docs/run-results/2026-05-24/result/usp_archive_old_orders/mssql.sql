-- ============================================================
-- Source DDL: dbo.usp_archive_old_orders
-- Database: Source RDS for SQL Server
-- Extracted: 2026-05-23
-- ============================================================

CREATE PROCEDURE dbo.usp_archive_old_orders
    @cutoff_date DATE,
    @rows_archived INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @rows_archived = 0;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @archived TABLE(order_id INT);

        DELETE FROM dbo.orders
        OUTPUT DELETED.order_id, DELETED.customer_id, DELETED.order_date,
               DELETED.total_amount, DELETED.status
        INTO dbo.orders_archive(order_id, customer_id, order_date, total_amount, status)
        WHERE order_date < @cutoff_date AND status = N'COMPLETED';

        SET @rows_archived = @@ROWCOUNT;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        DECLARE @msg NVARCHAR(2000) = ERROR_MESSAGE();
        THROW 50001, @msg, 1;
    END CATCH
END
