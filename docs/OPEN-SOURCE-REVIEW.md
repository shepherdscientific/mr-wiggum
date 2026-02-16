# Open Source Code Review Options

Mr. Wiggum prioritizes open source and self-hosted code review tools to maintain data privacy and avoid vendor lock-in.

## Recommended: Qodo Merge (PR-Agent)

**Why Qodo Merge?**
- ✅ Fully open source (Apache 2.0)
- ✅ Self-hosted
- ✅ Works with local LLMs (Ollama, llama.cpp)
- ✅ Free forever
- ✅ No cloud dependencies

### Installation

```bash
# pip (recommended)
pip install pr-agent --break-system-packages

# Docker
docker pull qodo/pr-agent

# npm
npm install -g pr-agent-cli
```

### Configuration for Local LLM

**Option 1: Environment Variables**
```bash
export PR_AGENT__MODEL=ollama/qwen3-coder
export OLLAMA__API_BASE=http://localhost:11434
```

**Option 2: Config File (~/.pr_agent/config.toml)**
```toml
[model]
model = "ollama/qwen3-coder"

[ollama]
api_base = "http://localhost:11434"

[pr_reviewer]
num_code_suggestions = 5
require_tests_review = true
```

### Usage

**Pre-commit Hook (automatic):**
```bash
./setup-wiggum.sh
# Choose option 1: Qodo Merge
```

**CLI (manual):**
```bash
# Review current changes
pr-agent review

# Review specific PR
pr-agent review --pr.url="https://github.com/owner/repo/pull/123"

# Generate improvements
pr-agent improve

# Generate PR description
pr-agent describe
```

### Features

- **Code Review:** Quality, security, performance analysis
- **Suggestions:** Auto-generate code improvements
- **PR Management:** Auto-descriptions, test coverage
- **Multi-platform:** GitHub, GitLab, Bitbucket, CLI

## Alternative: SonarQube Community Edition

**Why SonarQube?**
- ✅ Open source (LGPL)
- ✅ Self-hosted
- ✅ Mature static analysis
- ✅ Quality gates
- ✅ Compliance features

### Installation

```bash
# Docker (easiest)
docker run -d --name sonarqube \
  -p 9000:9000 \
  sonarqube:community

# Access: http://localhost:9000 (admin/admin)
```

### Integration

```bash
./setup-wiggum.sh
# Choose option 2: SonarQube

# Or manual setup
sonar-scanner \
  -Dsonar.projectKey=your-project \
  -Dsonar.sources=src \
  -Dsonar.host.url=http://localhost:9000
```

## Comparison

| Feature | Qodo Merge | SonarQube | Korbit.ai | CodeRabbit |
|---------|------------|-----------|-----------|------------|
| **License** | Open Source | Open Source | Proprietary | Proprietary |
| **Self-hosted** | ✅ | ✅ | ❌ | ❌ |
| **Local LLM** | ✅ | N/A | ❌ | ❌ |
| **Cost** | Free | Free | Paid/Free OSS | Paid |
| **Privacy** | Complete | Complete | Cloud | Cloud |
| **AI Review** | ✅ | ❌ | ✅ | ✅ |

## Not Recommended (Proprietary)

### Korbit.ai
- ❌ NOT open source
- ❌ Cloud-only SaaS
- ❌ No self-hosting option
- ✅ Free for open source projects

### CodeRabbit
- ❌ NOT open source
- ❌ Cloud-only SaaS
- ❌ Subscription required

## Complete Workflow Example

```bash
# 1. Setup Mr. Wiggum with Qodo Merge
cd ~/your-project
./setup-wiggum.sh
# Choose: 1 (Qodo Merge)
# Choose: y (Install)

# 2. Configure for local LLM
cat >> ~/.pr_agent/config.toml << EOF
[model]
model = "ollama/qwen3-coder"

[ollama]
api_base = "http://localhost:11434"
EOF

# 3. Test pre-commit hook
echo "// test" >> src/test.js
git add src/test.js
git commit -m "test: review"
# Qodo Merge runs automatically

# 4. Run autonomous loop
./wiggum.sh --tool claude 50
# Every commit gets reviewed
```

## Resources

### Qodo Merge
- **GitHub:** https://github.com/qodo-ai/pr-agent
- **Docs:** https://qodo-merge-docs.qodo.ai/
- **Ollama Guide:** https://qodo-merge-docs.qodo.ai/tools/ollama/

### SonarQube
- **Website:** https://www.sonarqube.org/
- **Docs:** https://docs.sonarqube.org/
- **Docker:** https://hub.docker.com/_/sonarqube

### Other Open Source Options
- **GitLab CE:** Full DevOps platform with code review
- **Gitea:** Lightweight self-hosted Git service
- **Gerrit:** Code review system used by Google, Android
- **Phorge:** Phabricator fork with active development

## Privacy Benefits

**Complete data sovereignty:**
- Code never leaves your infrastructure
- No telemetry or tracking
- No cloud API calls
- Run completely air-gapped if needed

**Perfect for:**
- Financial services
- Healthcare
- Government
- Blockchain/crypto projects
- Security-conscious teams

## Cost Benefits

**Zero ongoing costs:**
- No per-seat pricing
- No API usage fees
- No subscription fees
- Only infrastructure costs (self-hosted)

**Scales without cost:**
- Unlimited developers
- Unlimited repositories
- Unlimited reviews

## Why Not Proprietary Tools?

**Data privacy:**
- Your code goes to third-party servers
- Subject to their data retention policies
- Compliance/regulatory concerns

**Vendor lock-in:**
- Dependent on their pricing
- Features gated by plan tier
- Risk of service discontinuation

**Cost:**
- Per-seat monthly fees
- API usage charges
- Price increases over time

## Recommendation

**For Mr. Wiggum users:**
Use **Qodo Merge (PR-Agent)** with local LLMs for:
- Complete privacy
- Zero cost
- Full customization
- Local inference (no network latency)
- Works with your existing Ollama/llama.cpp setup

This aligns perfectly with:
- QubesOS security principles
- Local-first architecture
- Cost optimization goals
- Fresh context approach
