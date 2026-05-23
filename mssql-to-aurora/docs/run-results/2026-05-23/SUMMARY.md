# 実行サマリー: 2026-05-23 一括変換 (9オブジェクト)

## 概要

`./run.sh --multi-agent` を実行し、サンプルT-SQL DDL に含まれる9個のデータベースオブジェクトを変換・検証。

## 環境

| 項目 | 値 |
|---|---|
| Source | RDS for SQL Server 2022 Express, db.t3.small |
| Target #1 | Aurora PostgreSQL 15.10 Serverless v2 (Data API) |
| Target #2 | Babelfish for Aurora PostgreSQL 4.3.3 (12.0.2000.8), db.r6i.large |
| エージェント | Strands Agents 1.41.0 + Bedrock Claude Sonnet 4.5 |
| Workbench | EC2 t3.medium (Amazon Linux 2023, 接続は SSM Session Manager のみ) |

## 変換結果

| オブジェクト | 種別 | 変換結果 | 移行先 | 備考 |
|---|---|---|---|---|
| `fn_format_employee_name` | SQL Scalar Function | ✅ BABELFISH_OK | Babelfish | T-SQLそのまま動作 |
| `fn_get_fiscal_year` | SQL Scalar Function | ✅ BABELFISH_OK | Babelfish | DATEADD/MONTH等そのまま |
| `fn_split_csv` | SQL Table-Valued Function | ✅ BABELFISH_OK | Babelfish | CHARINDEX/SUBSTRING互換 |
| `trg_audit_employees` | Trigger | ✅ BABELFISH_OK | Babelfish | inserted/deleted対応 |
| `usp_archive_old_orders` | Stored Procedure | ✅ BABELFISH_OK | Babelfish | TRY/CATCH + OUTPUT INTO 動作 |
| `usp_calculate_employee_bonus` | Stored Procedure | ✅ BABELFISH_OK | Babelfish | UPSERT(IF EXISTS+UPDATE/INSERT)動作 |
| `usp_recursive_org_chart` | Stored Procedure | ✅ BABELFISH_OK | Babelfish | 再帰CTE動作 |
| `usp_upsert_department` | Stored Procedure | ⚠ OK (PG-native) | Aurora PG | MERGE文 → ON CONFLICT に変換 |
| `v_active_employees` | View | ✅ BABELFISH_OK | Babelfish | OUTER APPLY含む |

## 集計

| 指標 | 値 |
|---|---|
| 全オブジェクト数 | 9 |
| Babelfish 互換 (BABELFISH_OK) | 8 (89%) |
| PG-native 移行 (OK) | 1 (11%) |
| 失敗 (NG) | 0 |
| 総実行時間 | 67分 |
| 平均時間/オブジェクト | 7.5分 |

## エージェント挙動の特筆事項

### Babelfish 早期終了が機能
4段階パイプラインのうち Stage 2 (Babelfish試行) で互換性確認が取れた8オブジェクトは Stage 3-4 をスキップ。本来 17分/objだった処理を 7.5分/obj に短縮。

### 唯一のPG-native選択: `usp_upsert_department`
`MERGE` 文を含むため Babelfish 互換性試行で問題が出た。エージェントは自動的に Stage 3 に進み、`INSERT ... ON CONFLICT DO UPDATE` への変換を生成。Aurora PG で実テスト実行・MSSQL結果と比較し OK 判定。

### テストケース自動生成の質
代表例 `usp_calculate_employee_bonus`:
- 13テストケース (正常系3 / 境界値5 / 例外系3 / 副作用2)
- 結果一致率 13/13 (EXACT 12, SEMANTIC 1)
- timestamp 精度差 (DATETIME vs TIMESTAMP) は SEMANTIC で MATCH 扱い

### 出力レポート
`OK.txt` / `BABELFISH_OK.txt` には以下が含まれる:
- 主要変換ルール (DATEDIFF→EXTRACT, ISNULL→COALESCE, MERGE→ON CONFLICT等)
- 各テストケースの期待値・実測値・判定
- デプロイ前チェックリスト
- 既知の差異 (リターンコード機構、トランザクション分離レベル等)

## 結論

**サンプルT-SQL 9個に対して、エージェントによる自動移行が機能することを確認**。

実プロジェクト適用時の期待値:
- 単純な T-SQL (関数、UPSERTなし、TRY/CATCH程度) は Babelfish で吸収可能 (~80%以上見込み)
- MERGE 文 / sp_executesql 動的 OUTPUT / CLR 等を含むものは PG-native 変換必要
- 残るのは人手レビュー対象 (CLR / Linked Server / Service Broker 等の本質的な再設計)

## 各オブジェクトの詳細結果

各オブジェクトのフォルダ (`./<object_name>/`) に以下のファイルが格納されています:

- `mssql.sql` — Source の DDL
- `mssql_test.sql` / `mssql_test.txt` — テストケースとMSSQL実行結果
- `babelfish_attempt.txt` — Babelfish試行ログ
- `babelfish_test.sql` / `babelfish_test.txt` — Babelfishでのテスト結果
- `BABELFISH_OK.txt` — Babelfish互換性確認OKの判定書
- `postgres.sql` — PG-native変換後 (PG-native振り分け時のみ)
- `postgres_test.sql` / `postgres_test.txt` — PGでのテスト結果 (同上)
- `comparison_result.txt` — MSSQL/PG結果比較
- `OK.txt` — PG-native移行OKの判定書 (該当時)

## 実行コマンド

参考までに、本結果を再現するためのコマンド:

```bash
# (Workbench EC2 上で)
cd ~/mssql-to-aurora/agent
set -a; source .env; set +a
./run.sh --multi-agent
```
