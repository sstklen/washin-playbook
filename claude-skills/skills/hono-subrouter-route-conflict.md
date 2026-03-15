---
name: hono-subrouter-route-conflict
description: |
  Fix Hono app.route() sub-router swallowing parent path routes (404 on exact match).
  Use when: (1) app.get('/path', handler) returns 404 but app.route('/path', subApp)
  is mounted, (2) sub-router handles /path/child but not /path itself,
  (3) need to serve HTML landing page at same prefix as API sub-router.
  Also covers lazy getter pattern for avoiding temporal dead zone when
  passing large const to createRoutes() before const is defined.
author: Claude Code
version: 1.0.0
date: 2026-02-14
---

# Hono Sub-Router Route Conflict

## Problem

When using `app.route('/prefix', subApp)` in Hono, registering a separate
`app.get('/prefix', handler)` for the exact path (e.g., serving an HTML page)
results in 404. The sub-router intercepts ALL requests to `/prefix*` including
the exact `/prefix` path, and does NOT fall through to subsequent route handlers
when no matching route is found internally.

## Context / Trigger Conditions

- Using Hono web framework (any version)
- `app.route('/mcp', mcpRoutes)` mounted for API endpoints like `/mcp/free`, `/mcp/proxy`
- Want to also serve HTML at `/mcp` (the mount root) — e.g., a landing/info page
- `app.get('/mcp', (c) => c.html(pageHtml))` registered AFTER `app.route()` → returns 404
- `app.get('/mcp', ...)` registered BEFORE `app.route()` → also 404 (Hono does NOT prioritize exact match over sub-router)

## Solution

### Step 1: Add handler inside the sub-router

The only reliable fix is to add the handler INSIDE the sub-router for the root path `/`:

```typescript
// mcp-http-routes.ts
export function createMcpRoutes(getLandingHtml?: () => string): Hono {
  const mcp = new Hono();

  // Handle GET / (maps to /mcp in the parent app)
  if (getLandingHtml) {
    mcp.get('/', (c) => c.html(getLandingHtml()));
  }

  // Existing API routes
  mcp.all('/free', async (c) => { /* ... */ });
  mcp.all('/proxy', async (c) => { /* ... */ });

  return mcp;
}
```

### Step 2: Use lazy getter to avoid temporal dead zone

If the HTML const is defined AFTER the `createRoutes()` call in the source file
(common in large files where route registration happens early but page HTML is
defined later), passing the const directly will cause a `ReferenceError`.

**Wrong** (temporal dead zone):
```typescript
// Line 2397
const mcpRoutes = createMcpRoutes(MCP_PAGE_HTML);  // ReferenceError!
app.route('/mcp', mcpRoutes);

// Line 3944
const MCP_PAGE_HTML = `<!DOCTYPE html>...`;  // defined too late
```

**Correct** (lazy getter):
```typescript
// Line 2397
const mcpRoutes = createMcpRoutes(() => MCP_PAGE_HTML);  // closure, evaluated later
app.route('/mcp', mcpRoutes);

// Line 3944
const MCP_PAGE_HTML = `<!DOCTYPE html>...`;  // safe: accessed at request time
```

The closure captures the variable reference. By the time an HTTP request arrives,
all module-level code has executed and `MCP_PAGE_HTML` is initialized.

### Step 3: Remove the dead route

Remove any `app.get('/prefix', handler)` registered outside the sub-router — it will
never be reached and is dead code.

## Verification

```bash
# Start server
bun run src/api/http-server.ts &
sleep 3

# Test the routes
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:3000/mcp      # Should be 200
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:3000/mcp/free  # Should be 406 (MCP needs POST)
```

## Example

Real-world scenario from production API project:

```
Before (404):
  app.route('/mcp', mcpRoutes);     // line 2398 — catches ALL /mcp*
  ...
  app.get('/mcp', (c) => c.html(MCP_PAGE_HTML));  // line 4185 — NEVER reached

After (200):
  const mcpRoutes = createMcpRoutes(() => MCP_PAGE_HTML);  // lazy getter
  app.route('/mcp', mcpRoutes);     // sub-router now handles GET / internally
  // No separate app.get('/mcp') needed
```

## Notes

- This is NOT a Hono bug — it's by design. Sub-routers own their entire path prefix.
- `app.route('/prefix', subApp)` maps `/prefix` → `/` in the sub-app,
  `/prefix/child` → `/child` in the sub-app.
- The sub-app's internal 404 does NOT propagate back to try other handlers in the parent.
- This pattern applies to any framework with similar sub-router mounting (Express `app.use()`
  has the same behavior).
- The lazy getter pattern is useful whenever you need to pass a value that's defined
  later in the same module but only accessed asynchronously (e.g., at request time).
- `/mcp/` (with trailing slash) may still 404 — this is a separate Hono trailing slash behavior.

## See Also

- `hono-subrouter-auth-isolation` — sub-router middleware NOT inherited (auth bypass)
- `hono-503-sqlite-fk-constraint` — another Hono debugging skill
- `mcp-http-adapter-pattern` — MCP HTTP adapter architecture

## References

- [Hono Routing Documentation](https://hono.dev/docs/api/routing)
- [Hono Sub-Application (app.route)](https://hono.dev/docs/api/hono#route)
