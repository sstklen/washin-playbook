---
name: hono-global-middleware-ordering
description: |
  Fix Hono app.use('*') global middleware silently not executing for sub-routes
  registered via app.route(). Also fixes Response body consumed by middleware
  causing blank pages. Use when: (1) global middleware (nav injection, analytics,
  auth check) doesn't run for pages mounted via app.route(), (2) middleware works
  for inline app.get() routes but NOT for sub-router routes, (3) pages render as
  blank/empty after adding response-modifying middleware, (4) c.res.text() in
  middleware causes downstream middleware to receive empty body. Two bugs, one root
  cause: middleware registration order + ReadableStream one-time consumption.
author: Claude Code
version: 1.0.0
date: 2026-02-16
---

# Hono Global Middleware Ordering + Response Body Restoration

## Problem

Two related bugs that compound to create hard-to-debug issues:

**Bug 1 (Silent):** `app.use('*')` middleware registered AFTER `app.route()` calls
does NOT execute for those sub-routes. No error, no warning — the middleware simply
never runs. This is a Hono v4 behavior that differs from Express.

**Bug 2 (Blank pages):** Middleware that reads `c.res.text()` for inspection/modification
consumes the ReadableStream body. If the middleware does an early return without restoring
the body, all subsequent middleware and the framework itself receive an empty Response.

## Context / Trigger Conditions

### Bug 1: Middleware not executing
- Using Hono v4 with `app.route()` for sub-applications
- Global middleware registered with `app.use('*', ...)` AFTER `app.route('/path', subApp)`
- Symptoms: middleware effects (injected HTML, headers, logging) appear on inline routes
  but NOT on sub-router routes
- Example: Login/logout button injection works on `/pool` (inline) but not on `/my-orchard` (sub-router)

### Bug 2: Blank pages
- Middleware calls `c.res.text()` to inspect HTML content
- Middleware has early return paths (e.g., `if (!html.includes('class="hud"')) return;`)
- After the early return, `c.res.body` is an exhausted ReadableStream
- Subsequent middleware or Hono's response sender gets empty body
- User sees a blank white page with correct HTTP status

## Solution

### Fix Bug 1: Register middleware BEFORE all app.route() calls

```typescript
// === Global middleware (MUST be before app.route) ===

// 1. Rate limiting
app.use('*', rateLimitMiddleware);

// 2. Page visibility / auth checks
app.use('*', pageVisibilityMiddleware);

// 3. Nav enhancement / HTML injection
app.use('*', navEnhancementMiddleware);

// === Sub-router mounting (AFTER all global middleware) ===
app.route('/admin', adminRoutes);          // line 1437
app.route('/my-orchard', orchardRoutes);   // line 1443
app.route('/auth', authRoutes);            // line 1544
// ... all other app.route() calls
```

Add a comment warning to prevent regression:
```typescript
// ========================================
// ============================================
// Sub-router mounting
// ============================================
app.route('/admin', adminRoutes);
app.route('/my-orchard', orchardRoutes);
```

### Fix Bug 2: Always restore body after c.res.text()

Every middleware that reads `c.res.text()` MUST restore the body in ALL code paths:

```typescript
app.use('*', async (c, next) => {
  await next();

  const ct = c.res.headers.get('content-type');
  if (!ct?.includes('text/html') || !c.res.body) return;

  try {
    const html = await c.res.text();  // body consumed!

    if (!html.includes('class="hud"')) {
      // CRITICAL: restore body before returning
      c.res = new Response(html, {
        status: c.res.status,
        headers: c.res.headers,
      });
      return;
    }

    // Normal path: modify and set new Response
    const modified = html.replace('</body>', injectedContent + '</body>');
    c.res = new Response(modified, {
      status: c.res.status,
      headers: c.res.headers,
    });
  } catch {
    // If text() itself fails, body may already be consumed
    // Nothing to restore — just skip
  }
});
```

**Rule of thumb:** If you call `c.res.text()`, you MUST set `c.res = new Response(...)`
in EVERY code path that follows, including error paths and early returns.

### Related Fix: Middleware reading session without authMiddleware

Global middleware that needs user identity cannot use `getCurrentUser(c)` because
`authMiddleware` hasn't run yet. Solution: read the session cookie directly:

```typescript
import { getCookie } from 'hono/cookie';
import { validateSession } from './oauth';

app.use('*', async (c, next) => {
  // Don't use getCurrentUser(c) — authMiddleware hasn't set c.session yet
  const token = getCookie(c, 'wv_session');
  const session = token ? validateSession(token) : null;

  if (session && session.userId === '1') {
    // Village chief bypass
  }
  // ...
});
```

## Verification

### Bug 1: Middleware ordering
```bash
# Before fix: returns 200 but no injected login button in HTML
curl -s http://localhost:3000/my-orchard | grep 'auth-btn'
# (empty — middleware didn't run)

# After fix: login button present
curl -s http://localhost:3000/my-orchard | grep 'auth-btn'
# <a class="auth-btn"...>
```

### Bug 2: Body restoration
```bash
# Before fix: blank page (0 bytes body)
curl -s http://localhost:3000/pool | wc -c
# 0

# After fix: full HTML
curl -s http://localhost:3000/pool | wc -c
# 15234
```

## Example

Real-world case from production API project:

**Before (broken):**
```
Line 596:  app.use('*', bugWidgetMiddleware);     // works for inline routes only
Line 1443: app.route('/my-orchard', orchardRoutes);
Line 2157: app.use('*', navEnhancementMiddleware); // NEVER runs for /my-orchard!
Line 2203: app.use('*', pageVisibilityMiddleware); // NEVER runs for /my-orchard!
```

**After (fixed):**
```
Line 596:  app.use('*', bugWidgetMiddleware);
Line 617:  app.use('*', pageVisibilityMiddleware);  // MOVED before app.route()
Line 676:  app.use('*', navEnhancementMiddleware);   // MOVED before app.route()
Line 1443: app.route('/my-orchard', orchardRoutes);  // now covered by middleware
```

## Debugging Checklist

When global middleware doesn't work for a route:

- [ ] Is the route mounted via `app.route()`?
- [ ] Is the middleware registered AFTER that `app.route()` call?
- [ ] Does the middleware modify `c.res`? Check for body consumption without restoration
- [ ] Does the middleware rely on `c.get('session')` or similar context set by other middleware?
- [ ] Multiple middleware modifying `c.res`? Each must handle body correctly

## Notes

- This is NOT documented in Hono's official docs as of 2026-02. The behavior was confirmed
  through testing: sub-router handlers execute but middleware registered afterward does not.
- Express `app.use()` has different behavior — it applies to all subsequently defined routes
  regardless of registration order (middleware runs in definition order, not route order).
- The body consumption bug is inherent to the Web Streams API (ReadableStream is one-time read).
  It affects ANY framework using standard Response objects (Hono, Remix, SvelteKit, etc.).
- When multiple middleware all call `c.res.text()`, each one creates a new Response, so
  the chain works correctly as long as every step restores the body.

## See Also

- `hono-subrouter-route-conflict` — sub-router swallowing parent path routes (404)
- `hono-subrouter-auth-isolation` — sub-router middleware NOT inherited (auth bypass)
- `hono-503-sqlite-fk-constraint` — misleading 503 errors in Hono
- `brute-force-parallel-request-self-lock` — SPA parallel requests triggering rate limiting

## References

- [Hono Routing: app.route()](https://hono.dev/docs/api/hono#route)
- [Hono Middleware Guide](https://hono.dev/docs/guides/middleware)
- [Web Streams API: ReadableStream](https://developer.mozilla.org/en-US/docs/Web/API/ReadableStream)
