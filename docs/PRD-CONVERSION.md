# Converting PRD.md to prd.json

Mr. Wiggum requires structured `prd.json` for reliable parsing. Here's how to convert from markdown to JSON.

## Option 1: Manual Conversion

### From PRD.md
```markdown
# User Authentication Feature

## User Stories

### US-001: Login Endpoint
As a user, I want to log in with email/password

**Acceptance Criteria:**
- POST /api/auth/login endpoint exists
- Accepts email and password
- Returns JWT on success
- Returns 401 on invalid credentials

### US-002: User Profile
As a user, I want to view my profile

**Acceptance Criteria:**
- GET /api/users/me endpoint exists
- Requires valid JWT
- Returns user data excluding password
```

### To prd.json
```json
{
  "projectName": "User Authentication Feature",
  "branchName": "wiggum/auth-feature",
  "userStories": [
    {
      "id": "US-001",
      "title": "Login Endpoint",
      "acceptanceCriteria": [
        "POST /api/auth/login endpoint exists",
        "Accepts email and password",
        "Returns JWT on success",
        "Returns 401 on invalid credentials"
      ],
      "passes": false
    },
    {
      "id": "US-002",
      "title": "User Profile",
      "acceptanceCriteria": [
        "GET /api/users/me endpoint exists",
        "Requires valid JWT",
        "Returns user data excluding password"
      ],
      "passes": false
    }
  ]
}
```

## Option 2: Use Claude

```bash
# Put your PRD.md in the project
# Then ask Claude:
claude "Convert PRD.md to prd.json format following the Mr. Wiggum structure"
```

Claude will read your PRD.md and generate proper prd.json.

## Option 3: Wiggum Skill (Recommended)

The wiggum skill helps generate PRDs from descriptions.

### Install the Skill

```bash
# For Claude Code
mkdir -p ~/.config/claude/skills
cp -r skills/wiggum ~/.config/claude/skills/

# For Amp
mkdir -p ~/.config/amp/skills
cp -r skills/wiggum ~/.config/amp/skills/
```

### Use the Skill

```
Load the wiggum skill and create a PRD for [your feature description]

Example:
"Load the wiggum skill and create a PRD for a REST API with user authentication, 
role-based access control, and audit logging"
```

The skill will:
1. Ask clarifying questions about your requirements
2. Generate a detailed prd.json with proper user stories
3. Create acceptance criteria for each story
4. Structure it for autonomous execution

## prd.json Structure

```json
{
  "projectName": "Human-readable project name",
  "branchName": "wiggum/feature-name",
  "userStories": [
    {
      "id": "STORY-001",
      "title": "Short descriptive title",
      "acceptanceCriteria": [
        "Testable criterion 1",
        "Testable criterion 2",
        "Tests pass",
        "Type checks pass"
      ],
      "passes": false
    }
  ]
}
```

## Best Practices

### Good User Story
```json
{
  "id": "API-003",
  "title": "Implement pagination for user list",
  "acceptanceCriteria": [
    "GET /api/users accepts page and limit params",
    "Returns max 100 users per page",
    "Includes total count in response",
    "Returns proper 400 for invalid params",
    "Tests cover edge cases (empty, overflow)",
    "Tests pass"
  ],
  "passes": false
}
```

### Bad User Story
```json
{
  "id": "FEATURE-001",
  "title": "Build entire user management system",
  "acceptanceCriteria": [
    "Everything works"
  ],
  "passes": false
}
```

## Acceptance Criteria Guidelines

Make them **testable and specific:**

✅ Good:
- "POST /api/users returns 201 with user ID"
- "Password must be hashed with bcrypt"
- "JWT expires after 24 hours"
- "Tests achieve >80% coverage"

❌ Bad:
- "User management works"
- "Security is good"
- "Fast performance"

## Story Sizing

Each story should complete in one iteration (~30-60 min of agent work):

**Too big:**
```json
{
  "title": "Complete authentication system with OAuth, 2FA, and SSO"
}
```

**Right size:**
```json
[
  {"title": "Implement basic email/password login"},
  {"title": "Add JWT token generation and validation"},
  {"title": "Add password reset flow"},
  {"title": "Implement OAuth provider integration"},
  {"title": "Add 2FA using TOTP"}
]
```

## Common Patterns

### API Endpoint Story
```json
{
  "id": "API-001",
  "title": "Create user endpoint",
  "acceptanceCriteria": [
    "POST /api/users accepts name, email, password",
    "Validates email format",
    "Returns 400 for invalid data",
    "Returns 201 with user object on success",
    "Password is hashed before storage",
    "Tests pass"
  ],
  "passes": false
}
```

### Bug Fix Story
```json
{
  "id": "BUG-042",
  "title": "Fix race condition in payment processing",
  "acceptanceCriteria": [
    "Add transaction locking",
    "Concurrent requests handled correctly",
    "Regression test added",
    "All existing tests still pass"
  ],
  "passes": false
}
```

### Refactor Story
```json
{
  "id": "REFACTOR-005",
  "title": "Extract auth logic to middleware",
  "acceptanceCriteria": [
    "Auth logic moved to middleware/auth.js",
    "All routes use new middleware",
    "Tests updated and passing",
    "No behavior changes",
    "Coverage maintained or improved"
  ],
  "passes": false
}
```

## Updating Stories

As work progresses, the agent updates `passes` to `true`:

```json
{
  "id": "STORY-001",
  "title": "Login endpoint",
  "acceptanceCriteria": ["..."],
  "passes": true  // ← Agent sets this when complete
}
```

You can also add notes for complex stories:

```json
{
  "id": "STORY-042",
  "title": "Complex feature",
  "acceptanceCriteria": ["..."],
  "passes": false,
  "notes": "Blocked by US-041. Requires database migration first."
}
```

## Tips

1. **Start small**: Begin with 3-5 stories to test the flow
2. **Be specific**: Vague criteria = unreliable completion
3. **Include tests**: "Tests pass" should be in every story
4. **One thing per story**: Don't combine unrelated work
5. **Order matters**: Put foundational work first

## Need Help?

The wiggum skill can help you structure your PRD. Just load it and describe what you want to build!
