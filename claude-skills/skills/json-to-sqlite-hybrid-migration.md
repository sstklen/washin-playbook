---
name: json-to-sqlite-hybrid-migration
description: |
  Migrate Bun/Node.js server modules from JSON file persistence (with DebouncedWriter)
  or pure in-memory Maps/Sets to SQLite (bun:sqlite) while keeping in-memory data structures
  as hot caches. Use when:
  (1) JSON files + DebouncedWriter cause race conditions or data loss on crash,
  (2) Pure in-memory Maps lose all data on restart,
  (3) Need atomic writes without debounce delays,
  (4) Migrating multiple modules incrementally (one at a time, with E2E tests between),
  (5) Need backward compatibility with callers of saveNow()/flushSync().
  Covers: _dbId tracking, 3-tier loading fallback, encryption preservation, no-op backward compat.
version: 1.0.0
date: 2026-02-12
author: Claude Code
---

# JSON/Memory to SQLite Hybrid Migration Pattern

## Problem

Server modules using JSON file persistence (via DebouncedWriter pattern) or pure in-memory
Maps/Sets have critical reliability issues:

- **JSON + DebouncedWriter**: Crash during debounce window = data loss. Race conditions
  when multiple writes queue up. Entire file rewritten on every change.
- **Pure in-memory**: All data lost on server restart. No persistence at all.
- **Both**: No atomic operations. No query capability. No referential integrity.

## Context / Trigger Conditions

- Bun server (bun:sqlite available natively, zero dependencies)
- Existing modules use `writeFileSync()` + `createDebouncedWriter()` for JSON persistence
- Or modules use `new Map<K,V>()` / `new Set<T>()` with no persistence
- Need to migrate incrementally (one module at a time) without breaking others
- Performance-sensitive hot paths that need O(1) reads
- Existing export signatures (`saveNow()`, `flushSync()`) must remain stable

## Solution

### Architecture: Hybrid Cache + SQLite

```
Read Path:  Map.get(key) → O(1) from memory
Write Path: Map.set(key) → immediate db.run(INSERT/UPDATE) → O(1) memory + durable
Load Path:  Server startup → SELECT * FROM table → populate Map
```

### Step 1: Add `_dbId` to Interfaces

Add an optional `_dbId?: number` field to track the SQLite auto-increment ID for each
in-memory object. This enables targeted UPDATE/DELETE without scanning.

```typescript
export interface ApiKey {
  key: string;
  label: string;
  status: 'active' | 'banned';
  // ... existing fields ...
  _dbId?: number;  // SQLite row ID for targeted UPDATE/DELETE
}
```

### Step 2: Create SQLite Helper Functions

For each data operation, create a targeted SQLite function:

```typescript
import { getDb } from './database';

function dbInsertItem(item: Item): number {
  const db = getDb();
  db.run('INSERT INTO items (name, value) VALUES (?, ?)', [item.name, item.value]);
  const row = db.query('SELECT last_insert_rowid() as id').get() as { id: number };
  return row.id;
}

function dbUpdateItem(item: Item): void {
  if (!item._dbId) return;
  const db = getDb();
  db.run('UPDATE items SET name = ?, value = ? WHERE id = ?',
    [item.name, item.value, item._dbId]);
}

function dbDeleteItem(dbId: number): void {
  const db = getDb();
  db.run('DELETE FROM items WHERE id = ?', [dbId]);
}
```

### Step 3: Replace save() Calls with Targeted Writes

Before (DebouncedWriter):
```typescript
items.set(key, newItem);
save();  // debounced, rewrites entire JSON file
```

After (SQLite):
```typescript
items.set(key, newItem);
dbUpdateItem(newItem);  // immediate, targeted UPDATE
```

### Step 4: Implement 3-Tier Loading Fallback

```typescript
function load(): void {
  const db = getDb();
  const count = (db.query('SELECT COUNT(*) as n FROM items').get() as any).n;

  if (count > 0) {
    // Tier 1: SQLite has data → load from SQLite
    loadFromSqlite();
  } else if (existsSync(JSON_FILE)) {
    // Tier 2: JSON file exists → one-time migration
    migrateFromJson();
  } else {
    // Tier 3: Fresh install → initialize defaults
    initDefaults();
  }
}
```

### Step 5: Make saveNow()/flushSync() No-ops

```typescript
/** Backward compat — SQLite writes are immediate, no flush needed */
export function saveNow(): void {
  /* SQLite writes are immediate — this is a no-op */
}

export function flushSessionsSync(): void {
  /* SQLite writes are immediate — this is a no-op */
}
```

### Step 6: Handle Encryption (if applicable)

If the module encrypts data (e.g., API keys with AES-256-GCM), add encrypt/decrypt
wrapper functions at the SQLite boundary:

```typescript
function encryptForDb(plainKey: string): string {
  // Encrypt before INSERT/UPDATE
  return encrypt(plainKey);  // existing encryption function
}

function decryptFromDb(stored: string): { key: string; ok: boolean } {
  // Decrypt after SELECT
  try {
    return { key: decrypt(stored), ok: true };
  } catch {
    return { key: stored, ok: false };  // fallback: treat as plaintext
  }
}
```

### Step 7: Periodic Cleanup (for session-like data)

```typescript
setInterval(() => {
  // Clean memory
  for (const [token, session] of sessionStore) {
    if (session.expiresAt < Date.now()) sessionStore.delete(token);
  }
  // Sync clean SQLite
  db.run('DELETE FROM sessions WHERE expires_at < ?', [new Date().toISOString()]);
}, CLEANUP_INTERVAL_MS);
```

## Verification

After each module migration:

1. **Server startup test**: Verify all modules load from SQLite correctly
2. **Check logs**: Look for `(SQLite)` in startup messages
3. **E2E tests**: Run full test suite (all tests should pass without changes)
4. **Graceful shutdown**: Verify `closeDb()` is called and no data loss
5. **Restart test**: Kill server, restart, verify data persists

## Example: Real Migration Results (production-api)

| Module | Before | After | Tests |
|--------|--------|-------|-------|
| billing.ts | JSON + DebouncedWriter | SQLite + Map cache | 34/34 |
| key-store.ts | JSON + DebouncedWriter + AES-256-GCM | SQLite + Map + encrypt/decrypt layer | 34/34 |
| stripe-payment.ts | JSON + DebouncedWriter | SQLite + Set cache | 34/34 |
| oauth.ts | Pure in-memory Map (lost on restart) | SQLite + Map cache (survives restart) | 34/34 |

Key metrics:
- 4 modules migrated incrementally
- Zero breaking changes to export signatures
- All 34 E2E tests passed after each migration
- JSON migration path preserved for backward compatibility

## Notes

- **Migration order matters**: Migrate the database module first (if not already done),
  then leaf modules (fewer dependencies) before hub modules
- **Don't remove JSON code immediately**: Keep `existsSync` + `readFileSync` imports
  for the one-time JSON→SQLite migration path
- **DebouncedWriter module**: After all consumers migrated, the debounce-writer.ts
  module can be safely removed (check with `grep -r 'debounce-writer' src/`)
- **WAL mode**: Always use `PRAGMA journal_mode = WAL` for concurrent read/write
- **`last_insert_rowid()`**: Must be called immediately after INSERT (before any other
  statement) to get the correct ID
- **Set → SQLite**: For simple Set<string>, use `INSERT OR IGNORE` for idempotent adds
- **Column name mapping**: SQLite uses snake_case, TypeScript uses camelCase — map
  explicitly in load functions

## See Also

- `batch-processing-output-architecture` — Related output file architecture patterns
- `elizaos-pglite-migration-timing-fix` — PGlite migration timing issues
