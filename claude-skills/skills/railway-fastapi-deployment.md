---
name: railway-fastapi-deployment
description: |
  Railway 部署 FastAPI 服務的完整流程和常見陷阱。使用時機：(1) 部署 Python FastAPI 到 Railway，
  (2) 遇到 "pip: command not found" 或 "No module named pip" 錯誤，(3) Monorepo 多服務部署，
  (4) 建置成功但部署狀態 FAILED，(5) railway up 用了錯誤的 nixpacks.toml，
  (6) 需要 --path-as-root 部署子目錄，(7) RAILWAY_ROOT_DIRECTORY 環境變數無效，
  (8) Monorepo watchPatterns 卡在錯誤的路徑，(9) 需要用 GraphQL API 設定 rootDirectory，
  (10) --path-as-root 部署 FAILED 且無 build logs（靜默失敗），cd 進子目錄部署反而成功。
  涵蓋 Nixpacks 配置、Monorepo 模式、環境變數、CLI 操作、GraphQL API 進階設定。
author: Washin Village + Claude
version: 3.1.0
date: 2026-02-06
---

# Railway FastAPI 部署指南

## Problem

部署 FastAPI 服務到 Railway 時，常遇到：
1. Nixpacks 自訂 `phases.install` 導致 pip 不在 PATH
2. Monorepo 中 `railway up` 用了根目錄的 nixpacks.toml 而非子目錄的
3. 建置成功 + Healthcheck 通過，但部署狀態 FAILED
4. 環境變數變更後自動重部署全部失敗
5. Token 類型混淆（Project Token vs Account Token）

## Context / Trigger Conditions

- 使用 Railway CLI 部署 Python/FastAPI 服務
- 遇到 `pip: command not found` 或 `No module named pip` 錯誤
- Monorepo 結構（`apps/api/`, `apps/bot/` 等子目錄）
- 建置日誌顯示 SUCCESS 但 `railway deployment list` 顯示 FAILED
- Pydantic Settings 驗證失敗（缺少環境變數）

## Solution

### 1. Nixpacks 配置（最關鍵！）

**根因：** 當你自訂 `phases.install` 時，會繞過 Python provider 的 venv 設定，
導致 `pip` 不在 PATH 中。

**❌ 錯誤配置（pip 不在 PATH）：**
```toml
providers = ["python"]

[phases.setup]
nixPkgs = ["python311"]

[phases.install]
cmds = ["pip install -r requirements.txt"]  # ← pip 找不到！
```

**✅ 正確配置（讓 Python provider 自動處理）：**
```toml
# nixpacks.toml — 不要覆蓋 phases.install！
providers = ["python"]

[phases.setup]
nixPkgs = ["python311", "gcc"]

[start]
cmd = "uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000}"
```

**原理：**
- nixpacks Python provider 會自動偵測 `requirements.txt`
- 自動建立 venv 並安裝依賴
- 自動設定 PATH（`/opt/venv/bin:$PATH`）
- 覆蓋 `phases.install` 會繞過這些步驟

### 2. Monorepo 子目錄部署（`--path-as-root`）

**問題：** `railway up` 預設從專案根目錄上傳，所有服務共用根目錄的 `nixpacks.toml`。

**解法：** `cd` 進子目錄再部署（最可靠）：

```bash
# ✅ 推薦：cd 進子目錄直接部署
cd apps/telegram-bot && railway up --service telegram-bot -d
cd apps/line-bot && railway up --service line-bot -d
```

**⚠️ `--path-as-root` 可能靜默失敗！**

```bash
# ⚠️ 有時成功有時失敗（FAILED 但無 build logs）：
railway up apps/telegram-bot --service telegram-bot --path-as-root -d
# → deployment list 顯示 FAILED
# → `railway logs --build <id>` 回 "Deployment does not have an associated build"
# → 無任何錯誤訊息，完全靜默失敗

# ✅ 同樣的代碼，cd 進去就成功：
cd apps/telegram-bot && railway up --service telegram-bot -d
# → deployment list 顯示 SUCCESS
```

**根因推測：** `--path-as-root` 在某些情況下（例如環境變數剛變更、或 watchPatterns
已被設定為其他路徑）會導致上傳成功但建置永遠不啟動。`cd` 進子目錄則繞過了
路徑解析邏輯，讓 Railway 把當前目錄整個當作專案根目錄。

**建議：** 統一使用 `cd` 進子目錄的方式部署，放棄 `--path-as-root`。

**根目錄的 Core API（無需 --path-as-root）：**
```bash
# 根目錄部署，但需要一個 requirements.txt 指向子目錄
railway up --service core-api -d
```

**根目錄 requirements.txt（指向子目錄）：**
```
# requirements.txt
-r apps/api/requirements.txt
```

### 3. 建置成功但部署 FAILED 的排查

**症狀：** Build logs 顯示成功 + Healthcheck 通過，但 `railway deployment list` 顯示 FAILED。

**可能原因：**

| 原因 | 診斷方式 | 修復 |
|------|---------|------|
| 環境變數變更觸發重部署，但建置失敗 | `railway logs --build <deploy-id>` | 修復 nixpacks.toml |
| Pydantic validator 在啟動時拋異常 | `railway logs --service X` 查看 | 修正 validator 或環境變數 |
| 舊版本還在跑，新版本全部失敗 | `railway deployment list` 看歷史 | 找到 SUCCESS 的和第一個 FAILED 的之間發生了什麼 |

**關鍵觀念：**
- Railway 環境變數是**執行時期**的，不是建置時期
- 舊的成功部署會繼續服務，直到新的成功部署取代它
- 所有失敗部署不影響正在運行的舊版本

### 4. `.railwayignore`（防止洩漏 .env）

```bash
# .railwayignore — 排除敏感和不必要的檔案
.env
.env.*
*.env
.git
.vscode
__pycache__
*.pyc
.pytest_cache
node_modules
.next
_archive
_temp
```

**重要：** 即使 `.gitignore` 有 `.env`，也建議顯式建立 `.railwayignore`。
`railway up` 應該尊重 `.gitignore`，但為了安全起見，雙重保險。

### 5. Token 類型說明

| Token 類型 | 格式 | 權限 | 取得位置 |
|-----------|------|------|---------|
| Project Token | `xxxxxxxx-xxxx-...` | 只能部署特定專案 | Project Settings → Tokens |
| **Account Token** | `rlwy_xxxxx...` | **完整控制所有專案** | Account Settings → Tokens |

**重要：** CLI 操作（list、link、add）需要 **Account Token**！

### 6. 完整 Monorepo 部署流程

```bash
# ─── 準備 ───
railway login
railway init --name "my-project"  # 或 railway link

# ─── Core API（從根目錄部署）───
railway add --service "core-api"
railway domain --service core-api
railway variables --set 'KEY=value' --service core-api
railway up --service core-api -d

# ─── 子服務（用 --path-as-root）───
railway add --service "telegram-bot"
railway domain --service telegram-bot
railway variables --set 'CORE_API_URL=https://core-api-xxx.up.railway.app' --service telegram-bot
railway up apps/telegram-bot --service telegram-bot --path-as-root -d

# ─── 驗證 ───
railway deployment list --service core-api
railway deployment list --service telegram-bot
curl https://core-api-xxx.up.railway.app/health
curl https://telegram-bot-xxx.up.railway.app/health
```

### 7. 常見錯誤處理

| 錯誤 | 原因 | 解法 |
|------|------|------|
| `pip: command not found` | 自訂 `phases.install` 繞過 venv | 移除 `phases.install`，讓 provider 自動處理 |
| 建置成功但 FAILED | 啟動時 validator 拋異常 | 查 deploy logs，修 env vars |
| 子服務用了根目錄 nixpacks | `railway up` 從根目錄上傳 | 用 `--path-as-root` |
| `ValidationError: Field required` | 缺少環境變數 | `railway variables --set` |
| CORS 400 Bad Request | pydantic-settings 解析 List 失敗 | 見 `python-lazy-init-proxy-pattern` |
| `Unauthorized` | Token 類型錯誤 | 使用 Account Token（`rlwy_` 開頭） |

## Verification

```bash
# 檢查所有服務部署狀態
railway deployment list --service core-api
railway deployment list --service line-bot

# 健康檢查
curl https://your-service.up.railway.app/health

# 查看日誌
railway logs --service core-api
```

## Example

ExampleApp Concierge Network — 3 服務 Monorepo：

```
golden-key/
├── nixpacks.toml           ← Core API 用（provider auto-detect）
├── requirements.txt        ← -r apps/api/requirements.txt
├── railway.toml            ← Core API 建置設定
├── .railwayignore          ← 排除 .env
├── apps/
│   ├── api/                ← Core API (FastAPI)
│   │   ├── requirements.txt
│   │   └── main.py
│   ├── line-bot/           ← Line Bot (FastAPI)
│   │   ├── nixpacks.toml   ← 自己的 nixpacks 設定
│   │   ├── requirements.txt
│   │   └── main.py
│   └── telegram-bot/       ← Telegram Bot (FastAPI)
│       ├── nixpacks.toml   ← 自己的 nixpacks 設定
│       ├── requirements.txt
│       └── main.py
```

## Notes

- Railway 每次 `variables set` 後會自動重新部署
- 使用 `railway redeploy --yes` 手動觸發重新部署
- 日誌用 `railway logs` 查看，建置日誌用 `railway logs --build <id>`
- `railway up -d` 的 `-d` = detach（不串流日誌）
- 免費額度 $5/月，超過會暫停服務

### 8. Monorepo rootDirectory 設定（GraphQL API）

**問題：** `RAILWAY_ROOT_DIRECTORY` 環境變數 **不會生效**！這是一個常見的誤區。
Railway 的 rootDirectory 和 watchPatterns 必須透過 **GraphQL API** 設定。

**症狀：**
- 設了 `RAILWAY_ROOT_DIRECTORY=apps/my-service` 但服務仍從根目錄建置
- 日誌顯示 `No changed files matched patterns: apps/api/**`（watchPatterns 指向錯誤路徑）
- 第一次 `railway up` 從根目錄部署後，watchPatterns 被設成根目錄的子服務路徑

**根因：**
Railway CLI 的 `railway up` 會根據**上傳來源目錄**設定 watchPatterns。
如果第一次從根目錄 `railway up --service my-bot`，watchPatterns 會被設為 `apps/api/**`
（根目錄的第一個服務），之後即使用 `--path-as-root` 也**無法覆蓋**已設定的 watchPatterns。

**解法：使用 Railway GraphQL API**

```bash
# 步驟 1：取得 Railway API Token
# Account Settings → Tokens → Create Token

# 步驟 2：查詢 service ID 和 environment ID
railway service list
# 或用 GraphQL 查詢

# 步驟 3：用 GraphQL mutation 設定 rootDirectory + watchPatterns
curl -X POST https://backboard.railway.com/graphql/v2 \
  -H "Authorization: Bearer $RAILWAY_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation { serviceInstanceUpdate(serviceId: \"SERVICE_ID\", environmentId: \"ENV_ID\", input: { rootDirectory: \"apps/my-service\", watchPatterns: [\"apps/my-service/**\"] }) }"
  }'

# 步驟 4：觸發重新部署
railway redeploy --service my-service --yes
```

**完整 Python 腳本範例：**
```python
import httpx, json

RAILWAY_TOKEN = "your-account-token"
SERVICE_ID = "your-service-id"
ENV_ID = "your-environment-id"

mutation = """
mutation {
  serviceInstanceUpdate(
    serviceId: "%s"
    environmentId: "%s"
    input: {
      rootDirectory: "apps/op-telegram-bot"
      watchPatterns: ["apps/op-telegram-bot/**"]
    }
  )
}
""" % (SERVICE_ID, ENV_ID)

resp = httpx.post(
    "https://backboard.railway.com/graphql/v2",
    headers={
        "Authorization": f"Bearer {RAILWAY_TOKEN}",
        "Content-Type": "application/json",
    },
    json={"query": mutation},
)
print(json.dumps(resp.json(), indent=2))
```

**查詢現有 watchPatterns：**
```bash
curl -X POST https://backboard.railway.com/graphql/v2 \
  -H "Authorization: Bearer $RAILWAY_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "query { service(id: \"SERVICE_ID\") { serviceInstances { edges { node { watchPatterns rootDirectory } } } } }"
  }'
```

**要點記憶：**
| 方法 | 是否有效 | 說明 |
|------|---------|------|
| `RAILWAY_ROOT_DIRECTORY` 環境變數 | ❌ 無效 | 這個 env var 不被 Railway 識別 |
| `railway up apps/x --path-as-root` | ⚠️ 部分有效 | 可以改建置根目錄，但不改 watchPatterns |
| `cd apps/x && railway up` | ⚠️ 部分有效 | 同上 |
| **GraphQL API mutation** | ✅ 完全有效 | 唯一可靠的方式設定 rootDirectory + watchPatterns |

## See Also

- `python-lazy-init-proxy-pattern` — CORS_ORIGINS 等 List 欄位解析問題 / Python 全域服務 import 綁定問題
- `service-channel-replication-pattern` — Line Bot + FastAPI 整合
- `supabase-rls-empty-data-debugging` — Supabase 測試資料建立
