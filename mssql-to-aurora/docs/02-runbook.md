# 02. 実行手順書（E2E Runbook）

## 0. 前提

- AWS 認証情報がセット済み（AdministratorAccess 推奨）
- `npm`, `node`, `uv`, `aws` CLI がインストール済み
- Bedrock の Claude Sonnet 4.5 が `us-east-1` で有効化済み
- 現在ブランチ: `feat/mssql-to-aurora`

```bash
aws sts get-caller-identity        # アカウント確認
aws bedrock list-foundation-models --region us-east-1 | grep -i claude-sonnet-4-5
```

## 1. CDK 依存関係インストール & Bootstrap

```bash
cd mssql-to-aurora/cdk
npm ci
npx cdk bootstrap   # 初回のみ（既存リージョンでboot済みならskip）
cd ../..
```

## 2. デプロイ

### 2.1 サンプルモード（デフォルト）

```bash
./mssql-to-aurora/scripts/deploy.sh
```

`deploy.sh` の処理:

1. CDK で `MssqlToAuroraStack` をデプロイ（VPC / RDS SQL Server / Aurora PG / Babelfish / Workbench EC2 / S3）  
   → 約 25〜35分
2. 出力（`output.json`）から各エンドポイントを取得
3. Workbench EC2 のキーペアを SSM Parameter Store から取得し `mssql-workbench-key.pem` に保存
4. `ssh-config-mssql` の HostName を Workbench InstanceID に書き換え
5. `tests/ddl/sample_objects.sql` を S3 にアップロード
6. SSM RunCommand で Source RDS SQL Server に対してサンプル DDL を投入
7. Babelfish の Babelfish DB (`bbf`) を初期化（`CREATE DATABASE bbf` 相当）
8. Aurora PG ネイティブに `migration` スキーマを作成

### 2.2 Snapshot モード（実RDS利用、将来）

```bash
./mssql-to-aurora/scripts/deploy.sh \
  --source-mode snapshot \
  --snapshot-id arn:aws:rds:ap-northeast-1:111122223333:snapshot:my-prod-mssql-2026-05-23
```

CDK context が `sourceMode=snapshot` で動作し、Source 構成が `DatabaseInstanceFromSnapshot` に切り替わります。元 Snapshot のインスタンスサイズに合わせるため、`--instance-class db.m5.xlarge` のような指定も可能。

## 3. デプロイ後の接続確認

```bash
# Workbench EC2 に SSH（EC2 Instance Connect Endpoint 経由）
ssh -F ssh-config-mssql workbench

# Workbench EC2 上で以下のテストスクリプト実行
cd ~/mssql-to-aurora/agent
uv sync
uv run python -m utils.connect_test
```

`connect_test` が出力する内容:
- `[OK] Source MSSQL: SELECT @@VERSION → ...`
- `[OK] Aurora PG (native): SELECT version() → ...`
- `[OK] Babelfish (TDS:1433): SELECT @@VERSION → ...`
- `[OK] Babelfish (PG:5432): SELECT version() → ...`

## 4. エージェントによる変換

### 4.1 単一オブジェクト

```bash
cd ~/mssql-to-aurora/agent
uv run main.py --multi-agent --prompt "PROCEDURE dbo.usp_calculate_employee_bonus"
```

実行されるステージ（標準フロー）:

```
[1/4] MSSQL検証 開始
[1/4] MSSQL検証 完了 → result/usp_calculate_employee_bonus/mssql.sql ほか
[2/4] Babelfish試行 開始
[2/4] Babelfish試行 完了 → babelfish_attempt.txt
      → BABELFISH_OK.txt が作成されたためStage 3/4 をスキップ
```

または:

```
[2/4] Babelfish試行 失敗 (T-SQL構文非対応箇所あり)
[3/4] PG変換 開始
[3/4] PG変換 完了 → postgres.sql
[4/4] PG検証 開始
[4/4] PG検証 完了 → OK.txt
```

### 4.2 一括変換

```bash
cd ~/mssql-to-aurora/agent
./run.sh --multi-agent
```

`object_list.ini` のオブジェクトを順次処理。

### 4.3 オプション

| オプション | 効果 |
|---|---|
| `--multi-agent` | 4段階パイプラインを有効化 |
| `--avoid-throttling` | Bedrock スロットリング時に自動リトライ |
| `--always-validate-both` | Babelfish成功時もPG変換まで実行（比較レポート用） |
| `-f, --file <path>` | 一括処理対象リスト指定 |

## 5. 結果の集計

```bash
cd ~/mssql-to-aurora/agent

# 結果サマリー
ls result/

# 集計
echo "=== Babelfishのみで完結 ===" && find result -name BABELFISH_OK.txt | wc -l
echo "=== PG変換成功 ===" && find result -name OK.txt | wc -l
echo "=== 失敗 ===" && find result -name NG.txt | wc -l

# サマリーレポート生成（提供スクリプト）
uv run python -m utils.summarize_results > summary.md
```

`summary.md` には以下が含まれる:
- 各オブジェクトのターゲット振り分け（Babelfish / PG-native / 失敗）
- 失敗したオブジェクトの NG 理由トップN
- 推定移行工数の目安

## 6. 結果の取り出し

```bash
# Workbench EC2 → ローカル
scp -F ssh-config-mssql -r workbench:~/mssql-to-aurora/agent/result ./result-snapshot-$(date +%Y%m%d)
scp -F ssh-config-mssql workbench:~/mssql-to-aurora/agent/summary.md ./
```

## 7. クリーンアップ

```bash
./mssql-to-aurora/scripts/destroy.sh
```

`destroy.sh` の処理:

1. Aurora PG / Babelfish / RDS SQL Server の `deletionProtection` を無効化（保険）
2. CDK destroy
3. ローカルの `mssql-workbench-key.pem`, `output.json` を削除
4. Snapshot 類は **削除しない**（手動確認のため）

```bash
# 残ったSnapshot確認
aws rds describe-db-snapshots --query 'DBSnapshots[?contains(DBSnapshotIdentifier, `mssql-to-aurora`)]'
aws rds describe-db-cluster-snapshots --query 'DBClusterSnapshots[?contains(DBClusterSnapshotIdentifier, `mssql-to-aurora`)]'
```

## 8. トラブルシューティング

| 症状 | 対処 |
|---|---|
| `cdk deploy` で `Bedrock model not enabled` | コンソールで Claude Sonnet 4.5 を有効化 |
| Workbench EC2 から MSSQL に接続できない | `msodbcsql18` インストール確認、SG 1433 確認 |
| Babelfish に TDS で接続できない | `rds.babelfish_status=on` 確認、ポート1433疎通確認 |
| Bedrock ThrottlingException | `--avoid-throttling` を付与 |
| サンプル DDL 投入失敗 | `tests/ddl/sample_objects.sql` の文法確認、`SSM RunCommand` のログ確認 |
| `cdk destroy` がタイムアウト | RDS の deletionProtection を手動でOFFにして再実行 |

## 9. 想定所要時間とコスト目安

| フェーズ | 時間 | 備考 |
|---|---|---|
| Bootstrap (初回) | 2分 | |
| Deploy | 25〜35分 | RDS SQL Server / Babelfishクラスタが時間を要する |
| サンプル投入 | 1〜2分 | |
| エージェント1オブジェクト処理 | 2〜5分 | Bedrock速度依存 |
| Destroy | 15〜25分 | |

コスト目安（東京リージョン、24時間稼働の場合）:
- Aurora PG (Serverless v2 0.5ACU平均): ~$3/日
- Aurora PG with Babelfish (db.r6i.large): ~$8/日
- RDS SQL Server Express (db.t3.small): ~$2/日
- Workbench EC2 (t3.medium): ~$1/日
- Bedrock Claude Sonnet 4.5: 使用量次第

合計 ~$15/日 + Bedrock 利用料。**使い終わったら必ず destroy** を推奨。
