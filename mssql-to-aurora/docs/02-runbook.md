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

> [!IMPORTANT]
> Workbench EC2 への接続は **SSM Session Manager 一本**です。SSH ポート(22) は SG レベルで遮断しています。
> ローカル端末には [Session Manager Plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) のインストールが必要です。

```bash
# output.json から接続コマンドを取得
SSM_CMD=$(jq -r '.MssqlToAuroraStack.WorkbenchSsmStartSessionCommand' mssql-to-aurora/output.json)
echo "$SSM_CMD"   # 例: aws ssm start-session --target i-0123abc... --region us-east-1
eval "$SSM_CMD"

# Workbench EC2 セッションに入った後:
sudo -u ec2-user -i      # ec2-user に切替 (SSM デフォルトは ssm-user)
cd ~/mssql-to-aurora/agent
uv sync
set -a; source .env; set +a

# 接続疎通テスト
uv run python -c "
import os
import boto3, json, pyodbc, psycopg
print('AWS account:', boto3.client('sts').get_caller_identity()['Account'])
print('MSSQL_HOST :', os.environ['MSSQL_HOST'])
print('PG / Babelfish env are set:', bool(os.environ.get('AURORA_PG_SECRET_NAME')))
"
```

ポートフォワードでローカル端末から DB に接続したい場合 (例: PG エンドポイントを localhost:15432 にトンネル):

```bash
aws ssm start-session \
  --target i-XXXXXXXXXXXXXX \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters '{"host":["<TargetAuroraPgEndpoint>"],"portNumber":["5432"],"localPortNumber":["15432"]}'
```

## 4. エージェントによる変換

### 4.1 単一オブジェクト

```bash
# Workbench EC2 上で
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
# Workbench EC2 → ローカル (SSM 経由)
# 方法1: S3経由（推奨）
WORKBENCH_ID=$(jq -r '.MssqlToAuroraStack.WorkbenchInstanceId' mssql-to-aurora/output.json)
BUCKET=$(jq -r '.MssqlToAuroraStack.ExtractionBucketName' mssql-to-aurora/output.json)

aws ssm send-command --instance-ids $WORKBENCH_ID --document-name AWS-RunShellScript \
  --parameters "commands=[\"tar -C /home/ec2-user/mssql-to-aurora/agent -czf /tmp/results.tgz result summary.md 2>/dev/null || true; aws s3 cp /tmp/results.tgz s3://$BUCKET/results/\"]"

aws s3 cp s3://$BUCKET/results/results.tgz ./
tar -xzf results.tgz
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
| `aws ssm start-session` で `SessionManagerPlugin is not found` | [Session Manager Plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) を導入 |
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
