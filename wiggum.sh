#!/bin/bash
# Mr. Wiggum - Fresh Context Ralph Loop
# Usage: ./wiggum.sh [--tool amp|claude] [max_iterations]

set -e

# Parse arguments
TOOL="claude"  # Default to claude (local LLM friendly)
MAX_ITERATIONS=50

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

if [[ "$TOOL" != "amp" && "$TOOL" != "claude" ]]; then
  echo "Error: Invalid tool '$TOOL'. Must be 'amp' or 'claude'."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRD_FILE="$SCRIPT_DIR/prd.json"
AGENTS_FILE="$SCRIPT_DIR/AGENTS.md"
PROMPT_FILE="$SCRIPT_DIR/prompt.md"
CLAUDE_FILE="$SCRIPT_DIR/CLAUDE.md"

# Select prompt based on tool
if [[ "$TOOL" == "claude" ]]; then
  ACTIVE_PROMPT="$CLAUDE_FILE"
else
  ACTIVE_PROMPT="$PROMPT_FILE"
fi

# Verify essentials
if [ ! -f "$PRD_FILE" ]; then
  echo "❌ prd.json not found"
  echo "Run ./setup-wiggum.sh to initialize"
  exit 1
fi

if [ ! -f "$AGENTS_FILE" ]; then
  echo "❌ AGENTS.md not found"
  echo "Run ./setup-wiggum.sh to initialize"
  exit 1
fi

if [ ! -f "$ACTIVE_PROMPT" ]; then
  echo "❌ $ACTIVE_PROMPT not found"
  exit 1
fi

echo "🤖 Mr. Wiggum - Fresh Context Mode"
echo "Tool: $TOOL | Max: $MAX_ITERATIONS iterations"
echo ""

for i in $(seq 1 $MAX_ITERATIONS); do
  echo "═══════════════════════════════════════════════════════════"
  echo "  Iteration $i/$MAX_ITERATIONS"
  echo "═══════════════════════════════════════════════════════════"
  
  # Get task stats
  REMAINING=$(jq '[.userStories[] | select(.passes == false)] | length' "$PRD_FILE")
  TOTAL=$(jq '.userStories | length' "$PRD_FILE")
  COMPLETED=$((TOTAL - REMAINING))
  
  echo "📊 Progress: $COMPLETED/$TOTAL tasks complete ($REMAINING remaining)"
  
  if [ "$REMAINING" -eq 0 ]; then
    echo ""
    echo "✅ All tasks complete!"
    exit 0
  fi
  
  # Run with FRESH context (critical: no session persistence)
  if [[ "$TOOL" == "claude" ]]; then
    OUTPUT=$(claude --dangerously-skip-permissions --print --no-session-persistence < "$ACTIVE_PROMPT" 2>&1 | tee /dev/stderr) || true
  else
    OUTPUT=$(cat "$ACTIVE_PROMPT" | amp --dangerously-allow-all 2>&1 | tee /dev/stderr) || true
  fi
  
  # Check completion signal
  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "✅ Agent declared complete!"
    exit 0
  fi
  
  # Auto-compact AGENTS.md (keep under 500 lines)
  if [ -f "$AGENTS_FILE" ] && [ $(wc -l < "$AGENTS_FILE") -gt 500 ]; then
    echo "⚠️  Compacting AGENTS.md (>500 lines)"
    tail -200 "$AGENTS_FILE" > "$AGENTS_FILE.tmp"
    mv "$AGENTS_FILE.tmp" "$AGENTS_FILE"
  fi
  
  echo ""
  sleep 2
done

echo ""
echo "⏱️  Max iterations reached ($MAX_ITERATIONS)"
echo "📋 Check prd.json for status"
exit 1
