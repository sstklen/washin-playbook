---
name: ai-concierge-intent-router-pattern
description: |
  AI Concierge / Intent Router Pattern — 在 API marketplace 前面放一個 LLM 路由層，讓使用者用自然語言描述需求。
  使用時機：
  1. 設計 API marketplace 或 API 工具集合，需要智慧路由層
  2. 需要讓不熟悉 API 的用戶/AI Agent 用自然語言呼叫服務
  3. 想在現有 API 上加一層「AI 管家」而不重寫架構
  4. 需要同時服務人類用戶（自然語言）和 AI Agent（結構化）的統一端點
  5. 想分離路由成本（LLM）和工具成本（各 middleware 計費）
  核心洞察：Dual-Mode Endpoint（自然語言免費路由 vs 結構化），Internal HTTP Self-Call 重用 middleware，
  Groq Llama 3.3 70B 低溫確定性 JSON，串行 vs 並行智能偵測。
version: 1.0.0
date: 2026-02-12
---

# AI Concierge / Intent Router Pattern

## Problem

建立 API marketplace 時遇到三個挑戰：

1. **用戶體驗差** — 用戶需要知道每個 API 的簽名、參數、返回格式，學習曲線陡峭
2. **工具組合困難** — 多 API 組合時需要手寫編排邏輯（如：搜尋 → 翻譯 → 摘要），重複造輪子
3. **成本結構不清** — LLM 路由成本（Groq）和工具成本（API 調用）混在一起，無法按需計費
4. **AI Agent 支援差** — AI Agent 常用結構化 API 呼叫，但同時需要支援人類的自然語言模式

## Context / Trigger Conditions

**這個 Pattern 適合以下場景：**

- 設計 API marketplace、API 工具集合、或多工具的 AI agent 平台
- 需要「AI 管家」層智慧路由和工具組合
- 想支援兩種客群：非技術用戶（自然語言）+ AI Agent 開發者（結構化）
- 希望 LLM 路由成本和工具執行成本分離計費
- 使用 Hono / Express / FastAPI 等框架，想加一層 LLM 中間層
- 需要在現有 API 上加智慧而不改動底層實現

**技術棧要求：**
- Hono（推薦）或任何 REST API 框架
- Bun（推薦）或 Node.js/Python
- Groq API（便宜 LLM：Llama 3.3 70B）
- 現有的 REST API 端點

## Solution

### 核心架構：Dual-Mode Endpoint

同一個 `/concierge` 端點支援兩種模式：

```
┌─────────────────────────────────────────────────────┐
│                   /concierge 端點                    │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌─ 自然語言模式（人類用）                          │
│  │  "幫我搜尋最新的 AI 新聞然後翻譯成中文"          │
│  │  ↓                                              │
│  │  ✓ 路由費：$0.005（Groq LLM 成本）              │
│  │  ✓ Groq 解析意圖 → JSON { tools, params }      │
│  │  ✓ 調用自己的 API 端點 → 完全重用 middleware    │
│  │  ✓ 整合結果 → 回傳給用戶                        │
│  │                                                 │
│  └─ 結構化模式（AI Agent 用）                      │
│     { "tools": ["search", "translate"], ...}      │
│     ↓                                              │
│     ✓ 路由費：$0（跳過 Groq）                       │
│     ✓ 直接驗證工具 ID 合法性                        │
│     ✓ 調用自己的 API 端點 → 完全重用 middleware    │
│     ✓ 回傳結果                                     │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### Mode 1: 自然語言模式（Human-Friendly）

```typescript
// 用戶請求
POST /concierge
Content-Type: application/json

{
  "query": "搜尋最新 AI 新聞，然後翻譯成中文",
  "mode": "natural"  // 或省略，預設就是 natural
}

// 後端流程
1. 驗證用戶配額（來自 middleware）
2. 呼叫 Groq Llama 3.3 70B（低溫 0.1，JSON mode）
   - 輸入：用戶自然語言查詢 + 合法工具清單
   - 輸出：{ tools: ["search", "translate"], params: {...}}
3. 收 $0.005 路由費（Groq token 計費）
4. 用 fetch localhost 呼叫 /tools/{toolId}（重用現有 middleware）
   - Middleware 自動計費、驗證、限流、重試
5. 整合結果，回傳給用戶

// 回應
{
  "status": "success",
  "result": "最新 AI 新聞：[翻譯後的中文內容]",
  "cost": { "routing": 0.005, "tools": 0.15, "total": 0.155 },
  "trace": [
    { "tool": "search", "status": "success", "tokens": 180 },
    { "tool": "translate", "status": "success", "tokens": 120 }
  ]
}
```

### Mode 2: 結構化模式（AI Agent-Friendly）

```typescript
// AI Agent 請求（跳過 LLM 路由！）
POST /concierge
Content-Type: application/json

{
  "tools": ["search", "translate"],
  "toolParams": {
    "search": { "query": "latest AI news" },
    "translate": { "targetLang": "zh-CN" }
  },
  "mode": "structured"
}

// 後端流程
1. 驗證工具 ID 在合法清單中（快速檢查）
2. 無 Groq 調用，直接跳過 → 路由費 $0（節省錢！）
3. 用 fetch localhost 呼叫 /tools/{toolId}（重用 middleware）
4. 串行/並行執行（見下）
5. 回傳結果

// 回應
{
  "status": "success",
  "result": { ... },
  "cost": { "routing": 0, "tools": 0.15, "total": 0.15 },  // 沒有路由費！
  "trace": [...]
}
```

**結構化模式的優勢：**
- 路由費 $0（鼓勵 AI Agent 直接呼叫）
- 更快（不需要等 LLM）
- 對 Agent 開發者更透明（他們知道確切呼叫的工具）

### Internal HTTP Self-Call 設計

**為什麼 Concierge 要用 HTTP 呼叫自己而不是 import？**

```typescript
// ❌ 不好（緊耦合，無法重用 middleware）
import { searchAPI } from './tools/search.ts'
const result = await searchAPI(params)

// ✅ 好（鬆耦合，自動重用計費/速限/重試/驗證）
const response = await fetch('http://localhost:3000/tools/search', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(params)
})
```

**優勢：**

| 優勢 | 說明 |
|------|------|
| **Middleware 重用** | 計費、rate limit、驗證、重試都自動套用 |
| **隔離故障** | 一個工具故障不會癱瘓整個系統 |
| **統計完整** | 所有請求都經過同一套 middleware，數據一致 |
| **無需改動底層** | 現有 API 完全不知道被 Concierge 呼叫 |
| **可擴展** | 將來可以分佈式部署，Concierge 仍然適用 |

**實現方式（Hono）：**

```typescript
import { Hono } from 'hono'

const app = new Hono()

// 現有的工具端點（已有 middleware）
app.post('/tools/search', async (c) => {
  // middleware 自動：驗證、計費、限流
  const result = await search(c.req.json())
  return c.json(result)
})

// 新的 Concierge 端點
app.post('/concierge', async (c) => {
  const { query, mode = 'natural' } = await c.req.json()

  if (mode === 'natural') {
    // 呼叫 Groq 路由
    const routed = await routeWithGroq(query)

    // 用 fetch 呼叫自己（！重點）
    const toolRes = await fetch('http://localhost:3000/tools/' + routed.toolId, {
      method: 'POST',
      body: JSON.stringify(routed.params)
    })

    return c.json(await toolRes.json())
  }

  // 結構化模式省略 Groq，直接呼叫
  if (mode === 'structured') {
    const { tools, toolParams } = await c.req.json()

    for (const toolId of tools) {
      const res = await fetch(`http://localhost:3000/tools/${toolId}`, {
        method: 'POST',
        body: JSON.stringify(toolParams[toolId])
      })
      // 處理結果
    }
  }
})
```

### Groq JSON 輸出設定

確保 Groq 返回結構化 JSON，且格式一致：

```typescript
const groqRouting = async (userQuery: string, toolsList: string[]) => {
  const response = await groq.chat.completions.create({
    model: 'mixtral-8x7b-32768', // 或 llama-3.3-70b-versatile
    temperature: 0.1,  // 低溫 = 確定性
    response_format: {
      type: 'json_object'
    },
    messages: [{
      role: 'user',
      content: `
        用戶查詢：${userQuery}

        可用工具：${toolsLis.join(', ')}

        回傳 JSON（無任何額外文字）：
        {
          "tools": ["tool_id_1", "tool_id_2"],
          "params": {
            "tool_id_1": { "key": "value" },
            "tool_id_2": { "key": "value" }
          },
          "reason": "為什麼選這些工具"
        }
      `
    }]
  })

  // 驗證返回的工具 ID 合法性（安全檢查！）
  const routed = JSON.parse(response.choices[0].message.content)

  const validTools = routed.tools.filter(t => toolsListSet.has(t))
  if (validTools.length === 0) throw new Error('No valid tools selected')

  return { ...routed, tools: validTools }
}
```

**低溫設定的重要性：**
- `temperature: 0.1` = 模型輸出幾乎確定，不會隨機亂選工具
- 配合 `response_format: json_object` = JSON 格式保證
- 即使提示詞不完美，也能穩定返回正確結構

### 串行 vs 並行智能偵測

根據工具組合自動決定執行策略：

```typescript
const executeTools = async (tools: string[], params: any) => {
  // 檢測是否需要串行
  const chainedPatterns = {
    'search→translate': ['search', 'translate'],
    'search→summary': ['search', 'summary'],
    'fetch→extract': ['fetch', 'extract']
  }

  const toolChain = tools.join('→')
  const isChained = Object.values(chainedPatterns).some(pattern =>
    pattern.every((t, i) => tools[i] === t)
  )

  if (isChained) {
    // 串行：前一個的輸出是後一個的輸入
    let result = null
    for (const toolId of tools) {
      const toolParams = { ...params[toolId] }

      // 如果有前置結果，注入為 context
      if (result) {
        toolParams.context = result
      }

      const res = await fetch(`http://localhost:3000/tools/${toolId}`, {
        method: 'POST',
        body: JSON.stringify(toolParams)
      })
      result = await res.json()
    }
    return result

  } else {
    // 並行：工具之間無依賴，一起跑
    const promises = tools.map(toolId =>
      fetch(`http://localhost:3000/tools/${toolId}`, {
        method: 'POST',
        body: JSON.stringify(params[toolId])
      }).then(r => r.json())
    )

    const results = await Promise.allSettled(promises)
    return results.map((r, i) => ({
      tool: tools[i],
      result: r.status === 'fulfilled' ? r.value : { error: r.reason }
    }))
  }
}
```

**自動偵測邏輯：**

| 工具組合 | 執行策略 | 原因 |
|---------|--------|------|
| search → translate | 串行 | 翻譯需要搜尋結果 |
| search → summary | 串行 | 摘要需要搜尋內容 |
| fetch → extract | 串行 | 提取需要先獲取內容 |
| search ⊥ sentiment | 並行 | 搜尋和情感分析無關 |
| price_check ⊥ currency | 並行 | 價格檢查和匯率換算無關 |

### 計費設計

**路由費（僅自然語言模式）：**

```typescript
// 自然語言模式
{
  "mode": "natural",
  "query": "搜尋 AI 新聞並翻譯",
  "cost": {
    "routing": 0.005,    // Groq 調用費（一次性）
    "search": 0.10,      // 搜尋工具費
    "translate": 0.05,   // 翻譯工具費
    "total": 0.155
  }
}

// 結構化模式
{
  "mode": "structured",
  "tools": ["search", "translate"],
  "cost": {
    "routing": 0,        // 無 Groq 調用！
    "search": 0.10,      // 搜尋工具費
    "translate": 0.05,   // 翻譯工具費
    "total": 0.15        // 便宜 $0.005
  }
}
```

**定價策略：**

| 項目 | 計費 | 說明 |
|------|------|------|
| 自然語言路由 | $0.005 / 請求 | Groq Llama 3.3 近似成本 |
| 結構化路由 | $0 | 鼓勵 AI Agent 直接用 |
| 工具費 | 各 middleware 獨立計費 | 透明計費 |

## Verification

1. **Groq JSON 輸出穩定性** — 測試 100 次 Groq 呼叫，檢查 JSON 是否總是有效（應 >99%）
2. **HTTP 自呼叫延遲** — 測試 Concierge 呼叫自己的往返時間（應 <50ms local）
3. **串行 vs 並行邏輯** — 確認工具組合檢測準確率 (>95%)
4. **計費準確性** — 對比 Groq API bill 和實際收費（誤差 <5%）
5. **成本對比** — 自然語言 vs 結構化平均成本差異（應 ~$0.005）
6. **中間層故障隔離** — 關閉某個工具，確認其他工具仍可用

## Example

### 實際案例：多工具編排

**場景：** 用戶想「監控競品動態，自動翻譯和總結」

**自然語言模式：**

```bash
curl -X POST http://localhost:3000/concierge \
  -H 'Content-Type: application/json' \
  -d '{
    "query": "監控 OpenAI 和 Google 的最新動態，翻譯成中文，然後產生 1 句摘要",
    "mode": "natural"
  }'
```

**後端執行流程：**

```
1. Groq 路由：
   輸入：上述查詢
   輸出：{
     "tools": ["search", "translate", "summarize"],
     "params": {
       "search": { "query": "OpenAI Google latest news", "limit": 5 },
       "translate": { "target": "zh-CN" },
       "summarize": { "max_sentences": 1 }
     }
   }
   成本：$0.005

2. 串行執行檢測：search → translate → summarize = 串行

3. 執行：
   - fetch http://localhost:3000/tools/search { query: "..." }
     結果：["article1", "article2", ...]
     成本：$0.10

   - fetch http://localhost:3000/tools/translate { content: "[上述文章]", target: "zh-CN" }
     結果：["文章1中文", "文章2中文", ...]
     成本：$0.05

   - fetch http://localhost:3000/tools/summarize { articles: "[中文文章]", max_sentences: 1 }
     結果："OpenAI 發布新 API，Google 推出對標產品"
     成本：$0.02

4. 回傳：
   {
     "result": "OpenAI 發布新 API，Google 推出對標產品",
     "cost": {
       "routing": 0.005,
       "search": 0.10,
       "translate": 0.05,
       "summarize": 0.02,
       "total": 0.175
     }
   }
```

**結構化模式（AI Agent 直接用）：**

```bash
curl -X POST http://localhost:3000/concierge \
  -H 'Content-Type: application/json' \
  -d '{
    "mode": "structured",
    "tools": ["search", "translate", "summarize"],
    "toolParams": {
      "search": { "query": "OpenAI Google latest news", "limit": 5 },
      "translate": { "target": "zh-CN" },
      "summarize": { "max_sentences": 1 }
    }
  }'
```

成本省 $0.005（無路由費）。

## Implementation Checklist

- [ ] 建立 Hono 應用（或現有框架）
- [ ] 實現 Groq 集成（低溫 0.1，JSON mode）
- [ ] 實現工具 ID 白名單驗證
- [ ] 實現 HTTP 自呼叫機制（localhost 或容器內網）
- [ ] 實現串行/並行偵測邏輯
- [ ] 測試 Groq JSON 穩定性 (>99% 成功率)
- [ ] 實現成本追蹤（每個工具、每個路由）
- [ ] 實現 Dual-Mode 端點路由
- [ ] 實現錯誤處理和 fallback（工具故障時）
- [ ] 實現成本透明回傳（每次請求顯示費用明細）
- [ ] 測試整個流程（自然語言→Groq→工具執行→結果）
- [ ] 發布文檔（API 簽名、示例、定價）

## Notes

- **Groq 選擇** — Llama 3.3 70B 足夠，比 GPT-4 便宜 10 倍
- **低溫很關鍵** — temperature: 0.1 + json_object 才能確保穩定的結構化輸出
- **HTTP 自呼叫開銷小** — Local 環境 <50ms，可接受；生產用容器內網 <10ms
- **串行偵測簡單** — 不用複雜的依賴圖，簡單的字符串匹配就夠
- **Permission / Rate Limit** — Middleware 自動處理，Concierge 無需重複驗證
- **Logging / Tracing** — 記錄每次 Groq 呼叫和工具執行，便於除錯和成本優化
- **Cold Start** — 如果在 serverless（如 Vercel）上跑，首次 Groq 呼叫有 cold start；可用預熱
- **用戶教育** — 告訴用戶自然語言模式比結構化模式多 $0.005，但更易用

## References

- [Groq API Documentation](https://console.groq.com/docs) — API 簽名、模型選擇
- [Hono Web Framework](https://hono.dev/) — 輕量 REST 框架
- [HTTP Caching and Middleware](https://developer.mozilla.org/en-US/docs/Web/HTTP/Caching) — 請求重用原理
- [AI Agent Orchestration Patterns](https://github.com/langchain-ai/langchain) — 多工具編排思想

## See Also

- `api-platform-three-layer-architecture` — API marketplace 三層架構（Layer 2 可結合此 Pattern）
- `api-pool-token-pricing-methodology` — Token 計費細節（工具層定價參考）
- `multi-agent-workflow-design` — 多 Agent 設計（Concierge 可作為 Agent 的智慧路由層）

---

*實現建議：先在本地用 Hono + Bun 實現完整的端到端流程，驗證 Groq 穩定性後再上線。*
