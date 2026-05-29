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
#   ./deploy.sh --source-mode snapshot \
#               --snapshot-id <SnapshotARN> \
#               --auto-extract                   # 復元 DB から自動でオブジェクト一覧抽出
# ============================================================================
set -euo pipefail

export AWS_PAGER=""
STACK_NAME="MssqlToAuroraStack"

# --- 引数パース ---
SOURCE_MODE="sample"
SNAPSHOT_ID=""
INSTANCE_CLASS=""
SKIP_SAMPLE_LOAD="false"
AUTO_EXTRACT="false"
EXTRACT_DATABASE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --source-mode)      SOURCE_MODE="$2"; shift 2 ;;
        --snapshot-id)      SNAPSHOT_ID="$2"; shift 2 ;;
        --instance-class)   INSTANCE_CLASS="$2"; shift 2 ;;
        --skip-sample-load) SKIP_SAMPLE_LOAD="true"; shift ;;
        --auto-extract)     AUTO_EXTRACT="true"; shift ;;
        --extract-database) EXTRACT_DATABASE="$2"; shift 2 ;;
        -h|--help)
            grep '^#' "$0" | head -28; exit 0 ;;
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

    # SSM RunCommand でサンプル DDL 投入 (basic + advanced)
    echo "Submitting SSM command to load sample_objects.sql + sample_objects_advanced.sql..."
    # JSON parameters をファイル経由で渡す（heredoc + jq の shebang問題を回避）
    PARAMS_FILE=$(mktemp)
    jq -n \
      --arg bucket "$EXTRACTION_BUCKET" \
      --arg region "$REGION" \
      --arg host "$SOURCE_HOST" \
      '{
        commands: [
          "set -e",
          "export PATH=/opt/mssql-tools18/bin:$PATH",
          ("aws s3 cp s3://" + $bucket + "/tests/ddl/sample_objects.sql /tmp/sample_objects.sql --region " + $region),
          ("aws s3 cp s3://" + $bucket + "/tests/ddl/sample_objects_advanced.sql /tmp/sample_objects_advanced.sql --region " + $region + " 2>/dev/null || echo \"advanced sample not present, skipping\""),
          ("SECRET=$(aws secretsmanager get-secret-value --region " + $region + " --secret-id mssql-to-aurora/source-mssql-credentials --query SecretString --output text)"),
          "USER=$(echo \"$SECRET\" | jq -r .username)",
          "PASS=$(echo \"$SECRET\" | jq -r .password)",
          ("echo \"[1/2] Loading sample_objects.sql into Source MSSQL @ " + $host + "...\""),
          ("sqlcmd -S " + $host + ",1433 -U \"$USER\" -P \"$PASS\" -C -N -i /tmp/sample_objects.sql -m 1"),
          ("if [ -f /tmp/sample_objects_advanced.sql ]; then echo \"[2/2] Loading sample_objects_advanced.sql...\"; sqlcmd -S " + $host + ",1433 -U \"$USER\" -P \"$PASS\" -C -N -i /tmp/sample_objects_advanced.sql -m 1; fi"),
          "echo Sample load complete."
        ]
      }' > "$PARAMS_FILE"

    LOAD_CMD_ID=$(aws ssm send-command \
        --instance-ids "$WORKBENCH_ID" \
        --document-name AWS-RunShellScript \
        --comment "Load MSSQL sample T-SQL" \
        --parameters "file://$PARAMS_FILE" \
        --cloud-watch-output-config 'CloudWatchOutputEnabled=true' \
        --query 'Command.CommandId' --output text)
    rm -f "$PARAMS_FILE"

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
tar -C "$PROJ_DIR" -czf "$AGENT_TGZ" agent/ extraction/
aws s3 cp "$AGENT_TGZ" "s3://${EXTRACTION_BUCKET}/agent/agent.tgz" --region "$REGION"
rm -f "$AGENT_TGZ"

SYNC_PARAMS_FILE=$(mktemp)
jq -n \
  --arg bucket "$EXTRACTION_BUCKET" \
  --arg region "$REGION" \
  --arg host "$SOURCE_HOST" \
  --arg bbf "$BBF_HOST" \
  '{
    commands: [
      "set -e",
      "mkdir -p /home/ec2-user/mssql-to-aurora",
      ("aws s3 cp s3://" + $bucket + "/agent/agent.tgz /tmp/agent.tgz --region " + $region),
      "tar -xzf /tmp/agent.tgz -C /home/ec2-user/mssql-to-aurora/",
      "chown -R ec2-user:ec2-user /home/ec2-user/mssql-to-aurora",
      ("printf \"MSSQL_HOST=" + $host + "\\nMSSQL_SECRET_NAME=mssql-to-aurora/source-mssql-credentials\\nMSSQL_DATABASE=migration_demo\\nBABELFISH_HOST=" + $bbf + "\\nBABELFISH_SECRET_NAME=mssql-to-aurora/target-babelfish-credentials\\nBABELFISH_DB=babelfish_db\\nAURORA_PG_SECRET_NAME=mssql-to-aurora/target-pg-credentials\\nAURORA_PG_DBNAME=postgres\\nAWS_REGION=" + $region + "\\n\" > /home/ec2-user/mssql-to-aurora/agent/.env"),
      "chown ec2-user:ec2-user /home/ec2-user/mssql-to-aurora/agent/.env",
      "echo Agent synced to /home/ec2-user/mssql-to-aurora/agent/"
    ]
  }' > "$SYNC_PARAMS_FILE"

SYNC_CMD_ID=$(aws ssm send-command \
    --instance-ids "$WORKBENCH_ID" \
    --document-name AWS-RunShellScript \
    --parameters "file://$SYNC_PARAMS_FILE" \
    --query 'Command.CommandId' --output text)
rm -f "$SYNC_PARAMS_FILE"

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

# --- (任意) 自動抽出: Source MSSQL から object_list.ini を生成 ---
EXTRACTED_OBJECT_LIST=""
if [[ "$AUTO_EXTRACT" == "true" ]]; then
    echo "=== Auto-extracting object list from Source MSSQL ==="
    # 対象 DB 名: 明示指定 > sample モード(migration_demo) > 自動検出を要求
    EXTRACT_DB="${EXTRACT_DATABASE:-}"
    if [[ -z "$EXTRACT_DB" ]]; then
        if [[ "$SOURCE_MODE" == "sample" ]]; then
            EXTRACT_DB="migration_demo"
        else
            echo "ERROR: --auto-extract with --source-mode=snapshot requires --extract-database <dbname>" >&2
            echo "       (Snapshot 内のどの DB を抽出対象とするか指定してください)" >&2
            exit 1
        fi
    fi
    echo "Target database: $EXTRACT_DB"

    EXTRACT_PARAMS_FILE=$(mktemp)
    jq -n \
      --arg bucket "$EXTRACTION_BUCKET" \
      --arg region "$REGION" \
      --arg db "$EXTRACT_DB" \
      '{
        commands: [
          "set -e",
          "export PATH=/opt/mssql-tools18/bin:$PATH",
          "cd /home/ec2-user/mssql-to-aurora/extraction/scripts",
          "chmod +x export-ddl.sh generate-object-list.sh",
          ("MSSQL_DATABASE=" + $db + " sudo -E -u ec2-user bash export-ddl.sh"),
          "sudo -u ec2-user bash generate-object-list.sh",
          "OUT=/home/ec2-user/mssql-to-aurora/extraction/output",
          ("aws s3 cp $OUT/objects.csv s3://" + $bucket + "/extraction/objects.csv --region " + $region),
          ("aws s3 cp $OUT/object_list.ini s3://" + $bucket + "/extraction/object_list.ini --region " + $region),
          "echo Auto-extract complete."
        ]
      }' > "$EXTRACT_PARAMS_FILE"

    EXTRACT_CMD_ID=$(aws ssm send-command \
        --instance-ids "$WORKBENCH_ID" \
        --document-name AWS-RunShellScript \
        --comment "Auto-extract object list from MSSQL" \
        --parameters "file://$EXTRACT_PARAMS_FILE" \
        --cloud-watch-output-config 'CloudWatchOutputEnabled=true' \
        --query 'Command.CommandId' --output text)
    rm -f "$EXTRACT_PARAMS_FILE"

    echo "SSM Command ID: $EXTRACT_CMD_ID"
    for i in $(seq 1 60); do
        STATUS=$(aws ssm list-commands --command-id "$EXTRACT_CMD_ID" --query 'Commands[0].Status' --output text 2>/dev/null || echo "Pending")
        echo "  $(date '+%H:%M:%S') status=$STATUS"
        if [[ "$STATUS" == "Success" ]]; then
            aws ssm get-command-invocation --command-id "$EXTRACT_CMD_ID" --instance-id "$WORKBENCH_ID" \
                --query 'StandardOutputContent' --output text | tail -20
            # ローカルにダウンロード
            EXTRACTED_OBJECT_LIST="$PROJ_DIR/extraction/output/object_list.ini"
            mkdir -p "$(dirname "$EXTRACTED_OBJECT_LIST")"
            aws s3 cp "s3://${EXTRACTION_BUCKET}/extraction/object_list.ini" "$EXTRACTED_OBJECT_LIST" --region "$REGION"
            aws s3 cp "s3://${EXTRACTION_BUCKET}/extraction/objects.csv"     "$PROJ_DIR/extraction/output/objects.csv"     --region "$REGION"
            echo "=== Object list downloaded to: $EXTRACTED_OBJECT_LIST ==="
            break
        elif [[ "$STATUS" =~ ^(Failed|Cancelled|TimedOut)$ ]]; then
            echo "ERROR: extraction failed."
            aws ssm get-command-invocation --command-id "$EXTRACT_CMD_ID" --instance-id "$WORKBENCH_ID" \
                --query 'StandardErrorContent' --output text
            aws ssm get-command-invocation --command-id "$EXTRACT_CMD_ID" --instance-id "$WORKBENCH_ID" \
                --query 'StandardOutputContent' --output text | tail -30
            exit 1
        fi
        sleep 10
    done
fi

cat <<EOF

=== Deploy complete ===

Source MSSQL:        $SOURCE_HOST
Target Aurora PG:    $PG_HOST
Target Babelfish:    $BBF_HOST  (PG:5432, TDS:1433)
Workbench InstanceId: $WORKBENCH_ID
Extraction Bucket:   $EXTRACTION_BUCKET
EOF

if [[ -n "$EXTRACTED_OBJECT_LIST" ]]; then
cat <<EOF

Auto-extracted object list (use as -f option to run.sh):
  $EXTRACTED_OBJECT_LIST

  cd ~/mssql-to-aurora/agent
  ./run.sh --multi-agent -f /path/to/extracted/object_list.ini -j 3
EOF
fi

cat <<EOF

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
