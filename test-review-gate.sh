#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Tests for the REVIEW-GATE HARDENING in aider-review.sh — the gate that refuses
# to pass a story whose iteration did not actually change CODE. Asserts:
#   1. empty diff (errored / zero-output codegen)         -> REVIEW-FAIL (exit 1)
#   2. bookkeeping-only commit ("mark passes:true")       -> REVIEW-FAIL (exit 1)
#   3. real code committed since RALPH_BASE_SHA            -> gate lets it through
#   4. RALPH_ALLOW_EMPTY_DIFF=1 overrides an empty diff    -> gate lets it through
#   5. real code uncommitted in the working tree          -> gate lets it through
#   6. a FAIL is recorded to .ralph-metrics.jsonl (shows up as a review rejection)
#
# "Lets it through" = the hardening banner does NOT fire. (With no `aider` CLI the
# script then exits 0 at the install check; this test asserts on the banner, so it
# is robust whether or not aider is installed.) Hermetic: the test's stdout capture
# and metrics file live OUTSIDE the fixture repo, so the gate's own untracked-file
# scan never mistakes them for a code change.
#
# Run:  bash test-review-gate.sh      (exit 0 = all green)
# ---------------------------------------------------------------------------
set -uo pipefail
AR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aider-review.sh"
PASS=0; FAIL=0
ok(){ echo "  PASS  $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL  $1"; FAIL=$((FAIL+1)); }
BANNER="REVIEW-FAIL — no substantive"

newrepo(){ # -> fresh repo dir with a base commit (prd.json, progress.txt, app.py)
  local d; d=$(mktemp -d)
  git -C "$d" init -q; git -C "$d" config user.email t@t.t; git -C "$d" config user.name t
  echo '{"userStories":[{"id":"US-1","title":"x","passes":false}]}' > "$d/prd.json"
  : > "$d/progress.txt"; echo "print('hi')" > "$d/app.py"
  git -C "$d" add -A; git -C "$d" commit -qm base; echo "$d"
}

# Run the gate inside repo $1 with RALPH_BASE_SHA=$2; extra env assignments $3...
# Sets globals GATE_RC and GATE_WORK. Helper files (stdout capture + metrics) are
# written into $GATE_WORK, OUTSIDE the fixture repo, so the gate's untracked scan
# never sees them.
run_gate(){ local d="$1" base="$2"; shift 2
  GATE_WORK=$(mktemp -d)
  ( cd "$d" && RALPH_METRICS_DIR="$GATE_WORK" RALPH_METRICS_FILE="$GATE_WORK/.m.jsonl" \
      RALPH_BASE_SHA="$base" SKIP_AIDER_REVIEW=0 AIDER_REVIEW_MODEL="" "$@" \
      bash "$AR" ) >"$GATE_WORK/out.txt" 2>&1
  GATE_RC=$?
}

echo "1) empty diff (nothing changed since base) -> REVIEW-FAIL"
d=$(newrepo); base=$(git -C "$d" rev-parse HEAD)
run_gate "$d" "$base"
[ "$GATE_RC" = "1" ]                              && ok "exit 1"                 || no "exit=$GATE_RC"
grep -q "$BANNER" "$GATE_WORK/out.txt"           && ok "emits REVIEW-FAIL banner" || no "no banner"
grep -q '"verdict":"FAIL"' "$GATE_WORK/.m.jsonl" && ok "logged a FAIL metric"     || no "no FAIL metric"

echo "2) bookkeeping-only commit (prd.json+progress.txt) -> REVIEW-FAIL"
d=$(newrepo); base=$(git -C "$d" rev-parse HEAD)
jq '(.userStories[]|select(.id=="US-1")|.passes)=true' "$d/prd.json" > "$d/p" && mv "$d/p" "$d/prd.json"
echo "ts — US-1 — x — done" >> "$d/progress.txt"
git -C "$d" add prd.json progress.txt; git -C "$d" commit -qm "feat(US-1): complete [harness]"
run_gate "$d" "$base"
[ "$GATE_RC" = "1" ]                    && ok "exit 1 (bookkeeping is not code)" || no "exit=$GATE_RC"
grep -q "$BANNER" "$GATE_WORK/out.txt" && ok "banner fired on bookkeeping-only"  || no "no banner"

echo "3) real code committed since base -> gate lets it through"
d=$(newrepo); base=$(git -C "$d" rev-parse HEAD)
printf 'def f():\n    return 42\n' >> "$d/app.py"
git -C "$d" add app.py; git -C "$d" commit -qm "feat: real code"
run_gate "$d" "$base"
grep -q "$BANNER" "$GATE_WORK/out.txt" && no "gate wrongly blocked real code" || ok "gate let real code through"

echo "4) RALPH_ALLOW_EMPTY_DIFF=1 overrides an empty diff"
d=$(newrepo); base=$(git -C "$d" rev-parse HEAD)
run_gate "$d" "$base" RALPH_ALLOW_EMPTY_DIFF=1
grep -q "$BANNER" "$GATE_WORK/out.txt" && no "override ignored" || ok "empty diff allowed with override"

echo "5) real code uncommitted in the working tree -> gate lets it through"
d=$(newrepo); base=$(git -C "$d" rev-parse HEAD)
echo "x = 1" >> "$d/app.py"   # modify a tracked file, leave it uncommitted
run_gate "$d" "$base"
grep -q "$BANNER" "$GATE_WORK/out.txt" && no "blocked an uncommitted real change" || ok "uncommitted real change passes"

echo ""
echo "  RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
