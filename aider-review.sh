#!/usr/bin/env bash
set -euo pipefail

# Skip entirely if requested
if [ "${SKIP_AIDER_REVIEW:-0}" = "1" ]; then
  echo "⏭️  SKIP_AIDER_REVIEW=1 — skipping aider review step"
  exit 0
fi

# Verify aider is installed
if ! command -v aider &> /dev/null; then
  echo "⚠️ Aider not found, skipping review."
  exit 0
fi

# Fallback defaults for safety
: "${LLM_API_BASE:=http://localhost:8080/v1}"
: "${LLM_API_KEY:=dummy}"

# Verify server is alive before blocking the loop
if ! curl -sf --max-time 5 "$LLM_API_BASE/models" > /dev/null; then
  echo -e "\033[33m⚠️  LLM server not responding at $LLM_API_BASE — skipping aider review\033[0m"
  echo "   Set SKIP_AIDER_REVIEW=1 to suppress this warning"
  exit 0
fi

echo "🔍 Running Aider review via $LLM_API_BASE"

aider \
  --model openai/qwen3-coder-next \
  --yes \
  --no-auto-commit \
  --message "Analyze the current uncommitted changes. 
1. If there are critical logic errors or PRD mismatches, output 'RESULT: FAIL' and list them.
2. If the code is sound, output 'RESULT: PASS'.
3. Always suggest one new pattern for AGENTS.md." | tee .review_output

if grep -q "RESULT: FAIL" .review_output; then
  exit 1
fi
exit 0