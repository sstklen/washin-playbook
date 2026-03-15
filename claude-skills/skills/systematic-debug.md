---
name: systematic-debug
description: |
  系統化除錯工作流，針對開發者的使用習慣優化。
  解決三個問題：(1) 多 Bug Session 常未完成，(2) 環境限制沒提早告知，(3) 高 trial-and-error 比例。
  觸發時機：用戶報告 bug、除錯需求、或系統異常時自動啟用。
argument-hint: [bug描述]
version: 1.0.0
date: 2026-02-05
---

# 🔧 Systematic Debug（系統化除錯）

> 基於實際的 /insights 報告優化，解決三大痛點

---

## 🚨 啟動檢查清單（每次除錯必做）

### Step 1: Bug 分流（避免多 Bug 未完成）

```
⚠️ 偵測到多個問題？
│
├─ 是 → 立即拆分！每個 bug 獨立處理
│       → 用 TaskCreate 建立任務清單
│       → 按優先級排序：P0 阻斷性 > P1 功能性 > P2 體驗性
│
└─ 否 → 繼續 Step 2
```

**強制規則：**
- ❌ 禁止在一個 session 處理超過 2 個獨立 bug
- ✅ 每修完一個 bug，必須驗證後才進下一個
- ✅ 驗證 = 測試用戶實際看到的輸出，不只是「代碼能跑」

---

### Step 2: 環境聲明（避免 local ≠ production）

**開始除錯前，必須確認：**

```markdown
## 🌍 環境資訊（必填！）

| 項目 | 值 |
|------|---|
| 部署平台 | [ ] Local / [ ] Vercel / [ ] Railway / [ ] Lambda / [ ] 其他: ___ |
| Runtime | [ ] Node.js / [ ] Python / [ ] Bun |
| 記憶體限制 | ___MB（serverless 必填！）|
| Timeout | ___秒 |
| 特殊限制 | （如：冷啟動、無 filesystem、只讀等）|
```

**常見環境陷阱：**

| 平台 | 常見限制 | 解法 |
|------|---------|------|
| Vercel | 10s timeout (免費)、50MB 記憶體 | 用 Edge Function 或 streaming |
| Lambda | 15min timeout、512MB 預設 | 調整設定或拆分任務 |
| Railway | 8GB 最大、無 cold start | 注意 build 時間 |
| Cloudflare Worker | 128MB、10ms CPU | 用 Durable Objects |

---

### Step 3: 結構化診斷（減少 trial-and-error）

**不要亂試！按照這個流程：**

```
1️⃣ 重現 → 確認能穩定重現問題
   └─ 無法重現？→ 先收集更多資訊，不要猜

2️⃣ 定位 → 找到出問題的具體位置
   └─ 用 Grep 搜關鍵字，不要用 Bash grep
   └─ 用 Read 看相關檔案，不要用 cat

3️⃣ 根因 → 理解「為什麼」出問題
   └─ 說出假設：「我認為是因為 X 導致 Y」
   └─ 驗證假設：找證據支持或否定

4️⃣ 修復 → 針對根因修改
   └─ 最小改動原則：只改必要的部分
   └─ 說明修改理由

5️⃣ 驗證 → 確認問題真的解決
   └─ 測試用戶實際看到的輸出！
   └─ Bot/API：印出實際 response
   └─ 前端：截圖或描述畫面
```

---

## 📋 Debug 完成檢查清單

每次說「修好了」之前，必須確認：

- [ ] 我重現了原始問題
- [ ] 我找到了根本原因（不只是症狀）
- [ ] 我的修改是針對根因，不是繞過問題
- [ ] 我測試了**用戶實際看到的輸出**，不只是代碼能跑
- [ ] 如果是 Bot/API，我印出了實際 response 格式
- [ ] 如果有環境限制，我確認修復在目標環境也能運作

---

## 🎯 常見模式速查

### Bot 輸出錯誤（如 JSON 顯示給用戶）

```python
# ❌ 錯誤：直接 send 物件
await bot.send_message(chat_id, data)

# ✅ 正確：格式化後再 send
message = format_for_user(data)
print(f"DEBUG: 實際輸出 = {repr(message)}")  # 驗證格式
await bot.send_message(chat_id, message)
```

### Serverless 記憶體爆炸

```python
# ❌ 錯誤：一次載入全部
all_data = load_everything()  # 可能 500MB

# ✅ 正確：streaming 或分批
async for chunk in stream_data():
    process(chunk)
```

### Local 能跑 Production 失敗

```
檢查清單：
1. 環境變數是否都設了？
2. 檔案路徑是否用相對路徑？（serverless 無 filesystem）
3. 是否有硬編碼的 localhost？
4. 依賴是否都在 requirements/package.json？
5. timeout 是否足夠？
```

---

## 🔄 整合 Multi-Agent（複雜問題）

當問題很複雜時，派出多個 Agent 並行調查：

```
用戶: 「這個 bug 很複雜，我搞不清楚」

Claude 回應:
「讓我派 3 個 Agent 同時調查：
 - Agent 1: 搜尋 codebase 找相關代碼和最近改動
 - Agent 2: 分析錯誤路徑，加 logging 追蹤
 - Agent 3: 寫最小重現測試

 我會整合他們的發現，然後提出修復方案。」
```

---

*基於 2026-02-05 的 /insights 報告優化*
