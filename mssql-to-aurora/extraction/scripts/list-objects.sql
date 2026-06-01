-- ============================================================================
-- list-objects.sql
-- Source RDS for SQL Server から、object_list.ini 生成用に必要な最小情報
-- (type_desc, schema, name, is_encrypted) のみ取得する軽量 SQL。
--
-- 完全な DDL 抽出 (definition 含む) は export-ddl.sql を使用。
-- このファイルは scripts/export-ddl.sh から呼ばれる。
-- ============================================================================

SET NOCOUNT ON;

SELECT
    o.type_desc                                              AS object_type,
    SCHEMA_NAME(o.schema_id)                                 AS schema_name,
    o.name                                                   AS object_name,
    -- WITH ENCRYPTION で保護されているか (定義取得不可 = AI 変換不能)
    CASE
        WHEN m.definition IS NULL AND o.type IN ('P','FN','IF','TF','FS','FT','TR','V')
            THEN 1 ELSE 0
    END                                                      AS is_encrypted_or_unavailable
FROM sys.objects o
LEFT JOIN sys.sql_modules m ON m.object_id = o.object_id
WHERE
    o.is_ms_shipped = 0
    AND o.type IN (
        'P',   -- SQL_STORED_PROCEDURE
        'FN',  -- SQL_SCALAR_FUNCTION
        'IF',  -- SQL_INLINE_TABLE_VALUED_FUNCTION
        'TF',  -- SQL_TABLE_VALUED_FUNCTION
        'FS',  -- CLR_SCALAR_FUNCTION (AI 変換非対応、警告対象)
        'FT',  -- CLR_TABLE_VALUED_FUNCTION (AI 変換非対応、警告対象)
        'TR',  -- SQL_TRIGGER
        'V'    -- VIEW
    )
ORDER BY object_type, schema_name, object_name;
