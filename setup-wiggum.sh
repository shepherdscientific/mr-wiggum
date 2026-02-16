#!/bin/bash
# Mr. Wiggum Setup - Interactive configuration
# Creates AGENTS.md, prd.json, and optional pre-commit hooks

set -e

echo "🤖 Mr. Wiggum Setup"
echo "=================="
echo ""

# Detect project info
PROJECT_NAME=$(basename "$PWD")
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "main")

echo "📁 Project: $PROJECT_NAME"
echo "🌿 Current branch: $CURRENT_BRANCH"
echo ""

# Ask about tech stack
echo "🔧 Tech Stack Configuration"
echo "---"

read -p "Primary language (e.g., JavaScript, Python, Go): " LANGUAGE
read -p "Framework (e.g., Express, FastAPI, none): " FRAMEWORK
read -p "Database (e.g., PostgreSQL, MongoDB, none): " DATABASE
read -p "Test command (e.g., npm test, pytest): " TEST_CMD
read -p "Type check command (e.g., npm run typecheck, mypy .): " TYPECHECK_CMD

echo ""
echo "📋 PRD Configuration"
echo "---"

read -p "Feature name for this branch (e.g., user-auth, api-v2): " FEATURE_NAME
read -p "Number of initial user stories to create: " NUM_STORIES

echo ""
echo "🔍 Code Review Integration"
echo "---"
echo "Optional: Configure automated code review"
echo ""
echo "Available options:"
echo "  1) CodeRabbit (AI code reviewer)"
echo "  2) None (skip for now)"
read -p "Choose option [1-2]: " REVIEW_CHOICE

SETUP_HOOKS=false
if [ "$REVIEW_CHOICE" == "1" ]; then
  SETUP_HOOKS=true
  echo ""
  echo "ℹ️  CodeRabbit requires:"
  echo "   - Install: gh extension install coderabbitai/gh-coderabbit"
  echo "   - Setup: gh coderabbit setup"
  read -p "Have you installed CodeRabbit? [y/N]: " HAS_CODERABBIT
  
  if [[ ! "$HAS_CODERABBIT" =~ ^[Yy]$ ]]; then
    echo "⚠️  Install CodeRabbit first, then re-run setup"
    SETUP_HOOKS=false
  fi
fi

echo ""
echo "✨ Creating files..."
echo ""

# Create AGENTS.md
cat > AGENTS.md << EOF
# Agent Pattern Library

**Purpose:** Curated, reusable knowledge for autonomous agents.

**Rules:**
- Keep under 500 lines (auto-compacted if exceeded)
- Only general patterns, not story-specific details
- Clear, actionable guidance

---

## Project Setup

**Tech Stack:**
- Language: $LANGUAGE
- Framework: ${FRAMEWORK:-none}
- Database: ${DATABASE:-none}

**Commands:**
\`\`\`bash
$TEST_CMD           # Run tests
$TYPECHECK_CMD      # Type checking
\`\`\`

**Test Requirements:**
- Tests must pass before committing
- ${DATABASE:+Mock database calls in unit tests}

---

## Codebase Conventions

### File Organization
- \`src/\` - Application code
- \`tests/\` - Test files

### Code Patterns
(Agents will populate as they discover patterns)

---

## Common Gotchas

(Agents will populate this section as they discover issues)

---

## Implementation Notes

**When adding new features:**
1. Write tests first (TDD)
2. Implement feature
3. Ensure all tests pass
4. Update this file with any new patterns

---

*Last updated: $(date)*
EOF

echo "✅ Created AGENTS.md"

# Create prd.json
cat > prd.json << EOF
{
  "projectName": "$PROJECT_NAME - $FEATURE_NAME",
  "branchName": "ralph/$FEATURE_NAME",
  "userStories": [
EOF

for i in $(seq 1 $NUM_STORIES); do
  COMMA=""
  if [ $i -lt $NUM_STORIES ]; then
    COMMA=","
  fi
  
  cat >> prd.json << EOF
    {
      "id": "STORY-$(printf "%03d" $i)",
      "title": "TODO: Define user story $i",
      "acceptanceCriteria": [
        "TODO: Define acceptance criteria",
        "Tests pass",
        "Type check passes"
      ],
      "passes": false
    }$COMMA
EOF
done

cat >> prd.json << EOF

  ]
}
EOF

echo "✅ Created prd.json with $NUM_STORIES placeholder stories"
echo "   📝 Edit prd.json to define your actual user stories"

# Setup pre-commit hooks if requested
if [ "$SETUP_HOOKS" = true ]; then
  mkdir -p .git/hooks
  
  cat > .git/hooks/pre-commit << 'HOOK_EOF'
#!/bin/bash
# Mr. Wiggum pre-commit hook - CodeRabbit review

echo "🔍 Running CodeRabbit review..."

# Get staged files
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM)

if [ -z "$STAGED_FILES" ]; then
  echo "No files to review"
  exit 0
fi

# Run CodeRabbit
if command -v gh &> /dev/null && gh extension list | grep -q coderabbit; then
  # Create temporary diff
  DIFF_FILE=$(mktemp)
  git diff --cached > "$DIFF_FILE"
  
  # Run review
  gh coderabbit review < "$DIFF_FILE"
  RESULT=$?
  
  rm "$DIFF_FILE"
  
  if [ $RESULT -ne 0 ]; then
    echo ""
    echo "⚠️  CodeRabbit found issues"
    echo "   Review suggestions above"
    echo ""
    read -p "Commit anyway? [y/N]: " FORCE_COMMIT
    
    if [[ ! "$FORCE_COMMIT" =~ ^[Yy]$ ]]; then
      echo "Commit cancelled"
      exit 1
    fi
  fi
else
  echo "⚠️  CodeRabbit not installed, skipping review"
fi

exit 0
HOOK_EOF
  
  chmod +x .git/hooks/pre-commit
  echo "✅ Created pre-commit hook with CodeRabbit integration"
fi

echo ""
echo "🎉 Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Edit prd.json and define your user stories"
echo "  2. Review AGENTS.md and customize for your project"
echo "  3. Run: ./wiggum.sh"
echo ""
echo "Example user story:"
echo '  {'
echo '    "id": "AUTH-001",'
echo '    "title": "Implement JWT authentication",'
echo '    "acceptanceCriteria": ['
echo '      "POST /api/auth/login returns JWT token",'
echo '      "Invalid credentials return 401",'
echo '      "Tests pass"'
echo '    ],'
echo '    "passes": false'
echo '  }'
echo ""
