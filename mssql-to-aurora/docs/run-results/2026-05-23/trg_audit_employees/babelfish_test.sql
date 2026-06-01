-- ========================================
-- トリガーテストケース: dbo.trg_audit_employees (Babelfish)
-- ========================================
-- 対象: AFTER INSERT, UPDATE, DELETE トリガー
-- 親テーブル: dbo.employees
-- 監査テーブル: dbo.audit_log
-- ========================================

-- ========================================
-- SETUP: テストデータ準備
-- ========================================

-- 一時的な監査ログバックアップテーブル作成
IF OBJECT_ID('tempdb..#audit_log_backup') IS NOT NULL DROP TABLE #audit_log_backup;
CREATE TABLE #audit_log_backup (
    audit_id BIGINT,
    table_name NVARCHAR(100),
    operation NVARCHAR(10),
    primary_key INT,
    changed_at DATETIME2,
    changed_by NVARCHAR(100)
);

-- 既存の audit_log をバックアップ
INSERT INTO #audit_log_backup
SELECT * FROM dbo.audit_log WHERE table_name = 'employees';

-- テスト用の従業員データを削除（クリーンアップ）
SET IDENTITY_INSERT dbo.employees ON;
DELETE FROM dbo.employees WHERE employee_id >= 9000;
SET IDENTITY_INSERT dbo.employees OFF;
DELETE FROM dbo.audit_log WHERE table_name = 'employees' AND primary_key >= 9000;

-- テスト結果格納用テーブル
IF OBJECT_ID('tempdb..#test_results') IS NOT NULL DROP TABLE #test_results;
CREATE TABLE #test_results (
    test_case INT,
    description NVARCHAR(200),
    expected_operation NVARCHAR(10),
    actual_operation NVARCHAR(10),
    expected_count INT,
    actual_count INT,
    result NVARCHAR(10)
);


-- ========================================
-- Test Case 1: 単一行 INSERT
-- ========================================
-- 正常系: 1件の INSERT で audit_log に 'INSERT' レコードが1件追加される

DELETE FROM dbo.audit_log WHERE table_name = 'employees' AND primary_key = 9001;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES (9001, 1, N'Test', N'User1', '2024-01-01', 1, N'test1@example.com', GETDATE());
SET IDENTITY_INSERT dbo.employees OFF;

-- アサーション
INSERT INTO #test_results
SELECT 
    1 AS test_case,
    N'Single INSERT' AS description,
    'INSERT' AS expected_operation,
    operation AS actual_operation,
    1 AS expected_count,
    COUNT(*) AS actual_count,
    CASE WHEN operation = 'INSERT' AND COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END AS result
FROM dbo.audit_log
WHERE table_name = 'employees' AND primary_key = 9001
GROUP BY operation;


-- ========================================
-- Test Case 2: 複数行 INSERT
-- ========================================
-- 正常系: 3件の一括 INSERT で audit_log に 'INSERT' レコードが3件追加される

DELETE FROM dbo.audit_log WHERE table_name = 'employees' AND primary_key BETWEEN 9002 AND 9004;

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES 
    (9002, 1, N'Test', N'User2', '2024-01-02', 1, N'test2@example.com', GETDATE()),
    (9003, 2, N'Test', N'User3', '2024-01-03', 1, N'test3@example.com', GETDATE()),
    (9004, 3, N'Test', N'User4', '2024-01-04', 0, NULL, GETDATE());
SET IDENTITY_INSERT dbo.employees OFF;

-- アサーション
INSERT INTO #test_results
SELECT 
    2 AS test_case,
    N'Multiple INSERT (3 rows)' AS description,
    'INSERT' AS expected_operation,
    operation AS actual_operation,
    3 AS expected_count,
    COUNT(*) AS actual_count,
    CASE WHEN operation = 'INSERT' AND COUNT(*) = 3 THEN 'PASS' ELSE 'FAIL' END AS result
FROM dbo.audit_log
WHERE table_name = 'employees' AND primary_key BETWEEN 9002 AND 9004
GROUP BY operation;


-- ========================================
-- Test Case 3: 単一行 UPDATE
-- ========================================
-- 正常系: 1件の UPDATE で audit_log に 'UPDATE' レコードが1件追加される

DELETE FROM dbo.audit_log WHERE table_name = 'employees' AND primary_key = 9001 AND operation = 'UPDATE';

UPDATE dbo.employees
SET first_name = N'Updated'
WHERE employee_id = 9001;

-- アサーション
INSERT INTO #test_results
SELECT 
    3 AS test_case,
    N'Single UPDATE' AS description,
    'UPDATE' AS expected_operation,
    operation AS actual_operation,
    1 AS expected_count,
    COUNT(*) AS actual_count,
    CASE WHEN operation = 'UPDATE' AND COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END AS result
FROM dbo.audit_log
WHERE table_name = 'employees' AND primary_key = 9001 AND operation = 'UPDATE'
GROUP BY operation;


-- ========================================
-- Test Case 4: 複数行 UPDATE
-- ========================================
-- 正常系: 3件の一括 UPDATE で audit_log に 'UPDATE' レコードが3件追加される

DELETE FROM dbo.audit_log WHERE table_name = 'employees' AND primary_key BETWEEN 9002 AND 9004 AND operation = 'UPDATE';

UPDATE dbo.employees
SET is_active = 0
WHERE employee_id BETWEEN 9002 AND 9004;

-- アサーション
INSERT INTO #test_results
SELECT 
    4 AS test_case,
    N'Multiple UPDATE (3 rows)' AS description,
    'UPDATE' AS expected_operation,
    operation AS actual_operation,
    3 AS expected_count,
    COUNT(*) AS actual_count,
    CASE WHEN operation = 'UPDATE' AND COUNT(*) = 3 THEN 'PASS' ELSE 'FAIL' END AS result
FROM dbo.audit_log
WHERE table_name = 'employees' AND primary_key BETWEEN 9002 AND 9004 AND operation = 'UPDATE'
GROUP BY operation;


-- ========================================
-- Test Case 5: 単一行 DELETE
-- ========================================
-- 正常系: 1件の DELETE で audit_log に 'DELETE' レコードが1件追加される

DELETE FROM dbo.audit_log WHERE table_name = 'employees' AND primary_key = 9001 AND operation = 'DELETE';

SET IDENTITY_INSERT dbo.employees ON;
DELETE FROM dbo.employees WHERE employee_id = 9001;
SET IDENTITY_INSERT dbo.employees OFF;

-- アサーション
INSERT INTO #test_results
SELECT 
    5 AS test_case,
    N'Single DELETE' AS description,
    'DELETE' AS expected_operation,
    operation AS actual_operation,
    1 AS expected_count,
    COUNT(*) AS actual_count,
    CASE WHEN operation = 'DELETE' AND COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END AS result
FROM dbo.audit_log
WHERE table_name = 'employees' AND primary_key = 9001 AND operation = 'DELETE'
GROUP BY operation;


-- ========================================
-- Test Case 6: 複数行 DELETE
-- ========================================
-- 正常系: 3件の一括 DELETE で audit_log に 'DELETE' レコードが3件追加される

DELETE FROM dbo.audit_log WHERE table_name = 'employees' AND primary_key BETWEEN 9002 AND 9004 AND operation = 'DELETE';

SET IDENTITY_INSERT dbo.employees ON;
DELETE FROM dbo.employees WHERE employee_id BETWEEN 9002 AND 9004;
SET IDENTITY_INSERT dbo.employees OFF;

-- アサーション
INSERT INTO #test_results
SELECT 
    6 AS test_case,
    N'Multiple DELETE (3 rows)' AS description,
    'DELETE' AS expected_operation,
    operation AS actual_operation,
    3 AS expected_count,
    COUNT(*) AS actual_count,
    CASE WHEN operation = 'DELETE' AND COUNT(*) = 3 THEN 'PASS' ELSE 'FAIL' END AS result
FROM dbo.audit_log
WHERE table_name = 'employees' AND primary_key BETWEEN 9002 AND 9004 AND operation = 'DELETE'
GROUP BY operation;


-- ========================================
-- Test Case 7: トランザクションロールバック (INSERT)
-- ========================================
-- 境界値: トランザクションがロールバックされた場合、audit_log も巻き戻される

DELETE FROM dbo.audit_log WHERE table_name = 'employees' AND primary_key = 9010;

BEGIN TRANSACTION;
    SET IDENTITY_INSERT dbo.employees ON;
    INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
    VALUES (9010, 1, N'Rollback', N'Test', '2024-01-10', 1, N'rollback@example.com', GETDATE());
    SET IDENTITY_INSERT dbo.employees OFF;
ROLLBACK TRANSACTION;

-- アサーション: ロールバック後は audit_log にレコードが存在しないはず
INSERT INTO #test_results
SELECT 
    7 AS test_case,
    N'Transaction ROLLBACK (INSERT)' AS description,
    'NONE' AS expected_operation,
    'NONE' AS actual_operation,
    0 AS expected_count,
    COUNT(*) AS actual_count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM dbo.audit_log
WHERE table_name = 'employees' AND primary_key = 9010;


-- ========================================
-- Test Case 8: トランザクションコミット (UPDATE)
-- ========================================
-- 正常系: トランザクションがコミットされた場合、audit_log にレコードが残る

SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES (9011, 1, N'Commit', N'Test', '2024-01-11', 1, N'commit@example.com', GETDATE());
SET IDENTITY_INSERT dbo.employees OFF;

DELETE FROM dbo.audit_log WHERE table_name = 'employees' AND primary_key = 9011 AND operation = 'UPDATE';

BEGIN TRANSACTION;
    UPDATE dbo.employees SET first_name = N'Committed' WHERE employee_id = 9011;
COMMIT TRANSACTION;

-- アサーション
INSERT INTO #test_results
SELECT 
    8 AS test_case,
    N'Transaction COMMIT (UPDATE)' AS description,
    'UPDATE' AS expected_operation,
    operation AS actual_operation,
    1 AS expected_count,
    COUNT(*) AS actual_count,
    CASE WHEN operation = 'UPDATE' AND COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END AS result
FROM dbo.audit_log
WHERE table_name = 'employees' AND primary_key = 9011 AND operation = 'UPDATE'
GROUP BY operation;


-- ========================================
-- Test Case 9: UPDATE で0件該当
-- ========================================
-- 境界値: WHERE 条件に該当する行がない UPDATE では audit_log にレコードが追加されない

DELETE FROM dbo.audit_log WHERE table_name = 'employees' AND primary_key = 99999;

UPDATE dbo.employees
SET first_name = N'NoMatch'
WHERE employee_id = 99999;

-- アサーション
INSERT INTO #test_results
SELECT 
    9 AS test_case,
    N'UPDATE with 0 rows affected' AS description,
    'NONE' AS expected_operation,
    'NONE' AS actual_operation,
    0 AS expected_count,
    COUNT(*) AS actual_count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM dbo.audit_log
WHERE table_name = 'employees' AND primary_key = 99999;


-- ========================================
-- Test Case 10: DELETE で0件該当
-- ========================================
-- 境界値: WHERE 条件に該当する行がない DELETE では audit_log にレコードが追加されない

DELETE FROM dbo.audit_log WHERE table_name = 'employees' AND primary_key = 99998;

DELETE FROM dbo.employees WHERE employee_id = 99998;

-- アサーション
INSERT INTO #test_results
SELECT 
    10 AS test_case,
    N'DELETE with 0 rows affected' AS description,
    'NONE' AS expected_operation,
    'NONE' AS actual_operation,
    0 AS expected_count,
    COUNT(*) AS actual_count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM dbo.audit_log
WHERE table_name = 'employees' AND primary_key = 99998;


-- ========================================
-- ASSERT: テスト結果の出力
-- ========================================

SELECT 
    test_case,
    description,
    expected_operation,
    actual_operation,
    expected_count,
    actual_count,
    result
FROM #test_results
ORDER BY test_case;

-- サマリー
SELECT 
    COUNT(*) AS total_tests,
    SUM(CASE WHEN result = 'PASS' THEN 1 ELSE 0 END) AS passed,
    SUM(CASE WHEN result = 'FAIL' THEN 1 ELSE 0 END) AS failed
FROM #test_results;


-- ========================================
-- CLEANUP: テストデータとテーブルの削除
-- ========================================

-- テスト用従業員データ削除
SET IDENTITY_INSERT dbo.employees ON;
DELETE FROM dbo.employees WHERE employee_id >= 9000;
SET IDENTITY_INSERT dbo.employees OFF;

-- テスト用監査ログ削除
DELETE FROM dbo.audit_log WHERE table_name = 'employees' AND primary_key >= 9000;

-- 一時テーブル削除
DROP TABLE #test_results;
DROP TABLE #audit_log_backup;
