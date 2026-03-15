---
name: chatbot-promise-execution-gap
description: |
  修復 Chatbot「說但沒做」的 bug 模式 - AI 回覆說「我發給你看」但從不實際發送。
  使用時機：(1) Bot 說「我發給你看」「我找給你」但用戶沒收到東西，
  (2) AI 回覆中承諾執行動作但實際代碼沒觸發，
  (3) 動態內容發送邏輯使用 currentMessage 而非 conversationContext，
  (4) 對話中的地點/關鍵字在之前訊息中，但發送邏輯只看當前訊息。
  根本原因：AI 回覆和實際執行邏輯是分離的，執行邏輯缺少足夠上下文。
author: Claude Code
version: 1.0.0
date: 2026-02-06
---

# Chatbot「說但沒做」Bug 模式

## Problem

Telegram/Line Bot 的 AI 回覆說「好，我發給你看」，但用戶從來沒收到影片/圖片。

**症狀**：
- 用戶說「草津溫泉 想看影片」
- Bot 回覆：「好的，我發給你看一些草津溫泉的影片！」
- 但用戶**沒有收到任何 YouTube 連結**
- 對話歷史顯示多次「發給你看」但沒有實際 URL

**根本原因**：
AI 回覆和實際發送邏輯是**分離**的兩個步驟：
1. AI (Claude) 生成回覆：「好，我發給你看」
2. 代碼邏輯決定是否發送影片

問題出在第 2 步：發送邏輯使用 `currentMessage`（只有「想看」），
而不是 `conversationContext`（包含「草津溫泉」），
導致提取不到地點關鍵字，影片推薦失敗。

## Context / Trigger Conditions

**當你看到這些症狀時使用此 Skill**：

- 用戶反映「Bot 說要發但沒發」
- 對話歷史有「發給你看」「我找給你」但沒有 URL
- 影片/媒體發送邏輯使用 `currentMessage` 變數
- `smartRecommendVideos()` 返回空陣列
- Console log 顯示「沒有找到相關影片推薦」

**技術環境**：
- grammY / Telegraf Telegram Bot
- Serverless (Vercel / Cloudflare Worker)
- 有 AI 對話 + 獨立的媒體發送邏輯

## Solution

### Step 1: 診斷問題

查詢對話歷史，找出「說但沒做」的模式：

```sql
-- Supabase 查詢
SELECT
  user_id,
  conversation_history::text
FROM telegram_sessions
WHERE conversation_history::text LIKE '%發給你看%'
  AND conversation_history::text NOT LIKE '%youtube.com%'
ORDER BY updated_at DESC;
```

或用腳本：

```typescript
// 分析對話歷史
function detectPromiseExecutionGap(history: Array<{role: string; content: string}>): boolean {
  const botMessages = history.filter(h => h.role === 'assistant').map(h => h.content);

  // Bot 說要發
  const promisedToSend = botMessages.some(m => /發給你看|給你看|我找給你/.test(m));

  // 但沒有實際發送 URL
  const actuallySent = botMessages.some(m => /youtube\.com|http/.test(m));

  return promisedToSend && !actuallySent;
}
```

### Step 2: 找到根因 - currentMessage vs conversationContext

**❌ 錯誤代碼**：
```typescript
// handlers.ts
const currentMessage = ctx.message?.text || '';  // 只有「想看」

// 用當前訊息搜尋影片 - 沒有地點資訊！
const recommendations = await smartRecommendVideos(currentMessage, 1);
```

**✅ 正確代碼**：
```typescript
// handlers.ts
const currentMessage = ctx.message?.text || '';

// 🔑 從對話歷史中提取上下文（包含地點資訊）
const recentHistory = ctx.session.conversationHistory.slice(-6);
const conversationContext = recentHistory
  .map(h => h.content)
  .join(' ');

// 用對話歷史搜尋影片 - 包含「草津溫泉」！
const recommendations = await smartRecommendVideos(conversationContext, 1);
```

### Step 3: 加入詳細 logging

```typescript
if (shouldSendVideo) {
  console.log(`🎬 [${userId}] 觸發影片推薦`);
  console.log(`🎬 [${userId}] 當前訊息: "${currentMessage}"`);
  console.log(`🎬 [${userId}] 對話上下文: "${conversationContext.substring(0, 200)}..."`);

  const recommendations = await smartRecommendVideos(conversationContext, 1);

  console.log(`🎬 [${userId}] 推薦結果: ${recommendations.length} 部影片`);

  if (recommendations.length > 0) {
    const rec = recommendations[0];
    console.log(`🎬 [${userId}] 影片 URL: ${rec.video.url}`);
    await ctx.reply(`🎬 ${rec.video.title}\n\n${rec.video.url}`);
    console.log(`🎬 [${userId}] ✅ 發送影片成功`);
  } else {
    console.log(`🎬 [${userId}] ❌ 沒有找到相關影片`);
    // 🔑 告訴用戶，而不是沉默
    await ctx.reply('🔍 正在搜尋相關影片，如果幾秒內沒收到，可能目前沒有匹配的影片');
  }
}
```

### Step 4: 確保發送失敗時也有回饋

```typescript
// 不要沉默失敗！
if (recommendations.length === 0) {
  await ctx.reply('🔍 暫時沒有找到相關影片，但我可以幫你用文字介紹這個地方');
}
```

## Verification

### 1. 查看 Vercel Logs

```bash
vercel logs --follow
```

應該看到：
```
🎬 [123] 觸發影片推薦
🎬 [123] 當前訊息: "想看"
🎬 [123] 對話上下文: "用戶提到草津溫泉... 想看"
🎬 [123] 推薦結果: 1 部影片
🎬 [123] ✅ 發送影片成功
```

### 2. 對話測試

```
你：草津溫泉有什麼好玩的？
Bot：草津溫泉是日本三名泉之一...
你：想看影片
Bot：好的，我發給你看！
Bot：🎬 草津温泉 観光おすすめスポット  ← 這個必須出現！
     https://youtube.com/watch?v=xxxxx
```

### 3. 再次查詢對話歷史

修復後，搜尋「發給你看」的對話應該也有 URL：

```sql
SELECT conversation_history::text
FROM telegram_sessions
WHERE conversation_history::text LIKE '%發給你看%'
  AND conversation_history::text LIKE '%youtube.com%'  -- 現在應該有了！
```

## Example

### Before（bug）

```typescript
// handlers.ts - 第 824 行（修復前）
const recommendations = await smartRecommendVideos(currentMessage, 1);
// currentMessage = "想看"
// → 沒有地點 → 返回空陣列 → 用戶沒收到影片
```

### After（修復後）

```typescript
// handlers.ts - 修復後
const recommendations = await smartRecommendVideos(conversationContext, 1);
// conversationContext = "草津溫泉有什麼好玩的 ... 想看"
// → 提取到「草津溫泉」→ 搜尋影片 → 用戶收到影片
```

## Notes

### 為什麼 AI 會說「我發給你看」但沒發？

1. **AI 和執行邏輯分離**：Claude 生成的回覆只是文字，它不能真的「發送」東西
2. **執行邏輯獨立判斷**：代碼根據自己的條件判斷是否發送
3. **上下文不同步**：AI 看到完整對話，但執行邏輯只看 `currentMessage`

### 通用設計原則

當 AI 回覆可能承諾某個動作時，**執行邏輯必須使用相同的上下文**：

```typescript
// ❌ 不一致
const aiResponse = await claude.chat(conversationHistory);  // AI 看完整歷史
const action = determineAction(currentMessage);  // 執行只看當前

// ✅ 一致
const aiResponse = await claude.chat(conversationHistory);  // AI 看完整歷史
const action = determineAction(conversationHistory);  // 執行也看完整歷史
```

### 類似問題

這個模式也可能出現在：
- 「我幫你查」但沒有查詢結果
- 「我傳給你」但沒有發送檔案
- 「我記下了」但沒有實際儲存

## See Also

- `telegram-bot-conversation-history-debugging` - 類似的對話歷史問題，但症狀是「回答不相關」
- `telegram-bot-conversation-history-debugging` - 監控對話品質，偵測這類問題

## References

- [grammY Session](https://grammy.dev/plugins/session)
- [Vercel Serverless Functions Logs](https://vercel.com/docs/functions/logs)
