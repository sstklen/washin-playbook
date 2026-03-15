---
name: telegram-bot-conversation-history-debugging
description: |
  Telegram Bot 對話歷史、session 儲存、初始化、監控完整方案。使用時機：
  (1) Bot 回答不相關內容，每次只處理當前訊息沒有上下文，
  (2) "TypeError: index.filter is not a function" 錯誤，KV 索引格式問題，
  (3) Serverless 環境 session 丟失，每次請求都是初始值，
  (4) grammY bot "Bot not initialized!" 錯誤（Vercel/Lambda），
  (5) 需要監控對話品質、發現「說但沒做」的 bug。
  涵蓋對話歷史管理（Worker + KV）、Supabase Session Storage Adapter、
  serverless bot.init()、對話品質監控（SQL 查詢 + 自動檢測）。
author: Claude Code + Washin Village
version: 2.0.0
date: 2026-02-10
---

# Telegram Bot 對話歷史調試

## Problem

Telegram Bot 回答不相關內容：

**症狀**：
- 用戶問新問題，Bot 回答上一個話題的內容
- Bot 無法記住對話上下文
- 追問時 Bot 不知道在問什麼
- Cloudflare Worker 日誌顯示：`TypeError: index.filter is not a function`

**根本原因**：
1. Worker 沒有讀取對話歷史，每次只處理當前訊息
2. KV 索引格式錯誤（`index` 應該是 `index.messages`）
3. 沒有將歷史傳給 Claude API

## Context / Trigger Conditions

**當你看到這些症狀時使用此 Skill**：

- Bot 回覆與問題無關
- 用戶說「你回答錯了」或「這不是我問的」
- Worker 日誌：`index.filter is not a function`
- Worker 日誌：`讀取對話歷史失敗`
- Claude API 呼叫沒有 `messages` 陣列，只有單條訊息

**技術環境**：
- Cloudflare Worker 處理 Telegram webhook
- Cloudflare KV 儲存對話歷史
- Claude API 進行分析
- JavaScript/Node.js

## Solution

### Step 1: 檢查是否讀取對話歷史

```javascript
// ❌ 錯誤：只處理當前訊息
async function handleMessage(message, env) {
  const text = message.text;
  const response = await analyzeWithClaude(text, env);  // 沒有歷史！
  await sendMessage(chatId, response, env);
}

// ✅ 正確：讀取並傳遞歷史
async function handleMessage(message, env) {
  const text = message.text;
  const chatId = message.chat.id;

  // 讀取對話歷史
  const history = await getConversationHistory(chatId, env, 50);
  console.log(`讀取到 ${history.length} 條歷史訊息`);

  // 傳遞給 Claude
  const response = await analyzeWithClaude(text, env, history);
  await sendMessage(chatId, response, env);
}
```

### Step 2: 實施對話歷史管理

```javascript
/**
 * 從 KV 讀取對話歷史
 */
async function getConversationHistory(chatId, env, limit = 50) {
  try {
    // 讀取索引
    const indexData = await env.LEARNING_NOTES.get('_index');
    if (!indexData) {
      return [];
    }

    const index = JSON.parse(indexData);
    const allMessages = index.messages || [];  // 注意：index.messages，不是直接 index

    // 過濾該聊天室的訊息
    const chatMessages = allMessages
      .filter(item => item.chat_id === chatId)
      .sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp))
      .slice(0, limit);

    // 讀取完整內容
    const messages = [];
    for (const item of chatMessages.reverse()) {
      const recordData = await env.LEARNING_NOTES.get(item.id);
      if (recordData) {
        const record = JSON.parse(recordData);

        // 用戶訊息
        messages.push({
          role: 'user',
          content: record.content.original || ''
        });

        // AI 回覆
        if (record.claude_analysis) {
          messages.push({
            role: 'assistant',
            content: record.claude_analysis
          });
        }
      }
    }

    return messages;
  } catch (error) {
    console.error('讀取對話歷史失敗:', error);
    return [];
  }
}
```

### Step 3: 修復 KV 索引格式

**問題**：索引直接是陣列，沒有 `.messages` 屬性

```javascript
// ❌ 錯誤的索引格式
{
  "messages": [...]  // 直接在根層級
}

// 或更糟：直接是陣列
[
  { id: "...", timestamp: "..." },
  ...
]
```

**解決**：統一索引格式

```javascript
async function updateIndex(messageId, timestamp, chatId, env) {
  const indexData = await env.LEARNING_NOTES.get('_index');
  const index = indexData ? JSON.parse(indexData) : { messages: [] };

  // 確保 index.messages 存在
  if (!index.messages) {
    index.messages = [];
  }

  // 加入新訊息（包含 chat_id）
  index.messages.unshift({
    id: messageId,
    timestamp: timestamp,
    chat_id: chatId  // 重要：用於過濾
  });

  // 限制長度
  if (index.messages.length > 100) {
    index.messages = index.messages.slice(0, 100);
  }

  await env.LEARNING_NOTES.put('_index', JSON.stringify(index));
}
```

### Step 4: 整合到 Claude API

```javascript
async function analyzeWithClaude(text, env, conversationHistory = []) {
  // 建立訊息陣列
  const messages = [
    ...conversationHistory,  // 歷史對話
    {
      role: 'user',
      content: text  // 當前訊息
    }
  ];

  // 限制長度（避免超過 token 限制）
  const maxMessages = 50;
  if (messages.length > maxMessages) {
    messages.splice(0, messages.length - maxMessages);
  }

  console.log(`發送 ${messages.length} 條訊息到 Claude API`);

  const response = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': env.CLAUDE_API_KEY,
      'anthropic-version': '2023-06-01'
    },
    body: JSON.stringify({
      model: 'claude-sonnet-4-5-20250929',
      max_tokens: 2000,
      messages: messages,  // 完整對話歷史
      system: '你是一個友善的學習助手...'
    })
  });

  const data = await response.json();
  return data.content[0].text;
}
```

## Verification

### 1. 檢查日誌

部署後查看 Worker 日誌：

```bash
wrangler tail
```

**應該看到**：
```
✅ 讀取到 10 條歷史訊息
✅ 發送 11 條訊息到 Claude API  # 10 條歷史 + 1 條新的
```

**不應該看到**：
```
❌ TypeError: index.filter is not a function
❌ 讀取對話歷史失敗
```

### 2. 測試對話連續性

```
測試 1：基本記憶
你：我叫 John
Bot：你好 John！
你：我叫什麼名字？
Bot：你叫 John  ✅ 記得！

測試 2：連結分析 + 追問
你：https://x.com/username/status/123
Bot：[分析內容]
你：我們可以學到什麼？
Bot：[基於之前分析回答]  ✅ 記得上下文！
```

### 3. 檢查 KV 索引格式

```bash
wrangler kv key get "_index" --namespace-id="YOUR_ID" --remote | jq .
```

**正確格式**：
```json
{
  "messages": [
    {
      "id": "1770007374304_49",
      "timestamp": "2026-02-02T04:39:34.304Z",
      "chat_id": 1175849449
    },
    ...
  ]
}
```

## Example

### 完整實施範例

```javascript
// worker.js

/**
 * 處理 Telegram 訊息
 */
async function handleMessage(message, env) {
  const chatId = message.chat.id;
  const text = message.text || '';

  await sendTypingAction(chatId, env);

  try {
    // 讀取對話歷史
    const conversationHistory = await getConversationHistory(chatId, env, 50);
    console.log(`讀取到 ${conversationHistory.length} 條歷史訊息`);

    // 分析（含歷史）
    const response = await analyzeWithClaude(text, env, conversationHistory);

    // 儲存到 KV
    await saveToKV(message, response, 'text', env);

    // 回覆
    await sendMessage(chatId, response, env);

  } catch (error) {
    console.error('處理訊息失敗:', error);
    await sendMessage(chatId, `錯誤：${error.message}`, env);
  }
}

/**
 * 儲存到 KV（更新索引）
 */
async function saveToKV(message, claudeResponse, messageType, env) {
  const timestamp = new Date().toISOString();
  const messageId = `${Date.now()}_${message.message_id}`;

  // 儲存訊息
  const record = {
    id: messageId,
    timestamp: timestamp,
    type: messageType,
    content: {
      original: message.text || ''
    },
    claude_analysis: claudeResponse,
    metadata: {
      chat_id: message.chat.id,
      date: message.date
    }
  };

  await env.LEARNING_NOTES.put(messageId, JSON.stringify(record));

  // 更新索引（重要：包含 chat_id）
  await updateIndex(messageId, timestamp, message.chat.id, env);
}
```

## Notes

### 常見錯誤

1. **忘記過濾 chat_id**
   - 多個聊天室會互相干擾
   - 必須 `.filter(item => item.chat_id === chatId)`

2. **索引格式不一致**
   - 舊代碼可能直接用陣列
   - 新代碼要用 `{ messages: [...] }`
   - 讀取時檢查：`index.messages || []`

3. **超過 token 限制**
   - 50 條訊息已經很長
   - 需要智能壓縮（見 Phase 3）

4. **忘記更新索引**
   - 每次儲存訊息必須更新 `_index`
   - 否則無法讀取歷史

### 效能考量

- **KV 讀取成本**：免費額度 100,000 次/天（足夠）
- **Worker CPU 時間**：讀取 50 條訊息 < 100ms
- **Claude API token**：50 條 ≈ 2000-5000 tokens

### 擴展方案

當歷史太長時，可實施：

1. **本機 API**（見 `cloudflare-worker-performance-debugging` Skill）
2. **智能壓縮**：舊訊息壓縮為摘要
3. **分層儲存**：熱數據（KV）+ 冷數據（R2）

## See Also

- `chatbot-promise-execution-gap` - Bot 說「我發給你看」但沒發的問題（不同症狀，同領域）
- `telegram-bot-conversation-history-debugging`（已整合至本指南）- 監控對話品質，偵測這類問題

## References

- [Cloudflare Workers KV](https://developers.cloudflare.com/kv/)
- [Claude API Messages](https://docs.anthropic.com/en/api/messages)
- [Telegram Bot API](https://core.telegram.org/bots/api)

## Merged Skills (archived)

The following skills have been merged into this guide:
- **grammy-supabase-session-storage** — grammY Bot Supabase Session Storage Adapter 實作，解決 Serverless 環境 session 丟失問題
- **grammy-vercel-serverless-init** — grammY Bot "Bot not initialized!" 錯誤修復，Vercel/Lambda 需要 await bot.init()
- **telegram-conversation-monitor** — 對話品質監控（Supabase SQL 查詢 + 自動檢測「說但沒做」問題）
