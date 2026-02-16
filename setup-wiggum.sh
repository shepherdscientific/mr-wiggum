#!/bin/bash
# Mr. Wiggum Setup Wizard
# Interactive setup for fresh context autonomous coding

set -e

echo "🎩 Mr. Wiggum Setup Wizard"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if we're in a git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "❌ Not a git repository. Please run 'git init' first."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# === STEP 1: Tech Stack Questions ===
echo "📋 Step 1: Tell me about your tech stack"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

read -p "Primary language (e.g., JavaScript, Python, Go): " LANG
read -p "Framework (e.g., Express, FastAPI, React): " FRAMEWORK
read -p "Database (e.g., PostgreSQL, MongoDB, MySQL): " DATABASE
read -p "Test framework (e.g., Jest, pytest, go test): " TEST_FRAMEWORK

echo ""
read -p "Test command (e.g., npm test, pytest): " TEST_CMD
read -p "Type check command (or 'none' if no type checking): " TYPECHECK_CMD
read -p "Dev server command (e.g., npm run dev): " DEV_CMD

# === STEP 2: Project Structure ===
echo ""
echo "📁 Step 2: Project structure"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

read -p "Source directory (e.g., src, lib, app): " SRC_DIR
read -p "Test directory (e.g., tests, test, __tests__): " TEST_DIR

# === STEP 3: Create AGENTS.md ===
echo ""
echo "✍️  Creating AGENTS.md..."

cat > "$SCRIPT_DIR/AGENTS.md" << EOF
# Agent Pattern Library

**Purpose:** Curated, reusable knowledge for autonomous agents.

**Rules:**
- Keep under 500 lines (auto-compacted if exceeded)
- Only general patterns, not story-specific details
- Clear, actionable guidance

---

## Project Setup

**Tech Stack:**
- Language: $LANG
- Framework: $FRAMEWORK
- Database: $DATABASE
- Tests: $TEST_FRAMEWORK

**Commands:**
\`\`\`bash
$TEST_CMD           # Run tests
EOF

if [ "$TYPECHECK_CMD" != "none" ]; then
  echo "$TYPECHECK_CMD  # Type checking" >> "$SCRIPT_DIR/AGENTS.md"
fi

cat >> "$SCRIPT_DIR/AGENTS.md" << EOF
$DEV_CMD        # Development server
\`\`\`

**Test Requirements:**
- Tests must pass before committing
- All new features need test coverage
EOF

if [ "$TYPECHECK_CMD" != "none" ]; then
  echo "- Type checks must pass" >> "$SCRIPT_DIR/AGENTS.md"
fi

cat >> "$SCRIPT_DIR/AGENTS.md" << EOF

---

## Codebase Conventions

### File Organization
- \`$SRC_DIR/\` - Application code
- \`$TEST_DIR/\` - Test files

### Code Patterns
(Agents will populate this as they discover patterns)

### Database
EOF

if [[ "$DATABASE" == *"Postgres"* ]] || [[ "$DATABASE" == *"MySQL"* ]]; then
  cat >> "$SCRIPT_DIR/AGENTS.md" << 'EOF'
- Always use parameterized queries
- Never concatenate user input into SQL
EOF
fi

cat >> "$SCRIPT_DIR/AGENTS.md" << EOF

---

## Common Gotchas

(Agents will populate this section as they discover issues)

---

## Implementation Notes

**When adding new features:**
1. Write tests first (TDD recommended)
2. Implement feature
3. Run full test suite
4. Commit only when green

**When modifying existing code:**
1. Ensure tests still pass
2. Update tests if behavior changed
3. Document any pattern changes here

---

*Last updated: $(date)*
*Auto-managed by Mr. Wiggum*
EOF

echo "✅ AGENTS.md created"

# === STEP 4: PRD Handling ===
echo ""
echo "📝 Step 3: PRD Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ -f "$SCRIPT_DIR/prd.json" ]; then
  echo "✅ prd.json already exists"
else
  echo "No prd.json found."
  echo ""
  echo "You can either:"
  echo "  1. Create prd.json manually (see prd.json.example)"
  echo "  2. Convert existing PRD.md using: claude 'Convert PRD.md to prd.json format'"
  echo "  3. Use the wiggum skill to generate from description"
  echo ""
  read -p "Create example prd.json now? (y/n): " CREATE_PRD
  
  if [[ "$CREATE_PRD" == "y" ]]; then
    cat > "$SCRIPT_DIR/prd.json" << 'EOF'
{
  "projectName": "Your Project",
  "branchName": "wiggum/initial-feature",
  "userStories": [
    {
      "id": "STORY-001",
      "title": "Setup project structure",
      "acceptanceCriteria": [
        "Project builds successfully",
        "Tests run without errors",
        "README documents setup"
      ],
      "passes": false
    }
  ]
}
EOF
    echo "✅ Example prd.json created - customize it with your tasks"
  fi
fi

# === STEP 5: Pre-commit Hooks ===
echo ""
echo "🪝 Step 4: Code Review Automation (Optional)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Would you like to add pre-commit hooks for automated code review?"
echo ""
echo "Options:"
echo "  1. CodeRabbit CLI (AI code review)"
echo "  2. ESLint/Prettier (for JavaScript/TypeScript)"
echo "  3. Ruff/Black (for Python)"
echo "  4. None"
echo ""
read -p "Choose (1-4): " HOOK_CHOICE

case $HOOK_CHOICE in
  1)
    if ! command -v coderabbit &> /dev/null; then
      echo "⚠️  CodeRabbit CLI not found"
      echo "Install: npm install -g @coderabbitai/cli"
      echo "Then run: coderabbit auth"
    else
      mkdir -p .git/hooks
      cat > .git/hooks/pre-commit << 'HOOK'
#!/bin/bash
# CodeRabbit pre-commit hook

echo "🐰 Running CodeRabbit review..."
coderabbit review --diff || {
  echo "❌ CodeRabbit found issues"
  exit 1
}
echo "✅ CodeRabbit approved"
HOOK
      chmod +x .git/hooks/pre-commit
      echo "✅ CodeRabbit pre-commit hook installed"
    fi
    ;;
  2)
    mkdir -p .git/hooks
    cat > .git/hooks/pre-commit << 'HOOK'
#!/bin/bash
# ESLint/Prettier pre-commit hook

echo "🔍 Running linters..."
npm run lint || {
  echo "❌ Linting failed"
  exit 1
}
echo "✅ Linting passed"
HOOK
    chmod +x .git/hooks/pre-commit
    echo "✅ ESLint pre-commit hook installed"
    echo "⚠️  Make sure you have 'npm run lint' configured in package.json"
    ;;
  3)
    mkdir -p .git/hooks
    cat > .git/hooks/pre-commit << 'HOOK'
#!/bin/bash
# Ruff/Black pre-commit hook

echo "🔍 Running Python formatters..."
ruff check . || {
  echo "❌ Ruff check failed"
  exit 1
}
black --check . || {
  echo "❌ Black formatting check failed"
  exit 1
}
echo "✅ Formatting checks passed"
HOOK
    chmod +x .git/hooks/pre-commit
    echo "✅ Python pre-commit hook installed"
    ;;
  4)
    echo "⏭️  Skipping pre-commit hooks"
    ;;
esac

# === STEP 6: Final Summary ===
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Setup Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Files created:"
echo "  📄 AGENTS.md - Pattern library for your $LANG stack"
if [ -f "$SCRIPT_DIR/prd.json" ]; then
  echo "  📄 prd.json - Task list (customize it!)"
fi
echo ""
echo "Next steps:"
echo "  1. Customize prd.json with your user stories"
echo "  2. Review AGENTS.md and add project-specific patterns"
echo "  3. Run: ./wiggum.sh --tool claude 50"
echo ""
echo "Need help with PRD?"
echo "  • See prd.json.example for format"
echo "  • Use Claude: 'Convert my PRD.md to prd.json format'"
echo "  • Load wiggum skill and ask for PRD generation"
echo ""
echo "Happy autonomous coding! 🚀"
