---
name: wiggum
description: Convert PRDs to prd.json format for the Mr. Wiggum fresh context autonomous agent system. Use when you have an existing PRD markdown file and need to convert it to Wiggum's JSON format for autonomous execution. Triggers on: convert PRD, wiggum json, turn into wiggum format, create prd.json.
---

# Mr. Wiggum PRD Converter

Converts existing PRDs to the prd.json format that Mr. Wiggum uses for fresh context autonomous execution.

**Key difference from Ralph:** Mr. Wiggum uses fresh context every iteration (~20-40K tokens) vs accumulated context (120K+).

---

## The Job

Take a PRD (markdown file or text) and convert it to `prd.json` with fresh context architecture in mind.

---

## Output Format

```json
{
  "projectName": "[Project Name]",
  "branchName": "ralph/[feature-name-kebab-case]",
  "userStories": [
    {
      "id": "STORY-001",
      "title": "[Story title]",
      "acceptanceCriteria": [
        "Criterion 1",
        "Criterion 2",
        "Tests pass",
        "Type check passes"
      ],
      "passes": false
    }
  ]
}
```

**Simplified vs Ralph:** No `description`, `priority`, or `notes` fields - keeping JSON minimal reduces context.

---

## Story Size: The Critical Rule

**Each story must be completable in ONE iteration with fresh context.**

Mr. Wiggum spawns a fresh LLM instance per iteration with ZERO memory. Each iteration starts at 0 tokens, reads only:
- prd.json (~5K tokens)
- AGENTS.md (~10K tokens) 
- git log (~5K tokens)

**Total budget: ~30K tokens** for reading state + working on task.

### Right-sized stories:
- Add a database column and migration
- Add one UI component
- Update one API endpoint
- Add one test suite

### Too big (split these):
- "Build the dashboard" → Split into: schema, API, components
- "Add authentication" → Split into: schema, middleware, login UI, session
- "Refactor API" → Split into one story per endpoint

**Rule of thumb:** If you cannot implement it in 30K tokens of context, it is too big.

---

## Story Ordering: Dependencies First

Stories execute by PRIORITY (agent picks most important incomplete), not in order.

**Correct dependency order:**
1. Schema/database changes (migrations)
2. Backend logic / API endpoints
3. UI components using the backend
4. Integration/dashboard views

**Wrong order:**
1. UI component (depends on schema that doesn't exist yet)
2. Schema change

Agent will pick highest value task, so ensure dependencies are satisfied first.

---

## Acceptance Criteria: Must Be Verifiable

Each criterion must be something the agent can CHECK with code or tests.

### Good criteria (verifiable):
- "POST /api/login returns JWT token"
- "Filter dropdown has options: All, Active, Completed"
- "Password field type='password'"
- "Tests pass"
- "Type check passes"

### Bad criteria (vague):
- "Works correctly"
- "Good UX"
- "Handles edge cases"

### Always include:
```
"Tests pass"
"Type check passes"
```

**For UI stories, also include:**
```
"Manually verify in browser"
```

---

## Fresh Context Architecture: Keep JSON Minimal

Mr. Wiggum reads prd.json EVERY iteration. Keep it small:

### ❌ Don't include:
- Long descriptions (agent can infer from title + criteria)
- Priority numbers (agent decides based on importance)
- Notes (use AGENTS.md for patterns, git for history)
- Progress logs (use git commits)

### ✅ Do include:
- Clear story ID and title
- Specific acceptance criteria
- `passes` status (false/true)

**Example of minimal story:**
```json
{
  "id": "AUTH-001",
  "title": "JWT authentication endpoint",
  "acceptanceCriteria": [
    "POST /api/auth/login accepts email/password",
    "Returns JWT on valid credentials",
    "Returns 401 on invalid credentials",
    "Tests pass"
  ],
  "passes": false
}
```

---

## Conversion Rules

1. **Each user story becomes one JSON entry**
2. **IDs**: Use semantic prefixes (AUTH-001, API-001, DB-001)
3. **All stories**: `passes: false` initially
4. **branchName**: Derive from feature name, kebab-case, prefixed with `ralph/`
5. **Keep minimal**: No description, priority, or notes fields

---

## Splitting Large PRDs

If a PRD has big features, split them into fresh-context-sized chunks:

**Original:**
> "Add user notification system"

**Split into:**
1. DB-001: Add notifications table and migration
2. API-001: Create POST /api/notifications endpoint
3. API-002: Create GET /api/notifications endpoint
4. UI-001: Add notification bell icon to header
5. UI-002: Create notification dropdown component
6. UI-003: Add mark-as-read functionality

Each can be completed in ~30K tokens of context.

---

## Example Conversion

**Input PRD:**
```markdown
# Task Status Feature

Add ability to mark tasks with different statuses.

## Requirements
- Toggle between pending/in-progress/done
- Filter list by status
- Show status badge on each task
- Persist status in database
```

**Output prd.json:**
```json
{
  "projectName": "TaskApp - Status Feature",
  "branchName": "ralph/task-status",
  "userStories": [
    {
      "id": "DB-001",
      "title": "Add status field to tasks table",
      "acceptanceCriteria": [
        "Add status column: 'pending' | 'in_progress' | 'done' (default 'pending')",
        "Generate and run migration successfully",
        "Type check passes"
      ],
      "passes": false
    },
    {
      "id": "UI-001",
      "title": "Display status badge on task cards",
      "acceptanceCriteria": [
        "Each task card shows colored badge (gray/blue/green)",
        "Badge reflects current status",
        "Type check passes",
        "Manually verify in browser"
      ],
      "passes": false
    },
    {
      "id": "UI-002",
      "title": "Add status toggle to task rows",
      "acceptanceCriteria": [
        "Each row has status dropdown",
        "Changing status saves immediately",
        "UI updates without page refresh",
        "Type check passes",
        "Manually verify in browser"
      ],
      "passes": false
    },
    {
      "id": "UI-003",
      "title": "Add status filter dropdown",
      "acceptanceCriteria": [
        "Filter dropdown: All | Pending | In Progress | Done",
        "Filter persists in URL params",
        "Empty state when no matches",
        "Type check passes",
        "Manually verify in browser"
      ],
      "passes": false
    }
  ]
}
```

---

## Fresh Context Best Practices

### Story Titles
Make them specific enough that agent knows what to do without reading long descriptions:

- ❌ "Update UI"
- ✅ "Add status filter dropdown to task list"

### Acceptance Criteria
List the bare minimum to verify completion:

- ❌ "Feature works well and looks good"
- ✅ "Filter dropdown filters tasks by status"

### AGENTS.md Integration
If a pattern emerges (like "always use parameterized queries"), the agent will add it to AGENTS.md. Don't include this in prd.json.

---

## Checklist Before Saving

Before writing prd.json, verify:

- [ ] Each story is completable in ~30K tokens of context
- [ ] Stories ordered by dependency (schema → backend → UI)
- [ ] Every story has "Tests pass" / "Type check passes"
- [ ] UI stories have "Manually verify in browser"
- [ ] Acceptance criteria are verifiable (not vague)
- [ ] JSON is minimal (no unnecessary fields)
- [ ] Story titles are specific and clear
- [ ] IDs use semantic prefixes (AUTH-, API-, DB-, UI-)

---

## Why Fresh Context Matters

**Standard Ralph:** Context accumulates → 120K tokens at iteration 4 → API errors

**Mr. Wiggum:** Fresh context → 30K tokens per iteration → consistent performance

This means:
- Smaller user stories (fits in 30K budget)
- Minimal JSON (less to read each time)
- Pattern library in AGENTS.md (curated, <500 lines)
- No progress.txt journal (git commits are the log)

**Result:** Agent never hits "dumb zone" (60-70% context capacity where performance degrades).
