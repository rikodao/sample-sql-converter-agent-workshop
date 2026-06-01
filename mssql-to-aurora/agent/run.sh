#!/usr/bin/env bash
# ============================================================================
# Bulk conversion runner for MSSQL → Aurora pipeline.
#
# Usage:
#   ./run.sh                              # standard mode (single agent, j=1)
#   ./run.sh --multi-agent                # 4-stage pipeline (sequential)
#   ./run.sh --multi-agent -j 3           # 3並列
#   ./run.sh --multi-agent --avoid-throttling
#   ./run.sh -f object_list_full.ini --multi-agent -j 2
#
# 並列実行時の注意:
#   - Bedrock の AWS account-level rate limit に注意 (Sonnet 4.5 は通常 50 RPM)
#   - 1 オブジェクト当たり 4 stages * ~30 LLM calls = ~120 calls
#   - 並列度 N が大きすぎると ThrottlingException が頻発する
#   - 推奨デフォルト: 2 並列、--avoid-throttling と併用するなら 3〜4
#   - 失敗したオブジェクトは標準エラーに記録される
# ============================================================================
set -euo pipefail

OBJECT_LIST="object_list.ini"
JOBS=1
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--file)
      OBJECT_LIST="$2"; shift 2 ;;
    -j|--jobs)
      JOBS="$2"; shift 2 ;;
    -h|--help)
      grep '^#' "$0" | head -20; exit 0 ;;
    *)
      EXTRA_ARGS+=("$1"); shift ;;
  esac
done

if [[ ! -f "$OBJECT_LIST" ]]; then
  echo "Object list file not found: $OBJECT_LIST" >&2
  exit 1
fi

if ! [[ "$JOBS" =~ ^[0-9]+$ ]] || [[ "$JOBS" -lt 1 ]]; then
  echo "Invalid -j value: $JOBS (must be positive integer)" >&2
  exit 1
fi

# 結果サマリー用ディレクトリ
LOG_DIR="./run-logs"
mkdir -p "$LOG_DIR"
TS=$(date '+%Y%m%d-%H%M%S')
SUMMARY_LOG="$LOG_DIR/run-$TS.log"
FAILED_LIST="$LOG_DIR/run-$TS.failed"
: > "$FAILED_LIST"

echo "=== run.sh start at $TS ==="
echo "Object list: $OBJECT_LIST"
echo "Parallel:    $JOBS"
echo "Extra args:  ${EXTRA_ARGS[*]:-(none)}"
echo "Log file:    $SUMMARY_LOG"
echo

# 対象一覧の読み込み (コメント・空行除外) - bash 3.2 互換
ITEMS=()
while IFS= read -r line || [[ -n "$line" ]]; do
  # コメント・空行スキップ
  case "$line" in
    ''|\#*) continue ;;
  esac
  # 末尾のCR削除 (Windows改行対策)
  line="${line%$'\r'}"
  # 行頭・行末の空白除去
  trimmed=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  [[ -z "$trimmed" ]] && continue
  case "$trimmed" in \#*) continue ;; esac
  ITEMS+=("$trimmed")
done < "$OBJECT_LIST"
TOTAL=${#ITEMS[@]}
echo "Total objects: $TOTAL"
echo

if [[ "$TOTAL" -eq 0 ]]; then
  echo "No objects to process." >&2
  exit 0
fi

# 1オブジェクトを処理する関数
# Args: $1=item, $2=index, $3=total, $4...=extra args for main.py
process_one() {
  local item="$1"
  local idx="$2"
  local total="$3"
  shift 3
  # xargs/bash -c 並列起動時に親シェルの env を引き継がないケースの保険として、
  # process_one 冒頭で .env を再 source する (AWS_REGION 等を確実に注入)。
  # 詳細は docs/run-results/2026-05-29/AUTO_EXTRACT_TEST.md §5.4 を参照。
  if [[ -f .env ]]; then
    set -a
    # shellcheck disable=SC1091
    . ./.env
    set +a
  fi
  local short
  short=$(echo "$item" | tr ' ' '_' | tr '/' '_' | tr -cd '[:alnum:]._-' | cut -c1-80)
  local item_log="$LOG_DIR/run-$TS.$short.log"

  local stamp
  stamp=$(date '+%H:%M:%S')
  echo "[$stamp] [$idx/$total] START: $item"
  if uv run main.py --prompt "$item" "$@" > "$item_log" 2>&1; then
    stamp=$(date '+%H:%M:%S')
    echo "[$stamp] [$idx/$total] OK:    $item"
    return 0
  else
    stamp=$(date '+%H:%M:%S')
    echo "[$stamp] [$idx/$total] FAIL:  $item (see $item_log)"
    echo "$item" >> "$FAILED_LIST"
    return 1
  fi
}
export -f process_one
export LOG_DIR TS FAILED_LIST TOTAL

if [[ "$JOBS" -eq 1 ]]; then
  # シーケンシャル: bash ループで実行（既存挙動に近い）
  IDX=0
  for item in "${ITEMS[@]}"; do
    IDX=$((IDX + 1))
    process_one "$item" "$IDX" "$TOTAL" "${EXTRA_ARGS[@]}" || true
  done | tee -a "$SUMMARY_LOG"
else
  # 並列: xargs -P。エクスポート可能でない bash 配列を避けるため、
  # extra args は printf で安全にエンコードして bash -c に渡す。
  # idx は 1から TOTAL まで事前に割り当てて流す（順序固定 = 入力順）。
  EXTRA_ARGS_QUOTED=$(printf '%q ' "${EXTRA_ARGS[@]:-}")

  # idx<TAB>item の形で流し、bash -c で分解
  for i in "${!ITEMS[@]}"; do
    printf '%d\t%s\0' "$((i + 1))" "${ITEMS[$i]}"
  done | xargs -0 -n 1 -P "$JOBS" -I {} bash -c '
      line="$1"
      idx="${line%%	*}"   # tab 区切り
      item="${line#*	}"
      process_one "$item" "$idx" "'"$TOTAL"'" '"$EXTRA_ARGS_QUOTED"'
    ' _ {} 2>&1 | tee -a "$SUMMARY_LOG" || true
fi

echo
echo "=== run.sh end at $(date '+%H:%M:%S') ==="
FAIL_COUNT=$(wc -l < "$FAILED_LIST" | tr -d ' ')
SUCCESS_COUNT=$((TOTAL - FAIL_COUNT))
echo "Success: $SUCCESS_COUNT / $TOTAL"
echo "Failed:  $FAIL_COUNT"
if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo "Failed objects:"
  cat "$FAILED_LIST" | sed 's/^/  /'
  echo
  echo "Per-object logs are in $LOG_DIR/"
  echo "To re-run only the failures:"
  echo "  ./run.sh ${EXTRA_ARGS[*]:-} -f $FAILED_LIST -j $JOBS"
fi

# 結果ディレクトリのサマリー
if [[ -d ./result ]]; then
  echo
  echo "=== result/ verdict counts ==="
  echo "BABELFISH_OK: $(find ./result -name BABELFISH_OK.txt 2>/dev/null | wc -l | tr -d ' ')"
  echo "OK (PG-nat):  $(find ./result -maxdepth 2 -name OK.txt 2>/dev/null | wc -l | tr -d ' ')"
  echo "NG:           $(find ./result -name NG.txt 2>/dev/null | wc -l | tr -d ' ')"
fi
