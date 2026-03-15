---
name: sqlite-check-constraint-migration
description: |
  Fix SQLite "CHECK constraint failed" when expanding allowed values (e.g., tier IN(0,1,2) to BETWEEN 0 AND 5).
  Use when: (1) SQLiteError: CHECK constraint failed on INSERT/UPDATE,
  (2) CREATE TABLE IF NOT EXISTS won't update existing constraints,
  (3) ALTER TABLE can't modify CHECK constraints in SQLite.
  Covers: table rebuild migration, column-count mismatch pitfalls, PRAGMA table_info usage.
author: Claude Code
version: 1.0.0
date: 2026-02-18
---

# SQLite CHECK Constraint Migration

## Problem

SQLite does not support modifying or dropping CHECK constraints via `ALTER TABLE`.
When you expand an enum-like constraint (e.g., `tier IN (0, 1, 2)` to `BETWEEN 0 AND 5`),
the existing database keeps the old constraint even if you update the `CREATE TABLE IF NOT EXISTS`
statement, because `IF NOT EXISTS` skips table creation entirely when the table already exists.

## Context / Trigger Conditions

- **Error message**: `SQLiteError: CHECK constraint failed: <constraint_expression>`
  (e.g., `CHECK constraint failed: tier IN (0, 1, 2)`)
- **Scenario**: Adding a new value category to an existing system (new tier, new status, etc.)
- **Root cause**: The runtime code's `CREATE TABLE IF NOT EXISTS` has the updated constraint,
  but the existing `.db` file still has the old, restrictive constraint
- **Applies to**: Bun SQLite, better-sqlite3, node-sqlite3, any SQLite binding

## Solution

### Step 1: Detect if old constraint exists

```typescript
const tableInfo = db.query(
  "SELECT sql FROM sqlite_master WHERE type='table' AND name='your_table'"
).get() as any;

// Check for the specific old constraint pattern
if (tableInfo?.sql && /tier IN\s*\(\s*0\s*,\s*1\s*,\s*2\s*\)/.test(tableInfo.sql)) {
  // Old constraint found — needs migration
}
```

### Step 2: Rebuild table with correct constraint

```typescript
db.run('PRAGMA foreign_keys = OFF');  // Disable FK checks during rebuild

db.transaction(() => {
  // 1. Create new table with corrected constraint
  db.run(`CREATE TABLE your_table_new (
    -- EXACT same columns as existing table, but with updated CHECK
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ...
    tier INTEGER NOT NULL DEFAULT 1 CHECK (tier BETWEEN 0 AND 5),
    ...
  )`);

  // 2. Copy all data
  db.run('INSERT INTO your_table_new SELECT * FROM your_table');

  // 3. Drop old, rename new
  db.run('DROP TABLE your_table');
  db.run('ALTER TABLE your_table_new RENAME TO your_table');
})();

db.run('PRAGMA foreign_keys = ON');  // Re-enable FK checks
```

### Step 3: Wrap in try/catch for idempotency

```typescript
try {
  // ... detection + migration above ...
  console.log('[DB] Constraint migration completed');
} catch (e: any) {
  console.warn(`[DB] Constraint migration skipped: ${e.message}`);
}
```

## Pitfalls (Learned the Hard Way)

### Pitfall 1: Column count mismatch

**Error**: `table your_table_new has 30 columns but 32 values were supplied`

The new table definition **must have the exact same columns** as the existing table,
including columns added later via `ALTER TABLE ADD COLUMN`. These late-added columns
appear at the end of `PRAGMA table_info()` output but may not be in your original
`CREATE TABLE` statement.

**Fix**: Check actual columns first:
```sql
PRAGMA table_info(your_table);
```
Then ensure the new table matches **all** columns, not just the original schema.

### Pitfall 2: Default value syntax for functions

**Error**: `near "(": syntax error` when dynamically generating column definitions.

Columns with function-based defaults like `DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))`
need the outer parentheses preserved. `PRAGMA table_info` returns the default value
**without** the outer parentheses, so dynamic reconstruction fails.

**Fix**: Hardcode the full table definition rather than dynamically reading it.

### Pitfall 3: Foreign key references

If other tables have `REFERENCES your_table(column)`, the `DROP TABLE` + `RENAME`
approach may break FK relationships. Always disable FK checks with
`PRAGMA foreign_keys = OFF` before the migration.

## Verification

```sql
-- After migration, verify the new constraint:
SELECT sql FROM sqlite_master WHERE type='table' AND name='your_table';
-- Should show: CHECK (tier BETWEEN 0 AND 5)

-- Test inserting a previously forbidden value:
INSERT INTO your_table (service_id, tier, ...) VALUES ('test', 3, ...);
-- Should succeed (was previously blocked by CHECK)
```

## Example

Real-world migration from production API project (database.ts):

```typescript
// Detect old constraint
const tableInfo = db.query(
  "SELECT sql FROM sqlite_master WHERE type='table' AND name='services'"
).get() as any;

if (tableInfo?.sql && /tier IN\s*\(\s*0\s*,\s*1\s*,\s*2\s*\)/.test(tableInfo.sql)) {
  db.run('PRAGMA foreign_keys = OFF');
  db.transaction(() => {
    db.run(`CREATE TABLE services_new (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      service_id TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL,
      -- ... all 32 columns with exact types/defaults ...
      tier INTEGER NOT NULL DEFAULT 1 CHECK (tier BETWEEN 0 AND 5),
      -- ...
    )`);
    db.run('INSERT INTO services_new SELECT * FROM services');
    db.run('DROP TABLE services');
    db.run('ALTER TABLE services_new RENAME TO services');
  })();
  db.run('PRAGMA foreign_keys = ON');
  console.log('[DB] tier constraint migrated: IN(0,1,2) -> BETWEEN 0 AND 5');
}
```

## Notes

- This migration is **idempotent**: the regex check on `sqlite_master` ensures it only
  runs once (after migration, the new constraint won't match the old pattern)
- Same technique works for expanding any enum-like constraint:
  `status IN ('a','b')` -> `status IN ('a','b','c','d')`
- For very large tables (millions of rows), the `INSERT INTO ... SELECT *` may take time
  and lock the database. Consider doing this during maintenance windows
- SQLite's `ALTER TABLE` only supports: `RENAME TABLE`, `RENAME COLUMN`, `ADD COLUMN`,
  `DROP COLUMN` (3.35.0+). No `ALTER CONSTRAINT`, `MODIFY COLUMN`, or `ADD CONSTRAINT`

## References

- [SQLite ALTER TABLE documentation](https://www.sqlite.org/lang_altertable.html)
- [SQLite FAQ: How do I change a table?](https://www.sqlite.org/faq.html#q11)
- See also: `json-to-sqlite-hybrid-migration` - JSON to SQLite migration patterns
- See also: `bun-sqlite-transaction-await-crash` - Bun SQLite transaction gotchas
