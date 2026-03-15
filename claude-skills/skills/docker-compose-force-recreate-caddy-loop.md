---
name: docker-compose-force-recreate-caddy-loop
description: |
  Fix Docker Compose watchdog/auto-restart scripts that use --force-recreate causing
  an infinite restart loop where Caddy (or any reverse proxy with depends_on: condition: service_healthy)
  gets stuck in "Created" state and never starts.
  Use when:
  (1) Caddy container shows "Created" but never "Up" after docker compose up -d,
  (2) Watchdog or auto-restart cron script keeps recreating containers every few minutes,
  (3) Cloudflare returns 502/521 but the API container is healthy,
  (4) docker ps shows reverse proxy as "Created" while API is "Up (healthy)",
  (5) VPS goes down during docker compose build (CPU exhaustion on small instances).
  Root cause: --force-recreate with -d flag + depends_on health condition = proxy never starts.
  Also covers: VPS recovery after Docker build CPU exhaustion, Lightsail browser SSH tips.
version: 1.0.0
date: 2026-02-15
---

# Docker Compose --force-recreate Caddy Loop

## Problem

Watchdog or auto-restart scripts that use `docker compose up -d --force-recreate` cause an
infinite restart loop. The reverse proxy (Caddy) gets stuck in "Created" state and never
starts, while the API container is healthy. This creates a 502/521 from Cloudflare.

## Context / Trigger Conditions

- `docker ps -a` shows Caddy as **"Created"** (not "Up", not "Exited")
- API container shows **"Up (healthy)"**
- Cloudflare returns **502** (Bad Gateway) or **521** (Web Server Down)
- A cron job runs a watchdog script every few minutes
- The watchdog script uses `--force-recreate` flag
- `docker-compose.yml` has `depends_on: condition: service_healthy`

## Root Cause

The chain of failure:

```
1. watchdog detects Caddy not running
2. watchdog runs: docker compose up -d --force-recreate
3. --force-recreate KILLS the healthy API container and recreates it
4. New API container starts but needs time to pass healthcheck
5. Caddy depends on API being healthy (depends_on: condition: service_healthy)
6. With -d flag, docker compose returns immediately
7. API is not yet healthy → Caddy is created but NOT started
8. Caddy stays in "Created" state forever
9. 3 minutes later → watchdog detects Caddy not running → GOTO step 2
10. INFINITE LOOP
```

## Solution

### Immediate Fix (restore service)

```bash
# Start the stuck Caddy container manually
docker start app-caddy
```

### Root Fix (prevent recurrence)

Remove `--force-recreate` from the watchdog script:

```bash
# One-liner fix
sed -i 's/--force-recreate //' ~/watchdog.sh
```

Without `--force-recreate`, `docker compose up -d` will:
- Start stopped containers (including stuck "Created" Caddy)
- Leave already-running healthy containers alone
- Only recreate containers whose config has changed

### Advanced Fix (smart restart logic)

For even better behavior, replace the single restart command with conditional logic:

```bash
# In watchdog.sh, replace:
docker compose -f docker-compose.yml up -d --force-recreate

# With:
if [ "$API_RUNNING" = "true" ] && [ "$API_HEALTH" = "healthy" ] && [ "$CADDY_RUNNING" != "true" ]; then
    # Only Caddy is down, API is fine — just start Caddy
    docker start app-caddy || docker compose -f docker-compose.yml up -d caddy
else
    # API is down — full restart (without --force-recreate!)
    docker compose -f docker-compose.yml up -d
fi
```

## Verification

```bash
# 1. Confirm --force-recreate is removed
grep "force-recreate" ~/watchdog.sh
# Should return nothing

# 2. Check both containers are running
docker ps --format 'table {{.Names}}\t{{.Status}}'
# Should show both "Up" with Caddy having port mappings

# 3. Check website
curl -s -o /dev/null -w "%{http_code}" https://your-domain.com/health
# Should return 200
```

## Related: VPS Docker Build CPU Exhaustion

### Symptom
Running `docker compose up -d --build` on a small VPS ($5-$12/month, 1-2 vCPU)
causes the instance to become unresponsive. SSH disconnects, website goes 502.

### Why
`bun install` (or `npm install`) of 500+ packages during Docker build consumes
100% CPU for 5-10 minutes on small instances.

### Recovery
1. Wait 3-5 minutes (build may complete on its own)
2. If still down → Reboot from cloud console (Lightsail/EC2)
3. After reboot: `docker start app-caddy` (Caddy is usually the one stuck)
4. If containers don't exist: `docker compose -f docker-compose.yml up -d`

### Prevention
- After first build, the `bun install` layer is cached → subsequent builds are fast
- Use `screen` or `tmux` before building so SSH disconnect doesn't kill the process:
  ```bash
  screen -S deploy
  docker compose -f docker-compose.yml up -d --build
  # If disconnected: screen -r deploy
  ```

## Related: Lightsail Browser SSH Limitations

- **Cannot paste multi-line commands**: Heredocs, multi-line Python, etc. will break
- **Tab completion triggers on `>`**: Heredoc continuation prompts trigger file listing
- **Workaround**: Write scripts to `/tmp/` as single files, then execute them
- **Best practice**: Use single-line commands, or `sed -i` for simple replacements

## Notes

- This bug is specific to `docker compose up -d` (detached mode) combined with
  `depends_on: condition: service_healthy`. In foreground mode (`-d` removed),
  Docker Compose waits for dependencies to be met.
- The `restart: unless-stopped` policy does NOT help here because the container
  was never started (it's "Created", not "Exited").
- Multiple cron scripts (watchdog + auto-deploy) can interfere with each other.
  Always check for lock files and ensure watchdog respects deploy locks.

See also: `docker-static-asset-copy-gotcha` (Dockerfile COPY issues)
See also: `docker-ghost-container-recovery` — 中斷 build 後的幽靈容器清除
See also: `vps-deploy-workflow` — 和心村完整部署流程
