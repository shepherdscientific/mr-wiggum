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
- Alembic migrations require `alembic.ini` configuration file with `script_location = db/migrations` and `prepend_path = .`
- When running Alembic from `orchestrator/`, the env.py must add the repo root (parent of orchestrator/) to sys.path for imports
- Use `sa.Enum("value1", "value2", ..., name="typename")` in migration files instead of `sa.Enum("typename", name="typename")` to avoid duplicate enum creation
- PostgreSQL JSONB type must be imported from `sqlalchemy.dialects.postgresql` (not `sqlalchemy`) - use `from sqlalchemy.dialects.postgresql import JSONB`
- Alembic async migrations require `greenlet` library - install with `pip install greenlet`
- Alembic async migrations with asyncpg require `psycopg2-binary` - install with `pip install psycopg2-binary`

## 4. ⚠️ CRITICAL: Updating prd.json Safely

**NEVER manually edit prd.json or use sed/awk!** This creates duplicate keys.

**ALWAYS use jq to update prd.json:**

```bash
# Mark a story as complete (US-015)
jq '(.userStories[] | select(.id == "US-015") | .passes) = true' prd.json > /tmp/prd.json && mv /tmp/prd.json prd.json

# Mark a story as incomplete
jq '(.userStories[] | select(.id == "US-015") | .passes) = false' prd.json > /tmp/prd.json && mv /tmp/prd.json prd.json

# Update notes for a story
jq '(.userStories[] | select(.id == "US-015") | .notes) = "Implementation complete"' prd.json > /tmp/prd.json && mv /tmp/prd.json prd.json
```

**Validation: Check for duplicate keys before committing:**

```bash
# Run validation script
./validate-prd.sh

# Or manual check (should return empty)
python3 -c "import json; d=json.load(open('prd.json')); print('Duplicates found!' if any('passes' in str(s) and str(s).count('\"passes\"') > 1 for s in d['userStories']) else '')"
```

**If you find duplicate keys, run:**
```bash
./fix-prd-duplicates.sh
```

## 5. Aider Review (Mandatory Post-Implementation Gate)
- Run `./scripts/ralph/aider-review.sh` **after** implementation, **before** updating prd.json.
- Apply *all* critical fixes Aider suggests.
- If Aider reports a reusable pattern (e.g., anti-pattern), add it here.
- If Aider finds a blocker you cannot fix: document in this file and EXIT (no commit).

## 6. Harness behavior — the LOOP owns completion & metrics (read this)

- **You don't have to flip `passes:true` yourself.** On a review PASS the loop
  flips `passes:true` in the **root** `prd.json`, appends `progress.txt`, and
  commits `feat(<STORY_ID>)` for the story it assigned this iteration. Still do
  your own bookkeeping when you can — it's idempotent, the loop no-ops if you
  already did it — but a missed jq update no longer strands the story forever.
  (Operator can disable loop-owned completion with `RALPH_NO_AUTO_PASS=1`.)
- **The review gate REVIEW-FAILs an iteration that changed no CODE.** An empty /
  no-op diff, or a commit that touches only bookkeeping files (`prd.json`,
  `progress.txt`, `.ralph-metrics.jsonl`, `.ralph-cost.log`, `.last-branch`), is
  rejected — you cannot "complete" a story by only marking it done. Write the
  actual code. (Genuine no-code story: operator sets `RALPH_ALLOW_EMPTY_DIFF=1`.)
- **`prd.json` lives at the repo ROOT**, not next to the scripts. Always update
  the root `prd.json` with the safe jq pattern in section 4.
- **Metrics are automatic.** Every codegen/review call appends one JSON record to
  `.ralph-metrics.jsonl` (gitignored). Don't hand-write it; don't commit it.
