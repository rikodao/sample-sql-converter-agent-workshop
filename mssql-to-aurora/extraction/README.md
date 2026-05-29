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
| `scripts/export-ddl.sql` | 完全な DDL / 依存関係 / テーブル列メタデータ抽出 | ✅ SQL のみ実装済 (Phase 2 でラッパ実装) |
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
3. SSM RunCommand で Source MSSQL に対し `export-ddl.sh` 実行
4. `generate-object-list.sh` で `object_list.ini` 生成
5. ローカル `extraction/output/` に成果物をダウンロード

## 出力先

```
mssql-to-aurora/extraction/output/
├── objects.csv         # 全オブジェクトの一覧 + WITH ENCRYPTION フラグ
└── object_list.ini     # AI エージェント入力 (CLR / 暗号化はコメントアウト)
```

## 手動実行 (Workbench EC2 上)

```bash
# Workbench EC2 に SSM 接続後
cd ~/mssql-to-aurora/extraction/scripts
MSSQL_DATABASE=YourAppDb bash export-ddl.sh
bash generate-object-list.sh

# 結果を S3 経由で持ち帰る
aws s3 cp ../output/object_list.ini s3://<extraction-bucket>/extraction/object_list.ini
```

## Phase 2 で予定している作業

- 完全な DDL ファイル分割保存 (各オブジェクトを individual ファイルに)
- 依存関係グラフ JSON 化
- テーブル列メタデータ JSON 化
- Query Store からの代表クエリ抽出 (`scripts/export-queries.sql`)
- 規模・難易度のアセスメントレポート生成 (`docs/assessments/<date>/REPORT.md`)
