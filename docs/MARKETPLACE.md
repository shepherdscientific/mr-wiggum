# Publishing to Claude Code Plugin Marketplace

This guide explains how to submit the Mr. Wiggum skill to the Claude Code Plugin Marketplace.

## Prerequisites

- GitHub account
- Claude Code CLI installed
- Repository with `.claude-plugin/` structure

## Plugin Structure

Mr. Wiggum has the required structure for Claude Code:

```
mr-wiggum/
├── .claude-plugin/
│   ├── plugin.json          # Plugin metadata for Claude Code
│   └── marketplace.json     # Marketplace listing
├── skills/
│   └── wiggum/
│       └── SKILL.md         # Skill documentation with frontmatter
└── README.md
```

## Installation for Claude Code

### Method 1: Install from GitHub (Available Now)

```bash
# Install the skill into Claude Code
claude skill add https://github.com/shepherdscientific/mr-wiggum

# Or install from local directory
cd /path/to/mr-wiggum
claude skill add .

# List installed skills
claude skill list

# Use in any project
cd your-project
claude "Load wiggum skill and convert my PRD.md"
```

### Method 2: Install via Config

Edit `~/.config/claude-code/config.json`:

```json
{
  "skills": [
    {
      "name": "wiggum",
      "source": "https://github.com/shepherdscientific/mr-wiggum"
    }
  ]
}
```

### Method 3: Claude Code Marketplace (Future)

Once marketplace launches:

```bash
# Search for skill
claude skill search wiggum

# Install from marketplace
claude skill install wiggum

# Or browse marketplace
claude skill browse
```

## Using the Skill in Claude Code

### In Command Line

```bash
# Convert PRD in current directory
claude "Load wiggum skill and convert PRD.md to prd.json"

# With file path
claude "Load wiggum skill and convert specs/feature.md to prd.json"

# Interactive mode
claude
> Load wiggum skill
> Convert my PRD to JSON
```

### In Project with Wiggum Loop

```bash
# Your workflow
cd ~/agora-dao
vi specs/new-feature.md  # Write PRD

# Use skill to convert
claude "Load wiggum skill and convert specs/new-feature.md to prd.json"

# Run wiggum loop
./wiggum.sh --tool claude 50
```

## Plugin Files Explained

### `.claude-plugin/plugin.json`

Defines the plugin for Claude Code CLI:

```json
{
  "name": "wiggum-skills",
  "version": "1.0.0",
  "description": "Fresh context Ralph Wiggum skills",
  "author": {
    "name": "shepherdscientific"
  },
  "skills": "./skills/",
  "keywords": ["wiggum", "ralph", "prd", "automation"]
}
```

### `.claude-plugin/marketplace.json`

Marketplace listing for discoverability:

```json
{
  "name": "wiggum-marketplace",
  "owner": {
    "name": "shepherdscientific"
  },
  "plugins": [
    {
      "name": "wiggum-skills",
      "category": "productivity",
      "skills": "./skills/"
    }
  ]
}
```

### `skills/wiggum/SKILL.md`

Skill with frontmatter that Claude Code reads:

```markdown
---
name: wiggum
description: "Convert PRDs to prd.json format..."
user-invocable: true
---

# Mr. Wiggum PRD Converter

[Skill documentation...]
```

## Testing Before Publication

### Local Testing with Claude Code

```bash
# 1. Install locally
cd /path/to/mr-wiggum
claude skill add .

# 2. Verify installation
claude skill list | grep wiggum

# 3. Test the skill
cd ~/test-project
echo "# Test PRD" > PRD.md
claude "Load wiggum skill and convert PRD.md"

# 4. Check output
cat prd.json | jq .
```

### Validation Checklist

- [ ] `plugin.json` has valid JSON syntax
- [ ] `marketplace.json` has valid JSON syntax  
- [ ] `SKILL.md` has proper frontmatter
- [ ] Skill loads in Claude Code without errors
- [ ] Conversion produces valid prd.json
- [ ] Works with `./wiggum.sh` loop

## Claude Code vs Claude Desktop

**This plugin is for Claude Code (CLI), not Claude Desktop.**

| Aspect | Claude Code (CLI) | Claude Desktop (GUI) |
|--------|-------------------|----------------------|
| **Installation** | `claude skill add` | Copy to skills folder |
| **Usage** | Command line | Desktop app |
| **Config** | `~/.config/claude-code/` | `~/.config/claude-desktop/` |
| **Our plugin** | ✅ This one | ❌ Different structure |

## Marketplace Submission

### Current Status

**Available now:**
- ✅ GitHub installation
- ✅ Manual skill add
- ✅ Local testing

**Future:**
- ⏳ Official Claude Code Marketplace
- ⏳ Browse/search/install via CLI
- ⏳ Automatic updates

### When Marketplace Launches

```bash
# Submit (future command)
cd /path/to/mr-wiggum
claude skill publish

# Or via web form
# Navigate to marketplace portal
# Submit GitHub repo URL
```

### Requirements for Marketplace

- [ ] Valid `.claude-plugin/` structure
- [ ] Working skill with frontmatter
- [ ] Clear documentation
- [ ] MIT or permissive license
- [ ] Example usage
- [ ] Tests passing

## Version Management

### Update Version

1. **Update both JSON files:**
   ```bash
   # .claude-plugin/plugin.json
   # .claude-plugin/marketplace.json
   "version": "1.0.1"
   ```

2. **Tag release:**
   ```bash
   git tag v1.0.1
   git push origin v1.0.1
   ```

3. **Users update:**
   ```bash
   claude skill update wiggum
   ```

## Integration with Wiggum Loop

### Complete Workflow

```bash
# 1. Write PRD (markdown)
vi specs/auth-feature.md

# 2. Convert with skill
claude "Load wiggum skill and convert specs/auth-feature.md to prd.json"

# 3. Review/edit prd.json
vi prd.json

# 4. Run autonomous loop
./wiggum.sh --tool claude 50

# 5. Monitor progress
git log --oneline -10
```

### Why This Matters

- **PRD.md → prd.json** conversion automated
- **Fresh context** optimization built-in
- **Story sizing** for 30K token budget
- **Seamless** with wiggum.sh loop

## Troubleshooting

### Skill Not Loading

```bash
# Check installation
claude skill list

# Reinstall
claude skill remove wiggum
claude skill add https://github.com/shepherdscientific/mr-wiggum

# Check config
cat ~/.config/claude-code/config.json | jq .skills
```

### Conversion Errors

```bash
# Test with simple PRD
cat > test.md << 'EOF'
# Test Feature
## US-001: Simple test
- [ ] Test criterion
EOF

claude "Load wiggum skill and convert test.md"

# Check for errors
echo $?
```

### JSON Validation

```bash
# After conversion
jq . prd.json

# If invalid, check syntax
jq --color-output . prd.json | less
```

## Resources

- **Claude Code CLI Docs:** https://docs.anthropic.com/claude-code
- **Skill System:** Check Claude Code documentation
- **Ralph Example:** https://github.com/snarktank/ralph/.claude-plugin
- **Our Repo:** https://github.com/shepherdscientific/mr-wiggum

## Contributing

To improve the skill:

1. Fork the repo
2. Make changes to `skills/wiggum/SKILL.md`
3. Test with Claude Code
4. Submit PR

## Support

- **Issues:** https://github.com/shepherdscientific/mr-wiggum/issues
- **Discussions:** https://github.com/shepherdscientific/mr-wiggum/discussions

## Next Steps

1. **Install:** `claude skill add https://github.com/shepherdscientific/mr-wiggum`
2. **Test:** Create a sample PRD.md and convert it
3. **Use:** Integrate with your wiggum.sh workflow
4. **Feedback:** Open issues for improvements
