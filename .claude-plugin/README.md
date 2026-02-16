# ⚠️ Deprecated Directory

This `.claude-plugin/` directory is **no longer used** by Claude Code.

## What Changed

Claude Code skills now use a simpler structure:
- ✅ **Current:** `skills/wiggum/SKILL.md` with YAML frontmatter
- ❌ **Old:** `.claude-plugin/plugin.json` and `marketplace.json`

## Migration

No action needed! The skill at `skills/wiggum/SKILL.md` is the current version.

To use the skill:
```bash
cd your-project
mkdir -p .claude/skills
ln -s /path/to/mr-wiggum/skills/wiggum .claude/skills/wiggum
```

## Why Keep This Directory?

For reference/archival purposes only. It may be removed in future versions.

## More Info

See [Claude Code Skills Documentation](https://code.claude.com/docs/en/skills)
