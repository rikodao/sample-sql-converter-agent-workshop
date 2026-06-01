#!/usr/bin/env bash
# ============================================================================
# destroy.sh - MSSQL → Aurora 検証スタックの削除
# ============================================================================
set -euo pipefail

export AWS_PAGER=""
STACK_NAME="MssqlToAuroraStack"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CDK_DIR="$PROJ_DIR/cdk"

cd "$CDK_DIR"

echo "=== Destroying $STACK_NAME ==="
npx cdk destroy "$STACK_NAME" --force

# ローカル成果物クリーンアップ
[[ -f "$PROJ_DIR/mssql-workbench-key.pem" ]] && rm -f "$PROJ_DIR/mssql-workbench-key.pem"
[[ -f "$PROJ_DIR/output.json" ]]              && rm -f "$PROJ_DIR/output.json"
[[ -f "$PROJ_DIR/ssh-config-mssql" ]]         && rm -f "$PROJ_DIR/ssh-config-mssql"

cat <<EOF
=== Destroy complete ===
[NOTE] Snapshots (DB instance & cluster) are NOT auto-deleted.
       Verify and remove manually if not needed:
         aws rds describe-db-snapshots         --query 'DBSnapshots[?contains(DBSnapshotIdentifier, \`mssql-to-aurora\`)]'
         aws rds describe-db-cluster-snapshots --query 'DBClusterSnapshots[?contains(DBClusterSnapshotIdentifier, \`mssql-to-aurora\`)]'
EOF
