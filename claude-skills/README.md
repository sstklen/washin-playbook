<p align="center">
  <h1 align="center">112 Claude Code Skills</h1>
  <p align="center"><strong>Every bug we solved, every pattern we discovered — building an AI-powered platform with zero engineers.</strong></p>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Skills-112-blue?style=for-the-badge" alt="112 Skills"/>
  <img src="https://img.shields.io/badge/Source-Real_Production-green?style=for-the-badge" alt="Real Production"/>
  <img src="https://img.shields.io/badge/Cost-Free-orange?style=for-the-badge" alt="Free"/>
  <a href="https://www.npmjs.com/package/washin-claude-skills"><img src="https://img.shields.io/npm/v/washin-claude-skills?style=for-the-badge&logo=npm&logoColor=white&label=npx" alt="npm"/></a>
</p>

<p align="center">
  <a href="https://github.com/sstklen/washin-claude-skills/stargazers"><img src="https://img.shields.io/github/stars/sstklen/washin-claude-skills?style=social" alt="Stars"/></a>
</p>

---

## The Story

We run an animal sanctuary in rural Japan. 28 cats and dogs. Zero engineers on staff.

We built an entire [API marketplace](https://api.washinmura.jp) using Claude Code as our only developer — 30+ API integrations, multi-language support, token economy, Docker deployment, the works.

Along the way, we hit every bug imaginable. Docker OOM kills at 3am. Auth bypasses we caught just in time. SQLite corruption from a single misplaced `await`. Each time, we extracted the lesson into a reusable Claude Code skill.

**This is that collection. 112 skills. All battle-tested. All free.**

---

## How is this different from AI-Research-SKILLs?

[AI-Research-SKILLs](https://github.com/Orchestra-Research/AI-Research-SKILLs) (3,700+ ⭐) covers **ML research** — training, fine-tuning, inference.

This collection covers **production web development** — the skills you need when you're actually shipping software:

| AI-Research-SKILLs | This Collection |
|---------------------|-----------------|
| Model training (Megatron, DeepSpeed) | API architecture (multi-provider gateway, quota enforcement) |
| Fine-tuning (LoRA, PEFT, Unsloth) | Docker deployment (OOM fixes, ghost containers, WAL traps) |
| Inference serving (vLLM, TensorRT) | Bug patterns (10 production outage lessons) |
| ML evaluation benchmarks | Security (auth bypass, brute-force, API audit) |
| Research paper writing | Hono / Bun / SQLite (7 framework-specific fixes) |

**They're complementary, not competing.** Install both if you do ML + web dev.

---

## Install

### Option A: curl (recommended)

```bash
curl -sSL https://raw.githubusercontent.com/sstklen/washin-claude-skills/main/install.sh | bash
```

### Option B: npx

```bash
npx washin-claude-skills
```

### By category

```bash
# curl
curl -sSL https://raw.githubusercontent.com/sstklen/washin-claude-skills/main/install.sh | bash -s -- --category docker

# npx
npx washin-claude-skills --category docker

# List all categories
npx washin-claude-skills --categories
```

### Single skill

```bash
curl -sSL https://raw.githubusercontent.com/sstklen/washin-claude-skills/main/skills/SKILL_NAME.md \
  -o ~/.claude/skills/SKILL_NAME.md
```

> Skills are `.md` files in `~/.claude/skills/`. Once installed, Claude Code automatically uses them when relevant.

---

## Table of Contents

- [AI Coding Workflow](#-ai-coding-workflow) (6)
- [Multi-Agent Systems](#-multi-agent-systems) (7)
- [AI Chatbot Development](#-ai-chatbot-development) (4)
- [LLM & AI API](#-llm--ai-api) (8)
- [API Architecture](#-api-architecture) (9)
- [Security](#-security) (5)
- [Hono & Bun](#-hono--bun) (7)
- [Docker & DevOps](#-docker--devops) (7)
- [Database](#-database) (3)
- [Frontend & UX](#-frontend--ux) (8)
- [Python & FastAPI](#-python--fastapi) (4)
- [Bug Patterns](#-bug-patterns) (10)
- [Billing & Token Economics](#-billing--token-economics) (5)
- [Testing & QA](#-testing--qa) (3)
- [Scraping & Data](#-scraping--data) (3)
- [Business & Market Research](#-business--market-research) (5)

---

## 🎯 AI Coding Workflow

| Skill | What it does |
|-------|-------------|
| **agentic-coding-complete** | Complete guide to AI-assisted coding: practices + mindset + theory vs reality |
| **code-assistant-advanced-workflow** | Boris Cherny's (Claude Code creator) tips, workflows, and prompting strategies |
| **code-verification-loop** | The #1 technique from Claude Code's creator — auto-verify every change |
| **multi-ai-cli-orchestration** | Use Claude Code as boss, orchestrate Codex + Gemini CLI as team |
| **multi-terminal-parallel-development** | Run multiple Claude Code instances in parallel safely |
| **ai-prompt-mastery** | One prompt to make any AI respond like an expert |

## 🤖 Multi-Agent Systems

| Skill | What it does |
|-------|-------------|
| **multi-agent-workflow-design** | Design multi-agent workflows: identify tasks, configure agents, validate output |
| **agent-autonomy-safety-framework** | Prevent dangerous AI behavior: collusion, deception, unauthorized decisions |
| **ai-to-ai-communication-protocol** | Machine-to-machine AI communication: message format, hallucination detection |
| **unified-ai-agent-architecture** | Unify prediction, recommendation, matching, and scoring into one AI hub |
| **audit-inflation-bias-prevention** | Prevent AI audit reports from inflating fake problems |
| **multi-agent-tdz-trap** | Fix "Cannot access X before initialization" from multi-agent code insertion |
| **infinite-gratitude** | 10 parallel research agents, 3 waves — like cats endlessly bringing gifts |

## 💬 AI Chatbot Development

| Skill | What it does |
|-------|-------------|
| **ai-chatbot-persona-design** | Design chatbot personality, conversation strategy, concierge flow |
| **ai-chatbot-automated-testing** | Auto-test chatbot with "difficult customer" personas, iterate prompts |
| **chatbot-promise-execution-gap** | Fix "bot says it will send X but never actually does" |
| **ai-concierge-intent-router-pattern** | LLM-powered natural language router for API marketplace |

## 🧠 LLM & AI API

| Skill | What it does |
|-------|-------------|
| **llm-api-cost-optimization** | Save 50-90% on Claude API (Batch, Caching, Extended Thinking) |
| **api-tool-use-upgrade-pattern** | Upgrade from sync API to async + Tool Use + Prompt Caching |
| **ai-quota-monitoring-tools** | Monitor Claude Max / ChatGPT Pro / Gemini Ultra usage |
| **gemini-api-guide** | Google Gemini API: SDK migration, error fixes, video analysis |
| **anthropic-vision-url-pitfalls** | Fix Claude Vision API failures with URL-based images |
| **vision-api-fastapi-integration** | Integrate Claude Vision into FastAPI (multimodal analysis) |
| **llm-model-version-migration-2026** | Fix "model not found" 404s from 2025-2026 model name changes |
| **nebula-ai-integration-guide** | Integrate with Nebula AI: capabilities, limits, communication protocol |

## 🏗️ API Architecture

| Skill | What it does |
|-------|-------------|
| **api-platform-three-layer-architecture** | 3-tier API platform design: same APIs, 3x revenue |
| **api-pricing-single-source-of-truth** | Centralize ALL pricing into a single zero-dependency registry |
| **api-proxy-quota-hardstop-pattern** | 3-layer quota enforcement: Config → Middleware → Endpoint |
| **multi-provider-fallback-gateway** | Multi-provider failover gateway for 99.97% uptime |
| **api-402-multilingual-deposit-persuasion** | 402 responses that convince AI Agents to get their humans to pay |
| **api-pool-token-pricing-methodology** | Price internal tokens for API sharing pools |
| **mcp-http-adapter-pattern** | Convert any REST API into MCP-native tools |
| **mcp-remote-auth-platform-differences** | MCP auth quirks across Claude Desktop, Cursor, Windsurf |
| **service-channel-replication-pattern** | Add Telegram/Discord/LINE to existing multi-channel systems |

## 🔒 Security

| Skill | What it does |
|-------|-------------|
| **api-security-audit-methodology** | 30+ vulnerability patterns + multi-round iterative audit strategy |
| **hono-subrouter-auth-isolation** | Fix CRITICAL auth bypass with multiple Hono sub-routers |
| **brute-force-parallel-request-self-lock** | Fix brute-force protection locking out real users (SPA parallel requests) |
| **github-action-security-hardening** | GitHub Action (composite) pre-release security checklist |
| **security-for-non-engineers** | Explain security in plain language — auto-detect and fix vulnerabilities |

## ⚡ Hono & Bun

| Skill | What it does |
|-------|-------------|
| **hono-503-sqlite-fk-constraint** | Fix misleading 503 errors when the real cause is SQLite FK constraints |
| **hono-global-middleware-ordering** | Fix global middleware silently not executing for sub-routes |
| **hono-subrouter-route-conflict** | Fix sub-router swallowing parent path routes (404 on exact match) |
| **bun-async-race-condition-pattern** | Fix async race conditions in Bun single-threaded handlers |
| **bun-sqlite-like-parameter-binding** | Fix bun:sqlite LIKE queries silently returning zero results |
| **bun-sqlite-test-infrastructure** | Complete test infrastructure for Bun + SQLite (bun:test) |
| **bun-sqlite-transaction-await-crash** | Fix production crash from `await` inside `db.transaction()` |

## 🐳 Docker & DevOps

| Skill | What it does |
|-------|-------------|
| **docker-small-vps-deploy-optimization** | Fix OOM kills on 2GB VPS during Docker build |
| **docker-ghost-container-recovery** | Fix ghost containers blocking `docker compose up` |
| **docker-compose-force-recreate-caddy-loop** | Fix infinite restart loop with `--force-recreate` |
| **docker-sqlite-wal-copy-trap** | Fix stale/corrupted SQLite data from `docker cp` |
| **docker-static-asset-copy-gotcha** | Fix static assets returning 404 in Docker containers |
| **vps-migration-dns-ghost-debugging** | Fix all 404s after VPS migration (Cloudflare DNS ghost) |
| **cloudflare-worker-performance-debugging** | Debug slow Cloudflare Workers and API integration |

## 🗄️ Database

| Skill | What it does |
|-------|-------------|
| **json-to-sqlite-hybrid-migration** | Migrate from JSON file persistence to SQLite (zero downtime) |
| **sqlite-check-constraint-migration** | Fix CHECK constraint failures when expanding allowed values |
| **supabase-rls-empty-data-debugging** | Debug Supabase RLS/Auth returning empty data |

## 🎨 Frontend & UX

| Skill | What it does |
|-------|-------------|
| **nextjs-common-patterns** | Next.js 13+ fixes: "params is a Promise", dynamic routes, Image config |
| **admin-elderly-friendly-ux** | Turn technical admin panels into interfaces anyone can use |
| **elderly-friendly-ssr-ui-optimization** | Make SSR pages accessible for elderly users |
| **eye-comfort-mode-implementation** | Implement eye comfort / dark mode with CSS variables |
| **ui-feedback-communication-protocol** | Let non-technical stakeholders give UI feedback efficiently |
| **cloudflare-tunnel-mobile-preview** | Preview localhost on mobile — one command, no signup |
| **template-literal-inline-js-escaping** | Fix silent page failures from template literal syntax errors |
| **remotion** | Create programmatic videos with React (Remotion best practices) |

## 🐍 Python & FastAPI

| Skill | What it does |
|-------|-------------|
| **python-lazy-init-proxy-pattern** | Lazy init proxy + deployment packaging + Pydantic tricks |
| **fastapi-development-production-dual-mode** | Dev/prod dual mode with agent caching + Next.js integration |
| **railway-fastapi-deployment** | Deploy FastAPI to Railway without the common pitfalls |
| **deterministic-preprocessing-pipeline** | Extract structured data from chat logs (Python + AI QC) |

## 🐛 Bug Patterns

Hard-won lessons from production outages. Each one cost us hours so it won't cost you.

| Skill | What it does |
|-------|-------------|
| **async-job-duplicate-insert** | Fix "UNIQUE constraint failed" when separating async job creation |
| **env-var-shadow-db-key-trap** | Fix .env placeholder silently shadowing valid DB-stored keys |
| **cron-generated-script-desync** | Fix cron running stale scripts when the script is auto-generated |
| **ledger-dual-purpose-side-effect-trap** | Prevent double-counting when logging functions also update balances |
| **try-catch-const-block-scope-trap** | Fix const/let block scope causing misleading 503/500 errors |
| **pre-deduct-phantom-refund-prevention** | Prevent phantom refunds in pre-deduct billing systems |
| **serverless-api-timeout-pattern** | Fix bot not responding in Vercel/Cloudflare Worker |
| **multi-layer-proxy-timeout-chain-debugging** | Debug 502/504 in CDN → reverse proxy → app → external API chains |
| **websocket-relay-stability-pattern** | Fix WebSocket disconnecting every ~120 seconds through proxies |
| **elizaos-pglite-migration-timing-fix** | Fix ElizaOS "relation 'agents' does not exist" |

## 💰 Billing & Token Economics

| Skill | What it does |
|-------|-------------|
| **token-economics-audit-methodology** | Red team audit for token economy: find exploits before users do |
| **platform-favorable-rounding** | Financial rounding strategy: ceil charges, floor payouts |
| **game-economy-dynamic-parameterization** | Convert hardcoded economy constants to admin-configurable params |
| **supply-side-honeymoon-incentive** | Incentivize new contributors in API sharing pools |
| **community-product-ghost-town-fix** | Fix the ghost town problem before beta launch |

## 🧪 Testing & QA

| Skill | What it does |
|-------|-------------|
| **parallel-quality-audit-workflow** | Multi-agent parallel QA for large frontend projects |
| **playwright-anti-ai-detection-bypass** | Bypass anti-bot detection with Playwright headless browser |
| **batch-processing-output-architecture** | Output file architecture for batch processing: sidecar + master DB + ledger |

## 🔍 Scraping & Data

| Skill | What it does |
|-------|-------------|
| **apify-actor-intelligence** | Top 200 Apify Actors tested — 27 pitfalls, 83 correct inputs documented |
| **youtube-search-language-localization** | Search language determines content perspective (tourist vs local) |
| **telegram-bot-conversation-history-debugging** | Debug Telegram Bot session storage, history, and monitoring |

## 📊 Business & Market Research

| Skill | What it does |
|-------|-------------|
| **pet-ai-comprehensive** | Complete pet AI social network design framework |
| **pet-veterinary-ai-market** | Pet veterinary AI market analysis (Japan + global) |
| **ai-agent-crypto-animal-welfare** | AI Agent + Blockchain for animal welfare strategy |
| **japan-concert-ticket-proxy-industry** | Japan concert ticket proxy industry competitive analysis |
| **erc8004-blockchain-identity** | ERC-8004 blockchain identity for animals, people, and AI agents |

---

## Also From Us

| Project | What it does | Stars |
|---------|-------------|-------|
| [**infinite-gratitude**](https://github.com/sstklen/infinite-gratitude) | 10 parallel research agents for Claude Code | ![Stars](https://img.shields.io/github/stars/sstklen/infinite-gratitude?style=social) |
| [**claude-api-cost-optimization**](https://github.com/sstklen/claude-api-cost-optimization) | Save 50-90% on Claude API costs | ![Stars](https://img.shields.io/github/stars/sstklen/claude-api-cost-optimization?style=social) |
| [**aeo-page**](https://github.com/sstklen/aeo-page) | Make AI recommend your business (AEO scanner) | ![Stars](https://img.shields.io/github/stars/sstklen/aeo-page?style=social) |
| [**washin-api-benchmark**](https://github.com/sstklen/washin-api-benchmark) | 30+ AI APIs tested monthly from Tokyo | ![Stars](https://img.shields.io/github/stars/sstklen/washin-api-benchmark?style=social) |
| [**yanhui-ci**](https://github.com/sstklen/yanhui-ci) | CI debug AI with shared knowledge base | ![Stars](https://img.shields.io/github/stars/sstklen/yanhui-ci?style=social) |

---

## Project Management Skills

These help you manage your skills and projects:

| Skill | What it does |
|-------|-------------|
| **auto-tidy** | Say "goodnight" → project auto-organizes |
| **project-index** | Auto-generate PROJECT_INDEX.json — AI finds files in 2 seconds |
| **techdebt** | Auto-detect and clean technical debt |
| **systematic-debug** | Systematic debugging workflow |
| **skill-format-standard** | Official Claude Code Skill format spec |
| **skill-library-lifecycle-management** | Manage 100+ skills: merge, archive, optimize |

---

<p align="center">
  <sub>
    Built at <a href="https://washinmura.jp">Washin Village</a> — 28 cats & dogs in rural Japan, building AI tools with zero engineers.
  </sub>
</p>
