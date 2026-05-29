#!/usr/bin/env bash
# ============================================================================
# export-ddl.sh
# Source RDS for SQL Server からオブジェクト情報を抽出する。
#
# 主な用途:
#   1. object_list.ini 生成用の軽量オブジェクト一覧取得 (デフォルト)
#   2. (将来) 完全な DDL / 依存関係 / テーブルメタデータ抽出
#
# 実行環境:
#   Workbench EC2 上で実行することを想定 (msodbcsql18 / mssql-tools18 必須)
#   または .env と同等の環境変数がセットされた任意の環境
#
# 必要な環境変数 (agent/.env から source されることを想定):
#   MSSQL_HOST          - SQL Server エンドポイント
#   MSSQL_DATABASE      - データベース名 (例: migration_demo, YourAppDb)
#   MSSQL_SECRET_NAME   - Secrets Manager のシークレット名
#                         (username/password を含む JSON)
#   AWS_REGION          - リージョン (Secrets Manager 取得用)
#
# 出力:
#   $OUT_DIR/objects.csv  - object_type,schema_name,object_name,is_encrypted
#
# Usage:
#   ./export-ddl.sh                               # デフォルト出力先 (./output/)
#   OUT_DIR=/tmp/extract ./export-ddl.sh          # 出力先カスタム
#   MSSQL_DATABASE=YourAppDb ./export-ddl.sh      # 対象 DB 切替
# ============================================================================
set -euo pipefail

# --- 環境変数チェック ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ENV_FILE="${HOME}/mssql-to-aurora/agent/.env"

if [[ -z "${MSSQL_HOST:-}" && -f "$DEFAULT_ENV_FILE" ]]; then
    echo "[INFO] Loading env from $DEFAULT_ENV_FILE" >&2
    set -a
    # shellcheck disable=SC1090
    source "$DEFAULT_ENV_FILE"
    set +a
fi

REQUIRED_VARS=(MSSQL_HOST MSSQL_DATABASE MSSQL_SECRET_NAME)
for var in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        echo "[ERROR] Required env var not set: $var" >&2
        echo "        Set it directly or via .env file ($DEFAULT_ENV_FILE)" >&2
        exit 1
    fi
done
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"

# --- 出力先 ---
OUT_DIR="${OUT_DIR:-$SCRIPT_DIR/../output}"
mkdir -p "$OUT_DIR"

# --- ツール依存チェック ---
SQLCMD_BIN=""
for candidate in /opt/mssql-tools18/bin/sqlcmd /opt/mssql-tools/bin/sqlcmd sqlcmd; do
    if command -v "$candidate" >/dev/null 2>&1; then
        SQLCMD_BIN="$candidate"
        break
    fi
done
if [[ -z "$SQLCMD_BIN" ]]; then
    echo "[ERROR] sqlcmd not found. Install msodbcsql18 + mssql-tools18." >&2
    exit 1
fi
command -v jq  >/dev/null 2>&1 || { echo "[ERROR] jq not found"  >&2; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "[ERROR] aws CLI not found" >&2; exit 1; }

# --- 認証情報を Secrets Manager から取得 ---
echo "[INFO] Fetching credentials from Secrets Manager: $MSSQL_SECRET_NAME" >&2
SECRET_JSON=$(aws secretsmanager get-secret-value \
    --region "$REGION" \
    --secret-id "$MSSQL_SECRET_NAME" \
    --query SecretString --output text)
MSSQL_USER=$(echo "$SECRET_JSON" | jq -r .username)
MSSQL_PASS=$(echo "$SECRET_JSON" | jq -r .password)

if [[ -z "$MSSQL_USER" || -z "$MSSQL_PASS" || "$MSSQL_USER" == "null" ]]; then
    echo "[ERROR] Could not extract username/password from secret" >&2
    exit 1
fi

# --- sqlcmd 共通オプション ---
SQLCMD_OPTS=(
    -S "${MSSQL_HOST},1433"
    -d "$MSSQL_DATABASE"
    -U "$MSSQL_USER"
    -P "$MSSQL_PASS"
    -C            # サーバ証明書を信頼 (RDS は CA チェーンが標準と異なる)
    -N            # 暗号化接続
    -h -1         # ヘッダ抑止
    -W            # 末尾空白除去
    -s ','        # カラム区切り
    -m 1          # エラー時に即座に終了
)

LIST_SQL="$SCRIPT_DIR/list-objects.sql"
if [[ ! -f "$LIST_SQL" ]]; then
    echo "[ERROR] SQL not found: $LIST_SQL" >&2
    exit 1
fi

OBJECTS_CSV="$OUT_DIR/objects.csv"
echo "[INFO] Extracting object list from $MSSQL_HOST/$MSSQL_DATABASE" >&2
echo "[INFO] Using SQL: $LIST_SQL" >&2
echo "[INFO] Output:    $OBJECTS_CSV" >&2

# CSV ヘッダを書く + sqlcmd 実行結果を追記
{
    echo "object_type,schema_name,object_name,is_encrypted_or_unavailable"
    "$SQLCMD_BIN" "${SQLCMD_OPTS[@]}" -i "$LIST_SQL" \
        | grep -v '^$' \
        | grep -vE '^\(.*rows? affected\)$' \
        | sed -E 's/[[:space:]]+,/,/g; s/,[[:space:]]+/,/g; s/[[:space:]]+$//'
} > "$OBJECTS_CSV"

# --- 結果サマリ ---
TOTAL=$(($(wc -l < "$OBJECTS_CSV") - 1))
ENCRYPTED=$(awk -F, 'NR>1 && $4==1 {n++} END{print n+0}' "$OBJECTS_CSV")
echo "[INFO] Total objects extracted: $TOTAL"
echo "[INFO]   - convertible:         $((TOTAL - ENCRYPTED))"
echo "[INFO]   - encrypted/unavail:   $ENCRYPTED"
echo "[INFO] Output saved to: $OBJECTS_CSV"
