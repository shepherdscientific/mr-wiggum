# Claude Code Skills Guide

This guide explains how to use and distribute the Mr. Wiggum skill with Claude Code.

## What Are Claude Code Skills?

Skills in Claude Code are self-contained directories with a `SKILL.md` file containing:
1. **Frontmatter** (YAML) - metadata like name, description, user-invocable flag
2. **Documentation** (Markdown) - instructions for Claude on how to use the skill

**No plugin manifest, no marketplace submission, no `.claude-plugin/` directory needed.**

## Mr. Wiggum Skill Structure

```
skills/wiggum/
└── SKILL.md          # Skill with frontmatter + documentation
```

That's it! No `plugin.json` or `marketplace.json` required.

## Installation

### Method 1: Reference in Project (Recommended)

```bash
# In your project
cd your-project
mkdir -p .claude/skills

# Symlink the skill
ln -s /path/to/mr-wiggum/skills/wiggum .claude/skills/wiggum

# Or copy it
cp -r /path/to/mr-wiggum/skills/wiggum .claude/skills/
```

### Method 2: Add to Claude Code Configuration

```bash
# Add skill path to Claude Code
claude add-skill --path /path/to/mr-wiggum/skills/wiggum
```

### Method 3: Clone Repo into Skills Directory

```bash
# Clone entire repo into your project's skills folder
cd your-project/.claude/skills
git clone https://github.com/shepherdscientific/mr-wiggum.git
# Claude Code will find skills/wiggum/SKILL.md automatically
```

## Using the Skill

### In Claude Code CLI

```bash
# Convert a PRD
claude "Use the wiggum skill to convert PRD.md to prd.json"

# With specific file
claude "Use wiggum skill on specs/feature.md"

# Interactive
claude chat
> Use wiggum skill to convert my PRD
```

### In Project with Wiggum Loop

```bash
# Complete workflow
vi specs/new-feature.md              # Write PRD
claude "wiggum skill: convert PRD"   # Convert to prd.json
vi prd.json                           # Review/edit
./wiggum.sh --tool claude 50          # Run wiggum loop
```

## How Skills Work

1. **Discovery**: Claude Code finds skills in:
   - Project `.claude/skills/` directory
   - Global skills configured with `claude add-skill`

2. **Loading**: When invoked, Claude reads the SKILL.md file

3. **Execution**: Claude follows the instructions in SKILL.md

4. **Context**: Skills only affect the current conversation - they don't persist state

## Skill Frontmatter

The wiggum skill's frontmatter:

```yaml
---
name: wiggum
description: "Convert PRDs to prd.json format for Mr. Wiggum fresh context autonomous agent system"
user-invocable: true
---
```

**Fields:**
- `name`: Unique identifier for the skill
- `description`: What the skill does (shown to Claude)
- `user-invocable`: If true, users can explicitly request the skill

## Distributing Skills

### Via GitHub

Users can clone your repo into their skills folder:

```bash
cd .claude/skills
git clone https://github.com/shepherdscientific/mr-wiggum.git
```

Claude Code automatically discovers `skills/wiggum/SKILL.md`.

### Via Direct Share

Share the skill directory:

```bash
# Zip the skill
cd mr-wiggum/skills
zip -r wiggum-skill.zip wiggum/

# Users extract to their skills folder
unzip wiggum-skill.zip -d ~/.claude/skills/
```

### Via Documentation

Include installation instructions in your README:

```markdown
## Installation

```bash
cd your-project/.claude/skills
git clone https://github.com/you/your-skill.git
```

Or copy the skill directory directly.
```

## No Marketplace (Yet)

**Important:** There is no central Claude Code skills marketplace currently. Distribution is manual:
- GitHub repos
- Direct file sharing
- Documentation with installation instructions

If Anthropic adds a marketplace in the future, skills will likely remain simple directories with SKILL.md files.

## Testing Your Skill

### Local Testing

```bash
# 1. Add skill to a test project
cd ~/test-project
mkdir -p .claude/skills
ln -s /path/to/mr-wiggum/skills/wiggum .claude/skills/wiggum

# 2. Test with Claude Code
echo "# Test PRD" > test.md
claude "Use wiggum skill to convert test.md"

# 3. Verify output
cat prd.json | jq .
```

### Validation Checklist

- [ ] SKILL.md has valid YAML frontmatter
- [ ] Frontmatter includes name, description, user-invocable
- [ ] Skill documentation is clear and actionable
- [ ] Claude Code can find and load the skill
- [ ] Skill produces expected output
- [ ] Works in realistic project scenarios

## Skill Best Practices

### Clear Invocation Triggers

Document how users invoke the skill:

```markdown
**Invocation examples:**
- "Use wiggum skill to convert my PRD"
- "wiggum: convert PRD.md"
- "Load wiggum skill"
```

### Focused Scope

Skills should do ONE thing well:
- ✅ Convert PRD to JSON
- ✅ Generate test cases
- ✅ Create API docs
- ❌ "Do everything" mega-skill

### Minimal Dependencies

Skills work best when self-contained:
- No external tools required
- No API keys needed (unless core to function)
- Works with just Claude + files

### Clear Output Format

Specify exactly what the skill produces:

```markdown
**Output:** Creates `prd.json` in current directory with format:
```json
{
  "projectName": "...",
  "userStories": [...]
}
```
```

## Troubleshooting

### Skill Not Found

```bash
# Check skills directory exists
ls -la .claude/skills/

# Check skill has SKILL.md
ls -la .claude/skills/wiggum/

# Check frontmatter
head -10 .claude/skills/wiggum/SKILL.md
```

### Skill Not Loading

```bash
# Try explicit invocation
claude "Use the skill named 'wiggum' to convert PRD.md"

# Check for YAML syntax errors
head -10 .claude/skills/wiggum/SKILL.md | grep -A 5 "^---$"
```

### Wrong Output Format

- Verify SKILL.md documentation is clear
- Add more examples to SKILL.md
- Specify output format explicitly

## Comparison: Old vs New System

| Aspect | Old Plugin System | Current Skills System |
|--------|-------------------|----------------------|
| **Structure** | `.claude-plugin/` directory | Simple SKILL.md file |
| **Metadata** | `plugin.json`, `marketplace.json` | YAML frontmatter |
| **Installation** | `claude skill add` (complex) | Copy/link directory |
| **Discovery** | Registry/manifest | File system scan |
| **Distribution** | Marketplace (planned) | Manual (GitHub, zip) |
| **Complexity** | High | Low |

**Mr. Wiggum has migrated to the simpler current system.**

## Complete Example: Wiggum Skill

```markdown
---
name: wiggum
description: "Convert PRDs to prd.json format for Mr. Wiggum"
user-invocable: true
---

# Mr. Wiggum PRD Converter

Converts PRDs to prd.json format.

## Usage

"Use wiggum skill to convert PRD.md"

## Output Format

Creates `prd.json`:
```json
{
  "projectName": "...",
  "branchName": "ralph/feature",
  "userStories": [...]
}
```

[Full skill documentation...]
```

## Resources

- **[Claude Code Skills Docs](https://code.claude.com/docs/en/skills)** - Official documentation
- **[Wiggum Skill](../skills/wiggum/SKILL.md)** - Full skill documentation
- **[GitHub Repo](https://github.com/shepherdscientific/mr-wiggum)** - Source code

## Contributing

To improve the skill:

1. Fork the repo
2. Edit `skills/wiggum/SKILL.md`
3. Test locally
4. Submit PR

No complex build process, no manifests, just edit the markdown file.

## Support

- **Issues:** https://github.com/shepherdscientific/mr-wiggum/issues
- **Discussions:** https://github.com/shepherdscientific/mr-wiggum/discussions
