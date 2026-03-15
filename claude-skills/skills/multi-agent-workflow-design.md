---
name: multi-agent-workflow-design
description: |
  識別適合 Multi-Agent 工作流的任務，設計 Agent 配置，並提供驗證與成本優化模式。
  觸發條件：(1) 批量處理 100+ 檔案，(2) 可並行的獨立作業，(3) 有明確步驟的流程，
  (4) 耗時長的任務，(5) 需要外部 API，(6) 派發多個並行 Agent 需要驗證交付物，
  (7) 大量圖片/媒體處理成本太高需降低，(8) 從零建立包含多服務的 Monorepo 專案。
  包含：架構設計、並行驗證三階段法、低成本外部 API 模式、完整專案開發流程。
version: 1.1.0
date: 2026-02-10
author: Washin Village + Claude
---

# Multi-Agent 工作流設計指南

## 適用場景識別

### 主動觸發條件

當用戶任務符合以下任一特徵時，**主動提醒**：

| 特徵 | 識別信號 | 建議方案 |
|------|---------|---------|
| **批量處理** | 100+ 檔案、「全部」、「所有」 | 並行 Agent |
| **可並行** | 多資料夾、獨立作業、互不依賴 | 背景 Agent |
| **明確步驟** | 分析→處理→輸出的流程 | 鏈式 Agent |
| **重複性高** | 每個項目做相同操作 | 模板化 Agent |
| **耗時長** | 預估 > 10 分鐘 | 背景執行 |
| **外部 API** | 圖片/影片分析、翻譯 | 便宜 API 代理 |

### 提醒模板

```
💡 **這個任務很適合用 Multi-Agent 工作流！**

識別到：
- [列出符合的特徵]

建議方案：
- 並行處理可加速 3-5x
- 用 Gemini/Haiku 可降低成本 90%
- 可以設計自動化流水線

要我幫你設計 Agent 配置嗎？
```

---

## 三種協作模式

### 1. 並行分頭（Parallel）

```
         ┌─── Agent A（任務 1）
         │
主對話 ──┼─── Agent B（任務 2）──→ 結果合併
         │
         └─── Agent C（任務 3）
```

**適用**：獨立任務、資料夾分割、批量處理

**指令範例**：
```
同時用三個 subagent 分析 A、B、C 三個資料夾
```

### 2. 接力串連（Chain）

```
主對話 → Agent A → 結果 → Agent B → 結果 → Agent C
```

**適用**：有依賴的步驟、流水線處理

**指令範例**：
```
先用 analyzer 分析，再用 organizer 整理，最後用 reporter 生成報告
```

### 3. 合併綜合（Synthesize）

```
Agent A ──┐
Agent B ──┼──→ 主對話綜合 ──→ 最終輸出
Agent C ──┘
```

**適用**：多維度研究、競品分析

**指令範例**：
```
三個 agent 分別研究不同方面，回來後綜合成報告
```

---

## Agent 配置模板

### 基礎配置

```markdown
---
name: task-agent
description: 描述何時使用這個 agent
tools: Read, Grep, Glob, Bash
model: haiku  # 便宜快速
---

你是專門處理 [任務類型] 的助手。

執行時：
1. [步驟 1]
2. [步驟 2]
3. [步驟 3]

輸出格式：
[定義輸出結構]
```

### 影片分析 Agent（範例）

```markdown
---
name: video-analyzer
description: 分析影片內容，識別動物種類和行為。批量影片處理時使用。
tools: Bash, Read, Write
model: haiku
---

你是影片分析專家。

執行時：
1. 使用 Gemini Vision API 分析影片
2. 識別動物種類（貓/狗/羊）
3. 識別品種特徵
4. 輸出結構化 JSON

輸出格式：
{
  "animals_detected": [...],
  "suggested_category": "...",
  "confidence": 0.95
}
```

### 檔案整理 Agent（範例）

```markdown
---
name: file-organizer
description: 根據分析結果整理檔案到對應資料夾。
tools: Bash, Read
model: haiku
---

你是檔案整理專家。

執行時：
1. 讀取分析結果 JSON
2. 根據分類建立目標資料夾
3. 搬移檔案到對應位置
4. 輸出整理報告

注意：
- 不要刪除原檔案
- 保持檔名不變
- 記錄所有操作
```

---

## 成本優化策略

### 外部 API 代理模式

**問題**：Claude tokens 昂貴（$3-15/M tokens）

**解法**：Claude 只負責調度，實際工作由便宜 API 執行

| 任務類型 | 便宜 API | 成本比較 |
|---------|---------|---------|
| 影片分析 | Gemini Vision | 降低 90%+ |
| 圖片標籤 | Gemini Flash | 降低 95%+ |
| 簡單分類 | Haiku | 降低 80% |
| 文本處理 | Batch API | 降低 50% |

### 模型選擇指南

| 任務複雜度 | 推薦模型 | 說明 |
|-----------|---------|------|
| 簡單分類 | haiku | 最快最便宜 |
| 中等分析 | sonnet | 平衡 |
| 複雜推理 | opus/inherit | 需要深度思考 |

---

## 限制與注意事項

### 技術限制

| 可以 | 不可以 |
|------|--------|
| 主對話生成多個 subagents | Subagent 生成另一個 subagent |
| 主對話串連 subagents | Subagent 自己呼叫下一個 |
| 背景並行執行 | MCP 工具在背景 subagent |
| Resume 已完成的 subagent | 跨 session resume |

### 最佳實踐

1. **設計專注的 agent** — 每個只做一件事
2. **寫詳細的 description** — Claude 用它決定何時委派
3. **限制工具存取** — 只給必要權限
4. **使用便宜模型** — 簡單任務用 haiku
5. **提交到版本控制** — 與團隊共享 agent 配置

---

## 實戰案例

### 案例：294 個寵物影片分類

**問題**：手動分類太慢，之前的模型分錯了

**解法**：
1. Agent 1（Gemini Vision）：批量分析影片
2. 主對話：綜合結果，建立確認資料夾
3. Agent 2：根據用戶確認搬移檔案

**結果**：
- 時間：1 小時（vs 手動 8+ 小時）
- 成本：Gemini API ≈ $0.50（vs Claude ≈ $15+）
- 準確率：61% single_tabby 正確識別

**關鍵學習**：
- 用 symlink 建立確認資料夾，不動原檔
- 檔名不可信時，只靠視覺辨識
- 分批處理避免 API rate limit

---

## 快速檢查清單

在開始任務前，問自己：

- [ ] 檔案數量 > 50？→ 考慮批量處理
- [ ] 可以分割成獨立子任務？→ 考慮並行
- [ ] 有明確的步驟順序？→ 考慮鏈式
- [ ] 需要圖片/影片分析？→ 用 Gemini
- [ ] 預估時間 > 10 分鐘？→ 背景執行

如果有 2+ 項符合，**建議使用 Multi-Agent 工作流**。

---

## References

- [Create custom subagents - Claude Code Docs](https://code.claude.com/docs/en/sub-agents)
- [Subagents in the SDK](https://docs.claude.com/en/docs/agent-sdk/subagents)
- [Building agents with the Claude Agent SDK](https://claude.com/blog/building-agents-with-the-claude-agent-sdk)

---

## Merged Skills (archived)

The following skills have been merged into this guide:

- **multi-agent-parallel-verification-pattern** — 並行 Agent 工作成果驗證流程（三階段驗證法：報告審查、檔案位置確認、功能驗證）
- **low-cost-multi-agent-external-api-pattern** — 低成本多代理外部 API 架構（Claude 調度 + 便宜 API 執行，成本降低 90%+）
- **project-level-multi-agent-development** — 專案級 Multi-Agent 開發模式（從商業需求到完整 Monorepo 的五階段流程）
