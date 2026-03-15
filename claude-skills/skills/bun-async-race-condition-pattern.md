---
name: bun-async-race-condition-pattern
description: |
  Identify and fix race conditions in Bun/Node.js single-threaded async handlers.
  Use when: (1) auditing async request handlers for race conditions, (2) sub-agents
  report "race condition" bugs and you need to verify real vs false, (3) pattern
  "SELECT check → await external API → INSERT/UPDATE" exists in code, (4) daily
  limits, idempotency checks, or duplicate prevention relies on pre-async checks.
  Covers: Bun event loop yield points, sync vs async handler safety, db.transaction()
  re-check pattern, WHATWG URL parser normalization for SSRF guards.
author: Claude Code
version: 1.0.0
date: 2026-02-15
---

# Bun/Node.js Async Race Condition Pattern

## Problem

In Bun's single-threaded runtime, audit agents frequently report "race conditions"
in request handlers. ~90% of these are **false positives** because synchronous code
cannot interleave in a single-threaded event loop. However, `await` expressions
create real yield points where other requests CAN execute, making "check → await →
write" patterns genuinely vulnerable.

The challenge: knowing which race condition reports are real and which are false.

## Context / Trigger Conditions

- Bun or Node.js server with async request handlers
- Code pattern: `SELECT check → await externalAPI() → db.transaction(write)`
- Sub-agent audit reports claiming "race condition" or "TOCTOU" bugs
- Features with daily limits, idempotency checks, or duplicate prevention
- Any handler where a condition is checked BEFORE an `await`, then acted upon AFTER

## Solution

### Rule 1: Sync handlers are SAFE

```typescript
// SAFE — No await, no yield point, runs atomically
app.post('/water', (c) => {           // ← No async!
  const existing = db.query(...).get(userId, today);  // sync
  if (existing) return c.json({ error: 'already done' });

  const doWater = db.transaction(() => {
    db.run('INSERT INTO daily_activities ...', [userId, today]);
  });
  doWater();  // runs immediately, no interleaving possible
  return c.json({ success: true });
});
```

**Why safe:** Bun's event loop processes one microtask at a time. Without `await`,
the entire handler runs to completion before any other request starts.

### Rule 2: Async handlers with `await` between check and write are VULNERABLE

```typescript
// VULNERABLE — await creates yield point between check and write
app.post('/fortune', async (c) => {   // ← async!
  const count = db.query('SELECT COUNT(*)...').get(userId, today);
  if (count >= limit) return c.json({ error: 'limit reached' });

  // ⚠️ YIELD POINT — other requests execute here!
  const fortune = await generateFortune(animal, rank);

  // By the time we get here, another request may have already inserted
  const draw = db.transaction(() => {
    db.run('INSERT INTO fortune_records ...', [...]);  // count is now stale!
  });
  draw();
});
```

**Attack timeline:**
```
Request A: check count=1 (< limit 2) ✓
Request B: check count=1 (< limit 2) ✓  ← same stale value!
Request A: await generateFortune()... yields
Request B: await generateFortune()... yields
Request A: INSERT (count becomes 2) ✓
Request B: INSERT (count becomes 3) ← EXCEEDS LIMIT!
```

### Rule 3: Fix with re-check inside transaction

```typescript
app.post('/fortune', async (c) => {
  // Quick pre-check (still useful for fast rejection)
  const count = db.query('SELECT COUNT(*)...').get(userId, today);
  if (count >= limit) return c.json({ error: 'limit reached' });

  const fortune = await generateFortune(animal, rank);  // yield point

  let limitExceeded = false;
  const draw = db.transaction(() => {
    // 🛡️ RE-CHECK inside transaction (sees latest data)
    const recheck = db.query('SELECT COUNT(*)...').get(userId, today);
    if ((recheck?.cnt ?? 0) >= limit) {
      limitExceeded = true;
      return;  // abort transaction
    }
    db.run('INSERT INTO fortune_records ...', [...]);
  });
  draw();

  if (limitExceeded) {
    return c.json({ error: 'limit reached' }, 400);
  }
});
```

**Why this works:** SQLite transactions in Bun are synchronous. Once `db.transaction()`
starts, no other JavaScript can execute until it commits/rolls back.

### Rule 4: UNIQUE constraints as safety nets

If a table has a UNIQUE constraint, concurrent INSERTs to the same key will cause
one to fail with `UNIQUE constraint failed`. This prevents double-execution but
results in unhandled 500 errors unless caught:

```typescript
// weather_results has UNIQUE(target_date) — second settlement crashes but no double-pay
// This is "safe but ugly" — add explicit duplicate check for clean error handling
```

### Bonus: WHATWG URL Parser Normalizes Octal/Hex IPs

When auditing SSRF guards, agents often report "octal IP bypass" (e.g., `0177.0.0.1`).
This is a false positive in modern runtimes:

```typescript
new URL('http://0177.0.0.1/').hostname  // → '127.0.0.1' (normalized!)
new URL('http://0x7f000001/').hostname  // → '127.0.0.1' (normalized!)
```

The WHATWG URL Standard (used by Bun, Node.js, browsers) resolves octal/hex BEFORE
your code sees `url.hostname`. So SSRF guards checking the resolved hostname are safe.

## Verification

To verify a reported race condition is real:

1. **Check if handler is sync or async** — sync = safe, async = investigate
2. **Find the yield points** — look for `await` between condition check and state mutation
3. **Check for UNIQUE constraints** — they provide a safety net (but with ugly errors)
4. **Test with concurrent requests:**
   ```bash
   # Fire 5 simultaneous requests
   for i in {1..5}; do curl -X POST http://localhost:3000/fortune -d '...' & done; wait
   ```

## Example: Auditing a Codebase

When a sub-agent reports "10 race conditions found":

| Pattern | Verdict | Why |
|---------|---------|-----|
| sync handler, no await | ❌ FALSE | Single-threaded, no yield |
| async but check+write in same transaction | ❌ FALSE | Transaction is atomic |
| check → await API → write | ✅ REAL | Yield between check and write |
| check → await → write with UNIQUE constraint | ⚠️ SAFE but crashes | Constraint prevents damage |

Typical result: 1-2 real bugs out of 10 reported. ~80-90% false positive rate.

## Notes

- This applies to **Bun AND Node.js** — both are single-threaded event loops
- `db.transaction()` in bun:sqlite is synchronous — it's the safest place for checks
- The "pre-check + re-check" pattern wastes the API call on the losing request,
  but this is acceptable (alternative: put API call inside transaction, making it slow)
- Redis/external databases may behave differently (network I/O between check and write)
- See also: `audit-inflation-bias-prevention` skill for general audit false positive prevention
- See also: `pre-deduct-phantom-refund-prevention` skill for billing-specific patterns
- See also: `bun-sqlite-transaction-await-crash` — if you put `await` inside `db.transaction()`, the server crashes on startup (different from race conditions)

## References

- [Bun SQLite documentation](https://bun.sh/docs/api/sqlite)
- [WHATWG URL Standard — IPv4 parsing](https://url.spec.whatwg.org/#concept-ipv4-parser)
- [Node.js Event Loop](https://nodejs.org/en/learn/asynchronous-work/event-loop-timers-and-nexttick)
