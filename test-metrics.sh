#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Tests for the REAL per-call metrics logging (metrics-lib.sh) + the aggregator
# (metrics-report.sh). Asserts:
#   1. codegen LOCAL  -> endpoint=local, cost_usd=0 (NOT null/estimate), watts kept
#   2. codegen CLOUD  -> cost computed from REAL tokens × rate (source tagged)
#   3. review  CLOUD  -> verdict + REAL tokens/cost parsed from aider stdout
#   4. review  LOCAL  -> cost_usd=0, verdict FAIL
#   5. unknown CLOUD cost -> cost_usd=null (HONEST, never a fabricated estimate)
#   6. every record carries the required self-tagging keys + valid JSON
#   7. concurrency: N parallel appends -> exactly N intact, valid JSON lines
#   8. aggregator math: iter/hr, rejection %, $/story, and the local ENERGY cost
#      (energy + cloud review = TRUE cost, never $0)
#
# Run:  bash scripts/ralph/test-metrics.sh      (exit 0 = all green)
# ---------------------------------------------------------------------------
set -uo pipefail
PASS=0; FAIL=0
ok(){ echo "  PASS  $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL  $1"; FAIL=$((FAIL+1)); }
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- fixture: throwaway git repo so the repo tag resolves -------------------
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
git -C "$TMP" init -q; git -C "$TMP" config user.email t@t.t; git -C "$TMP" config user.name t
mkdir -p "$TMP/scripts/ralph"
export RALPH_METRICS_DIR="$TMP/scripts/ralph"
export RALPH_METRICS_FILE="$TMP/scripts/ralph/.ralph-metrics.jsonl"
REPO_TAG="$(basename "$TMP")"
# shellcheck disable=SC1090
. "$HERE/metrics-lib.sh"

jget(){ jq -r "$2" <(sed -n "${1}p" "$RALPH_METRICS_FILE"); }   # field of Nth line

echo "1) codegen LOCAL — cost 0, endpoint local, watts kept, real tokens null when none"
ralph_metrics_log_codegen opencode local/qwen3-coder-next local 1 US-1 200 /dev/null 88.5
[ "$(jget 1 .endpoint)" = "local" ]      && ok "endpoint=local"        || no "endpoint=$(jget 1 .endpoint)"
[ "$(jget 1 .cost_usd)" = "0" ]          && ok "local cost_usd=0 (not null)" || no "cost_usd=$(jget 1 .cost_usd)"
[ "$(jget 1 .avg_watts)" = "88.5" ]      && ok "avg_watts=88.5 kept"   || no "watts=$(jget 1 .avg_watts)"
[ "$(jget 1 .repo)" = "$REPO_TAG" ]      && ok "self-tagged repo"      || no "repo=$(jget 1 .repo)"

echo "2) codegen CLOUD — cost computed from REAL tokens × rate"
printf 'input tokens: 10000\noutput tokens: 1000\n' > "$TMP/oc.txt"
RALPH_COST_PER_MTOK_INPUT=0.27 RALPH_COST_PER_MTOK_OUTPUT=1.10 \
  ralph_metrics_log_codegen opencode deepseek/deepseek-chat remote 2 US-2 120 "$TMP/oc.txt" ""
# expect 10000/1e6*0.27 + 1000/1e6*1.10 = 0.0027 + 0.0011 = 0.0038
awk -v v="$(jget 2 .cost_usd)" 'BEGIN{exit !(v>0.00379 && v<0.00381)}' && ok "cloud cost computed=0.0038" || no "cost=$(jget 2 .cost_usd)"
[ "$(jget 2 .source)" = "computed-from-tokens" ] && ok "source tagged"  || no "source=$(jget 2 .source)"
[ "$(jget 2 .endpoint)" = "cloud" ]      && ok "remote->cloud mapped"   || no "endpoint=$(jget 2 .endpoint)"

echo "3) review CLOUD — verdict + REAL tokens/cost from aider stdout"
printf 'RESULT: PASS\nTokens: 9.5k sent, 1.2k received. Cost: $0.0234 message, $0.12 session.\n' > "$TMP/ar.txt"
RALPH_ITER=2 RALPH_STORY_ID=US-2 ralph_metrics_log_review openrouter/moonshotai/kimi-k2.6 cloud PASS 60 "$TMP/ar.txt"
[ "$(jget 3 .verdict)" = "PASS" ]        && ok "verdict=PASS"           || no "verdict=$(jget 3 .verdict)"
[ "$(jget 3 .total_tokens)" = "10700" ] && ok "tokens=10700"           || no "tokens=$(jget 3 .total_tokens)"
[ "$(jget 3 .cost_usd)" = "0.0234" ]     && ok "real cost=0.0234"       || no "cost=$(jget 3 .cost_usd)"

echo "4) review LOCAL — cost 0, verdict FAIL"
RALPH_ITER=3 RALPH_STORY_ID=US-3 ralph_metrics_log_review openai/qwen3-coder-next local FAIL 30 /dev/null
[ "$(jget 4 .cost_usd)" = "0" ]          && ok "local review cost 0"    || no "cost=$(jget 4 .cost_usd)"
[ "$(jget 4 .verdict)" = "FAIL" ]        && ok "verdict=FAIL"           || no "verdict=$(jget 4 .verdict)"

echo "5) unknown CLOUD cost -> null (HONEST, never an estimate)"
RALPH_ITER=4 RALPH_STORY_ID=US-4 ralph_metrics_log_review openrouter/moonshotai/kimi-k2.6 cloud PASS 40 /dev/null
[ "$(jget 5 .cost_usd)" = "null" ]       && ok "unknown cloud cost=null" || no "cost=$(jget 5 .cost_usd)"

echo "6) schema — required keys present + every line valid JSON"
jq -e . "$RALPH_METRICS_FILE" >/dev/null 2>&1 && ok "all lines valid JSON" || no "invalid JSON present"
missing=$(jq -rc 'select((has("ts") and has("repo") and has("iteration") and has("role") and has("model") and has("endpoint") and has("prompt_tokens") and has("completion_tokens") and has("total_tokens") and has("cost_usd") and has("duration_s") and has("verdict"))|not)' "$RALPH_METRICS_FILE")
[ -z "$missing" ] && ok "all required keys present" || no "records missing keys: $missing"

echo "7) concurrency — 60 parallel appends, exactly 60 intact valid lines"
CFILE="$TMP/conc.jsonl"; ( export RALPH_METRICS_FILE="$CFILE"
  for n in $(seq 1 60); do ( ralph_metrics_log codegen opencode m local 1 1 2 0 5 "" S "$n" "" t ) & done; wait )
lines=$(wc -l < "$CFILE" | tr -d ' ')
[ "$lines" = "60" ] && ok "exactly 60 lines (atomic append)" || no "got $lines lines"
jq -e . "$CFILE" >/dev/null 2>&1 && ok "all 60 lines valid JSON (no interleave)" || no "interleaved/garbled JSON"

echo "8) aggregator — iter/hr, rejection %, energy + TRUE cost (local row != \$0)"
A="$TMP/agg/repoA/scripts/ralph"; mkdir -p "$A"
{
  # 2 local-codegen iters, Kimi review, 1 PASS 1 FAIL. durations: cg 300+300, rv 60+60 -> 720s=0.2h -> 10 iter/hr
  printf '{"ts":"t","repo":"repoA","iteration":1,"story_id":"US-1","role":"codegen","tool":"opencode","model":"local/qwen3","endpoint":"local","prompt_tokens":1,"completion_tokens":1,"total_tokens":2,"cost_usd":0,"duration_s":300,"avg_watts":90,"verdict":null,"source":"local-zero"}\n'
  printf '{"ts":"t","repo":"repoA","iteration":1,"story_id":"US-1","role":"review","tool":"aider","model":"kimi","endpoint":"cloud","prompt_tokens":1,"completion_tokens":1,"total_tokens":2,"cost_usd":0.10,"duration_s":60,"avg_watts":null,"verdict":"PASS","source":"aider-stdout"}\n'
  printf '{"ts":"t","repo":"repoA","iteration":2,"story_id":"US-2","role":"codegen","tool":"opencode","model":"local/qwen3","endpoint":"local","prompt_tokens":1,"completion_tokens":1,"total_tokens":2,"cost_usd":0,"duration_s":300,"avg_watts":90,"verdict":null,"source":"local-zero"}\n'
  printf '{"ts":"t","repo":"repoA","iteration":2,"story_id":"US-2","role":"review","tool":"aider","model":"kimi","endpoint":"cloud","prompt_tokens":1,"completion_tokens":1,"total_tokens":2,"cost_usd":0.10,"duration_s":60,"avg_watts":null,"verdict":"FAIL","source":"aider-stdout"}\n'
} > "$A/.ralph-metrics.jsonl"
OUT="$(RALPH_POWER_KW=0.09 RALPH_TARIFF_NGN_PER_KWH=345 RALPH_NGN_PER_USD=1400 bash "$HERE/metrics-report.sh" "$TMP/agg/repoA")"
echo "$OUT" | grep -qE '10\.00' && ok "iter/hr = 10.00" || no "iter/hr wrong"
echo "$OUT" | grep -qE '50%' && ok "rejection = 50%" || no "rej% wrong: $(echo "$OUT"|grep -i repoA|head -1)"
# energy: 2 iters × 300s × 0.09kW = 0.015 kWh × ₦345 = ₦5.175 ; +review API $0.20×₦1400=₦280 -> TRUE ₦285.18 ; 1 story -> ₦285.18/story
echo "$OUT" | grep -qE '5\.17|5\.18' && ok "energy ≈ ₦5.18 (measured 90W)" || no "energy wrong"
# only 1 completed story (US-1 PASS); US-2 only FAIL
sline="$(echo "$OUT" | awk '/repoA/&&/local\/qwen3/{print; exit}')"
echo "$OUT" | grep -qE '285\.' && ok "TRUE ₦/story ≈ 285 (energy + cloud review, NOT 0)" || no "TRUE/story wrong"

echo ""
echo "  RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
