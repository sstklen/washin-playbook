---
name: serverless-api-timeout-pattern
description: |
  修復 Serverless 環境（Vercel/Cloudflare Worker）中 Bot 不回覆/卡死的問題。
  使用時機：(1) Bot 收到訊息但沒有回覆，(2) Vercel logs 顯示請求超時，
  (3) 外部 API 調用（Supabase/Claude/Apify）沒有設置超時，
  (4) 用 Promise.race 實現超時機制。
  根本原因：Serverless 有 30-60 秒硬限制，外部 API 可能無限等待。
author: Claude Code
version: 1.0.0
date: 2026-02-06
---

# Serverless API 超時模式

## Problem

Telegram/Line Bot 部署在 Vercel/Cloudflare Worker 上，用戶發訊息後 Bot 不回覆。

**症狀**：
- 用戶發送訊息 → 收到 webhook → 沒有回覆
- Vercel logs 顯示：「請求超時」或無後續日誌
- 本地測試正常，部署後卡死

**根本原因**：
- Vercel Serverless 有 30-60 秒硬限制
- Supabase 查詢、Claude API、Apify 爬取可能超過這個時間
- 這些 API **沒有內建超時**，會無限等待
- 當外部 API 慢或不穩定時，整個請求卡住

## Context / Trigger Conditions

**當你看到這些症狀時使用此 Skill**：

- Bot 部署在 Vercel/Cloudflare Worker/AWS Lambda
- 用戶反映「Bot 不理人」「Bot 卡住」
- Vercel logs 顯示 webhook 收到但無後續
- 代碼中有 `await supabase.from(...)` 或 `await client.messages.create(...)`
- 這些 await 沒有包裝 timeout

**技術環境**：
- Vercel Serverless (30s hobby / 60s pro)
- Cloudflare Worker (30s)
- AWS Lambda (15min max, 但通常設更短)

## Solution

### 核心模式：Promise.race + Timeout

```typescript
// 🔑 通用超時包裝函數
async function withTimeout<T>(
  promise: Promise<T>,
  timeoutMs: number,
  fallback: T
): Promise<T> {
  const timeoutPromise = new Promise<T>((resolve) =>
    setTimeout(() => resolve(fallback), timeoutMs)
  );
  return Promise.race([promise, timeoutPromise]);
}

// 用法
const result = await withTimeout(
  supabase.from('table').select('*'),
  5000,  // 5 秒超時
  { data: [], error: null }  // 超時時的 fallback
);
```

### 實際應用：Supabase 查詢

```typescript
// ❌ 錯誤：沒有超時，可能無限等待
const knowledgeContext = await searchRelevantKnowledge(message, history);

// ✅ 正確：5 秒超時
let knowledgeContext = '';
try {
  const knowledgePromise = searchRelevantKnowledge(message, history);
  const timeoutPromise = new Promise<string>((_, reject) =>
    setTimeout(() => reject(new Error('知識庫搜尋超時')), 5000)
  );
  knowledgeContext = await Promise.race([knowledgePromise, timeoutPromise]);
} catch (e) {
  console.log('知識庫搜尋跳過:', e);
  knowledgeContext = '';  // 超時時使用空上下文
}
```

### 實際應用：Claude API

```typescript
// ❌ 錯誤：沒有超時
const response = await client.messages.create({...});

// ✅ 正確：15 秒超時
const apiPromise = client.messages.create({
  model: 'claude-sonnet-4-20250514',
  max_tokens: 80,
  messages: [...]
});

const timeoutPromise = new Promise<never>((_, reject) =>
  setTimeout(() => reject(new Error('Claude API 超時')), 15000)
);

const response = await Promise.race([apiPromise, timeoutPromise]);
```

### 超時時間建議

| 操作 | 建議超時 | 原因 |
|------|---------|------|
| Supabase 簡單查詢 | 3-5 秒 | 通常 < 1 秒 |
| Supabase 複雜查詢 | 5-10 秒 | join/聚合較慢 |
| Claude API (80 tokens) | 10-15 秒 | 通常 2-5 秒 |
| Claude API (1000 tokens) | 20-30 秒 | 可能更長 |
| Apify 爬取 | 跳過或背景執行 | 可能 30+ 秒 |

### 總時間控制

```typescript
// Vercel Pro 有 60 秒限制，要留 buffer
const TOTAL_BUDGET = 50000;  // 50 秒總預算

const startTime = Date.now();

// 步驟 1：知識庫（5 秒）
const remainingTime1 = TOTAL_BUDGET - (Date.now() - startTime);
const knowledge = await withTimeout(searchKnowledge(), Math.min(5000, remainingTime1), '');

// 步驟 2：Claude API（剩餘時間 - 5 秒 buffer）
const remainingTime2 = TOTAL_BUDGET - (Date.now() - startTime) - 5000;
const response = await withTimeout(callClaude(), remainingTime2, fallbackResponse);

// 步驟 3：回覆用戶（應該在 50 秒內完成）
await ctx.reply(response);
```

## Verification

### 1. 加入時間日誌

```typescript
const startTime = Date.now();

// 各步驟後
console.log(`[${Date.now() - startTime}ms] 知識庫搜尋完成`);
console.log(`[${Date.now() - startTime}ms] Claude API 完成`);
console.log(`[${Date.now() - startTime}ms] 回覆發送完成`);
```

### 2. 檢查 Vercel logs

部署後查看 logs，確認：
- 每個步驟都在預期時間內完成
- 沒有「Function timeout」錯誤
- 用戶收到回覆

### 3. 測試超時情況

```typescript
// 故意加入延遲測試超時處理
const slowQuery = new Promise(resolve => setTimeout(() => resolve('結果'), 10000));
const result = await withTimeout(slowQuery, 3000, '超時 fallback');
console.log(result);  // 應該是 '超時 fallback'
```

## Example

### Before（Bot 不回覆）

```typescript
async function handleMessage(ctx) {
  // 這些都可能卡住
  const knowledge = await searchKnowledge(message);  // 可能 10+ 秒
  const response = await claude.messages.create({...});  // 可能 20+ 秒
  await ctx.reply(response);  // Vercel 早就超時了
}
```

### After（穩定回覆）

```typescript
async function handleMessage(ctx) {
  // 知識庫：5 秒超時
  let knowledge = '';
  try {
    knowledge = await Promise.race([
      searchKnowledge(message),
      new Promise((_, reject) => setTimeout(() => reject(), 5000))
    ]);
  } catch { knowledge = ''; }

  // Claude：15 秒超時
  let response = '不好意思，請稍後再試。';
  try {
    const apiResult = await Promise.race([
      claude.messages.create({...}),
      new Promise((_, reject) => setTimeout(() => reject(), 15000))
    ]);
    response = apiResult.content[0].text;
  } catch { /* 使用 fallback */ }

  // 回覆（應該在 25 秒內到達這裡）
  await ctx.reply(response);
}
```

## Notes

### 為什麼不用 AbortController？

- Claude SDK 不支援 AbortController
- Supabase JS SDK 支援但行為不一致
- Promise.race 是最通用的方案

### Fallback 策略

超時時不要讓用戶看到錯誤，而是：
1. 使用預設回覆：「讓我想想...」
2. 跳過非必要步驟（如知識庫搜尋）
3. 使用較短的回覆（減少 token）

### 監控建議

加入 metrics 追蹤：
- 每個外部 API 的平均延遲
- 超時發生的頻率
- 哪個步驟最常超時

## See Also

- `chatbot-promise-execution-gap` - Bot「說但沒做」的問題
- `telegram-bot-conversation-history-debugging` - grammY 在 Vercel 的初始化問題

## References

- [Vercel Serverless Functions Limits](https://vercel.com/docs/functions/serverless-functions/runtimes#maxduration)
- [Cloudflare Workers Limits](https://developers.cloudflare.com/workers/platform/limits/)
