---
name: hono-503-sqlite-fk-constraint
description: |
  Fix misleading 503 "Service Unavailable" errors in Hono when the actual root cause is
  SQLite FOREIGN KEY constraint failed. Use when: (1) POST/PATCH endpoint returns 503 instead
  of expected JSON, (2) GET endpoints on the same route prefix work fine but POST/PATCH fails,
  (3) server log shows "FOREIGN KEY constraint failed" in app.onError handler,
  (4) admin/system endpoints that create records with hardcoded user IDs (like creatorUserId=1).
  Common in API systems with SQLite FK constraints + Hono onError catch-all.
version: 1.0.0
date: 2026-02-13
---

# Hono 503 ← SQLite FOREIGN KEY Constraint

## Problem
A Hono POST endpoint returns `503 Service Unavailable` with a misleading message like
"All engines are temporarily unavailable", when the actual error is a SQLite
`FOREIGN KEY constraint failed` thrown inside the route handler.

## Context / Trigger Conditions
- POST or PATCH endpoint returns 503, but GET endpoints on the same route prefix work fine
- The 503 response body contains generic error messages from `app.onError()` handler
- Server logs show: `Unhandled error: FOREIGN KEY constraint failed`
- The route handler INSERTs a record with a foreign key reference (e.g., `inviter_id` → `users.id`)
- The referenced record doesn't exist (e.g., hardcoded `userId = 1` but no user with `id = 1`)
- Common scenario: admin endpoints that assume a "system user" exists

## Why It's Misleading
1. The `app.onError()` catch-all returns 503 with a generic message
2. The 503 + "engines unavailable" message makes you think it's a route collision or gateway issue
3. GET endpoints work because they only SELECT (no FK constraint checks)
4. curl with `-sf` flag hides the response body, making diagnosis harder

## Solution

### Step 1: Check server logs (not just HTTP response)
```bash
# Start server with visible logs
API_PORT=3009 bun run src/api/http-server.ts 2>&1 | tee /tmp/server.log &
# Make the failing request
curl -v -X POST http://localhost:3009/your/endpoint ...
# Check for the real error
grep -i 'error\|FOREIGN\|constraint' /tmp/server.log
```

### Step 2: Add FK existence check before INSERT
```typescript
// Before INSERT, verify the FK reference exists
const user = db.query<{ id: number }, [number]>(
  'SELECT id FROM users WHERE id = ?'
).get(creatorUserId);

if (!user) {
  // Fallback to first available user, or return clear error
  const firstUser = db.query<{ id: number }, []>(
    'SELECT id FROM users ORDER BY id ASC LIMIT 1'
  ).get();
  if (!firstUser) {
    return { success: false, error: 'No users exist yet. Login first.' };
  }
  creatorUserId = firstUser.id;
}
```

### Step 3: Wrap DB operations in try-catch
```typescript
try {
  db.run(`INSERT INTO table (...) VALUES (...)`, [params]);
} catch (err) {
  const msg = err instanceof Error ? err.message : String(err);
  return { success: false, error: `DB error: ${msg}` };
}
```

## Verification
1. The endpoint now returns 400 with a descriptive error instead of 503
2. When a valid FK reference exists, the endpoint returns 200 with success
3. Server logs show no more `Unhandled error` entries

## Notes
- This pattern applies to ANY web framework with a global error handler + SQLite FK constraints
- SQLite FK constraints are enforced by default in Bun's `bun:sqlite`
- In development, DB tables may be empty (no users), but production usually has data — test both!
- Always use `curl -v` (not `-sf`) when debugging 5xx errors to see the full response
- See also: `pre-deduct-phantom-refund-prevention` skill for related DB error patterns
