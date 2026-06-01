#!/usr/bin/env bash
# =============================================================================
# run-ansible.sh — ローカル端末から SCT ホストへ Ansible を流すヘルパー
#
# Usage:
#   ./run-ansible.sh                                  # inventory.ini 既存前提
#   MSSQL_SA_PASSWORD=xxx ./run-ansible.sh
#   ./run-ansible.sh --tags install,configure        # タグ指定
#   ./run-ansible.sh --check                          # dry-run
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$(cd "$SCRIPT_DIR/../ansible" && pwd)"

cd "$ANSIBLE_DIR"

# 必須ファイルチェック
if [[ ! -f inventory.ini ]]; then
    echo "ERROR: $ANSIBLE_DIR/inventory.ini がありません。" >&2
    echo "  cp inventory.ini.template inventory.ini して編集してください。" >&2
    exit 1
fi
if [[ ! -f group_vars/all.yml ]]; then
    echo "ERROR: $ANSIBLE_DIR/group_vars/all.yml がありません。" >&2
    echo "  cp group_vars/all.yml.template group_vars/all.yml して編集してください。" >&2
    exit 1
fi

EXTRA_VARS=()
[[ -n "${MSSQL_SA_PASSWORD:-}" ]] && EXTRA_VARS+=("-e" "mssql_sa_password=${MSSQL_SA_PASSWORD}")
[[ -n "${MSSQL_RESTORE_BAK_S3_URI:-}" ]] && EXTRA_VARS+=(
    "-e" "mssql_restore_enabled=true"
    "-e" "mssql_restore_bak_s3_uri=${MSSQL_RESTORE_BAK_S3_URI}"
)
[[ -n "${MSSQL_RESTORE_DATABASE_NAME:-}" ]] && EXTRA_VARS+=("-e" "mssql_restore_database_name=${MSSQL_RESTORE_DATABASE_NAME}")

ansible-playbook -i inventory.ini playbook.yml "${EXTRA_VARS[@]}" "$@"
