-- ============================================================================
-- Test Suite for public.usp_upsert_department (PostgreSQL Native)
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
BEGIN;

-- 既存データの退避用一時テーブル
CREATE TEMP TABLE backup_departments AS SELECT * FROM public.departments;

-- テスト用の初期データをクリア（テスト用の名前パターンのみ）
DELETE FROM public.departments WHERE name LIKE 'TEST_%';

-- 初期テストデータ挿入
INSERT INTO public.departments (name, parent_id) VALUES ('TEST_EXISTING_DEPT', NULL);
INSERT INTO public.departments (name, parent_id) VALUES ('TEST_DEPT_WITH_PARENT', 1);

SELECT 'SETUP COMPLETE' AS setup_status;

-- ============================================================================
-- Test Case 1: 正常系 - 新規部署の挿入
-- ============================================================================
SELECT '=== Test Case 1: Insert New Department ===' AS test_case;

-- 実行前の件数
DO $$
DECLARE
    count_before_1 INT;
BEGIN
    SELECT COUNT(*) INTO count_before_1 FROM public.departments WHERE name = 'TEST_NEW_DEPT_1';
    RAISE NOTICE 'count_before: %', count_before_1;
END $$;

-- プロシージャ実行
CALL public.usp_upsert_department('TEST_NEW_DEPT_1', NULL);

-- 実行後の確認
SELECT 
    name,
    parent_id,
    CASE WHEN created_at IS NOT NULL THEN 'HAS_VALUE' ELSE 'NULL' END AS created_at_status
FROM public.departments 
WHERE name = 'TEST_NEW_DEPT_1';

DO $$
DECLARE
    count_after_1 INT;
BEGIN
    SELECT COUNT(*) INTO count_after_1 FROM public.departments WHERE name = 'TEST_NEW_DEPT_1';
    RAISE NOTICE 'count_after: %', count_after_1;
END $$;

-- ============================================================================
-- Test Case 2: 正常系 - 新規部署の挿入（parent_id 指定あり）
-- ============================================================================
SELECT '=== Test Case 2: Insert New Department with Parent ===' AS test_case;

-- 親部署のIDを取得してプロシージャ実行
DO $$
DECLARE
    parent_dept_id INT;
BEGIN
    SELECT department_id INTO parent_dept_id FROM public.departments WHERE name = 'TEST_EXISTING_DEPT';
    CALL public.usp_upsert_department('TEST_NEW_DEPT_2', parent_dept_id);
END $$;

-- 実行後の確認
SELECT 
    name,
    parent_id,
    CASE WHEN parent_id = (SELECT department_id FROM public.departments WHERE name = 'TEST_EXISTING_DEPT') 
         THEN 'CORRECT' ELSE 'INCORRECT' END AS parent_id_check
FROM public.departments 
WHERE name = 'TEST_NEW_DEPT_2';

-- ============================================================================
-- Test Case 3: 正常系 - 既存部署の更新（parent_id を変更）
-- ============================================================================
SELECT '=== Test Case 3: Update Existing Department ===' AS test_case;

-- 実行前の状態
SELECT name, parent_id AS parent_id_before
FROM public.departments 
WHERE name = 'TEST_EXISTING_DEPT';

-- parent_id を更新（NULL → 値あり）
DO $$
DECLARE
    new_parent_id INT;
BEGIN
    SELECT department_id INTO new_parent_id FROM public.departments WHERE name = 'TEST_DEPT_WITH_PARENT';
    CALL public.usp_upsert_department('TEST_EXISTING_DEPT', new_parent_id);
END $$;

-- 実行後の確認
SELECT 
    name, 
    parent_id AS parent_id_after,
    CASE WHEN parent_id = (SELECT department_id FROM public.departments WHERE name = 'TEST_DEPT_WITH_PARENT') 
         THEN 'UPDATED' ELSE 'NOT_UPDATED' END AS update_status
FROM public.departments 
WHERE name = 'TEST_EXISTING_DEPT';

-- 件数が増えていないことを確認（UPDATE であって INSERT ではない）
SELECT COUNT(*) AS count_should_be_1
FROM public.departments 
WHERE name = 'TEST_EXISTING_DEPT';

-- ============================================================================
-- Test Case 4: 境界値 - parent_id が NULL（デフォルト値）
-- ============================================================================
SELECT '=== Test Case 4: Boundary - NULL parent_id (default) ===' AS test_case;

-- parent_id パラメータを省略（デフォルト NULL）
CALL public.usp_upsert_department('TEST_NULL_PARENT');

SELECT name, parent_id, 
       CASE WHEN parent_id IS NULL THEN 'NULL' ELSE 'NOT_NULL' END AS parent_id_status
FROM public.departments 
WHERE name = 'TEST_NULL_PARENT';

-- ============================================================================
-- Test Case 5: 境界値 - 最小長の name（1文字）
-- ============================================================================
SELECT '=== Test Case 5: Boundary - Minimum Length Name ===' AS test_case;

CALL public.usp_upsert_department('T', NULL);

SELECT name, LENGTH(name) AS name_length
FROM public.departments 
WHERE name = 'T';

-- ============================================================================
-- Test Case 6: 境界値 - 最大長に近い name（100文字）
-- ============================================================================
SELECT '=== Test Case 6: Boundary - Maximum Length Name ===' AS test_case;

DO $$
DECLARE
    long_name TEXT;
BEGIN
    long_name := REPEAT('A', 100);
    CALL public.usp_upsert_department(long_name, NULL);
END $$;

SELECT name, LENGTH(name) AS name_length
FROM public.departments 
WHERE name = REPEAT('A', 100);

-- ============================================================================
-- Test Case 7: 境界値 - 既存レコードの parent_id を NULL に更新
-- ============================================================================
SELECT '=== Test Case 7: Boundary - Update parent_id to NULL ===' AS test_case;

-- 実行前の状態
SELECT name, parent_id AS parent_id_before
FROM public.departments 
WHERE name = 'TEST_DEPT_WITH_PARENT';

-- parent_id を NULL に更新
CALL public.usp_upsert_department('TEST_DEPT_WITH_PARENT', NULL);

-- 実行後の確認
SELECT name, parent_id AS parent_id_after,
       CASE WHEN parent_id IS NULL THEN 'UPDATED_TO_NULL' ELSE 'STILL_HAS_VALUE' END AS update_status
FROM public.departments 
WHERE name = 'TEST_DEPT_WITH_PARENT';

-- ============================================================================
-- Test Case 8: 例外系 - NULL name（必須パラメータ）
-- ============================================================================
SELECT '=== Test Case 8: Exception - NULL name ===' AS test_case;

DO $$
BEGIN
    BEGIN
        CALL public.usp_upsert_department(NULL, NULL);
        RAISE NOTICE 'error_status: NO_ERROR';
        RAISE NOTICE 'error_message: ';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'error_status: ERROR_OCCURRED';
        RAISE NOTICE 'error_message: %', SQLERRM;
        RAISE NOTICE 'error_code: %', SQLSTATE;
    END;
END $$;

-- ============================================================================
-- Test Case 9: 例外系 - name が最大長を超える（101文字）
-- ============================================================================
SELECT '=== Test Case 9: Exception - Name Too Long ===' AS test_case;

DO $$
DECLARE
    too_long_name TEXT;
BEGIN
    too_long_name := REPEAT('B', 101);
    
    BEGIN
        CALL public.usp_upsert_department(too_long_name, NULL);
        RAISE NOTICE 'error_status: NO_ERROR';
        RAISE NOTICE 'error_message: ';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'error_status: ERROR_OCCURRED';
        RAISE NOTICE 'error_message: %', SQLERRM;
        RAISE NOTICE 'error_code: %', SQLSTATE;
    END;
END $$;

-- ============================================================================
-- Test Case 10: 副作用 - 複数回実行時の冪等性確認
-- ============================================================================
SELECT '=== Test Case 10: Side Effect - Idempotency ===' AS test_case;

-- 同じパラメータで3回実行
CALL public.usp_upsert_department('TEST_IDEMPOTENT', NULL);
CALL public.usp_upsert_department('TEST_IDEMPOTENT', NULL);
CALL public.usp_upsert_department('TEST_IDEMPOTENT', NULL);

-- 件数は1件のみであることを確認
SELECT COUNT(*) AS count_should_be_1
FROM public.departments 
WHERE name = 'TEST_IDEMPOTENT';

-- ============================================================================
-- Test Case 11: 副作用 - MERGE による INSERT/UPDATE の動作確認
-- ============================================================================
SELECT '=== Test Case 11: Side Effect - MERGE Behavior ===' AS test_case;

-- 新規挿入
CALL public.usp_upsert_department('TEST_MERGE_BEHAVIOR', 1);

SELECT 'AFTER_INSERT' AS stage, name, parent_id
FROM public.departments 
WHERE name = 'TEST_MERGE_BEHAVIOR';

-- 更新
CALL public.usp_upsert_department('TEST_MERGE_BEHAVIOR', 2);

SELECT 'AFTER_UPDATE' AS stage, name, parent_id
FROM public.departments 
WHERE name = 'TEST_MERGE_BEHAVIOR';

-- parent_id が 2 に更新されていることを確認
SELECT 
    CASE WHEN parent_id = 2 THEN 'MERGE_UPDATE_SUCCESS' ELSE 'MERGE_UPDATE_FAILED' END AS merge_status
FROM public.departments 
WHERE name = 'TEST_MERGE_BEHAVIOR';

-- ============================================================================
-- Test Case 12: トランザクション - ロールバック動作
-- ============================================================================
SELECT '=== Test Case 12: Transaction - Rollback Behavior ===' AS test_case;

-- ネストしたトランザクションで確認
DO $$
DECLARE
    savepoint_count INT;
    count_after_insert INT;
    count_after_rollback INT;
BEGIN
    SELECT COUNT(*) INTO savepoint_count FROM public.departments WHERE name = 'TEST_ROLLBACK';
    
    SAVEPOINT savepoint1;
    
    CALL public.usp_upsert_department('TEST_ROLLBACK', NULL);
    
    SELECT COUNT(*) INTO count_after_insert FROM public.departments WHERE name = 'TEST_ROLLBACK';
    RAISE NOTICE 'count_after_insert: %', count_after_insert;
    
    ROLLBACK TO SAVEPOINT savepoint1;
    
    SELECT COUNT(*) INTO count_after_rollback FROM public.departments WHERE name = 'TEST_ROLLBACK';
    RAISE NOTICE 'count_after_rollback: %', count_after_rollback;
END $$;

-- ============================================================================
-- CLEANUP: テストデータのクリーンアップ
-- ============================================================================
SELECT '=== CLEANUP ===' AS cleanup_status;

-- トランザクションをロールバックして元の状態に戻す
ROLLBACK;

SELECT 'All tests completed and rolled back' AS final_status;
