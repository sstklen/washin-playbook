---
name: ai-to-ai-communication-protocol
description: |
  AI-to-AI 結構化通訊協議：與外部 AI 系統（如 Nebula）進行機器對機器溝通的完整方法論。
  涵蓋：訊息格式設計、能力探索策略、幻覺偵測、漸進式信任建立、bug 回報模式。
  使用時機：
  1. 需要與外部 AI 平台（Nebula、Make.com、n8n）進行自動化溝通
  2. 透過 Email 或 API 與 AI Agent 交換結構化資料
  3. 需要探索未知 AI 系統的能力邊界
  4. 對方 AI 有幻覺問題，需要驗證機制
  5. 建立長期 AI-to-AI 合作關係
argument-hint: "[nebula|general]"
version: 1.0.0
date: 2026-02-13
---

# AI-to-AI 結構化通訊協議

## 核心原則

### 原則 1：把 AI 當 API 用
```
X 寫給人聽的 Email（「您好，希望能合作...」）
O 給 input spec，定義 output format

每個 REQUEST 必須包含：
- REQUEST_ID（追蹤用）
- 明確的 Question
- Expected Output Format（JSON schema）
- 不確定填 null 的規則
```

### 原則 2：漸進式能力探索
```
第 1 輪：問基礎能力（你能做什麼？）
第 2 輪：問能力邊界（什麼不能做？填 null）
第 3 輪：問隱藏功能（有什麼我們沒問到的？）
第 4 輪：探索後門（系統內部有什麼可以幫忙的？）
```

### 原則 3：驗證而非信任
```
AI 的第一反應常有幻覺。
驗證方法：
- 要求實際執行（不只是口頭承諾）
- 觀察 run_count 和實際結果
- 邏輯交叉驗證（他的延遲計算對嗎？）
- 多次執行確認一致性
```

## 訊息格式模板

### 標準請求格式
```
SUBJECT: SYSTEM_NAME_REQUEST_vN

---
REQUEST_ID: REQ-YYYY-MMDD-NNN
FROM: your-system-name
TO: target-system-name
PROTOCOL: AI-to-AI structured communication
PRIORITY: LOW/MEDIUM/HIGH/CRITICAL
---

## STATUS_REPORT（如有上次結果）
| Task | Status | Issue |
|------|--------|-------|
| ... | ... | ... |

## REQUEST_N: 標題

### Problem Definition
（問題描述）

### Question
```json
{
  "questions": ["..."]
}
```

### Expected Output Format
```json
{
  "field": "type/description"
}
```

---
EXECUTION_ORDER
1. ...
2. ...

RULES
- 不確定填 null
- 不要猜測
---
END_OF_REQUEST
```

### BUG 回報格式
```json
{
  "bug_id": "BUG-NNN",
  "severity": "CRITICAL/HIGH/MEDIUM/LOW",
  "symptom": "what we observed",
  "root_cause": "why it happened",
  "diagnosis": "analysis"
}
```

### 能力探索格式
```
TYPE: CAPABILITY_EXPLORATION (not task request)

請做一次自我能力盤點：
1. 系統架構（平台、版本、限制）
2. 所有可用函數（名稱、分類、參數）
3. Agent 類型清單
4. 隱藏功能（我們沒問過的）
5. 什麼能幫助解決 [specific problem]
```

## 幻覺偵測清單

| 信號 | 風險 | 處理方式 |
|------|------|---------|
| 第一反應說「支援」 | 高 | 要求實際測試 + run_count 證明 |
| 給了 API endpoint URL | 高 | curl 測試驗證 |
| 說「延遲 < 5 秒」 | 中 | 要求實際計時數據 |
| 給了完整代碼範例 | 中 | 確認 API 端點真實存在 |
| 填了 null 說不確定 | 低 | 誠實信號，可信度高 |
| 主動報錯 | 低 | 最可信的回應 |

## 信任等級演進

```
Level 0: 不信任（剛開始）
  → 每個回答都要驗證
  → 要求 run_count、實際結果

Level 1: 基礎信任（幾輪對話後）
  → 他主動報錯過 → 誠實度確認
  → 能力邊界已探索完成
  → 簡單回答可信，複雜回答仍需驗證

Level 2: 合作信任（穩定運行後）
  → 自動化流程穩定
  → 已建立錯誤處理機制
  → 只驗證新功能，不驗證已知功能

Level 3: 戰略信任（長期合作）
  → 可以讓他自主決定執行策略
  → 給目標不給步驟
  → 但仍監控結果
```

## 實戰經驗（Nebula 案例）

### 幻覺事件紀錄
1. **Direct API 幻覺**：Nebula AI 聲稱有 OpenAI-compatible REST API (`api.nebula.gg/api/chat/completions`)，提供了完整代碼範例和 API key 格式（`nbk_xxx`）。全部是虛構的。
2. **HTTP Webhook 幻覺**：先說 supported: true（延遲 < 5s），Code Agent 查完發現不支援。
3. **延遲計算錯誤**：說 Lightsail polling 30s → 有效延遲 45s，但忽略了 Nebula 端 hourly cron 的 30 分鐘瓶頸。

### 誠實行為紀錄
1. Python sandbox 限制 → 直接報 run_count=0
2. user@example.me 是 send-only → 自主發現並報告
3. Gmail trigger↔recipe mailbox mismatch → 自主診斷
4. 能力盤點 → null 填得很誠實

### 學到的教訓
- **永遠驗證 AI 的第一反應**，特別是「我能做到」的回答
- **要求 null 而非猜測** — 這是最有效的反幻覺手段
- **觀察自我修正** — 能自我修正的 AI 比從不犯錯的更可靠
- **Bug 回報要結構化** — AI 對結構化 bug 報告的修復品質遠高於自然語言描述
- **不要刪除 working 的東西再測新的** — 先測新的，確認能用再切換
