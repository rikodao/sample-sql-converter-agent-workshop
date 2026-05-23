-- enable-xevents.sql (placeholder)
-- 実RDS で Extended Events を有効化するスクリプト。
-- Option Group の SQLSERVER_AUDIT が有効である必要がある。
--
-- 詳細: docs/03-source-extraction.md セクション 3.5 を参照。

CREATE EVENT SESSION [migration_query_capture] ON SERVER
ADD EVENT sqlserver.sql_batch_completed (
    ACTION (sqlserver.client_app_name, sqlserver.database_id, sqlserver.username)
    WHERE database_id = DB_ID('YourAppDb')   -- ★ 実DB名に書き換え
)
ADD TARGET package0.event_file (
    SET filename = N'D:\rdsdbdata\Log\migration_query_capture.xel',
        max_file_size = 50,    -- MB
        max_rollover_files = 5
);

ALTER EVENT SESSION [migration_query_capture] ON SERVER STATE = START;
