---
name: hono-subrouter-auth-isolation
description: |
  Fix CRITICAL auth bypass when multiple Hono sub-routers are mounted at similar paths.
  Use when: (1) admin API has authentication middleware but new routes bypass it,
  (2) mounting independent Hono instances via app.route() for admin endpoints,
  (3) security audit finds unauthenticated admin routes despite middleware existing,
  (4) adding new admin sub-routers to an existing Hono app with auth.
  Symptom: POST/GET to /admin/api/newfeature works without password while
  /admin/api/existing requires password. Root cause: Hono sub-routers don't
  inherit middleware from sibling sub-routers.
author: Claude Code
version: 1.0.0
date: 2026-02-16
---

# Hono Sub-Router Auth Isolation

## Problem

When you create a new Hono sub-router for admin features and mount it at
`/admin/api/something`, it does NOT inherit authentication middleware from
an existing admin sub-router mounted at `/admin`. Each `new Hono()` instance
is completely independent. This creates a CRITICAL security vulnerability
where new admin endpoints are publicly accessible without any authentication.

## Context / Trigger Conditions

- Hono web framework (any version)
- Existing admin router with auth middleware:
  ```typescript
  const admin = new Hono();
  admin.use('/api/*', adminAuthMiddleware);
  admin.get('/api/users', ...);  // protected
  app.route('/admin', admin);
  ```
- NEW feature router created independently:
  ```typescript
  const featureAdmin = new Hono();
  featureAdmin.get('/', ...);   // NO middleware!
  featureAdmin.post('/', ...);  // NO middleware!
  app.route('/admin/api/feature', featureAdmin);
  ```
- Result: `/admin/api/feature` is publicly accessible, no password needed
- Often discovered during security audit: "admin endpoint missing auth"

## Solution

### Option 1: Add middleware directly to the new sub-router (Recommended)

```typescript
import { adminAuthMiddleware } from './admin/middleware';

export function createFeatureAdminRoutes(): Hono {
  const admin = new Hono();
  admin.use('/*', adminAuthMiddleware);  // Add auth to THIS instance
  admin.get('/', (c) => { ... });
  admin.post('/', async (c) => { ... });
  return admin;
}
```

### Option 2: Mount inside the existing admin router

Instead of mounting on the main app, mount inside the admin sub-router:

```typescript
// admin-ui.ts
const admin = new Hono();
admin.use('/api/*', adminAuthMiddleware);

// Mount feature routes INSIDE admin router (inherits middleware)
const featureRoutes = createFeatureRoutes();  // no auth needed inside
admin.route('/api/feature', featureRoutes);

app.route('/admin', admin);
```

### Why This Happens

```
Hono architecture:

main app (app)
  ├── admin sub-router (new Hono())          ← has adminAuthMiddleware
  │     ├── GET  /api/users                   ← PROTECTED
  │     └── POST /api/config                  ← PROTECTED
  │
  └── feature sub-router (new Hono())        ← NO middleware!
        ├── GET  /                            ← UNPROTECTED!
        └── POST /                            ← UNPROTECTED!

When mounted as:
  app.route('/admin', admin);                 // admin's middleware covers /admin/*
  app.route('/admin/api/feature', feature);   // feature is INDEPENDENT, no middleware
```

The path `/admin/api/feature` matches the feature sub-router FIRST (more specific
path wins in Hono). The admin sub-router's middleware at `/admin/api/*` never runs
because the request is handled by a completely different Hono instance.

### Key Insight: Path matching != middleware inheritance

In Hono, `app.route()` creates isolated routing contexts. Unlike some frameworks
where middleware on a parent path applies to all children, Hono's sub-routers
are **siblings**, not parent-child. Each must declare its own middleware.

## Verification

```bash
# Without fix — should fail but returns 200:
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/admin/api/feature
# Expected: 401 (unauthorized)
# Actual (bug): 200 (full access!)

# After fix:
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/admin/api/feature
# Expected: 401 or 403
```

## Example

Real-world case from production API project:

**Before (CRITICAL vulnerability):**
```typescript
// equipment-shop.ts — NO auth!
export function createEquipmentAdminRoutes(): Hono {
  const admin = new Hono();
  // Missing: admin.use('/*', adminAuthMiddleware)
  admin.get('/', (c) => { /* lists all equipment */ });
  admin.post('/', async (c) => { /* creates equipment */ });
  return admin;
}

// http-server.ts — mounted directly, bypasses admin auth
app.route('/admin/api/equipment', createEquipmentAdminRoutes());
```

**After (fixed):**
```typescript
// equipment-shop.ts — auth added
import { adminAuthMiddleware } from './admin/middleware';

export function createEquipmentAdminRoutes(): Hono {
  const admin = new Hono();
  admin.use('/*', adminAuthMiddleware);  // One line fix
  admin.get('/', (c) => { /* lists all equipment */ });
  admin.post('/', async (c) => { /* creates equipment */ });
  return admin;
}
```

## Checklist: Adding New Admin Routes

When creating any new admin sub-router:

- [ ] Does the new Hono instance have `admin.use('/*', adminAuthMiddleware)`?
- [ ] Or is it mounted INSIDE an existing admin router that has middleware?
- [ ] Test: Can I access the endpoint WITHOUT the admin password?
- [ ] Test: Does it return 401/403 from a non-localhost IP without password?

## Notes

- This is NOT a Hono bug. It's by design: sub-routers are isolated instances.
- Express has the same behavior with `express.Router()`.
- The fix is always one line: `admin.use('/*', adminAuthMiddleware)`.
- Consider creating a shared `createAuthenticatedAdmin()` factory function
  that pre-applies the middleware to prevent this pattern:
  ```typescript
  function createAuthenticatedAdmin(): Hono {
    const admin = new Hono();
    admin.use('/*', adminAuthMiddleware);
    return admin;
  }
  ```
- CORS middleware on `/admin/api/*` does NOT provide authentication.
  CORS only restricts browser-initiated requests. `curl` and server-to-server
  requests bypass CORS entirely.

## See Also

- `hono-subrouter-route-conflict` -- sub-router path conflicts (404 on exact match)
- `bun-async-race-condition-pattern` -- race conditions in async handlers
- `api-security-audit-methodology` -- comprehensive API security audit

## References

- [Hono Routing: app.route()](https://hono.dev/docs/api/hono#route)
- [Hono Middleware](https://hono.dev/docs/guides/middleware)
- [OWASP A01:2021 - Broken Access Control](https://owasp.org/Top10/A01_2021-Broken_Access_Control/)
