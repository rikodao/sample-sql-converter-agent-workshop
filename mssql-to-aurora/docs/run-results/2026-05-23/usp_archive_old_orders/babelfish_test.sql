-- ============================================================================
-- Test Cases for dbo.usp_archive_old_orders (Babelfish)
-- ============================================================================

-- ============================================================================
-- SETUP: テストデータ準備
-- ============================================================================

-- 既存データのバックアップ（テスト後に復元）
SELECT * INTO #orders_backup FROM dbo.orders;
SELECT * INTO #orders_archive_backup FROM dbo.orders_archive;

-- テスト用データのクリア
DELETE FROM dbo.orders_archive;
DELETE FROM dbo.orders;

-- テスト用データの投入
INSERT INTO dbo.orders (order_id, customer_id, order_date, total_amount, status)
VALUES
    -- 古い完了済み注文（アーカイブ対象）
    (1001, 1, '2023-01-15', 100.00, N'COMPLETED'),
    (1002, 2, '2023-02-20', 250.50, N'COMPLETED'),
    (1003, 3, '2023-03-10', 75.25, N'COMPLETED'),
    -- 古い未完了注文（アーカイブ対象外）
    (1004, 4, '2023-01-20', 150.00, N'PENDING'),
    (1005, 5, '2023-02-15', 300.00, N'CANCELLED'),
    -- 新しい完了済み注文（アーカイブ対象外）
    (1006, 6, '2024-01-15', 200.00, N'COMPLETED'),
    (1007, 7, '2024-02-20', 450.75, N'COMPLETED'),
    -- 境界値テスト用
    (1008, 8, '2023-12-31', 99.99, N'COMPLETED'),
    (1009, 9, '2024-01-01', 88.88, N'COMPLETED'),
    -- 金額境界値
    (1010, 10, '2023-06-01', 0.01, N'COMPLETED'),
    (1011, 11, '2023-06-02', 999999.99, N'COMPLETED');

-- ============================================================================
-- Test Case 1: 正常系 - 基本的なアーカイブ処理
-- ============================================================================
PRINT '=== Test Case 1: 正常系 - 基本的なアーカイブ処理 ===';

DECLARE @rows_archived1 INT;
EXEC dbo.usp_archive_old_orders 
    @cutoff_date = '2024-01-01',
    @rows_archived = @rows_archived1 OUTPUT;

SELECT 
    'Test Case 1' AS test_case,
    'Rows Archived' AS metric,
    @rows_archived1 AS value;

SELECT 
    'Test Case 1' AS test_case,
    'Remaining in orders' AS metric,
    COUNT(*) AS value
FROM dbo.orders;

SELECT 
    'Test Case 1' AS test_case,
    'Archived records' AS metric,
    COUNT(*) AS value
FROM dbo.orders_archive;

SELECT 
    'Test Case 1' AS test_case,
    'Archived order_ids' AS metric,
    order_id,
    customer_id,
    order_date,
    total_amount,
    status
FROM dbo.orders_archive
ORDER BY order_id;

-- ============================================================================
-- Test Case 2: 正常系 - 該当レコードなし
-- ============================================================================
PRINT '=== Test Case 2: 正常系 - 該当レコードなし ===';

-- データをリセット
DELETE FROM dbo.orders_archive;
DELETE FROM dbo.orders;
INSERT INTO dbo.orders (order_id, customer_id, order_date, total_amount, status)
VALUES
    (2001, 1, '2024-06-01', 100.00, N'COMPLETED'),
    (2002, 2, '2024-07-01', 200.00, N'PENDING');

DECLARE @rows_archived2 INT;
EXEC dbo.usp_archive_old_orders 
    @cutoff_date = '2024-01-01',
    @rows_archived = @rows_archived2 OUTPUT;

SELECT 
    'Test Case 2' AS test_case,
    'Rows Archived' AS metric,
    @rows_archived2 AS value;

SELECT 
    'Test Case 2' AS test_case,
    'Remaining in orders' AS metric,
    COUNT(*) AS value
FROM dbo.orders;

-- ============================================================================
-- Test Case 3: 正常系 - status フィルタリング確認
-- ============================================================================
PRINT '=== Test Case 3: 正常系 - status フィルタリング確認 ===';

-- データをリセット
DELETE FROM dbo.orders_archive;
DELETE FROM dbo.orders;
INSERT INTO dbo.orders (order_id, customer_id, order_date, total_amount, status)
VALUES
    (3001, 1, '2023-01-01', 100.00, N'COMPLETED'),
    (3002, 2, '2023-01-02', 200.00, N'PENDING'),
    (3003, 3, '2023-01-03', 300.00, N'CANCELLED'),
    (3004, 4, '2023-01-04', 400.00, N'COMPLETED');

DECLARE @rows_archived3 INT;
EXEC dbo.usp_archive_old_orders 
    @cutoff_date = '2024-01-01',
    @rows_archived = @rows_archived3 OUTPUT;

SELECT 
    'Test Case 3' AS test_case,
    'Rows Archived' AS metric,
    @rows_archived3 AS value;

SELECT 
    'Test Case 3' AS test_case,
    'Remaining orders by status' AS metric,
    status,
    COUNT(*) AS count
FROM dbo.orders
GROUP BY status
ORDER BY status;

-- ============================================================================
-- Test Case 4: 境界値 - cutoff_date が境界日
-- ============================================================================
PRINT '=== Test Case 4: 境界値 - cutoff_date が境界日 ===';

-- データをリセット
DELETE FROM dbo.orders_archive;
DELETE FROM dbo.orders;
INSERT INTO dbo.orders (order_id, customer_id, order_date, total_amount, status)
VALUES
    (4001, 1, '2023-12-31', 100.00, N'COMPLETED'),
    (4002, 2, '2024-01-01', 200.00, N'COMPLETED'),
    (4003, 3, '2024-01-02', 300.00, N'COMPLETED');

DECLARE @rows_archived4 INT;
EXEC dbo.usp_archive_old_orders 
    @cutoff_date = '2024-01-01',
    @rows_archived = @rows_archived4 OUTPUT;

SELECT 
    'Test Case 4' AS test_case,
    'Rows Archived' AS metric,
    @rows_archived4 AS value;

SELECT 
    'Test Case 4' AS test_case,
    'Remaining order_ids' AS metric,
    order_id,
    order_date
FROM dbo.orders
ORDER BY order_id;

-- ============================================================================
-- Test Case 5: 境界値 - 金額の境界値
-- ============================================================================
PRINT '=== Test Case 5: 境界値 - 金額の境界値 ===';

-- データをリセット
DELETE FROM dbo.orders_archive;
DELETE FROM dbo.orders;
INSERT INTO dbo.orders (order_id, customer_id, order_date, total_amount, status)
VALUES
    (5001, 1, '2023-01-01', 0.01, N'COMPLETED'),
    (5002, 2, '2023-01-02', 999999.99, N'COMPLETED'),
    (5003, 3, '2023-01-03', 0.00, N'COMPLETED');

DECLARE @rows_archived5 INT;
EXEC dbo.usp_archive_old_orders 
    @cutoff_date = '2024-01-01',
    @rows_archived = @rows_archived5 OUTPUT;

SELECT 
    'Test Case 5' AS test_case,
    'Archived amounts' AS metric,
    order_id,
    total_amount
FROM dbo.orders_archive
ORDER BY order_id;

-- ============================================================================
-- Test Case 6: 境界値 - NULL cutoff_date
-- ============================================================================
PRINT '=== Test Case 6: 境界値 - NULL cutoff_date ===';

-- データをリセット
DELETE FROM dbo.orders_archive;
DELETE FROM dbo.orders;
INSERT INTO dbo.orders (order_id, customer_id, order_date, total_amount, status)
VALUES
    (6001, 1, '2023-01-01', 100.00, N'COMPLETED');

BEGIN TRY
    DECLARE @rows_archived6 INT;
    EXEC dbo.usp_archive_old_orders 
        @cutoff_date = NULL,
        @rows_archived = @rows_archived6 OUTPUT;
    
    SELECT 
        'Test Case 6' AS test_case,
        'NULL cutoff_date result' AS metric,
        @rows_archived6 AS value;
END TRY
BEGIN CATCH
    SELECT 
        'Test Case 6' AS test_case,
        'NULL cutoff_date error' AS metric,
        ERROR_MESSAGE() AS error_message;
END CATCH;

-- ============================================================================
-- Test Case 7: 例外系 - トランザクションロールバック確認
-- ============================================================================
PRINT '=== Test Case 7: 例外系 - トランザクションロールバック確認 ===';

-- データをリセット
DELETE FROM dbo.orders_archive;
DELETE FROM dbo.orders;
INSERT INTO dbo.orders (order_id, customer_id, order_date, total_amount, status)
VALUES
    (7001, 1, '2023-01-01', 100.00, N'COMPLETED');

-- orders_archive に制約違反を起こすため、同じ order_id を事前挿入
-- (order_id が主キーと仮定)
BEGIN TRY
    INSERT INTO dbo.orders_archive (order_id, customer_id, order_date, total_amount, status)
    VALUES (7001, 999, '2023-01-01', 999.99, N'COMPLETED');
    
    DECLARE @rows_archived7 INT;
    EXEC dbo.usp_archive_old_orders 
        @cutoff_date = '2024-01-01',
        @rows_archived = @rows_archived7 OUTPUT;
    
    SELECT 
        'Test Case 7' AS test_case,
        'Should not reach here' AS metric,
        @rows_archived7 AS value;
END TRY
BEGIN CATCH
    SELECT 
        'Test Case 7' AS test_case,
        'Rollback error caught' AS metric,
        ERROR_MESSAGE() AS error_message;
    
    -- ロールバック後、元のレコードが残っているか確認
    SELECT 
        'Test Case 7' AS test_case,
        'Orders after rollback' AS metric,
        COUNT(*) AS count
    FROM dbo.orders
    WHERE order_id = 7001;
END CATCH;

-- ============================================================================
-- Test Case 8: 副作用 - 複数回実行の冪等性
-- ============================================================================
PRINT '=== Test Case 8: 副作用 - 複数回実行の冪等性 ===';

-- データをリセット
DELETE FROM dbo.orders_archive;
DELETE FROM dbo.orders;
INSERT INTO dbo.orders (order_id, customer_id, order_date, total_amount, status)
VALUES
    (8001, 1, '2023-01-01', 100.00, N'COMPLETED'),
    (8002, 2, '2023-01-02', 200.00, N'COMPLETED');

-- 1回目の実行
DECLARE @rows_archived8_1 INT;
EXEC dbo.usp_archive_old_orders 
    @cutoff_date = '2024-01-01',
    @rows_archived = @rows_archived8_1 OUTPUT;

-- 2回目の実行（該当レコードなし）
DECLARE @rows_archived8_2 INT;
EXEC dbo.usp_archive_old_orders 
    @cutoff_date = '2024-01-01',
    @rows_archived = @rows_archived8_2 OUTPUT;

SELECT 
    'Test Case 8' AS test_case,
    'First execution' AS metric,
    @rows_archived8_1 AS value
UNION ALL
SELECT 
    'Test Case 8' AS test_case,
    'Second execution' AS metric,
    @rows_archived8_2 AS value;

-- ============================================================================
-- CLEANUP: テストデータのクリーンアップと復元
-- ============================================================================
PRINT '=== CLEANUP: データ復元 ===';

DELETE FROM dbo.orders;
DELETE FROM dbo.orders_archive;

INSERT INTO dbo.orders SELECT * FROM #orders_backup;
INSERT INTO dbo.orders_archive SELECT * FROM #orders_archive_backup;

DROP TABLE #orders_backup;
DROP TABLE #orders_archive_backup;

SELECT 'CLEANUP' AS test_case, 'Data restored' AS status;
