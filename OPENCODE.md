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

## 4. Commit Changes
- Stage and commit all changes before updating state:
  ```bash
  git add -A
  git commit -m "feat(STORY-ID): Brief description of what was implemented"
  ```

## 5. State Update
- If successful, update `prd.json` setting `passes: true` for the story.
- Append a brief summary to `progress.txt` following the established format.
- If you discovered a new reusable pattern, add it to `AGENTS.md`.

## 6. Exit
- If ALL stories in `prd.json` are done, reply with: <promise>COMPLETE</promise>
- Otherwise, just state the task is finished and exit.
