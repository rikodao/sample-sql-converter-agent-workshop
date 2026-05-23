#!/usr/bin/env bash
# ============================================================================
# deploy.sh - MSSQL → Aurora 移行検証スタックのデプロイ
#
# Usage:
#   ./deploy.sh                              # サンプルモード (デフォルト)
#   ./deploy.sh --source-mode snapshot \
#               --snapshot-id <SnapshotARN> \
#               --instance-class db.m5.xlarge
# ============================================================================
set -euo pipefail

export AWS_PAGER=""
STACK_NAME="MssqlToAuroraStack"

# --- 引数パース ---
SOURCE_MODE="sample"
SNAPSHOT_ID=""
INSTANCE_CLASS=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --source-mode)    SOURCE_MODE="$2"; shift 2 ;;
        --snapshot-id)    SNAPSHOT_ID="$2"; shift 2 ;;
        --instance-class) INSTANCE_CLASS="$2"; shift 2 ;;
        -h|--help)
            grep '^#' "$0" | head -20; exit 0 ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
    esac
done

if [[ "$SOURCE_MODE" == "snapshot" && -z "$SNAPSHOT_ID" ]]; then
    echo "ERROR: --snapshot-id is required when --source-mode=snapshot" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CDK_DIR="$PROJ_DIR/cdk"

# --- CDK ビルド & デプロイ ---
cd "$CDK_DIR"
npm ci

CDK_CONTEXT_ARGS=()
CDK_CONTEXT_ARGS+=("-c" "sourceMode=$SOURCE_MODE")
[[ -n "$SNAPSHOT_ID" ]]    && CDK_CONTEXT_ARGS+=("-c" "snapshotIdentifier=$SNAPSHOT_ID")
[[ -n "$INSTANCE_CLASS" ]] && CDK_CONTEXT_ARGS+=("-c" "sourceInstanceClass=$INSTANCE_CLASS")

echo "=== Deploying $STACK_NAME (sourceMode=$SOURCE_MODE) ==="
npx cdk deploy "$STACK_NAME" \
    --outputs-file "$PROJ_DIR/output.json" \
    --require-approval never \
    "${CDK_CONTEXT_ARGS[@]}"

# --- Workbench Key 取得 ---
echo "=== Retrieving workbench EC2 key pair ==="
KEY_RETRIEVAL_CMD=$(jq -r --arg s "$STACK_NAME" '.[$s].WorkbenchKeyPairRetrievalCommand' "$PROJ_DIR/output.json")
[[ -f "$PROJ_DIR/mssql-workbench-key.pem" ]] && rm -f "$PROJ_DIR/mssql-workbench-key.pem"
( cd "$CDK_DIR" && eval "$KEY_RETRIEVAL_CMD" )
ls -la "$PROJ_DIR/mssql-workbench-key.pem"

# --- ssh-config 生成 ---
INSTANCE_ID=$(jq -r --arg s "$STACK_NAME" '.[$s].WorkbenchInstanceId' "$PROJ_DIR/output.json")
REGION=${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}
cat > "$PROJ_DIR/ssh-config-mssql" <<EOF
Host workbench
    HostName $INSTANCE_ID
    User ec2-user
    IdentityFile $PROJ_DIR/mssql-workbench-key.pem
    ProxyCommand sh -c "aws ec2-instance-connect open-tunnel --instance-id %h --region $REGION"
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF

echo "=== ssh-config-mssql written ==="
cat "$PROJ_DIR/ssh-config-mssql"

# --- サンプルモードのみ: サンプル DDL を投入 ---
if [[ "$SOURCE_MODE" == "sample" ]]; then
    echo "=== Loading sample T-SQL into Source MSSQL ==="

    SOURCE_HOST=$(jq -r --arg s "$STACK_NAME" '.[$s].SourceMssqlEndpoint' "$PROJ_DIR/output.json")
    EXTRACTION_BUCKET=$(jq -r --arg s "$STACK_NAME" '.[$s].ExtractionBucketName' "$PROJ_DIR/output.json")

    cat <<MSG
[INFO] Source MSSQL endpoint: $SOURCE_HOST
[INFO] Sample DDL is already uploaded to s3://$EXTRACTION_BUCKET/tests/ddl/sample_objects.sql
[INFO] Sample DDL load is performed manually for now (Phase A scaffolding):
       1. ssh -F ssh-config-mssql workbench
       2. aws s3 cp s3://$EXTRACTION_BUCKET/tests/ddl/sample_objects.sql /tmp/
       3. SECRET=\$(aws secretsmanager get-secret-value --secret-id mssql-to-aurora/source-mssql-credentials --query SecretString --output text)
       4. USER=\$(echo \$SECRET | jq -r .username); PASS=\$(echo \$SECRET | jq -r .password)
       5. sqlcmd -S $SOURCE_HOST,1433 -U \$USER -P \$PASS -C -N -i /tmp/sample_objects.sql

[NOTE] The above will be automated via SSM RunCommand in Phase B.
MSG
fi

echo ""
echo "=== Deploy complete ==="
echo "Connect: ssh -F ssh-config-mssql workbench"
