---
name: cloudflare-tunnel-mobile-preview
description: |
  快速建立公開 URL 讓手機或遠端設備訪問本地開發伺服器。使用情境：(1) 手機無法連接 localhost，
  (2) 需要讓客戶/業主遠端預覽開發中的網站，(3) ngrok 需要登入但沒有帳號，
  (4) 需要 HTTPS 連線測試 PWA 或相機等功能。無需註冊、免費、一行指令搞定。
author: Claude Code
version: 1.0.0
date: 2026-01-29
tags: [cloudflare, tunnel, mobile, preview, localhost, remote-access]
---

# Cloudflare Tunnel 手機預覽本地開發伺服器

## Problem
開發 Next.js/React 等前端專案時，想用手機測試但：
- `localhost:3000` 手機連不到
- 區域網路 IP（如 `192.168.x.x`）有時不通（防火牆、不同網段）
- ngrok 現在強制要登入才能用
- 需要 HTTPS 才能測試某些功能（PWA、相機、地理位置等）

## Context / Trigger Conditions
- 用戶說「手機連不上」或「想用手機測試」
- 區域網路 IP 訪問失敗
- 需要讓非同網路的人預覽網站（客戶、業主）
- 需要 HTTPS 環境測試

## Solution

### 前置條件
```bash
# 確認已安裝 cloudflared
brew install cloudflared

# 或檢查是否已安裝
which cloudflared
```

### 一行指令啟動
```bash
# 假設本地伺服器在 port 3000
cloudflared tunnel --url http://localhost:3000
```

### 取得公開 URL
```bash
# 背景執行並取得 URL
cloudflared tunnel --url http://localhost:3000 > /tmp/cloudflared.log 2>&1 &
sleep 5
grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' /tmp/cloudflared.log | head -1
```

輸出範例：
```
https://event-ignored-eating-parking.trycloudflare.com
```

## Verification
1. 複製產生的 `https://xxx.trycloudflare.com` URL
2. 在手機瀏覽器打開
3. 應該能看到本地開發中的網站

## Example

```bash
# 完整流程
$ cd my-nextjs-project
$ npm run dev &
# Next.js 啟動在 localhost:3000

$ cloudflared tunnel --url http://localhost:3000
# 等待幾秒後會顯示：
# Your quick Tunnel has been created! Visit it at:
# https://random-words.trycloudflare.com

# 把這個 URL 發給手機或任何人
```

## Notes

### 優點
- **免註冊**：不需要 Cloudflare 帳號
- **免費**：Quick Tunnels 完全免費
- **HTTPS**：自動提供 SSL 憑證
- **全球可訪問**：不限同一網路
- **隨機 URL**：每次啟動會產生新的 URL

### 限制
- URL 每次重啟會改變（Quick Tunnel 特性）
- 電腦關機或終止程序後 URL 失效
- 如需固定 URL 需要註冊 Cloudflare 帳號

### 對比其他工具
| 工具 | 免註冊 | 免費 | HTTPS | 固定 URL |
|------|--------|------|-------|----------|
| **Cloudflare Tunnel** | ✅ | ✅ | ✅ | ❌（需註冊）|
| ngrok | ❌ | ⚠️ 限制 | ✅ | ❌（需付費）|
| localtunnel | ✅ | ✅ | ✅ | ⚠️ 可能被佔用 |

### 常見問題
**Q: 為什麼 URL 這麼奇怪？**
A: Quick Tunnel 會自動產生隨機單詞組合的 URL，這是正常的。

**Q: 可以指定 URL 嗎？**
A: Quick Tunnel 不行，需要註冊 Cloudflare 帳號並設定 Named Tunnel。

**Q: 安全嗎？**
A: URL 是隨機的很難猜到，但仍建議只在測試時使用，測試完畢就關閉。

## References
- [Cloudflare Tunnel 官方文檔](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
- [Quick Tunnels](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/do-more-with-tunnels/trycloudflare/)
