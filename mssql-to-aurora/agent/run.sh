#!/usr/bin/env bash
# Bulk conversion runner.
# Usage:
#   ./run.sh                              # standard mode (single agent)
#   ./run.sh --multi-agent                # 4-stage pipeline
#   ./run.sh --multi-agent --avoid-throttling
#   ./run.sh -f custom_object_list.ini --multi-agent
set -euo pipefail

OBJECT_LIST="object_list.ini"
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--file)
      OBJECT_LIST="$2"; shift 2 ;;
    *)
      EXTRA_ARGS+=("$1"); shift ;;
  esac
done

if [[ ! -f "$OBJECT_LIST" ]]; then
  echo "Object list file not found: $OBJECT_LIST" >&2
  exit 1
fi

while IFS= read -r line || [[ -n "$line" ]]; do
  # コメント・空行スキップ
  [[ -z "${line// }" ]] && continue
  [[ "$line" =~ ^[[:space:]]*# ]] && continue

  echo "==== Processing: $line ===="
  uv run main.py --prompt "$line" "${EXTRA_ARGS[@]}" || {
    echo "[ERROR] Failed to process: $line"
  }
done < "$OBJECT_LIST"

echo "==== All done ===="
