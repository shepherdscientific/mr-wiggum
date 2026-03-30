#!/bin/bash
# Ralph Wiggum - Autonomous AI agent loop
# Usage: ./ralph.sh [--tool amp|claude|opencode|gemini|codex|kimi] [max_iterations]
#
# Agent persona support:
#   Add "agents" to prd.json at the PRD level (default for all stories) and/or
#   at the story level (overrides the default for that iteration).
#   Agent files are loaded from an agency-agents/ directory — checked first as
#   a sibling of this script's directory, then as a subdirectory within it.
#   Agent names must match filenames in agency-agents/ (without the .md extension).
#   Example: "agents": ["engineering-software-architect"]
#            → loads agency-agents/engineering/engineering-software-architect.md
#
# Cost tracking:
#   Each iteration appends a JSON line to cost_log.jsonl:
#     {"ts", "tool", "model", "iteration", "stories_passed_delta",
#      "tokens_in", "tokens_out", "cost_usd"}
#   Token/cost extraction is best-effort (parsed from tool output).
#   For amp/gemini/opencode, cost_usd will be null — add manually or
#   route those tools through OpenRouter for unified spend tracking.
#   Run ./cost-report.sh to summarise spend and cost-per-story by model.
#
# Kimi via OpenRouter:
#   Set KIMI_MODEL env var to override the default model string.
#   Default: openrouter/moonshotai/kimi-k2
#   Requires OPENROUTER_API_KEY env var.

set -e

TOOL="amp"        # Default tool
MAX_ITERATIONS=10
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRD_FILE="$SCRIPT_DIR/prd.json"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
ARCHIVE_DIR="$SCRIPT_DIR/archive"
LAST_BRANCH_FILE="$SCRIPT_DIR/.last-branch"
COST_LOG_FILE="$SCRIPT_DIR/cost_log.jsonl"

# ---------------------------------------------------------------------------
# Locate agency-agents directory
# Priority: sibling directory first, then subdirectory of SCRIPT_DIR
# ---------------------------------------------------------------------------
AGENT_DIR=""
for _candidate in "$SCRIPT_DIR/../agency-agents" "$SCRIPT_DIR/agency-agents"; do
  if [ -d "$_candidate" ]; then
    AGENT_DIR="$(cd "$_candidate" && pwd)"
    break
  fi
done

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case $1 in
    --tool)
      TOOL="$2"
      shift 2
      ;;
    --tool=*)
      TOOL="${1#*=}"
      shift
      ;;
    *)
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        MAX_ITERATIONS="$1"
      fi
      shift
      ;;
  esac
done

# Validate tool
VALID_TOOLS="amp claude opencode gemini codex kimi"
if ! echo "$VALID_TOOLS" | grep -qw "$TOOL"; then
  echo "Error: Invalid tool '$TOOL'. Must be one of: $VALID_TOOLS"
  exit 1
fi

# ---------------------------------------------------------------------------
# Resolve display model name for cost logging
# ---------------------------------------------------------------------------
case "$TOOL" in
  amp)      TOOL_MODEL="amp" ;;
  claude)   TOOL_MODEL="claude-code" ;;
  opencode) TOOL_MODEL="opencode" ;;
  gemini)   TOOL_MODEL="gemini" ;;
  codex)    TOOL_MODEL="gpt-4o" ;;
  kimi)     TOOL_MODEL="${KIMI_MODEL:-openrouter/moonshotai/kimi-k2}" ;;
  *)        TOOL_MODEL="$TOOL" ;;
esac

# ---------------------------------------------------------------------------
# Archive previous run if branch changed
# ---------------------------------------------------------------------------
if [ -f "$PRD_FILE" ] && [ -f "$LAST_BRANCH_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")

  if [ -n "$CURRENT_BRANCH" ] && [ -n "$LAST_BRANCH" ] && [ "$CURRENT_BRANCH" != "$LAST_BRANCH" ]; then
    DATE=$(date +%Y-%m-%d)
    FOLDER_NAME=$(echo "$LAST_BRANCH" | sed 's|^ralph/||')
    ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"
    echo "Archiving previous run: $LAST_BRANCH"
    mkdir -p "$ARCHIVE_FOLDER"
    [ -f "$PRD_FILE" ]      && cp "$PRD_FILE"      "$ARCHIVE_FOLDER/"
    [ -f "$PROGRESS_FILE" ] && cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"
    [ -f "$COST_LOG_FILE" ] && cp "$COST_LOG_FILE" "$ARCHIVE_FOLDER/"
    echo "   Archived to: $ARCHIVE_FOLDER"

    echo "# Ralph Progress Log" > "$PROGRESS_FILE"
    echo "Started: $(date)" >> "$PROGRESS_FILE"
    echo "---" >> "$PROGRESS_FILE"
  fi
fi

# Track current branch
if [ -f "$PRD_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  [ -n "$CURRENT_BRANCH" ] && echo "$CURRENT_BRANCH" > "$LAST_BRANCH_FILE"
fi

# Initialize progress file
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Ralph Progress Log" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

echo "🚀 Starting Ralph — Tool: $TOOL ($TOOL_MODEL) — Max iterations: $MAX_ITERATIONS"
if [ -n "$AGENT_DIR" ]; then
  echo "   Agent directory: $AGENT_DIR"
else
  echo "   No agency-agents/ directory found — persona injection disabled"
fi
echo "   Cost log: $COST_LOG_FILE"

# ---------------------------------------------------------------------------
# Helper: check prd.json for incomplete stories
# ---------------------------------------------------------------------------
prd_all_complete() {
  if [ ! -f "$PRD_FILE" ]; then return 1; fi
  local incomplete
  incomplete=$(jq '[.userStories[] | select(.passes != true)] | length' "$PRD_FILE" 2>/dev/null) || return 1
  [ "$incomplete" = "0" ]
}

# ---------------------------------------------------------------------------
# Helper: count currently passing stories in prd.json
# ---------------------------------------------------------------------------
count_passing() {
  if [ ! -f "$PRD_FILE" ]; then echo "0"; return; fi
  jq '[.userStories[] | select(.passes == true)] | length' "$PRD_FILE" 2>/dev/null || echo "0"
}

# ---------------------------------------------------------------------------
# Helper: write agent persona prefix for the next incomplete story to a file.
#
# Resolution order: story.agents → prd.agents → empty (no persona, no change)
#
# $1 — output file path to write combined agent content into
# Logs loaded/missing agents to stderr so they surface in the terminal.
# Returns 0 if at least one agent was loaded, 1 if none.
# ---------------------------------------------------------------------------
write_agent_prefix() {
  local out_file="$1"
  : > "$out_file"   # truncate / create

  if [ ! -f "$PRD_FILE" ] || [ -z "$AGENT_DIR" ]; then
    return 1
  fi

  # Resolve agents: story-level overrides PRD-level
  local agents
  agents=$(jq -r '
    ([ .userStories[] | select(.passes != true) ][0].agents // .agents // []) | .[]
  ' "$PRD_FILE" 2>/dev/null) || agents=""

  if [ -z "$agents" ]; then
    return 1
  fi

  local loaded=0
  while IFS= read -r agent_name; do
    [ -z "$agent_name" ] && continue
    local agent_file
    agent_file=$(find "$AGENT_DIR" -name "${agent_name}.md" 2>/dev/null | head -1)
    if [ -f "$agent_file" ]; then
      cat "$agent_file" >> "$out_file"
      printf '\n\n---\n\n' >> "$out_file"
      echo "  🎭 Agent loaded: $agent_name" >&2
      loaded=$((loaded + 1))
    else
      echo "  ⚠️  Warning: agent '${agent_name}' not found in $AGENT_DIR" >&2
    fi
  done <<< "$agents"

  [ "$loaded" -gt 0 ] && return 0 || return 1
}

# ---------------------------------------------------------------------------
# Helper: best-effort token/cost extraction from tool output.
# Sets _TOKENS_IN, _TOKENS_OUT, _COST_USD in the calling scope.
# ---------------------------------------------------------------------------
extract_tokens() {
  local tool="$1"
  local output="$2"
  _TOKENS_IN=0
  _TOKENS_OUT=0
  _COST_USD="null"

  case "$tool" in
    codex|kimi)
      # Aider: "Tokens: 15.2k sent, 1.2k received. Cost: $0.40 message, ..."
      local raw_sent raw_recv raw_cost
      raw_sent=$(printf '%s\n' "$output" | grep -oE 'Tokens: [0-9]+\.?[0-9]*k? sent' | tail -1 | grep -oE '[0-9]+\.?[0-9]*k?')
      raw_recv=$(printf '%s\n' "$output" | grep -oE '[0-9]+\.?[0-9]*k? received'      | tail -1 | grep -oE '[0-9]+\.?[0-9]*k?')
      raw_cost=$(printf '%s\n' "$output" | grep -oE 'Cost: \$[0-9]+\.[0-9]+'          | tail -1 | grep -oE '[0-9]+\.[0-9]+')
      # Convert k suffix to integer
      if [[ "$raw_sent" == *k ]]; then
        _TOKENS_IN=$(echo "${raw_sent%k} * 1000 / 1" | bc 2>/dev/null || echo 0)
      else
        _TOKENS_IN=${raw_sent:-0}
      fi
      if [[ "$raw_recv" == *k ]]; then
        _TOKENS_OUT=$(echo "${raw_recv%k} * 1000 / 1" | bc 2>/dev/null || echo 0)
      else
        _TOKENS_OUT=${raw_recv:-0}
      fi
      [ -n "$raw_cost" ] && _COST_USD="$raw_cost"
      ;;
    claude)
      # Claude Code CLI: "Total cost: $X.XX"
      local raw_cost
      raw_cost=$(printf '%s\n' "$output" | grep -oE 'Total cost: \$?[0-9]+\.[0-9]+' | tail -1 | grep -oE '[0-9]+\.[0-9]+')
      [ -n "$raw_cost" ] && _COST_USD="$raw_cost"
      ;;
    opencode)
      # opencode may print session cost summary
      local raw_cost
      raw_cost=$(printf '%s\n' "$output" | grep -oiE 'cost[: ]+\$?[0-9]+\.[0-9]+' | tail -1 | grep -oE '[0-9]+\.[0-9]+')
      [ -n "$raw_cost" ] && _COST_USD="$raw_cost"
      ;;
    # amp and gemini: no reliable cost in stdout — use OpenRouter dashboard
  esac
}

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------
for i in $(seq 1 $MAX_ITERATIONS); do
  echo ""
  echo "==============================================================="
  echo "  Ralph Iteration $i of $MAX_ITERATIONS ($TOOL)"
  echo "==============================================================="

  # Early exit: all stories already marked complete before this iteration
  if prd_all_complete; then
    echo ""
    echo "✅ All PRD stories already complete — skipping iteration $i"
    exit 0
  fi

  # Snapshot pass count before this iteration for delta tracking
  _PASSES_BEFORE=$(count_passing)

  # -------------------------------------------------------------------------
  # Resolve agent personas for this iteration's story
  # -------------------------------------------------------------------------
  AGENT_PREFIX_FILE=$(mktemp)
  write_agent_prefix "$AGENT_PREFIX_FILE" || true   # failure = no agents, that's fine

  # -------------------------------------------------------------------------
  # Build the combined prompt (agent prefix + base instruction file)
  # -------------------------------------------------------------------------
  TMPPROMPT=$(mktemp)
  TMPOUT=$(mktemp)

  # -------------------------------------------------------------------------
  # Determine whether we can stream output live via /dev/tty.
  # /dev/tty is the controlling terminal — works on Linux and macOS.
  # Falls back to captured-then-printed output (e.g. CI with no tty).
  # -------------------------------------------------------------------------
  STREAM_LIVE=false
  [ -w /dev/tty ] && STREAM_LIVE=true

  # -------------------------------------------------------------------------
  # Run the AI tool
  # -------------------------------------------------------------------------
  case "$TOOL" in

    "amp")
      cat "$AGENT_PREFIX_FILE" "$SCRIPT_DIR/prompt.md" > "$TMPPROMPT"
      if $STREAM_LIVE; then
        cat "$TMPPROMPT" | amp --dangerously-allow-all 2>&1 | tee /dev/tty > "$TMPOUT" || true
      else
        cat "$TMPPROMPT" | amp --dangerously-allow-all > "$TMPOUT" 2>&1 || true
      fi
      ;;

    "claude")
      # NOTE: Claude Code requires the prompt as a string argument, NOT via
      # stdin. Newer versions misparse stdin as structured tool input (ZodError).
      cat "$AGENT_PREFIX_FILE" "$SCRIPT_DIR/CLAUDE.md" > "$TMPPROMPT"
      if $STREAM_LIVE; then
        claude --dangerously-skip-permissions --print "$(cat "$TMPPROMPT")" 2>&1 | tee /dev/tty > "$TMPOUT" || true
      else
        claude --dangerously-skip-permissions --print "$(cat "$TMPPROMPT")" > "$TMPOUT" 2>&1 || true
      fi
      ;;

    "opencode")
      cat "$AGENT_PREFIX_FILE" "$SCRIPT_DIR/OPENCODE.md" > "$TMPPROMPT"
      if $STREAM_LIVE; then
        opencode run "$(cat "$TMPPROMPT")" 2>&1 | tee /dev/tty > "$TMPOUT" || true
      else
        opencode run "$(cat "$TMPPROMPT")" > "$TMPOUT" 2>&1 || true
      fi
      ;;

    "gemini")
      cat "$AGENT_PREFIX_FILE" "$SCRIPT_DIR/GEMINI.md" > "$TMPPROMPT"
      if $STREAM_LIVE; then
        gemini -p "$(cat "$TMPPROMPT")" 2>&1 | tee /dev/tty > "$TMPOUT" || true
      else
        gemini -p "$(cat "$TMPPROMPT")" > "$TMPOUT" 2>&1 || true
      fi
      ;;

    "codex")
      # aider reads instructions from a file; prepend agent content inline
      cat "$AGENT_PREFIX_FILE" "$SCRIPT_DIR/AIDER_CODEX.md" > "$TMPPROMPT"
      if $STREAM_LIVE; then
        aider --model gpt-4o --message-file "$TMPPROMPT" --yes --no-auto-commit 2>&1 | tee /dev/tty > "$TMPOUT" || true
      else
        aider --model gpt-4o --message-file "$TMPPROMPT" --yes --no-auto-commit > "$TMPOUT" 2>&1 || true
      fi
      ;;

    "kimi")
      # Kimi K2 via OpenRouter, driven by aider + litellm's openrouter/ prefix.
      # Override model: KIMI_MODEL=openrouter/moonshotai/kimi-k2 ./ralph.sh --tool kimi
      # Requires OPENROUTER_API_KEY env var.
      _KIMI_MODEL="${KIMI_MODEL:-openrouter/moonshotai/kimi-k2}"
      if [ -z "${OPENROUTER_API_KEY:-}" ]; then
        echo "  ⚠️  Warning: OPENROUTER_API_KEY not set — kimi requests may fail"
      fi
      cat "$AGENT_PREFIX_FILE" "$SCRIPT_DIR/AIDER_CODEX.md" > "$TMPPROMPT"
      if $STREAM_LIVE; then
        OPENAI_API_KEY="${OPENROUTER_API_KEY:-$OPENAI_API_KEY}" \
          aider --model "$_KIMI_MODEL" --message-file "$TMPPROMPT" --yes --no-auto-commit 2>&1 | tee /dev/tty > "$TMPOUT" || true
      else
        OPENAI_API_KEY="${OPENROUTER_API_KEY:-$OPENAI_API_KEY}" \
          aider --model "$_KIMI_MODEL" --message-file "$TMPPROMPT" --yes --no-auto-commit > "$TMPOUT" 2>&1 || true
      fi
      ;;

  esac

  # Capture output for completion detection and cost parsing
  OUTPUT=$(cat "$TMPOUT")

  # -------------------------------------------------------------------------
  # Cost tracking: extract tokens + write one JSON line to cost_log.jsonl
  # -------------------------------------------------------------------------
  _PASSES_AFTER=$(count_passing)
  _STORIES_DELTA=$(( _PASSES_AFTER - _PASSES_BEFORE ))
  extract_tokens "$TOOL" "$OUTPUT"
  _LOG_TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  printf '{"ts":"%s","tool":"%s","model":"%s","iteration":%d,"stories_passed_delta":%d,"tokens_in":%d,"tokens_out":%d,"cost_usd":%s}\n' \
    "$_LOG_TS" "$TOOL" "$TOOL_MODEL" "$i" "$_STORIES_DELTA" \
    "${_TOKENS_IN:-0}" "${_TOKENS_OUT:-0}" "${_COST_USD:-null}" \
    >> "$COST_LOG_FILE"

  # Clean up temp files
  rm -f "$AGENT_PREFIX_FILE" "$TMPPROMPT" "$TMPOUT"

  # If not streamed live, print now
  if ! $STREAM_LIVE; then
    printf '%s\n' "$OUTPUT"
  fi

  # -------------------------------------------------------------------------
  # Completion detection
  # -------------------------------------------------------------------------

  # Primary: model emits <promise>COMPLETE</promise>
  if printf '%s\n' "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "✅ Ralph completed all tasks at iteration $i of $MAX_ITERATIONS"
    exit 0
  fi

  # Fallback: inspect prd.json directly.
  # Handles cases where the model finishes but doesn't emit the signal
  # (e.g. truncated output, JSON-wrapped response, or crash after writing).
  if prd_all_complete; then
    echo ""
    echo "✅ All PRD stories complete (verified via prd.json) at iteration $i"
    exit 0
  fi

  echo "Iteration $i complete. Continuing..."
  sleep 2
done

echo ""
echo "Ralph reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check $PROGRESS_FILE for status. Remaining stories:"
jq '[.userStories[] | select(.passes != true) | {id, title}]' "$PRD_FILE" 2>/dev/null || true
exit 1
