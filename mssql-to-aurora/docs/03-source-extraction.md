# 03. 実RDSからのソース抽出手順

> [!NOTE]
> このドキュメントは **Snapshot モード（将来の本番適用時）** の手順です。
> 検証フェーズで使うサンプルT-SQLについては `tests/ddl/` を参照してください。

## 1. 概要

実 RDS for SQL Server から AI エージェントに食わせる素材（DDL・ストアド・関数・トリガー・代表クエリ・依存関係）を抽出する。**本番 RDS には絶対に触れない**ため、Snapshot を作って別アカウント or 同アカウント別 VPC に復元してから抽出する。

> [!IMPORTANT]
> 「実トラフィックのアプリクエリ」を採取する用途では、本番側に Extended Events を仕込むのではなく、**Query Store** (SQL Server 2016+ 標準機能) を利用する。Query Store のデータは DB 内に永続化されているため Snapshot にそのまま含まれ、本番 DB に追加で何かを仕込む必要がない。

## 2. 抽出対象と方式

| 対象 | 取得方法 | 出力 | 自動化状態 |
|---|---|---|---|
| ストアドプロシージャ / 関数 / トリガー / ビューの一覧 | `sys.objects` LEFT JOIN `sys.sql_modules` | `extraction/output/objects.csv` | ✅ 実装済 (`export-ddl.sh`) |
| `agent/object_list.ini` 生成 | 上記 CSV → 整形 | `extraction/output/object_list.ini` | ✅ 実装済 (`generate-object-list.sh`) |
| 各オブジェクトの DDL (definition) | エージェント Stage 1 が `sys.sql_modules` から都度 SELECT | `result/<obj>/mssql.sql` | ✅ Agent が実行時に自動取得 |
| 依存関係グラフ | `sys.sql_expression_dependencies` | `extraction/output/dependencies.json` | ⚠️ Phase 2 (アセスメントレポートで利用予定) |
| テーブル列メタデータ | `sys.tables` / `sys.columns` | `extraction/output/tables.json` | ⚠️ Phase 2 |
| 代表的なアプリクエリ | **Query Store** (`sys.query_store_*`) | `extraction/output/queries.json` | ⚠️ Phase 2 (本番非侵襲、Query Store 有効化が前提) |
| スキーマ DDL（テーブル/インデックス/制約） | AWS Schema Conversion Tool (SCT) | 別ツール | ❌ 本ツールのスコープ外 |

## 3. 手順

### 3.1 Snapshot のコピー (お客様作業)

> [!IMPORTANT]
> 本番アカウントへの直接アクセスは禁止です。お客様 DBA が **本番アカウントで Snapshot を作成 → 検証用アカウントへコピー** を完了させてから弊社作業に引き継ぎます。
> 詳細手順 (KMS キー共有、リージョン跨ぎ、トラブルシュート) は [06-customer-handover.md §4.5](./06-customer-handover.md#45-クロスアカウント-snapshot-コピー-お客様作業) を参照。

最小フロー (本番アカウントの DBA が実行):

```bash
# ① Snapshot 作成
aws rds create-db-snapshot \
  --db-instance-identifier prod-mssql \
  --db-snapshot-identifier prod-mssql-for-migration-$(date +%Y%m%d)

# ② 検証用アカウントへ共有 (権限付与のみ、データはまだ移動しない)
aws rds modify-db-snapshot-attribute \
  --db-snapshot-identifier prod-mssql-for-migration-YYYYMMDD \
  --attribute-name restore \
  --values-to-add <検証用アカウントID>

# ③ 暗号化済みなら KMS キーも共有 (キーポリシーまたは grant)
#   詳細: 06-customer-handover.md §4.5.4
```

検証用アカウント側 (お客様または弊社):

```bash
# ④ Snapshot を us-east-1 にコピー (検証用アカウント所有のリソースとして取り込み)
aws rds copy-db-snapshot \
  --region us-east-1 \
  --source-db-snapshot-identifier arn:aws:rds:<prod-region>:<本番アカウントID>:snapshot:<prod-snapshot-id> \
  --target-db-snapshot-identifier mssql-to-aurora-source-$(date +%Y%m%d) \
  --copy-tags
```

このコピー先 ARN を §3.2 の `--snapshot-id` に渡します。

### 3.2 Snapshot モードでデプロイ + 自動抽出 (推奨)

`--auto-extract` を付けると、Snapshot からの復元 → 検証 DB への接続 → オブジェクト一覧抽出 → `object_list.ini` 生成 までを deploy.sh 内で自動実行します。

```bash
./mssql-to-aurora/scripts/deploy.sh \
  --source-mode snapshot \
  --snapshot-id mssql-to-aurora-source-20260523 \
  --instance-class db.m5.xlarge \
  --extract-database YourAppDb \
  --auto-extract
```

完了後、ローカルの以下に成果物がダウンロードされます:

```
mssql-to-aurora/extraction/output/
├── objects.csv         # 全オブジェクトの一覧 (type, schema, name, encrypted フラグ)
└── object_list.ini     # AI エージェント用入力ファイル (CLR / 暗号化済はコメントアウト)
```

そのまま一括変換を実行できます:

```bash
# Workbench EC2 にコピーするか、ローカルから object_list.ini を agent/ に置く
cd ~/mssql-to-aurora/agent
./run.sh --multi-agent -f /path/to/extracted/object_list.ini -j 3
```

### 3.3 手動抽出 (deploy 後に再実行する場合)

`--auto-extract` を使わずデプロイした場合や、別 DB を再抽出する場合:

```bash
# Workbench EC2 に SSM Session Manager で接続
aws ssm start-session --target $(jq -r '.MssqlToAuroraStack.WorkbenchInstanceId' output.json)

# (EC2 内で)
cd ~/mssql-to-aurora/extraction/scripts
MSSQL_DATABASE=YourAppDb bash export-ddl.sh    # objects.csv を生成
bash generate-object-list.sh                   # object_list.ini を生成

# 結果を S3 経由でローカルに引き上げる
aws s3 cp ../output/object_list.ini s3://<extraction-bucket>/extraction/object_list.ini
```

`export-ddl.sh` の実体は `extraction/scripts/list-objects.sql` を `sqlcmd` で実行し、CSV 形式で吐き出すラッパです (詳細: §4)。

### 3.4 アプリクエリ抽出 (Phase 2、Query Store 利用)

実トラフィックの代表クエリを抽出したい場合、**Query Store** を利用します。Query Store のデータは DB 内 (MDF) に永続化されているため、Snapshot からの復元 DB を読むだけで取得可能で、**本番 DB への追加設定は不要**です。

> [!NOTE]
> Phase 2 で実装予定。本セクションは設計メモ。

前提:
- SQL Server 2016 以降
- 対象 DB で Query Store が有効化されている (確認: `SELECT name, is_query_store_on FROM sys.databases`)

抽出 SQL の例:

```sql
SELECT TOP 100
    qsq.query_id,
    qsqt.query_sql_text,
    qsrs.count_executions,
    qsrs.avg_duration / 1000.0   AS avg_duration_ms,
    qsrs.avg_logical_io_reads,
    qsrs.last_execution_time
FROM sys.query_store_query_text   qsqt
JOIN sys.query_store_query        qsq  ON qsqt.query_text_id = qsq.query_text_id
JOIN sys.query_store_plan         qsp  ON qsq.query_id       = qsp.query_id
JOIN sys.query_store_runtime_stats qsrs ON qsp.plan_id        = qsrs.plan_id
ORDER BY qsrs.count_executions DESC;
```

取得した代表クエリは、Babelfish / PG ネイティブでの互換性チェックに利用予定。

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
mssql-to-aurora/extraction/output/
├── objects.csv              # 全オブジェクトの一覧 (export-ddl.sh が生成)
│                            # columns: object_type, schema_name, object_name, is_encrypted_or_unavailable
└── object_list.ini          # AI エージェント入力ファイル (generate-object-list.sh が生成)
                             # CLR / WITH ENCRYPTION はコメントアウトで残る
```

### 6.1 objects.csv の例

```csv
object_type,schema_name,object_name,is_encrypted_or_unavailable
SQL_STORED_PROCEDURE,dbo,usp_calculate_employee_bonus,0
SQL_STORED_PROCEDURE,dbo,usp_encrypted_demo,1
SQL_SCALAR_FUNCTION,dbo,fn_get_fiscal_year,0
CLR_SCALAR_FUNCTION,dbo,fn_clr_uppercase,0
SQL_TRIGGER,dbo,trg_audit_employees,0
VIEW,dbo,v_active_employees,0
```

### 6.2 object_list.ini の例

```
# Auto-generated by extraction/scripts/generate-object-list.sh
# Generated at: 2026-05-29 14:54:29 JST
# Source CSV:   ./extraction/output/objects.csv
#
# Format: <ObjectType> <SchemaName>.<ObjectName>
# 行頭に '#' を付けると変換対象から除外されます。

PROCEDURE dbo.usp_calculate_employee_bonus
# [SKIP-ENCRYPTED] PROCEDURE dbo.usp_encrypted_demo (WITH ENCRYPTION, set INCLUDE_ENCRYPTED=1 to include)
FUNCTION dbo.fn_get_fiscal_year
# [SKIP-CLR] CLR_SCALAR_FUNCTION not supported by AI converter: dbo.fn_clr_uppercase
TRIGGER dbo.trg_audit_employees
VIEW dbo.v_active_employees
```

## 7. エージェント側との接続

`object_list.ini` を `agent/` ディレクトリに配置するか、`run.sh -f <path>` で直接指定すれば、そのまま一括変換に使えます:

```bash
cd ~/mssql-to-aurora/agent
./run.sh --multi-agent -f /path/to/extracted/object_list.ini -j 3
```

エージェントは内部で Source MSSQL に接続し、各オブジェクトの DDL を `sys.sql_modules` から再取得するため、**抽出ファイルは「変換対象リスト」を提供する役割**となります。DDL ファイル自体を事前に作る必要はありません。
