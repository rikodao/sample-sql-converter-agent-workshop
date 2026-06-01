-- ============================================================================
-- Test Suite for dbo.usp_recursive_org_chart
-- ============================================================================
-- このテストスイートは再帰CTEを使用した組織階層取得プロシージャを検証します
-- 既存のdepartmentsデータを使用してテストを実行します
-- ============================================================================

-- ============================================================================
-- SETUP: 現在のデータ構造確認
-- ============================================================================

PRINT '=== Current departments data ===';
SELECT department_id, name, parent_id, created_at 
FROM dbo.departments 
ORDER BY department_id;

-- ============================================================================
-- EXEC & ASSERT: テストケース実行
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Test Case 1: 正常系 - 複数階層のツリー全体を取得 (Engineering部門)
-- ----------------------------------------------------------------------------
PRINT '';
PRINT '=== Test Case 1: 正常系 - 複数階層のツリー全体を取得 (Engineering) ===';
EXEC dbo.usp_recursive_org_chart @root_id = 1;

-- Expected: Engineering (depth=0), Backend (depth=1), Frontend (depth=1), 
--           TEST_MERGE_BEHAVIOR (depth=2)

-- ----------------------------------------------------------------------------
-- Test Case 2: 正常系 - 中間ノードから開始 (Backend部門)
-- ----------------------------------------------------------------------------
PRINT '';
PRINT '=== Test Case 2: 正常系 - 中間ノードから開始 (Backend) ===';
EXEC dbo.usp_recursive_org_chart @root_id = 2;

-- Expected: Backend (depth=0), TEST_MERGE_BEHAVIOR (depth=1)

-- ----------------------------------------------------------------------------
-- Test Case 3: 正常系 - リーフノード (Frontend部門 - 子なし)
-- ----------------------------------------------------------------------------
PRINT '';
PRINT '=== Test Case 3: 正常系 - リーフノード (Frontend - 子なし) ===';
EXEC dbo.usp_recursive_org_chart @root_id = 3;

-- Expected: Frontend (depth=0) のみ

-- ----------------------------------------------------------------------------
-- Test Case 4: 正常系 - 別のルートツリー (Sales部門)
-- ----------------------------------------------------------------------------
PRINT '';
PRINT '=== Test Case 4: 正常系 - 別のルートツリー (Sales) ===';
EXEC dbo.usp_recursive_org_chart @root_id = 4;

-- Expected: Sales (depth=0) のみ

-- ----------------------------------------------------------------------------
-- Test Case 5: 境界値 - 存在しないID
-- ----------------------------------------------------------------------------
PRINT '';
PRINT '=== Test Case 5: 境界値 - 存在しないID (9999) ===';
EXEC dbo.usp_recursive_org_chart @root_id = 9999;

-- Expected: 空の結果セット (0行)

-- ----------------------------------------------------------------------------
-- Test Case 6: 境界値 - 負のID
-- ----------------------------------------------------------------------------
PRINT '';
PRINT '=== Test Case 6: 境界値 - 負のID (-1) ===';
EXEC dbo.usp_recursive_org_chart @root_id = -1;

-- Expected: 空の結果セット (0行)

-- ----------------------------------------------------------------------------
-- Test Case 7: 境界値 - ゼロID
-- ----------------------------------------------------------------------------
PRINT '';
PRINT '=== Test Case 7: 境界値 - ゼロID (0) ===';
EXEC dbo.usp_recursive_org_chart @root_id = 0;

-- Expected: 空の結果セット (0行)

-- ----------------------------------------------------------------------------
-- Test Case 8: 例外系 - NULL入力
-- ----------------------------------------------------------------------------
PRINT '';
PRINT '=== Test Case 8: 例外系 - NULL入力 ===';
BEGIN TRY
    EXEC dbo.usp_recursive_org_chart @root_id = NULL;
    SELECT 'No error' AS result, 'NULL was accepted, returned 0 rows' AS message;
END TRY
BEGIN CATCH
    SELECT 'Error occurred' AS result, 
           ERROR_NUMBER() AS error_number,
           ERROR_MESSAGE() AS error_message;
END CATCH

-- Expected: 空の結果セット (WHERE department_id = NULL は常にFALSE)

-- ----------------------------------------------------------------------------
-- Test Case 9: 例外系 - 循環参照
-- ----------------------------------------------------------------------------
PRINT '';
PRINT '=== Test Case 9: 例外系 - 循環参照 ===';

-- 循環参照データの追加
SET IDENTITY_INSERT dbo.departments ON;
INSERT INTO dbo.departments (department_id, name, parent_id, created_at)
VALUES 
    (100, N'部門A', 101, '2024-01-10'),
    (101, N'部門B', 100, '2024-01-11');
SET IDENTITY_INSERT dbo.departments OFF;

BEGIN TRY
    EXEC dbo.usp_recursive_org_chart @root_id = 100;
    SELECT 'No error' AS result, 'Circular reference was processed without error' AS message;
END TRY
BEGIN CATCH
    SELECT 'Error occurred (expected)' AS result, 
           ERROR_NUMBER() AS error_number,
           ERROR_MESSAGE() AS error_message;
END CATCH

-- Expected: エラー 530 (最大再帰回数に達した) または処理完了

-- 循環参照データの削除
DELETE FROM dbo.departments WHERE department_id IN (100, 101);

-- ----------------------------------------------------------------------------
-- Test Case 10: パス生成の検証 (特殊文字を含む名前)
-- ----------------------------------------------------------------------------
PRINT '';
PRINT '=== Test Case 10: パス生成の検証 (特殊文字) ===';

SET IDENTITY_INSERT dbo.departments ON;
INSERT INTO dbo.departments (department_id, name, parent_id, created_at)
VALUES 
    (200, N'特殊>文字<部門', 1, '2024-01-12'),
    (201, N'子部門', 200, '2024-01-13');
SET IDENTITY_INSERT dbo.departments OFF;

EXEC dbo.usp_recursive_org_chart @root_id = 200;

-- Expected: 
--   200, '特殊>文字<部門', 0, '特殊>文字<部門'
--   201, '子部門', 1, '特殊>文字<部門 > 子部門'

DELETE FROM dbo.departments WHERE department_id IN (200, 201);

-- ----------------------------------------------------------------------------
-- Test Case 11: 深い階層のリーフノードから開始
-- ----------------------------------------------------------------------------
PRINT '';
PRINT '=== Test Case 11: 深い階層のリーフノードから開始 (TEST_MERGE_BEHAVIOR) ===';
EXEC dbo.usp_recursive_org_chart @root_id = 19;

-- Expected: TEST_MERGE_BEHAVIOR (depth=0) のみ

-- ----------------------------------------------------------------------------
-- Test Case 12: 長い名前を持つ部門でのパス生成
-- ----------------------------------------------------------------------------
PRINT '';
PRINT '=== Test Case 12: 長い名前を持つ部門でのパス生成 ===';

SET IDENTITY_INSERT dbo.departments ON;
INSERT INTO dbo.departments (department_id, name, parent_id, created_at)
VALUES 
    (300, N'非常に長い部門名を持つ部門AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA', 1, '2024-01-14'),
    (301, N'その子部門BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB', 300, '2024-01-15'),
    (302, N'さらにその子部門CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC', 301, '2024-01-16');
SET IDENTITY_INSERT dbo.departments OFF;

EXEC dbo.usp_recursive_org_chart @root_id = 300;

-- Expected: NVARCHAR(MAX)なので長いパスでも問題なく連結される

DELETE FROM dbo.departments WHERE department_id IN (300, 301, 302);

-- ============================================================================
-- CLEANUP: 確認
-- ============================================================================

PRINT '';
PRINT '=== CLEANUP: Final data check ===';
SELECT COUNT(*) AS final_count FROM dbo.departments;

PRINT '';
PRINT '=== Test Suite Completed ===';
