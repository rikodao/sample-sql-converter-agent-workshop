-- ============================================
-- Test Suite for dbo.fn_get_fiscal_year
-- ============================================
-- 対象: 4月始まりの会計年度計算関数
-- 入力: DATE型
-- 出力: INT型 (会計年度)
-- ============================================

-- ============================================
-- SETUP: テストデータ準備
-- ============================================
-- 一時テーブルでテストケースを管理
IF OBJECT_ID('tempdb..#test_cases') IS NOT NULL DROP TABLE #test_cases;
CREATE TABLE #test_cases (
    test_id INT PRIMARY KEY,
    test_name NVARCHAR(100),
    input_date DATE,
    expected_result INT,
    category NVARCHAR(50)
);

-- ============================================
-- Test Case 1: 正常系 - 4月以降の日付
-- ============================================
INSERT INTO #test_cases VALUES (1, '年度開始日 (4月1日)', '2023-04-01', 2023, '正常系');
INSERT INTO #test_cases VALUES (2, '年度中間 (8月15日)', '2023-08-15', 2023, '正常系');
INSERT INTO #test_cases VALUES (3, '年度末日 (3月31日)', '2024-03-31', 2023, '正常系');

-- ============================================
-- Test Case 2: 正常系 - 1-3月の日付
-- ============================================
INSERT INTO #test_cases VALUES (4, '1月の日付', '2023-01-15', 2022, '正常系');
INSERT INTO #test_cases VALUES (5, '2月の日付', '2023-02-28', 2022, '正常系');
INSERT INTO #test_cases VALUES (6, '3月の日付', '2023-03-31', 2022, '正常系');

-- ============================================
-- Test Case 3: 境界値 - 月の境界
-- ============================================
INSERT INTO #test_cases VALUES (7, '3月最終日 (境界)', '2023-03-31', 2022, '境界値');
INSERT INTO #test_cases VALUES (8, '4月初日 (境界)', '2023-04-01', 2023, '境界値');
INSERT INTO #test_cases VALUES (9, '12月最終日', '2023-12-31', 2023, '境界値');

-- ============================================
-- Test Case 4: 境界値 - 年の境界
-- ============================================
INSERT INTO #test_cases VALUES (10, '年初 (1月1日)', '2023-01-01', 2022, '境界値');
INSERT INTO #test_cases VALUES (11, '年末 (12月31日)', '2023-12-31', 2023, '境界値');

-- ============================================
-- Test Case 5: 境界値 - 閏年
-- ============================================
INSERT INTO #test_cases VALUES (12, '閏年2月29日', '2024-02-29', 2023, '境界値');
INSERT INTO #test_cases VALUES (13, '閏年3月31日', '2024-03-31', 2023, '境界値');
INSERT INTO #test_cases VALUES (14, '閏年4月1日', '2024-04-01', 2024, '境界値');

-- ============================================
-- Test Case 6: 境界値 - 過去・未来の日付
-- ============================================
INSERT INTO #test_cases VALUES (15, '過去の日付 (1990年)', '1990-06-15', 1990, '境界値');
INSERT INTO #test_cases VALUES (16, '未来の日付 (2050年)', '2050-11-20', 2050, '境界値');
INSERT INTO #test_cases VALUES (17, '最小日付付近', '1753-04-01', 1753, '境界値');

-- ============================================
-- Test Case 7: 例外系 - NULL入力
-- ============================================
-- NULL入力のテスト用
IF OBJECT_ID('tempdb..#null_test') IS NOT NULL DROP TABLE #null_test;
CREATE TABLE #null_test (
    test_id INT,
    test_name NVARCHAR(100),
    result INT,
    error_message NVARCHAR(500)
);

-- ============================================
-- EXEC: 関数実行
-- ============================================

-- 正常系・境界値テストの実行
IF OBJECT_ID('tempdb..#test_results') IS NOT NULL DROP TABLE #test_results;
CREATE TABLE #test_results (
    test_id INT,
    test_name NVARCHAR(100),
    input_date DATE,
    expected_result INT,
    actual_result INT,
    category NVARCHAR(50),
    status NVARCHAR(20)
);

INSERT INTO #test_results
SELECT 
    test_id,
    test_name,
    input_date,
    expected_result,
    dbo.fn_get_fiscal_year(input_date) AS actual_result,
    category,
    CASE 
        WHEN dbo.fn_get_fiscal_year(input_date) = expected_result THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM #test_cases;

-- NULL入力テスト
BEGIN TRY
    INSERT INTO #null_test
    SELECT 
        18,
        'NULL入力',
        dbo.fn_get_fiscal_year(NULL),
        NULL;
END TRY
BEGIN CATCH
    INSERT INTO #null_test
    SELECT 
        18,
        'NULL入力',
        NULL,
        ERROR_MESSAGE();
END CATCH;

-- ============================================
-- ASSERT: 結果検証
-- ============================================

-- 全テストケースの結果
SELECT 
    test_id,
    test_name,
    CONVERT(VARCHAR(10), input_date, 120) AS input_date,
    expected_result,
    actual_result,
    category,
    status
FROM #test_results
ORDER BY test_id;

-- サマリー
SELECT 
    category,
    COUNT(*) AS total_tests,
    SUM(CASE WHEN status = 'PASS' THEN 1 ELSE 0 END) AS passed,
    SUM(CASE WHEN status = 'FAIL' THEN 1 ELSE 0 END) AS failed
FROM #test_results
GROUP BY category
ORDER BY category;

-- NULL入力の結果
SELECT 
    test_id,
    test_name,
    result,
    error_message
FROM #null_test;

-- 失敗したテストの詳細
SELECT 
    test_id,
    test_name,
    CONVERT(VARCHAR(10), input_date, 120) AS input_date,
    expected_result,
    actual_result,
    category
FROM #test_results
WHERE status = 'FAIL';

-- ============================================
-- CLEANUP: 一時テーブル削除
-- ============================================
DROP TABLE #test_cases;
DROP TABLE #test_results;
DROP TABLE #null_test;
