#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Test for the harness-owned story-completion logic added to ralph.sh.
#
# It exercises a faithful copy of the post-review-gate block (jq passes:true
# flip + feat(<id>) commit + progress append) and asserts:
#   1. a FAIL review marks nothing and commits nothing
#   2. a PASS on the open target flips passes:true, writes ONE feat(<id>) commit
#      and a progress line
#   3. re-running PASS on the now-complete story is idempotent (NO 2nd commit)
#   4. a story already passes:true (agent self-completed) is a clean no-op
#   5. the next open story advances independently
#   6. the block is safe under `set -e` (the shell ralph.sh runs with)
#   7. best-effort push: fires after a committing PASS, is suppressed by
#      RALPH_NO_PUSH=1, and a failing push never aborts the loop (set -e safe)
#
# Run:  bash scripts/ralph/test-harness-bookkeeping.sh     (exit 0 = all green)
# ---------------------------------------------------------------------------
set -uo pipefail

PASS=0; FAIL=0
ok(){ echo "  PASS  $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL  $1"; FAIL=$((FAIL+1)); }

# --- function under test: a faithful copy of the ralph.sh bookkeeping block --
# Args: REVIEW_RESULT STORY_ID PRD_FILE REPO_ROOT [iteration]
harness_complete_story() {
  local REVIEW_RESULT="$1" STORY_ID="$2" PRD_FILE="$3" REPO_ROOT="$4" i="${5:-1}"
  if [ "$REVIEW_RESULT" = "pass" ] && [ -n "${STORY_ID:-}" ] && [ "$STORY_ID" != "unknown" ] && [ -f "$PRD_FILE" ]; then
    local STORY_STILL_OPEN STORY_TITLE _PRD_TMP
    STORY_STILL_OPEN=$(jq -r --arg id "$STORY_ID" \
      'if any(.userStories[]?; .id == $id and (.passes != true)) then "yes" else "no" end' \
      "$PRD_FILE" 2>/dev/null || echo "no")
    if [ "$STORY_STILL_OPEN" = "yes" ]; then
      STORY_TITLE=$(jq -r --arg id "$STORY_ID" \
        'first(.userStories[]? | select(.id == $id) | .title) // ""' "$PRD_FILE" 2>/dev/null || echo "")
      _PRD_TMP=$(mktemp)
      if jq --arg id "$STORY_ID" \
           '(.userStories[]? | select(.id == $id) | .passes) = true' \
           "$PRD_FILE" > "$_PRD_TMP" 2>/dev/null && [ -s "$_PRD_TMP" ]; then
        mv "$_PRD_TMP" "$PRD_FILE" 2>/dev/null || rm -f "$_PRD_TMP"
      else
        rm -f "$_PRD_TMP"
      fi
      printf '%s — %s — %s — completed by harness (review PASS, iteration %s)\n' \
        "$(date +%Y-%m-%dT%H:%M:%S%z)" "$STORY_ID" "${STORY_TITLE:-untitled}" "$i" \
        >> "$REPO_ROOT/progress.txt" 2>/dev/null || true
      git -C "$REPO_ROOT" add -- "$PRD_FILE" "$REPO_ROOT/progress.txt" 2>/dev/null || true
      if ! git -C "$REPO_ROOT" diff --cached --quiet -- "$PRD_FILE" "$REPO_ROOT/progress.txt" 2>/dev/null; then
        git -C "$REPO_ROOT" commit -m "feat($STORY_ID): ${STORY_TITLE:-complete story} [harness: loop-owned completion on review PASS]" >/dev/null 2>&1 || true
        # Best-effort per-iteration push (mirrors ralph.sh): push the loop branch
        # after the feat() commit; a failed push is logged + ignored so it can
        # never fail the loop. Opt out with RALPH_NO_PUSH=1.
        if [ "${RALPH_NO_PUSH:-0}" != "1" ]; then
          local _LOOP_BRANCH
          _LOOP_BRANCH=$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
          if [ -n "$_LOOP_BRANCH" ] && [ "$_LOOP_BRANCH" != "HEAD" ]; then
            if git -C "$REPO_ROOT" push origin "$_LOOP_BRANCH" >/dev/null 2>&1; then
              echo "      ⬆️  pushed $_LOOP_BRANCH (feat($STORY_ID))" >&2
            else
              echo "      ⚠️  push failed (best-effort, ignored)" >&2
            fi
          fi
        fi
      fi
    fi
  fi
}

# --- fixture: throwaway git repo with a 4-story PRD --------------------------
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
git -C "$TMP" init -q
git -C "$TMP" config user.email t@t.t; git -C "$TMP" config user.name tester
cat > "$TMP/prd.json" <<'JSON'
{ "branchName": "ralph/mvp", "userStories": [
  { "id": "US-1", "title": "First story",  "passes": false },
  { "id": "US-2", "title": "Second story", "passes": false },
  { "id": "US-3", "title": "Third story",  "passes": true  },
  { "id": "US-4", "title": "Fourth story", "passes": false }
] }
JSON
: > "$TMP/progress.txt"
git -C "$TMP" add -A; git -C "$TMP" commit -qm init
base=$(git -C "$TMP" rev-list --count HEAD)

# --- mock the push: intercept ONLY `git … push …`, record it, return a
# configurable rc; every other git call passes through to the real binary so
# the fixture and assertions are unaffected. Lets us assert the push step fires
# WITHOUT a real remote, and simulate a push failure (best-effort) safely.
PUSH_LOG="$TMP/push.log"; : > "$PUSH_LOG"
MOCK_PUSH_RC=0
git() {
  if [ "${3:-}" = "push" ]; then
    echo "push $*" >> "$PUSH_LOG"
    return "$MOCK_PUSH_RC"
  fi
  command git "$@"
}

passes_of(){ jq -r --arg id "$1" 'first(.userStories[]|select(.id==$id)|.passes)' "$TMP/prd.json"; }
commits(){ git -C "$TMP" rev-list --count HEAD; }
subject(){ git -C "$TMP" log -1 --format='%s'; }

echo "1) FAIL review must mark nothing and commit nothing"
harness_complete_story fail US-1 "$TMP/prd.json" "$TMP" 1
[ "$(passes_of US-1)" = "false" ] && ok "FAIL left US-1 passes:false" || no "FAIL wrongly marked US-1"
[ "$(commits)" = "$base" ]        && ok "FAIL made no commit"        || no "FAIL created a commit"

echo "2) PASS on the open target flips passes:true + one feat(US-1) commit + progress"
harness_complete_story pass US-1 "$TMP/prd.json" "$TMP" 2
[ "$(passes_of US-1)" = "true" ]      && ok "PASS flipped US-1 -> true"          || no "PASS did not flip US-1"
[ "$(commits)" = "$((base+1))" ]      && ok "PASS made exactly one commit"       || no "wrong commit count: $(commits)"
case "$(subject)" in feat\(US-1\):*)  ok "commit subject is feat(US-1): ..." ;;  *) no "bad subject: $(subject)";; esac
grep -q "US-1" "$TMP/progress.txt"    && ok "progress.txt got a US-1 line"        || no "progress.txt missing US-1"

echo "3) Idempotent: re-running PASS on the now-complete US-1 makes NO new commit"
before=$(commits)
harness_complete_story pass US-1 "$TMP/prd.json" "$TMP" 3
[ "$(commits)" = "$before" ] && ok "idempotent re-run did not double-commit" || no "idempotent re-run double-committed"

echo "4) A story already passes:true (agent self-completed) is a clean no-op"
before=$(commits)
harness_complete_story pass US-3 "$TMP/prd.json" "$TMP" 4
[ "$(commits)" = "$before" ] && ok "already-passing US-3 is a no-op" || no "US-3 wrongly committed"

echo "5) The next open story advances independently"
harness_complete_story pass US-2 "$TMP/prd.json" "$TMP" 5
[ "$(passes_of US-2)" = "true" ]     && ok "US-2 advanced -> true"             || no "US-2 not marked"
case "$(subject)" in feat\(US-2\):*) ok "subject is feat(US-2): ..." ;;        *) no "bad US-2 subject: $(subject)";; esac

echo "6) Safe under 'set -e' (no-op path AND mark path must not abort the loop)"
( set -e; harness_complete_story pass US-3 "$TMP/prd.json" "$TMP" 6 ) && ok "set -e safe on no-op path" || no "set -e aborted on no-op path"
( set -e; harness_complete_story pass US-4 "$TMP/prd.json" "$TMP" 6 ) && ok "set -e safe on mark path"  || no "set -e aborted on mark path"
[ "$(passes_of US-4)" = "true" ] && ok "US-4 marked under set -e" || no "US-4 not marked under set -e"

echo "7) Best-effort push: fires on a committing PASS, respects RALPH_NO_PUSH, never fails the loop"
# Add fresh open stories so the push path has something to commit.
_p=$(mktemp); jq '.userStories += [
  {"id":"US-5","title":"Fifth story","passes":false},
  {"id":"US-6","title":"Sixth story","passes":false},
  {"id":"US-7","title":"Seventh story","passes":false}]' "$TMP/prd.json" > "$_p" && mv "$_p" "$TMP/prd.json"
git -C "$TMP" add -A; git -C "$TMP" commit -qm "add US-5..7"

# (a) a committing PASS also pushes the current loop branch (mock records it)
: > "$PUSH_LOG"; MOCK_PUSH_RC=0
harness_complete_story pass US-5 "$TMP/prd.json" "$TMP" 7
grep -q "push" "$PUSH_LOG" && ok "committing PASS pushed the loop branch" || no "committing PASS did not push"

# (b) RALPH_NO_PUSH=1 suppresses the push but still completes + commits the story
: > "$PUSH_LOG"; before=$(commits)
RALPH_NO_PUSH=1 harness_complete_story pass US-6 "$TMP/prd.json" "$TMP" 8
[ ! -s "$PUSH_LOG" ]               && ok "RALPH_NO_PUSH=1 suppressed the push"  || no "RALPH_NO_PUSH=1 still pushed"
[ "$(passes_of US-6)" = "true" ]   && ok "US-6 completed with push disabled"    || no "US-6 not completed under RALPH_NO_PUSH"
[ "$(commits)" = "$((before+1))" ] && ok "US-6 still made its feat commit"      || no "US-6 commit miscount: $(commits)"

# (c) a no-op PASS (already complete) does not push
: > "$PUSH_LOG"
harness_complete_story pass US-5 "$TMP/prd.json" "$TMP" 9
[ ! -s "$PUSH_LOG" ] && ok "no-op PASS did not push" || no "no-op PASS wrongly pushed"

# (d) a FAILING push is non-fatal under set -e and the feat commit still stands
before=$(commits); : > "$PUSH_LOG"; MOCK_PUSH_RC=1
( set -e; harness_complete_story pass US-7 "$TMP/prd.json" "$TMP" 10 ) \
  && ok "failing push is non-fatal under set -e" || no "failing push aborted the loop"
grep -q "push" "$PUSH_LOG"         && ok "push was attempted before it failed"  || no "push not attempted on US-7"
[ "$(passes_of US-7)" = "true" ]   && ok "US-7 committed despite push failure"  || no "US-7 not committed on push failure"
[ "$(commits)" = "$((before+1))" ] && ok "exactly one feat commit despite failed push" || no "commit miscount after failed push: $(commits)"
MOCK_PUSH_RC=0

echo ""
echo "  RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
