-- ============================================================================
-- Test Suite for dbo.fn_format_employee_name
-- ============================================================================
-- 対象: SQL Scalar Function
-- 機能: 姓名を "姓, 名" 形式にフォーマット
-- ============================================================================

-- ============================================================================
-- SETUP: テストデータ準備
-- ============================================================================
-- この関数は純粋関数のため、セットアップ不要

-- ============================================================================
-- Test Case 1: 正常系 - 通常の姓名
-- ============================================================================
SELECT 
    'Test Case 1' AS test_case,
    'Normal names' AS description,
    dbo.fn_format_employee_name(N'John', N'Smith') AS result,
    N'Smith, John' AS expected;

-- ============================================================================
-- Test Case 2: 正常系 - 日本語の姓名
-- ============================================================================
SELECT 
    'Test Case 2' AS test_case,
    'Japanese names' AS description,
    dbo.fn_format_employee_name(N'太郎', N'山田') AS result,
    N'山田, 太郎' AS expected;

-- ============================================================================
-- Test Case 3: 正常系 - 長い名前
-- ============================================================================
SELECT 
    'Test Case 3' AS test_case,
    'Long names' AS description,
    dbo.fn_format_employee_name(
        N'Christopher Alexander', 
        N'Montgomery-Wellington'
    ) AS result,
    N'Montgomery-Wellington, Christopher Alexander' AS expected;

-- ============================================================================
-- Test Case 4: 境界値 - 空文字列 (first)
-- ============================================================================
SELECT 
    'Test Case 4' AS test_case,
    'Empty string first name' AS description,
    dbo.fn_format_employee_name(N'', N'Smith') AS result,
    N'Smith, ' AS expected;

-- ============================================================================
-- Test Case 5: 境界値 - 空文字列 (last)
-- ============================================================================
SELECT 
    'Test Case 5' AS test_case,
    'Empty string last name' AS description,
    dbo.fn_format_employee_name(N'John', N'') AS result,
    N', John' AS expected;

-- ============================================================================
-- Test Case 6: 境界値 - 両方空文字列
-- ============================================================================
SELECT 
    'Test Case 6' AS test_case,
    'Both empty strings' AS description,
    dbo.fn_format_employee_name(N'', N'') AS result,
    N', ' AS expected;

-- ============================================================================
-- Test Case 7: 境界値 - NULL (first)
-- ============================================================================
SELECT 
    'Test Case 7' AS test_case,
    'NULL first name' AS description,
    dbo.fn_format_employee_name(NULL, N'Smith') AS result,
    N'(unknown)' AS expected;

-- ============================================================================
-- Test Case 8: 境界値 - NULL (last)
-- ============================================================================
SELECT 
    'Test Case 8' AS test_case,
    'NULL last name' AS description,
    dbo.fn_format_employee_name(N'John', NULL) AS result,
    N'(unknown)' AS expected;

-- ============================================================================
-- Test Case 9: 境界値 - 両方NULL
-- ============================================================================
SELECT 
    'Test Case 9' AS test_case,
    'Both NULL' AS description,
    dbo.fn_format_employee_name(NULL, NULL) AS result,
    N'(unknown)' AS expected;

-- ============================================================================
-- Test Case 10: 境界値 - 単一文字
-- ============================================================================
SELECT 
    'Test Case 10' AS test_case,
    'Single character names' AS description,
    dbo.fn_format_employee_name(N'A', N'B') AS result,
    N'B, A' AS expected;

-- ============================================================================
-- Test Case 11: 境界値 - 最大長 (50文字)
-- ============================================================================
SELECT 
    'Test Case 11' AS test_case,
    'Maximum length names (50 chars each)' AS description,
    dbo.fn_format_employee_name(
        REPLICATE(N'A', 50), 
        REPLICATE(N'B', 50)
    ) AS result,
    LEN(dbo.fn_format_employee_name(REPLICATE(N'A', 50), REPLICATE(N'B', 50))) AS result_length,
    102 AS expected_length;

-- ============================================================================
-- Test Case 12: 正常系 - 特殊文字を含む名前
-- ============================================================================
SELECT 
    'Test Case 12' AS test_case,
    'Names with special characters' AS description,
    dbo.fn_format_employee_name(N'Mary-Jane', N'O''Connor') AS result,
    N'O''Connor, Mary-Jane' AS expected;

-- ============================================================================
-- Test Case 13: 正常系 - スペースを含む名前
-- ============================================================================
SELECT 
    'Test Case 13' AS test_case,
    'Names with spaces' AS description,
    dbo.fn_format_employee_name(N'Jean Paul', N'De La Cruz') AS result,
    N'De La Cruz, Jean Paul' AS expected;

-- ============================================================================
-- Test Case 14: 境界値 - 先頭・末尾スペース
-- ============================================================================
SELECT 
    'Test Case 14' AS test_case,
    'Names with leading/trailing spaces' AS description,
    dbo.fn_format_employee_name(N' John ', N' Smith ') AS result,
    N' Smith ,  John ' AS expected;

-- ============================================================================
-- Test Case 15: 正常系 - 数字を含む名前
-- ============================================================================
SELECT 
    'Test Case 15' AS test_case,
    'Names with numbers' AS description,
    dbo.fn_format_employee_name(N'John2', N'Smith3') AS result,
    N'Smith3, John2' AS expected;

-- ============================================================================
-- CLEANUP: 後処理
-- ============================================================================
-- この関数は副作用がないため、クリーンアップ不要
