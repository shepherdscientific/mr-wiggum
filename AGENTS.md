# Python Agent Logic (Lean Mode)

## 1. Python Environment
- VirtualEnv: `.venv/bin/activate`
- Type Checking: `mypy .`
- Testing: `pytest`

## 2. Iteration Rules
1. Read `prd.json` & `AGENTS.md`.
2. Check `git log -n 10`.
3. Execute ONE task from `prd.json` (Priority-based).
4. Update `progress.txt` (Human Audit) & `prd.json` (State).
5. If tests fail: Fix or document blocker in `AGENTS.md` and EXIT.

## 3. Discovered Patterns (The "Brain")
- [Add project-specific python gotchas here]

## 4. Aider Review (Mandatory Post-Implementation Gate)
- Run `./scripts/ralph/aider_review.sh` **after** implementation, **before** step 4.
- Apply *all* critical fixes Aider suggests.
- If Aider reports a reusable pattern (e.g., anti-pattern), add it here.
- If Aider finds a blocker you cannot fix: document in this file and EXIT (no commit).
