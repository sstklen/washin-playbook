---
name: platform-favorable-rounding
description: |
  Financial rounding strategy for API billing / token economy / marketplace systems:
  ceil for charges (platform collects more), floor for refunds/payouts (platform pays less).
  Use when: (1) building pay-per-call API proxy with charge+refund flows,
  (2) designing token economy with mint/burn/earn/spend operations,
  (3) any billing system where IEEE 754 floating point can cause micro-discrepancies,
  (4) roundUSD / roundWT helper functions need directional variants.
  Covers USDC, internal tokens (WT), contributor rewards, and referral bonuses.
  See also: pre-deduct-phantom-refund-prevention (scope-level billing bugs).
author: Claude Code
version: 1.0.0
date: 2026-02-13
---

# Platform-Favorable Rounding — 收款進位、退款捨去

## Problem

In billing systems with floating-point currency (USDC, internal tokens), using symmetric
rounding (`Math.round`) means the platform sometimes loses fractions of a cent on every
transaction. Over millions of transactions, these micro-losses compound. More importantly,
having a single `roundUSD()` function applied everywhere obscures the business intent of
each operation.

## Context / Trigger Conditions

- Building an API marketplace / proxy with pre-deduct billing
- Token economy with mint, burn, earn, spend operations
- Any system where money flows in two directions (charge vs refund, earn vs spend)
- Current code uses a single `roundUSD()` / `roundWT()` for all operations
- Business owner says "平台永遠不吃虧" (platform never loses)

## Solution

### 1. Define Three Rounding Functions

```typescript
// 6-decimal precision for USDC (micro-USDC granularity)
const PRECISION = 1_000_000;

/** Neutral — balance display, reporting */
function roundUSD(n: number): number {
  return Math.round(n * PRECISION) / PRECISION;
}

/** Platform collects — charges, fees, burns */
function roundUSDCeil(n: number): number {
  return Math.ceil(n * PRECISION) / PRECISION;
}

/** Platform pays out — refunds, rewards, minting */
function roundUSDFloor(n: number): number {
  return Math.floor(n * PRECISION) / PRECISION;
}
```

For internal tokens (e.g., WT with 2-decimal precision):
```typescript
const WT_PRECISION = 100;

function roundWT(n: number): number { return Math.round(n * WT_PRECISION) / WT_PRECISION; }
function roundWTCeil(n: number): number { return Math.ceil(n * WT_PRECISION) / WT_PRECISION; }
function roundWTFloor(n: number): number { return Math.floor(n * WT_PRECISION) / WT_PRECISION; }
```

### 2. Apply by Money Flow Direction

| Scenario | Direction | Function | Rationale |
|----------|-----------|----------|-----------|
| **User pays for API call** | User → Platform | `roundUSDCeil` | Charge slightly more |
| **Refund on API failure** | Platform → User | `roundUSDFloor` | Refund slightly less |
| **User spends tokens** | User → Platform | `roundWTCeil` | Burn slightly more |
| **Token refund** | Platform → User | `roundWTFloor` | Refund slightly less |
| **Contributor reward** | Platform → User | `roundUSDFloor` | Pay out slightly less |
| **Referral bonus** | Platform → User | `roundWTFloor` | Mint slightly less |
| **Platform fee** | User → Platform | `roundWTCeil` | Collect slightly more |
| **Balance display** | N/A | `roundUSD` / `roundWT` | Neutral (informational) |

### 3. Decision Rule (Simple)

```
Money flows INTO platform  → Ceil  (collect more)
Money flows OUT of platform → Floor (pay less)
Just displaying numbers     → Round (neutral)
```

## Verification

1. Run E2E tests to ensure charge/refund flows still balance correctly
2. Verify with fixed-price APIs (e.g., $0.008/call) — ceil/floor have no effect on clean numbers
3. Test with dynamic pricing (e.g., per-token billing) to see the rounding in action
4. Check that `balance display = initial - sum(charges) + sum(refunds)` holds within tolerance

## Example

Before (single function):
```typescript
// billing.ts — charge
account.balance = roundUSD(account.balance - price);
account.totalSpent = roundUSD(account.totalSpent + price);

// billing.ts — refund
account.balance = roundUSD(account.balance + price);
account.totalSpent = roundUSD(account.totalSpent - price);
```

After (directional):
```typescript
// billing.ts — charge (platform collects → ceil)
account.balance = roundUSD(account.balance - roundUSDCeil(price));
account.totalSpent = roundUSD(account.totalSpent + roundUSDCeil(price));

// billing.ts — refund (platform pays → floor)
account.balance = roundUSD(account.balance + roundUSDFloor(price));
account.totalSpent = roundUSD(account.totalSpent - roundUSDFloor(price));
```

## Notes

- **Fixed prices unaffected**: If all your prices are clean decimals ($0.008, $0.015),
  ceil/floor produce the same result as round. The protection kicks in with dynamic
  pricing (per-token, percentage-based fees, multiplied rewards).
- **Outer roundUSD still needed**: The outer `roundUSD()` on balance is neutral and
  prevents accumulation drift from repeated additions/subtractions.
- **Don't apply twice**: Round the `price` with ceil/floor, then wrap the final
  balance update with neutral `roundUSD`. Don't ceil the entire expression.
- **Comments are documentation**: Add a comment like `// 收款用 ceil（多收，保護平台）`
  at each call site so future developers understand the business intent.
- **E2E test impact**: If tests assert exact balances after charge+refund cycles,
  they may need tolerance (`Math.abs(actual - expected) < 0.001`) since ceil charge +
  floor refund ≠ original amount when dynamic pricing is involved.

## See Also

- `pre-deduct-phantom-refund-prevention` — Prevents refunding when no charge was made
- `token-economics-audit-methodology` — Broader token economy security audit
