# Mr. Wiggum 🤖

> Fresh context Ralph Wiggum architecture - autonomous coding with zero context accumulation

[![Claude Code Skill](https://img.shields.io/badge/Claude_Code-Skill-blue)](https://github.com/shepherdscientific/mr-wiggum/tree/main/skills/wiggum)

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

## Claude Code Skill

Add the Wiggum skill for automated PRD conversion:

### Installation

```bash
# Option 1: Add skill to Claude Code configuration
claude add-skill --path /path/to/mr-wiggum/skills/wiggum

# Option 2: Reference in your project (recommended)
cd your-project
mkdir -p .claude/skills
ln -s /path/to/mr-wiggum/skills/wiggum .claude/skills/wiggum

# Option 3: Copy skill directory directly
cp -r /path/to/mr-wiggum/skills/wiggum your-project/.claude/skills/
```

### Usage

```bash
# In Claude Code
claude "Use the wiggum skill to convert PRD.md to prd.json"

# Or in chat
claude chat
> Use wiggum skill on specs/feature.md
```

### What the Skill Does

1. **Parses your PRD.md** - Markdown format
2. **Optimizes for fresh context** - Stories sized for ~30K tokens
3. **Generates minimal JSON** - No unnecessary fields
4. **Validates structure** - Ensures valid prd.json
5. **Orders dependencies** - Schema → Backend → UI

**Note:** Skills in Claude Code are directories containing a SKILL.md file with frontmatter. No installation manifest or marketplace submission needed - just reference the skill directory.

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
# Make sure skill is linked/referenced in your project
claude "Use wiggum skill to convert PRD.md"
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
claude "wiggum skill: convert PRD" # Convert to JSON
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
| **Claude Code Skill** | Plugin system (old) | Skill directory (current) |

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
# Link skill to your project
cd your-project
mkdir -p .claude/skills
ln -s ~/bin/mr-wiggum/skills/wiggum .claude/skills/wiggum
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
- **[Claude Code Skills Docs](https://code.claude.com/docs/en/skills)** - Official skills documentation

## Contributing

PRs welcome! Especially for:
- Additional code review integrations
- Improved parsing in wiggum skill
- Better AGENTS.md templates
- Documentation improvements
