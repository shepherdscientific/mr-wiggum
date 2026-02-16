# Mr. Wiggum 🤖

> Ralph Wiggum fresh context architecture - autonomous coding with proper context management

## The Problem

Standard Ralph loops accumulate context over iterations, leading to:
- 120K+ token contexts
- LLM hits "dumb zone" (60-70% capacity)  
- Performance degradation
- Lost context during compaction

## The Solution

**Fresh context every iteration** (~20-40K tokens):
- No progress.txt journal
- Only prd.json + AGENTS.md + git
- Each iteration starts clean
- Consistent performance

## Quick Start

```bash
# 1. Clone into your project
cd your-project
curl -O https://raw.githubusercontent.com/shepherdscientific/mr-wiggum/main/ralph-fresh.sh
curl -O https://raw.githubusercontent.com/shepherdscientific/mr-wiggum/main/RALPH-PROMPT.md
curl -O https://raw.githubusercontent.com/shepherdscientific/mr-wiggum/main/AGENTS.md
curl -O https://raw.githubusercontent.com/shepherdscientific/mr-wiggum/main/prd.json.example
chmod +x ralph-fresh.sh

# 2. Create your prd.json
cp prd.json.example prd.json
vim prd.json  # Add your user stories

# 3. Customize AGENTS.md for your stack
vim AGENTS.md

# 4. Run
./ralph-fresh.sh claude 50
```

## Architecture

```
Iteration 1          Iteration 2          Iteration 3
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│Fresh context │     │Fresh context │     │Fresh context │
│              │     │              │     │              │
│Read:         │     │Read:         │     │Read:         │
│- prd.json    │     │- prd.json    │     │- prd.json    │
│- AGENTS.md   │     │- AGENTS.md   │     │- AGENTS.md   │
│- git log     │     │- git log     │     │- git log     │
│              │     │              │     │              │
│Work → Commit │     │Work → Commit │     │Work → Commit │
│EXIT (dies)   │     │EXIT (dies)   │     │EXIT (dies)   │
└──────────────┘     └──────────────┘     └──────────────┘
```

**Key:** Context never accumulates. Git commits ARE your progress log.

## Files

- **ralph-fresh.sh** - Loop script (fresh context every iteration)
- **RALPH-PROMPT.md** - Agent instructions
- **AGENTS.md** - Pattern library (auto-compacts at 500 lines)
- **prd.json** - Your task list

## prd.json Format

```json
{
  "projectName": "Your Project",
  "branchName": "ralph/feature-name",
  "userStories": [
    {
      "id": "STORY-001",
      "title": "Implement feature X",
      "acceptanceCriteria": [
        "Tests pass",
        "Type check passes"
      ],
      "passes": false
    }
  ]
}
```

## Usage

```bash
# Run with Claude Code (local LLM)
./ralph-fresh.sh claude 50

# Run with amp (Anthropic API)  
./ralph-fresh.sh amp 50

# Monitor progress
watch -n 5 'jq ".userStories[] | select(.passes == true) | .id" prd.json'
git log --oneline -20
```

## Key Differences

| Aspect | Standard Ralph | Mr. Wiggum |
|--------|---------------|------------|
| **progress.txt** | Growing journal | Eliminated |
| **Context size** | 120K+ tokens | 20-40K tokens |
| **Memory** | Accumulated | Git only |
| **AGENTS.md** | Optional | Core |
| **Session** | May persist | Always fresh |

## Best Practices

### Good User Story
```json
{
  "id": "API-001",
  "title": "Add user login endpoint",
  "acceptanceCriteria": [
    "POST /api/auth/login accepts email/password",
    "Returns JWT on success",
    "Tests pass"
  ],
  "passes": false
}
```

### Good AGENTS.md Entry
```markdown
## Database Queries

Always use parameterized queries:
```sql
db.query('SELECT * FROM users WHERE id = $1', [userId])
```
```

## Credits

Based on Geoffrey Huntley's Ralph Wiggum pattern.  
Architecture informed by Theo's breakdown of context management.

## License

MIT
