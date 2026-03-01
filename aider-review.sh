#!/usr/bin/env bash
set -euo pipefail

# Verify aider is installed
if ! command -v aider &> /dev/null; then
  echo "⚠️ Aider not found, skipping review."
  exit 0
fi

echo "🔍 Running Aider Static Review..."

aider \
  --model openai/qwen3-coder-next \
  --openai-api-base "$LLM_API_BASE" \
  --openai-api-key "$LLM_API_KEY" \
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