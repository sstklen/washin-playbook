---
name: multi-layer-proxy-timeout-chain-debugging
description: |
  Debug timeout and 502/504 errors in multi-layer proxy architectures (CDN -> reverse proxy -> app -> external API).
  Use when: (1) External API calls return 502/504 but work fine locally or via direct curl,
  (2) Timeout occurs at unpredictable layers (Cloudflare 100s, Caddy/Nginx, app-level),
  (3) Long-running external API calls (Apify Actors, web scrapers, AI inference) fail through proxy chain,
  (4) Key/token lookup returns null despite keys existing in admin panel,
  (5) DB-persisted config overrides code defaults after deployment.
  Covers: Apify sync-to-async migration, Caddy timeout tuning, key-store enabled state auto-heal.
version: 1.0.0
date: 2026-02-18
---

# Multi-Layer Proxy Timeout Chain Debugging

## Problem

External API calls (e.g., Apify Actors, web scrapers) that take 30-120+ seconds fail
with 502/504 errors when routed through a multi-layer proxy chain, even though the
external API itself works fine. Additionally, service configuration persisted in a
database can become inconsistent with code defaults, causing "token not found" errors.

## Context / Trigger Conditions

- **502/504 from CDN** (Cloudflare): External API call takes >100 seconds
- **502 at ~60 seconds**: Reverse proxy (Caddy/Nginx) kills connection before CDN does
- **"Token not found"** despite key visible in admin panel: DB `enabled=false` blocks key lookup
- **Code default change has no effect**: DB already persisted the old value
- **Works locally, fails in production**: Different timeout chain in production

### Architecture Pattern

```
Client
  -> Cloudflare (100s free / 300s Pro timeout)
    -> Caddy/Nginx (response_header_timeout)
      -> App (AbortSignal.timeout)
        -> External API (Apify Actor, 30-120s+)
```

Each layer has its own timeout. The SHORTEST one in the chain determines the max allowed time.

## Solution

### Step 1: Map the Timeout Chain (Outside-In)

```
1. CDN layer:     Cloudflare free=100s, Pro=300s
2. Proxy layer:   Caddy response_header_timeout, Nginx proxy_read_timeout
3. App layer:     fetch timeout, AbortSignal.timeout
4. External API:  Actor runtime, API timeout parameter
```

**Find the bottleneck**: The layer with the shortest timeout is your culprit.

### Step 2: Fix External API (Convert Sync to Async)

If the external API takes >30s, NEVER use synchronous single-HTTP calls.

**Before (bad):**
```
GET /v2/acts/{id}/run-sync-get-dataset-items  <- Single HTTP, blocks 120s+
```

**After (good) - Three-phase async:**
```
Phase 1: POST /v2/acts/{id}/runs          <- Start Actor (returns in <3s)
Phase 2: GET /v2/actor-runs/{runId}       <- Poll status every 3s (<3s each)
Phase 3: GET /v2/datasets/{id}/items      <- Get results (<3s)
```

Each HTTP call is <5 seconds. Total elapsed may be 30-120s, but no single
connection hangs longer than the proxy timeout.

**Apify-specific**: Dataset is append-only. Even if Actor times out, you can
still retrieve partial results from Phase 3.

### Step 3: Tune Proxy Timeouts

Set each layer's timeout slightly higher than the expected max:

```
# Caddy
transport http {
    response_header_timeout 120s  # Must be > app max wait
    read_timeout 120s
    write_timeout 120s
}

# Nginx equivalent
proxy_read_timeout 120s;
proxy_send_timeout 120s;
```

**Important**: After changing Caddy config, you must restart the Caddy container:
```bash
docker compose restart caddy
# `docker compose up -d --build` only rebuilds app container;
# Caddy reads config at startup, volume-mounted changes need restart
```

### Step 4: Fix DB-Persisted Config State

**The trap**: `DEFAULT_SERVICES` in code sets `enabled: true`, but the DB already
has `enabled: false` from a previous deployment. Changing the code default only
affects NEW installations.

**Self-healing pattern** (recommended):
```typescript
export function getKey(serviceId: string): string | null {
  const svc = services.get(serviceId);
  if (!svc || svc.keys.length === 0) return null;

  // Auto-heal: keys exist but service disabled = inconsistent state
  if (!svc.enabled) {
    log.warn(`Service ${serviceId} has ${svc.keys.length} keys but enabled=false, auto-enabling`);
    svc.enabled = true;
    dbUpdateServiceEnabled(serviceId, true);  // Persist fix to DB
  }
  // ... continue with normal key selection
}
```

**Why this is safe**: If an admin intentionally disabled a service, they would
remove the keys first. Having keys + disabled is always an inconsistent state.

### Step 5: Verify Key Lookup Path

Different lookup functions may exist:

| Function | Lookup Path | Use Case |
|----------|------------|----------|
| `getKey(service)` | Shared pool only | Normal API routing |
| `getSystemKey(service)` | systemOnly keys only | Internal system functions |
| `getSystemKeyOrEnv(service, env)` | systemOnly -> shared -> env | Internal with fallback |
| `getKeyOrEnv(service, env)` | shared -> env | External tools with env fallback |

**Common mistake**: Using `getSystemKeyOrEnv` when the key is in the shared pool
(not marked as systemOnly). Use `getKeyOrEnv` instead.

## Verification

```bash
# 1. Check each timeout layer
curl -s -o /dev/null -w "HTTP:%{http_code} TIME:%{time_total}s" \
  --max-time 120 YOUR_ENDPOINT

# 2. If 502: check which layer killed it
#    - TIME < 60s = proxy layer (Caddy/Nginx)
#    - TIME ~ 100s = CDN layer (Cloudflare)
#    - TIME < 30s = app layer

# 3. After fix: expect 200 with time = external API runtime + overhead
# Example: Apify GMaps 20-45s + 2-3s overhead = ~25-50s total

# 4. Check auto-heal log
docker logs myapp-api 2>&1 | grep "auto-enabling\|enabled=false"
```

## Example

**Real case**: Apify Google Maps Reviews Actor via Washin Village L4 Task Engine

- Actor runtime: 30-120s (scrapes Google Maps reviews)
- Before fix: 502 at 58s (Caddy killed it)
- Fix 1: Caddy timeout 60s -> 120s (eliminated proxy bottleneck)
- Fix 2: Sync -> Async API (each HTTP <5s, total ~20s)
- Fix 3: getKeyOrEnv (correct key lookup path)
- Fix 4: Auto-heal enabled state in getKey()
- After fix: 200 OK in 24s, quality 0.70, 3/3 steps completed

**5 commits, 3 hours, 5 independent bugs in chain.**

## Notes

- Always debug timeout chains from the **outermost layer inward**
- The error message (502/504) tells you WHERE it died, not WHY
- DB-persisted config is invisible when reading source code - always check actual DB state
- Docker volume mounts reflect file changes immediately for app code, but Caddy/Nginx
  read config at startup only - need container restart
- Apify Actors: prefer async API (`/runs` + polling) over sync (`/run-sync-get-dataset-items`)
- Cloudflare free tier: 100s timeout is hard limit, Pro ($20/mo) extends to 300s

## See also

- `serverless-api-timeout-pattern` - Timeout handling in serverless environments
- `docker-compose-force-recreate-caddy-loop` - Caddy restart gotchas
- `vps-deploy-workflow` - VPS deployment checklist
