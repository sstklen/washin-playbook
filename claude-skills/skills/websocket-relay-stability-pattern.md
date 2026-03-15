---
name: websocket-relay-stability-pattern
description: |
  Fix WebSocket long-lived connections that disconnect every ~120 seconds through
  reverse proxy chains (Caddy/Nginx + Bun/Node). Use when:
  (1) WebSocket connects but disconnects exactly every 2 minutes (120s = Bun default idleTimeout),
  (2) Relay/bridge pattern where server-side close triggers client reconnect loop,
  (3) Multiple WebSocket clients cause "duplicate connection" kick → reconnect → infinite loop,
  (4) WebSocket works locally but breaks through Caddy/Nginx/Cloudflare reverse proxy.
  Covers: Bun idleTimeout, Caddy transport timeouts, close handler race conditions,
  silent connection replacement, PID lock files.
author: Claude Code
version: 1.0.0
date: 2026-02-22
---

# WebSocket Relay Stability Pattern

## Problem

Long-lived WebSocket connections (relay, bridge, real-time) disconnect every ~120 seconds
when running through a multi-layer proxy chain (Client -> Cloudflare -> Caddy -> Bun).
Reconnection attempts cause infinite loops when the server kicks old connections.

## Context / Trigger Conditions

- WebSocket connects successfully but disconnects at exactly 120 seconds
- VPS logs show repeating pattern: `connect -> 120s -> disconnect -> 5s -> reconnect`
- After adding duplicate detection: `connect -> kick old -> old closes -> reconnect -> kick -> loop`
- Application-level heartbeats (JSON messages) don't prevent disconnection
- Connection works fine locally but breaks through reverse proxy

## Root Causes (Three Layers)

### Layer 1: Bun WebSocket idleTimeout (120s default)

Bun's `Bun.serve()` has a default `idleTimeout: 120` for WebSockets. This kills
connections after 120 seconds of "inactivity" — and Bun may use protocol-level
ping/pong, not application-level JSON messages, to determine activity.

```typescript
// BAD: default idleTimeout = 120 seconds
websocket: {
  open(ws) { ... },
  close(ws) { ... },
}

// GOOD: disable idle timeout for long-lived connections
websocket: {
  idleTimeout: 0,           // Never auto-close
  sendPingsAutomatically: true,  // Keep protocol-level pings
  open(ws) { ... },
  close(ws) { ... },
}
```

### Layer 2: Caddy reverse proxy transport timeouts

Caddy's `transport http` block has `read_timeout` and `write_timeout` that also
apply to WebSocket connections. Default or explicit 120s values kill long connections.

```caddyfile
# BAD: WebSocket uses same timeout as HTTP
reverse_proxy backend:3000 {
    transport http {
        read_timeout 120s   # Kills WebSocket after 120s
        write_timeout 120s
    }
}

# GOOD: Separate handler for WebSocket path with no timeout
@websocket path /api/v2/my-websocket-endpoint
handle @websocket {
    reverse_proxy backend:3000 {
        transport http {
            dial_timeout 5s
            read_timeout 0    # No timeout for WebSocket
            write_timeout 0
        }
    }
}

# Regular HTTP keeps its timeouts
reverse_proxy backend:3000 {
    transport http {
        dial_timeout 5s
        read_timeout 120s
        write_timeout 120s
    }
}
```

### Layer 3: Close handler race condition (the killer)

When server detects duplicate connection and kicks the old one, `close()` is
**synchronous in Bun** — it triggers `handleClose()` immediately, BEFORE the
code returns to `handleOpen()`.

```typescript
// BAD: close() is synchronous in Bun — this clears the NEW connection!
export function handleOpen(ws) {
  if (currentWs && currentWs !== ws) {
    currentWs.close();  // Triggers handleClose() synchronously!
    // handleClose() sets currentWs = null ← clears the NEW ws too!
  }
  currentWs = ws;  // Too late — already nulled
}

export function handleClose() {
  currentWs = null;  // Unconditionally clears — BUG!
}
```

```typescript
// GOOD: Set new FIRST, then close old. Close handler checks identity.
export function handleOpen(ws) {
  const oldWs = currentWs;
  currentWs = ws;  // SET NEW FIRST
  // Don't kick old — let it die naturally from missed heartbeats
  if (oldWs && oldWs !== ws) {
    log('New connection replaces old');
  }
}

export function handleClose(closingWs) {
  // Only clear if the CURRENT connection is closing
  if (currentWs !== null && currentWs !== closingWs) {
    return;  // Old connection closing — ignore
  }
  currentWs = null;
  // ... cleanup
}
```

**Critical: Pass `ws` to close handler so it can distinguish old vs new:**

```typescript
// In Bun serve config:
websocket: {
  close(ws) {
    handleClose(ws);  // Pass ws identity!
  },
}
```

## Solution: Silent Replacement (Not Kicking)

The key insight: **never actively kick old connections**. Kicking triggers
client-side reconnect, which creates a new connection, which kicks again = infinite loop.

Instead: silently replace. Old connections die naturally from:
- Missed heartbeats (client-side watchdog)
- TCP keepalive timeout
- Proxy timeout (for truly idle connections)

## Additional Hardening

### Server-side ping (belt and suspenders)

```typescript
let pingTimer: ReturnType<typeof setInterval> | null = null;

function handleOpen(ws) {
  currentWs = ws;
  // Server-side ping every 30s — penetrates Caddy/Cloudflare
  if (pingTimer) clearInterval(pingTimer);
  pingTimer = setInterval(() => {
    if (currentWs) {
      try { currentWs.ping(); } catch {}
    }
  }, 30000);
}
```

### Client-side heartbeat watchdog

```typescript
const HEARTBEAT_TIMEOUT = 45000;  // 45s no ack = dead

function resetWatchdog() {
  if (watchdog) clearTimeout(watchdog);
  watchdog = setTimeout(() => {
    log('Heartbeat timeout — force reconnect');
    try { ws.close(); } catch {}
  }, HEARTBEAT_TIMEOUT);
}
```

### PID lock file (prevent multiple instances)

```typescript
const LOCK_FILE = '/tmp/my-relay.lock';

function acquireLock(): boolean {
  if (existsSync(LOCK_FILE)) {
    const oldPid = readFileSync(LOCK_FILE, 'utf-8').trim();
    try {
      process.kill(Number(oldPid), 0);  // Check if alive
      console.error(`Already running (PID ${oldPid})`);
      return false;
    } catch {}  // Dead process — take over
  }
  writeFileSync(LOCK_FILE, String(process.pid));
  return true;
}
```

### Exponential backoff reconnection

```typescript
const MIN_RECONNECT = 3000;   // 3s
const MAX_RECONNECT = 60000;  // 60s
let consecutiveFailures = 0;

function scheduleReconnect() {
  consecutiveFailures++;
  const delay = Math.min(
    MIN_RECONNECT * Math.pow(2, consecutiveFailures - 1),
    MAX_RECONNECT,
  );
  setTimeout(connect, delay);
}

// Reset on successful connection:
ws.onopen = () => { consecutiveFailures = 0; };
```

## Verification

1. Check VPS logs — should see ONE connect event, no repeated connect/disconnect
2. Wait 3+ minutes (previously died at 120s) — no disconnect
3. `curl /api/status` should show relay: online
4. Kill and restart relay — should reconnect once, not loop

## Diagnostic Checklist

| Symptom | Cause | Fix |
|---------|-------|-----|
| Disconnects at exactly 120s | Bun idleTimeout or Caddy read_timeout | Set both to 0 for WS path |
| Connect-disconnect loop every 5s | Multiple clients or kick-reconnect cycle | Silent replacement, PID lock |
| "Already connected" + immediate disconnect | Close handler clears new connection | Pass ws to close, check identity |
| Works locally, breaks through proxy | Caddy/Nginx/CF timeout | Dedicated WS handler with no timeout |
| Heartbeats sent but still disconnects | App-level heartbeat vs protocol ping | Add server-side ws.ping() |

## Notes

- Bun's `ServerWebSocket.close()` is synchronous — always set new state BEFORE closing old
- Caddy automatically handles WebSocket upgrade but still applies transport timeouts
- Cloudflare keeps WebSocket alive as long as there's traffic (heartbeats are enough)
- The "三次規則" (three-times rule): if the same problem recurs 3 times, stop patching — redesign

See also: `multi-layer-proxy-timeout-chain-debugging`
