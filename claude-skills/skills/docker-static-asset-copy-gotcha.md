---
name: docker-static-asset-copy-gotcha
description: |
  Fix static assets (images, fonts, CSS, WebP) returning 404 in Docker container
  but working fine in local development. Use when:
  (1) Background images, NPC avatars, or other static files show 404 only in production/Docker,
  (2) Added a new directory outside src/ (public/, static/, assets/, data/) but forgot to update Dockerfile,
  (3) "Works on my machine" — local dev reads filesystem directly, Docker only has what COPY brings in,
  (4) Multi-stage Docker build silently drops directories not explicitly copied.
  Root cause: Dockerfile COPY instructions are selective — new directories must be explicitly added.
version: 1.0.0
date: 2026-02-13
---

# Docker Static Asset COPY Gotcha

## Problem

Static assets (images, WebP, fonts, CSS files) return 404 in a Docker container
but work perfectly in local development. This happens because local dev reads
from the filesystem directly, while Docker containers only contain files
explicitly `COPY`-ed in the Dockerfile.

## Context / Trigger Conditions

- You added a new directory like `public/`, `static/`, or `assets/` to the project
- Local development works perfectly (`bun run dev` / `npm run dev`)
- After `docker build` + `docker run`, static assets return 404
- The server code is correct — it has routes serving `/assets/*` or similar
- The Dockerfile was written before the new directory existed

**Typical error pattern:**
```
GET /assets/images/bg-gate.webp  → 404 (Docker)
GET /assets/images/bg-gate.webp  → 200 (local)
```

## Solution

### Step 1: Check the Dockerfile

Look at what directories are being `COPY`-ed:

```dockerfile
# Typical Dockerfile — notice public/ is MISSING
COPY package.json bun.lock ./
COPY src/ ./src/
# Missing: COPY public/ ./public/
```

### Step 2: Add the missing COPY

```dockerfile
COPY package.json bun.lock ./
COPY src/ ./src/
COPY public/ ./public/    # <-- ADD THIS
```

### Step 3: Rebuild and deploy

```bash
docker build -t myapp .
docker run -p 3000:3000 myapp
```

### Prevention Checklist

Every time you add a non-`src/` directory to your project, check:

- [ ] Is this directory referenced by server code at runtime?
- [ ] Is it in the Dockerfile `COPY` instructions?
- [ ] If using `.dockerignore`, is it NOT excluded?
- [ ] If multi-stage build, is it copied to the final stage?

## Verification

```bash
# Check what's inside the container
docker exec <container> ls -la /app/public/images/

# Or test the endpoint
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/assets/images/bg-gate.webp
# Should return 200, not 404
```

## Example

**Real-world incident (2026-02-13, Washin Village):**

Added `public/images/` with 6 WebP files (DQ-style backgrounds + NPC avatars).
Server code in `http-server.ts` had `/assets/*` static route working perfectly
in local dev. After Docker deploy to AWS Lightsail, all 6 images returned 404.

**Root cause:** Dockerfile only had `COPY src/ ./src/` — no `COPY public/ ./public/`.

**Fix:** Added one line to Dockerfile:
```dockerfile
COPY public/ ./public/
```

**Time wasted:** ~15 minutes debugging before realizing it was deployment, not code.

## Notes

- This is NOT limited to images — applies to any runtime-accessed file outside `src/`
  (templates, config files, data directories, migration scripts, etc.)
- Common directories that get forgotten: `public/`, `static/`, `assets/`, `data/`,
  `scripts/`, `templates/`, `migrations/`
- In multi-stage builds, check BOTH the build stage AND the production stage
- `.dockerignore` can also silently exclude directories
- Add a note to your project's CLAUDE.md or README to prevent recurrence
- Consider using a wildcard pattern if your project frequently adds directories:
  ```dockerfile
  # Copy everything except node_modules
  COPY . .
  ```
  But be careful — this may include unwanted files (secrets, test data, etc.)

## See also

- Project CLAUDE.md should document this requirement for the team
- `railway-fastapi-deployment` skill — similar deployment gotchas for Railway
