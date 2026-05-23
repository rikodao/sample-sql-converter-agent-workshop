# 01. アーキテクチャ設計書

## 1. ゴール再掲

T-SQL（SQL Server）の DB オブジェクト（プロシージャ・関数・トリガー・ビュー・型）を AI エージェントで Aurora PostgreSQL（ネイティブ）/ Babelfish に変換・検証する基盤を提供する。最終的には実 RDS for SQL Server の Snapshot を投入できる構成にする。

## 2. システム全体像

```
                        ┌────────────────────────────────────────┐
                        │             AWS Account                 │
                        │                                          │
                        │  ┌────────────────────────────────────┐ │
                        │  │ MssqlToAuroraStack (CDK)            │ │
                        │  │                                      │ │
                        │  │  ┌─ Network ────────────────────┐  │ │
                        │  │  │ VPC (3-AZ)                    │  │ │
                        │  │  │  - Public                     │  │ │
                        │  │  │  - PrivateWithEgress          │  │ │
                        │  │  │  - Isolated                   │  │ │
                        │  │  │  - EC2 Instance Connect EP    │  │ │
                        │  │  └───────────────────────────────┘  │ │
                        │  │                                      │ │
                        │  │  ┌─ Source ──────────────────────┐  │ │
                        │  │  │ RDS for SQL Server             │  │ │
                        │  │  │  - Express Edition (検証用)    │  │ │
                        │  │  │  - Snapshot復元モードに切替可  │  │ │
                        │  │  │  - Option Group:               │  │ │
                        │  │  │    SQLSERVER_AUDIT (将来用)    │  │ │
                        │  │  └───────────────────────────────┘  │ │
                        │  │                                      │ │
                        │  │  ┌─ Target #1 (PG native) ────────┐  │ │
                        │  │  │ Aurora PostgreSQL Serverless v2│  │ │
                        │  │  │  - Data API 有効               │  │ │
                        │  │  │  - 0.5〜2 ACU                  │  │ │
                        │  │  └───────────────────────────────┘  │ │
                        │  │                                      │ │
                        │  │  ┌─ Target #2 (Babelfish) ────────┐  │ │
                        │  │  │ Aurora PostgreSQL + Babelfish  │  │ │
                        │  │  │  - Provisioned db.r6i.large    │  │ │
                        │  │  │  - TDS port 1433 で T-SQL受付   │  │ │
                        │  │  │  - ParameterGroup: babelfish=1 │  │ │
                        │  │  └───────────────────────────────┘  │ │
                        │  │                                      │ │
                        │  │  ┌─ Workbench EC2 ───────────────┐  │ │
                        │  │  │ Amazon Linux 2023              │  │ │
                        │  │  │  - uv / Python 3.12            │  │ │
                        │  │  │  - pyodbc (msodbcsql18)        │  │ │
                        │  │  │  - psycopg                     │  │ │
                        │  │  │  - Strands Agents + MCP        │  │ │
                        │  │  │  - IAM: Bedrock + RDS Data API │  │ │
                        │  │  │    + SecretsManager + S3       │  │ │
                        │  │  └───────────────────────────────┘  │ │
                        │  │                                      │ │
                        │  │  ┌─ S3 ──────────────────────────┐  │ │
                        │  │  │ Extraction Bucket             │  │ │
                        │  │  │  - 抽出DDL / クエリログ        │  │ │
                        │  │  │  - サンプルT-SQL投入物         │  │ │
                        │  │  └───────────────────────────────┘  │ │
                        │  │                                      │ │
                        │  └────────────────────────────────────┘ │
                        │                                          │
                        │     Bedrock (us-east-1)                  │
                        │      Claude Sonnet 4.5                   │
                        └────────────────────────────────────────┘
```

## 3. コンポーネント一覧

### 3.1 Network (`cdk/lib/constructs/network.ts`)

- VPC: 2-AZ、`maxAzs=2`、NAT Gateway 1
- サブネット: Public / PrivateWithEgress / Isolated
- Flow Logs: REJECT のみ CloudWatch へ
- セキュリティグループ:
  - `sgWorkbench` (EC2) — **インバウンドなし**（SSH不可、SSM Session Manager のみ）
  - `sgSourceMssql` (RDS SQL Server) — 1433 from sgWorkbench
  - `sgTargetPg` (Aurora PG) — 5432 from sgWorkbench
  - `sgTargetBabelfish` (Aurora PG with Babelfish) — 1433 + 5432 from sgWorkbench

> [!IMPORTANT]
> Workbench EC2 への接続は **SSM Session Manager 一本**です。
> SSH (port 22) のインバウンドルールは作成しません。
> EC2 Instance Connect Endpoint も使用しません。

### 3.2 Source (`cdk/lib/constructs/source-mssql.ts`)

- RDS for SQL Server Express Edition (`db.t3.small`〜`db.t3.medium`)
- 認証: Secrets Manager (`mssql-to-aurora/source-mssql-credentials`)
- ストレージ: gp3 50GB、暗号化
- Multi-AZ: false（検証用）
- バックアップ: 1日（検証用、最小）
- Option Group: SQLSERVER_AUDIT を将来用に有効化（既定オフ）
- **2つのモード**:
  - `sample` モード（デフォルト）: 空のDB起動 → deploy.sh で `tests/ddl/sample_objects.sql` を投入
  - `snapshot` モード: CDK context `-c sourceMode=snapshot -c snapshotIdentifier=...` で snapshot から復元

### 3.3 Target #1: Aurora PostgreSQL ネイティブ (`cdk/lib/constructs/target-aurora-pg.ts`)

- Aurora PostgreSQL 15.x Serverless v2
- ACU: 0.5〜2
- Data API: **有効**（既存の `postgres.py` を流用するため）
- 認証: Secrets Manager (`mssql-to-aurora/target-pg-credentials`)
- IAM 認証も併用

### 3.4 Target #2: Aurora PostgreSQL with Babelfish (`cdk/lib/constructs/target-babelfish.ts`)

- Aurora PostgreSQL 16.x **Provisioned** (`db.r6i.large` 1ノード)
  - Babelfish は 2026年5月時点で Serverless v2 に正式対応も、ACU下限/メモリ制約あるためまずは Provisioned から
- DB Cluster Parameter Group:
  - `rds.babelfish_status = on`
  - `babelfishpg_tsql.migration_mode = single-db` または `multi-db`
- Babelfish Database name: `bbf` を作成
- ポート: PG=5432, **TDS=1433**
- 認証: Secrets Manager (`mssql-to-aurora/target-babelfish-credentials`)
- 接続テスト: PGネイティブ接続(5432)とTDS接続(1433)の両方で疎通

### 3.5 Workbench EC2 (`cdk/lib/constructs/workbench-ec2.ts`)

- Amazon Linux 2023 / `t3.medium` / 50GB gp3
- UserData: uv / msodbcsql18 / unixODBC / psycopg / git / jq をインストール
- IAM Role:
  - SSM Session Manager (`AmazonSSMManagedInstanceCore`)
  - Bedrock InvokeModel
  - SecretsManager:GetSecretValue
  - RDS Data API
  - S3 (Extraction Bucket)
- Source/Target各DBへの接続権限
- **Key Pair なし、SSH ポート開放なし**
- 接続: `aws ssm start-session --target <instance-id>` 一本

### 3.6 S3 Extraction Bucket

- DDL/ログ抽出物の置き場
- サンプルT-SQLのアップロード経由地（CDKのBucketDeployment）
- 暗号化、Block Public Access、サーバアクセスログ有効

## 4. エージェント実装

### 4.1 構成

```
agent/
├── main.py                          # CLI エントリ
├── multi_agent_processor.py         # 4段階オーケストレータ
├── mcp.json                          # MCP設定
├── object_list.ini                   # 一括変換対象リスト
├── run.sh                            # 一括実行
├── pyproject.toml
├── mcpserver/
│   ├── server.py                     # FastMCP サーバ
│   ├── mssql.py                      # pyodbc → Source MSSQL
│   ├── babelfish.py                  # pyodbc → TDS:1433
│   ├── postgres.py                   # boto3 RDS Data API → Aurora PG
│   └── shell.py                      # mkdir 等の補助
├── prompts/
│   ├── prompts.py                    # MultiAgent クラス（4段階対応）
│   ├── common/
│   │   └── conversion_rules_tsql.txt
│   └── db_object/
│       ├── instruction.txt
│       ├── workflow.txt
│       ├── test_strategy.txt
│       ├── error_policy.txt
│       ├── output_specification.txt
│       └── multi_agent/
│           ├── 01_mssql_validation.txt
│           ├── 02_babelfish_attempt.txt
│           ├── 03_postgres_conversion.txt
│           └── 04_postgres_verification.txt
└── utils/
    ├── logger.py
    └── callbacks.py
```

### 4.2 4段階パイプライン

| 段階 | エージェント名 | 入力 | 出力 | 早期終了条件 |
|---|---|---|---|---|
| 1 | MSSQL検証 | 対象オブジェクト名 | `mssql.sql`, `mssql_test.sql`, `mssql_test.txt`, `prerequisites.txt` | - |
| 2 | Babelfish試行 | `mssql.sql` | `babelfish_attempt.txt`, `babelfish_test.sql`, `babelfish_test.txt`, `BABELFISH_OK.txt` | 全テストが成功し結果が一致したらここで終了可（フラグで切替） |
| 3 | PG変換 | `mssql.sql` | `postgres.sql`（PL/pgSQL） | - |
| 4 | PG検証 | `postgres.sql`, `mssql_test.*` | `postgres_test.sql`, `postgres_test.txt`, `comparison_result.txt`, `OK.txt`/`NG.txt` | - |

**振る舞いオプション**:
- `--early-exit-on-babelfish` (デフォルト ON): Babelfish成功時に Stage 3/4 をスキップ
- `--always-validate-both`: 両方とも検証する（比較レポート生成）

### 4.3 MCPツール（追加分）

| ツール名 | 説明 |
|---|---|
| `run_mssql_sql(sql)` | Source MSSQL に T-SQL を実行 |
| `run_babelfish_tsql(sql)` | Babelfish (TDS:1433) に T-SQL を実行 |
| `run_babelfish_pg(sql)` | Babelfish (PG:5432) に PL/pgSQL を実行（混在検証用） |
| `run_postgres_sql(sql)` | Aurora PG ネイティブに PL/pgSQL を実行（既存流用） |
| `create_directory(path)` | mkdir -p 相当（既存流用） |

## 5. データフロー

```
[サンプルT-SQLモード]
  tests/ddl/sample_objects.sql
        ↓ (deploy.sh が S3 → SSM RunCommand 経由で投入)
  Source MSSQL
        ↓ (エージェントが sys.sql_modules で取得)
  result/<obj>/mssql.sql
        ↓
  Babelfish 試行 → 失敗 → PG変換
        ↓                    ↓
  result/<obj>/babelfish_*  result/<obj>/postgres_*
        ↓                    ↓
        └───── 結果比較 ─────┘
                  ↓
          OK.txt / NG.txt
```

```
[Snapshot モード（将来用）]
  本番 RDS for SQL Server
        ↓ (Snapshotコピー)
  Workbench AWS Account
        ↓ (CDK で Snapshot から RDS 復元)
  Source MSSQL (クローン)
        ↓ (以下サンプルモードと同じ)
```

## 6. セキュリティ

- 全DBは isolated subnet（Babelfishのみアプリ接続検証のため private/egress も検討）
- Workbench EC2 は private/egress、SSH は EC2 Instance Connect Endpoint 経由のみ
- 全クレデンシャルは Secrets Manager
- S3 は SSE-S3、BPA、SSL強制
- VPC Flow Logs（REJECT）

## 7. 既存 Oracle スタックとの関係

**完全独立**。VPC、Stack、Bucket、Secret 名すべて prefix `mssql-to-aurora-` で衝突回避。既存 `SqlConverterAgentStack` には触れない。

## 8. 拡張ポイント

| 項目 | 拡張方針 |
|---|---|
| 実RDS Snapshot 利用 | `cdk.json` の context `sourceMode=snapshot, snapshotIdentifier=...` で切替 |
| アプリSQL対応 | `prompts/app/` を別途追加（Oracle側の `App` クラスをコピー流用） |
| Skill/Plugin化 | `extraction/` の抽出スクリプトを Lambda 化、`agent/main.py` を MCP サーバ化 |
| Q Developer連携 | `mcpserver/server.py` を `~/.aws/amazonq/mcp.json` に登録するだけ |
