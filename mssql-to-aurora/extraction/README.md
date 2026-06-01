# Source extraction utilities

このディレクトリは **実 RDS for SQL Server から Snapshot 経由でソース情報を抽出する** ツール群です。
サンプル T-SQL モード (デフォルト) では出番なし。

詳細手順は [../docs/03-source-extraction.md](../docs/03-source-extraction.md) を参照。

## 内容

| ファイル | 用途 | 状態 |
|---|---|---|
| `scripts/list-objects.sql` | 軽量オブジェクト一覧 SQL (object_list.ini 生成用) | ✅ 実装済 |
| `scripts/export-ddl.sh` | sqlcmd で list-objects.sql を実行 → objects.csv | ✅ 実装済 |
| `scripts/generate-object-list.sh` | objects.csv → object_list.ini 整形 | ✅ 実装済 |
| `scripts/list-queries.sql` | Query Store からアプリ実行クエリ全量を集約抽出 | ✅ 実装済 |
| `scripts/export-queries.sh` | sqlcmd で list-queries.sql を実行 → queries.csv | ✅ 実装済 |
| `scripts/export-ddl.sql` | 完全な DDL / 依存関係 / テーブル列メタデータ抽出 | ✅ SQL のみ実装済 (Phase 2.1 でラッパ実装) |
| `scripts/snapshot-restore.sh` | 抽出先 RDS への接続疎通確認・DB一覧取得 | ⚠️ プレースホルダ |
| `scripts/enable-xevents.sql` | (廃止予定) Extended Events を本番に仕込む方式 | ❌ 削除予定 (Query Store 方式に置換) |
| `scripts/collect-query-logs.sh` | (廃止予定) XEL ログを S3 にアップロード | ❌ 削除予定 |

## 推奨フロー

最も簡単なのは `scripts/deploy.sh` の `--auto-extract` オプション:

```bash
./mssql-to-aurora/scripts/deploy.sh \
  --source-mode snapshot \
  --snapshot-id <SnapshotARN> \
  --extract-database YourAppDb \
  --auto-extract
```

これで以下が自動実行されます:

1. CDK で Snapshot から検証 RDS を復元
2. Workbench EC2 にエージェント+抽出スクリプト一式を配置
3. SSM RunCommand で Source MSSQL に対し `export-ddl.sh` 実行 → `objects.csv`
4. `generate-object-list.sh` で `object_list.ini` 生成
5. **`export-queries.sh` を best-effort で実行 → `queries.csv` (Query Store 有効時のみ)**
6. ローカル `extraction/output/` に成果物をダウンロード

## 出力先

```
mssql-to-aurora/extraction/output/
├── objects.csv         # 全オブジェクトの一覧 + WITH ENCRYPTION フラグ
├── object_list.ini     # AI エージェント入力 (CLR / 暗号化はコメントアウト)
└── queries.csv         # アプリ実行クエリ全量 (Query Store 有効時のみ)
```

### queries.csv カラム

```
query_hash, sample_text, schema_name, object_name, object_type,
variant_count, total_executions, avg_duration_ms, max_duration_ms,
total_logical_reads, first_execution_time, last_execution_time
```

`query_hash` で集約された全ユニーククエリパターンが含まれます。
TOP 制限なしの全量。`total_executions` 降順で出力。

## 手動実行 (Workbench EC2 上)

```bash
# Workbench EC2 に SSM 接続後
cd ~/mssql-to-aurora/extraction/scripts

# オブジェクト一覧
MSSQL_DATABASE=YourAppDb bash export-ddl.sh
bash generate-object-list.sh

# Query Store (要 Query Store 有効化)
MSSQL_DATABASE=YourAppDb bash export-queries.sh

# 結果を S3 経由で持ち帰る
aws s3 cp ../output/object_list.ini s3://<extraction-bucket>/extraction/object_list.ini
aws s3 cp ../output/queries.csv     s3://<extraction-bucket>/extraction/queries.csv
```

## Query Store の前提

`export-queries.sh` は対象 DB で Query Store が有効化されている必要があります。

```sql
-- 確認
SELECT name, is_query_store_on FROM sys.databases WHERE name = 'YourAppDb';

-- 有効化 (本番側で事前実施推奨)
ALTER DATABASE [YourAppDb] SET QUERY_STORE = ON
    (OPERATION_MODE = READ_WRITE,
     QUERY_CAPTURE_MODE = AUTO,
     MAX_STORAGE_SIZE_MB = 2048,
     STALE_QUERY_THRESHOLD_DAYS = 30);
```

無効の場合 `export-queries.sh` は exit 2 で early-return し、`queries.csv` は生成されません。
`deploy.sh --auto-extract` 経路では best-effort で skip されデプロイは継続します。

## Phase 2.1 以降で予定している作業

- 完全な DDL ファイル分割保存 (各オブジェクトを individual ファイルに)
- 依存関係グラフ JSON 化
- テーブル列メタデータ JSON 化
- 規模・難易度のアセスメントレポート生成 (`docs/assessments/<date>/REPORT.md`)
- 廃止予定スクリプト (`enable-xevents.sql`, `collect-query-logs.sh`) の削除
