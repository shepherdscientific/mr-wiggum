# Agent Pattern Library

**Purpose:** Curated, reusable knowledge for autonomous agents.

**Rules:**
- Keep under 500 lines (auto-compacted if exceeded)
- Only general patterns, not story-specific details
- Clear, actionable guidance

---

## Project Setup

**Tech Stack:**
- Node.js + Express
- PostgreSQL
- Jest for testing

**Commands:**
```bash
npm test           # Run tests
npm run typecheck  # Type checking
npm run dev        # Development server
```

**Test Requirements:**
- Tests must pass before committing
- Mock database calls in unit tests
- Use supertest for API tests

---

## Codebase Conventions

### File Organization
- `src/` - Application code
- `src/*/index.js` - Module exports
- `src/*/routes.js` - Express routes
- `tests/unit/` - Unit tests

### Code Patterns
- Use async/await for database queries
- Export functions from index.js
- Import routes in src/index.js
- Use Joi for validation

### Database
- Migrations in `migrations/`
- Always use parameterized queries
- Handle connection errors

---

## Common Gotchas

(Agents will populate this section as they discover issues)

---

## Implementation Notes

**When adding new modules:**
1. Create `src/module-name/index.js`
2. Create `src/module-name/routes.js`
3. Import routes in `src/index.js`
4. Add tests in `tests/unit/`

**When modifying APIs:**
1. Update validation schemas
2. Update tests
3. Run full test suite

---

*Last updated: Auto-managed by Ralph loop*
