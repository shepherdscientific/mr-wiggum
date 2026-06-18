#!/usr/bin/env bash
# metrics-report.sh — aggregate .ralph-metrics.jsonl into the article grid.
#
# Reads one record per API call (codegen + review) and reports, per
# repo x codegen-model x reviewer:
#     iter/hr        throughput (iterations per active hour)
#     $/iter         TRUE cost per iteration   (energy + cloud review API)
#     $/story        TRUE cost per COMPLETED story (review PASS)
#     rejection %    review FAILs / reviews    (the review-gate reject rate)
#
# LOCAL ENERGY COST  — a local-codegen iteration is NOT free. The Mac Mini draws
# real power and Band-A electricity costs real naira. For local rows we compute
#     energy_kWh = duration_s/3600 * power_kW
#     energy_NGN = energy_kWh * tariff_NGN_per_kWh
# using the MEASURED avg_watts logged per iteration when present (powermetrics),
# else the 90 W ceiling below. A local row's TRUE cost is therefore
#     energy (₦, ground truth)  +  the CLOUD review-API cost ($, the reviewer is
#     still a cloud call) — explicitly NOT zero.
#
# Usage:
#   metrics-report.sh [FILE_OR_DIR ...]
#     no args     -> .ralph-metrics.jsonl next to this script
#     a FILE      -> that JSONL
#     a DIR       -> <dir>/scripts/ralph/.ralph-metrics.jsonl
#                    and <dir>/*/scripts/ralph/.ralph-metrics.jsonl (all 5 loops)
#
# ---------------------------------------------------------------------------
# Configurable constants (override via env). NAIRA is ground truth.
# ---------------------------------------------------------------------------
POWER_KW="${RALPH_POWER_KW:-0.09}"                  # 90 W peak at full GPU (user's MacMon reading)
TARIFF_NGN_PER_KWH="${RALPH_TARIFF_NGN_PER_KWH:-345}"   # ₦/kWh — Nigeria Band A (user's real rate)
NGN_PER_USD="${RALPH_NGN_PER_USD:-1400}"            # ₦/USD (~Jun 2026) — for the USD comparison only
# ---------------------------------------------------------------------------

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Resolve input files.
FILES=()
_add() { [ -f "$1" ] && FILES+=("$1"); }
if [ "$#" -eq 0 ]; then
  _add "$SCRIPT_DIR/.ralph-metrics.jsonl"
else
  for a in "$@"; do
    if [ -d "$a" ]; then
      # Layout-agnostic: scripts at the repo ROOT (canonical mr-wiggum) AND in a
      # scripts/ralph/ subdir (benchmark fleet). Add whichever exist.
      _add "$a/.ralph-metrics.jsonl"
      _add "$a/scripts/ralph/.ralph-metrics.jsonl"
      for f in "$a"/*/.ralph-metrics.jsonl;               do _add "$f"; done
      for f in "$a"/*/scripts/ralph/.ralph-metrics.jsonl; do _add "$f"; done
    else
      _add "$a"
    fi
  done
fi

if [ "${#FILES[@]}" -eq 0 ]; then
  echo "metrics-report: no .ralph-metrics.jsonl found." >&2
  echo "  pass a file, or a projects dir containing */scripts/ralph/.ralph-metrics.jsonl" >&2
  exit 0
fi

command -v jq >/dev/null 2>&1 || { echo "metrics-report: jq required" >&2; exit 1; }

# Per-group aggregates as TSV (join codegen<->review by repo|iteration).
TSV="$(cat "${FILES[@]}" 2>/dev/null | grep -h . 2>/dev/null | jq -s -r '
  map(select(type=="object" and .role!=null)) as $all
  | ($all | map(select(.role=="codegen"))) as $cg
  | ($all | map(select(.role=="review"))) as $rv
  | ($rv | map({key:(.repo + "|" + ((.iteration//0)|tostring)), value:.}) | from_entries) as $rvidx
  | [ $cg[] | . as $c
      | ($rvidx[$c.repo + "|" + ((.iteration//0)|tostring)]) as $r
      | { repo:$c.repo,
          cg_model:($c.model // "?"),
          rv_model:($r.model // "(none)"),
          ep:($c.endpoint // "?"),
          cg_cost:($c.cost_usd // 0),
          rv_cost:(($r.cost_usd) // 0),
          dur:(($c.duration_s // 0) + (($r.duration_s) // 0)),
          verdict:($r.verdict // null),
          story:($c.story_id // null),
          energy_kwh:( if ($c.endpoint=="local")
                       then ((($c.duration_s // 0)/3600.0)
                             * (if ($c.avg_watts != null) then ($c.avg_watts/1000.0) else '"$POWER_KW"' end))
                       else 0 end ),
          measured:( ($c.endpoint=="local") and ($c.avg_watts != null) ),
          cost_known:( ($c.cost_usd != null) and (($r == null) or ($r.cost_usd != null)) )
        } ]
  | group_by([.repo, .cg_model, .rv_model, .ep])
  | map({
      repo:.[0].repo, cg:.[0].cg_model, rv:.[0].rv_model, ep:.[0].ep,
      iters:length,
      passes:(map(select(.verdict=="PASS"))|length),
      fails:(map(select(.verdict=="FAIL"))|length),
      reviews:(map(select(.verdict!=null))|length),
      stories:(map(select(.verdict=="PASS")|.story)|map(select(.!=null))|unique|length),
      api_usd:(map(.cg_cost + .rv_cost)|add),
      dur_s:(map(.dur)|add),
      energy_kwh:(map(.energy_kwh)|add),
      measured_iters:(map(select(.measured))|length),
      null_cost_iters:(map(select(.cost_known|not))|length)
    })
  | .[]
  | [ .repo, .cg, .rv, .ep, .iters, .passes, .fails, .reviews, .stories,
      .api_usd, .dur_s, .energy_kwh, .measured_iters, .null_cost_iters ]
  | @tsv
')"

if [ -z "$TSV" ]; then
  echo "metrics-report: no codegen records found in: ${FILES[*]}" >&2
  exit 0
fi

echo "Ralph metrics — local vs cloud agentic coding"
echo "files: ${#FILES[@]}   |   power=${POWER_KW}kW (90W ceiling)   tariff=₦${TARIFF_NGN_PER_KWH}/kWh   fx=₦${NGN_PER_USD}/\$"
echo

# ---- Table 1: SPEED & QUALITY ----
{
  printf 'repo\tcodegen_model\treviewer\tendpoint\titers\titer/hr\tpass\tfail\trej%%\tstories\n'
  printf '%s\n' "$TSV" | awk -F'\t' '{
    iters=$5; passes=$6; fails=$7; reviews=$8; stories=$9; dur=$11;
    iph = (dur>0)? iters/(dur/3600.0) : 0;
    rej = (reviews>0)? (fails/reviews*100.0) : -1;
    rejs = (rej<0)? "n/a" : sprintf("%.0f%%", rej);
    printf "%s\t%s\t%s\t%s\t%d\t%.2f\t%d\t%d\t%s\t%d\n", $1,$2,$3,$4,iters,iph,passes,fails,rejs,stories;
  }'
} | column -t -s $'\t'

echo
# ---- Table 2: COST (TRUE = local energy + cloud review API; ₦ ground truth) ----
{
  printf 'repo\tcodegen_model\treviewer\tendpoint\tapi_$\tenergy_₦\tenergy_$\t₦/iter\t$/iter\t₦/story\t$/story\tenergy_src\n'
  printf '%s\n' "$TSV" | awk -F'\t' -v fx="$NGN_PER_USD" -v tariff="$TARIFF_NGN_PER_KWH" '{
    repo=$1; cg=$2; rv=$3; ep=$4; iters=$5; stories=$9;
    api=$10; energy_kwh=$12; measured=$13; nullc=$14;
    energy_ngn = energy_kwh*tariff;
    energy_usd = energy_ngn/fx;
    true_usd = api + energy_usd;
    true_ngn = energy_ngn + api*fx;
    piter_ngn = (iters>0)? true_ngn/iters : 0;
    piter_usd = (iters>0)? true_usd/iters : 0;
    pstory_ngn = (stories>0)? true_ngn/stories : -1;
    pstory_usd = (stories>0)? true_usd/stories : -1;
    esrc = (ep!="local")? "-" : ((measured>0)? sprintf("measured(%d/%d)",measured,iters) : "ceiling90W");
    psn = (pstory_ngn<0)? "n/a" : sprintf("%.2f", pstory_ngn);
    psu = (pstory_usd<0)? "n/a" : sprintf("%.4f", pstory_usd);
    nf = (nullc>0)? "*" : "";
    printf "%s\t%s\t%s\t%s\t%.4f%s\t%.2f\t%.4f\t%.2f\t%.4f\t%s\t%s\t%s\n",
      repo,cg,rv,ep, api,nf, energy_ngn, energy_usd, piter_ngn, piter_usd, psn, psu, esrc;
  }'
} | column -t -s $'\t'

echo
echo "notes:"
echo "  • TRUE cost of a LOCAL row = energy (₦, ground truth) + cloud review-API cost (\$). It is NOT \$0."
echo "    energy uses MEASURED avg watts/iter (powermetrics) when present, else the ${POWER_KW}kW (90W) ceiling — see energy_src."
echo "  • ₦/iter, \$/iter, ₦/story, \$/story are TRUE costs (energy + API). \$ via ₦${NGN_PER_USD}/\$ (naira is ground truth)."
echo "  • api_\$ marked * means some calls logged cost_usd=null (unknown) — reconcile against the per-loop OpenRouter key."
echo "  • iter/hr is iterations per ACTIVE hour (sum of per-iteration codegen+review duration_s); excludes overnight/idle gaps."
echo "  • stories = distinct story_ids that passed the review gate (completed)."
