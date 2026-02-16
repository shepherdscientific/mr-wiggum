# Wiggum Skill - PRD Conversion

This skill helps you convert markdown PRDs to structured JSON for Mr. Wiggum.

## What This Skill Does

1. Reads your PRD.md (markdown format)
2. Extracts project name, branch, and user stories
3. Generates valid prd.json
4. Validates the JSON structure

## How to Use

### In Claude.ai or Claude Desktop

```
Load the wiggum skill and convert my PRD.md to prd.json
```

### What Happens

Claude will:
1. Ask for your PRD.md content (or read from file)
2. Parse project metadata
3. Extract all user stories
4. Generate structured JSON
5. Validate syntax
6. Show you the result

### Example Input

```markdown
# Project: User Authentication

Branch: `ralph/user-auth`

### AUTH-001: Login Endpoint
- [ ] POST /api/auth/login accepts email/password
- [ ] Returns JWT on success
- [ ] Tests pass
```

### Example Output

```json
{
  "projectName": "User Authentication",
  "branchName": "ralph/user-auth",
  "userStories": [
    {
      "id": "AUTH-001",
      "title": "Login Endpoint",
      "acceptanceCriteria": [
        "POST /api/auth/login accepts email/password",
        "Returns JWT on success",
        "Tests pass"
      ],
      "passes": false
    }
  ]
}
```

## Claude Prompt for Conversion

When a user says "convert my PRD to prd.json" or similar:

1. **Ask for the PRD:**
```
I'll help you convert your PRD.md to prd.json. Please either:
- Paste your PRD.md content here
- Or share the file path and I'll read it
```

2. **Parse the markdown:**
   - Extract project name from first `# Project:` heading
   - Extract branch from `Branch:` line
   - Find all user stories (markdown headings with IDs)
   - Extract acceptance criteria (checkbox lists)

3. **Generate JSON structure:**
```json
{
  "projectName": "...",
  "branchName": "...",
  "userStories": [
    {
      "id": "...",
      "title": "...",
      "acceptanceCriteria": [...],
      "passes": false
    }
  ]
}
```

4. **Validate:**
   - Check JSON syntax
   - Ensure all required fields present
   - Verify unique story IDs

5. **Present result:**
   - Show the generated JSON
   - Offer to save to file if using Claude Code
   - Provide next steps (run setup-wiggum.sh)

## Installation

### Claude Desktop

```bash
mkdir -p ~/.config/claude-desktop/skills/wiggum
cp SKILL.md ~/.config/claude-desktop/skills/wiggum/
```

### Amp

```bash
mkdir -p ~/.config/amp/skills/wiggum
cp SKILL.md ~/.config/amp/skills/wiggum/
```

## Parsing Rules

### Project Name
```markdown
# Project: User Authentication System
# User Authentication System
```
Both formats work. Extract text after `# Project:` or just `#`.

### Branch Name
```markdown
Branch: `ralph/user-auth`
Branch: ralph/user-auth
```
Extract from backticks or plain text.

### User Stories
```markdown
### AUTH-001: Login Endpoint
### US-001 - Login Endpoint
```
Extract ID before `:` or `-`, title after.

### Acceptance Criteria
```markdown
- [ ] Criterion one
- [ ] Criterion two
* [ ] Criterion three
```
Extract all checkbox items (checked or unchecked).

## Advanced Features

### Story Priority

If PRD includes priority:
```markdown
**Priority:** High
```

Add to JSON:
```json
{
  "id": "...",
  "priority": "High",
  ...
}
```

### Story Dependencies

If PRD includes dependencies:
```markdown
**Depends on:** US-001, US-002
```

Add to JSON:
```json
{
  "id": "...",
  "dependencies": ["US-001", "US-002"],
  ...
}
```

### Story Status

If PRD shows completion:
```markdown
**Status:** ✅ Complete
**Status:** 🔴 Not Started
```

Set `passes`:
```json
"passes": true   // if Complete
"passes": false  // if Not Started/In Progress
```

## Error Handling

### No Stories Found
```
⚠️  No user stories found in PRD.

Expected format:
### STORY-ID: Title
- [ ] Acceptance criterion 1
```

### Invalid JSON
```
❌ Generated invalid JSON. Fixing...

Common issues:
- Extra commas
- Missing quotes
- Unescaped characters
```

### Duplicate IDs
```
⚠️  Duplicate story IDs found: AUTH-001

Please ensure all story IDs are unique.
```

## Examples

### Full Conversion

**Input PRD.md:**
```markdown
# E-Commerce Platform

Branch: `ralph/checkout`

### CART-001: Add to Cart
**Priority:** High

- [ ] POST /api/cart adds item
- [ ] Validates product exists
- [ ] Returns updated cart
- [ ] Tests pass

### CART-002: Remove from Cart
**Priority:** Medium

- [ ] DELETE /api/cart/:id removes item
- [ ] Returns 404 if not in cart
- [ ] Tests pass
```

**Output prd.json:**
```json
{
  "projectName": "E-Commerce Platform",
  "branchName": "ralph/checkout",
  "userStories": [
    {
      "id": "CART-001",
      "title": "Add to Cart",
      "priority": "High",
      "acceptanceCriteria": [
        "POST /api/cart adds item",
        "Validates product exists",
        "Returns updated cart",
        "Tests pass"
      ],
      "passes": false
    },
    {
      "id": "CART-002",
      "title": "Remove from Cart",
      "priority": "Medium",
      "acceptanceCriteria": [
        "DELETE /api/cart/:id removes item",
        "Returns 404 if not in cart",
        "Tests pass"
      ],
      "passes": false
    }
  ]
}
```

## Next Steps After Conversion

1. Save the JSON to `prd.json` in your project
2. Run `./setup-wiggum.sh` to initialize AGENTS.md
3. Customize AGENTS.md with your stack details
4. Run `./wiggum.sh` to start the loop

## Tips

- Keep story IDs semantic (AUTH-001, API-001, DB-001)
- Include "Tests pass" in all acceptance criteria
- Break large features into small, completable stories
- Use actionable, verifiable criteria

## Troubleshooting

**"Claude can't find the wiggum skill"**
- Ensure SKILL.md is in correct directory
- Restart Claude Desktop/Amp
- Try: "List available skills" to verify

**"Conversion result has errors"**
- Check original PRD markdown syntax
- Ensure story IDs are unique
- Verify acceptance criteria use checkbox format

**"Want to re-convert after changes"**
- Edit your PRD.md
- Run conversion again
- Claude will regenerate fresh JSON
