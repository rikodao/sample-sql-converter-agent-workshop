-- ============================================================================
-- export-ddl.sql
-- Source RDS for SQL Server から DDL を抽出する SQL。
-- 1ファイル1オブジェクトで保存する想定で、scripts/export-ddl.sh から呼ばれる。
-- ============================================================================

-- 1. オブジェクト一覧 (type, schema, name, definition)
SELECT
    o.type_desc                                AS object_type,
    SCHEMA_NAME(o.schema_id)                   AS schema_name,
    o.name                                     AS object_name,
    LEN(ISNULL(m.definition, ''))              AS definition_length,
    CONVERT(NVARCHAR(MAX), m.definition)       AS definition
FROM sys.sql_modules m
RIGHT JOIN sys.objects o ON m.object_id = o.object_id
WHERE o.type IN ('P', 'FN', 'IF', 'TF', 'FS', 'FT', 'TR', 'V')
  AND o.is_ms_shipped = 0
ORDER BY object_type, schema_name, object_name;

-- 2. 依存関係
SELECT
    SCHEMA_NAME(o1.schema_id) + '.' + o1.name  AS referencing_object,
    o1.type_desc                                AS referencing_type,
    d.referenced_schema_name                    AS referenced_schema,
    d.referenced_entity_name                    AS referenced_object,
    o2.type_desc                                AS referenced_type
FROM sys.sql_expression_dependencies d
INNER JOIN sys.objects o1 ON d.referencing_id = o1.object_id
LEFT JOIN sys.objects o2 ON d.referenced_id = o2.object_id;

-- 3. テーブル列メタデータ
SELECT
    SCHEMA_NAME(t.schema_id)                   AS schema_name,
    t.name                                     AS table_name,
    c.name                                     AS column_name,
    ty.name                                    AS data_type,
    c.max_length, c.precision, c.scale, c.is_nullable, c.is_identity
FROM sys.tables t
INNER JOIN sys.columns c ON t.object_id = c.object_id
INNER JOIN sys.types ty ON c.user_type_id = ty.user_type_id
ORDER BY schema_name, table_name, c.column_id;
