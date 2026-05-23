#!/usr/bin/env bash
# ============================================================================
# deploy.sh - MSSQL → Aurora 移行検証スタックのデプロイ
#
# 接続方式: SSM Session Manager のみ (SSH 不使用、Key Pair なし)
#   接続:   aws ssm start-session --target <instance-id>
#   ポートFW: aws ssm start-session --target <id> \
#             --document-name AWS-StartPortForwardingSession \
#             --parameters '{"portNumber":["5432"],"localPortNumber":["15432"]}'
#
# Usage:
#   ./deploy.sh                                  # サンプルモード (デフォルト)
#   ./deploy.sh --source-mode snapshot \
#               --snapshot-id <SnapshotARN> \
#               --instance-class db.m5.xlarge
#   ./deploy.sh --skip-sample-load               # サンプル投入をスキップ
# ============================================================================
set -euo pipefail

export AWS_PAGER=""
STACK_NAME="MssqlToAuroraStack"

# --- 引数パース ---
SOURCE_MODE="sample"
SNAPSHOT_ID=""
INSTANCE_CLASS=""
SKIP_SAMPLE_LOAD="false"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --source-mode)      SOURCE_MODE="$2"; shift 2 ;;
        --snapshot-id)      SNAPSHOT_ID="$2"; shift 2 ;;
        --instance-class)   INSTANCE_CLASS="$2"; shift 2 ;;
        --skip-sample-load) SKIP_SAMPLE_LOAD="true"; shift ;;
        -h|--help)
            grep '^#' "$0" | head -25; exit 0 ;;
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

REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"

# --- CDK ビルド & デプロイ ---
cd "$CDK_DIR"
[[ -d node_modules ]] || npm ci

CDK_CONTEXT_ARGS=()
CDK_CONTEXT_ARGS+=("-c" "sourceMode=$SOURCE_MODE")
[[ -n "$SNAPSHOT_ID" ]]    && CDK_CONTEXT_ARGS+=("-c" "snapshotIdentifier=$SNAPSHOT_ID")
[[ -n "$INSTANCE_CLASS" ]] && CDK_CONTEXT_ARGS+=("-c" "sourceInstanceClass=$INSTANCE_CLASS")

echo "=== Deploying $STACK_NAME (sourceMode=$SOURCE_MODE) ==="
npx cdk deploy "$STACK_NAME" \
    --outputs-file "$PROJ_DIR/output.json" \
    --require-approval never \
    "${CDK_CONTEXT_ARGS[@]}"

# --- output.json から各種 ID/エンドポイントを取得 ---
OUTPUT_JSON="$PROJ_DIR/output.json"
SOURCE_HOST=$(jq -r --arg s "$STACK_NAME" '.[$s].SourceMssqlEndpoint' "$OUTPUT_JSON")
PG_HOST=$(jq -r --arg s "$STACK_NAME" '.[$s].TargetAuroraPgEndpoint' "$OUTPUT_JSON")
BBF_HOST=$(jq -r --arg s "$STACK_NAME" '.[$s].TargetBabelfishEndpoint' "$OUTPUT_JSON")
WORKBENCH_ID=$(jq -r --arg s "$STACK_NAME" '.[$s].WorkbenchInstanceId' "$OUTPUT_JSON")
EXTRACTION_BUCKET=$(jq -r --arg s "$STACK_NAME" '.[$s].ExtractionBucketName' "$OUTPUT_JSON")
SSM_CMD=$(jq -r --arg s "$STACK_NAME" '.[$s].WorkbenchSsmStartSessionCommand' "$OUTPUT_JSON")

# --- サンプルモード: SSM RunCommand でサンプル T-SQL を投入 ---
if [[ "$SOURCE_MODE" == "sample" && "$SKIP_SAMPLE_LOAD" == "false" ]]; then
    echo "=== Loading sample T-SQL via SSM RunCommand on workbench EC2 ==="

    # Workbench EC2 の UserData 完了待機
    echo "Waiting for workbench UserData to complete (up to 15 minutes)..."
    for i in $(seq 1 90); do
        STATUS=$(aws ec2 describe-instance-status \
            --instance-ids "$WORKBENCH_ID" \
            --query 'InstanceStatuses[0].InstanceStatus.Status' \
            --output text 2>/dev/null || echo "pending")
        if [[ "$STATUS" == "ok" ]]; then
            PING=$(aws ssm describe-instance-information \
                --filters "Key=InstanceIds,Values=$WORKBENCH_ID" \
                --query 'InstanceInformationList[0].PingStatus' \
                --output text 2>/dev/null || echo "")
            if [[ "$PING" == "Online" ]]; then
                CHECK=$(aws ssm send-command \
                    --instance-ids "$WORKBENCH_ID" \
                    --document-name AWS-RunShellScript \
                    --parameters 'commands=["test -f /var/log/userdata-complete && echo OK || echo PENDING"]' \
                    --query 'Command.CommandId' --output text)
                sleep 5
                RESULT=$(aws ssm get-command-invocation \
                    --command-id "$CHECK" \
                    --instance-id "$WORKBENCH_ID" \
                    --query 'StandardOutputContent' --output text 2>/dev/null | tr -d '\n' || echo "")
                if [[ "$RESULT" == "OK" ]]; then
                    echo "Workbench is ready (attempt $i)."
                    break
                fi
            fi
        fi
        echo "  attempt $i/90 (status=$STATUS) - waiting..."
        sleep 10
    done

    # SSM RunCommand でサンプル DDL 投入
    echo "Submitting SSM command to load sample_objects.sql..."
    LOAD_CMD=$(cat <<SHELLEOF
#!/bin/bash
set -e
export PATH="/opt/mssql-tools18/bin:\$PATH"
aws s3 cp s3://${EXTRACTION_BUCKET}/tests/ddl/sample_objects.sql /tmp/sample_objects.sql --region ${REGION}
SECRET=\$(aws secretsmanager get-secret-value --region ${REGION} --secret-id mssql-to-aurora/source-mssql-credentials --query SecretString --output text)
USER=\$(echo "\$SECRET" | jq -r .username)
PASS=\$(echo "\$SECRET" | jq -r .password)
echo "Loading sample_objects.sql into Source MSSQL @ ${SOURCE_HOST}..."
sqlcmd -S ${SOURCE_HOST},1433 -U "\$USER" -P "\$PASS" -C -N -i /tmp/sample_objects.sql -m 1
echo "Sample load complete."
SHELLEOF
)
    LOAD_CMD_ID=$(aws ssm send-command \
        --instance-ids "$WORKBENCH_ID" \
        --document-name AWS-RunShellScript \
        --comment "Load MSSQL sample T-SQL" \
        --parameters "commands=[$(echo "$LOAD_CMD" | jq -Rs .)]" \
        --cloud-watch-output-config 'CloudWatchOutputEnabled=true' \
        --query 'Command.CommandId' --output text)

    echo "SSM Command ID: $LOAD_CMD_ID"
    for i in $(seq 1 60); do
        STATUS=$(aws ssm list-commands --command-id "$LOAD_CMD_ID" \
            --query 'Commands[0].Status' --output text 2>/dev/null || echo "Pending")
        echo "  $(date '+%H:%M:%S') status=$STATUS"
        if [[ "$STATUS" == "Success" ]]; then
            aws ssm get-command-invocation --command-id "$LOAD_CMD_ID" --instance-id "$WORKBENCH_ID" \
                --query 'StandardOutputContent' --output text | tail -20
            echo "=== Sample T-SQL loaded successfully ==="
            break
        elif [[ "$STATUS" == "Failed" || "$STATUS" == "Cancelled" || "$STATUS" == "TimedOut" ]]; then
            echo "ERROR: SSM command failed."
            aws ssm get-command-invocation --command-id "$LOAD_CMD_ID" --instance-id "$WORKBENCH_ID" \
                --query 'StandardErrorContent' --output text
            aws ssm get-command-invocation --command-id "$LOAD_CMD_ID" --instance-id "$WORKBENCH_ID" \
                --query 'StandardOutputContent' --output text | tail -30
            exit 1
        fi
        sleep 15
    done
fi

# --- Workbench EC2 にエージェント一式を配布 ---
echo "=== Syncing agent code to workbench EC2 via S3 ==="
AGENT_TGZ="/tmp/mssql-agent-$(date +%s).tgz"
tar -C "$PROJ_DIR" -czf "$AGENT_TGZ" agent/
aws s3 cp "$AGENT_TGZ" "s3://${EXTRACTION_BUCKET}/agent/agent.tgz" --region "$REGION"
rm -f "$AGENT_TGZ"

SYNC_CMD=$(cat <<SHELLEOF
#!/bin/bash
set -e
mkdir -p /home/ec2-user/mssql-to-aurora
aws s3 cp s3://${EXTRACTION_BUCKET}/agent/agent.tgz /tmp/agent.tgz --region ${REGION}
tar -xzf /tmp/agent.tgz -C /home/ec2-user/mssql-to-aurora/
chown -R ec2-user:ec2-user /home/ec2-user/mssql-to-aurora
cat > /home/ec2-user/mssql-to-aurora/agent/.env <<ENVEOF
MSSQL_HOST=${SOURCE_HOST}
MSSQL_SECRET_NAME=mssql-to-aurora/source-mssql-credentials
BABELFISH_HOST=${BBF_HOST}
BABELFISH_SECRET_NAME=mssql-to-aurora/target-babelfish-credentials
BABELFISH_DB=babelfish_db
AURORA_PG_SECRET_NAME=mssql-to-aurora/target-pg-credentials
AURORA_PG_DBNAME=postgres
AWS_REGION=${REGION}
ENVEOF
chown ec2-user:ec2-user /home/ec2-user/mssql-to-aurora/agent/.env
echo "Agent synced to /home/ec2-user/mssql-to-aurora/agent/"
SHELLEOF
)
SYNC_CMD_ID=$(aws ssm send-command \
    --instance-ids "$WORKBENCH_ID" \
    --document-name AWS-RunShellScript \
    --parameters "commands=[$(echo "$SYNC_CMD" | jq -Rs .)]" \
    --query 'Command.CommandId' --output text)

for i in $(seq 1 30); do
    STATUS=$(aws ssm list-commands --command-id "$SYNC_CMD_ID" --query 'Commands[0].Status' --output text 2>/dev/null || echo "Pending")
    if [[ "$STATUS" == "Success" ]]; then
        echo "Agent sync complete."
        break
    elif [[ "$STATUS" =~ ^(Failed|Cancelled|TimedOut)$ ]]; then
        aws ssm get-command-invocation --command-id "$SYNC_CMD_ID" --instance-id "$WORKBENCH_ID" --query 'StandardErrorContent' --output text
        exit 1
    fi
    sleep 5
done

cat <<EOF

=== Deploy complete ===

Source MSSQL:        $SOURCE_HOST
Target Aurora PG:    $PG_HOST
Target Babelfish:    $BBF_HOST  (PG:5432, TDS:1433)
Workbench InstanceId: $WORKBENCH_ID
Extraction Bucket:   $EXTRACTION_BUCKET

Connect via SSM Session Manager (no SSH):
  $SSM_CMD

On workbench (after entering session):
  cd ~/mssql-to-aurora/agent
  uv sync
  set -a; source .env; set +a
  uv run main.py --multi-agent --prompt "PROCEDURE dbo.usp_calculate_employee_bonus"

Prerequisite: AWS CLI session-manager plugin
  https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html
EOF
