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
echo "🔍 Code Review Integration (Open Source)"
echo "---"
echo "Optional: Configure automated code review"
echo ""
echo "Available options:"
echo "  1) Qodo Merge (PR-Agent) - Open source, self-hosted, supports local LLMs ⭐"
echo "  2) SonarQube CE - Open source static analysis"
echo "  3) None (skip for now)"
read -p "Choose option [1-3]: " REVIEW_CHOICE

SETUP_HOOKS=false
REVIEW_TOOL=""

if [ "$REVIEW_CHOICE" == "1" ]; then
  REVIEW_TOOL="qodo"
  echo ""
  echo "📦 Qodo Merge (PR-Agent) Setup"
  echo "---"
  echo "Installation options:"
  echo "  A) Docker (recommended): docker run -it qodo/pr-agent"
  echo "  B) pip: pip install pr-agent"
  echo "  C) CLI local: npm install -g pr-agent-cli"
  echo ""
  echo "Pre-commit hook will use CLI mode"
  read -p "Install Qodo Merge? [y/N]: " INSTALL_QODO
  
  if [[ "$INSTALL_QODO" =~ ^[Yy]$ ]]; then
    echo "Installing pr-agent..."
    if command -v pip &> /dev/null; then
      pip install pr-agent --break-system-packages 2>/dev/null || pip install pr-agent
      echo "✅ Installed via pip"
    else
      echo "⚠️  pip not found. Install manually:"
      echo "   pip install pr-agent"
      echo "   OR"
      echo "   docker pull qodo/pr-agent"
    fi
  fi
  
  SETUP_HOOKS=true
  
elif [ "$REVIEW_CHOICE" == "2" ]; then
  REVIEW_TOOL="sonarqube"
  echo ""
  echo "📦 SonarQube CE Setup"
  echo "---"
  echo "SonarQube requires:"
  echo "  - Docker: docker run -d --name sonarqube -p 9000:9000 sonarqube:community"
  echo "  - OR download from: https://www.sonarqube.org/downloads/"
  echo ""
  echo "Pre-commit hook will run sonar-scanner"
  read -p "Setup SonarQube hook? [y/N]: " SETUP_SONAR
  
  if [[ "$SETUP_SONAR" =~ ^[Yy]$ ]]; then
    SETUP_HOOKS=true
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
  
  if [ "$REVIEW_TOOL" == "qodo" ]; then
    cat > .git/hooks/pre-commit << 'HOOK_EOF'
#!/bin/bash
# Mr. Wiggum pre-commit hook - Qodo Merge (PR-Agent)

echo "🔍 Running Qodo Merge review..."

# Get staged files
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM)

if [ -z "$STAGED_FILES" ]; then
  echo "No files to review"
  exit 0
fi

# Create temporary commit for review
git stash -q --keep-index

# Run pr-agent review
if command -v pr-agent &> /dev/null; then
  echo ""
  echo "Files to review:"
  echo "$STAGED_FILES" | head -5
  echo ""
  
  # Run review on staged changes
  pr-agent review \
    --pr.diff="$(git diff --cached)" \
    --pr.mode=cli \
    2>&1 | tee /tmp/pr-agent-review.log
  
  RESULT=$?
  
  git stash pop -q
  
  if [ $RESULT -ne 0 ]; then
    echo ""
    echo "⚠️  Qodo Merge found issues"
    echo "   See /tmp/pr-agent-review.log for details"
    echo ""
    read -p "Commit anyway? [y/N]: " FORCE_COMMIT
    
    if [[ ! "$FORCE_COMMIT" =~ ^[Yy]$ ]]; then
      echo "Commit cancelled"
      exit 1
    fi
  else
    echo "✅ Code review passed"
  fi
else
  echo "⚠️  pr-agent not installed, skipping review"
  echo "   Install: pip install pr-agent"
  git stash pop -q
fi

exit 0
HOOK_EOF
  
  elif [ "$REVIEW_TOOL" == "sonarqube" ]; then
    cat > .git/hooks/pre-commit << 'HOOK_EOF'
#!/bin/bash
# Mr. Wiggum pre-commit hook - SonarQube

echo "🔍 Running SonarQube analysis..."

# Get staged files
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM)

if [ -z "$STAGED_FILES" ]; then
  echo "No files to review"
  exit 0
fi

# Run sonar-scanner if available
if command -v sonar-scanner &> /dev/null; then
  echo ""
  echo "Analyzing staged files..."
  
  # Create temp sonar-project.properties
  cat > /tmp/sonar-project.properties << SONAR_EOF
sonar.projectKey=wiggum-precommit
sonar.sources=$STAGED_FILES
sonar.host.url=http://localhost:9000
SONAR_EOF
  
  sonar-scanner -Dproject.settings=/tmp/sonar-project.properties
  RESULT=$?
  
  rm /tmp/sonar-project.properties
  
  if [ $RESULT -ne 0 ]; then
    echo ""
    echo "⚠️  SonarQube found issues"
    echo "   Review at http://localhost:9000"
    echo ""
    read -p "Commit anyway? [y/N]: " FORCE_COMMIT
    
    if [[ ! "$FORCE_COMMIT" =~ ^[Yy]$ ]]; then
      echo "Commit cancelled"
      exit 1
    fi
  else
    echo "✅ SonarQube analysis passed"
  fi
else
  echo "⚠️  sonar-scanner not installed, skipping review"
  echo "   Install: https://docs.sonarqube.org/latest/analysis/scan/sonarscanner/"
fi

exit 0
HOOK_EOF
  fi
  
  chmod +x .git/hooks/pre-commit
  echo "✅ Created pre-commit hook with $REVIEW_TOOL integration"
fi

echo ""
echo "🎉 Setup complete!"
echo ""

if [ "$REVIEW_TOOL" == "qodo" ]; then
  echo "📚 Qodo Merge Resources:"
  echo "   - Docs: https://qodo-merge-docs.qodo.ai/"
  echo "   - GitHub: https://github.com/qodo-ai/pr-agent"
  echo "   - Local LLM support: Use Ollama with --model flag"
  echo ""
  echo "Configure for local LLM:"
  echo "   export PR_AGENT__MODEL=ollama/qwen3-coder"
  echo "   export OLLAMA__API_BASE=http://localhost:11434"
  echo ""
fi

if [ "$REVIEW_TOOL" == "sonarqube" ]; then
  echo "📚 SonarQube Resources:"
  echo "   - Docs: https://docs.sonarqube.org/"
  echo "   - Docker: docker run -d --name sonarqube -p 9000:9000 sonarqube:community"
  echo "   - Web UI: http://localhost:9000"
  echo ""
fi

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
