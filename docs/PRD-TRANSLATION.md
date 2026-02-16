# PRD Translation Guide

## From PRD.md to prd.json

Mr. Wiggum uses **structured JSON** (`prd.json`) instead of markdown for reliable parsing. Here's how to convert.

## PRD.md Format (Human-Friendly)

```markdown
# Project: User Authentication System

Branch: `ralph/user-auth`

## User Stories

### US-001: Login Endpoint
**Priority:** High

Create POST /api/auth/login endpoint

**Acceptance Criteria:**
- [ ] Accepts email and password
- [ ] Returns JWT token on success
- [ ] Returns 401 on invalid credentials
- [ ] Tests pass

**Status:** 🔴 Not Started

### US-002: Password Reset
**Priority:** Medium

Implement password reset flow

**Acceptance Criteria:**
- [ ] POST /api/auth/reset-request sends email
- [ ] POST /api/auth/reset-confirm updates password
- [ ] Tokens expire after 1 hour

**Status:** 🔴 Not Started
```

## prd.json Format (Machine-Readable)

```json
{
  "projectName": "User Authentication System",
  "branchName": "ralph/user-auth",
  "userStories": [
    {
      "id": "US-001",
      "title": "Login Endpoint",
      "acceptanceCriteria": [
        "Accepts email and password",
        "Returns JWT token on success",
        "Returns 401 on invalid credentials",
        "Tests pass"
      ],
      "passes": false
    },
    {
      "id": "US-002",
      "title": "Password Reset",
      "acceptanceCriteria": [
        "POST /api/auth/reset-request sends email",
        "POST /api/auth/reset-confirm updates password",
        "Tokens expire after 1 hour"
      ],
      "passes": false
    }
  ]
}
```

## Translation Rules

### 1. Project Info
```markdown
# Project: User Authentication System
Branch: `ralph/user-auth`
```
↓
```json
{
  "projectName": "User Authentication System",
  "branchName": "ralph/user-auth"
}
```

### 2. User Stories
```markdown
### US-001: Login Endpoint
```
↓
```json
{
  "id": "US-001",
  "title": "Login Endpoint"
}
```

### 3. Acceptance Criteria
```markdown
- [ ] Accepts email and password
- [ ] Returns JWT token
```
↓
```json
"acceptanceCriteria": [
  "Accepts email and password",
  "Returns JWT token"
]
```

### 4. Status
```markdown
**Status:** 🔴 Not Started
**Status:** ✅ Complete
```
↓
```json
"passes": false  // Not started/in progress
"passes": true   // Complete
```

## Manual Translation (Quick Method)

### Step 1: Create Structure
```bash
cat > prd.json << 'EOF'
{
  "projectName": "Your Project Name",
  "branchName": "ralph/your-branch",
  "userStories": []
}
EOF
```

### Step 2: Add Stories
For each story in your PRD.md, add:

```json
{
  "id": "STORY-001",
  "title": "Story title from markdown",
  "acceptanceCriteria": [
    "Criterion 1",
    "Criterion 2",
    "Tests pass"
  ],
  "passes": false
}
```

### Step 3: Validate JSON
```bash
# Check syntax
jq . prd.json

# If valid, you'll see formatted output
# If invalid, you'll see error message
```

## Automated Translation (Claude Plugin)

### Using the Wiggum Skill

1. **In Claude.ai or Claude Desktop:**
```
Load the wiggum skill and convert my PRD.md to prd.json
```

2. **Claude will:**
   - Read your PRD.md
   - Extract project name, branch, stories
   - Generate valid prd.json
   - Validate JSON structure

3. **Review and save:**
   - Claude shows the generated JSON
   - Copy to `prd.json` in your project

### Skill Location

Copy the wiggum skill to your Claude config:

**Claude Desktop:**
```bash
cp -r skills/wiggum ~/.config/claude-desktop/skills/
```

**Amp:**
```bash
cp -r skills/wiggum ~/.config/amp/skills/
```

## Common Mistakes

### ❌ Wrong: Extra commas
```json
{
  "userStories": [
    {"id": "US-001", "passes": false},  // ← comma
  ]  // ← no comma after last item
}
```

### ✅ Right: Clean JSON
```json
{
  "userStories": [
    {"id": "US-001", "passes": false}
  ]
}
```

### ❌ Wrong: Missing quotes
```json
{
  id: "US-001",  // ← needs quotes
  passes: false  // ← needs quotes
}
```

### ✅ Right: All keys quoted
```json
{
  "id": "US-001",
  "passes": false
}
```

## Tips

**Keep criteria actionable:**
- ❌ "Make it work"
- ✅ "POST /api/login returns 200 status"

**Include test requirements:**
Always add "Tests pass" or "Type check passes" to criteria

**One task per story:**
Break large features into smaller stories (easier for agents)

**Use semantic IDs:**
- `AUTH-001` for authentication stories
- `API-001` for API stories
- `DB-001` for database stories

## Example: Full Conversion

### Input: PRD.md
```markdown
# E-commerce API

Branch: `ralph/checkout-flow`

### CART-001: Add to Cart
- [ ] POST /api/cart/items adds product
- [ ] Validates product exists
- [ ] Returns updated cart
- [ ] Tests pass
Status: 🔴

### CART-002: Remove from Cart  
- [ ] DELETE /api/cart/items/:id removes product
- [ ] Returns 404 if not in cart
- [ ] Tests pass
Status: 🔴
```

### Output: prd.json
```json
{
  "projectName": "E-commerce API",
  "branchName": "ralph/checkout-flow",
  "userStories": [
    {
      "id": "CART-001",
      "title": "Add to Cart",
      "acceptanceCriteria": [
        "POST /api/cart/items adds product",
        "Validates product exists",
        "Returns updated cart",
        "Tests pass"
      ],
      "passes": false
    },
    {
      "id": "CART-002",
      "title": "Remove from Cart",
      "acceptanceCriteria": [
        "DELETE /api/cart/items/:id removes product",
        "Returns 404 if not in cart",
        "Tests pass"
      ],
      "passes": false
    }
  ]
}
```

## Validation Checklist

- [ ] Valid JSON (use `jq . prd.json`)
- [ ] All stories have unique IDs
- [ ] All stories have title and acceptanceCriteria
- [ ] All passes set to false initially
- [ ] Acceptance criteria are actionable
- [ ] Tests/quality checks included in criteria

## Next Steps

After creating `prd.json`:
1. Review with `cat prd.json | jq .`
2. Customize `AGENTS.md` for your stack
3. Run `./wiggum.sh`
