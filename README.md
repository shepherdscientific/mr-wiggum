# Mr. Wiggum

![Ralph](ralph.webp)

Mr. Wiggum is a fork of [Ralph](https://github.com/snarktank/ralph) — an autonomous AI agent loop that runs AI coding tools ([Amp](https://ampcode.com) or [Claude Code](https://docs.anthropic.com/en/docs/claude-code)) repeatedly until all PRD items are complete. Each iteration is a fresh instance with clean context. Memory persists via git history, `progress.txt`, and `prd.json`.

**What this fork adds on top of Ralph:**
- **Aider code review gate** — after each implementation, [aider](https://aider.chat) reviews the diff using a local or remote LLM before committing. Critical issues must be fixed; the loop never commits code that fails review.
- **Local LLM support** — the review step works against any OpenAI-compatible server (llama.cpp, Ollama, LiteLLM, etc.) via `LLM_API_BASE`. No cloud dependency required for the review pass.
- **`SKIP_AIDER_REVIEW` env var** — opt out of the review step per-run without editing any files. Useful when iterating fast or when the local model server is offline.
- **Graceful server detection** — if the LLM server is unreachable (5s timeout), the review step skips automatically instead of blocking the loop indefinitely.

Based on [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/).

---

## Prerequisites

- One of the following AI coding tools installed and authenticated:
  - [Amp CLI](https://ampcode.com) (default)
  - [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (`npm install -g @anthropic-ai/claude-code`)
- [aider](https://aider.chat) installed (`pip install aider-chat`) — required for the review gate
- `jq` installed (`brew install jq` on macOS)
- A git repository for your project
- **For local LLM review:** a running OpenAI-compatible server (llama.cpp `llama-server`, Ollama, LiteLLM proxy, etc.)

---

## Setup

### Option 1: Copy to your project

```bash
# From your project root
mkdir -p scripts/ralph
cp /path/to/mr-wiggum/ralph.sh scripts/ralph/
cp /path/to/mr-wiggum/aider-review.sh scripts/ralph/
cp /path/to/mr-wiggum/AGENTS.md scripts/ralph/

# Copy the prompt template for your AI tool of choice:
cp /path/to/mr-wiggum/prompt.md scripts/ralph/prompt.md    # For Amp
# OR
cp /path/to/mr-wiggum/CLAUDE.md scripts/ralph/CLAUDE.md    # For Claude Code

chmod +x scripts/ralph/ralph.sh scripts/ralph/aider-review.sh
```

### Option 2: Install skills globally (Amp)

```bash
# For Amp
cp -r skills/prd ~/.config/amp/skills/
cp -r skills/ralph ~/.config/amp/skills/

# For Claude Code
cp -r skills/prd ~/.claude/skills/
cp -r skills/ralph ~/.claude/skills/
```

### Option 3: Use as Claude Code Marketplace

```bash
/plugin marketplace add snarktank/ralph
/plugin install ralph-skills@ralph-marketplace
```

Available skills after installation:
- `/prd` — Generate Product Requirements Documents
- `/ralph` — Convert PRDs to prd.json format

### Configure Amp auto-handoff (recommended)

Add to `~/.config/amp/settings.json`:

```json
{
  "amp.experimental.autoHandoff": { "context": 90 }
}
```

---

## Aider Review Gate

This fork adds an optional aider-powered code review step between implementation and commit. After Claude Code or Amp finishes a story, `aider-review.sh` runs aider against the current diff and asks it to identify critical issues before the commit happens.

### How it works

```
implement story → typecheck → tests → aider review → commit
                                           ↓
                                   fix critical issues
                                   (or document blocker and exit)
```

Aider reviews for:
- Correctness against the PRD acceptance criteria
- Test coverage and quality
- Type safety and anti-patterns
- Consistency with patterns in `AGENTS.md`

It returns critical issues (must fix), optional improvements, and any new patterns worth adding to `AGENTS.md`.

### Configuration

The review script is controlled by environment variables:

| Variable | Default | Description |
|---|---|---|
| `SKIP_AIDER_REVIEW` | `0` | Set to `1` to skip the review step entirely |
| `LLM_API_BASE` | `http://localhost:8080/v1` | OpenAI-compatible API base URL |
| `LLM_API_KEY` | `dummy` | API key (use `dummy` for local servers that don't require auth) |

### Running with a local LLM (llama.cpp example)

Start your local model server first:

```bash
llama-server \
  --host 0.0.0.0 \
  -m ~/.cache/huggingface/hub/models--unsloth--Qwen3-Coder-Next-GGUF/snapshots/main/Qwen3-Coder-Next-Q4_K_M.gguf \
  --port 8080 \
  --ctx-size 131072 \
  --n-gpu-layers 99 \
  --alias qwen3-coder-next
```

Then run Ralph — the review step points at `http://localhost:8080/v1` by default:

```bash
./scripts/ralph/ralph.sh --tool claude 10
```

### Running with a remote LLM

```bash
LLM_API_BASE=https://api.openai.com/v1 \
LLM_API_KEY=sk-... \
./scripts/ralph/ralph.sh --tool claude 10
```

### Skipping the review step

```bash
# Skip for this run only
SKIP_AIDER_REVIEW=1 ./scripts/ralph/ralph.sh --tool claude 10
```

If the LLM server is unreachable, the review step skips automatically with a warning rather than blocking the loop.

---

## Workflow

### 1. Create a PRD

```
Load the prd skill and create a PRD for [your feature description]
```

Answer the clarifying questions. The skill saves output to `tasks/prd-[feature-name].md`.

### 2. Convert PRD to Ralph format

```
Load the ralph skill and convert tasks/prd-[feature-name].md to prd.json
```

This creates `prd.json` with user stories structured for autonomous execution.

### 3. Run Mr. Wiggum

```bash
# Using Claude Code with aider review (default: review enabled, local LLM)
./scripts/ralph/ralph.sh --tool claude 10

# Using Amp
./scripts/ralph/ralph.sh --tool amp 10

# Skip aider review for speed
SKIP_AIDER_REVIEW=1 ./scripts/ralph/ralph.sh --tool claude 10

# Use a different local server
LLM_API_BASE=http://192.168.8.100:8080/v1 ./scripts/ralph/ralph.sh --tool claude 10
```

Each iteration:
1. Picks the highest priority story where `passes: false`
2. Implements that single story
3. Runs typechecks and tests
4. Runs aider review (unless `SKIP_AIDER_REVIEW=1`)
5. Fixes any critical issues aider identifies
6. Commits if all gates pass
7. Updates `prd.json` to mark story as `passes: true`
8. Appends learnings to `progress.txt`
9. Repeats until all stories pass or max iterations reached

---

## Key Files

| File | Purpose |
|------|---------|
| `ralph.sh` | The bash loop that spawns fresh AI instances |
| `prompt.md` | Prompt template for Amp |
| `CLAUDE.md` | Prompt template for Claude Code |
| `aider-review.sh` | Aider-powered code review gate (this fork) |
| `AGENTS.md` | Seed pattern library — copy to `scripts/ralph/AGENTS.md` in your project and customise for your stack |
| `prd.json.example` | Example PRD format for reference |
| `skills/prd/` | Skill for generating PRDs |
| `skills/ralph/` | Skill for converting PRDs to JSON |
| `.claude-plugin/` | Plugin manifest for Claude Code marketplace |
| `flowchart/` | Interactive visualization of how Ralph works |

---

## AGENTS.md — The Pattern Library

`AGENTS.md` is the most important file in the system. It is the only persistent, curated knowledge that survives between iterations. Every fresh Claude Code or Amp instance reads it at the start.

**What belongs in AGENTS.md:**
- Stack-specific patterns ("always use `select()` not `query()` in SQLAlchemy 2.x")
- Gotchas ("asyncssh not paramiko — paramiko blocks the event loop")
- Quality gate commands for your specific project
- Enum definitions and naming conventions
- Known blockers and how to work around them

**What does not belong:**
- Story-specific notes (those go in `prd.json` notes fields and `progress.txt`)
- Temporary debugging observations
- Things already obvious from reading the code

Keep it under 500 lines. When it grows past that, delete outdated entries. Future iterations benefit from density, not length.

The `AGENTS.md` in this repo is a generic seed. When you copy it to your project's `scripts/ralph/AGENTS.md`, rewrite it entirely for your stack. See [NeuralMesh's AGENTS.md](https://github.com/shepherdscientific/NeuralMesh/blob/main/scripts/ralph/AGENTS.md) for a real-world Python/FastAPI example.

---

## Critical Concepts

### Each Iteration = Fresh Context

Each iteration spawns a **new AI instance** with clean context. The only memory between iterations is git history, `progress.txt`, and `prd.json`. Design your stories and AGENTS.md accordingly.

### Small Tasks

Each PRD item should be completable in one context window. If a task is too big, split it.

Right-sized stories:
- Add a database model and migration
- Implement CRUD endpoints for one resource
- Add a background service
- Write a test suite for one module

Too big (split these):
- "Build authentication"
- "Create the billing system"
- "Implement all API endpoints"

### The Review Loop

The aider review gate catches issues that typechecks and tests miss — logical errors, missing edge cases, patterns that diverge from the rest of the codebase. When aider identifies a critical issue, the agent fixes it before committing. This keeps the git history clean and prevents bugs from compounding across iterations.

If the review identifies something the agent cannot fix in the current iteration, it documents the blocker in `AGENTS.md` and exits without committing. The next iteration reads the blocker and either solves it or routes around it.

### Stop Condition

When all stories have `passes: true`, the agent outputs `<promise>COMPLETE</promise>` and the loop exits.

---

## Debugging

```bash
# See which stories are done
cat prd.json | jq '.userStories[] | {id, title, passes}'

# Watch commits appear in real time
watch -n 30 'git log --oneline -5'

# Tail the progress log
tail -f progress.txt

# Morning stock-take
git log --oneline --since="8 hours ago"
python3 -c "
import json
d = json.load(open('prd.json'))
done = [s for s in d['userStories'] if s['passes']]
todo = [s for s in d['userStories'] if not s['passes']]
print(f'Done: {len(done)}/{len(d[\"userStories\"])}')
print('Next up:', todo[0]['id'], todo[0]['title'] if todo else 'ALL DONE')
"

# Check if processes are alive
ps aux | grep -E 'aider|claude|ralph' | grep -v grep
```

---

## Archiving

Mr. Wiggum automatically archives previous runs when you start a new feature (different `branchName` in `prd.json`). Archives are saved to `archive/YYYY-MM-DD-feature-name/`.

---

## Flowchart

[![Ralph Flowchart](ralph-flowchart.png)](https://snarktank.github.io/ralph/)

**[View Interactive Flowchart](https://snarktank.github.io/ralph/)**

```bash
cd flowchart
npm install
npm run dev
```

---

## References

- [Original Ralph by Geoffrey Huntley](https://ghuntley.com/ralph/)
- [snarktank/ralph](https://github.com/snarktank/ralph) — upstream repo this is forked from
- [aider](https://aider.chat) — the AI pair programming tool used for the review gate
- [Amp documentation](https://ampcode.com/manual)
- [Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code)
- [NeuralMesh](https://github.com/shepherdscientific/NeuralMesh) — a real project built with Mr. Wiggum
