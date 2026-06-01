-- ============================================================================
-- Test Suite for dbo.usp_upsert_department
-- ============================================================================
-- このテストスイートは MERGE 文を使用した UPSERT プロシージャの動作を検証します
-- 
-- テストカテゴリ:
-- 1. 正常系: 新規挿入、既存更新、parent_id の変更
-- 2. 境界値: NULL parent_id、空文字に近い値、長い文字列
-- 3. 例外系: NULL name、長すぎる name
-- 4. トランザクション: ロールバック動作
-- 5. 副作用: INSERT/UPDATE の件数確認
-- ============================================================================

-- ============================================================================
-- SETUP: テストデータ準備
-- ============================================================================

-- トランザクション開始（全テスト終了後にロールバック）
BEGIN TRANSACTION;

-- 既存データの退避用一時テーブル
SELECT * INTO #backup_departments FROM dbo.departments;

-- テスト用の初期データをクリア（テスト用の名前パターンのみ）
DELETE FROM dbo.departments WHERE name LIKE 'TEST_%';

-- 初期テストデータ挿入
INSERT INTO dbo.departments (name, parent_id) VALUES ('TEST_EXISTING_DEPT', NULL);
INSERT INTO dbo.departments (name, parent_id) VALUES ('TEST_DEPT_WITH_PARENT', 1);

SELECT 'SETUP COMPLETE' AS setup_status;

-- ============================================================================
-- Test Case 1: 正常系 - 新規部署の挿入
-- ============================================================================
SELECT '=== Test Case 1: Insert New Department ===' AS test_case;

-- 実行前の件数
DECLARE @count_before_1 INT;
SELECT @count_before_1 = COUNT(*) FROM dbo.departments WHERE name = 'TEST_NEW_DEPT_1';
SELECT @count_before_1 AS count_before;

-- プロシージャ実行
EXEC dbo.usp_upsert_department @name = 'TEST_NEW_DEPT_1', @parent_id = NULL;

-- 実行後の確認
SELECT 
    name,
    parent_id,
    CASE WHEN created_at IS NOT NULL THEN 'HAS_VALUE' ELSE 'NULL' END AS created_at_status
FROM dbo.departments 
WHERE name = 'TEST_NEW_DEPT_1';

DECLARE @count_after_1 INT;
SELECT @count_after_1 = COUNT(*) FROM dbo.departments WHERE name = 'TEST_NEW_DEPT_1';
SELECT @count_after_1 AS count_after;

-- ============================================================================
-- Test Case 2: 正常系 - 新規部署の挿入（parent_id 指定あり）
-- ============================================================================
SELECT '=== Test Case 2: Insert New Department with Parent ===' AS test_case;

-- 親部署のIDを取得
DECLARE @parent_dept_id INT;
SELECT @parent_dept_id = department_id FROM dbo.departments WHERE name = 'TEST_EXISTING_DEPT';

-- プロシージャ実行
EXEC dbo.usp_upsert_department @name = 'TEST_NEW_DEPT_2', @parent_id = @parent_dept_id;

-- 実行後の確認
SELECT 
    name,
    parent_id,
    CASE WHEN parent_id = @parent_dept_id THEN 'CORRECT' ELSE 'INCORRECT' END AS parent_id_check
FROM dbo.departments 
WHERE name = 'TEST_NEW_DEPT_2';

-- ============================================================================
-- Test Case 3: 正常系 - 既存部署の更新（parent_id を変更）
-- ============================================================================
SELECT '=== Test Case 3: Update Existing Department ===' AS test_case;

-- 実行前の状態
SELECT name, parent_id AS parent_id_before
FROM dbo.departments 
WHERE name = 'TEST_EXISTING_DEPT';

-- parent_id を更新（NULL → 値あり）
DECLARE @new_parent_id INT;
SELECT @new_parent_id = department_id FROM dbo.departments WHERE name = 'TEST_DEPT_WITH_PARENT';

EXEC dbo.usp_upsert_department @name = 'TEST_EXISTING_DEPT', @parent_id = @new_parent_id;

-- 実行後の確認
SELECT 
    name, 
    parent_id AS parent_id_after,
    CASE WHEN parent_id = @new_parent_id THEN 'UPDATED' ELSE 'NOT_UPDATED' END AS update_status
FROM dbo.departments 
WHERE name = 'TEST_EXISTING_DEPT';

-- 件数が増えていないことを確認（UPDATE であって INSERT ではない）
SELECT COUNT(*) AS count_should_be_1
FROM dbo.departments 
WHERE name = 'TEST_EXISTING_DEPT';

-- ============================================================================
-- Test Case 4: 境界値 - parent_id が NULL（デフォルト値）
-- ============================================================================
SELECT '=== Test Case 4: Boundary - NULL parent_id (default) ===' AS test_case;

-- parent_id パラメータを省略（デフォルト NULL）
EXEC dbo.usp_upsert_department @name = 'TEST_NULL_PARENT';

SELECT name, parent_id, 
       CASE WHEN parent_id IS NULL THEN 'NULL' ELSE 'NOT_NULL' END AS parent_id_status
FROM dbo.departments 
WHERE name = 'TEST_NULL_PARENT';

-- ============================================================================
-- Test Case 5: 境界値 - 最小長の name（1文字）
-- ============================================================================
SELECT '=== Test Case 5: Boundary - Minimum Length Name ===' AS test_case;

EXEC dbo.usp_upsert_department @name = N'T', @parent_id = NULL;

SELECT name, LEN(name) AS name_length
FROM dbo.departments 
WHERE name = N'T';

-- ============================================================================
-- Test Case 6: 境界値 - 最大長に近い name（100文字）
-- ============================================================================
SELECT '=== Test Case 6: Boundary - Maximum Length Name ===' AS test_case;

DECLARE @long_name NVARCHAR(100);
SET @long_name = REPLICATE(N'A', 100);

EXEC dbo.usp_upsert_department @name = @long_name, @parent_id = NULL;

SELECT name, LEN(name) AS name_length
FROM dbo.departments 
WHERE name = @long_name;

-- ============================================================================
-- Test Case 7: 境界値 - 既存レコードの parent_id を NULL に更新
-- ============================================================================
SELECT '=== Test Case 7: Boundary - Update parent_id to NULL ===' AS test_case;

-- 実行前の状態
SELECT name, parent_id AS parent_id_before
FROM dbo.departments 
WHERE name = 'TEST_DEPT_WITH_PARENT';

-- parent_id を NULL に更新
EXEC dbo.usp_upsert_department @name = 'TEST_DEPT_WITH_PARENT', @parent_id = NULL;

-- 実行後の確認
SELECT name, parent_id AS parent_id_after,
       CASE WHEN parent_id IS NULL THEN 'UPDATED_TO_NULL' ELSE 'STILL_HAS_VALUE' END AS update_status
FROM dbo.departments 
WHERE name = 'TEST_DEPT_WITH_PARENT';

-- ============================================================================
-- Test Case 8: 例外系 - NULL name（必須パラメータ）
-- ============================================================================
SELECT '=== Test Case 8: Exception - NULL name ===' AS test_case;

BEGIN TRY
    EXEC dbo.usp_upsert_department @name = NULL, @parent_id = NULL;
    SELECT 'NO_ERROR' AS error_status, '' AS error_message;
END TRY
BEGIN CATCH
    SELECT 'ERROR_OCCURRED' AS error_status, 
           ERROR_MESSAGE() AS error_message,
           ERROR_NUMBER() AS error_number;
END CATCH;

-- ============================================================================
-- Test Case 9: 例外系 - name が最大長を超える（101文字）
-- ============================================================================
SELECT '=== Test Case 9: Exception - Name Too Long ===' AS test_case;

BEGIN TRY
    DECLARE @too_long_name NVARCHAR(200);
    SET @too_long_name = REPLICATE(N'B', 101);
    
    EXEC dbo.usp_upsert_department @name = @too_long_name, @parent_id = NULL;
    SELECT 'NO_ERROR' AS error_status, '' AS error_message;
END TRY
BEGIN CATCH
    SELECT 'ERROR_OCCURRED' AS error_status, 
           ERROR_MESSAGE() AS error_message,
           ERROR_NUMBER() AS error_number;
END CATCH;

-- ============================================================================
-- Test Case 10: 副作用 - 複数回実行時の冪等性確認
-- ============================================================================
SELECT '=== Test Case 10: Side Effect - Idempotency ===' AS test_case;

-- 同じパラメータで3回実行
EXEC dbo.usp_upsert_department @name = 'TEST_IDEMPOTENT', @parent_id = NULL;
EXEC dbo.usp_upsert_department @name = 'TEST_IDEMPOTENT', @parent_id = NULL;
EXEC dbo.usp_upsert_department @name = 'TEST_IDEMPOTENT', @parent_id = NULL;

-- 件数は1件のみであることを確認
SELECT COUNT(*) AS count_should_be_1
FROM dbo.departments 
WHERE name = 'TEST_IDEMPOTENT';

-- ============================================================================
-- Test Case 11: 副作用 - MERGE による INSERT/UPDATE の動作確認
-- ============================================================================
SELECT '=== Test Case 11: Side Effect - MERGE Behavior ===' AS test_case;

-- 新規挿入
EXEC dbo.usp_upsert_department @name = 'TEST_MERGE_BEHAVIOR', @parent_id = 1;

SELECT 'AFTER_INSERT' AS stage, name, parent_id
FROM dbo.departments 
WHERE name = 'TEST_MERGE_BEHAVIOR';

-- 更新
EXEC dbo.usp_upsert_department @name = 'TEST_MERGE_BEHAVIOR', @parent_id = 2;

SELECT 'AFTER_UPDATE' AS stage, name, parent_id
FROM dbo.departments 
WHERE name = 'TEST_MERGE_BEHAVIOR';

-- parent_id が 2 に更新されていることを確認
SELECT 
    CASE WHEN parent_id = 2 THEN 'MERGE_UPDATE_SUCCESS' ELSE 'MERGE_UPDATE_FAILED' END AS merge_status
FROM dbo.departments 
WHERE name = 'TEST_MERGE_BEHAVIOR';

-- ============================================================================
-- Test Case 12: トランザクション - ロールバック動作
-- ============================================================================
SELECT '=== Test Case 12: Transaction - Rollback Behavior ===' AS test_case;

-- ネストしたトランザクションで確認
DECLARE @savepoint_count INT;
SELECT @savepoint_count = COUNT(*) FROM dbo.departments WHERE name = 'TEST_ROLLBACK';

SAVE TRANSACTION savepoint1;

EXEC dbo.usp_upsert_department @name = 'TEST_ROLLBACK', @parent_id = NULL;

SELECT COUNT(*) AS count_after_insert FROM dbo.departments WHERE name = 'TEST_ROLLBACK';

ROLLBACK TRANSACTION savepoint1;

SELECT COUNT(*) AS count_after_rollback FROM dbo.departments WHERE name = 'TEST_ROLLBACK';

-- ============================================================================
-- CLEANUP: テストデータのクリーンアップ
-- ============================================================================
SELECT '=== CLEANUP ===' AS cleanup_status;

-- トランザクションをロールバックして元の状態に戻す
ROLLBACK TRANSACTION;

SELECT 'All tests completed and rolled back' AS final_status;
