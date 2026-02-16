# Mr. Wiggum 🤖

> Fresh context Ralph Wiggum architecture - autonomous coding with zero context accumulation

[![Claude Code Plugin](https://img.shields.io/badge/Claude_Code-Plugin-blue)](https://github.com/shepherdscientific/mr-wiggum/tree/main/.claude-plugin)

## The Problem

Standard Ralph loops accumulate context, leading to:
- 120K+ token bloat per iteration
- LLM hits "dumb zone" at 60-70% capacity  
- Performance degradation over time
- Critical context lost during compaction

## The Solution

**Fresh context every iteration** (~20-40K tokens):
- No progress.txt journal ❌
- Only prd.json + AGENTS.md + git ✅
- Each iteration starts with 0 tokens ✅
- Consistent performance throughout ✅

## Quick Start

```bash
# 1. Copy files to your project
cd your-project
curl -O https://raw.githubusercontent.com/shepherdscientific/mr-wiggum/main/wiggum.sh
curl -O https://raw.githubusercontent.com/shepherdscientific/mr-wiggum/main/setup-wiggum.sh
curl -O https://raw.githubusercontent.com/shepherdscientific/mr-wiggum/main/CLAUDE.md
curl -O https://raw.githubusercontent.com/shepherdscientific/mr-wiggum/main/prompt.md
chmod +x wiggum.sh setup-wiggum.sh

# 2. Run interactive setup
./setup-wiggum.sh

# 3. Edit prd.json to define your user stories
vim prd.json

# 4. Start the loop
./wiggum.sh
```

## Claude Code Plugin

Install the Wiggum skill for automated PRD conversion:

### Installation

```bash
# Install from GitHub
claude skill add https://github.com/shepherdscientific/mr-wiggum

# Verify installation
claude skill list | grep wiggum
```

### Usage

```bash
# Convert PRD to prd.json
cd your-project
claude "Load wiggum skill and convert PRD.md to prd.json"

# Then run wiggum loop
./wiggum.sh --tool claude 50
```

### What the Skill Does

1. **Parses your PRD.md** - Markdown format
2. **Optimizes for fresh context** - Stories sized for ~30K tokens
3. **Generates minimal JSON** - No unnecessary fields
4. **Validates structure** - Ensures valid prd.json
5. **Orders dependencies** - Schema → Backend → UI

See [docs/MARKETPLACE.md](docs/MARKETPLACE.md) for publishing details.

## Files

| File | Purpose | Notes |
|------|---------|-------|
| `wiggum.sh` | Main loop script | Fresh context each iteration |
| `setup-wiggum.sh` | Interactive setup wizard | Creates AGENTS.md, prd.json, hooks |
| `CLAUDE.md` | Prompt for Claude Code | Used with `--tool claude` |
| `prompt.md` | Prompt for Amp | Used with `--tool amp` |
| `prd.json` | Structured task list | Machine-readable, no regex parsing |
| `AGENTS.md` | Pattern library | Auto-compacts at 500 lines |

## PRD Format

### From Markdown to JSON

Mr. Wiggum uses **structured JSON** instead of markdown for reliable parsing.

**Before (PRD.md):**
```markdown
# Project: User Auth
### AUTH-001: Login
- [ ] POST /api/login works
- [ ] Tests pass
```

**After (prd.json):**
```json
{
  "projectName": "User Auth",
  "branchName": "ralph/auth",
  "userStories": [
    {
      "id": "AUTH-001",
      "title": "Login",
      "acceptanceCriteria": [
        "POST /api/login works",
        "Tests pass"
      ],
      "passes": false
    }
  ]
}
```

### Conversion Methods

**Option 1: Claude Code Skill (Automated)**
```bash
claude skill add https://github.com/shepherdscientific/mr-wiggum
claude "Load wiggum skill and convert PRD.md"
```

**Option 2: Manual**
See [PRD Translation Guide](docs/PRD-TRANSLATION.md)

## Architecture

```
Iteration 1          Iteration 2          Iteration 3
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│0 tokens      │     │0 tokens      │     │0 tokens      │
│              │     │              │     │              │
│Read:         │     │Read:         │     │Read:         │
│- prd.json    │     │- prd.json    │     │- prd.json    │
│- AGENTS.md   │     │- AGENTS.md   │     │- AGENTS.md   │
│- git log     │     │- git log     │     │- git log     │
│              │     │              │     │              │
│Work → Commit │     │Work → Commit │     │Work → Commit │
│Update files  │     │Update files  │     │Update files  │
│EXIT          │     │EXIT          │     │EXIT          │
└──────────────┘     └──────────────┘     └──────────────┘
     ~30K                ~30K                 ~30K
```

**Key:** Context NEVER accumulates. Git commits ARE your progress log.

## Usage

### Basic

```bash
# With Claude Code (local LLM)
./wiggum.sh

# With Amp (Anthropic API)
./wiggum.sh --tool amp

# Custom max iterations
./wiggum.sh 100
```

### With Claude Code Skill

```bash
# Full workflow
vi specs/feature.md         # Write PRD
claude "wiggum convert PRD" # Convert to JSON
vi prd.json                 # Review
./wiggum.sh                 # Run loop
```

### Monitor Progress

```bash
# Watch task completion
watch -n 5 'jq ".userStories[] | select(.passes == true)" prd.json'

# Recent commits
git log --oneline -20

# Learned patterns
cat AGENTS.md
```

### Code Review Integration

During setup, choose CodeRabbit for automated pre-commit reviews:

```bash
./setup-wiggum.sh
# Choose: 1) CodeRabbit
```

## Key Differences from Ralph

| Aspect | Standard Ralph | Mr. Wiggum |
|--------|---------------|------------|
| **Context file** | progress.txt (grows) | None |
| **Context size** | 120K+ tokens | 20-40K tokens |
| **Parsing** | Regex on markdown | Structured JSON |
| **Memory** | Accumulated | Files + git only |
| **AGENTS.md** | Optional | Core (auto-compact) |
| **Session** | May persist | Always fresh |
| **Performance** | Degrades | Consistent |
| **Claude Code Skill** | Available | ✅ Available |

## Best Practices

### Good User Story

```json
{
  "id": "API-001",
  "title": "User login endpoint",
  "acceptanceCriteria": [
    "POST /api/auth/login accepts email/password",
    "Returns JWT token on valid credentials",
    "Returns 401 on invalid credentials",
    "Password is hashed with bcrypt",
    "Tests pass",
    "Type check passes"
  ],
  "passes": false
}
```

**Features:**
- ✅ Specific, actionable criteria
- ✅ Includes test requirements
- ✅ Verifiable completion
- ✅ One focused task

### Good AGENTS.md Pattern

```markdown
## Database Queries

Always use parameterized queries to prevent SQL injection:

```sql
-- Good
db.query('SELECT * FROM users WHERE id = $1', [userId])

-- Bad
db.query(`SELECT * FROM users WHERE id = ${userId}`)
```
```

## Troubleshooting

### Context Still Growing

**Check:**
- AGENTS.md size (should be <500 lines)
- prd.json complexity (break into smaller stories)
- Not reading unnecessary files in prompts

### Agent Forgetting Patterns

**This is expected.**
- Not everything needs remembering
- Git history is the source of truth
- Only add patterns that help future work

### Tasks Not Completing

**Break them down:**
- One story = one commit
- ~2-4 hours of work maximum
- Clear, verifiable acceptance criteria

## Installation Options

### Option 1: Per-Project (Recommended)

```bash
cd your-project
curl -O https://raw.githubusercontent.com/shepherdscientific/mr-wiggum/main/wiggum.sh
chmod +x wiggum.sh
./setup-wiggum.sh
```

### Option 2: Global Installation

```bash
mkdir -p ~/bin
cd ~/bin
git clone https://github.com/shepherdscientific/mr-wiggum.git
ln -s ~/bin/mr-wiggum/wiggum.sh ~/bin/wiggum
```

### Option 3: Claude Code Skill

```bash
claude skill add https://github.com/shepherdscientific/mr-wiggum
```

## Credits

- Based on [Geoffrey Huntley's Ralph Wiggum pattern](https://ghuntley.com/ralph/)
- Architecture informed by [Theo's context management breakdown](https://www.youtube.com/watch?v=Yr9O6KFwbW4)
- Inspired by [snarktank/ralph](https://github.com/snarktank/ralph)

## License

MIT - see [LICENSE](LICENSE)

## Resources

- **[PRD Translation Guide](docs/PRD-TRANSLATION.md)** - Convert markdown to JSON
- **[Wiggum Skill](skills/wiggum/SKILL.md)** - Claude Code skill documentation
- **[Plugin Files](.claude-plugin/)** - Claude Code plugin structure
- **[Marketplace Guide](docs/MARKETPLACE.md)** - Publishing to Claude Code marketplace

## Contributing

PRs welcome! Especially for:
- Additional code review integrations
- Improved parsing in wiggum skill
- Better AGENTS.md templates
- Documentation improvements
