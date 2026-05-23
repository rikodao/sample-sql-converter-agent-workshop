# Source extraction utilities

> このディレクトリは将来 **実RDS for SQL Server から Snapshot 経由でソースを取り込む** 際に使うツール群です。
> サンプル T-SQL モード (デフォルト) では出番なし。

詳細手順は [../docs/03-source-extraction.md](../docs/03-source-extraction.md) を参照。

## 内容

| ファイル | 用途 |
|---|---|
| `scripts/snapshot-restore.sh` | 抽出先 RDS への接続疎通確認・DB一覧取得 |
| `scripts/export-ddl.sql` | sys.sql_modules からストアド・関数・トリガー・ビューを抽出 |
| `scripts/export-ddl.sh` | 上記 SQL を sqlcmd で実行し、ファイル分割保存 |
| `scripts/enable-xevents.sql` | Extended Events 有効化 (実トラフィック取得用) |
| `scripts/collect-query-logs.sh` | XELログを S3 にアップロード |

## 出力先

```
extraction/output/<dbname>/
  ├── procedures/
  ├── functions/
  ├── triggers/
  ├── views/
  ├── schema/
  ├── dependencies.json
  └── queries/
```

> [!WARNING]
> 本ディレクトリのスクリプトは Phase A (本コミット時点) ではプレースホルダです。
> Snapshot モード適用フェーズで実装を完成させます。
