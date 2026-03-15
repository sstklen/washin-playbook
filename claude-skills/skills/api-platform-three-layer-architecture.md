---
name: api-platform-three-layer-architecture
description: |
  API 平台三層架構設計模式，將同一批 API 服務收入提升 3 倍。使用時機：
  1. 設計 API marketplace 或 API 共享池的產品分層
  2. 需要提升同一批 API 服務的 ARPU（每用戶平均收入）
  3. 解決 AI Agent 工具呼叫可靠性問題（75% 生產環境失敗率）
  4. 設計社群驅動的工具生態（Recipe 分潤飛輪）
  5. 需要決定 API 產品的分層定價策略
  6. 從「賣食材」升級到「賣餐廳」的商業模式轉型
  核心發現：食材層（Raw API）+ 廚師層（Smart Gateway）+ 菜單層（Recipe Store）
  = revenue tripled with 3-tier architecture，已在 API Platform v1.7 規格書驗證。
version: 1.0.0
date: 2026-02-12
---

# API Platform Three-Layer Architecture

## Problem

擁有一批 API 資源（自有或共享池），但只能做最基礎的 proxy 轉發，
收入 = API 原價 + 微薄服務費。同時 AI Agent 時代來臨，75% 的 Agent 任務
在生產環境失敗（Superface.ai），開發者願意付溢價換可靠性，但市場上
Zapier 太簡單、LangChain 太複雜，中間存在巨大空白。

## Context / Trigger Conditions

- 正在設計 API marketplace、API 共享池、或 API gateway 產品
- 有一批 API 資源但 ARPU 太低，想提升單位收入
- 目標客群包含 AI Agent 開發者（可靠性需求極高）
- 想設計社群驅動的工具生態（用戶可以創建並賺錢）
- 需要將「技術產品」包裝成「非技術用戶也能用」的服務

## Solution

### 核心架構：三層遞進

```
Layer 3: 菜單層 (Recipe Store)
  ┌─────────────────────────────────┐
  │  預製工作流：2-5 個 API 組合    │  ← 最高價值
  │  客群：AI Agent、非技術用戶     │
  │  定價：各步 L2 費 + 編排費      │
  └──────────────┬──────────────────┘
                 │ 調用
Layer 2: 廚師層 (Smart Gateway)
  ┌──────────────┴──────────────────┐
  │  智慧路由 + fallback + 快取     │  ← 核心加值
  │  客群：AI Agent 開發者、SaaS    │
  │  定價：L1 + 1-2 WT 加值稅      │
  └──────────────┬──────────────────┘
                 │ 調用
Layer 1: 食材層 (Raw API Pool)
  ┌──────────────┴──────────────────┐
  │  原始 API 呼叫                  │  ← 基礎
  │  客群：開發者（會寫程式的人）   │
  │  定價：API 原價 + 服務費        │
  └─────────────────────────────────┘
```

### Layer 1: 食材層 (Raw API Pool)

就是傳統 API proxy，直接轉發請求。

| 項目 | 內容 |
|------|------|
| 提供什麼 | 原始 API 呼叫、統一認證、用量追蹤 |
| 客群 | 開發者（會寫程式的人） |
| 定價 | API 原價 + 平台服務費 |
| 價值主張 | 方便（一個 Key 用多個 API） |

### Layer 2: 廚師層 (Smart Gateway)

在原始 API 之上加入智慧中間層，這是**收入主力**。

| 項目 | 內容 |
|------|------|
| 提供什麼 | 智慧路由、自動 fallback、輸入預處理、輸出標準化、語意快取、統一錯誤處理 |
| 客群 | AI Agent 開發者、SaaS 公司、no-code 玩家 |
| 定價 | Layer 1 費用 + 1-2 WT 加值稅 |
| 價值主張 | 可靠性（98% → 99.97%）、省開發時間 |

**可靠性計算：**
```
單 API 成功率 = 98%
加三備用 fallback 後 = 1 - (0.02)^3 = 99.9992% ≈ 99.97%

多步驟場景（20 步）：
  無 Gateway: 0.95^20 = 35.8% 成功率
  有 Gateway: 0.9997^20 = 99.4% 成功率
```

**六大加值功能：**

1. **智慧路由** — 根據任務類型自動選最佳 API
2. **自動 Fallback** — API A 失敗自動切 B、C（三備用）
3. **輸入預處理** — 自動格式轉換、參數驗證
4. **輸出標準化** — 不同 API 回傳統一 schema
5. **語意快取** — 相似請求命中快取，省錢省時間
6. **統一錯誤處理** — 重試、指數退避、優雅降級

### Layer 3: 菜單層 (Recipe Store)

預製的多 API 組合工作流，像餐廳的菜單。

| 項目 | 內容 |
|------|------|
| 提供什麼 | 2-5 個 API 串成一個完整工作流（"菜"） |
| 客群 | AI Agent（60%）、非技術用戶（25%）、企業（15%） |
| 定價 | 各步 Layer 2 費用 + 編排費 |
| 價值主張 | 即插即用、零開發成本 |

**殺手功能：社群可以自己創建 Recipe 並賺分潤**

### 開發者五大 API 痛點（Layer 2 解決的核心問題）

| # | 痛點 | 錯誤碼 | 發生頻率 | Layer 2 解法 |
|---|------|--------|---------|-------------|
| 1 | Rate Limit | 429 Too Many Requests | 高峰 1-8% | 智慧路由 + 自動切換 |
| 2 | Timeout 雪崩 | ETIMEDOUT | 0.2-3% | 超時偵測 + fallback |
| 3 | Schema 漂移 | 回傳格式改變 | 每季發生 | 輸出標準化 |
| 4 | 認證失敗 | 401 Unauthorized | Key 輪換時 | Key 池自動輪換 |
| 5 | 語意不一致 | 不同 API 同欄位不同名 | 永遠存在 | 統一 schema mapping |

### 關鍵市場數據

| 數據點 | 來源 |
|--------|------|
| 75% AI Agent 任務生產環境失敗 | Superface.ai |
| 每步 95% → 20 步只剩 36% | Composio |
| 開發者願付 $100-30,000/月 for 智慧中間層 | Codex CLI 調研 |
| 可靠性溢價：20-60% | Codex CLI 開發者報告 |
| 市場空白：Zapier 太簡單、LangChain 太複雜 | 市場分析 |
| iPaaS 市場 $110B+ | Gartner |

### 收入對比

```
同一批 16 個 API，100 位用戶：

單層（只有 Layer 1）:
  $X/month

三層架構:
  Layer 1:  $X/month（基礎不變）
  Layer 2:  $600/月（加值稅收入）
  Layer 3:  $350/月（編排費收入）
  合計:    $1,400/月

提升: x3.1
```

### Recipe 經濟（社群飛輪）

三條賺錢路徑形成增長飛輪：

```
Route A: 貢獻 API Key → 被動收入（Key 被使用時賺）
Route B: 付 $ 買 Token → 使用 API 服務
Route C: 創建 Recipe → 被使用時賺分潤（新！）

分潤比例：
  API Key 貢獻者: 85%
  Recipe 創建者:  10%
  平台:           5%
```

**飛輪效應：**
```
更多 Recipe → 更多用戶 → 更多 API 呼叫
    ↑                          ↓
更多創建者 ← 更多分潤收入 ← 更多收入
```

### 定價策略模板

```
Layer 1 定價：
  1 WT = API 原價（Level 乘數）+ 服務費

Layer 2 定價：
  Layer 1 價格 + 1-2 WT（加值稅）
  加值稅理由：可靠性溢價 20-60%

Layer 3 定價：
  SUM(各步 Layer 2 價格) + 編排費（1-3 WT）
  編排費理由：零開發成本 + 即插即用
```

## Verification

1. **收入驗算**：三層收入加總是否 >= 單層 x2.5
2. **可靠性數學**：fallback 計算是否合理（不能假設 100%）
3. **分潤永續**：85% + 10% + 5% = 100%，平台 5% 能否覆蓋成本
4. **Recipe 可行性**：2-5 步串接的延遲是否可接受
5. **市場驗證**：目標客群是否真的存在（AI Agent 開發者）

## Example

### API Platform v1.7 實際案例

25 個預設 Recipe，分三類：

**AI 工作流類（10 個）：**
- 多語言翻譯管線（DeepL → GPT-4o-mini 校對 → 語意快取）
- 智慧摘要（URL 擷取 → Claude 摘要 → 關鍵字提取）

**數據處理類（8 個）：**
- 市場監控（CoinGecko 價格 → 異常偵測 → Telegram 通知）
- 競品分析（Brave 搜尋 → 內容擷取 → 比較報告）

**生活應用類（7 個）：**
- 旅行規劃（天氣 → 匯率 → 翻譯 → 行程生成）
- 寵物健康檢查（圖片辨識 → 症狀比對 → 獸醫建議）

**定價範例（翻譯管線 Recipe）：**
```
Step 1: DeepL 翻譯     = 2 WT (L1) + 1 WT (L2 加值) = 3 WT
Step 2: GPT-4o-mini 校對 = 1 WT (L1) + 1 WT (L2 加值) = 2 WT
Step 3: 語意快取        = 0 WT (命中快取免費)
編排費:                 = 2 WT
總計:                   = 7 WT（vs 各步分開叫 3 WT，多收 4 WT）
```

## Notes

- Layer 2 是利潤中心，Layer 1 和 Layer 3 是獲客工具
- Recipe Store 的核心不是技術，是社群 — 誰能吸引創建者誰就贏
- 三層架構也適用於非 API 場景（如：SaaS 工具組合、數據管線）
- 快取命中率是利潤關鍵：語意快取 30-50% 命中 = 省下的就是賺到的
- 不要一開始就做三層，先做 Layer 1 驗證需求，再逐步加 Layer 2、3
- AI Agent 可靠性問題是 2025-2026 最大痛點，這是 Layer 2 存在的根本理由

## References

- [Superface.ai Agent Reality Gap](https://superface.ai/blog/agent-reality-gap) — 75% Agent 任務失敗
- [Composio 2025 AI Agent Report](https://composio.dev/blog/why-ai-agent-pilots-fail-2026-integration-roadmap) — 多步驟成功率衰減
- [Cleanlab AI Agents in Production](https://cleanlab.ai/ai-agents-in-production-2025/) — 生產環境 Agent 挑戰
- [Galileo AI Agent Reliability](https://galileo.ai/blog/ai-agent-reliability-strategies) — Agent 可靠性策略

## See Also

- `api-pool-token-pricing-methodology` — Token 定價方法論（Layer 1 定價細節）
- `token-economics-audit-methodology` — Token 經濟審計（防套利驗證）
- `llm-api-cost-optimization` — LLM API 成本優化（Layer 2 快取策略）
