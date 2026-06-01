-- ============================================================================
-- テストケース: dbo.fn_split_csv
-- ============================================================================
-- 対象: CSV文字列分割テーブル値関数
-- 戦略: 正常系、境界値、例外系、特殊文字を網羅的にテスト
-- ============================================================================

-- ============================================================================
-- SETUP: テストデータ準備
-- ============================================================================
-- 一時テーブルは不要 (関数は副作用なし)

PRINT '=== SETUP COMPLETE ===';
GO

-- ============================================================================
-- TEST CASE 1: 正常系 - 基本的なカンマ区切り文字列
-- ============================================================================
PRINT '=== TEST CASE 1: Basic comma-separated string ===';
SELECT idx, value 
FROM dbo.fn_split_csv('apple,banana,cherry', ',')
ORDER BY idx;
GO

-- ============================================================================
-- TEST CASE 2: 正常系 - セミコロン区切り
-- ============================================================================
PRINT '=== TEST CASE 2: Semicolon separator ===';
SELECT idx, value 
FROM dbo.fn_split_csv('red;green;blue;yellow', ';')
ORDER BY idx;
GO

-- ============================================================================
-- TEST CASE 3: 正常系 - パイプ区切り
-- ============================================================================
PRINT '=== TEST CASE 3: Pipe separator ===';
SELECT idx, value 
FROM dbo.fn_split_csv('one|two|three', '|')
ORDER BY idx;
GO

-- ============================================================================
-- TEST CASE 4: 境界値 - 単一要素 (区切り文字なし)
-- ============================================================================
PRINT '=== TEST CASE 4: Single element (no separator) ===';
SELECT idx, value 
FROM dbo.fn_split_csv('single', ',')
ORDER BY idx;
GO

-- ============================================================================
-- TEST CASE 5: 境界値 - 空文字列
-- ============================================================================
PRINT '=== TEST CASE 5: Empty string ===';
SELECT COUNT(*) AS result_count
FROM dbo.fn_split_csv('', ',');
GO

-- ============================================================================
-- TEST CASE 6: 境界値 - NULL入力
-- ============================================================================
PRINT '=== TEST CASE 6: NULL input ===';
SELECT COUNT(*) AS result_count
FROM dbo.fn_split_csv(NULL, ',');
GO

-- ============================================================================
-- TEST CASE 7: 境界値 - 空要素を含む (連続区切り文字)
-- ============================================================================
PRINT '=== TEST CASE 7: Empty elements (consecutive separators) ===';
SELECT idx, value, LEN(value) AS value_length
FROM dbo.fn_split_csv('a,,b,,,c', ',')
ORDER BY idx;
GO

-- ============================================================================
-- TEST CASE 8: 境界値 - 先頭が区切り文字
-- ============================================================================
PRINT '=== TEST CASE 8: Leading separator ===';
SELECT idx, value, LEN(value) AS value_length
FROM dbo.fn_split_csv(',first,second', ',')
ORDER BY idx;
GO

-- ============================================================================
-- TEST CASE 9: 境界値 - 末尾が区切り文字
-- ============================================================================
PRINT '=== TEST CASE 9: Trailing separator ===';
SELECT idx, value, LEN(value) AS value_length
FROM dbo.fn_split_csv('first,second,', ',')
ORDER BY idx;
GO

-- ============================================================================
-- TEST CASE 10: 境界値 - 区切り文字のみ
-- ============================================================================
PRINT '=== TEST CASE 10: Only separators ===';
SELECT idx, value, LEN(value) AS value_length
FROM dbo.fn_split_csv(',,,', ',')
ORDER BY idx;
GO

-- ============================================================================
-- TEST CASE 11: 境界値 - 長い文字列 (多数の要素)
-- ============================================================================
PRINT '=== TEST CASE 11: Long string with many elements ===';
SELECT COUNT(*) AS element_count, 
       MIN(idx) AS min_idx, 
       MAX(idx) AS max_idx
FROM dbo.fn_split_csv('1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20', ',');
GO

-- ============================================================================
-- TEST CASE 12: 境界値 - 長い個別要素
-- ============================================================================
PRINT '=== TEST CASE 12: Long individual elements ===';
SELECT idx, LEN(value) AS value_length, LEFT(value, 20) AS value_preview
FROM dbo.fn_split_csv(REPLICATE('A', 150) + ',' + REPLICATE('B', 180) + ',' + REPLICATE('C', 200), ',')
ORDER BY idx;
GO

-- ============================================================================
-- TEST CASE 13: 例外系 - 区切り文字が文字列に存在しない
-- ============================================================================
PRINT '=== TEST CASE 13: Separator not in string ===';
SELECT idx, value 
FROM dbo.fn_split_csv('no-separator-here', ',')
ORDER BY idx;
GO

-- ============================================================================
-- TEST CASE 14: 例外系 - 特殊文字を含む要素
-- ============================================================================
PRINT '=== TEST CASE 14: Special characters in elements ===';
SELECT idx, value 
FROM dbo.fn_split_csv('hello world,tab	here,newline
here', ',')
ORDER BY idx;
GO

-- ============================================================================
-- TEST CASE 15: 正常系 - スペース区切り
-- ============================================================================
PRINT '=== TEST CASE 15: Space separator ===';
SELECT idx, value, LEN(value) AS value_length
FROM dbo.fn_split_csv('word1 word2 word3', ' ')
ORDER BY idx;
GO

-- ============================================================================
-- TEST CASE 16: 境界値 - 数値文字列
-- ============================================================================
PRINT '=== TEST CASE 16: Numeric strings ===';
SELECT idx, value, 
       CASE WHEN ISNUMERIC(value) = 1 THEN 'numeric' ELSE 'non-numeric' END AS is_numeric
FROM dbo.fn_split_csv('123,456.78,-999,0,abc', ',')
ORDER BY idx;
GO

-- ============================================================================
-- TEST CASE 17: 境界値 - Unicode文字
-- ============================================================================
PRINT '=== TEST CASE 17: Unicode characters ===';
SELECT idx, value 
FROM dbo.fn_split_csv(N'日本語,한국어,中文,English', ',')
ORDER BY idx;
GO

-- ============================================================================
-- TEST CASE 18: 境界値 - 引用符を含む要素
-- ============================================================================
PRINT '=== TEST CASE 18: Elements with quotes ===';
SELECT idx, value 
FROM dbo.fn_split_csv('normal,"quoted value",''single quoted''', ',')
ORDER BY idx;
GO

-- ============================================================================
-- CLEANUP: 後処理
-- ============================================================================
-- 副作用なし、クリーンアップ不要

PRINT '=== ALL TESTS COMPLETE ===';
GO
