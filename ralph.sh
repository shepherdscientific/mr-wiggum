#!/bin/bash
# Ralph Wiggum - Multi-Tool Agent Loop (2026 Edition)
set -e

TOOL="opencode" # Default tool
MAX_ITERATIONS=10
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

while [[ $# -gt 0 ]]; do
  case $1 in
    --tool) TOOL="$2"; shift 2 ;;
    *) if [[ "$1" =~ ^[0-9]+$ ]]; then MAX_ITERATIONS="$1"; fi; shift ;;
  esac
done

echo "🚀 Starting Ralph - Tool: $TOOL - Max iterations: $MAX_ITERATIONS"

for i in $(seq 1 $MAX_ITERATIONS); do
  echo -e "\n================ [ Iteration $i ($TOOL) ] ================"

  case "$TOOL" in
    "opencode")
      # Using the native OpenCode CLI in non-interactive mode
      # Ensure you have run 'opencode /init' once in the repo first
      OUTPUT=$(opencode run "$(cat "$SCRIPT_DIR/OPENCODE.md")" 2>&1 | tee /dev/stderr) || true
      ;;
    "gemini")
      # Standalone Gemini CLI
      OUTPUT=$(gemini -p "$(cat "$SCRIPT_DIR/GEMINI.md")" 2>&1 | tee /dev/stderr) || true
      ;;
    "codex")
      # Aider using GPT-4o for high-reasoning tasks
      OUTPUT=$(aider --model gpt-4o --message-file "$SCRIPT_DIR/AIDER_CODEX.md" --yes --no-auto-commit 2>&1 | tee /dev/stderr) || true
      ;;
    "amp")
      OUTPUT=$(cat "$SCRIPT_DIR/prompt.md" | amp --dangerously-allow-all 2>&1 | tee /dev/stderr) || true
      ;;
  esac

  # Check for the completion signal
  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo -e "\n✅ Ralph completed all tasks in $i iterations!"
    exit 0
  fi
done