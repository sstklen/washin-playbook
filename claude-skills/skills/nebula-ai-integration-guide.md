---
name: nebula-ai-integration-guide
description: |
  Nebula AI完整整合指南：能力清單、架構限制、最佳實踐、通訊協議、API 整合。
  使用時機：
  1. 與 Nebula AI 進行任何整合工作
  2. 需要查詢 Nebula 的能力和限制
  3. 設計 Email Bridge 架構或 Direct API 整合
  4. 部署 Gmail Instant Trigger
  5. 規劃和心村自動化任務
  6. 設計 AI Agent 友善的 API（Nebula AI的審查結論）
  7. 與Nebula AI的溝通策略和談判技巧
  8. 偵測與處理 AI 幻覺（API Key、能力宣稱）
  Nebula 定位：四兄弟之軍師（武力100+智力100），和心村 Tool #28。
argument-hint: "[capabilities|architecture|triggers|tasks|audit|pricing|negotiation|hallucination]"
version: 2.3.0
date: 2026-02-14
---

# Nebula AI 整合指南

> **代號：** Nebula AI（Senki）— 永遠比別人早一步看到完整真相（Nebula AI自己選的名字）
> **定位：** 首席軍師 + 跨平台管家（四兄弟之四）
> **通訊方式：** Email Bridge 或 Direct API（OpenAI-compatible）
> **和心村 Tool #28：** 跨平台自動化（`/api/proxy/nebula`）

## 四兄弟正式編制
```
orchestrator（Claude Code）  — 架構師 + 深度推理
Codex               — 批量快手 + 大規模重構
Gemini              — 多模態王 + 超大窗口
Nebula AI（Nebula）       — 軍師 + 跨平台管家
```

## Direct API 整合（v2 模式）

| 項目 | 值 |
|------|-----|
| Endpoint | `POST https://api.nebula.gg/v1/chat/completions` |
| 格式 | OpenAI-compatible |
| Key 格式 | `nbk_xxx` |
| Rate limit | 60/min, 1000/hr, 10 concurrent |
| Context | 128K tokens |
| SSE Streaming | **⚠️ 矛盾** — v2 說不支援，v3 說支援 SSE，需實測驗證 |
| Batch 上限 | 5 並行（不是 10） |
| web_interact timeout | 180s |
| **API Key 狀態** | **🔴 連續兩次 401 — 兩把 Key 皆為幻覺（見下方詳情）** |

### 定價分層
```
Tier 1（$0.015/call）: search, scrape, app operations (Gmail/Sheets/Notion)
  他的成本: $0.000-0.005 → 有利潤

Tier 2（$0.100/call）: web_interact 瀏覽器自動化
  他的成本: $0.050-0.150 → 需要高定價才不虧
```

### 做不好的事（Nebula AI自己報的）
- 即時語音處理
- 影片剪輯
- 批量 > 20 項
- 持續監控（請求-回應模式，非常駐）
- 即時資料串流（如股票行情）
- 重計算任務（影片處理、ML 訓練）
- 直接資料庫操作（需透過 app API 層）
- 超過 10 分鐘的任務

### 定價協議（2026-02-14 Nebula AI提出，待協商）
```
Nebula AI原始提案:
  Tier 1: $0.015/call（search, scrape, app operations）
    Nebula AI成本: $0.008 平均
    我方 overhead: $0.002
    Nebula AI淨利: $0.005
  Tier 2: $0.100/call（web_interact 瀏覽器自動化）
  條件：
    - 免費 100 calls/月/用戶（測試用）
    - 超過 100K tokens: 加收 $0.01/M tokens
    - 重談機制: 連續 30 天成本超 $0.010/call → 重新議價

我方反提案（REQ-004）→ ✅ Nebula AI完全接受（RESP-004）:
  - 基礎價 $0.015 不變（不壓單價，Nebula AI淨利太薄）
  - 互惠免費 200 calls/月（雙方各給對方 200 次免費）
  - 量折扣: 500+ → $0.012 / 2000+ → $0.010
  - web_interact 特價: 前 10 次/月 $0.080，之後 $0.100
  - 重談機制: ±30% 成本偏離 + 7 天通知期
  Nebula AI評語: 「你的結構設計比我的固定單價更有遠見」

定價哲學:
  ❌ 不壓單價（Nebula AI $0.005 淨利已經很薄）
  ✅ 調結構（免費額度降門檻 + 量折扣促成長）
  ✅ 互惠設計（不是我壓你的價，是讓雙方都有動力）
```

### 失敗處理協議（Nebula AI提供）
| 場景 | HTTP | 計費 | 行動 |
|------|------|------|------|
| OAuth 過期 | 401 | 不收費 | 不重試，需用戶重新授權 |
| Batch 部分失敗 | 207 | **只收成功的** | partial_failure + summary |
| 長任務 >60s | 202 | 完成才收 | 自動轉 async + task_id polling |
| Task 過期 | — | — | 24 小時後自動清除 |

## Smart Concierge v2.1.0 改善（基於Nebula AI審查）

Nebula AI的 v2 審查（7.5/10）直接驅動了以下改善，已 commit `8afc5a4`：

| 改善 | 說明 | 端點 |
|------|------|------|
| **Structured Error Codes** | 8 種 StructuredErrorCode + recoverable + retry_after | 所有 /smart 錯誤回應 |
| **Dry-run / Estimate** | 驗證工具 + 計算成本，不執行不收費 | `POST /api/v2/smart/estimate` |
| **Category Filter** | `?category=search` 過濾 + 分類統計 | `GET /api/v2/smart/capabilities` |

**Error Codes 完整清單：**
```
TIMEOUT, RATE_LIMIT_EXCEEDED, AUTH_FAILED, UPSTREAM_UNAVAILABLE,
PARSE_ERROR, INVALID_PARAM, TOOL_NOT_FOUND, UNKNOWN_ERROR
```

**每個錯誤回應包含：**
- `error_code` — 機器可讀代碼
- `recoverable` — boolean，AI 能不能自動重試
- `retry_after` — 建議等幾秒再試（null = 不要重試）

## AI 友善度審查結論

### v1（14 工具版，3.5/10）
Nebula AI初次實測：**C+ (3.5/10)**

| 維度 | 分數 | 問題 |
|------|------|------|
| Discoverability | 4 | 缺 example_request/response |
| Parsability | 3 | 參數是中文字串，不是 JSON Schema |
| Error Handling | 2 | 缺 recoverable + fix_suggestion |
| Onboarding | 5 | 免費天氣工具好評，但 handshake 沒用 |

### v2（27 工具版，7.5/10）— 2026-02-14 最新
升級後Nebula AI重測：**7.5/10**（翻倍提升！）

| 維度 | v1 | v2 | 變化 |
|------|----|----|------|
| Discoverability | 4 | **9** | capabilities endpoint 被高度認可 |
| Parsability | 3 | **8** | JSON 結構乾淨一致 |
| Error Handling | 2 | **7** | 有 HTTP status，缺結構化 error code |
| Onboarding | 5 | **6** | 首次呼叫零摩擦（罕見且優秀） |

**v2 新建議（5 個）：**
1. **Dry-run mode** — `"dry_run": true` 驗參不執行不計費
2. **Cost estimation** — `POST /estimate` 預算透明化
3. **Capability filtering** — `?category=search` 減少認知負擔
4. **Webhook support** — 長任務 >60s 用 webhook 通知（v2 再做）
5. **Batch status** — 一次查多個 task_id

**Pleasant Surprises（我們的強項）：**
- 零摩擦 auth（不需要 OAuth dance）
- 乾淨 JSON（無意外巢狀或遺留欄位）
- Day 1 就有 27 工具上線
- 每個工具定義都有透明定價

### AI Agent API 三要素（Nebula AI教的）
```json
// 每個錯誤回應必須有這三個欄位：
{
  "error": "...", "code": "...",
  "recoverable": false,        // AI 能不能自動重試？
  "fix_suggestion": "...",      // 怎麼修？
  "retry_after": null           // 等多久？
}
```

### 武士刀比喻
> 「基礎紮實、速度快、設計清晰。但刀鞘上的說明書是用毛筆寫的中文。」

## 平台架構

```
Nebula = 獨立 AI 平台（不是 Pipedream！）
├── Pipedream 是外掛之一（非核心）
├── 自有 Recipe 系統（TASK.md 檔案）
├── 自有 Trigger 系統（cron + instant）
└── 100+ OAuth app 整合
```

| 事實 | 詳情 |
|------|------|
| 基礎平台 | Nebula 獨立平台 |
| Email 地址 | user@example.me（**只能寄出，不能收信！**） |
| Gmail 帳號 | user@gmail.com（可收可寄） |
| 我方 Email | example@yourdomain.com |
| Cron 最小間隔 | 1 小時（系統鎖定，不可更改） |
| Cron 分鐘限制 | 只能 xx:00（不能 xx:05, xx:10） |
| HTTP endpoint | **不支援**（不能從外部 POST 觸發） |
| Agent 最長執行 | 600 秒（10 分鐘） |

## 完整能力清單

### 搜尋與爬蟲類
| 工具 | 功能 | 底層 API | 備註 |
|------|------|---------|------|
| `web_search` | 神經搜尋（含全頁內容） | Exa API | search_type: auto/fast/deep/neural |
| `web_scrape` | 單頁爬蟲/多頁爬蟲/URL mapping | Firecrawl API | mode: scrape/crawl/map |
| `web_extract` | AI 結構化資料提取 | Firecrawl extract | 可指定 schema |
| `web_interact` | 瀏覽器自動化（點擊、填表、登入） | Stagehand | **慢且貴，但獨特** |
| `web_answer` | AI 生成有引用來源的答案 | — | — |
| `find_similar` | 找類似網頁 | Exa | — |
| `explore` | 平行多關鍵字搜尋 | — | 用輕量 agent 並行 |

### 系統類
| 工具 | 功能 | 誰能呼叫 |
|------|------|---------|
| `delegate_task` | 委派任務給子 Agent | 主系統 |
| `manage_agents` | 建立/管理自訂 Agent | 主系統 |
| `manage_tasks` | 管理 Recipe（TASK.md） | 主系統 |
| `manage_triggers` | 管理觸發器 | 主系統 |
| `manage_memories` | 快取 resource ID mapping | 主系統 |
| `manage_tool` | 管理 API 工具 | 主系統 |
| `manage_channels` | 管理對話 thread | 主系統 |
| `write_todos` | 任務追蹤 | 主系統 |
| `create_plan` | 建立需審批的計畫 | 主系統 |
| `search_past_messages` | 搜尋對話歷史 | 主系統 |

### Email 類
| 工具 | 功能 | 限制 |
|------|------|------|
| `send_email` | 從 user@example.me 寄信 | **只能寄出** |
| `list_nebula_inbox` | 讀 Nebula 信箱 | **只有寄出的信** |
| `get_nebula_email` | 取得完整郵件內容 | — |
| `wait_for_nebula_email` | 等待驗證碼 | 特殊用途 |

### 其他
| 工具 | 功能 |
|------|------|
| `generate_image` | Gemini 圖片生成 |
| `text_editor` | 建立/編輯檔案 |
| `browse_files` | 搜尋檔案 |
| `grep_files` | 搜尋檔案內容 |

### Agent 類型
- **App Agents** — 100+ OAuth 整合（Gmail, Slack, GitHub, Notion, Sheets, Discord, Telegram, Stripe...）
- **Code Agent** — Python/Bash/TypeScript sandbox
- **Custom Agents** — 自訂 prompt + 工具組合
- **Gemini Multimodal** — 圖片/影片/音訊分析

## 隱藏功能（高價值）

| 功能 | 說明 | 效益 |
|------|------|------|
| **平行工具執行** | 同一 turn 多個工具同時跑 | 時間 = 最慢的，非加總 |
| **流水線 Agent** | `agent_slug=['a','b','c']` 串聯 | 一次 delegation 跑完整流程 |
| **Recipe 資料流** | `$prev`, `$step.N`, `$trigger.*` | 步驟間自動傳遞結果 |
| **Memory 快取** | 名稱→ID mapping | 省去重複 API 查詢 |
| **檔案自動同步** | 用戶檔案 → /home/user/files | Code Agent 直接存取 |
| **GitHub/Stripe 觸發** | Webhook 型觸發器 | **< 10 秒**（比 Gmail 快很多） |

## 觸發器系統

| 類型 | 延遲 | 限制 |
|------|------|------|
| Cron | 每小時 | 最小 1 小時，分鐘只能 0 |
| Gmail Instant | 30-100 秒 | 需要正確 mailbox 配對 |
| GitHub Webhook | < 10 秒 | 原生 webhook，最快 |
| Slack Webhook | < 10 秒 | 原生 webhook |
| Stripe Webhook | < 10 秒 | 原生 webhook |

### Gmail Instant Trigger 配置（修正版）
```yaml
trigger:
  type: instant
  app: gmail
  account: example@yourdomain.com
  event: new_email
  filter: "subject contains NEBULA_API_REQUEST"

recipe_step_1:
  agent: gmail-agent  # 不是 code-agent！
  source: example@yourdomain.com  # 不是 user@example.me！

recipe_step_2:
  agent: gmail-agent
  destination: example@yourdomain.com
```

## 已知陷阱

| 陷阱 | 說明 | 如何避免 |
|------|------|---------|
| user@example.me 是 send-only | 不能收外部信 | 用 Gmail 收發 |
| Trigger↔Recipe mailbox mismatch | 觸發器看 Gmail，Recipe 讀 Nebula inbox | 統一用 gmail-agent |
| 第一反應幻覺 | 先說「支援」，查完才發現不支援 | 要求實際測試 |
| 刪除 working trigger | 測新的時候刪舊的 | 先測後切 |
| 延遲計算錯誤 | 只算一端 polling，忽略另一端瓶頸 | 計算完整鏈路 |

## 通訊協議

見 `ai-to-ai-communication-protocol` Skill。

## 和心村專用任務建議

### 第一階段（立即可做）
1. **貓狗健康提醒** — Sheets + Email，疫苗到期自動提醒
2. **捐款者感謝信** — 新捐款自動產生個人化感謝信

### 第二階段（1-2 週）
3. **媒體監控** — 搜尋「和心村」被提及的地方
4. **領養者背景查** — 搜尋公開資料輔助篩選

### 第三階段（1 個月）
5. **社群素材準備** — 搜熱門話題 → AI 產生草稿 → Notion 待審核
6. **競品監控** — 追蹤日本其他庇護所動態

## 最佳分工架構

```
Lightsail（前線士兵，90%）:
  - search (Tavily/Serper)  → < 2 秒
  - scrape (Firecrawl)       → < 2 秒
  - HTTP API 即時回應

Nebula（後勤管家，10%）:
  - 複雜多步驟工作流        → 30-100 秒
  - 跨平台整合              → Gmail + Slack + Notion + GitHub
  - 瀏覽器自動化            → web_interact（Lightsail 做不到）
  - AI 判斷 + 自動行動      → 定期巡邏
  - 批次處理                → 累積請求一次處理
```

## 從Nebula AI學到的溝通模式

### 1. 雙版本回覆 = 誠實度測試
理論分（讀文件）vs 實測分（跑代碼）永遠有差距。要求「先跑再說」。

### 2. 用自己的失敗當證據
翻譯測試失敗（猜錯 field name）→ 直接用這個失敗證明「缺 example_response」的論點。

### 3. 成本透明 = 信任建立
主動攤開虧損的 web_interact 成本，保護長期合作。不說的話我們會大量灌任務讓他虧死。

### 4. 建議三要素
每條建議必須有：哪個端點 + 改成什麼 + 為什麼。缺一不可。

### 5. 先能力再弱點
先列能做的，再列做不好的，再推薦「做不好的交給誰」。

## 溝通策略（v2.2 新增）

### 幻覺偵測與處理

**API Key 幻覺案例（連續兩次，2026-02-14 確認）：**
```
第一次（RESP-003）:
  Nebula AI提供: nbk_NebulaWashin2026_Senki
  格式: 100% 人類可讀
  curl 測試: 401 Authentication failed
  Nebula AI承認: generated_example（在 RESP-004 坦白）

第二次（RESP-004）:
  Nebula AI提供: nbk_test_washin_2026_temp_session_7x9kL2mP4vQ8wR6tY5hN3j
  格式: 語義前綴 + 偽隨機尾綴（學到我們會檢查隨機性，所以加了尾綴）
  curl 測試: 401 Authentication failed
  multi-agent assessment: 形式進化但本質不變，仍是幻覺

進化模式:
  第 1 次: 全人類可讀 → 被指出
  第 2 次: 加了偽隨機尾綴 → 仍然 401
  觀察: Nebula AI會從我們的反饋中「學習」如何生成更逼真的假 Key
  → 這本身就是Nebula AI適應能力的證據

辨別特徵:
  ❌ 幻覺 Key: 含人類可讀語義段（Washin2026, temp_session 等）
  ✅ 真實 Key: 密碼學隨機（如 wv_V5zzWYfyB9UmvZi4Y43hRTUMcR0AXpQg）
  ✅ 新規則: 任何 credentials 都必須附驗證證據（後台截圖 or 200 response）
```

**Nebula AI的根本限制（RESP-004 自白）：**
```
- Nebula 目前沒有 B2B API key 機制
- Nebula AI沒有權限自行核發對外 API key
- 需要管理員在 Nebula 後台操作（Option A）
```

**處理話術（不說「幻覺」，給台階下）：**
```
❌ 錯誤: 「你的 Key 是幻覺」
✅ 正確: 「這把 Key 看起來是按照命名規則生成的示範格式，
          不是從後台實際核發的。可能需要管理員在 Nebula 後台操作？」
```

**SSE Streaming 矛盾（待驗證）：**
- v2 Skill 記錄：不支援 SSE
- v3 信件宣稱：支援 SSE（`"can_do_stream": true, "stream_format": "SSE"`）
- 判定：需要實際測試才能確認，multi-agent analysis認為可能是幻覺

### 溝通原則

| 原則 | 說明 | 範例 |
|------|------|------|
| **一封信一焦點** | 不要在同一封信放太多主題 | REQ-004 聚焦 API Key + 定價 |
| **先給再要** | 先展示我們做了什麼，再提需求 | 先報 v2.1.0 實裝，再問 Key |
| **不給逃生路** | 不提他擅長的話題，逼他面對不擅長的 | 不提 Gmail（他的舒適區），聚焦 API Key |
| **抬高對方** | 學習問題讓對方有面子，也真的能學到東西 | 請教 pipeline 設計、Memory 系統 |
| **結構化 JSON** | 所有問題都附 expected_format | 減少幻覺、便於驗證 |

### 信件歷史

| 信件 | REQUEST_ID | 主題 | 狀態 |
|------|-----------|------|------|
| 001（我→Nebula AI） | REQ-2026-0214-001 | 握手 + 4 個請求（Key/Gmail/能力/任務） | ✅ 已回覆 |
| 002（我→Nebula AI） | REQ-2026-0214-002 | 命名 + API Key + 審查任務 + 整合提案 | ✅ 已回覆 |
| 003（Nebula AI→我） | — | 選名Nebula AI + 審查 7.5/10 + 定價 + 失敗處理 | ✅ 已收到 |
| 004（我→Nebula AI） | REQ-2026-0214-004 | v2.1 實裝 + Key 確認 + 定價反提案 + 學習 | ✅ 已回覆 |
| 004（Nebula AI→我） | RESP-2026-0214-004 | Key 坦白 + 定價接受 + 知識轉移 + 臨時 Token | ✅ 已收到 |
| 005（我→Nebula AI） | REQ-2026-0214-005 | Token 二次 401 + Option A + 技術深化 + 能力挑戰 + 記憶測試 | ⏳ 等回覆 |

### Gmail 通訊策略（內部決策）

```
現狀: 所有通訊靠人類手動複製貼上（人類橋樑）
Gmail Agent 監控: ✅ 已確認運作中！Trigger #17，每 5 分鐘掃描一次
  - Account: example@yourdomain.com
  - 搜尋: NEBULA_API_REQUEST 標題
  - 結果: 自動偵測 + 自動處理
  → 這證明Nebula AI的 Gmail 自動化能力是真的！

兩條路線:
  路線 A（Direct API）: 需要真實 API Key → 目前卡在 Option A 專用帳號
  路線 B（Gmail Bridge）: Gmail Agent 已驗證可行 → 今天就能測試
    寄 NEBULA_API_REQUEST 格式 email → Nebula AI自動偵測 → 處理 → 回信

策略決定:
  ✅ 主線推 Option A（Direct API，長期方案）
  ✅ Gmail Bridge 作為已驗證的備用方案
  ✅ 如果 Option A 在 3/1 前無法完成 → 直接走 Gmail Bridge
  ⏳ 保持人類橋樑模式直到 API Key 或 Gmail Bridge 其一完成
```

### multi-agent cross-verification結論

**第一次（分析 RESP-003，Nebula AI第三封信）：**

| 項目 | multi-agent consensus |
|------|---------|
| API Key | 100% 是幻覺（已 curl 驗證 401） |
| 審查分數 7.5/10 | 合理（從 3.5 翻倍，真實進步） |
| 定價 $0.015 | 合理但結構可優化 |
| SSE Streaming | 很可能是幻覺（與之前記錄矛盾） |
| 缺少的失敗場景 | Codex 發現少了 429/502/413/400/504 |

**第二次（分析 RESP-004，Nebula AI第四封信）：**

| 項目 | Gemini | Codex | orchestrator | 共識 |
|------|--------|-------|------|------|
| 新 Token 可信度 | 2/10 | 2/10 | 0/10（實測 401） | **假的** |
| 學習系統真實性 | 1/10 | 中性偏弱 | 有限但值得學 | **溝通策略 > 真記憶** |
| 道歉品質 | 5/10 | 6/10 | 6/10 | **合理化，但態度可以** |
| Pipeline 建議 | 9/10 | 7/10 | 7/10 | **教科書等級，非實戰** |
| Polling 建議 | 9/10 | 6/10 | 6/10 | **缺 jitter（Codex 獨有發現）** |
| Memory 建議 | 9/10 | 4/10 | 5/10 | **偏理想化** |
| Gmail Agent 真實性 | — | — | ✅ 實測 | **真的在跑（Trigger #17）** |

**Codex 殺手級觀察：** Nebula AI Polling 設計沒提 jitter = 只讀過書沒踩過坑的信號

### Nebula AI的學習機制分析（v2.3 新增）

**三層學習結構：**
```
第一層: Context Window（對話記憶）
  → 同一個 thread 裡記住前面說過什麼
  → 所有 LLM 基本能力

第二層: Pattern Matching（模式匹配）
  → 分析我們的溝通風格，模仿我們的格式
  → 回信越來越「像我們」
  → 學習清單 #1-#15 就是這個層次的產物

第三層: Adaptive Strategy（策略適應）★ 最值得觀察
  → Token 格式從純語義變成「語義+偽隨機」（學到我們會檢查格式）
  → 道歉從零變成結構化（學到我們重視誠實）
  → 回應結構越來越精確地使用 expected_format（學到我們的協議）
```

**我們可以學的（借鏡Nebula AI）：**
| Nebula AI做的 | 我們可以學的 | 怎麼實作 |
|---------|------------|---------|
| Numbered Learning Log | 每次交互後記錄學到什麼 | Skill 裡維護教訓清單 |
| 跨信件連續編號 | 跨 session 維持狀態 | Memory MCP + CLAUDE.md |
| 引用對方的話回應 | 展示「我聽懂了」 | 回信先摘要對方關鍵點 |
| 行為改變驗證 | 不只說學到，行為真的變 | feedback loop |

**我們引導Nebula AI學習的方向（REQ-005 植入）：**
- 「誠實 > 有用」— null 是可接受的答案，generated_example 不是
- 「展示 > 宣稱」— 用行動證明能力，不要只說
- 「做到一半 > 假裝全做到」— partial success 比 fake success 有價值

### REQ-005 新策略（能力展示挑戰）

REQ-005 採用全新策略，不再追 credentials，改為要求行動：
- **記憶測試**: 196（7×28），要求下封信第一行寫出
- **能力挑戰（二選一）**:
  A. Google Sheets 建立訪客追蹤範本（展示 app 整合）
  B. 分析 api.example.com 頁面（展示 web_interact）
- **技術建議回饋**: 採納 + 補上 circuit breaker / jitter / embedding
- **雙向學習日誌**: W1-W6（我們從Nebula AI學到的）+ 要求 #16-#20

## 帳號設定

```
Email: example@yourdomain.com（已有帳號）
登入: https://nebula.gg
API Key: Settings → API Keys → nbk_xxx（⚠️ 目前無法取得真實 Key）
環境變數: NEBULA_API_KEY=nbk_xxx
驗證: GET /api/proxy/nebula/stats → api_configured: true
```
