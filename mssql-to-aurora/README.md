# MSSQL → Aurora PostgreSQL / Babelfish 移行ワークショップ

RDS for SQL Server から Aurora PostgreSQL（ネイティブ） および Aurora PostgreSQL with Babelfish へ、AI エージェントを使って T-SQL のスキーマ・ストアドプロシージャ・関数を変換・検証するプロジェクトです。

> [!IMPORTANT]
> 本プロジェクトは検証・PoC用です。本番環境の RDS には触れません（Snapshot からクローンを作る経路で進めます）。

## 🎯 ゴール

| # | 内容 |
|---|---|
| 1 | T-SQL ストアド/関数を **Babelfish にそのまま投入して動くか試す**（最小工数） |
| 2 | 動かないものは **PL/pgSQL に変換**し、Aurora PG ネイティブで動かす |
| 3 | **両方とも実テストで結果を比較**し、OK/NG を機械判定する |
| 4 | 最終的には Snapshot 直接利用に切り替えられる構成にしておく（Skill/Plugin化前提） |

## 🏗️ アーキテクチャ概要

```
                ┌─────────────────────────────────┐
                │            VPC                   │
  Snapshot ────► │   ┌─────────────────────────┐  │
  or サンプルDDL  │   │  Source: RDS SQL Server  │  │
                │   └─────────────────────────┘  │
                │                                  │
                │   ┌─────────────────────────┐  │
                │   │  Workbench EC2           │  │
                │   │  - Strands Agents        │  │
                │   │  - MCP Server            │  │
                │   └─┬──────────┬──────────┬─┘  │
                │     ▼          ▼          ▼     │
                │   ┌────┐  ┌────────┐  ┌────────┐│
                │   │MSSQL│ │Aurora │  │Babelfish ││
                │   │クローン│ │PG     │  │(TDS:1433)││
                │   └────┘  └────────┘  └────────┘│
                └─────────────────────────────────┘
```

詳細: [docs/01-architecture.md](docs/01-architecture.md)

## 🤖 マルチエージェント 4段階パイプライン

```
[1] MSSQL検証      mssql.sql / mssql_test.sql / mssql_test.txt
       ↓
[2] Babelfish試行   babelfish_attempt.txt → 成功なら BABELFISH_OK.txt 作成して完了
       ↓ (失敗時)
[3] PG変換         postgres.sql (T-SQL → PL/pgSQL)
       ↓
[4] PG検証         postgres_test.txt + comparison_result.txt → OK.txt / NG.txt
```

詳細: [docs/04-conversion-strategy.md](docs/04-conversion-strategy.md)

## 📋 前提条件

- AWS CDK / Node.js / uv（Python）がインストール済み
- AWS 認証情報（AdministratorAccess 推奨）
- Bedrock の Claude Sonnet 4.5 が `us-east-1` で有効化済み

## 🚀 セットアップ（クイックスタート）

```bash
# 1. CDK 依存関係インストール
cd mssql-to-aurora/cdk && npm ci && cd ../..

# 2. CDK Bootstrap (初回のみ)
cd mssql-to-aurora/cdk && npx cdk bootstrap && cd ../..

# 3. 全部デプロイ（30〜40分）
./mssql-to-aurora/scripts/deploy.sh

# 4. サンプル T-SQL を Source MSSQL に投入（deploy.sh 内で自動実行）

# 5. エージェント起動
cd mssql-to-aurora/agent
uv sync
uv run main.py --multi-agent --prompt "PROCEDURE dbo.usp_calculate_employee_bonus"

# 6. 一括変換
./run.sh --multi-agent

# 7. 結果集計
ls result/
```

詳細: [docs/02-runbook.md](docs/02-runbook.md)

## 🗂️ ディレクトリ構成

```
mssql-to-aurora/
├── README.md                  # 本ファイル
├── docs/                      # 設計書・実行手順書・ADR
├── cdk/                       # インフラ（TypeScript）
├── agent/                     # Strands Agents 実装
├── mcpserver/                 # 各DBアクセスのMCPサーバ
├── extraction/                # 実RDSからのソース抽出スクリプト（将来用）
├── tests/                     # サンプル T-SQL・データ
└── scripts/                   # deploy.sh / destroy.sh
```

## 📚 ドキュメント

| ファイル | 内容 |
|---|---|
| [docs/01-architecture.md](docs/01-architecture.md) | 全体アーキ・コンポーネント詳細 |
| [docs/02-runbook.md](docs/02-runbook.md) | E2E実行手順 |
| [docs/03-source-extraction.md](docs/03-source-extraction.md) | 実RDSからのソース抽出（Snapshotモード用） |
| [docs/04-conversion-strategy.md](docs/04-conversion-strategy.md) | Babelfish vs PG-native の判断基準 |
| [docs/05-test-strategy.md](docs/05-test-strategy.md) | テスト戦略・比較判定ロジック |
| [docs/adr/](docs/adr/) | アーキテクチャ決定記録 |

## 🧹 クリーンアップ

```bash
./mssql-to-aurora/scripts/destroy.sh
```

## ⚠️ 注意事項

- 本ワークショップは検証目的です。AI が DB を操作するため、本番環境では使用しないでください。
- Babelfish 用の Aurora PG クラスタは **Provisioned 構成必須**（Serverless v2 は ACU 下限制約あり）。コストに注意。
- Source RDS SQL Server は最小構成（`db.t3.medium`）で起動します。実Snapshotから復元する場合は元のサイズに合わせます。
