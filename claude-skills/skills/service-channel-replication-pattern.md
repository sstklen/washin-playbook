---
name: service-channel-replication-pattern
description: |
  在現有多管道系統中新增一個管道（如 Telegram Bot / Discord Bot / WhatsApp / LINE Bot）的完整工作流。
  使用時機：(1) 系統已有一個管道實作，需要新增另一個類似管道，
  (2) 新管道跟現有管道共用同一個 Core API，(3) 需要快速且一致地複製架構模式，
  (4) 建立 Line Bot 並需要連接 FastAPI 後端 API，(5) 需要用 Cloudflare Tunnel 建立公開 Webhook URL，
  (6) 訊息需要識別客戶並個性化回覆，(7) 需要從 Line ID 查詢資料庫客戶。
  五階段流程：偵察 → 策略決定 → 目錄建立 → 並行建造 → 整合驗證。
  涵蓋 Webhook 設定、訊息路由、客戶識別、服務架構。
version: 1.0.0
date: 2026-02-06
---

# Service Channel Replication Pattern

## Problem

當一個多管道系統（如 ExampleApp 的 LINE Bot + API + Portal）需要新增另一個管道時
（如 Telegram Bot、Discord Bot、WhatsApp），直接從零開始建造效率低且容易跟現有
架構不一致。而完全照抄舊管道又可能帶入不需要的複雜度。

**核心挑戰**：
- 如何在保持架構一致的同時，適應新平台的特性？
- 如何確保新管道跟 Core API 的整合沒有遺漏？
- 如何用最少時間完成且品質有保障？

## Context / Trigger Conditions

當你看到以下情境時，使用此模式：

1. **系統已有至少一個管道實作**（LINE Bot、Telegram Bot、Discord Bot 等）
2. **需要新增另一個類似管道**（接收訊息 → 轉發 Core API → 格式化回覆 → 發送）
3. **新管道跟現有管道共用同一個 Core API**
4. **Core API 有統一的訊息入口**（如 POST /messages/）

**不適用的情況**：
- 新管道的邏輯完全不同（不只是接收/發送訊息）
- 沒有現有管道可以參考
- Core API 不存在或需要大幅改造

## Solution

### 第一階段：偵察（Reconnaissance）

派出 3 個 Agent 並行探索三個資訊來源：

```
Agent 1 → 舊版/歸檔的實作（如果有的話）
         了解歷史功能清單、用戶期望、已知問題

Agent 2 → 現有管道的實作（如 LINE Bot）
         提取架構模式：目錄結構、服務分層、API 整合方式

Agent 3 → Core API 的訊息端點
         記錄 API 規格：request/response 格式、認證方式、速率限制
```

**偵察報告必須包含**：
- 現有管道的架構圖（哪些檔案做什麼事）
- Core API 的確切 payload 格式
- 認證方式（JWT / API Key / 其他）
- 平台特有的限制（如 Telegram 4096 字元限制）

### 第二階段：策略決定

根據偵察結果，決定建造策略：

| 策略 | 適用場景 | 風險 |
|------|---------|------|
| **Thin Client 複製** | 新管道功能跟現有管道類似 | 低 — 已驗證的模式 |
| **Monolith 遷移** | 舊版有大量本地邏輯 | 高 — 可能帶入技術債 |
| **混合模式** | 部分功能需本地處理 | 中 — 需要清楚劃分界線 |

**ExampleApp 的決策過程**：
- 舊 Telegram Bot = Next.js + grammY monolith（本地 AI）
- LINE Bot = Python + FastAPI thin client（AI 在 Core API）
- 決策 → 選擇 Thin Client 複製（跟 LINE Bot 同模式），不復活舊 monolith

### 第三階段：目錄建立 + Core API 修改

1. **建立目錄結構**（完全平行於現有管道）
2. **修改 Core API** 支援新頻道：
   - 在訊息驗證器中加入新頻道名稱
   - 加入新管道特有的欄位（如 `telegram_chat_id`）
   - 注意不要破壞現有管道的驗證邏輯

```python
# 修改前
allowed = {"line", "portal", "api"}

# 修改後
allowed = {"line", "portal", "api", "telegram"}  # 加入新頻道

# 新增平台特有欄位
telegram_chat_id: Optional[str] = Field(None, max_length=100)
telegram_message_id: Optional[str] = Field(None, max_length=100)
```

### 第四階段：並行建造（3 Agent 同時）

把新管道拆成三個獨立的工作包：

```
Agent 1 → 基礎設施
         config.py, requirements.txt, Procfile,
         models/types.py, 所有 __init__.py, .env.example
         + Core API 修改

Agent 2 → Services 層
         api_client.py（HTTP 客戶端，參照現有管道的 message_router）
         telegram_service.py（平台 SDK 封裝）
         reply_formatter.py（回覆格式化，確保純文字不送物件）

Agent 3 → Handlers + Main
         command_handler.py（/start, /help 等指令）
         message_handler.py（文字訊息 → Core API → 格式化 → 回覆）
         main.py（FastAPI + webhook + lifespan 生命週期）
```

**每個 Agent 的 prompt 必須包含**：
- 現有管道的對應程式碼片段（供參照）
- Core API 的 request/response 格式
- 依賴的其他層的介面定義（函數簽名、全域變數名）
- 平台特有的注意事項（訊息長度限制、認證方式等）

### 第五階段：整合驗證

派出 1 個驗證 Agent 做 6 項檢查：

| # | 驗證項目 | 方法 |
|---|---------|------|
| 1 | 檔案結構 | `find` 列出所有檔案 |
| 2 | Python 語法 | `ast.parse()` 每個 .py 檔 |
| 3 | Import 鏈 | 實際 import 所有模組 |
| 4 | Core API 整合 | grep 確認新頻道在驗證器中 |
| 5 | 架構一致性 | 對比兩個管道的模式 |
| 6 | 安全性 | grep 搜尋硬編碼密鑰 |

## Verification

在 ExampleApp 專案中實際驗證通過：

- 15 個檔案全部建立（12 個 .py + 1 requirements.txt + 1 Procfile + 1 .env.example）
- 12 個 Python 檔案語法全部通過
- Import 鏈驗證通過（包含 reply_formatter 的 8 個函數測試）
- Core API messages.py 正確加入 `telegram` 頻道 + 3 個 Telegram 欄位
- 架構與 LINE Bot 完全一致（FastAPI + lifespan + httpx + X-API-Key + webhook + push）
- 無硬編碼密鑰

## Example

ExampleApp 新增 Telegram Bot B2C 管道：

```
偵察耗時：~3 分鐘（3 Agent 並行）
策略決定：~1 分鐘
建造耗時：~3 分鐘（3 Agent 並行）
驗證耗時：~5 分鐘（1 Agent）
總計：~12 分鐘，1315 行代碼

結構：
apps/telegram-bot/
├── config.py              ← pydantic-settings（port 8003）
├── main.py                ← FastAPI + webhook + lifespan
├── requirements.txt       ← python-telegram-bot + httpx
├── Procfile               ← Railway 部署
├── .env.example
├── handlers/
│   ├── command_handler.py   ← /start /help /services /status /language
│   └── message_handler.py   ← 文字 → Core API → 格式化 → 回覆
├── services/
│   ├── api_client.py        ← httpx + X-API-Key → Core API
│   ├── telegram_service.py  ← python-telegram-bot 封裝
│   └── reply_formatter.py   ← 格式化（品牌識別 + 純文字保證）
└── models/
    └── types.py             ← Pydantic 模型
```

## Notes

### Thin Client 的關鍵設計原則

1. **所有 AI 處理在 Core API**：Bot 不直接呼叫 Claude/OpenAI
2. **Bot 只做四件事**：接收 → 轉發 → 格式化 → 發送
3. **格式化是關鍵**：Bot 回覆必須先經過 `reply_formatter`，絕不直接 send dict/object
4. **httpx.AsyncClient 統一**：所有管道用同一種 HTTP 客戶端

### Agent 邊界的劃分原則

- **基礎設施 Agent** 可以修改 Core API（因為要加新頻道支援）
- **Services Agent** 只依賴 config.py 和 models/（不依賴 handlers）
- **Handlers Agent** 需要 services 的介面定義（函數簽名）但不需要實作細節
- 三個 Agent 互不依賴 → 可以真正並行

### Core API 修改的注意事項

- 只改驗證器的 allowed 集合（最小改動）
- 新欄位都是 Optional（不影響現有管道）
- 不改動業務邏輯（客戶查詢、工單建立等暫時不處理新管道）

### 可複製到其他管道

此模式可直接用於新增：
- Discord Bot（discord.py + slash commands）
- WhatsApp Bot（Twilio / WhatsApp Business API）
- Slack Bot（slack-bolt）
- WeChat Bot（wechat-sdk）

只需更換 Step 4 的平台 SDK 和 handler 邏輯。

## References

- [python-telegram-bot v20+ 文件](https://docs.python-telegram-bot.org/)
- [Telegram Bot API Webhook](https://core.telegram.org/bots/api#setwebhook)
- See also: `multi-agent-workflow-design` — 從零建專案的模式
- See also: `multi-agent-workflow-design` — 並行 Agent 驗證的模式
- See also: `api-tool-use-upgrade-pattern` — Core API AI Agent 升級模式
- See also: `service-channel-replication-pattern`（已整合至本指南）— LINE Bot 整合模式

## Merged Skills (archived)

The following skills have been merged into this guide:
- **line-bot-fastapi-webhook-integration** — Line Bot + FastAPI Webhook 整合（Webhook 設定、客戶識別、Cloudflare Tunnel）
