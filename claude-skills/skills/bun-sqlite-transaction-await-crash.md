---
name: bun-sqlite-transaction-await-crash
description: |
  Fix production crash caused by using `await` inside Bun SQLite `db.transaction()` callback.
  Use when: (1) Bun server crashes on startup with '"await" can only be used inside an "async" function',
  (2) adding async operations (dynamic import, fetch, API call) inside db.transaction() callback,
  (3) container crash-loops after deploy with bun:sqlite transaction code,
  (4) need to call async function after a synchronous SQLite transaction completes.
  Root cause: db.transaction() returns a synchronous wrapper function — its callback CANNOT be async.
  Covers: bun:sqlite, db.transaction(), dynamic import(), production crash prevention.
author: Claude Code
version: 1.0.0
date: 2026-02-16
---

# Bun SQLite Transaction Await Crash

## Problem

Placing `await` (or any async operation) inside a `db.transaction()` callback in Bun's
`bun:sqlite` causes a **fatal compilation error** that crashes the entire server on startup.
The error is:

```
"await" can only be used inside an "async" function
```

This is particularly dangerous because:
1. The error occurs at **module load time**, not at runtime
2. The entire server fails to start (503 for all requests)
3. Container enters a crash-loop, requiring a hotfix + redeploy
4. It passes TypeScript type checking (no compile-time warning)

## Context / Trigger Conditions

- Using `bun:sqlite` with `db.transaction()`
- Adding `await import('./module')` inside the transaction callback
- Adding `await fetch()` or any async call inside the transaction callback
- Deploying to production (Docker container) after local development
- Error message: `"await" can only be used inside an "async" function" at [file]:[line]`

**Why it's tricky:**
- `db.transaction()` accepts a callback, and you might think marking it `async` fixes it
- But `db.transaction()` calls the callback **synchronously** — it doesn't await Promises
- Making the callback `async` means the transaction commits before async work finishes
- Bun's bundler/runtime catches the `await` in non-async context and throws a fatal error

## Solution

### The Wrong Way (causes crash)

```typescript
// CRASH! await inside synchronous transaction callback
const txn = db.transaction(() => {
  db.run('INSERT INTO users ...', [name, email]);

  // Fatal error: "await" can only be used inside an "async" function
  const { doSomething } = await import('./other-module');
  doSomething(userId);
});
txn();
```

### Also Wrong (transaction commits before async work)

```typescript
// NO CRASH but WRONG: transaction commits immediately, async work happens later
const txn = db.transaction(async () => {  // async callback
  db.run('INSERT INTO users ...', [name, email]);

  // This runs AFTER the transaction has already committed
  // If this fails, the INSERT is already permanent (no rollback)
  const { doSomething } = await import('./other-module');
  doSomething(userId);
});
txn();  // Transaction commits synchronously, Promise is ignored
```

### The Correct Way (async work AFTER transaction)

```typescript
// Step 1: Run the synchronous transaction
const txn = db.transaction(() => {
  db.run('INSERT INTO users ...', [name, email]);
  // Only synchronous DB operations here
});
txn();

// Step 2: Do async work AFTER the transaction completes
try {
  const { doSomething } = await import('./other-module');
  doSomething(userId);
} catch (err) {
  // Non-critical: log but don't fail the main operation
  console.warn(`Async post-processing failed: ${err}`);
}
```

### Pattern: Transaction + Post-Transaction Async

```typescript
// Common pattern in Hono/Express route handlers
app.post('/register', async (c) => {
  const { name, email } = await c.req.json();

  // Phase 1: Synchronous transaction (atomic DB operations)
  let userId: number;
  const register = db.transaction(() => {
    const result = db.run('INSERT INTO users (name, email) VALUES (?, ?)', [name, email]);
    userId = Number(result.lastInsertRowid);
    db.run('INSERT INTO user_settings (user_id) VALUES (?)', [userId]);
  });
  register();

  // Phase 2: Async post-processing (non-atomic, can fail independently)
  try {
    const { sendWelcomeEmail } = await import('./email-service');
    await sendWelcomeEmail(email, name);
  } catch (err) {
    // Email failure shouldn't roll back user registration
    log.warn(`Welcome email failed for user ${userId}: ${err}`);
  }

  return c.json({ success: true, userId });
});
```

## Verification

1. Server starts without errors: `bun run src/server.ts`
2. The transaction's DB operations are atomic (all succeed or all fail)
3. Async operations run after the transaction commits
4. If async operations fail, the transaction's changes persist (intended behavior)
5. Health check returns 200: `curl http://localhost:3000/health`

## Real-World Example

**The incident (2026-02-16, production-api):**

After adding invite code auto-registration, `await import('./key-store')` was placed
inside `db.transaction()` in `oauth.ts`. The code passed local testing (unclear why),
but on VPS deploy the container crash-looped with:

```
"await" can only be used inside an "async" function" at oauth.ts:981
```

**The fix:** Move the `await import()` and `autoRegisterContributor()` call outside
the transaction, after `txn()` completes:

```typescript
// Before (CRASH):
const txn = db.transaction(() => {
  db.run('UPDATE invite_codes SET ...', [...]);
  const { autoRegisterContributor } = await import('./key-store');  // BOOM!
  autoRegisterContributor(uid, name, email);
});
txn();

// After (FIXED):
const txn = db.transaction(() => {
  db.run('UPDATE invite_codes SET ...', [...]);
});
txn();

// Async work outside transaction
try {
  const { autoRegisterContributor } = await import('./key-store');
  autoRegisterContributor(uid, name, email);
} catch (regErr) {
  log.warn(`Auto-registration failed (login still works): ${regErr}`);
}
```

## Prevention Checklist

Before deploying code with `db.transaction()`:

- [ ] No `await` keyword inside the transaction callback
- [ ] No `async` keyword on the transaction callback
- [ ] No dynamic `import()` inside the transaction
- [ ] All async operations are placed AFTER `txn()` call
- [ ] Async failures are wrapped in try-catch (non-critical path)

## Mental Model

```
db.transaction(() => {
  // SYNCHRONOUS ZONE - only db.run(), db.query(), variables
  // Think of this as a "frozen moment" - no I/O, no network, no imports
})

// ASYNC ZONE - free to await, import, fetch, etc.
// Transaction is already committed at this point
```

## Notes

- This applies to `bun:sqlite` specifically; other SQLite drivers (better-sqlite3) have the same constraint
- TypeScript does NOT catch this error — there's no type-level enforcement
- The error happens at Bun's module load/parse time, not at the transaction call site
- In the `bun-async-race-condition-pattern` skill, Rule 3 shows the correct pattern for
  re-checking inside transactions — those are fine because they're purely synchronous DB ops
- See also: `bun-async-race-condition-pattern` for race condition patterns with transactions
- See also: `hono-503-sqlite-fk-constraint` for other misleading SQLite errors in Hono
