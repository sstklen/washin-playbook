---
name: game-economy-dynamic-parameterization
description: |
  Systematically convert hardcoded game economy constants (costs, rewards, limits, shares)
  into admin-ui-configurable dynamic parameters with caching. Use when:
  (1) Game/token economy has hardcoded costs/rewards/limits scattered across modules,
  (2) Need admin to tune economy parameters without redeploying,
  (3) Preparing for beta launch where rapid parameter tuning is critical,
  (4) Multiple game modules share a config pattern but each has hardcoded values.
  Pattern: getter functions + central config defaults + admin whitelist + backward compat.
author: Claude Code
version: 1.0.0
date: 2026-02-14
---

# Game Economy Dynamic Parameterization

## Problem

Game/token economy systems start with hardcoded constants (`const BET_COST = 2`), but as
the system grows, operators need to tune parameters without redeploying. Converting
scattered constants across many modules into a unified dynamic config system is error-prone
if done without a systematic approach.

## Context / Trigger Conditions

- Multiple game modules (betting, fortune, daily activities) with hardcoded costs/rewards
- Admin panel exists but can't control game parameters
- Preparing for beta launch where rapid tuning is essential
- User says "make everything configurable" or "I need on/off switches for all features"

## Solution

### Step 1: Audit All Hardcoded Constants

Scan every game module for patterns like:
```typescript
const BET_COST = 2;          // hardcoded cost
const DAILY_LIMIT = 3;       // hardcoded limit
const POOL_SHARE = 0.70;     // hardcoded share ratio
const REWARD = 0.3;          // hardcoded reward amount
```

### Step 2: Register Defaults in Central Config Manager

Group by category with descriptive metadata:
```typescript
// config-manager.ts — Add to DEFAULTS
'game.weather_bet_cost': { value: '1', type: 'number', category: 'games', description: 'Weather bet cost (WT)' },
'game.crypto_bet_cost': { value: '2', type: 'number', category: 'games', description: 'Crypto prediction cost (WT)' },
'daily.bug_cost': { value: '2', type: 'number', category: 'daily', description: 'Bug removal cost (WT)' },
'neighbor.water_reward': { value: '0.3', type: 'number', category: 'neighbor', description: 'Water help reward (WT)' },
```

**Naming convention:** `{category}.{module}_{parameter}` — e.g., `game.fortune_daily_limit`

### Step 3: Use Getter Functions (NOT Module-Level Constants)

```typescript
// ❌ WRONG — reads once at module load, never updates
const BET_COST = getConfigNum('game.weather_bet_cost', 1);

// ✅ CORRECT — reads fresh from cache on each call
const getBetCost = () => getConfigNum('game.weather_bet_cost', 1);
const getPoolShare = () => getConfigNum('game.weather_pool_share', 0.70);
```

**Why getter functions?** Module-level `const` reads config once at import time.
Getter functions read from the cache on each call, so admin changes take effect
within the cache TTL (typically 60 seconds) without restart.

### Step 4: Replace All Usages

Use `replace_all` or search-and-replace carefully:
```typescript
// Before
if (balance < BET_COST) { ... }
writeLedger(userId, -BET_COST, ...);
return c.json({ cost: BET_COST });

// After
if (balance < getBetCost()) { ... }
writeLedger(userId, -getBetCost(), ...);
return c.json({ cost: getBetCost() });
```

**For complex objects (like BUFF_TYPES), use a factory function:**
```typescript
function getBuffTypes() {
  return {
    water: { bonus: getWaterBonus(), cost: 0, ... },
    bug: { bonus: getBugBonus(), cost: getBugCost(), ... },
  };
}
// Keep static version for TypeScript type definitions
const BUFF_TYPES = { ... } as const;
type BuffType = keyof typeof BUFF_TYPES;
```

### Step 5: Update Admin Panel Whitelist

```typescript
// admin-ui.ts — Expand allowed prefixes
const ALLOWED_PREFIXES = ['wt.', 'reward.', 'limit.', 'feature.', 'game.', 'daily.', 'neighbor.'];
```

### Step 6: Add New Feature Dimensions (Bonus!)

Parameterization is a good time to add features that were previously impossible:
```typescript
// Example: free daily fortune draws (impossible with hardcoded cost)
const getFreeDailyCount = () => getConfigNum('game.fortune_free_daily', 0);

// In the draw handler:
const isFree = todayCount < getFreeDailyCount();
const cost = isFree ? 0 : getFortuneCost();
if (!isFree && balance < cost) { return error('balance insufficient'); }
if (cost > 0) { writeLedger(...); }
```

### Step 7: Maintain Backward Compatibility

Export deprecated static constants for external consumers:
```typescript
/** @deprecated Use getProbationThreshold() instead */
export const PROBATION_SUCCESS_THRESHOLD = 10;
export const getProbationThreshold = () => getConfigNum('limit.probation_calls', 10);
```

## Verification

1. **Build check:** `bun build src/api/http-server.ts --target=bun` — no errors
2. **E2E tests:** All existing tests pass (auth checks, endpoint availability)
3. **Runtime test:** Start server → change config via admin API → verify new values take effect within cache TTL
4. **Fallback test:** Delete config row from DB → getter returns hardcoded fallback

## Example

**8-file parameterization completed in one session:**

| Module | Constants Converted | Config Keys |
|--------|-------------------|-------------|
| game-weather.ts | 4 (cost, pool/platform/fund shares) | `game.weather_*` |
| game-crypto.ts | 6 (cost, shares, window, daily limit) | `game.crypto_*` |
| game-fortune.ts | 3 (cost, daily limit, free count) | `game.fortune_*` |
| daily-activities.ts | 7 (bug cost, bonuses, 5 chest tiers) | `daily.*` |
| neighbor-system.ts | 2 (water/bug rewards) | `neighbor.*` |
| key-store.ts | 1 (probation threshold) | `limit.probation_calls` |
| config-manager.ts | 25+ new defaults registered | — |
| admin-ui.ts | Whitelist expanded | — |

## Notes

- **Cache TTL tradeoff:** Shorter = faster admin changes, longer = fewer DB reads.
  60 seconds is a good default for game economies (not real-time critical).
- **Don't parameterize everything:** Technical constants (timeouts, model names, buffer sizes)
  should stay hardcoded. Only parameterize business/economy values.
- **Feature flags are separate:** Use `isFeatureEnabled('game_xxx')` for on/off,
  `getConfigNum('game.xxx_cost', N)` for tunable values. Don't mix them.
- **Streak/tier rewards:** For tables like chest rewards (day 1→2 WT, day 3→3 WT, etc.),
  use individual config keys per tier (`daily.chest_day1`, `daily.chest_day3`, etc.)
  rather than trying to store a JSON table in config.

See also: `token-economics-audit-methodology`, `api-pool-token-pricing-methodology`
