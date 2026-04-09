# OpenCode Agent Instructions

> **Permissions note:** OpenCode prompts for tool permissions interactively by default. To run unattended in the Ralph loop, add the following to your project's `opencode.json`:
> ```json
> "permission": { "read": "allow", "write": "allow", "bash": "allow" }
> ```

You are operating in an autonomous Ralph Loop. Your goal is to move the project forward by exactly ONE user story per iteration.

## 1. Context Initialization
- Read `prd.json` to find the highest priority task where `passes: false`.
- Read `scripts/ralph/AGENTS.md` for project patterns and rules.
- Check `git log -n 5` to see recent changes.

## 2. Implementation Phase
- Work on ONLY the selected story.
- Use your `edit`, `write`, and `bash` tools to implement and test.
- Follow the patterns in `AGENTS.md` (e.g., SQLAlchemy Enum usage, migrations paths).

## 3. Quality Gate
- Run `cd orchestrator && mypy .` (or project equivalent).
- Run `pytest`.
- **Mandatory:** Run `./scripts/ralph/aider-review.sh`. You MUST apply any fixes marked as "Critical."

## 4. State Update
- If successful, update `prd.json` setting `passes: true` for **the single story you just implemented**.
- **CRITICAL — never bulk-update multiple stories.** Only mark a story `passes: true` after you have verifiably implemented and tested it in this iteration. Marking stories complete without doing the work is a critical failure.
- Append a brief summary to `progress.txt` following the established format.
- If you discovered a new reusable pattern, add it to `AGENTS.md`.

## 5. Exit
- **Do NOT emit `<promise>COMPLETE</promise>` unless `git diff HEAD~1` shows real implementation changes AND all stories in `prd.json` are genuinely complete.**
- If ALL stories in `prd.json` are done: reply with: <promise>COMPLETE</promise>
- Otherwise, just state the single task is finished and exit.
