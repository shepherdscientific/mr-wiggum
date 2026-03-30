#!/bin/bash
# cost-report.sh — Summarise implementation cost from cost_log.jsonl
#
# Usage:
#   ./cost-report.sh                              # summary table by model
#   ./cost-report.sh --by-iteration               # show every iteration row
#   ./cost-report.sh --raw                        # dump raw JSONL
#   ./cost-report.sh --log /path/to/cost_log.jsonl
#
# Output metrics:
#   - Runs, stories completed, token counts, total cost — grouped by model
#   - Cost per story completed (the key benchmark metric)
#
# Notes:
#   Token/cost data is best-effort from ralph.sh parsing. For amp, gemini,
#   and opencode where stdout parsing is unreliable, route through OpenRouter
#   for unified spend tracking, or add cost_usd manually to cost_log.jsonl.
#   cost_log.jsonl is JSONL — one JSON object per line.
#
# Requires: jq

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/cost_log.jsonl"
MODE="summary"

while [[ $# -gt 0 ]]; do
  case $1 in
    --raw)            MODE="raw";        shift ;;
    --by-iteration)   MODE="iterations"; shift ;;
    --log)            LOG_FILE="$2";     shift 2 ;;
    --log=*)          LOG_FILE="${1#*=}"; shift ;;
    *) shift ;;
  esac
done

if [ ! -f "$LOG_FILE" ]; then
  echo "No cost log found at: $LOG_FILE"
  echo "Run ralph.sh first to generate cost data."
  exit 0
fi

LINE_COUNT=$(wc -l < "$LOG_FILE" | tr -d ' ')
if [ "$LINE_COUNT" -eq 0 ]; then
  echo "Cost log is empty: $LOG_FILE"
  exit 0
fi

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  Ralph Cost Report"
echo "  Log: $LOG_FILE  ($LINE_COUNT iterations recorded)"
echo "══════════════════════════════════════════════════════════════"

case "$MODE" in

  "raw")
    cat "$LOG_FILE"
    ;;

  "iterations")
    echo ""
    printf '%-22s %-10s %-36s %5s %10s %10s %8s %9s\n' \
      "Timestamp" "Tool" "Model" "Iter" "Tokens In" "Tokens Out" "Stories" "Cost USD"
    printf '%-22s %-10s %-36s %5s %10s %10s %8s %9s\n' \
      "----------------------" "----------" "------------------------------------" "-----" "----------" "----------" "--------" "---------"
    jq -r '
      [
        .ts[0:19],
        .tool,
        .model,
        (.iteration | tostring),
        (.tokens_in | tostring),
        (.tokens_out | tostring),
        (.stories_passed_delta | tostring),
        (if .cost_usd == null then "n/a" else ("$" + (.cost_usd | tostring)) end)
      ] | @tsv
    ' "$LOG_FILE" | \
    awk -F'\t' '{ printf "%-22s %-10s %-36s %5s %10s %10s %8s %9s\n", $1, $2, $3, $4, $5, $6, $7, $8 }'
    echo ""
    ;;

  "summary")
    echo ""
    echo "── By model ──────────────────────────────────────────────────"
    echo ""
    printf '%-36s %5s %7s %12s %12s %10s %12s\n' \
      "Model" "Runs" "Stories" "Tokens In" "Tokens Out" "Cost USD" "Cost/Story"
    printf '%-36s %5s %7s %12s %12s %10s %12s\n' \
      "------------------------------------" "-----" "-------" "------------" "------------" "----------" "------------"

    jq -rs '
      group_by(.model) |
      map({
        model:      .[0].model,
        runs:       length,
        stories:    (map(.stories_passed_delta) | add // 0),
        tokens_in:  (map(.tokens_in)  | add // 0),
        tokens_out: (map(.tokens_out) | add // 0),
        cost_usd:   (map(select(.cost_usd != null) | .cost_usd) | if length > 0 then add else null end)
      }) |
      .[] |
      [
        .model,
        (.runs     | tostring),
        (.stories  | tostring),
        (.tokens_in  | tostring),
        (.tokens_out | tostring),
        (if .cost_usd == null then "n/a" else ("$" + (.cost_usd | tostring)) end),
        (if .cost_usd == null or .stories == 0 then "n/a"
         else ("$" + ((.cost_usd / .stories * 100 | round) / 100 | tostring))
         end)
      ] | @tsv
    ' "$LOG_FILE" | \
    awk -F'\t' '{ printf "%-36s %5s %7s %12s %12s %10s %12s\n", $1, $2, $3, $4, $5, $6, $7 }'

    echo ""
    echo "── Totals ────────────────────────────────────────────────────"
    echo ""
    jq -rs '
      {
        iterations:  length,
        stories:     (map(.stories_passed_delta) | add // 0),
        tokens_in:   (map(.tokens_in)  | add // 0),
        tokens_out:  (map(.tokens_out) | add // 0),
        cost_usd:    (map(select(.cost_usd != null) | .cost_usd) | if length > 0 then add else null end),
        tools:       ([.[].tool] | unique | sort | join(", ")),
        models:      ([.[].model] | unique | sort | join(", "))
      } |
      "  Tools used:        " + .tools,
      "  Models used:       " + .models,
      "  Total iterations:  " + (.iterations | tostring),
      "  Stories completed: " + (.stories | tostring),
      "  Total tokens in:   " + (.tokens_in  | tostring),
      "  Total tokens out:  " + (.tokens_out | tostring),
      "  Total cost:        " + (if .cost_usd == null then "n/a (see note below)" else ("$" + (.cost_usd | tostring)) end),
      "  Avg cost/story:    " + (if .cost_usd == null or .stories == 0 then "n/a"
                                  else ("$" + ((.cost_usd / .stories * 100 | round) / 100 | tostring)) end)
    ' "$LOG_FILE"

    echo ""
    echo "── Note ──────────────────────────────────────────────────────"
    echo "  cost_usd is parsed from tool stdout (best-effort)."
    echo "  Supported:  codex, kimi (aider token line), claude (total cost line)"
    echo "  Not parsed: amp, gemini, opencode"
    echo "  → For full coverage route all tools through OpenRouter, or"
    echo "    manually patch cost_usd values in cost_log.jsonl."
    echo "  → Run with --by-iteration to see which rows have null costs."
    echo ""
    ;;

esac
