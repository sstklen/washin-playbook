---
name: async-job-duplicate-insert
description: |
  Fix for "UNIQUE constraint failed" when separating async job creation (API route)
  from job execution (background worker). Use when: (1) API endpoint creates a job
  record then launches background execution via setTimeout, (2) the background
  worker also tries to INSERT the same job record, (3) SQLite/PostgreSQL throws
  UNIQUE constraint violation. Pattern: route INSERT + setTimeout(worker) where
  worker also INSERTs. Fix: route does INSERT, worker does UPDATE only.
author: Claude Code
version: 1.0.0
date: 2026-02-20
---

# Async Job Creation vs Execution — Duplicate INSERT Prevention

## Problem

When building a "fire-and-forget" async job system (API returns immediately,
background worker executes), it's common for both the route handler and the
worker to try to INSERT the job record, causing a UNIQUE constraint violation.

## Context / Trigger Conditions

- **Error**: `UNIQUE constraint failed: jobs.id` (or equivalent)
- **Pattern**: Two files/modules both responsible for the same DB record
- **Architecture**: `POST /api/job → INSERT record → setTimeout(worker) → worker also INSERTs`
- **Timing**: Job fails immediately on first run, 0 results produced

## Solution

### Clear Ownership Rule

**Route handler** owns INSERT (creation). **Worker** owns UPDATE (execution).

```typescript
// ── Route Handler (exam-routes.ts) ──
admin.post('/api/exam/run', async (c) => {
  const examId = generateId();

  // Route CREATES the record
  db.run('INSERT INTO exam_runs (id, type, status, started_at) VALUES (?, ?, ?, ?)',
    [examId, type, 'running', now]);

  // Fire-and-forget
  setTimeout(() => runExam(examId, { type }), 0);

  return c.json({ examId, status: 'running' });
});

// ── Worker (exam-runner.ts) ──
async function runExam(examId: string, opts: { type: string }) {
  // Worker UPDATES the record (NOT INSERT!)
  db.run('UPDATE exam_runs SET total_services = ? WHERE id = ?',
    [serviceCount, examId]);

  // ... execute work, INSERT child records ...

  db.run('UPDATE exam_runs SET status = ?, completed_at = ? WHERE id = ?',
    ['completed', now, examId]);
}
```

### Anti-Pattern

```typescript
// ❌ WRONG — Both route AND worker INSERT
// Route:
db.run('INSERT INTO exam_runs ...', [examId, ...]);
setTimeout(() => runExam(examId), 0);

// Worker:
async function runExam(examId) {
  db.run('INSERT INTO exam_runs ...', [examId, ...]);  // BOOM! UNIQUE constraint
}
```

## Verification

1. Trigger the job via API
2. Check logs for UNIQUE constraint errors
3. Verify job completes with results in child table

## Notes

- This pattern applies to any "create then execute" flow: job queues, exam runners,
  report generators, data pipelines
- Alternative: Use `INSERT OR IGNORE` or `ON CONFLICT DO UPDATE` if you want the
  worker to be idempotent, but explicit role separation is cleaner
- For distributed systems, use `INSERT ... ON CONFLICT DO NOTHING` and have the
  worker check if the record exists before proceeding
