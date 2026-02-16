---
name: wiggum
description: "Convert PRDs to prd.json format for the Mr. Wiggum fresh context autonomous agent system. Use when you have an existing PRD and need to convert it to Wiggum's JSON format. Triggers on: convert this prd, turn this into wiggum format, create prd.json from this."
user-invocable: true
---

# Mr. Wiggum PRD Converter

Converts existing PRDs to the prd.json format that Mr. Wiggum uses for fresh context autonomous execution.

**Key difference from Ralph:** Mr. Wiggum uses fresh context every iteration (~30K tokens) with no memory. Ralph accumulates context.

---

## The Job

Take a PRD (markdown file or text) and convert it to `prd.json`.

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

**Minimal JSON:** No `description`, `priority`, or `notes` fields. Fresh context means less to read = better performance.

---

## Story Size: The Critical Rule

**Each story must be completable in ONE iteration with fresh context (~30K tokens).**

Mr. Wiggum spawns a fresh LLM instance per iteration with ZERO memory. Context budget:
- prd.json (~5K tokens)
- AGENTS.md (~10K tokens) 
- git log (~5K tokens)
- Work space (~10K tokens)

### Right-sized stories:
- Add a database column and migration
- Add one UI component
- Update one API endpoint
- Add one test suite

### Too big (split these):
- "Build the dashboard" → schema, API, components
- "Add authentication" → schema, middleware, login UI, session
- "Refactor API" → one story per endpoint

**Rule of thumb:** If you cannot implement it in 30K tokens, it is too big.

---

## Story Ordering: Dependencies First

Stories execute by agent priority. Ensure dependencies come first:

**Correct order:**
1. Schema/database changes (migrations)
2. Backend logic / API endpoints
3. UI components using the backend
4. Integration/dashboard views

**Wrong order:**
1. UI component (depends on non-existent schema)
2. Schema change

---

## Acceptance Criteria: Must Be Verifiable

Each criterion must be checkable with code or tests.

### Good criteria:
- "POST /api/login returns JWT token"
- "Filter dropdown has options: All, Active, Completed"
- "Tests pass"
- "Type check passes"

### Bad criteria:
- "Works correctly"
- "Good UX"
- "Handles edge cases"

### Always include:
```
"Tests pass"
"Type check passes"
```

**For UI stories:**
```
"Manually verify in browser"
```

---

## Conversion Rules

1. Each user story becomes one JSON entry
2. IDs: Use semantic prefixes (AUTH-001, API-001, DB-001, UI-001)
3. All stories: `passes: false` initially
4. branchName: Feature name in kebab-case with `ralph/` prefix
5. Keep minimal: Only id, title, acceptanceCriteria, passes

---

## Splitting Large PRDs

Split big features into fresh-context-sized chunks:

**Original:** "Add user notification system"

**Split into:**
1. DB-001: Add notifications table and migration
2. API-001: POST /api/notifications endpoint
3. API-002: GET /api/notifications endpoint
4. UI-001: Notification bell icon in header
5. UI-002: Notification dropdown component
6. UI-003: Mark-as-read functionality

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
        "Add status column: 'pending' | 'in_progress' | 'done'",
        "Default value: 'pending'",
        "Migration runs successfully",
        "Type check passes"
      ],
      "passes": false
    },
    {
      "id": "UI-001",
      "title": "Display status badge on task cards",
      "acceptanceCriteria": [
        "Badge shows: gray=pending, blue=in_progress, green=done",
        "Type check passes",
        "Manually verify in browser"
      ],
      "passes": false
    },
    {
      "id": "UI-002",
      "title": "Add status toggle to task rows",
      "acceptanceCriteria": [
        "Dropdown with status options",
        "Saves immediately on change",
        "UI updates without refresh",
        "Type check passes",
        "Manually verify in browser"
      ],
      "passes": false
    },
    {
      "id": "UI-003",
      "title": "Add status filter dropdown",
      "acceptanceCriteria": [
        "Options: All | Pending | In Progress | Done",
        "Filter persists in URL params",
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

**Story Titles:** Specific enough to understand without long descriptions.
- ❌ "Update UI"
- ✅ "Add status filter dropdown to task list"

**Acceptance Criteria:** Bare minimum to verify completion.
- ❌ "Feature works well"
- ✅ "Filter dropdown filters tasks by status"

**AGENTS.md:** Patterns emerge naturally. Agent adds them to AGENTS.md automatically. Don't duplicate in prd.json.

---

## Checklist Before Saving

- [ ] Each story completable in ~30K tokens
- [ ] Stories ordered by dependency (schema → backend → UI)
- [ ] Every story has "Tests pass" / "Type check passes"
- [ ] UI stories have "Manually verify in browser"
- [ ] Acceptance criteria are verifiable
- [ ] JSON is minimal (no unnecessary fields)
- [ ] Story titles are specific and clear
- [ ] IDs use semantic prefixes

---

## Why Fresh Context Matters

**Standard Ralph:** Context accumulates → 120K tokens → API errors

**Mr. Wiggum:** Fresh context → 30K tokens/iteration → consistent performance

Result: Agent never hits context ceiling. Stories stay small. JSON stays minimal. Git commits are the progress log.
