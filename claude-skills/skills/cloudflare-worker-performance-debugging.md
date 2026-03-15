---
name: cloudflare-worker-performance-debugging
description: |
  Cloudflare Workers 性能診斷、API 整合與架構優化。
  使用時機：
  (1) Worker 回應慢（10+ 秒），simple requests 快，
  (2) Console logs 延遲 30s 才出現，用戶報告「不回應」，
  (3) 需要呼叫 Apify Actor（Twitter/Instagram scraping），Actor ID 404 錯誤，
  (4) 需要本機 API + KV fallback 混合架構（無限對話歷史），
  (5) 需要系統化優化工作流（診斷→設計→實施→驗證→測試→審查）。
  涵蓋性能診斷（timing logs、KV 瓶頸）、Apify 整合（run-sync-get-dataset-items、conversation_id）、
  混合架構（Cloudflare Tunnel + FastAPI + 智能路由）、6 階段優化流程（並行 Opus agents）。
author: Claude Code + Washin Village
version: 2.0.0
date: 2026-02-10
---

# Cloudflare Worker 性能診斷與優化

## Problem

Cloudflare Worker 處理業務邏輯非常慢（10-30 秒），但簡單的 ping 請求立即回應。

**症狀**：
- Worker 處理實際請求需要 20+ 秒
- 簡單的 `{"test": "ping"}` 請求立即返回 OK
- Console.log 輸出延遲（30 秒後才出現在 `wrangler tail` 中）
- 用戶報告「發了訊息沒反應」或「不理我了」
- CPU 時間沒超過限制（免費 10ms / 付費 50ms）

**與其他問題的區別**：
- **不是** Worker timeout（會返回 524 錯誤）
- **不是** CPU 時間超限（會被終止）
- **是** 業務邏輯中某個環節極慢

## Context / Trigger Conditions

**使用此 Skill 的場景**：

### 症狀檢查清單
- [ ] 簡單請求（無業務邏輯）< 1 秒
- [ ] 實際請求（含業務邏輯）> 10 秒
- [ ] Console.log 沒有即時輸出
- [ ] 請求最終會成功（返回 200 OK），只是很慢
- [ ] 沒有明顯的外部 API timeout

### 技術環境
- Cloudflare Workers（邊緣運算）
- Cloudflare KV（鍵值儲存）
- 外部 API 調用（如 Claude API、OpenAI、Telegram）
- 複雜的業務邏輯（讀取歷史、處理數據）

### 實際案例
```
用戶反饋：
"我發了一個訊息給 Bot，沒有任何反應"
"又不理我了"
"發了 123，沒有任何反應"

測試結果：
- curl 簡單 JSON：< 1 秒 ✅
- curl Telegram message 格式：27 秒 ❌
```

## Solution

### Phase 1: 添加詳細計時日誌

**目標**：找出具體哪個環節慢

```javascript
// 在主要處理函數中添加計時
async function handleMessage(message, env) {
  console.log('⏱️ [START] handleMessage');
  const t0 = Date.now();

  // 每個環節後記錄時間
  await someOperation();
  console.log(`⏱️ [${Date.now() - t0}ms] someOperation 完成`);

  await anotherOperation();
  console.log(`⏱️ [${Date.now() - t0}ms] anotherOperation 完成`);

  // ... 以此類推
}
```

**部署並測試**：
```bash
wrangler deploy

# 啟動即時日誌
wrangler tail --format pretty &

# 發送測試請求
curl -X POST "https://your-worker.workers.dev/" \
  -H "Content-Type: application/json" \
  -d @test-payload.json

# 等待 30 秒後檢查日誌
# 查看每個環節的耗時
```

### Phase 2: 分析瓶頸

**常見瓶頸模式**：

#### 模式 1：KV 讀取慢（讀取多個 keys）
```
⏱️ [882ms] sendTypingAction 完成
⏱️ [9903ms] 讀取到 66 條歷史訊息  ← 瓶頸！（9 秒）
⏱️ [26346ms] Claude 分析完成
```

**根本原因**：
- 每條記錄需要單獨 `KV.get()` 調用
- 66 條記錄 = 66 次網絡請求
- 即使 KV p90 延遲只有 12ms，串行讀取也需要 66 × 12ms ≈ 800ms
- 實際可能更慢（冷讀取、跨區域）

**官方數據**（2025-2026）：
- **Hot reads**（緩存命中）：< 5ms（p99）
- **Cold reads**（首次讀取）：22ms → 12ms（p90，已優化）
- **Bulk operations**：單次調用算 1 個請求

**優化方案**：
```javascript
// ❌ 串行讀取（慢）
for (const item of items) {
  const data = await env.KV.get(item.id);  // 每次都是網絡請求
}

// ✅ 減少數量（快）
const recentItems = items.slice(0, 10);  // 只讀取最近 10 條
for (const item of recentItems) {
  const data = await env.KV.get(item.id);
}

// ✅ 批量操作（更快，如果支持）
// 注意：KV 沒有原生的 multi-get，但可以用 Promise.all
const promises = items.map(item => env.KV.get(item.id));
const results = await Promise.all(promises);  // 並行讀取
```

#### 模式 2：LLM API 慢（token 數太多）
```
⏱️ [926ms] 讀取到 20 條歷史訊息
⏱️ [926ms] 開始 Claude 分析...
⏱️ [3822ms] Claude 分析完成  ← 瓶頸！（2.9 秒）
```

**根本原因**：
- 50 條訊息 = 可能 5,000-10,000 tokens
- Claude API 處理時間與 token 數成正比
- 歷史太長 → token 太多 → 回應慢

**優化方案**：
```javascript
// ❌ 發送全部歷史（慢）
const messages = [
  ...conversationHistory,  // 50 條
  { role: 'user', content: newMessage }
];

// ✅ 限制歷史長度（快）
const maxMessages = 10;  // 只保留最近 10 條
const recentHistory = conversationHistory.slice(-maxMessages);
const messages = [
  ...recentHistory,
  { role: 'user', content: newMessage }
];

console.log(`發送 ${messages.length} 條訊息到 Claude API`);
```

#### 模式 3：外部 API timeout
```
⏱️ [882ms] sendTypingAction 完成
⏱️ [3882ms] 本機 API 連接失敗  ← 等待 3 秒 timeout
⏱️ [3900ms] 開始讀取 KV...
```

**根本原因**：
- 嘗試連接無法訪問的本機 API
- 等待完整的 timeout 時間（3 秒）

**優化方案**：
```javascript
// ✅ 更短的 timeout
const response = await fetch(url, {
  signal: AbortSignal.timeout(2000)  // 2 秒而非 3 秒
});

// ✅ 或直接停用
if (!env.LOCAL_API_URL || env.LOCAL_API_URL === '') {
  return null;  // 跳過本機 API
}
```

### Phase 3: 實施優化

**優先級排序**：
1. **最高優先級**：減少數據量（最有效）
   - KV 讀取：從 50 條降到 10 條
   - LLM 歷史：從 50 條降到 10 條
   - 效果：27 秒 → 6 秒

2. **中優先級**：並行化
   - 用 `Promise.all()` 並行讀取 KV
   - 效果：可能再減少 30-50%

3. **低優先級**：優化 KV cacheTtl
   - 增加 cacheTtl 從 60s 到 300s
   - 效果：hit rate 提升，但首次讀取仍慢

**實施範例**：
```javascript
// 修改前：處理 27 秒
async function getConversationHistory(chatId, env, limit = 50) {
  // 讀取 66 條記錄...
}

// 修改後：處理 6 秒
async function getConversationHistory(chatId, env, limit = 10) {
  // 只讀取 10 條記錄
}
```

### Phase 4: 驗證優化效果

```bash
# 部署新版本
wrangler deploy

# 計時測試
START=$(date +%s)
curl -s -X POST "https://your-worker.workers.dev/" \
  -H "Content-Type: application/json" \
  -d @test-payload.json
END=$(date +%s)
echo "耗時: $((END - START)) 秒"

# 檢查詳細日誌
wrangler tail --format pretty
```

**預期結果**：
```
優化前：
⏱️ [9903ms] 讀取到 66 條歷史訊息
⏱️ [26346ms] Claude 分析完成
總計：27 秒

優化後：
⏱️ [926ms] 讀取到 20 條歷史訊息
⏱️ [3822ms] Claude 分析完成
總計：6 秒

改善：4.5 倍 🎉
```

## Verification

### 1. 檢查計時日誌

```bash
wrangler tail --format pretty | grep "⏱️"
```

**應該看到**：
- 每個環節的耗時清晰可見
- 瓶頸環節一目了然（> 5 秒的操作）
- 總處理時間顯著下降

### 2. 實際用戶測試

- 從 Telegram 發送訊息
- 記錄從發送到收到回覆的時間
- 應該在 10 秒內完成

### 3. 壓力測試

```bash
# 連續發送 5 個請求
for i in {1..5}; do
  time curl -s -X POST "https://your-worker.workers.dev/" \
    -H "Content-Type: application/json" \
    -d @test-payload.json
  sleep 2
done
```

## Example

### 完整案例：Telegram Bot 處理慢

**初始症狀**：
```
用戶：發送「你好」
等待：27 秒
Bot：「你好！有什麼可以幫你的嗎？」
```

**診斷過程**：

1. **添加計時日誌**：
```javascript
async function handleMessage(message, env) {
  console.log('⏱️ [START] handleMessage');
  const t0 = Date.now();

  await sendTypingAction(chatId, env);
  console.log(`⏱️ [${Date.now() - t0}ms] sendTypingAction 完成`);

  const conversationHistory = await getConversationHistory(chatId, env, 50);
  console.log(`⏱️ [${Date.now() - t0}ms] 讀取到 ${conversationHistory.length} 條歷史訊息`);

  const response = await analyzeWithClaude(text, env, conversationHistory);
  console.log(`⏱️ [${Date.now() - t0}ms] Claude 分析完成`);
}
```

2. **發現瓶頸**（通過 `wrangler tail`）：
```
⏱️ [882ms] sendTypingAction 完成
⏱️ [9903ms] 讀取到 66 條歷史訊息  ← 9 秒！
⏱️ [9903ms] 開始 Claude 分析...
發送 50 條訊息到 Claude API
⏱️ [26346ms] Claude 分析完成  ← 又花 16.4 秒！
總計：27 秒
```

3. **分析根因**：
   - **KV 瓶頸**：66 條記錄串行讀取，每條約 136ms
   - **Claude API 瓶頸**：50 條訊息 ≈ 8,000 tokens，處理需要 16 秒

4. **實施優化**：
```javascript
// 修改：減少歷史記錄數量
async function getConversationHistory(chatId, env, limit = 10) {  // 從 50 降到 10
  // ...
}

async function handleMessage(message, env) {
  const conversationHistory = await getConversationHistory(chatId, env, 10);  // 從 50 降到 10
  // ...
}
```

5. **驗證結果**：
```
⏱️ [891ms] sendTypingAction 完成
⏱️ [926ms] 讀取到 20 條歷史訊息  ← 僅 35ms！
⏱️ [3822ms] Claude 分析完成  ← 2.9 秒
總計：6 秒

改善：27s → 6s（4.5 倍）
```

## Notes

### 重要考量

1. **歷史長度 vs 性能的權衡**
   - 10 條歷史：快（6 秒），但上下文有限
   - 50 條歷史：慢（27 秒），但上下文完整
   - 建議：根據使用場景調整（即時對話 vs 深度分析）

2. **KV 讀取性能（官方數據 2025-2026）**
   - Hot reads（緩存）：< 5ms（p99）
   - Cold reads（首次）：12ms（p90）
   - 串行讀取 N 條：N × 12ms（最壞情況）
   - 並行讀取：理論上接近單次延遲，但受 Worker 並發限制

3. **計時日誌的成本**
   - `console.log` 本身幾乎無成本（< 1ms）
   - 但會增加日誌輸出量
   - 生產環境可以移除詳細計時，只保留關鍵節點

4. **Wrangler Tail 延遲**
   - 日誌可能延遲 10-30 秒才出現
   - 這是正常的（日誌傳輸延遲）
   - 不代表 Worker 本身慢

### 常見錯誤

1. **過早優化**
   - ❌ 猜測哪裡慢，直接改代碼
   - ✅ 先添加計時日誌，找到真正的瓶頸

2. **忽略數據量**
   - ❌ 只優化代碼邏輯（如改用更快的 JSON parser）
   - ✅ 減少數據量（最有效的優化）

3. **並行化的陷阱**
   - ❌ 盲目使用 `Promise.all()`（可能超過併發限制）
   - ✅ 先減少數量，再考慮並行化

4. **忘記測試真實場景**
   - ❌ 只測試簡單的 ping 請求
   - ✅ 用真實的業務請求測試

### 何時使用本 Skill vs 其他 Skill

| Skill | 使用場景 |
|-------|---------|
| **本 Skill** | Worker 慢，需要診斷具體瓶頸 |
| 本機 API + KV fallback 混合架構（已整合至本指南，見上方章節） | 需要訪問本機數據或無限歷史 |
| `telegram-bot-conversation-history-debugging` | 對話歷史功能不正常（回答錯誤） |

### 擴展方案

當優化後仍然慢（> 10 秒）：

1. **實施智能壓縮**（已整合至本指南，見上方混合架構章節）
   - 舊訊息壓縮為摘要
   - 只保留最近 10 條完整對話

2. **使用 Durable Objects**
   - 在內存中緩存歷史
   - 避免每次都讀 KV

3. **改用 R2 + Workers**
   - 大數據存 R2（對象儲存）
   - Worker 只讀取索引

## References

- [Cloudflare Workers Tracing (Open Beta)](https://blog.cloudflare.com/workers-tracing-now-in-open-beta/) - 自動追蹤性能瓶頸
- [Workers Performance and Timers](https://developers.cloudflare.com/workers/runtime-apis/performance/) - 官方性能 API 文檔
- [We made Workers KV up to 3x faster](https://blog.cloudflare.com/faster-workers-kv/) - KV 性能優化（2025）
- [Cloudflare Rearchitects Workers KV (InfoQ)](https://www.infoq.com/news/2025/08/cloudflare-workers-kv/) - KV 架構升級，p99 從 200ms 降到 < 5ms
- [How KV works](https://developers.cloudflare.com/kv/concepts/how-kv-works/) - KV 工作原理和性能特性

## Merged Skills (archived)

The following skills have been merged into this guide:
- **apify-cloudflare-worker-integration** — 在 Worker 中呼叫 Apify Actor（Twitter/Instagram scraping），Actor ID 格式陷阱（波浪號 vs 斜線），conversation_id 搜尋抓取完整 Thread
- **cloudflare-worker-local-api-hybrid** — 混合架構：Worker + 本機 FastAPI + KV fallback，Cloudflare Tunnel 設定，智能路由（優先本機，降級 KV）
- **cloudflare-worker-optimization-case-study** — 完整優化工作流（6 階段：診斷→設計→實施→驗證→測試→審查），並行 Opus agents，27s→1.8s 實戰案例
