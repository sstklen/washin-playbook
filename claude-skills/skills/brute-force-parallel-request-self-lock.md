---
name: brute-force-parallel-request-self-lock
description: |
  Fix brute force protection that locks out legitimate users due to SPA parallel API requests.
  Use when: (1) User reports "IP locked" but swears they didn't enter wrong password,
  (2) Admin panel or dashboard loads and fires 3+ parallel API requests on page load,
  (3) Session/password expiry + parallel requests = instant lockout from a single page load,
  (4) MAX_FAILURES threshold is <= number of parallel requests in loadData().
  Covers: sliding window counters, frontend lockout detection with countdown,
  SQLite CHECK constraint migration for enum expansion.
author: Claude Code
version: 1.0.0
date: 2026-02-16
---

# Brute Force Protection Self-Lock from Parallel Requests

## Problem

Brute force protection counts each failed API request as a separate login failure.
When a SPA (Single Page Application) dashboard fires N parallel API requests on page load,
and the session password is expired/wrong, ALL N requests fail simultaneously —
triggering the lockout threshold from a single page load.

**The user opens one page, gets locked out for 15 minutes, and has no idea why.**

## Context / Trigger Conditions

- User reports: "IP locked but I didn't enter the wrong password"
- Admin panel / dashboard with `Promise.all()` or sequential API calls on load
- `loadAdminData()` or similar calls 3+ endpoints in quick succession
- `MAX_FAILURES` is low (3-5) and parallel requests can exceed it
- Password stored in `sessionStorage` or `localStorage` that can become stale
- Server restart changes `ADMIN_PASSWORD` but browser still has old value

### The Deadly Sequence

```
1. User opens admin panel
2. sessionStorage has old/expired password
3. loadData() fires:
   - GET /api/services      → failure #1
   - GET /api/contributors  → failure #2  (parallel)
   - GET /api/config        → failure #3  (parallel)
4. MAX_FAILURES=3 reached → IP LOCKED for 15 min
5. User sees "IP locked" error, confused
```

## Solution

### Fix 1: Increase threshold + add sliding window

```typescript
// 原本：3 次累計就鎖（容易誤殺）
const MAX_FAILURES = 3;

// 修正：5 次 + 5 分鐘滑動窗口
const MAX_FAILURES = 5;
const FAIL_WINDOW_MS = 5 * 60 * 1000;

interface BruteForceEntry {
  failCount: number;
  lockedUntil: number;
  firstFailAt: number;  // ← 新增：窗口起點
}

function recordLoginFailure(ip: string): void {
  const now = Date.now();
  let entry = bruteForceMap.get(ip);
  if (!entry) {
    entry = { failCount: 0, lockedUntil: 0, firstFailAt: now };
    bruteForceMap.set(ip, entry);
  }

  // 滑動窗口：超過 FAIL_WINDOW_MS → 重置計數
  if (now - entry.firstFailAt > FAIL_WINDOW_MS) {
    entry.failCount = 0;
    entry.firstFailAt = now;
  }

  entry.failCount++;

  if (entry.failCount >= MAX_FAILURES) {
    entry.lockedUntil = now + LOCKOUT_MS;
  }
}
```

### Fix 2: Frontend stops on first auth failure

```javascript
// 關鍵：第一個 API 收到 "密碼錯誤" 就停止，不繼續送請求
async function loadAdminData() {
  const r = await api('/api/services');  // 先送一個
  if (r && r.error === '密碼錯誤') {
    showLoginOverlay();
    return;  // ← 不再送 /api/contributors、/api/config
  }
  // 密碼正確才繼續並行載入
  const [cr, ck] = await Promise.all([...]);
}
```

### Fix 3: Frontend detects IP lockout with countdown

```javascript
// 偵測 retryAfter 欄位，顯示倒數而非重試（重試會加重鎖定！）
if (r && r.retryAfter) {
  var secs = r.retryAfter;
  showError('IP 暫時鎖定，等待 ' + Math.ceil(secs/60) + ' 分鐘');
  var timer = setInterval(function() {
    secs--;
    if (secs <= 0) { clearInterval(timer); loadAdminData(); }
    updateCountdown(secs);
  }, 1000);
  return;  // ← 不要重試！
}
```

## Verification

1. Set a wrong password in sessionStorage
2. Open the admin panel → should show login overlay after 1 failure
3. Enter wrong password 4 times manually → should NOT be locked (< 5)
4. Enter wrong password 5 times within 5 minutes → should be locked
5. Wait for lockout to expire → auto-unlock and retry

## Key Insight

**Two correct systems create a bug together:**
- Brute force protection: correctly counts failures ✅
- SPA parallel loading: correctly loads data fast ✅
- Combined: parallel failures from one page load trigger lockout ❌

The fix is NOT to disable brute force protection. It's to:
1. Make the threshold aware of request bursts (sliding window)
2. Make the frontend aware of auth state before firing parallel requests
3. Make the frontend gracefully handle lockout (countdown, not retry-spam)

## Bonus: SQLite CHECK Constraint Migration

When expanding an enum-style CHECK constraint (e.g., adding new categories),
`CREATE TABLE IF NOT EXISTS` won't update existing tables. Use this pattern:

```typescript
// 檢查舊約束是否缺少新值
const tableInfo = db.query(
  `SELECT sql FROM sqlite_master WHERE type='table' AND name='my_table'`
).get();

if (tableInfo?.sql && !tableInfo.sql.includes("'new_value'")) {
  db.run(`ALTER TABLE my_table RENAME TO _my_table_old`);
  db.run(`CREATE TABLE my_table (...new CHECK constraint...)`);
  db.run(`INSERT INTO my_table SELECT * FROM _my_table_old`);
  db.run(`DROP TABLE _my_table_old`);
}
```

## Notes

- This pattern affects ANY SPA with auth middleware + brute force protection
- Common in: Admin panels, dashboards, API management consoles
- Also affects: Rate limiters that count per-request instead of per-session
- Related skill: `bun-async-race-condition-pattern` (different problem, same domain)

## References

- OWASP Brute Force Protection: https://owasp.org/www-community/controls/Blocking_Brute_Force_Attacks
- OWASP recommends progressive delays over hard lockouts for this reason
