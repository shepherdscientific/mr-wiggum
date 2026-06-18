# Mr. Wiggum

![Ralph](ralph.webp)

Mr. Wiggum is a fork of [Ralph](https://github.com/snarktank/ralph) — an
autonomous coding loop that runs an AI coding tool over and over until every
item in a PRD is done. Each iteration is a **fresh instance with clean context**;
memory persists only through git history, `progress.txt`, and `prd.json`. Based
on [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/).

> **Tested paths:** this fork is developed and run primarily with **OpenCode**
> (DeepSeek / Kimi / any OpenRouter model) and, secondarily, **Claude Code**.
> The loop can also drive **Amp**, the **Gemini CLI**, and **Codex** — those
> backends are wired in but only lightly exercised, so treat them as
> experimental. Examples below lead with OpenCode.

> **Canonical source.** This repo is the **canonical Ralph harness** for these
> projects — the fully-instrumented loop (`ralph.sh`, `aider-review.sh`,
> `metrics-lib.sh`, `metrics-report.sh`) lives here and **new repos copy the
> harness from here**. Drop the scripts at a repo root (as in this repo) or into a
> `scripts/ralph/` subdirectory — they resolve the repo root either way. See
> [Using this as the canonical template](#using-this-as-the-canonical-template).

**What this fork adds on top of Ralph:**

- **OpenCode-first, multi-harness** — one loop, selectable backend (`--tool`),
  each with its own prompt file. OpenCode and Claude Code are the maintained
  paths.
- **Local↔remote failover** — estimates each iteration's input size and routes
  to a local llama-server when it fits, a remote API when it doesn't (or when
  the local server is down). Fully env-configurable.
- **Aider review gate (hardened)** — after each implementation, [aider](https://aider.chat)
  reviews the diff before committing, using a model you choose **independently**
  of the loop's model (a real second opinion). Never commits code that fails
  review; never reports a false pass on a provider error; and now **REVIEW-FAILs
  any iteration with no substantive code change** — an empty/no-op diff or a
  bookkeeping-only commit can no longer be rubber-stamped into a false pass.
- **Loop-owned story completion** — the *loop*, not the agent, flips `passes:true`
  in the root `prd.json`, appends `progress.txt`, and commits `feat(<STORY_ID>)`
  on a review PASS. Idempotent and opt-out (`RALPH_NO_AUTO_PASS=1`), so a cheap
  model that writes code but skips its own bookkeeping no longer re-works the same
  first-incomplete story forever.
- **Agent persona injection** — assign specialist personas to a story or the
  whole PRD; they're prepended to the prompt per iteration.
- **Real per-call metrics + energy cost** — every codegen/review call logs one
  self-tagged JSON record to `.ralph-metrics.jsonl` (tokens, cost, duration,
  verdict); `metrics-report.sh` aggregates iter/hr, review-rejection %, and the
  **true cost per story** including local **energy** (measured watts → kWh → ₦,
  all configurable). The legacy estimate log (`.ralph-cost.log`) still works.
- **Completion hook** — run any command when the loop finishes (e.g. auto-push).
- **PATCH-not-REWRITE guards** — prompts instruct surgical edits, not whole-file
  rewrites, avoiding silent regressions and wasted tokens.

---

## Prerequisites

- **An AI coding tool**, authenticated:
  - [OpenCode](https://opencode.ai) (`opencode`) — **recommended**. Native tool
    calling for Gemini, DeepSeek, Kimi, and any OpenRouter model; no provider
    lock-in.
  - [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (`claude`) —
    supported. Anthropic-hosted models only (see below).
  - Amp / [Gemini CLI](https://github.com/google-gemini/gemini-cli) / Codex —
    wired in but less tested. For Gemini models prefer OpenCode (the standalone
    Gemini CLI has tool-calling gaps that stall the loop).
- [aider](https://aider.chat) (`pip install aider-chat`) — for the review gate.
- `jq` (`brew install jq`).
- A git repository for your project.

---

## Setup

Copy the loop, the review gate, the seed pattern library, and the prompt file
for your tool into your project:

```bash
mkdir -p scripts/ralph
cp /path/to/mr-wiggum/{ralph.sh,aider-review.sh,AGENTS.md} scripts/ralph/
cp /path/to/mr-wiggum/OPENCODE.md scripts/ralph/          # OpenCode (recommended)
cp /path/to/mr-wiggum/CLAUDE.md   scripts/ralph/          # Claude Code (optional)
# Amp / Gemini CLI prompts also exist: prompt.md, GEMINI.md

cp -r /path/to/mr-wiggum/agency-agents scripts/ralph/     # optional personas
chmod +x scripts/ralph/ralph.sh scripts/ralph/aider-review.sh
```

(Alternatively install the bundled skills globally — `cp -r skills/prd skills/ralph ~/.claude/skills/` for Claude Code, or `~/.config/amp/skills/` for Amp.)

---

## Usage

```bash
# OpenCode, 10 iterations (recommended)
./scripts/ralph/ralph.sh --tool opencode 10

# Claude Code
./scripts/ralph/ralph.sh --tool claude 10

# Skip the review gate for one run
SKIP_AIDER_REVIEW=1 ./scripts/ralph/ralph.sh --tool opencode 10
```

The historical default tool is `amp`, so **pass `--tool opencode` explicitly**.
The loop reads `prd.json`, picks the highest-priority story with `passes:false`,
implements it, runs the review gate, commits, updates state, and exits — the next
iteration starts fresh.

---

## Harness configuration

### OpenCode (recommended)

OpenCode prompts for tool permissions interactively, which blocks an unattended
loop. Pre-approve everything in your project's `opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "deepseek/deepseek-v4-pro",
  "permission": {
    "read": "allow",
    "write": "allow",
    "bash": "allow",
    "external_directory": "allow"
  }
}
```

`external_directory` is a **separate** permission class from `read`/`write` —
the loop writes files like `/tmp/prd.json`, so without it you'll still get
prompts for those paths. (Claude Code's equivalent is
`--dangerously-skip-permissions`; Amp's is `--dangerously-allow-all`.)

The loop reads `model` from `opencode.json` for the cost log, so it records the
real model rather than just `opencode`.

**Any OpenRouter model (Kimi, Qwen, DeepSeek, Gemini, …)** — add a provider
block; OpenCode handles tool calling for all of them:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "openrouter/moonshotai/kimi-k2.6",
  "permission": { "read": "allow", "write": "allow", "bash": "allow", "external_directory": "allow" },
  "provider": {
    "openrouter": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "OpenRouter",
      "options": { "baseURL": "https://openrouter.ai/api/v1", "apiKey": "{env:OPENROUTER_API_KEY}" },
      "models": { "moonshotai/kimi-k2.6": { "name": "Kimi K2.6", "limit": { "context": 131072, "output": 16384 } } }
    }
  }
}
```

Swap `model` and the `models` key for any other provider/model (Google via
`@ai-sdk/google` + `GEMINI_API_KEY`, DeepSeek direct, etc.); the rest is
identical. Then `export OPENROUTER_API_KEY=sk-or-...` and run `--tool opencode`.

### Claude Code

Three env vars route Claude Code through OpenRouter — no config file:

```bash
export ANTHROPIC_BASE_URL=https://openrouter.ai/api
export ANTHROPIC_AUTH_TOKEN=sk-or-...   # OpenRouter key
export ANTHROPIC_API_KEY=               # must be explicitly empty
./scripts/ralph/ralph.sh --tool claude 10
```

> The Claude Code CLI is hardcoded to Anthropic's provider protocol, so even via
> OpenRouter it can only call **Anthropic-hosted models** (Sonnet/Haiku/Opus).
> For Kimi/Qwen/etc. use OpenCode. If you already have an Anthropic
> subscription, link your key under OpenRouter → *Settings → Integrations*
> (BYOK) so Anthropic requests bill to your own account.

### Other harnesses (experimental)

Amp (`--tool amp`, `--dangerously-allow-all`) and Codex (`--tool codex`) are
supported but lightly tested. The Gemini **CLI** (`--tool gemini`) has
tool-calling gaps that break file edits/bash — to use a Gemini *model*, run it
through OpenCode instead (provider block above).

---

## Agent Personas

Each story (or the whole PRD) can run with a specialist mindset. Personas live in
`agency-agents/` and are prepended to the prompt before each iteration.

```json
{
  "agents": ["engineering-software-architect"],
  "userStories": [
    { "id": "US-001", "agents": ["engineering-frontend-developer"], "title": "Build the dashboard UI" },
    { "id": "US-002", "title": "Add API endpoint" }
  ]
}
```

Resolution order: `story.agents` → `prd.agents` → none (stories without agents
run exactly as before). Multiple agents concatenate in order. There are 27
personas across Engineering / Testing / Product / Design — see
[`agency-agents/README.md`](agency-agents/README.md).

---

## Aider Review Gate

After each implementation, `aider-review.sh` reviews the diff before the commit,
using a model chosen independently of the loop. It **embeds the working-tree
diff** in the prompt (so the model can't ask for it) and reports success only on
an explicit `RESULT: PASS`; a provider/model error produces a clear "did NOT
run" warning — **never a false pass**.

**Substantive-diff hardening.** Before the reviewer model runs, the gate checks
that the iteration actually changed CODE. It looks at this iteration's work —
commits since `RALPH_BASE_SHA` (the HEAD `ralph.sh` captured *before* the agent
ran) plus the working tree — and **REVIEW-FAILs** when nothing substantive
changed: an empty/no-op diff, or a commit that touches only bookkeeping files
(`prd.json`, `progress.txt`, `.ralph-metrics.jsonl`, `.ralph-cost.log`,
`.last-branch`) such as the harness's own "mark `passes:true`" commit. This is
the exact bug that let an errored codegen run get rubber-stamped to a false
13/13. It runs *before* the reviewer-availability checks (which exit `0` = skip,
read by the loop as a pass), so it fails hard even when no reviewer is
configured. Opt out for a genuine no-code story with `RALPH_ALLOW_EMPTY_DIFF=1`.

**Loop-owned completion.** On a review PASS the *loop* does the bookkeeping for
the story it set out to work this iteration — flips `passes:true` in the root
`prd.json`, appends `progress.txt`, and commits `feat(<STORY_ID>)`. It's
idempotent (a clean no-op when the agent already self-completed) and disabled
with `RALPH_NO_AUTO_PASS=1`.

**Provider auto-detection** (from the `AIDER_REVIEW_MODEL` prefix):

- `gemini/*` — uses `GEMINI_API_KEY`, no base URL (native litellm).
- `openrouter/*` — uses `OPENROUTER_API_KEY`, no base URL. Use this for Kimi /
  Qwen / Gemini / Claude via OpenRouter, e.g. `openrouter/moonshotai/kimi-k2.6`.
  (A bare `google/gemini-2.5-pro` has **no** litellm route — prefix `openrouter/`.)
- any other prefix (`deepseek/…`) — uses `AIDER_REVIEW_API_BASE` +
  `AIDER_REVIEW_API_KEY` (falling back to `OPENAI_BASE_URL` / `OPENAI_API_KEY`).
- unset — falls back to a local server with a health check; skips gracefully if
  unreachable.

```bash
# Recommended: cheap DeepSeek coder + independent Kimi reviewer
source .env.deepseek-kimi      # OPENCODE_MODEL=deepseek-* + AIDER_REVIEW_MODEL=openrouter/moonshotai/kimi-k2.6
./scripts/ralph/ralph.sh --tool opencode 7
```

---

## Environment variables

Every variable has a default — set only what you need. Provider **API keys** do
not live in this repo; they belong in the endpoint env files referenced by
`RALPH_LOCAL_ENV` / `RALPH_REMOTE_ENV` (typically `~/.local/bin/ralph-*.env`),
or in a gitignored `.env` you `source`. See `.env.example` and
`.env.deepseek-kimi.example`.

### Loop & cost

| Variable | Default | Purpose |
|---|---|---|
| *(arg)* `--tool` | `amp` | Backend: `opencode` (recommended), `claude`, `amp`, `gemini`, `codex`. |
| *(arg)* iterations | `10` | Max iterations, e.g. `ralph.sh --tool opencode 7`. |
| `OPENCODE_MODEL` | from `opencode.json` | Model name recorded in the cost log (falls back to `opencode.json`'s `model`). |
| `RALPH_COST_PER_MTOK_INPUT` | `0.27` | USD per 1M **input** tokens for `est_cost_usd` (DeepSeek ≈ 0.27, Kimi ≈ 0.74). |
| `RALPH_ON_COMPLETE` | *(unset)* | Command run once when the loop finishes — e.g. `'pullscript.sh . -p'` or `'git push'`. |
| `SKIP_AIDER_REVIEW` | `0` | `1` skips the review gate for the run. |

### Local↔remote failover

| Variable | Default | Purpose |
|---|---|---|
| `RALPH_LOCAL_ENV` | `~/.local/bin/ralph-local-llama.env` | Env file sourced when routing **local**. |
| `RALPH_REMOTE_ENV` | `~/.local/bin/ralph-opencode-anthropic.env` | Env file sourced when routing **remote**. |
| `RALPH_LOCAL_CONTEXT_MAX` | `131072` | Local model's hard context window (tokens). |
| `RALPH_LOCAL_CONTEXT_PCT` | `80` | Fail over to remote above this % of MAX. |
| `RALPH_AGENT_READ_BUDGET` | `30000` | Est. tokens the agent reads from the codebase on top of the prompt files. |
| `RALPH_LOCAL_LLAMA_URL` | `http://localhost:8080/health` | Health probe (3s); failure forces remote. |
| `RALPH_FORCE_REMOTE` | `0` | `1` always routes remote (skip estimation). |
| `RALPH_DISABLE_FAILOVER` | `0` | `1` always routes local (skip estimation). |

### Review gate

| Variable | Default | Purpose |
|---|---|---|
| `AIDER_REVIEW_MODEL` | *(unset → local)* | Reviewer model, e.g. `openrouter/moonshotai/kimi-k2.6`, `gemini/gemini-2.5-pro`, `deepseek/deepseek-chat`. |
| `AIDER_REVIEW_API_BASE` | `$LLM_API_BASE` | API base for OpenAI-compatible reviewers. |
| `AIDER_REVIEW_API_KEY` | `$LLM_API_KEY` | API key for the reviewer. |
| `LLM_API_BASE` | `http://localhost:8080/v1` | Local server base (used when `AIDER_REVIEW_MODEL` is unset). |
| `LLM_API_KEY` | `dummy` | Local server key. |
| `GEMINI_API_KEY` / `OPENROUTER_API_KEY` | — | Picked up automatically for `gemini/*` / `openrouter/*` reviewers. |
| `RALPH_ALLOW_EMPTY_DIFF` | `0` | `1` lets the gate pass an iteration with no code change (a genuine no-code / docs-only story). |

### Completion & bookkeeping

| Variable | Default | Purpose |
|---|---|---|
| `RALPH_NO_AUTO_PASS` | `0` | `1` disables loop-owned completion — the agent itself must flip `passes:true` and commit `feat(<id>)`. |

### Metrics & energy

| Variable | Default | Purpose |
|---|---|---|
| `RALPH_POWER_SAMPLE` | `0` | `1` measures real SoC watts per **local** iteration via macOS `powermetrics` (needs passwordless sudo); else the ceiling below. |
| `RALPH_POWER_KW` | `0.09` | Fallback local power draw (kW) when not measured — the 90 W ceiling. |
| `RALPH_TARIFF_NGN_PER_KWH` | `345` | Electricity tariff (₦/kWh) for local energy cost (Nigeria Band A). |
| `RALPH_NGN_PER_USD` | `1400` | FX rate for the USD comparison column (₦ is ground truth). |
| `RALPH_COST_PER_MTOK_OUTPUT` | input rate | USD per 1M **output** tokens — compute cloud cost from real tokens when a tool prints none. |

---

## Run on completion

Set `RALPH_ON_COMPLETE` to a command and Ralph runs it once when the loop
finishes — whether it completed every story, emitted
`<promise>COMPLETE</promise>`, or hit max iterations. It runs in a subshell and
its exit code never masks the loop's result. Unset = no-op (opt-in).

```bash
export RALPH_ON_COMPLETE='pullscript.sh . -p'   # or 'git push'
./scripts/ralph/ralph.sh --tool opencode 10
```

**Multi-repo workflow.** When you run the loop across several repos that finish
at different times, [`pullscript`](https://github.com/shepherdscientific/pullscript)
(recursively pushes/pulls every git repo under a path) is a clean fit for the
hook — `RALPH_ON_COMPLETE='pullscript.sh . -p'`. Each finished loop pushes itself;
pair that with a server-side deploy webhook and the push triggers the rebuild and
notification — fully hands-off.

---

## Cost tracking

Each iteration appends tab-separated lines to `.ralph-cost.log`, tagged by
**phase** so the coding run and the review gate can be tallied apart:

- `phase=run` — the coding iteration: timestamp, iteration, tool, **model**
  (read from `opencode.json` when no env override, so it's the real model — not
  just the tool name), endpoint, estimated input tokens, and an **estimated
  input cost** (`est_cost_usd = est_tokens × RALPH_COST_PER_MTOK_INPUT`). A
  best-effort second `phase=run` line records the tool's own reported
  `actual_cost_usd` (or `NA` when the tool prints none).
- `phase=review` — the review gate: its model (`AIDER_REVIEW_MODEL`) and reported
  `actual_cost_usd`. Worth watching when review runs a pricier model (Kimi) than
  the coder (DeepSeek).

Tally spend by phase and model:

```bash
awk -F'\t' '{p="";m="";c="";for(i=1;i<=NF;i++){if($i~/^phase=/)p=substr($i,7);if($i~/^model=/)m=substr($i,7);if($i~/cost_usd=/){split($i,a,"=");c=a[2]}} if(c!=""&&c!="NA")s[p"\t"m]+=c} END{print "phase\tmodel\tUSD";for(k in s)printf "%s\t$%.4f\n",k,s[k]}' .ralph-cost.log
```

### Real per-call metrics (`.ralph-metrics.jsonl`)

For ground-truth numbers the loop also writes **one self-tagged JSON record per
API call** (codegen and review) to `.ralph-metrics.jsonl` via `metrics-lib.sh`:
real tokens, real cost (or an honest `null` when a provider reports none — never
a fabricated estimate), duration, endpoint (`local`/`cloud`), review `verdict`,
and measured `avg_watts` for local iterations. Appends are atomic and
concurrency-safe, and every row is tagged with repo + model + role, so parallel
loops can even share a file without the rows blurring.

`metrics-report.sh` aggregates them — per repo × codegen-model × reviewer:

```bash
./metrics-report.sh                  # this repo's .ralph-metrics.jsonl
./metrics-report.sh ~/code/projects  # every loop under a dir (root- or scripts/ralph-layout)
```

It reports **iter/hr**, review **rejection %**, and the **true cost per story** —
which for a local run is **not $0**: it includes the Mac's **energy** (measured
watts → kWh → ₦ at your Band-A tariff) plus the cloud review-API spend. Tune
`RALPH_POWER_KW`, `RALPH_TARIFF_NGN_PER_KWH`, `RALPH_NGN_PER_USD` (see
[Metrics & energy](#metrics--energy)); set `RALPH_POWER_SAMPLE=1` to measure real
watts instead of the 90 W ceiling.

---

## Key Files

| File | Purpose |
|------|---------|
| `ralph.sh` | The loop: fresh instance per iteration, failover, review gate, cost log, completion hook. |
| `aider-review.sh` | Provider-agnostic code-review gate. |
| `OPENCODE.md` / `CLAUDE.md` | Prompt templates (OpenCode / Claude Code). |
| `prompt.md` / `GEMINI.md` / `AIDER_CODEX.md` | Prompt templates for the less-tested backends. |
| `AGENTS.md` | Seed pattern library — copy into your project and curate. |
| `prd.json.example` | Example PRD (includes `agents` fields). |
| `agency-agents/` | 27 specialist persona files. |
| `.env.example` / `.env.deepseek-kimi.example` | Config templates (failover knobs / DeepSeek+Kimi setup). |
| `metrics-lib.sh` | Emits one **real** per-call JSON metric to `.ralph-metrics.jsonl`; sourced by the loop + review gate (no-op stubs if absent). |
| `metrics-report.sh` | Aggregates `.ralph-metrics.jsonl` → iter/hr, rejection %, true ₦/$ per story incl. energy. |
| `test-harness-bookkeeping.sh` / `test-metrics.sh` / `test-review-gate.sh` | Self-contained tests for loop-owned completion, metrics, and the review-gate hardening. |
| `.ralph-cost.log` | Legacy per-iteration estimate log (superseded by `.ralph-metrics.jsonl`; gitignored). |
| `.ralph-metrics.jsonl` | Real per-call metrics — one JSON record per codegen/review call (gitignored). |

---

## Using this as the canonical template

This repo is the **canonical Ralph harness** — the source of truth. New projects
copy the harness from here; the scripts resolve the repo root themselves, so they
work whether they sit at the repo root (as here) or in a `scripts/ralph/` subdir:

```bash
# from the new repo's root
mkdir -p scripts/ralph
cp ~/tools/mr-wiggum/{ralph.sh,aider-review.sh,metrics-lib.sh,metrics-report.sh} scripts/ralph/
cp ~/tools/mr-wiggum/{OPENCODE.md,CLAUDE.md,AGENTS.md,prompt.md} scripts/ralph/   # the prompts you use
cp ~/tools/mr-wiggum/prd.json.example prd.json                                    # then edit your stories
# add to .gitignore:  .ralph-metrics.jsonl  .ralph-cost.log  and your real .env* files
./scripts/ralph/ralph.sh --tool opencode 10
```

`PRD_FILE`, the progress log, and the metrics file all resolve from
`git rev-parse --show-toplevel`, so `prd.json` is always read from and written to
the **real repo root**. Everything degrades to a safe no-op if a piece is missing
(no `metrics-lib.sh` → the loop runs exactly as before; no reviewer configured →
the review gate's empty-diff guard still fails a no-op iteration).

When you improve the harness, **change it here first**, then re-copy into the
target repos — don't fork per-project. The bundled tests
(`test-harness-bookkeeping.sh`, `test-metrics.sh`, `test-review-gate.sh`) guard
the loop-owned completion, the metrics, and the review-gate hardening.

---

## References

- [Original Ralph by Geoffrey Huntley](https://ghuntley.com/ralph/)
- [snarktank/ralph](https://github.com/snarktank/ralph) — upstream repo
- [shepherdscientific/pullscript](https://github.com/shepherdscientific/pullscript) — recursive multi-repo git push/pull (pairs with `RALPH_ON_COMPLETE`)
- [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents) — source of the persona files
- [aider](https://aider.chat) · [OpenCode](https://opencode.ai) · [Claude Code](https://docs.anthropic.com/en/docs/claude-code) · [OpenRouter](https://openrouter.ai)
