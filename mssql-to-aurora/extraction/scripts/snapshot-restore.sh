#!/usr/bin/env bash
# Snapshot 復元後の RDS 接続疎通確認スクリプト。
# CDK で復元済みの想定で、ここでは「接続できることの確認」と「DB 一覧取得」のみ行う。
#
# 使い方:
#   export MSSQL_HOST=...
#   export MSSQL_USER=...
#   export MSSQL_PASS=...
#   ./snapshot-restore.sh
set -euo pipefail

: "${MSSQL_HOST:?MSSQL_HOST not set}"
: "${MSSQL_USER:?MSSQL_USER not set}"
: "${MSSQL_PASS:?MSSQL_PASS not set}"

OUTDIR="${OUTDIR:-../output}"
mkdir -p "$OUTDIR"

echo "=== Connection test ==="
sqlcmd -S "$MSSQL_HOST,1433" -U "$MSSQL_USER" -P "$MSSQL_PASS" -C -N \
  -Q "SELECT @@VERSION;"

echo "=== DB list ==="
sqlcmd -S "$MSSQL_HOST,1433" -U "$MSSQL_USER" -P "$MSSQL_PASS" -C -N \
  -h-1 -W \
  -Q "SET NOCOUNT ON; SELECT name FROM sys.databases WHERE database_id > 4 ORDER BY name;" \
  | tee "$OUTDIR/db_list.txt"

echo "Done. Use export-ddl.sh next."
