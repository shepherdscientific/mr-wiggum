#!/bin/bash
# Ralph Loop - Fresh Context Edition
# Each iteration starts clean, no context accumulation

set -e

TOOL="${1:-claude}"
MAX_ITERATIONS="${2:-50}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PRD_FILE="$SCRIPT_DIR/prd.json"
AGENTS_FILE="$SCRIPT_DIR/AGENTS.md"
PROMPT_FILE="$SCRIPT_DIR/RALPH-PROMPT.md"

# Verify essentials exist
if [ ! -f "$PRD_FILE" ]; then
  echo "❌ prd.json not found"
  exit 1
fi

if [ ! -f "$AGENTS_FILE" ]; then
  echo "📝 Creating AGENTS.md"
  cat > "$AGENTS_FILE" << 'EOF'
# Agent Patterns

## Codebase Conventions
- Document patterns as you discover them
- Keep this file under 500 lines
- Only curated, reusable knowledge

## Current Patterns
- (Agents will populate this)
EOF
fi

echo "🤖 Ralph Loop - Fresh Context Mode"
echo "Tool: $TOOL | Max: $MAX_ITERATIONS iterations"
echo ""

for i in $(seq 1 $MAX_ITERATIONS); do
  echo "═══════════════════════════════════════════════════════════"
  echo "  Iteration $i/$MAX_ITERATIONS"
  echo "═══════════════════════════════════════════════════════════"
  
  # Get uncompleted task count
  REMAINING=$(jq '[.userStories[] | select(.passes == false)] | length' "$PRD_FILE")
  echo "📊 Remaining tasks: $REMAINING"
  
  if [ "$REMAINING" -eq 0 ]; then
    echo ""
    echo "✅ All tasks complete!"
    exit 0
  fi
  
  # Run with fresh context (no session persistence)
  if [[ "$TOOL" == "claude" ]]; then
    # Kill any existing context
    OUTPUT=$(claude --dangerously-skip-permissions --print --no-session-persistence < "$PROMPT_FILE" 2>&1 | tee /dev/stderr) || true
  else
    OUTPUT=$(cat "$PROMPT_FILE" | amp --dangerously-allow-all 2>&1 | tee /dev/stderr) || true
  fi
  
  # Check completion signal
  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "✅ Agent declared complete!"
    exit 0
  fi
  
  # Compact AGENTS.md if it gets too large (keep under 500 lines)
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
echo "Check prd.json for status"
exit 1
