-- ============================================================================
-- list-queries.sql
-- Query Store から「過去に実際に実行された SQL」を集約形式で全量取得する。
-- 同一 query_hash (≒ 同じパラメタライズされたクエリパターン) でまとめ、
-- 実行回数・平均実行時間・初回/最終実行時刻を集計する。
--
-- 用途:
-- - 移行対象オブジェクトの実呼出頻度の把握 (実行ゼロ = 移行不要)
-- - アプリが投げる代表クエリの T-SQL 構文の Babelfish 互換評価
-- - パフォーマンスベースライン取得
--
-- 前提:
-- - SQL Server 2016 以降 (Query Store は SS2016 で導入)
-- - 対象 DB で Query Store が有効化されている
--   確認: SELECT name, is_query_store_on FROM sys.databases WHERE name='<dbname>';
-- - データは Snapshot に含まれるため本番への追加負荷ゼロ
--
-- 出力カラム:
-- - query_hash:        同じクエリパターンを示すハッシュ (パラメータ違いを統合)
-- - sample_text:       代表的な SQL テキスト (同 hash のうち先頭の 1 つ)
-- - object_name:       関連するストアド/関数等の name (アドホッククエリは NULL)
-- - object_type:       PROCEDURE / FUNCTION / TRIGGER / VIEW / NULL(ad-hoc)
-- - variant_count:     パラメータ違いの query_id 数
-- - total_executions:  期間内の累計実行回数
-- - avg_duration_ms:   平均実行時間 (ミリ秒)
-- - max_duration_ms:   最大実行時間
-- - total_logical_reads: 累計論理I/O
-- - first_execution_time:  Query Store 内での初回観測時刻
-- - last_execution_time:   最終実行時刻
-- ============================================================================

SET NOCOUNT ON;

-- Query Store 有効性チェック
IF (SELECT is_query_store_on FROM sys.databases WHERE database_id = DB_ID()) = 0
BEGIN
    PRINT 'ERROR: Query Store is NOT enabled on this database.';
    PRINT 'Please enable: ALTER DATABASE [<dbname>] SET QUERY_STORE = ON;';
    RAISERROR('Query Store not enabled', 16, 1);
    RETURN;
END;

WITH q AS (
    SELECT
        qsq.query_hash,
        qsqt.query_sql_text,
        qsq.query_id,
        qsq.object_id,
        qsrs.count_executions,
        qsrs.avg_duration,
        qsrs.max_duration,
        qsrs.avg_logical_io_reads,
        qsrs.first_execution_time,
        qsrs.last_execution_time,
        ROW_NUMBER() OVER (PARTITION BY qsq.query_hash ORDER BY qsrs.count_executions DESC, qsq.query_id) AS rn_per_hash
    FROM sys.query_store_query           qsq
    JOIN sys.query_store_query_text      qsqt ON qsq.query_text_id = qsqt.query_text_id
    JOIN sys.query_store_plan            qsp  ON qsq.query_id      = qsp.query_id
    JOIN sys.query_store_runtime_stats   qsrs ON qsp.plan_id       = qsrs.plan_id
)
SELECT
    CONVERT(VARCHAR(34), q.query_hash, 1)              AS query_hash,
    -- 代表 sample_text。CSV 化のためカンマ・改行・タブを置換
    REPLACE(REPLACE(REPLACE(REPLACE(
        SUBSTRING(MAX(CASE WHEN q.rn_per_hash = 1 THEN q.query_sql_text END), 1, 4000),
        CHAR(13), ' '),
        CHAR(10), ' '),
        CHAR(9),  ' '),
        ',',      ';')                                  AS sample_text,
    SCHEMA_NAME(o.schema_id)                            AS schema_name,
    o.name                                              AS object_name,
    o.type_desc                                         AS object_type,
    COUNT(DISTINCT q.query_id)                          AS variant_count,
    SUM(q.count_executions)                             AS total_executions,
    CAST(AVG(q.avg_duration / 1000.0)            AS DECIMAL(18,2)) AS avg_duration_ms,
    CAST(MAX(q.max_duration / 1000.0)            AS DECIMAL(18,2)) AS max_duration_ms,
    SUM(CAST(q.avg_logical_io_reads AS BIGINT) * q.count_executions) AS total_logical_reads,
    MIN(q.first_execution_time)                         AS first_execution_time,
    MAX(q.last_execution_time)                          AS last_execution_time
FROM q
LEFT JOIN sys.objects o ON q.object_id = o.object_id
GROUP BY q.query_hash, o.schema_id, o.name, o.type_desc
ORDER BY total_executions DESC;
