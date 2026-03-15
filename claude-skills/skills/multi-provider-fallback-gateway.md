---
name: multi-provider-fallback-gateway
description: |
  多供應商容錯閘道（Smart Gateway）架構模式 — 將多個同類 API 供應商包裝為單一高可靠端點。
  使用時機：
  1. 建立 API 代理/市集，需要 99.97% 可靠性（單一供應商只有 98%）
  2. 需要「策略路由」（fast/smart/cheap）讓用戶選最快、最好、或最便宜
  3. 多 LLM 供應商（Groq/DeepSeek/OpenAI/Anthropic）需要統一介面 + 自動 fallback
  4. 多搜尋引擎（Brave/Tavily/Google）需要統一結果格式
  5. 需要 pre-charge/refund 的計費模式（先扣後退）
  6. OpenAI 相容格式的 LLM 路由（大部分 LLM 都支援）
  7. 需要即時可靠性統計追蹤（成功率、fallback 率、平均回應時間）
  關鍵字：smart gateway, fallback, multi-provider, LLM router, API proxy, strategy routing
version: 1.0.0
date: 2026-02-12
author: Claude Code (production-api session)
---

# Multi-Provider Fallback Gateway（多供應商容錯閘道）

## Problem

單一 API 供應商的可靠性約 98%（每月 ~14 小時停機）。對於付費 API 市集來說，這不夠。
同時，不同用戶有不同需求：有人要快、有人要好、有人要便宜。

## Context / Trigger Conditions

- 你正在建立 API 代理/市集，需要更高可靠性
- 你有多個同類 API 供應商（例如 Groq + DeepSeek + OpenAI 都是 LLM）
- 用戶需要選擇「策略」而非「供應商」
- 需要統一不同供應商的輸入/輸出格式
- 需要付費計量（先扣後退模式）

## Solution

### 核心架構：三層分離

```
Layer 1（食材）= 單一 API 代購 → 直接轉發，壞了就壞了
Layer 2（廚師）= 智慧路由 + Fallback → 自動切換，打不死
Layer 3（菜單）= 多 API 組合 Recipe → 搜尋+翻譯+摘要一站完成
```

### 實作步驟

#### 1. 定義統一輸出格式（供應商無關）

```typescript
// LLM 統一結果
interface LLMCallResult {
  text: string;
  model: string;
  tokensUsed: number;
  inputTokens: number;
  outputTokens: number;
}

// 搜尋統一結果
interface UnifiedSearchResult {
  title: string;
  url: string;
  snippet: string;
  source: string;
}
```

#### 2. 每個供應商封裝為獨立 async function

```typescript
async function callGroqLLM(messages, maxTokens): Promise<LLMCallResult> {
  const key = getKeyOrEnv('groq', 'GROQ_API_KEY');
  if (!key) throw new Error('Groq 無可用 Key');

  const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${key}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'llama-3.3-70b-versatile',
      messages,
      max_tokens: maxTokens,
      temperature: 0.7,
    }),
    signal: AbortSignal.timeout(15000), // 各供應商不同 timeout
  });

  // 統一輸出格式
  const data = await response.json();
  reportKeyResult('groq', true); // 回報成功
  return {
    text: data.choices[0].message.content,
    model: data.model,
    tokensUsed: data.usage.total_tokens,
    inputTokens: data.usage.prompt_tokens,
    outputTokens: data.usage.completion_tokens,
  };
}
```

**關鍵設計：**
- 每個函數獨立（不互相依賴）
- 統一 throw Error（不 return null）
- 回報 key 使用結果（成功/失敗），支持 key 輪替
- 各供應商有不同的 timeout（Groq 快 → 15s, DeepSeek 慢 → 30s）

#### 3. 策略路由引擎

```typescript
type LLMProvider = {
  name: string;
  callFn: (messages: any[], maxTokens: number) => Promise<LLMCallResult>;
};

// 根據策略決定呼叫順序
function getProviderChain(strategy: string): LLMProvider[] {
  switch (strategy) {
    case 'fast':   return [groq, deepseek];   // 快→穩
    case 'smart':  return [deepseek, groq];   // 好→快
    case 'cheap':  return [groq, deepseek];   // 便宜→fallback
    default:       return [groq, deepseek];
  }
}

// 執行 fallback 鏈
let result: LLMCallResult | null = null;
let sourceUsed = '';
let fallbackUsed = false;

for (const provider of providerChain) {
  try {
    result = await provider.callFn(messages, maxTokens);
    sourceUsed = provider.name;
    break; // 成功就停
  } catch (err) {
    log.warn(`${provider.name} 失敗: ${err.message}`);
    fallbackUsed = true;
    continue; // 試下一個
  }
}

if (!result) throw new Error('所有供應商都失敗');
```

#### 4. Pre-charge / Refund 計費模式

```typescript
// 先扣款
const chargeResult = preCharge(account.id, 'smart-llm');
if (!chargeResult.success) return c.json({ error: '餘額不足' }, 402);

try {
  // 執行業務邏輯
  const result = await processRequest();

  // 成功 → 不退款（收走！）
  return c.json({ success: true, result });
} catch (error) {
  // 失敗 → 全額退款
  refund(account.id, chargeResult.amount, `${service} 失敗退款`);
  return c.json({ error: '處理失敗，已自動退款' }, 502);
}
```

#### 5. 即時可靠性統計

```typescript
interface ReliabilityStats {
  totalCalls: number;
  successCalls: number;
  fallbackCalls: number;
  averageResponseMs: number;
  bySource: Record<string, {
    attempts: number;
    successes: number;
    failures: number;
  }>;
}

// 每次呼叫後記錄
function recordStats(source, success, responseMs, fallbackUsed) {
  stats.totalCalls++;
  if (success) stats.successCalls++;
  if (fallbackUsed) stats.fallbackCalls++;
  // 滾動平均
  stats.averageResponseMs =
    (stats.averageResponseMs * (stats.totalCalls - 1) + responseMs) / stats.totalCalls;
}

// 公開端點讓用戶查看
// GET /api/v2/stats → 回傳即時統計
```

### OpenAI 相容格式技巧

大部分 LLM 供應商（Groq、DeepSeek、Together AI、Fireworks）都支援 OpenAI 相容格式，差異僅在：

| 供應商 | Base URL | 特有參數 | Timeout 建議 |
|--------|----------|---------|-------------|
| Groq | api.groq.com/openai/v1 | 無 | 15s（LPU 極快） |
| DeepSeek | api.deepseek.com | 無 | 30s（推理較慢但品質高） |
| Together AI | api.together.xyz/v1 | 無 | 20s |
| Fireworks | api.fireworks.ai/inference/v1 | 無 | 20s |
| OpenAI | api.openai.com/v1 | 有最多特有參數 | 30s |

**這意味著同一套 callLLM 函數只需改 URL + model name + timeout 就能支持新供應商！**

## Verification

```bash
# 1. 正常呼叫（主供應商成功）
curl -s -X POST http://localhost:3000/api/v2/llm \
  -H "Authorization: Bearer wv_xxx" \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"hello"}],"strategy":"fast"}'
# 預期：200, sourceUsed: "groq", fallbackUsed: false

# 2. 查看可靠性統計
curl -s http://localhost:3000/api/v2/stats
# 預期：successRate, fallbackRate, avgResponseMs

# 3. 查看服務目錄
curl -s http://localhost:3000/api/v2/services
# 預期：列出所有 Layer 2 服務 + 定價 + 狀態
```

## Example

完整實作見：`production-api/src/api/gateway.ts`

這個檔案實作了：
- **Smart Search**（Brave → Tavily 二級 fallback + Groq AI 摘要）
- **Smart LLM Router**（Groq ↔ DeepSeek 雙向 fallback + 三種策略）
- 統一計費、統一統計、統一錯誤處理

## Notes

### 可靠性公式
- 單一供應商：98% 可靠
- 雙供應商 fallback：1 - (1-0.98)^2 = 99.96%
- 三供應商 fallback：1 - (1-0.98)^3 = 99.9992%

### 策略設計建議
- **fast**：最快的供應商先打（Groq LPU ≈ 1-3秒 vs DeepSeek ≈ 5-15秒）
- **smart**：品質最好的先打（DeepSeek reasoning > Groq）
- **cheap**：最便宜的先打，失敗才用貴的（Groq 免費 → DeepSeek 付費）

### 定價原則
Layer 2 服務價格 = 最差情況成本 × 2~3 倍
- 最差情況 = 所有供應商都打一次的成本
- 例：Groq $0 + DeepSeek $0.003 = $0.003 → 定價 $0.008

### See Also
- `api-platform-three-layer-architecture` — Layer 1/2/3 分層設計
- `api-proxy-quota-hardstop-pattern` — 額度管理
- `api-pool-token-pricing-methodology` — 代幣定價方法論

## References
- [OpenAI Chat Completions API](https://platform.openai.com/docs/api-reference/chat/create)
- [Groq API Docs](https://console.groq.com/docs/overview)
- [DeepSeek API Docs](https://platform.deepseek.com/api-docs)
