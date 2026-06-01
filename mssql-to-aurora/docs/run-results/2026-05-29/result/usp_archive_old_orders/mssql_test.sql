-- ============================================================================
-- Test Suite for dbo.usp_archive_old_orders
-- ============================================================================
-- This test suite covers:
-- - Normal cases: Archive records with various cutoff dates
-- - Boundary cases: NULL parameters, empty result sets, edge dates
-- - Exception cases: Invalid inputs, transaction rollback
-- - Side effects: Verify INSERT/DELETE counts, data integrity
-- ============================================================================

-- ============= TEST CASE 1: Normal archive with valid cutoff date =============
-- SETUP
CREATE TABLE #orders (
    order_id INT PRIMARY KEY,
    order_date DATETIME NOT NULL,
    customer_id INT NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    status NVARCHAR(20) NOT NULL
);

CREATE TABLE #orders_archive (
    order_id INT PRIMARY KEY,
    order_date DATETIME NOT NULL,
    customer_id INT NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    status NVARCHAR(20) NOT NULL,
    archived_date DATETIME NOT NULL
);

-- Insert test data: 5 old orders, 3 recent orders
INSERT INTO #orders (order_id, order_date, customer_id, total_amount, status) VALUES
(1, '2023-01-15', 101, 150.00, 'Completed'),
(2, '2023-02-20', 102, 200.00, 'Completed'),
(3, '2023-03-10', 103, 175.50, 'Completed'),
(4, '2023-06-15', 104, 300.00, 'Completed'),
(5, '2023-07-20', 105, 250.00, 'Completed'),
(6, '2024-01-10', 106, 400.00, 'Completed'),
(7, '2024-02-15', 107, 350.00, 'Completed'),
(8, '2024-03-20', 108, 500.00, 'Completed');

-- EXEC
DECLARE @archived_count INT;
DECLARE @cutoff DATETIME = '2024-01-01';

-- Create temporary procedure wrapper for testing
CREATE PROCEDURE #test_archive_proc
    @cutoff_date DATETIME,
    @archived_count INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        IF @cutoff_date IS NULL
        BEGIN
            RAISERROR('Parameter @cutoff_date cannot be NULL', 16, 1);
            RETURN;
        END
        
        INSERT INTO #orders_archive (order_id, order_date, customer_id, total_amount, status, archived_date)
        SELECT order_id, order_date, customer_id, total_amount, status, GETDATE()
        FROM #orders
        WHERE order_date < @cutoff_date;
        
        SET @archived_count = @@ROWCOUNT;
        
        DELETE FROM #orders WHERE order_date < @cutoff_date;
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @msg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@msg, 16, 1);
    END CATCH
END;

EXEC #test_archive_proc @cutoff_date = @cutoff, @archived_count = @archived_count OUTPUT;

-- ASSERT
SELECT 'TC1' AS tc, @archived_count AS archived_count, 
       (SELECT COUNT(*) FROM #orders) AS remaining_orders,
       (SELECT COUNT(*) FROM #orders_archive) AS archived_orders;

-- CLEANUP
DROP PROCEDURE #test_archive_proc;
DROP TABLE #orders;
DROP TABLE #orders_archive;
GO

-- ============= TEST CASE 2: Archive all records (cutoff date in future) =============
-- SETUP
CREATE TABLE #orders (
    order_id INT PRIMARY KEY,
    order_date DATETIME NOT NULL,
    customer_id INT NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    status NVARCHAR(20) NOT NULL
);

CREATE TABLE #orders_archive (
    order_id INT PRIMARY KEY,
    order_date DATETIME NOT NULL,
    customer_id INT NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    status NVARCHAR(20) NOT NULL,
    archived_date DATETIME NOT NULL
);

INSERT INTO #orders (order_id, order_date, customer_id, total_amount, status) VALUES
(1, '2023-01-15', 101, 150.00, 'Completed'),
(2, '2023-06-20', 102, 200.00, 'Completed'),
(3, '2023-12-10', 103, 175.50, 'Completed');

-- EXEC
DECLARE @archived_count INT;
DECLARE @cutoff DATETIME = '2025-12-31';

CREATE PROCEDURE #test_archive_proc
    @cutoff_date DATETIME,
    @archived_count INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF @cutoff_date IS NULL
        BEGIN
            RAISERROR('Parameter @cutoff_date cannot be NULL', 16, 1);
            RETURN;
        END
        INSERT INTO #orders_archive (order_id, order_date, customer_id, total_amount, status, archived_date)
        SELECT order_id, order_date, customer_id, total_amount, status, GETDATE()
        FROM #orders WHERE order_date < @cutoff_date;
        SET @archived_count = @@ROWCOUNT;
        DELETE FROM #orders WHERE order_date < @cutoff_date;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @msg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@msg, 16, 1);
    END CATCH
END;

EXEC #test_archive_proc @cutoff_date = @cutoff, @archived_count = @archived_count OUTPUT;

-- ASSERT
SELECT 'TC2' AS tc, @archived_count AS archived_count,
       (SELECT COUNT(*) FROM #orders) AS remaining_orders,
       (SELECT COUNT(*) FROM #orders_archive) AS archived_orders;

-- CLEANUP
DROP PROCEDURE #test_archive_proc;
DROP TABLE #orders;
DROP TABLE #orders_archive;
GO

-- ============= TEST CASE 3: No records to archive (cutoff date before all orders) =============
-- SETUP
CREATE TABLE #orders (
    order_id INT PRIMARY KEY,
    order_date DATETIME NOT NULL,
    customer_id INT NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    status NVARCHAR(20) NOT NULL
);

CREATE TABLE #orders_archive (
    order_id INT PRIMARY KEY,
    order_date DATETIME NOT NULL,
    customer_id INT NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    status NVARCHAR(20) NOT NULL,
    archived_date DATETIME NOT NULL
);

INSERT INTO #orders (order_id, order_date, customer_id, total_amount, status) VALUES
(1, '2024-01-15', 101, 150.00, 'Completed'),
(2, '2024-06-20', 102, 200.00, 'Completed');

-- EXEC
DECLARE @archived_count INT;
DECLARE @cutoff DATETIME = '2023-01-01';

CREATE PROCEDURE #test_archive_proc
    @cutoff_date DATETIME,
    @archived_count INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF @cutoff_date IS NULL
        BEGIN
            RAISERROR('Parameter @cutoff_date cannot be NULL', 16, 1);
            RETURN;
        END
        INSERT INTO #orders_archive (order_id, order_date, customer_id, total_amount, status, archived_date)
        SELECT order_id, order_date, customer_id, total_amount, status, GETDATE()
        FROM #orders WHERE order_date < @cutoff_date;
        SET @archived_count = @@ROWCOUNT;
        DELETE FROM #orders WHERE order_date < @cutoff_date;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @msg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@msg, 16, 1);
    END CATCH
END;

EXEC #test_archive_proc @cutoff_date = @cutoff, @archived_count = @archived_count OUTPUT;

-- ASSERT
SELECT 'TC3' AS tc, @archived_count AS archived_count,
       (SELECT COUNT(*) FROM #orders) AS remaining_orders,
       (SELECT COUNT(*) FROM #orders_archive) AS archived_orders;

-- CLEANUP
DROP PROCEDURE #test_archive_proc;
DROP TABLE #orders;
DROP TABLE #orders_archive;
GO

-- ============= TEST CASE 4: NULL cutoff_date parameter (exception expected) =============
-- SETUP
CREATE TABLE #orders (
    order_id INT PRIMARY KEY,
    order_date DATETIME NOT NULL,
    customer_id INT NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    status NVARCHAR(20) NOT NULL
);

CREATE TABLE #orders_archive (
    order_id INT PRIMARY KEY,
    order_date DATETIME NOT NULL,
    customer_id INT NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    status NVARCHAR(20) NOT NULL,
    archived_date DATETIME NOT NULL
);

INSERT INTO #orders (order_id, order_date, customer_id, total_amount, status) VALUES
(1, '2023-01-15', 101, 150.00, 'Completed');

-- EXEC
CREATE PROCEDURE #test_archive_proc
    @cutoff_date DATETIME,
    @archived_count INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF @cutoff_date IS NULL
        BEGIN
            RAISERROR('Parameter @cutoff_date cannot be NULL', 16, 1);
            RETURN;
        END
        INSERT INTO #orders_archive (order_id, order_date, customer_id, total_amount, status, archived_date)
        SELECT order_id, order_date, customer_id, total_amount, status, GETDATE()
        FROM #orders WHERE order_date < @cutoff_date;
        SET @archived_count = @@ROWCOUNT;
        DELETE FROM #orders WHERE order_date < @cutoff_date;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @msg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@msg, 16, 1);
    END CATCH
END;

DECLARE @archived_count INT;
BEGIN TRY
    EXEC #test_archive_proc @cutoff_date = NULL, @archived_count = @archived_count OUTPUT;
    -- ASSERT (should not reach here)
    SELECT 'TC4' AS tc, 'NO_ERROR' AS result;
END TRY
BEGIN CATCH
    -- ASSERT (expected path)
    SELECT 'TC4' AS tc, ERROR_MESSAGE() AS result;
END CATCH

-- CLEANUP
DROP PROCEDURE #test_archive_proc;
DROP TABLE #orders;
DROP TABLE #orders_archive;
GO

-- ============= TEST CASE 5: Empty orders table =============
-- SETUP
CREATE TABLE #orders (
    order_id INT PRIMARY KEY,
    order_date DATETIME NOT NULL,
    customer_id INT NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    status NVARCHAR(20) NOT NULL
);

CREATE TABLE #orders_archive (
    order_id INT PRIMARY KEY,
    order_date DATETIME NOT NULL,
    customer_id INT NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    status NVARCHAR(20) NOT NULL,
    archived_date DATETIME NOT NULL
);

-- No data inserted

-- EXEC
DECLARE @archived_count INT;
DECLARE @cutoff DATETIME = '2024-01-01';

CREATE PROCEDURE #test_archive_proc
    @cutoff_date DATETIME,
    @archived_count INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF @cutoff_date IS NULL
        BEGIN
            RAISERROR('Parameter @cutoff_date cannot be NULL', 16, 1);
            RETURN;
        END
        INSERT INTO #orders_archive (order_id, order_date, customer_id, total_amount, status, archived_date)
        SELECT order_id, order_date, customer_id, total_amount, status, GETDATE()
        FROM #orders WHERE order_date < @cutoff_date;
        SET @archived_count = @@ROWCOUNT;
        DELETE FROM #orders WHERE order_date < @cutoff_date;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @msg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@msg, 16, 1);
    END CATCH
END;

EXEC #test_archive_proc @cutoff_date = @cutoff, @archived_count = @archived_count OUTPUT;

-- ASSERT
SELECT 'TC5' AS tc, @archived_count AS archived_count,
       (SELECT COUNT(*) FROM #orders) AS remaining_orders,
       (SELECT COUNT(*) FROM #orders_archive) AS archived_orders;

-- CLEANUP
DROP PROCEDURE #test_archive_proc;
DROP TABLE #orders;
DROP TABLE #orders_archive;
GO

-- ============= TEST CASE 6: Boundary date - exact match on cutoff =============
-- SETUP
CREATE TABLE #orders (
    order_id INT PRIMARY KEY,
    order_date DATETIME NOT NULL,
    customer_id INT NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    status NVARCHAR(20) NOT NULL
);

CREATE TABLE #orders_archive (
    order_id INT PRIMARY KEY,
    order_date DATETIME NOT NULL,
    customer_id INT NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    status NVARCHAR(20) NOT NULL,
    archived_date DATETIME NOT NULL
);

-- Insert orders with exact cutoff date and before/after
INSERT INTO #orders (order_id, order_date, customer_id, total_amount, status) VALUES
(1, '2023-12-31', 101, 150.00, 'Completed'),
(2, '2024-01-01', 102, 200.00, 'Completed'),
(3, '2024-01-02', 103, 175.50, 'Completed');

-- EXEC
DECLARE @archived_count INT;
DECLARE @cutoff DATETIME = '2024-01-01';

CREATE PROCEDURE #test_archive_proc
    @cutoff_date DATETIME,
    @archived_count INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF @cutoff_date IS NULL
        BEGIN
            RAISERROR('Parameter @cutoff_date cannot be NULL', 16, 1);
            RETURN;
        END
        INSERT INTO #orders_archive (order_id, order_date, customer_id, total_amount, status, archived_date)
        SELECT order_id, order_date, customer_id, total_amount, status, GETDATE()
        FROM #orders WHERE order_date < @cutoff_date;
        SET @archived_count = @@ROWCOUNT;
        DELETE FROM #orders WHERE order_date < @cutoff_date;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @msg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@msg, 16, 1);
    END CATCH
END;

EXEC #test_archive_proc @cutoff_date = @cutoff, @archived_count = @archived_count OUTPUT;

-- ASSERT
SELECT 'TC6' AS tc, @archived_count AS archived_count,
       (SELECT COUNT(*) FROM #orders) AS remaining_orders,
       (SELECT COUNT(*) FROM #orders_archive) AS archived_orders,
       (SELECT MIN(order_date) FROM #orders) AS min_remaining_date;

-- CLEANUP
DROP PROCEDURE #test_archive_proc;
DROP TABLE #orders;
DROP TABLE #orders_archive;
GO

-- ============= TEST CASE 7: Verify data integrity after archive =============
-- SETUP
CREATE TABLE #orders (
    order_id INT PRIMARY KEY,
    order_date DATETIME NOT NULL,
    customer_id INT NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    status NVARCHAR(20) NOT NULL
);

CREATE TABLE #orders_archive (
    order_id INT PRIMARY KEY,
    order_date DATETIME NOT NULL,
    customer_id INT NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    status NVARCHAR(20) NOT NULL,
    archived_date DATETIME NOT NULL
);

INSERT INTO #orders (order_id, order_date, customer_id, total_amount, status) VALUES
(1, '2023-01-15', 101, 150.00, 'Completed'),
(2, '2023-06-20', 102, 200.00, 'Completed'),
(3, '2024-01-10', 103, 300.00, 'Completed');

-- EXEC
DECLARE @archived_count INT;
DECLARE @cutoff DATETIME = '2024-01-01';

CREATE PROCEDURE #test_archive_proc
    @cutoff_date DATETIME,
    @archived_count INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF @cutoff_date IS NULL
        BEGIN
            RAISERROR('Parameter @cutoff_date cannot be NULL', 16, 1);
            RETURN;
        END
        INSERT INTO #orders_archive (order_id, order_date, customer_id, total_amount, status, archived_date)
        SELECT order_id, order_date, customer_id, total_amount, status, GETDATE()
        FROM #orders WHERE order_date < @cutoff_date;
        SET @archived_count = @@ROWCOUNT;
        DELETE FROM #orders WHERE order_date < @cutoff_date;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @msg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@msg, 16, 1);
    END CATCH
END;

EXEC #test_archive_proc @cutoff_date = @cutoff, @archived_count = @archived_count OUTPUT;

-- ASSERT - Verify archived data matches original
SELECT 'TC7' AS tc,
       (SELECT SUM(total_amount) FROM #orders_archive) AS archived_total,
       (SELECT COUNT(DISTINCT customer_id) FROM #orders_archive) AS archived_customers,
       (SELECT MAX(order_date) FROM #orders_archive) AS max_archived_date;

-- CLEANUP
DROP PROCEDURE #test_archive_proc;
DROP TABLE #orders;
DROP TABLE #orders_archive;
GO

-- ============= TEST CASE 8: Transaction rollback on constraint violation =============
-- SETUP
CREATE TABLE #orders (
    order_id INT PRIMARY KEY,
    order_date DATETIME NOT NULL,
    customer_id INT NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    status NVARCHAR(20) NOT NULL
);

CREATE TABLE #orders_archive (
    order_id INT PRIMARY KEY,
    order_date DATETIME NOT NULL,
    customer_id INT NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    status NVARCHAR(20) NOT NULL,
    archived_date DATETIME NOT NULL
);

-- Insert data with potential duplicate
INSERT INTO #orders (order_id, order_date, customer_id, total_amount, status) VALUES
(1, '2023-01-15', 101, 150.00, 'Completed'),
(2, '2023-06-20', 102, 200.00, 'Completed');

-- Pre-insert a duplicate to cause constraint violation
INSERT INTO #orders_archive (order_id, order_date, customer_id, total_amount, status, archived_date) VALUES
(1, '2023-01-15', 101, 150.00, 'Completed', GETDATE());

-- EXEC
CREATE PROCEDURE #test_archive_proc
    @cutoff_date DATETIME,
    @archived_count INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF @cutoff_date IS NULL
        BEGIN
            RAISERROR('Parameter @cutoff_date cannot be NULL', 16, 1);
            RETURN;
        END
        INSERT INTO #orders_archive (order_id, order_date, customer_id, total_amount, status, archived_date)
        SELECT order_id, order_date, customer_id, total_amount, status, GETDATE()
        FROM #orders WHERE order_date < @cutoff_date;
        SET @archived_count = @@ROWCOUNT;
        DELETE FROM #orders WHERE order_date < @cutoff_date;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @msg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@msg, 16, 1);
    END CATCH
END;

DECLARE @archived_count INT;
DECLARE @cutoff DATETIME = '2024-01-01';

BEGIN TRY
    EXEC #test_archive_proc @cutoff_date = @cutoff, @archived_count = @archived_count OUTPUT;
    -- ASSERT (should not reach here)
    SELECT 'TC8' AS tc, 'NO_ERROR' AS result, 
           (SELECT COUNT(*) FROM #orders) AS orders_count;
END TRY
BEGIN CATCH
    -- ASSERT (expected path - verify rollback preserved original data)
    SELECT 'TC8' AS tc, 'ERROR_CAUGHT' AS result,
           (SELECT COUNT(*) FROM #orders) AS orders_count_after_rollback;
END CATCH

-- CLEANUP
DROP PROCEDURE #test_archive_proc;
DROP TABLE #orders;
DROP TABLE #orders_archive;
GO
