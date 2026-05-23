# 03. 実RDSからのソース抽出手順

> [!NOTE]
> このドキュメントは **Snapshot モード（将来の本番適用時）** の手順です。
> 検証フェーズで使うサンプルT-SQLについては `tests/ddl/` を参照してください。

## 1. 概要

実 RDS for SQL Server から AI エージェントに食わせる素材（DDL・ストアド・関数・トリガー・代表クエリ・依存関係）を抽出する。**本番 RDS には絶対に触れない**ため、Snapshot を作って別アカウント or 同アカウント別 VPC に復元してから抽出する。

## 2. 抽出対象と方式

| 対象 | 取得方法 | 出力 |
|---|---|---|
| スキーマ DDL（テーブル/インデックス/制約/シーケンス/型） | `sys.tables` 等 + 自動 DDL 生成（`SMO` or `mssql-scripter`） | `extraction/output/<db>/schema/*.sql` |
| ストアドプロシージャ | `sys.sql_modules` JOIN `sys.objects` WHERE type='P' | `extraction/output/<db>/procedures/*.sql` |
| ユーザー定義関数 | `sys.sql_modules` WHERE type IN ('FN','IF','TF','FS','FT') | `extraction/output/<db>/functions/*.sql` |
| トリガー | `sys.sql_modules` WHERE type='TR' | `extraction/output/<db>/triggers/*.sql` |
| ビュー | `sys.sql_modules` WHERE type='V' | `extraction/output/<db>/views/*.sql` |
| 依存関係グラフ | `sys.sql_expression_dependencies` | `extraction/output/<db>/dependencies.json` |
| 代表的なアプリクエリ | SQL Server Audit / Extended Events | `extraction/output/<db>/queries/*.xel` → 解析済JSON |

## 3. 手順

### 3.1 Snapshot のコピー

```bash
# 本番アカウントで Snapshot 作成（既存があれば不要）
aws rds create-db-snapshot \
  --db-instance-identifier prod-mssql \
  --db-snapshot-identifier prod-mssql-for-migration-$(date +%Y%m%d)

# 検証アカウントへコピー（KMS鍵共有が必要なら別途）
aws rds copy-db-snapshot \
  --source-db-snapshot-identifier arn:aws:rds:ap-northeast-1:PROD_ACCT:snapshot:prod-mssql-for-migration-... \
  --target-db-snapshot-identifier mssql-to-aurora-source-$(date +%Y%m%d) \
  --region ap-northeast-1
```

### 3.2 検証スタックを Snapshot モードでデプロイ

```bash
./mssql-to-aurora/scripts/deploy.sh \
  --source-mode snapshot \
  --snapshot-id mssql-to-aurora-source-20260523 \
  --instance-class db.m5.xlarge   # 本番元のサイズに合わせる
```

CDK 内部で `DatabaseInstanceFromSnapshot` を使い、SG とサブネット設定は通常モードと同じ。

### 3.3 抽出スクリプト実行

```bash
# Workbench EC2 へ SSH
ssh -F ssh-config-mssql workbench

# 抽出スクリプト実行
cd ~/mssql-to-aurora/extraction
./scripts/snapshot-restore.sh        # 既にCDKで復元済みのため、このスクリプトは「接続疎通とDB一覧取得」のみ
./scripts/export-ddl.sh              # DDL/ストアド/関数を一気に抽出 → S3
```

`export-ddl.sh` の中身は `extraction/scripts/export-ddl.sql`（後述）を `sqlcmd` で実行する。

### 3.4 ストアド一覧の生成

抽出されたファイル名から `agent/object_list.ini` を生成する補助スクリプト:

```bash
./scripts/generate-object-list.sh > ../agent/object_list.ini
```

出力例:
```
PROCEDURE dbo.usp_calculate_employee_bonus
PROCEDURE dbo.usp_archive_old_orders
FUNCTION dbo.fn_get_fiscal_year
TRIGGER dbo.trg_audit_insert
VIEW dbo.v_active_employees
```

### 3.5 アプリクエリログ（任意）

実トラフィックの代表クエリを取得したい場合:

```sql
-- enable-xevents.sql
CREATE EVENT SESSION [migration_query_capture] ON SERVER
ADD EVENT sqlserver.sql_batch_completed (
    ACTION (sqlserver.client_app_name, sqlserver.database_id)
    WHERE database_id = DB_ID('YourAppDb')
)
ADD TARGET package0.event_file (
    SET filename = N'D:\rdsdbdata\Log\migration_query_capture.xel'
);
ALTER EVENT SESSION [migration_query_capture] ON SERVER STATE = START;
```

> [!IMPORTANT]
> RDS for SQL Server で Extended Events を使う場合、Option Group に `SQLSERVER_AUDIT` または専用設定が必要。詳細は AWS ドキュメント「Working with extended events in SQL Server DB instances」を参照。

ログを S3 にエクスポート（`xp_readerrorlog` は使えないため、`rds_download_from_s3` の逆向き機能 = ファイルを `RDSADMIN.dbo.rds_download_from_s3` 経由で扱う）:

```sql
EXEC msdb.dbo.rds_gather_file_details;
EXEC msdb.dbo.rds_upload_to_s3
    @rds_file_path='D:\rdsdbdata\Log\migration_query_capture.xel',
    @s3_arn_to_upload_to='arn:aws:s3:::mssql-to-aurora-extraction-bucket/queries/';
```

## 4. 抽出 SQL の中身

### 4.1 ストアドプロシージャ取得

```sql
-- export-ddl.sql の一部
SELECT
    SCHEMA_NAME(o.schema_id) AS schema_name,
    o.name AS object_name,
    o.type_desc,
    m.definition
FROM sys.sql_modules m
JOIN sys.objects o ON m.object_id = o.object_id
WHERE o.type IN ('P', 'FN', 'IF', 'TF', 'TR', 'V')
ORDER BY o.type_desc, schema_name, o.name;
```

各行を 1ファイルに分割保存（`<schema>.<name>.sql`）。

### 4.2 依存関係抽出

```sql
SELECT
    SCHEMA_NAME(o1.schema_id) + '.' + o1.name AS referencing_object,
    o1.type_desc AS referencing_type,
    SCHEMA_NAME(o2.schema_id) + '.' + o2.name AS referenced_object,
    o2.type_desc AS referenced_type
FROM sys.sql_expression_dependencies d
JOIN sys.objects o1 ON d.referencing_id = o1.object_id
JOIN sys.objects o2 ON d.referenced_id  = o2.object_id;
```

JSON で保存し、エージェントが「対象オブジェクトの依存先一覧」を取得できるようにする。

## 5. 制約と注意事項

| 制約 | 対処 |
|---|---|
| RDS Master ユーザーは sysadmin ではない | sys.sql_modules / sys.objects は SELECT 可能、概ね問題なし |
| CLR アセンブリは definition が NULL | `sys.assemblies` から DLL バイナリ取得、別途扱い |
| 暗号化されたストアド (`WITH ENCRYPTION`) | definition が NULL になる。**変換不可**として記録、目視対応 |
| 大規模 DB（数千オブジェクト） | 並列抽出スクリプトを別途用意（本フェーズではスコープ外） |
| Linked Server / 外部依存 | 移行先での代替手段を別途設計（本フェーズではスコープ外） |

## 6. 出力フォーマット

```
extraction/output/<dbname>/
├── schema/
│   ├── dbo.employees.sql
│   └── ...
├── procedures/
│   ├── dbo.usp_calculate_bonus.sql
│   └── ...
├── functions/
│   ├── dbo.fn_get_fiscal_year.sql
│   └── ...
├── triggers/
│   └── ...
├── views/
│   └── ...
├── dependencies.json
└── queries/
    └── migration_query_capture-2026-05-23.xel.json   # XELパース後
```

## 7. エージェント側との接続

`agent/object_list.ini` を `generate-object-list.sh` で生成すれば、そのまま `./run.sh --multi-agent` で一括変換できる。エージェントは Source MSSQL に直接接続し、`sys.sql_modules` から再取得もできるので、**抽出ファイルは「変換対象リスト生成」用**と捉えるのが正確。
