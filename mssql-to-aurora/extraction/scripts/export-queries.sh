#!/usr/bin/env bash
# ============================================================================
# export-queries.sh
# Source RDS for SQL Server の Query Store から、
# 過去にアプリが実行した SQL を集約形式で全量取得する。
#
# 用途:
# - 移行対象オブジェクトの実呼出頻度の把握 (実行ゼロ = 移行不要)
# - アプリが投げる代表クエリの T-SQL 構文の Babelfish 互換評価
# - パフォーマンスベースライン取得
#
# 前提:
# - SQL Server 2016 以降
# - 対象 DB で Query Store が有効化されている
#   無効の場合: Snapshot 復元元 DB で先に有効化しておく必要がある
#     ALTER DATABASE [YourAppDb] SET QUERY_STORE = ON
#         (OPERATION_MODE = READ_WRITE, QUERY_CAPTURE_MODE = AUTO);
#
# 実行環境:
#   Workbench EC2 上で実行することを想定 (msodbcsql18 / mssql-tools18 必須)
#
# 必要な環境変数 (agent/.env から source されることを想定):
#   MSSQL_HOST          - SQL Server エンドポイント
#   MSSQL_DATABASE      - データベース名
#   MSSQL_SECRET_NAME   - Secrets Manager のシークレット名
#   AWS_REGION          - リージョン
#
# 出力:
#   $OUT_DIR/queries.csv  - query_hash, sample_text, schema_name, object_name,
#                           object_type, variant_count, total_executions,
#                           avg_duration_ms, max_duration_ms, total_logical_reads,
#                           first_execution_time, last_execution_time
#
# Usage:
#   ./export-queries.sh
#   OUT_DIR=/tmp/extract ./export-queries.sh
#   MSSQL_DATABASE=YourAppDb ./export-queries.sh
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

# --- Query Store 有効性チェック (事前) ---
echo "[INFO] Checking Query Store status on $MSSQL_DATABASE" >&2
QS_STATUS=$("$SQLCMD_BIN" \
    -S "${MSSQL_HOST},1433" \
    -d "master" \
    -U "$MSSQL_USER" -P "$MSSQL_PASS" \
    -C -N -h -1 -W \
    -Q "SET NOCOUNT ON; SELECT is_query_store_on FROM sys.databases WHERE name = N'$MSSQL_DATABASE';" \
    | head -1 | tr -d '[:space:]')

if [[ "$QS_STATUS" != "1" ]]; then
    echo "[ERROR] Query Store is NOT enabled on $MSSQL_DATABASE (is_query_store_on=$QS_STATUS)" >&2
    echo "        Enable it on the database before running this script:" >&2
    echo "          ALTER DATABASE [$MSSQL_DATABASE] SET QUERY_STORE = ON" >&2
    echo "              (OPERATION_MODE = READ_WRITE, QUERY_CAPTURE_MODE = AUTO);" >&2
    echo "" >&2
    echo "        If working with a Snapshot from production, the Query Store" >&2
    echo "        data is preserved if it was enabled at snapshot time." >&2
    exit 2
fi
echo "[INFO] Query Store is enabled on $MSSQL_DATABASE" >&2

# --- sqlcmd 共通オプション ---
SQLCMD_OPTS=(
    -S "${MSSQL_HOST},1433"
    -d "$MSSQL_DATABASE"
    -U "$MSSQL_USER"
    -P "$MSSQL_PASS"
    -C
    -N
    -h -1
    -W
    -s ','
    -m 1
)

LIST_SQL="$SCRIPT_DIR/list-queries.sql"
if [[ ! -f "$LIST_SQL" ]]; then
    echo "[ERROR] SQL not found: $LIST_SQL" >&2
    exit 1
fi

QUERIES_CSV="$OUT_DIR/queries.csv"
echo "[INFO] Extracting Query Store data from $MSSQL_HOST/$MSSQL_DATABASE" >&2
echo "[INFO] Using SQL: $LIST_SQL" >&2
echo "[INFO] Output:    $QUERIES_CSV" >&2

# CSV ヘッダ + sqlcmd 結果を追記
{
    echo "query_hash,sample_text,schema_name,object_name,object_type,variant_count,total_executions,avg_duration_ms,max_duration_ms,total_logical_reads,first_execution_time,last_execution_time"
    "$SQLCMD_BIN" "${SQLCMD_OPTS[@]}" -i "$LIST_SQL" \
        | grep -v '^$' \
        | grep -vE '^\(.*rows? affected\)$' \
        | sed -E 's/[[:space:]]+,/,/g; s/,[[:space:]]+/,/g; s/[[:space:]]+$//'
} > "$QUERIES_CSV"

# --- サマリ ---
TOTAL=$(($(wc -l < "$QUERIES_CSV") - 1))
echo "[INFO] Total unique query patterns extracted: $TOTAL"
if [[ "$TOTAL" -gt 0 ]]; then
    TOTAL_EXEC=$(awk -F, 'NR>1 {sum += $7} END {print sum+0}' "$QUERIES_CSV")
    echo "[INFO]   sum(total_executions) = $TOTAL_EXEC"
fi
echo "[INFO] Output saved to: $QUERIES_CSV"
