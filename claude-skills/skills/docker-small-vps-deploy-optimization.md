---
name: docker-small-vps-deploy-optimization
description: |
  修復小型 VPS (2GB RAM) 上 Docker build 導致的部署災難：OOM kill、服務 down、SSH 斷線。
  使用時機：
  1. Docker build 在小 VPS 上花 20-30+ 分鐘
  2. Build 過程中服務當掉（OOM kill）
  3. `chown -R` 步驟花 35+ 分鐘（node_modules 幾萬個檔案）
  4. SSH/終端機在 build 期間斷線
  5. 每次改一行代碼都要完整 rebuild
  涵蓋：Dockerfile --chown 優化、Volume mount 免 rebuild、部署腳本設計、
  2GB VPS 記憶體規劃、multi-agent AI collaboration部署方案評估。
author: Claude Code + Gemini + Research Scout
version: 1.0.0
date: 2026-02-15
---

# Docker 小型 VPS 部署優化（2GB RAM）

## Problem

在 2GB RAM 的 VPS（如 AWS Lightsail $12/月）上，Docker Compose 部署 Bun/Node.js 應用時：
- `docker compose build` 花 20-30+ 分鐘
- Build 過程吃光記憶體，導致正在運行的服務被 OOM kill
- 網站在部署期間 down 掉
- SSH 連線也因為記憶體不足而斷線
- `chown -R` 單一步驟就花 35 分鐘（2148 秒）

## Context / Trigger Conditions

- VPS RAM ≤ 2GB
- Docker multi-stage build（deps + app）
- 使用 `bun install` 或 `npm install`（產生大量 node_modules 小檔案）
- Dockerfile 有 `RUN chown -R user:group /app`（對 node_modules 逐檔改權限）
- 每次代碼變更都跑 `docker compose up -d --build`
- 使用 `--no-cache` 更是災難

### 瓶頸分析（實測數據）

| 步驟 | 耗時 | 原因 |
|------|------|------|
| `bun install --frozen-lockfile` | 372s | 在 2GB 機器上安裝依賴 |
| `COPY --from=deps node_modules` | 1369s | 複製幾萬個小檔案 |
| `chown -R washin:washin /app` | 2148s | 逐一改變幾萬個檔案的擁有者 |
| **總計** | **~65 分鐘** | 2GB 機器的 I/O + CPU 限制 |

## Solution

### 修復 1：Dockerfile — 用 `--chown` 取代 `chown -R`（省 35 分鐘）

**根因：** `RUN chown -R user:group /app` 要對 node_modules 裡幾萬個檔案逐一改權限。

**修復：** 先建用戶，再用 `COPY --chown` 在複製時直接設定擁有者。

```dockerfile
# ❌ 舊的（慢 35 分鐘）
FROM oven/bun:1.3-slim
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY src/ ./src/
RUN mkdir -p data/credits
RUN groupadd -r washin && useradd -r -g washin -s /bin/false washin
RUN chown -R washin:washin /app   # ← 這行花 35 分鐘！
USER washin

# ✅ 新的（幾乎 0 秒）
FROM oven/bun:1.3-slim
RUN groupadd -r washin && useradd -r -g washin -s /bin/false washin  # 先建用戶
WORKDIR /app
RUN mkdir -p data/credits && chown -R washin:washin data  # 只 chown 空目錄
COPY --chown=washin:washin --from=deps /app/node_modules ./node_modules
COPY --chown=washin:washin src/ ./src/
# ... 其他 COPY 也加 --chown
USER washin
```

### 修復 2：Volume Mount — 代碼變更不需 rebuild（3 秒部署）

**根因：** 每次改一行 TypeScript 都要完整 rebuild Docker image。

**修復：** 在 `docker-compose.yml` 中把 `src/` 掛為唯讀 volume。

```yaml
services:
  api:
    build: .
    volumes:
      - washin-data:/app/data          # 持久化資料（原有）
      - ./src:/app/src:ro              # 代碼即時生效（新增）
      - ./characters:/app/characters:ro
      - ./public:/app/public:ro
```

**日常部署流程：**
```bash
git pull origin main && docker compose -f docker-compose.yml restart api
# 3 秒搞定，不需 build，不會 OOM，不會 down
```

**完整 rebuild（僅 package.json 變了時）：**
```bash
docker compose -f docker-compose.yml up -d --build
```

### 修復 3：deploy.sh 腳本設計

```bash
#!/bin/bash
# 快速部署（預設）：git pull + restart = 3 秒
# 完整部署（--build）：重建 image = 僅 deps 變了時用

if [ "$1" = "--build" ]; then
    docker compose -f docker-compose.yml build api
    docker compose -f docker-compose.yml up -d
else
    docker compose -f docker-compose.yml restart api
fi
```

## Verification

```bash
# 確認 volume mount 生效（容器內能看到最新代碼）
docker exec myapp-api grep "某個新改的字串" /app/src/api/http-server.ts

# 確認 health check
docker inspect --format='{{.State.Health.Status}}' myapp-api
# 期望輸出：healthy
```

## Notes

### Volume Mount 注意事項
- **權限：** 容器內用戶可能無法讀取 host 上的檔案。使用 `:ro`（唯讀）較安全
- **node_modules 不要掛 volume：** 留在 image 裡，避免大量小檔案的 I/O 問題
- **Bun --hot 不支援：** Docker volume mount 的 fs events 不會傳到容器內（Bun issue #9300），但 restart 方式不受影響
- **首次啟用：** 改了 docker-compose.yml 後需跑一次 `docker compose up -d`（不是 restart）讓 volume mount 生效

### 2GB VPS 記憶體規劃
| 組件 | 記憶體 |
|------|--------|
| Docker daemon | 50-80MB |
| Caddy 容器 | 50-80MB |
| Bun API 容器 | 100-200MB |
| OS + 系統 | 200-400MB |
| **可用空間** | ~1.2-1.6GB |
| **Docker build 時** | 吃光全部 → OOM |

### Long-term solution (multi-agent consensus)
- **短期：** Volume mount + --chown 修復（本 skill）
- **中期：** `bun build --compile` 本地編譯二進制，VPS 只要複製
- **長期：** 評估 systemd 取代 Docker（省 300MB+，Bun 官方推薦）

### `--no-cache` 的陷阱
`docker compose build --no-cache` 在小 VPS 上絕對不要用！它會：
1. 重新下載所有基礎映像
2. 重新安裝所有 node_modules
3. 重新複製所有檔案
4. 耗時 30-60+ 分鐘
5. 吃光記憶體導致所有服務 down

### Docker build context 快取失效
`docker compose build`（有快取）有時也不偵測到 `src/` 的變化。
原因：git pull 不一定改變檔案時間戳。
解法（已被 volume mount 取代）：`touch src/` 在 build 前觸碰檔案。

## Example

**場景：** 和心村 API（Bun + Hono）部署在 AWS Lightsail 2GB

**之前（災難）：**
```
改一行代碼 → docker compose build → 30 分鐘
→ 記憶體吃光 → 服務 OOM killed → 網站 down
→ SSH 斷線 → 只能去 Lightsail Console 重連
```

**之後（3 秒）：**
```
改一行代碼 → git push → VPS: git pull + restart → 3 秒
→ 零記憶體消耗 → 服務不中斷 → 完美
```

## References

- [Bun 官方 Docker 指南](https://bun.com/docs/guides/ecosystem/docker)
- [Bun 官方 systemd 部署](https://bun.sh/guides/ecosystem/systemd)
- [Docker COPY --chown 文檔](https://docs.docker.com/reference/dockerfile/#copy---chown---chmod)
- [Docker Compose Volume Mount](https://docs.docker.com/compose/how-tos/volumes/)
- [Bun Docker fs events 問題 #9300](https://github.com/oven-sh/bun/issues/9300)
- [最小 Bun Docker 映像實踐](https://blog.dejangegic.com/smallest-bun-docker-image)
- See also: `docker-static-asset-copy-gotcha` — Docker 靜態資源 404 問題
- See also: `docker-compose-force-recreate-caddy-loop` — Docker Compose 無限重啟迴圈
- See also: `docker-ghost-container-recovery` — 中斷 build 後的幽靈容器清除
- See also: `vps-deploy-workflow` — 和心村完整部署流程
