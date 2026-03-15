---
name: docker-sqlite-wal-copy-trap
description: |
  Fix stale or corrupted SQLite data when using `docker cp` to copy DB from a running container.
  Use when: (1) `docker cp` gives old data even though the app updated the DB,
  (2) SQLite "database disk image is malformed" after docker cp,
  (3) scripts reading a DB copied from Docker show outdated values,
  (4) WAL mode SQLite inside Docker container.
  Root cause: SQLite WAL mode stores recent writes in .db-wal file, docker cp only copies .db.
author: Claude Code
version: 1.0.0
date: 2026-02-19
---

# Docker SQLite WAL Copy Trap

## Problem

When copying a SQLite database from a running Docker container using `docker cp`,
recent writes are missing or the database appears corrupted. The copied DB shows
stale data even though the application confirmed the update was successful.

## Context / Trigger Conditions

- SQLite database running inside a Docker container with WAL mode enabled
  (common with `bun:sqlite`, which uses WAL by default)
- Using `docker cp container:/path/db.db ./local.db` to extract the database
- The copied DB is missing recent INSERT/UPDATE operations
- Or: `Error: database disk image is malformed` when querying the copied DB
- Symptom: Admin panel says "update successful" but the copied DB shows old values

## Root Cause

SQLite WAL (Write-Ahead Logging) mode stores recent writes in two companion files:
- `database.db` — main database (may be stale)
- `database.db-wal` — recent writes (THIS IS WHERE NEW DATA LIVES)
- `database.db-shm` — shared memory index

`docker cp` copies only the single file you specify. If you only copy `.db`,
you miss all writes that haven't been checkpointed from WAL into the main file.

## Solution

### Method 1: Checkpoint WAL before copying (Recommended)

```bash
# 1. Force WAL checkpoint inside the container
docker exec CONTAINER sh -c 'cd /app && bun -e "
  const{Database}=require(\"bun:sqlite\");
  const db=new Database(\"data/app.db\");
  db.run(\"PRAGMA wal_checkpoint(TRUNCATE)\");
  db.close();
  console.log(\"WAL checkpoint done\");
"'

# 2. Wait a moment for file sync
sleep 1

# 3. Now docker cp gets the complete data
docker cp CONTAINER:/app/data/app.db ./local.db
```

### Method 2: Copy all three files

```bash
# Remove old files first
rm -f ./local.db ./local.db-wal ./local.db-shm

# Copy all three
docker cp CONTAINER:/app/data/app.db ./local.db
docker cp CONTAINER:/app/data/app.db-shm ./local.db-shm 2>/dev/null
docker cp CONTAINER:/app/data/app.db-wal ./local.db-wal 2>/dev/null
```

### Method 3: Query inside the container (avoids copy entirely)

```bash
docker exec CONTAINER sh -c 'cd /app && bun -e "
  const db = new (require(\"bun:sqlite\").Database)(\"data/app.db\", {readonly:true});
  const rows = db.prepare(\"SELECT * FROM table_name\").all();
  console.log(JSON.stringify(rows));
  db.close();
"'
```

## Verification

After copying, verify the data is current:
```bash
# Check file sizes (WAL should be 0 or small after checkpoint)
docker exec CONTAINER sh -c 'ls -la /app/data/app.db*'

# Compare record counts
docker exec CONTAINER sh -c 'bun -e "..."'  # count inside container
sqlite3 ./local.db "SELECT COUNT(*) FROM table_name"  # count in copy
```

## Example

Real-world scenario from production API project:

```bash
# Admin panel updated Serper API key via REST API → {"success": true}
# But script reading copied DB still got old placeholder "你的key"

# Fix: checkpoint first, then copy
docker exec myapp-api sh -c 'cd /app && bun -e "
  const{Database}=require(\"bun:sqlite\");
  const db=new Database(\"data/app.db\");
  db.run(\"PRAGMA wal_checkpoint(TRUNCATE)\");
  db.close();
"'
sleep 1
docker cp myapp-api:/app/data/app.db ~/myapp-api/data/app.db
# Now the copied DB has the updated key ✅
```

## Notes

- `bun:sqlite` enables WAL mode by default — this trap affects ALL Bun SQLite projects
- The WAL file can grow to several MB before auto-checkpoint (default 1000 pages)
- `PRAGMA wal_checkpoint(TRUNCATE)` is safest — it truncates the WAL file to zero
- If the container's SQLite process has an exclusive lock, checkpoint may fail — retry after a moment
- This issue does NOT occur when reading the DB from within the same container
- Consider adding WAL checkpoint to deployment/backup scripts as a best practice
- See also: `json-to-sqlite-hybrid-migration` for SQLite migration patterns
