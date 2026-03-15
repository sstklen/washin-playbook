---
name: pre-deduct-phantom-refund-prevention
description: |
  Prevent "phantom refund" bugs in pre-deduct billing systems where try/catch scope
  covers both validation AND payment, causing refund() to fire when no charge was made.
  Use when:
  (1) Building API proxy/marketplace with pre-deduct-then-call-upstream billing pattern,
  (2) try/catch block wraps both input validation and preCharge() in a single scope,
  (3) User balance increases without legitimate deposit (audit anomaly),
  (4) Refund fires on validation errors (400) that never reached payment step,
  (5) Error in sanitize/validate throws exception before preCharge() but catch always refunds.
  Covers: charged flag pattern, try/catch scope analysis for billing, refund guard conditions.
version: 1.0.0
date: 2026-02-12
author: Claude Code
---

# Pre-Deduct Phantom Refund Prevention

## Problem

In pre-deduct billing systems ("charge first, call upstream, refund on failure"), a common
bug occurs when the try/catch block scope is too wide: if an error happens BEFORE the
charge step (e.g., during input validation or sanitization), the catch block still calls
`refund()`, crediting money that was never debited. This allows users to inflate their
balance without depositing.

## Context / Trigger Conditions

- **Architecture**: Pre-deduct billing (preCharge → call upstream → refund on failure)
- **Symptom**: User balance increases without any deposit transaction
- **Audit signal**: Transaction log shows `refund` entries without corresponding `charge`
- **Code pattern**: Single try/catch wrapping validation + payment + execution
- **Risk level**: HIGH — attackable by crafting inputs that fail validation

Typical vulnerable code structure:
```typescript
try {
  validate(input);         // ← Can throw
  sanitize(input);         // ← Can throw
  const charge = preCharge(apiKey, price);  // ← Money deducted HERE
  const result = await callUpstream();      // ← Can throw
  return result;
} catch (err) {
  refund(apiKey, price);   // ← ALWAYS refunds, even if preCharge never ran!
}
```

## Solution

### Pattern: Charged Flag Guard

Add a boolean flag outside the try block that's only set to `true` after preCharge succeeds:

```typescript
let charged = false;  // Declare OUTSIDE try block

try {
  validate(input);
  sanitize(input);

  const charge = preCharge(apiKey, serviceId, price);
  if (!charge.success) {
    return errorResponse(charge.error, charge.statusCode);
  }
  charged = true;  // Only set AFTER successful preCharge

  const result = await callUpstream();
  return successResponse(result);

} catch (err) {
  // Only refund if we actually charged
  if (charged) {
    refund(apiKey, 'error-refund', serviceId, price);
  }

  return errorResponse('Service unavailable', {
    refunded: charged,  // Honest: tell user if refund actually happened
  });
}
```

### Key Rules

1. **`charged` flag declared BEFORE try** — survives into catch scope
2. **Set `charged = true` AFTER preCharge succeeds** — not before, not on the same line
3. **Guard ALL refund calls** — including nested try/catch in error handlers
4. **`refunded` response field matches `charged`** — don't tell users "refunded" when nothing was charged

### Alternative: Split Try Blocks

For complex handlers, split into two try blocks:

```typescript
// Phase 1: Validation (no financial ops)
let apiKey: string;
let sanitizedInput: string;
try {
  apiKey = extractApiKey(c);
  sanitizedInput = sanitize(input);
} catch (err) {
  return errorResponse('Invalid input');  // No refund needed
}

// Phase 2: Billing + Execution (financial ops)
try {
  const charge = preCharge(apiKey, price);
  const result = await callUpstream();
  return successResponse(result);
} catch (err) {
  refund(apiKey, price);  // Safe: preCharge was always reached in this block
  return errorResponse('Service unavailable', { refunded: true });
}
```

## Verification

After applying the fix:

1. **Unit test**: Send request with input that fails sanitization → verify balance unchanged
2. **Audit log check**: `grep 'refund' transactions.json` — every refund should have a matching charge
3. **Balance invariant**: `balance + totalSpent === totalDeposited` should always hold
4. **E2E test**: Run full test suite to verify no regressions

## Example: Real-World Fix (production-api)

**Before (vulnerable):**
```typescript
gateway.post('/search', async (c) => {
  try {
    const { query } = await c.req.json();
    const sanitizedQuery = sanitizeQuery(query);  // Can throw!
    const apiKey = extractApiKey(c);
    const charge = preCharge(apiKey, 'smart-search', 0.015);
    // ... execute search ...
  } catch (err) {
    const apiKey = extractApiKey(c);
    refund(apiKey, 'error-refund', 'smart-search', 0.015);  // Phantom refund!
  }
});
```

**After (fixed):**
```typescript
gateway.post('/search', async (c) => {
  let charged = false;
  try {
    const { query } = await c.req.json();
    const sanitizedQuery = sanitizeQuery(query);
    const apiKey = extractApiKey(c);
    const charge = preCharge(apiKey, 'smart-search', 0.015);
    if (!charge.success) return c.json({ error: charge.error }, 402);
    charged = true;  // Safe to refund from here on
    // ... execute search ...
  } catch (err) {
    if (charged) {
      const apiKey = extractApiKey(c);
      refund(apiKey, 'error-refund', 'smart-search', 0.015);
    }
    return c.json({ error: 'Service unavailable', refunded: charged }, 500);
  }
});
```

**Result**: 3 L2 endpoints fixed, 33/34 E2E tests passed, phantom refund eliminated.

## Notes

- **Single-threaded safety**: In Bun/Node.js (single event loop), preCharge is synchronous
  and atomic within a tick — no race condition between check and deduct. The phantom refund
  is a scope issue, not a concurrency issue.
- **Layer 1 (proxy middleware) is NOT vulnerable**: The proxy middleware sets `chargeId` in
  Hono context, and `autoRefund()` checks `chargeId !== 'free'` before refunding. The L2
  endpoints do their own billing without this middleware protection.
- **Detection**: Search for `refund` calls inside catch blocks, then trace backward to see
  if preCharge is guaranteed to have run before the catch is reachable.
- **Related concern**: Also check that `refunded: true` in error responses is honest — users
  making decisions based on false refund confirmations could retry and get double service.

## See Also

- `api-security-audit-methodology` — Systematic API security audit approach
- `api-proxy-quota-hardstop-pattern` — Quota management for API proxies
- `multi-provider-fallback-gateway` — Smart Gateway architecture with fallback chains
