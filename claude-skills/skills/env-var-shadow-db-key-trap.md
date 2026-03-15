---
name: env-var-shadow-db-key-trap
description: |
  Fix API keys reading wrong values when .env placeholder shadows valid DB keys.
  Use when: (1) getKey() returns placeholder text like "你的key" instead of real API key,
  (2) Admin panel shows key updated but scripts still use old value,
  (3) Multi-source key reader (env var → DB) returns stale data despite DB having correct key,
  (4) API calls fail with invalid key even though DB was just updated,
  (5) Docker container has different env vars than .env file on disk,
  (6) Random API failures where some calls succeed and some fail (key pool rotation hits bad key).
  Root cause: env var with placeholder value has higher priority than encrypted DB key.
  Includes 5-layer defense-in-depth pattern to prevent recurrence.
author: Claude Code
version: 2.0.0
date: 2026-02-19
---

# Environment Variable Shadows Database Key

## Problem

A `getKey()` function that reads from multiple sources (env var → SQLite DB) returns
a placeholder or invalid API key, even though the DB has a valid, recently-updated key.
The symptom is confusing because everything "looks right" in the database.

**v2.0 upgrade:** This now includes a complete 5-layer defense pattern to prevent
placeholder keys from ever entering the system, not just fix them after discovery.

## Context / Trigger Conditions

- Key reading function checks env vars BEFORE database (common pattern)
- `.env` file contains placeholder values like `SERPER_API_KEY=你的key` or `API_KEY=xxx`
- Admin panel successfully updates the key in the database
- But scripts keep using the old/fake value from the environment variable
- Docker container's env also inherits the placeholder (requires restart to clear)
- **New in v2.0:** Random 500 errors when Key Pool rotates to the bad key
  (e.g., DeepSeek fails randomly because one of N keys is a placeholder)

## Root Cause

Multi-source key reading pattern:
```typescript
// Priority: env var (1st) → SQLite DB (2nd)
function getKey(serviceId: string): string | null {
  const envName = SERVICE_ENV_MAP[serviceId];
  if (envName && process.env[envName]) {  // ← Placeholder is truthy!
    return process.env[envName]!;          // ← Returns "你的key" instead of DB value
  }
  // Never reaches DB reading code...
}
```

Any non-empty string in `.env` (including placeholders like `你的key`, `YOUR_KEY_HERE`,
`sk-xxx`) is truthy and blocks the DB fallback.

### Docker-Specific Variant

Docker containers bake env vars at creation time (`docker compose up`). Even if you
edit `.env` on disk, the **running container keeps the OLD values**. You must
`docker compose down && docker compose up -d --build` to apply changes.

```bash
# .env on disk:     DEEPSEEK_API_KEY=         (empty)
# Running container: DEEPSEEK_API_KEY=你的key  (baked from old .env!)
# grep .env shows clean → but container has the stale value
```

## Solution

### Layer 1: isPlaceholderKey() Utility Function

Central detection function with 15+ patterns:

```typescript
const PLACEHOLDER_PATTERNS = [
  '你的', 'your-', 'your_', 'xxx', 'placeholder', 'example',
  'test-key', 'demo-key', 'insert-', 'replace-', 'put-your',
  'change-me', 'fill-in', 'todo',
];

export function isPlaceholderKey(key: string | undefined | null): boolean {
  if (!key || key.trim() === '') return true;
  const k = key.trim().toLowerCase();
  if (k.length < 8) return true;  // Real API keys are always longer
  for (const pattern of PLACEHOLDER_PATTERNS) {
    if (k.includes(pattern)) return true;
  }
  return false;
}
```

### Layer 2: getKey() / getKeyOrEnv() Validation

Add placeholder check before returning env var fallback:

```typescript
export function getKeyOrEnv(serviceId: string, envName: string): string | null {
  const storeKey = getKey(serviceId);  // DB first
  if (storeKey) return storeKey;

  const envVal = process.env[envName] || null;
  if (envVal && isPlaceholderKey(envVal)) {
    log.warn(`⚠️ ${envName} is placeholder, ignoring ("${envVal.substring(0, 10)}...")`);
    return null;  // ← Fall through, don't return garbage
  }
  return envVal;
}
```

### Layer 3: Import/Sync Validation

When syncing env vars into the key store, filter placeholders:

```typescript
// In ensureEnvKeys() or similar sync function
if (isPlaceholderKey(baseKey)) {
  log.warn(`⚠️ Skipping placeholder: ${envName}`);
  continue;  // Don't import garbage into DB
}
```

### Layer 4: Startup ENV Scan

At server boot, scan ALL known env vars and delete placeholders:

```typescript
// In server startup, BEFORE any service initialization
import { ENV_MAP } from './service-registry';  // ← Don't forget this import!

{
  const placeholders: string[] = [];
  for (const [serviceId, envName] of Object.entries(ENV_MAP)) {
    const val = process.env[envName];
    if (val && isPlaceholderKey(val)) {
      placeholders.push(`${envName}="${val.substring(0, 10)}..."`);
      delete process.env[envName];  // ← Nuclear option: remove from process
    }
  }
  if (placeholders.length > 0) {
    log.warn(`🚨 Found ${placeholders.length} placeholder API keys (auto-cleared):`);
    placeholders.forEach(p => log.warn(`   ⚠️ ${p}`));
  }
}
```

**⚠️ CRITICAL:** Make sure ENV_MAP is imported! Missing import causes
`ReferenceError: ENV_MAP is not defined` at startup → container crash loop.

### Layer 5: Pre-flight Check (Test Scripts)

Before running integration tests, verify the system is healthy:

```typescript
// In test script main()
const healthResp = await fetch(`${BASE_URL}/health`);
if (!healthResp.ok) { console.log('❌ Server down'); process.exit(1); }

if (API_KEY) {
  const testResp = await fetch(`${BASE_URL}/api/proxy/weather`, {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${API_KEY}` },
    body: JSON.stringify({ location: 'Tokyo' }),
  });
  if (testResp.status === 402) { console.log('❌ Key balance empty'); process.exit(1); }
  if (testResp.status === 403) { console.log('❌ Key invalid'); process.exit(1); }
}
```

## Verification

```bash
# 1. Check server startup logs for placeholder warnings
docker logs myapp-api 2>&1 | grep "佔位符\|placeholder"

# 2. Verify no placeholder env vars in container
docker exec myapp-api env | grep -i "api_key\|token" | grep -E "你的|xxx|placeholder"

# 3. Run connectivity test
TEST_API_KEY=wv_xxx bun run scripts/p1-connectivity-t1.ts
```

## Example

Real-world scenario from production-api (2026-02-19):

```
Timeline:
1. Old .env had: DEEPSEEK_API_KEY=你的key (Chinese placeholder)
2. Docker container created → placeholder baked into env
3. Later: .env edited to DEEPSEEK_API_KEY= (empty)
4. But container still has 你的key from creation time!
5. Key Pool has 2 DeepSeek keys: 1 real (from DB) + 1 placeholder (from env)
6. Random rotation → sometimes hits the placeholder → HTTP 500
7. Error: "Header '14' has invalid value: 'Bearer 你的key'"
8. Misleading: looks like "random failures" not "bad key"

Fix applied: All 5 layers deployed → container rebuilt → P3 exam clean
```

## Notes

- This bug is especially insidious because the DB diagnostics show everything is correct
- Empty env var values (`KEY=`) are falsy in JS and won't cause this issue
- Docker containers bake env vars at creation — changing `.env` requires `down + up --build`
- When using `.env.example`, use obviously-fake values like `CHANGE_ME` not `你的key`
- Consider logging which source the key came from during debugging
- The 5-layer defense is defense-in-depth: any single layer failing is caught by the next
- Layer 4 (startup scan) is the most critical — catches ALL variants automatically
- Layer 4 MUST import ENV_MAP from the correct module (caused a container crash when missed)
- See also: `docker-sqlite-wal-copy-trap` for another Docker debugging nightmare
- See also: `t1-vps-exam-operations` for VPS deployment patterns
