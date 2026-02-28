#!/usr/bin/env bash
# scripts/ralph/aider_review.sh — local Qwen3-Coder-Next review agent
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}🔍 Running Aider review via Qwen3-Coder-Next (local)${NC}"

aider \
  --yes \
  --review \
  --model qwen3-coder-next \
  --openai-api-base http://localhost:8080/v1 \
  --openai-api-key dummy \
  --no-detect-models \
  --no-auto-commit \
  --message "Review the git diff since the last commit. Focus on:
- Correctness against PRD
- Test coverage & quality
- Type safety & anti-patterns
- Consistency with patterns in AGENTS.md

Return concise findings:
1. Critical issues (must fix)
2. Optional improvements
3. New patterns to add to AGENTS.md"
