# Publishing to Claude Plugin Marketplace

This guide explains how to submit the Mr. Wiggum skill to the Claude Plugin Marketplace.

## Prerequisites

- GitHub account
- Claude Desktop or claude.ai account
- Repository with `.claude-plugin/` structure

## Plugin Structure

Mr. Wiggum already has the required structure:

```
mr-wiggum/
├── .claude-plugin/
│   ├── plugin.json          # Plugin metadata
│   └── marketplace.json     # Marketplace listing
├── skills/
│   └── wiggum/
│       └── SKILL.md         # Skill documentation with frontmatter
└── README.md
```

## Plugin Files Explained

### `.claude-plugin/plugin.json`

Defines the plugin metadata:

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

Marketplace listing information:

```json
{
  "name": "wiggum-marketplace",
  "owner": {
    "name": "shepherdscientific"
  },
  "metadata": {
    "description": "Fresh context Ralph Wiggum skills",
    "version": "1.0.0"
  },
  "plugins": [
    {
      "name": "wiggum-skills",
      "source": "./",
      "category": "productivity",
      "skills": "./skills/"
    }
  ]
}
```

### `skills/wiggum/SKILL.md`

Must have frontmatter:

```markdown
---
name: wiggum
description: "Convert PRDs to prd.json format..."
user-invocable: true
---

# Mr. Wiggum PRD Converter

[Content...]
```

## Installation Methods

### Method 1: Manual Installation (Available Now)

Users can install directly from GitHub:

```bash
# Clone to skills directory
mkdir -p ~/.config/claude-desktop/skills
cd ~/.config/claude-desktop/skills
git clone https://github.com/shepherdscientific/mr-wiggum.git

# Create symlink
ln -s mr-wiggum/skills/wiggum wiggum

# Restart Claude Desktop
```

### Method 2: Claude Plugin Marketplace (Future)

Once Anthropic launches the official plugin marketplace:

1. **Submit to Marketplace Registry:**
   ```bash
   # If CLI is available
   claude plugin publish
   ```

2. **Or via Web Form:**
   - Visit Claude Plugin Marketplace
   - Click "Submit Plugin"
   - Provide GitHub repo URL
   - Fill in metadata

3. **Users Install via Marketplace:**
   - Browse Claude Desktop Plugin Marketplace
   - Search "wiggum"
   - Click "Install"

### Method 3: NPM Package (Alternative)

If you want to distribute via NPM:

```bash
# Package the skill
npm init
# Edit package.json

# Publish
npm publish

# Users install
npx install-claude-skill wiggum-skills
```

## Testing Before Publication

### Local Testing

1. **Install locally:**
   ```bash
   ln -s $(pwd)/skills/wiggum ~/.config/claude-desktop/skills/wiggum
   ```

2. **Restart Claude Desktop**

3. **Test the skill:**
   ```
   Load the wiggum skill and convert my PRD.md
   ```

4. **Verify:**
   - Skill loads without errors
   - Conversion works correctly
   - Generated JSON is valid

### Validation Checklist

- [ ] `plugin.json` has valid JSON syntax
- [ ] `marketplace.json` has valid JSON syntax
- [ ] `SKILL.md` has proper frontmatter
- [ ] Skills directory structure is correct
- [ ] All file paths in JSON are correct
- [ ] README has installation instructions
- [ ] LICENSE file exists
- [ ] Skill works in Claude Desktop

## Marketplace Categories

Available categories:
- `productivity` ✅ (Mr. Wiggum fits here)
- `development`
- `creativity`
- `research`
- `communication`
- `utilities`

## Keywords for Discoverability

Mr. Wiggum uses:
- `wiggum`
- `ralph`
- `prd`
- `automation`
- `agent`
- `fresh-context`
- `autonomous`

Add more as needed for better search results.

## Version Management

### Semantic Versioning

Follow semver (MAJOR.MINOR.PATCH):

- **MAJOR:** Breaking changes to skill API
- **MINOR:** New features (backward compatible)
- **PATCH:** Bug fixes

### Update Process

1. **Update version in both files:**
   - `.claude-plugin/plugin.json`
   - `.claude-plugin/marketplace.json`

2. **Tag release:**
   ```bash
   git tag v1.0.1
   git push origin v1.0.1
   ```

3. **Update marketplace listing:**
   - Republish via CLI or web form

## Marketplace Guidelines

### Do's
- ✅ Clear, concise descriptions
- ✅ Specific keywords
- ✅ Valid JSON syntax
- ✅ Proper frontmatter in SKILL.md
- ✅ MIT or permissive license
- ✅ Good documentation
- ✅ Working examples

### Don'ts
- ❌ Overly broad descriptions
- ❌ Misleading keywords
- ❌ Broken file paths
- ❌ Missing documentation
- ❌ Proprietary licenses (for marketplace)
- ❌ Untested code

## Support & Maintenance

### User Support

Add to README:
- Installation instructions
- Usage examples
- Troubleshooting
- Issue reporting link

### Maintenance

- Monitor GitHub issues
- Respond to user questions
- Fix bugs promptly
- Update for Claude API changes

## Promotion

### GitHub
- Good README with badges
- Clear examples
- Active issues/discussions

### Social Media
- Share on Twitter with #ClaudeAI
- Post in Claude Discord
- Reddit: r/ClaudeAI

### Documentation
- Blog post explaining fresh context architecture
- Video demo of PRD conversion
- Comparison with standard Ralph

## Example: Submit Process

### Step 1: Finalize Plugin

```bash
# Verify structure
ls -la .claude-plugin/
ls -la skills/wiggum/

# Validate JSON
jq . .claude-plugin/plugin.json
jq . .claude-plugin/marketplace.json
```

### Step 2: Tag Release

```bash
git tag v1.0.0
git push origin v1.0.0
```

### Step 3: Submit (When Available)

```bash
# Via CLI (future)
claude plugin publish

# Or via web form
# Navigate to marketplace
# Submit GitHub URL
```

### Step 4: Announce

```bash
# Social media
# Update README with marketplace badge
# Create release notes
```

## Current Status

**Mr. Wiggum is ready for:**
- ✅ Manual installation
- ✅ Direct GitHub cloning
- ✅ Local testing
- ⏳ Marketplace submission (when available)

**To submit to marketplace:**
1. Wait for official Claude Plugin Marketplace launch
2. Follow Anthropic's submission process
3. Update this guide with official instructions

## Resources

- [Claude Plugin Documentation](https://docs.anthropic.com/plugins) (check for updates)
- [Ralph Plugin Example](https://github.com/snarktank/ralph/.claude-plugin)
- [Mr. Wiggum Repository](https://github.com/shepherdscientific/mr-wiggum)

## Questions?

- Open an issue: https://github.com/shepherdscientific/mr-wiggum/issues
- Check Ralph's plugin structure: https://github.com/snarktank/ralph
