---
name: elizaos-pglite-migration-timing-fix
description: |
  Fix for ElizaOS v1.7.x "relation 'agents' does not exist" and "Database adapter not initialized"
  errors when using PGlite (embedded PostgreSQL). Use when:
  (1) AgentRuntime.initialize() throws "relation 'agents' does not exist" (error code 42P01),
  (2) Error "Database adapter not initialized. The SQL plugin (@elizaos/plugin-sql) is required",
  (3) PGlite database is empty on first run or after data directory deletion,
  (4) Using @elizaos/plugin-sql with PGlite (no POSTGRES_URL configured).
  Root cause: ElizaOS core calls ensureAgentExists() BEFORE runPluginMigrations(),
  so tables don't exist when first queried. Solution: pre-create adapter and run
  migrations manually before runtime.initialize().
author: Claude Code
version: 1.0.0
date: 2026-02-11
---

# ElizaOS PGlite Migration Timing Fix

## Problem

When using ElizaOS v1.7.x with PGlite (embedded PostgreSQL via `@elizaos/plugin-sql`),
the first startup crashes with:

```
error: relation "agents" does not exist
  code: "42P01"
```

This happens because the core's `initialize()` method queries the `agents` table
BEFORE running schema migrations that would create it.

## Context / Trigger Conditions

- **Error message**: `relation "agents" does not exist` (PostgreSQL error 42P01)
- **Secondary error**: `Database adapter not initialized. The SQL plugin (@elizaos/plugin-sql) is required`
- **When it happens**:
  - First run with PGlite (no pre-existing database)
  - After deleting the `data/` directory
  - When `POSTGRES_URL` is NOT set (falls back to PGlite)
  - When `PGLITE_DATA_DIR` points to an empty or new directory
- **Versions**: Confirmed in ElizaOS core v1.7.2 + plugin-sql v1.7.2
- **Does NOT happen**: When using a real PostgreSQL database that already has tables

## Root Cause Analysis

The `AgentRuntime.initialize()` method in `@elizaos/core` executes in this order:

```
1. registerPlugin(sqlPlugin)       → SQL plugin creates & registers PGlite adapter
2. registerPlugin(anthropicPlugin) → AI model setup
3. registerPlugin(twitterPlugin)   → Social media setup
4. adapter.init()                  → PGlite adapter just logs "initialized"
5. ensureAgentExists()             → ❌ QUERIES "agents" TABLE → FAILS (table doesn't exist!)
6. runPluginMigrations()           → Would CREATE tables, but never reached
```

Step 5 fails because step 6 (which creates the tables) hasn't run yet.
This is a chicken-and-egg problem in the core initialization sequence.

## Solution

Pre-create the database adapter and run schema migrations BEFORE calling `runtime.initialize()`.

### Step 1: Install plugin-sql

```bash
bun add @elizaos/plugin-sql
```

### Step 2: Import the migration tools

```typescript
import { AgentRuntime } from '@elizaos/core';
import sqlPlugin, {
  createDatabaseAdapter,
  DatabaseMigrationService,
} from '@elizaos/plugin-sql';
```

### Step 3: Pre-initialize database before runtime.initialize()

```typescript
import { mkdirSync } from 'fs';
import { resolve } from 'path';

// 1. Create runtime (but DON'T call initialize yet)
const runtime = new AgentRuntime({
  character: myCharacter,
  plugins: [sqlPlugin, anthropicPlugin, twitterPlugin],
});

// 2. Create persistent data directory
const dataDir = resolve(import.meta.dir, `../data/${agentName}`);
mkdirSync(dataDir, { recursive: true });

// 3. Create database adapter manually
const dbAdapter = createDatabaseAdapter({ dataDir }, runtime.agentId);
runtime.registerDatabaseAdapter(dbAdapter);

// 4. Run schema migrations to create all tables
const migrationService = new DatabaseMigrationService();
await migrationService.initializeWithDatabase(
  (dbAdapter as any).getDatabase()
);

// Register all plugin schemas
for (const plugin of plugins) {
  if ((plugin as any).schema) {
    migrationService.registerSchema(plugin.name, (plugin as any).schema);
  }
}
await migrationService.runAllPluginMigrations({});

// 5. NOW safe to initialize — tables exist!
await runtime.initialize();
```

### Why this works

1. **Pre-registered adapter**: When `runtime.initialize()` runs the SQL plugin's `init()`,
   it checks `runtime.isReady()` → finds adapter already registered → **skips creation**
2. **Tables already exist**: `ensureAgentExists()` can now query the `agents` table
3. **Idempotent migrations**: `runPluginMigrations()` runs again during initialize but
   detects "No changes detected, skipping migration" → safe

## Verification

After applying the fix, startup logs should show:

```
[Migration] Starting pre-1.6.5 → 1.6.5+ schema migration...
[Migration] ✓ Migration complete
[PLUGIN:SQL] Executing SQL statements (statementCount=61)
[PLUGIN:SQL] Migration completed successfully
[PLUGIN:SQL] Database adapter already registered, skipping creation  ← KEY LINE
[PLUGIN:SQL] No changes detected, skipping migration                ← Idempotent
✅ [AgentName] ElizaOS Runtime 已啟動
Agent: 1/1 運行中
```

## Example

Full `startAgent()` function used in washin-agent-factory:

```typescript
async function startAgent(factory, name) {
  const agent = factory.getAgent(name.toLowerCase());
  const plugins = [sqlPlugin, anthropicPlugin, twitterPlugin];

  const runtime = new AgentRuntime({
    character: agent.character,
    plugins,
  });

  // ── PGlite Migration Fix ──
  const dataDir = resolve(import.meta.dir, `../data/${name.toLowerCase()}`);
  mkdirSync(dataDir, { recursive: true });

  const dbAdapter = createDatabaseAdapter({ dataDir }, runtime.agentId);
  runtime.registerDatabaseAdapter(dbAdapter);

  const migrationService = new DatabaseMigrationService();
  await migrationService.initializeWithDatabase(
    (dbAdapter as any).getDatabase()
  );
  for (const p of plugins) {
    if ((p as any).schema) {
      migrationService.registerSchema(p.name, (p as any).schema);
    }
  }
  await migrationService.runAllPluginMigrations({});
  // ── Fix End ──

  await runtime.initialize();
  // Runtime is now running!
}
```

## Notes

- **PGlite data persists** in the specified `dataDir`. On subsequent runs, migrations
  are skipped ("No changes detected") so startup is fast.
- **Add `data/` to `.gitignore`** — the PGlite directory contains binary database files.
- **TypeScript types**: `getDatabase()` and `schema` are not exposed in the public
  TypeScript interfaces, hence the `as any` casts. This is safe because both methods
  exist on the actual runtime objects.
- **Twitter credential warning**: You may still see "Twitter API credentials not configured"
  during plugin init. This is a false warning — the Twitter service successfully loads
  credentials from `process.env` during its own `init()` phase. Ignore it if
  "Successfully authenticated with Twitter API v2" appears later.
- **Twitter 402 on home timeline**: Free tier Twitter API doesn't support home timeline
  access (HTTP 402 Payment Required). This is non-fatal — posting still works.
- **This fix may not be needed in future ElizaOS versions** if the core reorders
  `runPluginMigrations()` to run before `ensureAgentExists()`.

## References

- [ElizaOS GitHub](https://github.com/elizaOS/eliza)
- [ElizaOS plugin-sql on npm](https://www.npmjs.com/package/@elizaos/plugin-sql)
- [PGlite adapter PR #1810](https://github.com/elizaOS/eliza/pull/1810)
- [ElizaOS Documentation](https://docs.elizaos.ai/projects/overview)
