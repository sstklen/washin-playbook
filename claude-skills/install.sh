#!/bin/bash
# Washin Claude Skills — One-command installer
# Install production web dev skills for Claude Code
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/sstklen/washin-claude-skills/main/install.sh | bash
#   curl -sSL ... | bash -s -- --category bug-patterns
#   curl -sSL ... | bash -s -- --list

set -euo pipefail

SKILLS_DIR="${HOME}/.claude/skills"
REPO="sstklen/washin-claude-skills"
RAW_BASE="https://raw.githubusercontent.com/${REPO}/main/skills"

# =============================================
# Skill Registry (name → category)
# =============================================
declare -A SKILLS=(
  # AI Coding Workflow
  ["agentic-coding-complete"]="ai-coding"
  ["code-assistant-advanced-workflow"]="ai-coding"
  ["code-verification-loop"]="ai-coding"
  ["multi-ai-cli-orchestration"]="ai-coding"
  ["multi-terminal-parallel-development"]="ai-coding"
  ["ai-prompt-mastery"]="ai-coding"

  # Multi-Agent Systems
  ["multi-agent-workflow-design"]="multi-agent"
  ["agent-autonomy-safety-framework"]="multi-agent"
  ["ai-to-ai-communication-protocol"]="multi-agent"
  ["unified-ai-agent-architecture"]="multi-agent"
  ["audit-inflation-bias-prevention"]="multi-agent"
  ["multi-agent-tdz-trap"]="multi-agent"

  # AI Chatbot
  ["ai-chatbot-persona-design"]="chatbot"
  ["ai-chatbot-automated-testing"]="chatbot"
  ["chatbot-promise-execution-gap"]="chatbot"
  ["ai-concierge-intent-router-pattern"]="chatbot"

  # LLM & AI API
  ["llm-api-cost-optimization"]="llm-api"
  ["api-tool-use-upgrade-pattern"]="llm-api"
  ["ai-quota-monitoring-tools"]="llm-api"
  ["gemini-api-guide"]="llm-api"
  ["anthropic-vision-url-pitfalls"]="llm-api"
  ["vision-api-fastapi-integration"]="llm-api"
  ["llm-model-version-migration-2026"]="llm-api"
  ["nebula-ai-integration-guide"]="llm-api"

  # API Architecture
  ["api-platform-three-layer-architecture"]="api-arch"
  ["api-pricing-single-source-of-truth"]="api-arch"
  ["api-proxy-quota-hardstop-pattern"]="api-arch"
  ["multi-provider-fallback-gateway"]="api-arch"
  ["api-402-multilingual-deposit-persuasion"]="api-arch"
  ["mcp-http-adapter-pattern"]="api-arch"
  ["mcp-remote-auth-platform-differences"]="api-arch"
  ["service-channel-replication-pattern"]="api-arch"

  # Security
  ["api-security-audit-methodology"]="security"
  ["hono-subrouter-auth-isolation"]="security"
  ["brute-force-parallel-request-self-lock"]="security"
  ["github-action-security-hardening"]="security"
  ["security-for-non-engineers"]="security"

  # Hono & Bun
  ["hono-503-sqlite-fk-constraint"]="hono-bun"
  ["hono-global-middleware-ordering"]="hono-bun"
  ["hono-subrouter-route-conflict"]="hono-bun"
  ["bun-async-race-condition-pattern"]="hono-bun"
  ["bun-sqlite-like-parameter-binding"]="hono-bun"
  ["bun-sqlite-test-infrastructure"]="hono-bun"
  ["bun-sqlite-transaction-await-crash"]="hono-bun"

  # Docker & DevOps
  ["docker-small-vps-deploy-optimization"]="docker"
  ["docker-ghost-container-recovery"]="docker"
  ["docker-compose-force-recreate-caddy-loop"]="docker"
  ["docker-sqlite-wal-copy-trap"]="docker"
  ["docker-static-asset-copy-gotcha"]="docker"
  ["vps-migration-dns-ghost-debugging"]="docker"
  ["cloudflare-worker-performance-debugging"]="docker"

  # Database
  ["json-to-sqlite-hybrid-migration"]="database"
  ["sqlite-check-constraint-migration"]="database"
  ["supabase-rls-empty-data-debugging"]="database"

  # Frontend & UX
  ["nextjs-common-patterns"]="frontend"
  ["admin-elderly-friendly-ux"]="frontend"
  ["elderly-friendly-ssr-ui-optimization"]="frontend"
  ["eye-comfort-mode-implementation"]="frontend"
  ["ui-feedback-communication-protocol"]="frontend"
  ["cloudflare-tunnel-mobile-preview"]="frontend"
  ["template-literal-inline-js-escaping"]="frontend"
  ["remotion"]="frontend"

  # Python & FastAPI
  ["python-lazy-init-proxy-pattern"]="python"
  ["fastapi-development-production-dual-mode"]="python"
  ["railway-fastapi-deployment"]="python"
  ["deterministic-preprocessing-pipeline"]="python"

  # Bug Patterns
  ["async-job-duplicate-insert"]="bug-patterns"
  ["env-var-shadow-db-key-trap"]="bug-patterns"
  ["cron-generated-script-desync"]="bug-patterns"
  ["ledger-dual-purpose-side-effect-trap"]="bug-patterns"
  ["try-catch-const-block-scope-trap"]="bug-patterns"
  ["pre-deduct-phantom-refund-prevention"]="bug-patterns"
  ["serverless-api-timeout-pattern"]="bug-patterns"
  ["multi-layer-proxy-timeout-chain-debugging"]="bug-patterns"
  ["websocket-relay-stability-pattern"]="bug-patterns"
  ["elizaos-pglite-migration-timing-fix"]="bug-patterns"

  # Billing & Token Economics
  ["token-economics-audit-methodology"]="billing"
  ["platform-favorable-rounding"]="billing"
  ["game-economy-dynamic-parameterization"]="billing"
  ["supply-side-honeymoon-incentive"]="billing"
  ["community-product-ghost-town-fix"]="billing"

  # Testing & QA
  ["parallel-quality-audit-workflow"]="testing"
  ["playwright-anti-ai-detection-bypass"]="testing"
  ["batch-processing-output-architecture"]="testing"

  # Project Management
  ["auto-tidy"]="project-mgmt"
  ["project-index"]="project-mgmt"
  ["techdebt"]="project-mgmt"
  ["systematic-debug"]="project-mgmt"
  ["skill-format-standard"]="project-mgmt"
  ["skill-library-lifecycle-management"]="project-mgmt"
)

# =============================================
# Categories
# =============================================
declare -A CATEGORIES=(
  ["ai-coding"]="AI Coding Workflow"
  ["multi-agent"]="Multi-Agent Systems"
  ["chatbot"]="AI Chatbot Development"
  ["llm-api"]="LLM & AI API"
  ["api-arch"]="API Architecture"
  ["security"]="Security"
  ["hono-bun"]="Hono & Bun"
  ["docker"]="Docker & DevOps"
  ["database"]="Database"
  ["frontend"]="Frontend & UX"
  ["python"]="Python & FastAPI"
  ["bug-patterns"]="Bug Patterns"
  ["billing"]="Billing & Token Economics"
  ["testing"]="Testing & QA"
  ["project-mgmt"]="Project Management"
)

# =============================================
# Functions
# =============================================

list_categories() {
  echo ""
  echo "Available categories:"
  echo ""
  for key in $(echo "${!CATEGORIES[@]}" | tr ' ' '\n' | sort); do
    count=0
    for skill_cat in "${SKILLS[@]}"; do
      [ "$skill_cat" = "$key" ] && ((count++))
    done
    printf "  %-20s %s (%d skills)\n" "$key" "${CATEGORIES[$key]}" "$count"
  done
  echo ""
  echo "Total: ${#SKILLS[@]} skills"
  echo ""
  echo "Usage:"
  echo "  bash install.sh                    # Install all"
  echo "  bash install.sh --category docker  # Install one category"
  echo "  bash install.sh --list             # List all skills"
}

list_skills() {
  echo ""
  echo "All ${#SKILLS[@]} skills:"
  echo ""
  for skill in $(echo "${!SKILLS[@]}" | tr ' ' '\n' | sort); do
    printf "  %-45s [%s]\n" "$skill" "${SKILLS[$skill]}"
  done
  echo ""
}

install_skill() {
  local skill="$1"
  local url="${RAW_BASE}/${skill}.md"
  local dest="${SKILLS_DIR}/${skill}.md"

  if curl -sSf -o "$dest" "$url" 2>/dev/null; then
    echo "  ✅ ${skill}"
    return 0
  else
    echo "  ⏭️  ${skill} (not yet uploaded — install locally from ~/.claude/skills/)"
    return 1
  fi
}

install_category() {
  local target_cat="$1"
  local count=0
  local success=0

  echo ""
  echo "Installing ${CATEGORIES[$target_cat]} skills..."
  echo ""

  for skill in $(echo "${!SKILLS[@]}" | tr ' ' '\n' | sort); do
    if [ "${SKILLS[$skill]}" = "$target_cat" ]; then
      ((count++))
      install_skill "$skill" && ((success++)) || true
    fi
  done

  echo ""
  echo "Done: ${success}/${count} installed"
}

install_all() {
  local count=0
  local success=0

  echo ""
  echo "Installing all ${#SKILLS[@]} skills..."
  echo ""

  for skill in $(echo "${!SKILLS[@]}" | tr ' ' '\n' | sort); do
    ((count++))
    install_skill "$skill" && ((success++)) || true
  done

  echo ""
  echo "Done: ${success}/${count} installed to ${SKILLS_DIR}/"
}

# =============================================
# Main
# =============================================

echo ""
echo "🥋 Washin Claude Skills Installer"
echo "   112 battle-tested skills for production web dev"
echo ""

# 確保 skills 資料夾存在
mkdir -p "$SKILLS_DIR"

case "${1:-}" in
  --list)
    list_skills
    ;;
  --categories)
    list_categories
    ;;
  --category)
    if [ -z "${2:-}" ]; then
      echo "Error: specify a category name"
      list_categories
      exit 1
    fi
    if [ -z "${CATEGORIES[${2}]+x}" ]; then
      echo "Error: unknown category '${2}'"
      list_categories
      exit 1
    fi
    install_category "$2"
    ;;
  --help|-h)
    list_categories
    ;;
  *)
    install_all
    ;;
esac

echo ""
echo "Skills are loaded into Claude Code automatically."
echo "More info: https://github.com/sstklen/washin-claude-skills"
echo ""
