---
name: api-pricing-single-source-of-truth
description: |
  Centralize ALL pricing, tiers, and costs into a single zero-dependency registry file,
  then wire every consumer to import from it. Use when:
  (1) changing a price requires editing 7+ files and 180+ hardcoded values,
  (2) balance endpoint shows different price than actual charge,
  (3) frontend tier classification reverse-engineers from price instead of using backend data,
  (4) admin panel can't override pricing at runtime without code deployment.
  Covers: registry architecture, dependency injection for config override, parallel agent
  execution strategy for large-scale refactoring, and admin-configurable runtime pricing.
author: Claude Code
version: 2.0.0
date: 2026-02-15
---

# API Pricing Single Source of Truth

## Problem

In API proxy/marketplace systems, pricing gets defined in multiple locations (7+ files,
180+ hardcoded values) that drift apart. Changing one price requires a multi-hour,
multi-agent operation touching every file, and bugs still slip through (wrong tier values,
stale prices in HTML templates, frontend logic breaking).

**The real cost:** A simple price change becomes a full engineering project.

## Context / Trigger Conditions

- `grep -rn "0.006" src/` finds the same price in 20+ locations
- Changing pricing requires editing 5+ files
- Frontend tier badges are derived from price ranges instead of backend tier field
- Admin panel has no way to adjust prices without code deployment
- `priceUSDC`, `pricePerCall`, `costPerCall`, tier labels all defined independently
- HTML template strings contain hardcoded `$0.006 USDC` values

## Architecture: Zero-Dependency Registry

### Core Design

```
service-registry.ts (ZERO imports from project files)
    |
    +---> api-proxy.ts    (priceUSDC from tier)
    +---> billing.ts        (SERVICE_TIERS generated from registry)
    +---> key-store.ts            (tier/price/cost from registry)
    +---> smart-concierge.ts      (TOOL_CATALOG.price from registry)
    +---> proxy-mcp-server.ts     (tool descriptions use formatPriceUSDC())
    +---> gateway.ts        (LAYER2_PRICING from registry)
    +---> http-server.ts          (HTML pricing tables dynamically generated)
    +---> docs-page.ts            (HTML pricing tables dynamically generated)
    +---> pool-status.ts          (import from registry)
    +---> admin-ui.ts          (import from registry)
    +---> config-manager.ts       (defines config keys, registry reads via DI)
```

### Registry File Structure

```typescript
// service-registry.ts - THE single source of truth
// ZERO imports from any project file!

// --- Static definitions (code defaults) ---
export const TIER_DEFINITIONS = [
  { tier: 0, name: 'Free',    badge: 'emoji', priceUSD: 0 },
  { tier: 1, name: 'Login',   badge: 'emoji', priceUSD: 0.002 },
  // ...T2-T5
];

export const SERVICE_REGISTRY: Record<string, ServiceDef> = {
  'groq':      { tier: 1, category: 'llm', costEstimate: 0, displayName: 'Groq' },
  'firecrawl': { tier: 3, category: 'scraping', costEstimate: 0.003 },
  // ...26 services
};

export const LAYER2_PRICING = { /* smart-search, smart-llm, smart-translate */ };
export const LAYER3_PRICING = { routingFee: 0.02, routingFeeWT: 5 };
export const CONTENT_PRICING = { animalPhoto: 0.05, animalStory: 0.02 };
export let WELCOME_BONUS_USDC = 0.25;  // `let` for runtime override!

// --- Helper functions ---
export function getTierPrice(tier: number): number;
export function getServicePrice(id: string): number;
export function getServiceTier(id: string): number;
export function getServiceCost(id: string): number;
export function formatPriceUSD(n: number): string;   // 0.006 -> "$0.006", 0 -> "FREE"
export function formatPriceUSDC(n: number): string;  // 0.006 -> "$0.006 USDC"
export function getTierLabel(id: string): string;     // "T3"
export function buildL1PricingData(): PricingRow[];   // sorted array for tables
export function buildL2PricingData(): PricingRow[];

// --- Runtime override (dependency injection!) ---
export function applyConfigOverrides(
  getNum: (key: string, fallback: number) => number
): void;
```

## Key Patterns

### 1. Dependency Injection for Config Override

**Problem:** Registry must have ZERO imports, but needs to read config-manager values.

**Solution:** Accept a getter function as parameter:

```typescript
// service-registry.ts - stays zero-dependency
export function applyConfigOverrides(
  getNum: (key: string, fallback: number) => number
): void {
  TIER_DEFINITIONS[0].priceUSD = getNum('wt.tier0_price', TIER_DEFINITIONS[0].priceUSD);
  TIER_DEFINITIONS[1].priceUSD = getNum('wt.tier1_price', TIER_DEFINITIONS[1].priceUSD);
  // ...each tier, L2, L3, content, welcome bonus
  WELCOME_BONUS_USDC = getNum('reward.welcome_credit_usdc', WELCOME_BONUS_USDC);
}

// http-server.ts - caller injects the dependency
import { applyConfigOverrides } from './service-registry';
import { getConfigNum } from './config-manager';
applyConfigOverrides(getConfigNum);  // at startup

// admin-ui.ts - dynamic refresh on config change
if (key.startsWith('wt.') || key.startsWith('reward.welcome_credit')) {
  const { applyConfigOverrides } = await import('./service-registry');
  applyConfigOverrides(getConfigNum);
}
```

### 2. `let` vs `const` for Runtime-Mutable Values

```typescript
export const TIER_DEFINITIONS = [...];  // const: array ref unchanged, contents mutable
export let WELCOME_BONUS_USDC = 0.25;  // let: entire value replaced at runtime
```

Use `let` when `applyConfigOverrides()` needs to reassign the value entirely.
Use `const` for objects/arrays where you mutate properties in-place.

### 3. Frontend Tier Classification from Backend Data

**WRONG (breaks when prices change):**
```javascript
// Reverse-engineers tier from price - fragile!
var tier = p.price === 0 ? "tier-free" : (p.price <= 0.002 ? "tier-1" : ...);
var tierLabel = p.price === 0 ? "T0" : (p.price <= 0.002 ? "T1" : ...);
```

**RIGHT (uses backend tier field directly):**
```javascript
// Backend sends tier number, frontend just uses it
var tier = p.tier === 0 ? "tier-free" : "tier-" + p.tier;
var tierLabel = p.tierName + " " + p.tierBadge;
```

Backend data array must include tier info:
```typescript
JSON.stringify(buildL1PricingData().map(r => ({
  id: r.id, price: r.price,
  tier: r.tier,           // <-- pass tier number
  tierBadge: r.tierBadge, // <-- pass badge
  tierName: r.tierName    // <-- pass name
})));
```

### 4. Config-Manager Integration for Admin Panel

Add config entries for every price the admin might change:

```typescript
// config-manager.ts
'wt.tier0_price': { value: '0', type: 'number', category: 'wt_economy', description: '...' },
'wt.tier1_price': { value: '0.002', type: 'number', category: 'wt_economy', description: '...' },
// ...tier2-5, L2 prices, L3 routing fee, content prices, welcome bonus
```

## Execution Strategy: 7-Phase Parallel Refactoring

For a system with 180+ hardcoded values across 11 files:

| Phase | What | Risk | Agent Strategy |
|-------|------|------|---------------|
| 1 | Create registry file | Zero (new file) | Single agent |
| 2 | Core data files (marketplace, credit, key-store, gateway) | Low | 4 parallel agents |
| 3 | Derived consumers (concierge, MCP server, pool, admin) | Low | 4 parallel agents |
| 4 | HTML templates (http-server, docs-page) | Medium (most changes) | 2 parallel agents |
| 5 | Scan remaining hardcoded values | Low | 4 parallel agents |
| 6 | "Intentionally kept" items (animal content, L3, welcome bonus, frontend tier fix) | Low | Single agent |
| 7 | Admin-configurable pricing (config-manager + DI) | Low | Single agent |

**Key principle:** Each agent gets ONE file. Never let two agents touch the same file.

**After each phase:** Run `bun build` to verify compilation.

## Verification

```bash
# 1. Compile check
bun build src/index.ts --no-bundle --target=bun

# 2. Scan for remaining hardcoded prices
grep -rn "0\.006\|0\.004\|0\.002" src/api/*.ts | grep -v service-registry | grep -v node_modules

# 3. Change one tier price in admin panel, verify all pages update:
#    /, /pricing, /docs, /mcp, /admin, /pool

# 4. Nuclear test: change T3 from 0.006 to 0.007 in service-registry.ts
#    → Every page, API response, and billing should reflect 0.007
#    → Then change back
```

## Real Case: API Platform System (2026-02-15)

**Before:** 180+ hardcoded values across 11 files. Price change = 7 files, 5 agents, hours of work, still had bugs.

**After:** 4 commits in one session:
- `94aa580` Phase 1-4: registry + full system integration (13 files, +1031/-611)
- `b764126` Phase 5: remaining hardcoded prices (5 files, +69/-65)
- `85b2a46` Phase 6: last 5 "intentionally kept" items (7 files, +76/-37)
- `201310a` Phase 7: all pricing admin-configurable (4 files, +109/-6)

**Now:** Change price = edit 1 config entry in admin panel. Zero deployment needed.

## Prevention Checklist

When adding pricing to a new system:

- [ ] Define ALL prices in ONE zero-dependency registry file
- [ ] All consumers `import` from registry, never define their own prices
- [ ] Use `buildPricingData()` helpers for HTML tables (never hardcode in templates)
- [ ] Frontend receives tier number from backend (never reverse-engineer from price)
- [ ] Config-manager has entries for every adjustable price
- [ ] `applyConfigOverrides()` uses dependency injection (no import of config-manager)
- [ ] Admin panel triggers registry refresh on config change
- [ ] Use `let` for values that need full reassignment at runtime
- [ ] Database merge/migration logic syncs prices from registry on startup

## Common Traps

| Trap | Symptom | Fix |
|------|---------|-----|
| Frontend price-based tier logic | Tier badges wrong after price change | Pass tier field from backend |
| `const` on mutable scalars | `applyConfigOverrides` silently fails | Use `let` |
| Optional chaining on required data | Fallback hides real bugs | Remove `?.` after confirming data exists |
| HTML template hardcoded prices | Template strings with `$0.006` | Use `formatPriceUSD()` interpolation |
| Parallel agents on same file | Merge conflicts | One agent per file, always |

## Notes

- `costEstimate` (upstream cost) is separate from `pricePerCall` (what we charge). Don't unify these.
- Free services (T0, $0) should always stay free regardless of config overrides.
- The three-layer pricing (L1 direct proxy, L2 smart gateway, L3 concierge) each have independent price structures but ALL live in the same registry.

## See Also

- `platform-favorable-rounding` - Rounding rules for charges vs refunds
- `api-platform-three-layer-architecture` - L1/L2/L3 pricing strategy
- `game-economy-dynamic-parameterization` - Similar pattern for game economy constants
