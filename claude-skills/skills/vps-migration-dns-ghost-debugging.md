---
name: vps-migration-dns-ghost-debugging
description: |
  VPS 搬家後新端點全部 404，但舊端點正常 — 因為 Cloudflare DNS 還指向舊 VPS（舊機器還在跑）。
  使用時機：
  1. 部署新功能到 VPS，Docker 容器內測試正常，但外部 curl 全部 404
  2. 同一台 VPS 上的舊端點正常、新端點 404（「部分正常部分壞」的混淆假象）
  3. VPS 搬家/換 IP 後部署新功能
  4. `--resolve` 繞過 CDN 直連 VPS 能正常但走 CDN 不行
  5. 比較 /health 的 uptime 發現數字不合理（太長或太短）
author: Claude Code
version: 1.0.0
date: 2026-02-21
---

# VPS Migration DNS Ghost Debugging

## Problem

VPS 搬家後，Cloudflare（或任何 CDN/DNS 代理）的 A 記錄仍指向舊 IP。舊 VPS 還在運行舊代碼，導致：
- **新端點** → 404（舊代碼沒有）
- **舊端點** → 正常（舊代碼有）
- 造成「部分端點正常部分 404」的極度混淆假象

## Context / Trigger Conditions

- 剛做完 VPS 搬家（換機器、換 IP）
- 部署了新功能，Docker 容器內測試全部通過
- 外部 `curl https://domain/new-endpoint` → 404
- 外部 `curl https://domain/old-endpoint` → 200（正常）
- 用 `--resolve` 直連新 VPS IP 則新端點正常

## Solution

### 快速診斷三步法

**Step 1: 比較 uptime**
```bash
# 外部（走 Cloudflare）
curl -s https://domain/health | jq '.runtime.uptime'
# → "2h 18m"  ← 如果這數字跟你剛重啟的容器不符，就是打到別台機器

# 新 VPS 容器啟動時間
ssh vps "docker compose logs app 2>&1 | grep '啟動\|started' | tail -1"
# → 07:46:33  ← 幾分鐘前，uptime 應該是幾分鐘，不是 2 小時
```

**Step 2: --resolve 繞過 CDN 直連**
```bash
# 繞過 Cloudflare，直連新 VPS
curl -sk "https://domain/new-endpoint" --resolve "domain:443:NEW_VPS_IP"
# → 200 ✅  ← 新 VPS 正常

# 走 Cloudflare
curl -s "https://domain/new-endpoint"
# → 404 ❌  ← Cloudflare 打到舊 VPS
```

**Step 3: 確認新 VPS 公網 IP**
```bash
ssh vps "curl -s4 ifconfig.me"
# → 203.0.113.10  ← 可能跟你以為的 IP 不同！
```

### 修復

1. 登入 Cloudflare Dashboard → DNS → Records
2. 找到對應的 A 記錄
3. 更新 IP 為新 VPS 的公網 IP
4. 等待生效（通常幾秒，Cloudflare proxied 模式下）

### 善後

- 更新所有記錄中的 IP（CLAUDE.md、文件、腳本）
- 考慮關閉舊 VPS（避免浪費資源和安全風險）
- 如果有 AAAA（IPv6）記錄也要一起更新

## Verification

```bash
# 確認 DNS 已切換（uptime 應該很短）
curl -s https://domain/health | jq '.runtime.uptime'
# → "2m"  ← 對了，是新 VPS

# 新端點正常
curl -s https://domain/new-endpoint
# → 200 ✅
```

## Example

實際案例（2026-02-21 a production API deployment）：

1. 新 VPS IP: `203.0.113.10`，舊 VPS IP: `203.0.113.20`
2. Cloudflare A 記錄仍指向 `203.0.113.20`
3. 新端點 `/api/v2/debug-ai` → 404（舊 VPS 沒有這個路由）
4. 舊端點 `/api/v2/task` → 200（舊 VPS 有）
5. 排查 30 分鐘，最終通過比較 uptime 和 `--resolve` 確認

## Notes

- **為什麼排查困難：** 舊端點正常會讓人以為「代碼有問題」而不是「打錯機器」
- **SSH host key 變更是線索：** VPS 搬家後 SSH 報 host key 變更，這就是換了機器的信號
- **防範：** VPS 搬家 checklist 第一條就是更新 DNS
- **Hono feature flag 陷阱：** `createRouter()` 裡 `if (!isFeatureEnabled(...))` 在啟動時一次性判斷，之後改 flag 不生效。改用 `router.use()` middleware 每次請求即時檢查
- See also: `vps-deploy-workflow`, `multi-layer-proxy-timeout-chain-debugging`
