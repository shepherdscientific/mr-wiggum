#!/bin/bash
# Ship by Breakfast - One Command Setup
# Downloads MVP files and starts Ralph overnight

set -e

echo "🚀 Ship by Breakfast - MVP Setup"
echo "================================="
echo ""

PROJECT_DIR="${1:-$PWD}"

if [ ! -d "$PROJECT_DIR" ]; then
  echo "Error: Directory $PROJECT_DIR not found"
  echo "Usage: $0 /path/to/dao-domain-web"
  exit 1
fi

cd "$PROJECT_DIR"

echo "📁 Working directory: $PWD"
echo ""

# Check if git repo
if [ ! -d ".git" ]; then
  echo "❌ Not a git repository. Run this in your project root."
  exit 1
fi

echo "1️⃣ Creating MVP branch..."
git checkout -b mvp/launch 2>/dev/null || git checkout mvp/launch
echo "✅ On branch: mvp/launch"
echo ""

echo "2️⃣ Backing up current files..."
[ -f prd.json ] && cp prd.json prd-full-backup.json
[ -f progress.txt ] && cp progress.txt progress-full-backup.txt
echo "✅ Backed up to *-backup.json"
echo ""

echo "3️⃣ Downloading MVP files from mr-wiggum..."

# Download PRD
curl -sL https://raw.githubusercontent.com/shepherdscientific/mr-wiggum/main/examples/prd-mvp-launch.json -o prd.json
echo "✅ Downloaded prd.json (10 stories)"

# Download progress tracker
curl -sL https://raw.githubusercontent.com/shepherdscientific/mr-wiggum/main/examples/progress-mvp-launch.txt -o progress.txt
echo "✅ Downloaded progress.txt"

# Download wiggum script if not exists
if [ ! -f "wiggum.sh" ]; then
  curl -sL https://raw.githubusercontent.com/shepherdscientific/mr-wiggum/main/wiggum.sh -o wiggum.sh
  chmod +x wiggum.sh
  echo "✅ Downloaded wiggum.sh"
fi

# Download CLAUDE.md for minimal context
cat > CLAUDE.md << 'CLAUDEMD'
# Claude Code - Ship by Breakfast

## READ ONLY:
1. prd.json (10 MVP stories)
2. AGENTS.md (if exists, patterns only)
3. git log --oneline -5

## CRITICAL: Context budget = 30K tokens MAX

## Your Mission:
Fix blockers first (BLOCKER-001, BLOCKER-002), then implement MVP features.
One story per iteration. Exit after each story.

## Pricing (Competitive):
- Bundle: $19.99/year first, $29.99 renewal
- Domain: $12.99
- Hosting: $4.99/mo
- AI website: $9.99
**Total separately: $89 → Bundle: $19.99 (saves $69)**

## Competitors:
- Hostinger: $23.99/year (no AI)
- Namecheap: $18.88/year (basic)
- GoDaddy: $59.99/year (slow AI)

## Unit Economics:
- Revenue: $19.99
- COGS: $13.15 (domain $10 + hosting $3 + AI $0.15)
- Margin: $6.84 (34%)
- Break-even: 76 customers

## Exit after ONE story
CLAUDEMD
echo "✅ Created CLAUDE.md"
echo ""

echo "4️⃣ Creating AGENTS.md if not exists..."
if [ ! -f "AGENTS.md" ]; then
  cat > AGENTS.md << 'AGENTSMD'
# Agent Pattern Library

## Pricing Strategy
**Bundle pricing:** $19.99 first year (competitive with Hostinger $23.99)
**Renewal:** $29.99/year (vs Namecheap $48.88)
**Margin:** 34% first year, 56% renewal

## Domain Reseller APIs
**Namecheap:** Sandbox mode for testing, use .test TLD
**Production:** Requires approval (24-48 hours)

## Cost Controls
**AI generation:** Use GPT-4o-mini ($0.01-0.15 per site)
**Hosting:** Defer to post-MVP (ship domain first)
**Email:** SendGrid free tier (100/day sufficient for MVP)

## MVP Philosophy
Ship: Domain registration + Email confirmation
Defer: Hosting provision (add after 10 customers)
Defer: Web3/DAO (add after 200 customers)

---
Last updated: $(date)
AGENTSMD
  echo "✅ Created AGENTS.md"
else
  echo "⏭️  AGENTS.md exists, keeping it"
fi
echo ""

echo "5️⃣ Checking for security vulnerabilities..."
if command -v npm &> /dev/null; then
  echo "Running npm audit..."
  npm audit 2>&1 | grep -E "vulnerabilities|high|critical" | head -5
  echo ""
  echo "💡 Ralph will fix these in BLOCKER-002"
else
  echo "⚠️  npm not found, skip for now"
fi
echo ""

echo "6️⃣ Finding domains route error..."
if [ -d "app" ]; then
  echo "Searching for toLocaleString error..."
  grep -rn "toLocaleString()" app/ 2>/dev/null | grep -v node_modules | head -3 || echo "Not found yet"
  echo ""
  echo "💡 Ralph will fix this in BLOCKER-001"
else
  echo "⚠️  app/ directory not found"
fi
echo ""

cat << 'READY'
════════════════════════════════════════════════════════════
✅ READY FOR RALPH
════════════════════════════════════════════════════════════

Files in place:
  ✓ prd.json (10 MVP stories)
  ✓ progress.txt (tracking)
  ✓ CLAUDE.md (minimal context)
  ✓ AGENTS.md (patterns)
  ✓ wiggum.sh (runner)

Branch: mvp/launch
Backups: prd-full-backup.json, progress-full-backup.txt

════════════════════════════════════════════════════════════
🌙 RUN OVERNIGHT
════════════════════════════════════════════════════════════

Start Ralph with fresh context (recommended):

  ./wiggum.sh --tool claude 10

This will:
  1. Fix domains route crash (BLOCKER-001)
  2. Fix security vulns (BLOCKER-002)
  3. Simplify landing page
  4. Update pricing to $19.99
  5. Integrate Namecheap sandbox
  6. Add Stripe test mode
  7. Create AI generator
  8. Wire payment webhook
  9. Setup email confirmation
  10. Deploy to staging

Expected: ~2-3 hours with local LLM (qwen3-coder)

════════════════════════════════════════════════════════════
📊 COMPETITIVE PRICING (UPDATED)
════════════════════════════════════════════════════════════

Bundle: $19.99/year first year
        $29.99/year renewal

vs Competitors:
  • Hostinger: $23.99/year (no AI)
  • Namecheap: $18.88/year (basic only)
  • GoDaddy: $59.99/year (slow builder)

Our Edge: AI website generator at $19.99 total

Unit Economics:
  Revenue: $19.99
  COGS: $13.15
  Margin: $6.84 (34%)
  
Break-even: 76 customers
Target: 100 customers = $1,999 revenue

════════════════════════════════════════════════════════════
🎯 SUCCESS = DEPLOYABLE BY BREAKFAST
════════════════════════════════════════════════════════════

Morning checklist:
  [ ] Site loads without errors
  [ ] Can search domains
  [ ] Can checkout (test mode)
  [ ] Email confirmation sends
  [ ] Deployed to staging
  [ ] Ready for soft launch

════════════════════════════════════════════════════════════

Want to start? Run:

  ./wiggum.sh --tool claude 10

READY

echo ""
echo "Setup complete! Ready to run wiggum.sh"
echo ""
