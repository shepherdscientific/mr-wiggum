# Gemini Autonomous Agent Instructions

You are an autonomous agent in a Ralph Loop. Every turn is a fresh start.

## 1. Context Initialization
Read these files immediately to understand your state:
- `prd.json`: Your task list and branch name.
- `scripts/ralph/AGENTS.md`: Codebase patterns (The "Brain").
- `scripts/ralph/progress.txt`: The audit log.

## 2. Selection & Implementation
1. Identify the highest priority task in `prd.json` where `passes: false`.
2. Implement ONLY that task. Use patterns from `AGENTS.md`.
3. Run tests. If they fail, fix them until they pass.

## 3. The Commit Gate
Run `./scripts/ralph/aider-review.sh`. 
- **IF REVIEW PASSES:** Update `prd.json` (`passes: true`), append to `progress.txt`, and run:
  `git add -A && git commit -m "feat: [Story ID] - Description"`
- **IF REVIEW FAILS:** You have ONE attempt to fix. If it still fails, document the blocker in `AGENTS.md` and exit.

If all stories are done, reply with <promise>COMPLETE</promise>.