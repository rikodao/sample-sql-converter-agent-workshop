# HOWTO — SCT ホストのセットアップ手順

## 0. 前提

- Ubuntu 22.04 LTS / 24.04 LTS の EC2 インスタンス
- インスタンスタイプ: m5.xlarge 以上推奨
- EBS: 100 GB+ (gp3)
- 検証用アカウント内で起動 (本番には触らない)
- IAM Role に **s3:GetObject** 権限を付与 (S3 から `.bak` を取る場合)
- SG: 1433/tcp を SCT 接続元 (お客様 DBA の作業端末 IP 等) から許可
- 接続方式: SSM Session Manager 推奨 (本ツール本体と同じポリシー)

## 1. EC2 インスタンスの起動

CDK 拡張は本フェーズではスコープ外なので、AWS CLI で手動起動するか、
お客様 DBA に立ててもらってください。

```bash
# Ubuntu 22.04 LTS の最新 AMI を取得
AMI_ID=$(aws ec2 describe-images \
  --owners 099720109477 \
  --filters \
    "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-jammy-22.04-amd64-server-*" \
    "Name=state,Values=available" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
  --output text \
  --region us-east-1)
echo "AMI: $AMI_ID"

# 起動 (SG, Subnet, IAM Profile は環境に合わせて)
aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type m5.xlarge \
  --subnet-id subnet-xxxxx \
  --security-group-ids sg-xxxxx \
  --iam-instance-profile Name=SctHostRole \
  --block-device-mappings '[{
    "DeviceName": "/dev/sda1",
    "Ebs": {"VolumeSize": 100, "VolumeType": "gp3", "DeleteOnTermination": true, "Encrypted": true}
  }]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=sct-host}]' \
  --metadata-options 'HttpTokens=required,HttpEndpoint=enabled' \
  --region us-east-1
```

起動後、SSM Session Manager で接続できることを確認:

```bash
aws ssm start-session --target i-xxxxxxxxxxxxx --region us-east-1
```

## 2. このリポジトリを EC2 に転送

3 つの方法があります。状況に応じて選んでください。

### 方法 A: git clone (一番楽)

```bash
# EC2 内
sudo apt-get update
sudo apt-get install -y git
git clone <your-repo-url>
cd <repo>/mssql-to-aurora/extraction/sct-host/
```

### 方法 B: tar で送り込む (リポジトリを公開できない場合)

```bash
# ローカルから
cd mssql-to-aurora
tar czf /tmp/sct-host.tgz extraction/sct-host/
aws s3 cp /tmp/sct-host.tgz s3://your-bucket/

# EC2 内
aws s3 cp s3://your-bucket/sct-host.tgz /tmp/
mkdir -p ~/work && cd ~/work
tar xzf /tmp/sct-host.tgz
cd extraction/sct-host/
```

### 方法 C: SCP / SFTP

省略 (お好みで)

## 3. Self-Bootstrap (一発実行)

最もシンプルなのは EC2 上で `bootstrap.sh` を一発叩くこと。

```bash
# 必須の SA パスワードと、bak 復元情報 (任意) を環境変数で渡す
sudo \
  MSSQL_SA_PASSWORD='YourStrongP@ssw0rd2026' \
  MSSQL_RESTORE_BAK_S3_URI='s3://your-bucket/prod-mssql.bak' \
  MSSQL_RESTORE_DATABASE_NAME='YourAppDb' \
  AWS_REGION='us-east-1' \
  bash scripts/bootstrap.sh
```

これで以下が完了:
- apt update + Ansible / boto3 インストール
- Microsoft 公式 apt repo 登録
- SQL Server 2022 Developer Edition インストール
- mssql-conf で SA パスワード設定 + サービス起動
- ufw で 1433/tcp 許可
- (指定があれば) S3 から bak ダウンロード + RESTORE DATABASE

完了後、`SELECT @@VERSION` で動作確認:

```bash
/opt/mssql-tools18/bin/sqlcmd -S 127.0.0.1,1433 \
  -U SA -P 'YourStrongP@ssw0rd2026' -C -N \
  -Q "SELECT @@VERSION"
```

## 4. リモートから Ansible を流す方法 (任意)

ローカル端末から SSH or SSM で SCT ホストに接続して playbook を流すパターン。

### 4.1 ローカル準備

```bash
pip3 install ansible boto3
ansible-galaxy collection install community.general
# SSM 経由なら追加:
ansible-galaxy collection install community.aws
```

### 4.2 inventory / group_vars 編集

```bash
cd extraction/sct-host/ansible
cp inventory.ini.template inventory.ini
cp group_vars/all.yml.template group_vars/all.yml

# inventory.ini 編集 (SSH or SSM のパターン参照)
# group_vars/all.yml の mssql_sa_password を強いパスワードに変更
vi inventory.ini
vi group_vars/all.yml
```

### 4.3 実行

```bash
cd extraction/sct-host
./scripts/run-ansible.sh

# またはタグ指定で部分実行
./scripts/run-ansible.sh --tags install,configure

# dry-run
./scripts/run-ansible.sh --check

# bak 復元を環境変数経由で
MSSQL_SA_PASSWORD='YourStrongP@ss' \
MSSQL_RESTORE_BAK_S3_URI='s3://bucket/prod.bak' \
MSSQL_RESTORE_DATABASE_NAME='YourAppDb' \
  ./scripts/run-ansible.sh
```

## 5. SCT / DMS Schema Conversion から接続

セットアップ完了後、お客様 DBA は SCT (デスクトップ版) から以下で接続:

| 項目 | 値 |
|---|---|
| Hostname | EC2 の Private IP (VPN/Direct Connect/SSM Port Forwarding 経由) |
| Port | 1433 |
| Authentication | SQL Server Authentication |
| User | SA |
| Password | bootstrap.sh で指定したもの |
| TLS | `Trust server certificate` を ON (self-signed 受容) |

SSM Port Forwarding で手元から接続する場合の例:

```bash
aws ssm start-session \
  --target i-xxxxxxxxxxxxx \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters '{"host":["127.0.0.1"],"portNumber":["1433"],"localPortNumber":["11433"]}' \
  --region us-east-1

# → ローカルから 127.0.0.1:11433 で SQL Server に到達できる
```

## 6. クリーンアップ

評価が完了したら速やかに削除 (Developer Edition の EULA 上、評価後の保持は推奨されない)。

```bash
# bak と DB を消す
sudo systemctl stop mssql-server
sudo rm -rf /var/opt/mssql/backup /var/opt/mssql/data/YourAppDb*

# EC2 自体を terminate
aws ec2 terminate-instances --instance-ids i-xxxxxxxxxxxxx --region us-east-1
```

## 7. トラブルシュート

| 症状 | 対処 |
|---|---|
| `mssql-conf setup` が hang する | TTY 環境じゃない場合、`-n` フラグ + 環境変数 (本ツールはこれを使用) |
| RESTORE で `Operating system error 5` | `/var/opt/mssql/backup` の owner が `mssql:mssql` か確認 |
| RESTORE で `LSN` エラー | bak が古い差分の場合、`WITH RECOVERY` 等の指定を `restore.yml` で調整 |
| SCT が「server certificate not trusted」 | SCT 接続設定で `Trust server certificate` を ON |
| `apt install mssql-server` が `no such package` | repo が Ubuntu 22.04 用に登録されているか確認 (jammy 固定) |
| ufw でロックアウト | SSH を許可 → playbook 内で `OpenSSH` ルールを先に追加済 |
| メモリ不足で SQL Server 起動失敗 | mssql-conf set memory.memorylimitmb 4096 等で調整 |

## 8. 参考リンク

- [Quickstart: Install SQL Server on Ubuntu (Microsoft Docs)](https://learn.microsoft.com/sql/linux/quickstart-install-connect-ubuntu)
- [SQL Server on Linux の機能制限](https://learn.microsoft.com/sql/linux/sql-server-linux-editions-and-components-2022)
- [AWS SCT — RDS for SQL Server を Source として未対応の Note](https://docs.aws.amazon.com/SchemaConversionTool/latest/userguide/CHAP_Source.SQLServer.html)
- [RDS for SQL Server Native Backup and Restore](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/SQLServer.Procedural.Importing.html)
