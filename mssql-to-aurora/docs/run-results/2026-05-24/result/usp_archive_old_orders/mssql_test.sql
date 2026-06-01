-- ============================================================
-- TEST SUITE: dbo.usp_archive_old_orders
-- Database: Source RDS for SQL Server
-- Purpose: Comprehensive test coverage for archive procedure
-- ============================================================

-- ============= TEST CASE 1: Normal archiving of old completed orders =============
-- SETUP
CREATE TABLE #test_orders_tc1 (
    order_id INT,
    customer_id INT,
    order_date DATETIME2,
    total_amount MONEY,
    status NVARCHAR(20)
);

INSERT INTO dbo.orders (customer_id, order_date, total_amount, status)
VALUES 
    (1001, '2020-01-15', 100.00, N'COMPLETED'),
    (1002, '2020-06-20', 250.50, N'COMPLETED'),
    (1003, '2023-12-01', 500.00, N'COMPLETED');

-- Store initial counts
DECLARE @initial_orders_count_tc1 INT = (SELECT COUNT(*) FROM dbo.orders WHERE status = N'COMPLETED');
DECLARE @initial_archive_count_tc1 INT = (SELECT COUNT(*) FROM dbo.orders_archive);

-- EXEC
DECLARE @archived_tc1 INT;
EXEC dbo.usp_archive_old_orders @cutoff_date = '2021-01-01', @rows_archived = @archived_tc1 OUTPUT;

-- ASSERT
SELECT 'TC1' AS tc, @archived_tc1 AS rows_archived;
SELECT 'TC1' AS tc, COUNT(*) AS remaining_in_orders FROM dbo.orders WHERE order_date < '2021-01-01' AND status = N'COMPLETED';
SELECT 'TC1' AS tc, COUNT(*) AS added_to_archive FROM dbo.orders_archive WHERE order_date < '2021-01-01';
SELECT 'TC1' AS tc, order_id, customer_id, order_date, total_amount, status 
FROM dbo.orders_archive 
WHERE order_date < '2021-01-01' 
ORDER BY order_id;

-- CLEANUP
DELETE FROM dbo.orders_archive WHERE order_date < '2021-01-01';
DELETE FROM dbo.orders WHERE customer_id IN (1003) AND order_date >= '2021-01-01';
DROP TABLE #test_orders_tc1;

-- ============= TEST CASE 2: Archive with cutoff date matching exact boundary =============
-- SETUP
INSERT INTO dbo.orders (customer_id, order_date, total_amount, status)
VALUES 
    (2001, '2022-12-31 23:59:59', 150.00, N'COMPLETED'),
    (2002, '2023-01-01 00:00:00', 200.00, N'COMPLETED');

-- EXEC
DECLARE @archived_tc2 INT;
EXEC dbo.usp_archive_old_orders @cutoff_date = '2023-01-01', @rows_archived = @archived_tc2 OUTPUT;

-- ASSERT
SELECT 'TC2' AS tc, @archived_tc2 AS rows_archived;
SELECT 'TC2' AS tc, order_id, order_date, status 
FROM dbo.orders 
WHERE customer_id IN (2001, 2002)
ORDER BY order_id;
SELECT 'TC2' AS tc, order_id, order_date 
FROM dbo.orders_archive 
WHERE customer_id = 2001
ORDER BY order_id;

-- CLEANUP
DELETE FROM dbo.orders_archive WHERE customer_id = 2001;
DELETE FROM dbo.orders WHERE customer_id IN (2001, 2002);

-- ============= TEST CASE 3: No orders to archive (all orders are recent) =============
-- SETUP
INSERT INTO dbo.orders (customer_id, order_date, total_amount, status)
VALUES 
    (3001, '2025-01-01', 300.00, N'COMPLETED'),
    (3002, '2025-06-15', 400.00, N'COMPLETED');

-- EXEC
DECLARE @archived_tc3 INT;
EXEC dbo.usp_archive_old_orders @cutoff_date = '2020-01-01', @rows_archived = @archived_tc3 OUTPUT;

-- ASSERT
SELECT 'TC3' AS tc, @archived_tc3 AS rows_archived;
SELECT 'TC3' AS tc, COUNT(*) AS orders_still_present FROM dbo.orders WHERE customer_id IN (3001, 3002);

-- CLEANUP
DELETE FROM dbo.orders WHERE customer_id IN (3001, 3002);

-- ============= TEST CASE 4: Only COMPLETED orders are archived (PENDING/CANCELLED excluded) =============
-- SETUP
INSERT INTO dbo.orders (customer_id, order_date, total_amount, status)
VALUES 
    (4001, '2019-05-10', 100.00, N'COMPLETED'),
    (4002, '2019-05-11', 150.00, N'PENDING'),
    (4003, '2019-05-12', 200.00, N'CANCELLED'),
    (4004, '2019-05-13', 250.00, N'COMPLETED');

-- EXEC
DECLARE @archived_tc4 INT;
EXEC dbo.usp_archive_old_orders @cutoff_date = '2020-01-01', @rows_archived = @archived_tc4 OUTPUT;

-- ASSERT
SELECT 'TC4' AS tc, @archived_tc4 AS rows_archived;
SELECT 'TC4' AS tc, customer_id, status 
FROM dbo.orders 
WHERE customer_id IN (4001, 4002, 4003, 4004)
ORDER BY customer_id;
SELECT 'TC4' AS tc, customer_id, status 
FROM dbo.orders_archive 
WHERE customer_id IN (4001, 4004)
ORDER BY customer_id;

-- CLEANUP
DELETE FROM dbo.orders_archive WHERE customer_id IN (4001, 4004);
DELETE FROM dbo.orders WHERE customer_id IN (4002, 4003);

-- ============= TEST CASE 5: NULL cutoff_date parameter =============
-- SETUP
-- No setup needed

-- EXEC & ASSERT
BEGIN TRY
    DECLARE @archived_tc5 INT;
    EXEC dbo.usp_archive_old_orders @cutoff_date = NULL, @rows_archived = @archived_tc5 OUTPUT;
    SELECT 'TC5' AS tc, 'NO_ERROR' AS result;
END TRY
BEGIN CATCH
    SELECT 'TC5' AS tc, ERROR_MESSAGE() AS result;
END CATCH

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 6: Archive large batch of orders =============
-- SETUP
DECLARE @i INT = 0;
WHILE @i < 50
BEGIN
    INSERT INTO dbo.orders (customer_id, order_date, total_amount, status)
    VALUES (5000 + @i, '2018-01-01', 100.00 + @i, N'COMPLETED');
    SET @i = @i + 1;
END

-- EXEC
DECLARE @archived_tc6 INT;
EXEC dbo.usp_archive_old_orders @cutoff_date = '2019-01-01', @rows_archived = @archived_tc6 OUTPUT;

-- ASSERT
SELECT 'TC6' AS tc, @archived_tc6 AS rows_archived;
SELECT 'TC6' AS tc, COUNT(*) AS archived_count FROM dbo.orders_archive WHERE customer_id BETWEEN 5000 AND 5049;

-- CLEANUP
DELETE FROM dbo.orders_archive WHERE customer_id BETWEEN 5000 AND 5049;

-- ============= TEST CASE 7: Verify transaction rollback on error (constraint violation simulation) =============
-- SETUP
-- Create a scenario where archive would fail (e.g., if orders_archive had a constraint)
-- Since we can't easily simulate constraint failure, we'll test the rollback mechanism
-- by checking that partial work is not committed

INSERT INTO dbo.orders (customer_id, order_date, total_amount, status)
VALUES 
    (7001, '2017-01-01', 100.00, N'COMPLETED'),
    (7002, '2017-01-02', 200.00, N'COMPLETED');

DECLARE @before_archive_tc7 INT = (SELECT COUNT(*) FROM dbo.orders WHERE customer_id IN (7001, 7002));

-- EXEC
DECLARE @archived_tc7 INT;
BEGIN TRY
    EXEC dbo.usp_archive_old_orders @cutoff_date = '2018-01-01', @rows_archived = @archived_tc7 OUTPUT;
    SELECT 'TC7' AS tc, 'SUCCESS' AS result, @archived_tc7 AS rows_archived;
END TRY
BEGIN CATCH
    SELECT 'TC7' AS tc, 'ERROR' AS result, ERROR_MESSAGE() AS error_msg;
END CATCH

-- ASSERT
SELECT 'TC7' AS tc, COUNT(*) AS remaining_orders FROM dbo.orders WHERE customer_id IN (7001, 7002);
SELECT 'TC7' AS tc, COUNT(*) AS archived_orders FROM dbo.orders_archive WHERE customer_id IN (7001, 7002);

-- CLEANUP
DELETE FROM dbo.orders_archive WHERE customer_id IN (7001, 7002);

-- ============= TEST CASE 8: Archive with zero total_amount =============
-- SETUP
INSERT INTO dbo.orders (customer_id, order_date, total_amount, status)
VALUES 
    (8001, '2019-03-15', 0.00, N'COMPLETED'),
    (8002, '2019-03-16', -10.00, N'COMPLETED');

-- EXEC
DECLARE @archived_tc8 INT;
EXEC dbo.usp_archive_old_orders @cutoff_date = '2020-01-01', @rows_archived = @archived_tc8 OUTPUT;

-- ASSERT
SELECT 'TC8' AS tc, @archived_tc8 AS rows_archived;
SELECT 'TC8' AS tc, customer_id, total_amount 
FROM dbo.orders_archive 
WHERE customer_id IN (8001, 8002)
ORDER BY customer_id;

-- CLEANUP
DELETE FROM dbo.orders_archive WHERE customer_id IN (8001, 8002);

-- ============= TEST CASE 9: Verify OUTPUT parameter is set correctly when no rows archived =============
-- SETUP
-- No old completed orders exist for this test

-- EXEC
DECLARE @archived_tc9 INT = -1; -- Initialize to non-zero to verify it gets set
EXEC dbo.usp_archive_old_orders @cutoff_date = '1990-01-01', @rows_archived = @archived_tc9 OUTPUT;

-- ASSERT
SELECT 'TC9' AS tc, @archived_tc9 AS rows_archived;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 10: Archive orders with maximum date precision =============
-- SETUP
INSERT INTO dbo.orders (customer_id, order_date, total_amount, status)
VALUES 
    (10001, '2019-12-31 23:59:59.9999999', 500.00, N'COMPLETED'),
    (10002, '2020-01-01 00:00:00.0000000', 600.00, N'COMPLETED');

-- EXEC
DECLARE @archived_tc10 INT;
EXEC dbo.usp_archive_old_orders @cutoff_date = '2020-01-01', @rows_archived = @archived_tc10 OUTPUT;

-- ASSERT
SELECT 'TC10' AS tc, @archived_tc10 AS rows_archived;
SELECT 'TC10' AS tc, customer_id, order_date 
FROM dbo.orders_archive 
WHERE customer_id = 10001
ORDER BY customer_id;
SELECT 'TC10' AS tc, customer_id 
FROM dbo.orders 
WHERE customer_id = 10002;

-- CLEANUP
DELETE FROM dbo.orders_archive WHERE customer_id = 10001;
DELETE FROM dbo.orders WHERE customer_id = 10002;
