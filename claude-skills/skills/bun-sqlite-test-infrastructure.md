---
name: bun-sqlite-test-infrastructure
description: |
  Complete test infrastructure pattern for Bun + SQLite projects using bun:test.
  Use when: (1) Setting up unit tests for a Bun app with bun:sqlite singleton DB,
  (2) Tests fail with "CHECK constraint failed" but the error points to wrong column,
  (3) Tests fail with "FOREIGN KEY constraint failed" for system/special user IDs,
  (4) In-memory Map caches return stale data between tests,
  (5) Same-millisecond INSERT ordering causes flaky test assertions.
  Covers: in-memory DB injection, singleton reset, Map cache clearing, CHECK constraint
  value discovery, FK constraint workarounds, timestamp ordering pitfalls, roundWT precision.
author: Claude Code
version: 1.0.0
date: 2026-02-18
---

# Bun SQLite Test Infrastructure

## Problem

Setting up reliable unit tests for a Bun + SQLite application requires solving multiple
non-obvious problems simultaneously:

1. **Singleton DB isolation**: Production code uses a singleton `getDb()` — tests need
   fresh in-memory DBs without modifying production code paths
2. **CHECK constraint mismatches**: Test data uses type values not in the schema's
   CHECK constraint, but the error message is misleading
3. **FK constraints for special IDs**: System accounts (e.g., `userId=0`) need actual
   rows in referenced tables when `PRAGMA foreign_keys = ON`
4. **Stale Map caches**: Modules with in-memory Map caches (e.g., `accountsByKey`)
   retain data from previous tests
5. **Timestamp ordering**: Records inserted in the same millisecond have identical
   timestamps, making positional assertions flaky

## Context / Trigger Conditions

- **Framework**: Bun runtime + `bun:sqlite` + `bun:test`
- **Architecture**: Singleton DB pattern (`let db: Database | null`) with `getDb()`
- **Error**: `SQLiteError: CHECK constraint failed` on INSERT to ledger/transaction tables
- **Error**: `SQLiteError: FOREIGN KEY constraint failed` when using system user ID = 0
- **Symptom**: Tests pass individually but fail when run together (stale cache)
- **Symptom**: Test assertions on array order are flaky (same-millisecond timestamps)

## Solution

### 1. In-Memory DB Injection Pattern

Export a `_setupTestDb()` function that replaces the singleton:

```typescript
// database.ts
let db: Database | null = null;

export function getDb(): Database {
  if (!db) {
    db = new Database(DB_PATH);
    initSchema(db);
  }
  return db;
}

// Test-only: inject fresh in-memory DB
export function _setupTestDb(): void {
  if (db) db.close();
  db = new Database(':memory:');
  initSchema(db);  // Runs all CREATE TABLE + migrations
}

export function closeDb(): void {
  if (db) { db.close(); db = null; }
}
```

### 2. Map Cache Reset Pattern

Modules with in-memory caches need explicit reset functions:

```typescript
// billing.ts
const accountsByKey = new Map<string, Account>();
const accountsById = new Map<string, Account>();

export function initCreditSystem(): void {
  accountsByKey.clear();  // CRITICAL: clear on re-init
  accountsById.clear();
  // ... reload from DB
}

// Explicit reset for tests
export function _resetCreditSystemForTest(): void {
  accountsByKey.clear();
  accountsById.clear();
}
```

### 3. Config Manager Reset

If you have a config-manager with an `initialized` flag:

```typescript
// config-manager.ts
let initialized = false;
let configCache: Map<string, any>;

export function _resetConfigForTest(): void {
  initialized = false;
  configCache = new Map();
}
```

### 4. Test Setup (beforeEach / afterAll)

```typescript
import { describe, it, expect, beforeEach, afterAll } from 'bun:test';
import { _setupTestDb, getDb, closeDb } from '../src/api/database';
import { _resetConfigForTest } from '../src/api/config-manager';

beforeEach(() => {
  _setupTestDb();           // Fresh in-memory DB for EVERY test
  _resetConfigForTest();    // Reset config cache
});

afterAll(() => {
  closeDb();
});
```

### 5. CHECK Constraint Value Discovery

When you get `CHECK constraint failed`, find valid values:

```sql
-- Find the CHECK constraint definition
SELECT sql FROM sqlite_master WHERE type='table' AND name='token_ledger';

-- Look for the CHECK clause, e.g.:
-- CHECK (type IN ('earn_welcome','earn_bonus','spend_api_call',...))
```

Then use ONLY valid values in tests:

```typescript
// BAD: made-up type values
writeLedger(userId, 'spend_api', -10, 'test');      // CHECK fails!
writeLedger(userId, 'earn_test', 20, 'test');        // CHECK fails!

// GOOD: exact CHECK constraint values
writeLedger(userId, 'spend_api_call', -10, 'test');  // OK
writeLedger(userId, 'earn_bonus', 20, 'test');       // OK
```

### 6. FK Constraint for System Users

If your system uses `userId=0` (or any special ID) that doesn't exist in `users` table:

```typescript
it('System account can go negative', () => {
  const db = getDb();
  // MUST insert user row first — FK constraint requires it
  // oauth_provider has its own CHECK constraint — use valid value!
  db.run(
    `INSERT INTO users (id, email, name, oauth_provider, oauth_id, token_balance)
     VALUES (0, 'system@example.com', 'System', 'google', 'system-0', 0)`
  );

  const balance = writeLedger(0, 'fee_platform', -100, 'system fee');
  expect(balance).toBe(-100);  // System accounts allow negative
});
```

### 7. Same-Millisecond Timestamp Ordering

Don't rely on positional array access for records with identical timestamps:

```typescript
// BAD: flaky — order undefined for same timestamp
const txs = getTransactions(userId);
expect(txs[0].amount).toBe(20);   // Might be the wrong tx!
expect(txs[1].amount).toBe(-5);

// GOOD: find by unique attribute
const txs = getTransactions(userId);
const earnTx = txs.find(t => t.type === 'earn_welcome')!;
const spendTx = txs.find(t => t.type === 'spend_api_call')!;
expect(earnTx.amount).toBe(20);
expect(spendTx.amount).toBe(-5);
```

### 8. Precision Awareness (roundWT)

If your system rounds to 2 decimal places:

```typescript
// roundWT(0.001) = Math.round(0.001 * 100) / 100 = 0
// So 0.001 WT is effectively 0!

// BAD:
writeLedger(userId, 'earn_bonus', 0.001, 'tiny');
expect(getBalance(userId)).toBe(0.001);  // FAILS! Balance is 0

// GOOD: minimum meaningful amount is 0.01
writeLedger(userId, 'earn_bonus', 0.01, 'minimum');
expect(getBalance(userId)).toBe(0.01);   // OK
```

## Verification

Run all tests and verify:

```bash
bun test tests/
# All tests should pass on every run (no flaky tests)
# Run 3 times to confirm no ordering issues
```

## Example

Complete test file structure for a financial module:

```typescript
import { describe, it, expect, beforeEach, afterAll } from 'bun:test';
import { _setupTestDb, getDb, closeDb } from '../src/api/database';
import { _resetConfigForTest } from '../src/api/config-manager';
import { writeLedger, getTokenBalance } from '../src/api/token-engine';

function createTestUser(opts?: { tokenBalance?: number }): number {
  const db = getDb();
  const email = `test-${Date.now()}-${Math.random().toString(36).slice(2)}@test.com`;
  db.run(
    `INSERT INTO users (email, name, oauth_provider, oauth_id, token_balance)
     VALUES (?, ?, 'google', ?, ?)`,
    [email, 'TestUser', `google-${Date.now()}`, opts?.tokenBalance ?? 0]
  );
  return db.query<{ id: number }, [string]>(
    'SELECT id FROM users WHERE email = ?'
  ).get(email)!.id;
}

beforeEach(() => {
  _setupTestDb();
  _resetConfigForTest();
});

afterAll(() => closeDb());

describe('writeLedger', () => {
  it('credit should increase balance', () => {
    const userId = createTestUser();
    const bal = writeLedger(userId, 'earn_welcome', 20, 'test');
    expect(bal).toBe(20);
    expect(getTokenBalance(userId)).toBe(20);
  });

  // ... more tests using ONLY valid CHECK constraint values
});
```

## Notes

- **Naming convention**: Prefix test-only exports with `_` (e.g., `_setupTestDb`) to
  signal they're not for production use
- **Performance**: `bun:sqlite` in-memory DB is extremely fast — no need to share DB
  between tests. Fresh DB per test eliminates all cross-test contamination
- **Multiple CHECK constraints**: A single table can have CHECK on multiple columns.
  When you get `CHECK constraint failed`, the error doesn't tell you WHICH column.
  Check ALL columns with CHECK constraints
- **Bun.write() is async**: Never use `Bun.write()` in sync functions — the Promise
  is silently dropped. Use `fs.copyFileSync()` / `fs.writeFileSync()` instead.
  (See also: `bun-async-race-condition-pattern`)

## References

- [Bun SQLite documentation](https://bun.sh/docs/api/sqlite)
- [Bun Test documentation](https://bun.sh/docs/test/writing)
- See also: `sqlite-check-constraint-migration` — migrating CHECK constraints in production
- See also: `bun-sqlite-transaction-await-crash` — await inside db.transaction() crash
- See also: `bun-async-race-condition-pattern` — async race conditions in Bun handlers
- See also: `platform-favorable-rounding` — ceil/floor rounding for financial systems
