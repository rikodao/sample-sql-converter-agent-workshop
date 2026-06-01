#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — Ubuntu EC2 上で SCT ホストを self-bootstrap する
#
# このスクリプトは 「Ubuntu EC2 にログインして 1 コマンドで SQL Server を
# セットアップしたい」場合の入口。Ansible を localhost モードで実行する。
#
# 使い方:
#   curl -fsSL <raw-url>/scripts/bootstrap.sh | sudo bash
#       (リモートからのワンライナー)
#   または
#   sudo bash bootstrap.sh
#
# 環境変数で値を渡せる:
#   MSSQL_SA_PASSWORD                    SA パスワード (必須)
#   MSSQL_EDITION                        Developer (default) / Express / Standard / Enterprise
#   MSSQL_RESTORE_BAK_S3_URI             s3://bucket/path/file.bak (任意)
#   MSSQL_RESTORE_DATABASE_NAME          復元先 DB 名 (任意、bak 指定時は必須)
#   AWS_REGION                           us-east-1 (default)
#   FIREWALL_ALLOWED_CIDRS               カンマ区切り (任意、空 = 全許可)
# =============================================================================
set -euo pipefail

if [[ "$(id -u)" != "0" ]]; then
    echo "ERROR: このスクリプトは root で実行してください (sudo bash bootstrap.sh)" >&2
    exit 1
fi

# 必須環境変数
: "${MSSQL_SA_PASSWORD:?MSSQL_SA_PASSWORD を環境変数で指定してください}"

# デフォルト
MSSQL_EDITION="${MSSQL_EDITION:-Developer}"
AWS_REGION="${AWS_REGION:-us-east-1}"
MSSQL_RESTORE_BAK_S3_URI="${MSSQL_RESTORE_BAK_S3_URI:-}"
MSSQL_RESTORE_DATABASE_NAME="${MSSQL_RESTORE_DATABASE_NAME:-}"
FIREWALL_ALLOWED_CIDRS="${FIREWALL_ALLOWED_CIDRS:-}"

# Ubuntu 確認
if ! grep -q "Ubuntu" /etc/os-release; then
    echo "ERROR: Ubuntu 22.04 / 24.04 のみサポート (現: $(. /etc/os-release; echo "$NAME $VERSION_ID"))" >&2
    exit 1
fi

echo "[bootstrap] apt update + Ansible install"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq software-properties-common python3-pip
pip3 install --quiet --break-system-packages ansible boto3 botocore || pip3 install --quiet ansible boto3 botocore
ansible-galaxy collection install -q community.general

# 作業ディレクトリ (このスクリプトが置かれている前提) を決定
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$(cd "$SCRIPT_DIR/../ansible" && pwd)"

# 必要なら inventory / group_vars を template からコピー
[[ -f "$ANSIBLE_DIR/inventory.ini" ]] || cp "$ANSIBLE_DIR/inventory.ini.template" "$ANSIBLE_DIR/inventory.ini"
[[ -f "$ANSIBLE_DIR/group_vars/all.yml" ]] || cp "$ANSIBLE_DIR/group_vars/all.yml.template" "$ANSIBLE_DIR/group_vars/all.yml"

# ansible-playbook 実行 (localhost モード)
EXTRA_VARS=(
    "mssql_sa_password=${MSSQL_SA_PASSWORD}"
    "mssql_edition=${MSSQL_EDITION}"
    "aws_region=${AWS_REGION}"
)

if [[ -n "$MSSQL_RESTORE_BAK_S3_URI" ]]; then
    : "${MSSQL_RESTORE_DATABASE_NAME:?MSSQL_RESTORE_BAK_S3_URI を指定する場合 MSSQL_RESTORE_DATABASE_NAME も必須}"
    EXTRA_VARS+=(
        "mssql_restore_enabled=true"
        "mssql_restore_bak_s3_uri=${MSSQL_RESTORE_BAK_S3_URI}"
        "mssql_restore_database_name=${MSSQL_RESTORE_DATABASE_NAME}"
    )
fi

if [[ -n "$FIREWALL_ALLOWED_CIDRS" ]]; then
    # カンマ区切り → JSON list に変換
    cidr_json=$(echo "$FIREWALL_ALLOWED_CIDRS" | jq -R 'split(",")' 2>/dev/null || echo "[]")
    EXTRA_VARS+=("mssql_firewall_allowed_cidrs=${cidr_json}")
fi

EXTRA_VARS_STR=""
for v in "${EXTRA_VARS[@]}"; do
    EXTRA_VARS_STR+=" -e $v"
done

cd "$ANSIBLE_DIR"
echo "[bootstrap] ansible-playbook を実行 (localhost mode)"
# shellcheck disable=SC2086
ansible-playbook -i inventory.ini playbook.yml $EXTRA_VARS_STR

echo "==================================================================="
echo "[bootstrap] 完了"
echo "  接続: sqlcmd -S \$(curl -s ifconfig.me),1433 -U SA -P '<password>' -C -N"
echo "  確認: SELECT @@VERSION"
echo "==================================================================="
