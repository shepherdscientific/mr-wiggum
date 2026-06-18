#!/usr/bin/env bash
# metrics-lib.sh — REAL per-call usage/cost metrics for the ralph loop.
#
# Sourced by ralph.sh (codegen) and aider-review.sh (review). Emits exactly ONE
# JSON object per API call to .ralph-metrics.jsonl (next to these scripts).
#
# This REPLACES the old estimate logging (est_tokens x stale hardcoded rate)
# that wrote .ralph-cost.log. Numbers here are REAL:
#   * opencode codegen  — tokens+cost from opencode's own session telemetry
#                         (`opencode export`/stats DB); local llama-server = $0
#                         cost with real tokens + (optionally) measured watts.
#   * aider review      — tokens+cost from aider's printed "Tokens:/Cost:" line,
#                         or OpenRouter's authoritative generation-by-id endpoint.
#   * unknown           — emitted as JSON null (HONEST), never a fabricated
#                         estimate. Cloud spend reconciles against the per-loop
#                         OpenRouter key (records self-tag repo+model+role).
#
# Guarantees that always hold (harness-owned, never guessed):
#   timestamp, repo, iteration, story_id, role, model, endpoint, duration_s.
#
# Every function is best-effort and MUST NOT abort the loop (callers run under
# `set -e`). Reads are guarded; the public wrappers always `return 0`.

# Define-once guard.
if [ -n "${_RALPH_METRICS_LIB:-}" ]; then return 0 2>/dev/null || true; fi
_RALPH_METRICS_LIB=1

# --- locations -------------------------------------------------------------
_rm_self_dir() { cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd; }
RALPH_METRICS_DIR="${RALPH_METRICS_DIR:-$(_rm_self_dir)}"
RALPH_METRICS_FILE="${RALPH_METRICS_FILE:-$RALPH_METRICS_DIR/.ralph-metrics.jsonl}"

# Repo tag = basename of the git toplevel (falls back to two-levels-up dir name).
ralph_metrics_repo() {
  local r
  r="$(git -C "$RALPH_METRICS_DIR" rev-parse --show-toplevel 2>/dev/null)" || r=""
  if [ -n "$r" ]; then basename "$r"; else basename "$(cd "$RALPH_METRICS_DIR/../.." 2>/dev/null && pwd || echo unknown)"; fi
}

# ralph routes with local/remote; metrics records local|cloud.
ralph_metrics_endpoint() {
  case "$1" in
    local)        echo local ;;
    remote|cloud) echo cloud ;;
    *)            echo "${1:-unknown}" ;;
  esac
}

# --- number helpers --------------------------------------------------------
# Normalise "9.5k" / "1.2M" / "12,345" -> integer. Empty in -> empty out.
_rm_num() {
  awk -v s="$1" 'BEGIN{
    gsub(/,/,"",s); gsub(/[[:space:]]/,"",s);
    if (s ~ /[0-9]/) {
      m=1;
      if (s ~ /[kK]$/){m=1000;     sub(/[kK]$/,"",s)}
      else if (s ~ /[mM]$/){m=1000000; sub(/[mM]$/,"",s)}
      printf("%d", s*m+0.5);
    }
  }'
}

# All parsers below emit 4 TAB-separated fields: PROMPT<TAB>COMPLETION<TAB>TOTAL<TAB>COST
# (any field may be empty). Tab-delimited so empty leading fields never collapse.

# aider prints e.g.:  "Tokens: 9.5k sent, 1.2k received. Cost: $0.0234 message, $0.12 session."
_rm_parse_aider() {
  local f="$1" line sent recv cost p c t=""
  [ -f "$f" ] || { printf '\t\t\t\n'; return 0; }
  line=$(grep -aiE 'Tokens:.*sent.*received' "$f" 2>/dev/null | tail -1)
  if [ -n "$line" ]; then
    sent=$(printf '%s' "$line" | sed -nE 's/.*[Tt]okens:[[:space:]]*([0-9.,]+[kKmM]?)[[:space:]]*sent.*/\1/p')
    recv=$(printf '%s' "$line" | sed -nE 's/.*sent,[[:space:]]*([0-9.,]+[kKmM]?)[[:space:]]*received.*/\1/p')
  fi
  cost=$(grep -aiE 'Cost:[[:space:]]*\$[0-9]' "$f" 2>/dev/null | tail -1 | sed -nE 's/.*Cost:[[:space:]]*\$([0-9]+\.[0-9]+)[[:space:]]*message.*/\1/p')
  [ -z "$cost" ] && cost=$(grep -aiE 'Cost:[[:space:]]*\$[0-9]' "$f" 2>/dev/null | tail -1 | sed -nE 's/.*Cost:[[:space:]]*\$([0-9]+\.[0-9]+).*/\1/p')
  p=$(_rm_num "$sent"); c=$(_rm_num "$recv")
  [ -n "$p" ] && [ -n "$c" ] && t=$((p+c))
  printf '%s\t%s\t%s\t%s\n' "$p" "$c" "$t" "$cost"
}

# Generic stdout fallback (e.g. opencode formatted output). Looks for any
# "input/prompt"/"output/completion" token counts and a "$N.NN" cost.
_rm_parse_generic() {
  local f="$1" p c t="" cost
  [ -f "$f" ] || { printf '\t\t\t\n'; return 0; }
  p=$(grep -aoiE '(prompt|input)[^0-9]{0,12}[0-9][0-9.,]*[kKmM]?' "$f" 2>/dev/null | tail -1 | grep -oiE '[0-9][0-9.,]*[kKmM]?' | tail -1)
  c=$(grep -aoiE '(completion|output)[^0-9]{0,12}[0-9][0-9.,]*[kKmM]?' "$f" 2>/dev/null | tail -1 | grep -oiE '[0-9][0-9.,]*[kKmM]?' | tail -1)
  cost=$(grep -aoiE 'cost[^0-9$]{0,8}\$?[0-9]+\.[0-9]+' "$f" 2>/dev/null | tail -1 | grep -oE '[0-9]+\.[0-9]+' | tail -1)
  p=$(_rm_num "$p"); c=$(_rm_num "$c")
  [ -n "$p" ] && [ -n "$c" ] && t=$((p+c))
  printf '%s\t%s\t%s\t%s\n' "$p" "$c" "$t" "$cost"
}

# Best-effort: opencode's own telemetry for the most recent session in the
# CURRENT project (cwd) — concurrency-safe across loops (each loop has its own
# project dir). Schema-tolerant. Emits the 4 tab fields or all-empty.
_rm_opencode_usage() {
  command -v opencode >/dev/null 2>&1 || { printf '\t\t\t\n'; return 0; }
  local sid js
  sid=$(opencode session list --project "" --format json -n 1 2>/dev/null \
        | jq -r '(.[0].id // .[0].sessionID // .[0].sessionId // empty)' 2>/dev/null) || sid=""
  [ -n "$sid" ] || { printf '\t\t\t\n'; return 0; }
  js=$(opencode export "$sid" 2>/dev/null) || { printf '\t\t\t\n'; return 0; }
  printf '%s' "$js" | jq -r '
    [ .. | objects | select((.tokens?!=null) or (.usage?!=null) or (.cost?!=null)) ] as $m
    | (reduce $m[] as $x (0; . + (($x.tokens.input  // $x.usage.input_tokens  // $x.usage.prompt_tokens     // 0)))) as $pin
    | (reduce $m[] as $x (0; . + (($x.tokens.output // $x.usage.output_tokens // $x.usage.completion_tokens // 0)))) as $pout
    | (reduce $m[] as $x (0; . + (($x.cost // 0)))) as $cost
    | "\($pin)\t\($pout)\t\($pin+$pout)\t\($cost)"' 2>/dev/null \
  | awk -F'\t' 'NF>=3{ if(($1+0)==0 && ($2+0)==0 && ($4+0)==0){exit}; printf("%s\t%s\t%s\t%s\n",$1,$2,$3,$4) }'
}

# OpenRouter authoritative cost+tokens for a generation id. 4 tab fields.
ralph_metrics_openrouter_gen() {
  local id="$1" key="${OPENROUTER_API_KEY:-}" resp
  { [ -n "$id" ] && [ -n "$key" ] && command -v curl >/dev/null 2>&1; } || { printf '\t\t\t\n'; return 0; }
  resp=$(curl -sf -m 10 -H "Authorization: Bearer $key" \
          "https://openrouter.ai/api/v1/generation?id=$id" 2>/dev/null) || { printf '\t\t\t\n'; return 0; }
  printf '%s' "$resp" | jq -r '
    (.data // .) as $d
    | "\($d.tokens_prompt // "")\t\($d.tokens_completion // "")\t\((($d.tokens_prompt//0)+($d.tokens_completion//0)))\t\($d.total_cost // "")"' 2>/dev/null
}

# Detect an OpenRouter generation id (gen-XXXX) in a tool output file.
_rm_detect_genid() { grep -aoE 'gen-[A-Za-z0-9]{6,}' "$1" 2>/dev/null | tail -1; }

# --- power sampling (IDEAL: measured, not assumed) -------------------------
# Sample average SoC power (watts) via macOS `powermetrics` while a local
# iteration runs. Opt-in (RALPH_POWER_SAMPLE=1) and needs passwordless sudo:
#   echo "$USER ALL=(root) NOPASSWD: $(command -v powermetrics)" | sudo tee /etc/sudoers.d/ralph-powermetrics
# Falls back silently (empty -> aggregator uses the 90 W ceiling).
ralph_metrics_power_start() {
  _RM_PM_FILE=""; _RM_PM_PID=""
  [ "${RALPH_POWER_SAMPLE:-0}" = "1" ] || return 0
  command -v powermetrics >/dev/null 2>&1 || return 0
  command -v sudo >/dev/null 2>&1 || return 0
  sudo -n true >/dev/null 2>&1 || return 0
  _RM_PM_FILE=$(mktemp 2>/dev/null) || { _RM_PM_FILE=""; return 0; }
  local iv="${RALPH_POWER_INTERVAL_MS:-1000}"
  ( sudo -n powermetrics --samplers cpu_power,gpu_power -i "$iv" >"$_RM_PM_FILE" 2>/dev/null ) &
  _RM_PM_PID=$!
}
# Echoes average watts (real) or empty.
ralph_metrics_power_stop() {
  [ -n "${_RM_PM_PID:-}" ] || { echo ""; return 0; }
  kill "$_RM_PM_PID" 2>/dev/null
  wait "$_RM_PM_PID" 2>/dev/null || true
  local w=""
  if [ -s "${_RM_PM_FILE:-/nonexistent}" ]; then
    w=$(awk '
      /Combined Power \(CPU \+ GPU \+ ANE\):/ {for(i=1;i<=NF;i++) if($i ~ /^[0-9.]+$/){s+=$i;n++}}
      END{ if(n>0) printf("%.2f",(s/n)/1000.0) }' "$_RM_PM_FILE" 2>/dev/null)
    [ -z "$w" ] && w=$(awk '
      /Package Power:/ {for(i=1;i<=NF;i++) if($i ~ /^[0-9.]+$/){s+=$i;n++}}
      END{ if(n>0) printf("%.2f",(s/n)/1000.0) }' "$_RM_PM_FILE" 2>/dev/null)
  fi
  rm -f "$_RM_PM_FILE" 2>/dev/null || true
  echo "$w"
}

# --- record emit (atomic, concurrency-safe) --------------------------------
# Append a single JSON object. flock when available (Linux); else a single
# O_APPEND write (atomic for lines < PIPE_BUF on macOS/POSIX). Self-tagged, so
# even if N loops shared one file the rows never blur.
_rm_atomic_append() {
  local line="$1" file="$RALPH_METRICS_FILE"
  [ -n "$line" ] || return 0
  mkdir -p "$(dirname "$file")" 2>/dev/null || true
  if command -v flock >/dev/null 2>&1; then
    ( flock 9; printf '%s\n' "$line" >&9 ) 9>>"$file" 2>/dev/null && return 0
  fi
  printf '%s\n' "$line" >> "$file" 2>/dev/null || true
}

# Build + append one record. Empty numeric args become JSON null (honest).
# args: role tool model endpoint prompt completion total cost duration verdict story iter [watts] [source]
ralph_metrics_log() {
  local role="$1" tool="$2" model="$3" endpoint="$4" ptok="$5" ctok="$6" ttok="$7" \
        cost="$8" dur="$9" verdict="${10}" story="${11}" iter="${12}" watts="${13:-}" source="${14:-unknown}"
  local repo ts line
  repo="$(ralph_metrics_repo 2>/dev/null)"; repo="${repo:-unknown}"
  ts="$(date +%Y-%m-%dT%H:%M:%S%z 2>/dev/null)"
  endpoint="$(ralph_metrics_endpoint "$endpoint")"
  _j() { if [ -z "${1:-}" ]; then echo null; else echo "$1"; fi; }
  line=$(jq -c -n \
    --arg ts "$ts" --arg repo "$repo" --arg role "$role" --arg tool "$tool" \
    --arg model "$model" --arg endpoint "$endpoint" --arg story "${story:-}" \
    --arg verdict "${verdict:-}" --arg source "$source" \
    --argjson iter "$(_j "$iter")" \
    --argjson prompt_tokens "$(_j "$ptok")" \
    --argjson completion_tokens "$(_j "$ctok")" \
    --argjson total_tokens "$(_j "$ttok")" \
    --argjson cost_usd "$(_j "$cost")" \
    --argjson duration_s "$(_j "$dur")" \
    --argjson avg_watts "$(_j "$watts")" \
    '{ts:$ts, repo:$repo, iteration:$iter,
      story_id:(if $story=="" then null else $story end),
      role:$role, tool:$tool, model:$model, endpoint:$endpoint,
      prompt_tokens:$prompt_tokens, completion_tokens:$completion_tokens,
      total_tokens:$total_tokens, cost_usd:$cost_usd, duration_s:$duration_s,
      avg_watts:$avg_watts,
      verdict:(if $verdict=="" then null else $verdict end),
      source:$source}' 2>/dev/null) || return 0
  _rm_atomic_append "$line"
  return 0
}

# --- public wrappers -------------------------------------------------------
# CODEGEN: tool model endpoint iter story duration outfile [watts]
ralph_metrics_log_codegen() {
  local tool="$1" model="$2" endpoint="$3" iter="$4" story="$5" dur="$6" out="$7" watts="${8:-}"
  local p="" c="" t="" cost="" cost2="" src="unknown" parsed ep
  ep="$(ralph_metrics_endpoint "$endpoint")"
  parsed="$(_rm_opencode_usage 2>/dev/null || true)"
  if [ -n "$(printf '%s' "$parsed" | tr -d ' \t')" ]; then
    IFS=$'\t' read -r p c t cost <<<"$parsed" || true; src="opencode-telemetry"
  fi
  if [ -z "${p:-}${c:-}${t:-}" ]; then
    parsed="$(_rm_parse_generic "$out" 2>/dev/null || true)"
    IFS=$'\t' read -r p c t cost2 <<<"$parsed" || true
    [ -z "${cost:-}" ] && cost="${cost2:-}"
    [ -n "${p:-}${c:-}${t:-}" ] && src="stdout-parse"
  fi
  if [ "$ep" = "local" ]; then cost=0; [ "$src" = "unknown" ] && src="local-zero"; fi
  if [ -z "${cost:-}" ] && [ "$ep" = "cloud" ] && [ -n "${t:-}" ] && [ -n "${RALPH_COST_PER_MTOK_INPUT:-}" ]; then
    local orr="${RALPH_COST_PER_MTOK_OUTPUT:-$RALPH_COST_PER_MTOK_INPUT}"
    cost=$(awk -v p="${p:-0}" -v c="${c:-0}" -v ir="$RALPH_COST_PER_MTOK_INPUT" -v o="$orr" \
            'BEGIN{printf "%.6f",(p/1e6)*ir+(c/1e6)*o}')
    src="computed-from-tokens"
  fi
  ralph_metrics_log codegen "$tool" "$model" "$ep" "${p:-}" "${c:-}" "${t:-}" "${cost:-}" "$dur" "" "$story" "$iter" "$watts" "$src" || true
  return 0
}

# REVIEW: model endpoint verdict duration outfile   (iter/story via env RALPH_ITER/RALPH_STORY_ID)
ralph_metrics_log_review() {
  local model="$1" endpoint="$2" verdict="$3" dur="$4" out="$5"
  local p="" c="" t="" cost="" src="unknown" gid parsed ep
  ep="$(ralph_metrics_endpoint "$endpoint")"
  gid="$(_rm_detect_genid "$out" 2>/dev/null || true)"
  if [ -n "$gid" ]; then
    parsed="$(ralph_metrics_openrouter_gen "$gid" 2>/dev/null || true)"
    if [ -n "$(printf '%s' "$parsed" | tr -d ' \t')" ]; then IFS=$'\t' read -r p c t cost <<<"$parsed" || true; src="openrouter-generation"; fi
  fi
  if [ -z "${p:-}${c:-}${t:-}${cost:-}" ]; then
    parsed="$(_rm_parse_aider "$out" 2>/dev/null || true)"
    IFS=$'\t' read -r p c t cost <<<"$parsed" || true
    [ -n "$(printf '%s%s%s%s' "${p:-}" "${c:-}" "${t:-}" "${cost:-}")" ] && src="aider-stdout"
  fi
  if [ "$ep" = "local" ]; then cost=0; [ "$src" = "unknown" ] && src="local-zero"; fi
  ralph_metrics_log review aider "$model" "$ep" "${p:-}" "${c:-}" "${t:-}" "${cost:-}" "$dur" "$verdict" "${RALPH_STORY_ID:-}" "${RALPH_ITER:-}" "" "$src" || true
  return 0
}
