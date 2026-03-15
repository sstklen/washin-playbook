---
name: code-assistant-advanced-workflow
description: |
  Boris Cherny (Claude Code 創始人 + 團隊) 的完整使用技巧 + 進階工作流 + Prompting 策略。
  使用時機：(1) 想要提升 Claude Code 生產力，(2) 需要並行處理多個任務，
  (3) 想建立可重複的工作流程，(4) 團隊協作需要統一規範，(5) Bug 很複雜需要並行調查，
  (6) 有失敗測試要自主修復，(7) 要部署到 serverless 需要審查相容性，
  (8) 需要更高品質的代碼輸出，(9) 想要 AI 提供證明而非聲稱。
  涵蓋團隊 10 大技巧 + Boris 個人 13 個技巧 + 多 Agent 協調除錯 + 自主 Test-Driven 修復 +
  Serverless 架構審查 + 進階 Prompting（Reviewer mode、Proof requirements、設定標準）。
  核心哲學「Context + Attention」。驗證迴圈已獨立為 code-verification-loop skill。
author: Boris Cherny (Claude Code Team)
version: 2.2.0
date: 2026-02-10
---

# Claude Code 進階工作流程

> 來自 Claude Code 團隊 Boris Cherny 的實戰經驗

## 核心哲學

**Claude Code 不是聊天工具，而是工作系統**

```
傳統 AI 工具：一問一答
Claude Code：多線並行 + 持續學習 + 系統化積累
```

---

## 1. 並行工作流（最大生產力解鎖）

**問題：** 一次只能做一件事，等待時間被浪費。

**解法：** 同時運行 3-5 個 git worktree，每個運行獨立的 Claude 會話。把所有等待時間轉換成產出（修 Bug 時同時開發、等 CI 時做 Code Review、等部署時寫文檔）。

詳見 [references/parallel-workflow-setup.md](references/parallel-workflow-setup.md) — worktree 創建、shell alias 設定、使用模式、團隊實踐。

---

## 2. Plan Mode 優先

**原則：** 複雜任務一定先從 Plan Mode 開始。

> 你把心力花在規劃上，Claude 就比較容易一次到位

### 三種用法

**用法 1：單一 Claude 規劃**
```
/plan
「規劃 Telegram Bot 性能優化方案：
- 診斷當前瓶頸
- 列出優化選項
- 預估每個選項的效果
- 給出實施步驟
- 定義驗證標準」
```

**用法 2：雙 Claude 審查（推薦）**
```
# Claude A 寫計畫，Claude B 以 Staff Engineer 身分審查：
# 有沒有遺漏的邊界條件？更好的架構選擇？風險與取捨？驗證步驟？
```

**用法 3：驗證階段也用 Plan Mode** — 規劃測試策略、回歸範圍、副作用確認。

### 關鍵時機
- 任務開始前：制定計畫
- 任務卡住時：立即切回 Plan Mode 重新規劃
- 驗證階段：規劃測試策略

**深層洞察：** 與 AI 協作時，前期規劃的投入產出比遠高於後期修補。

---

## 3. 用心經營 CLAUDE.md

**核心概念：** 每次糾正 Claude 後，讓它更新 CLAUDE.md，確保不再重複錯誤。

**黃金句式：**
```
「更新你的 CLAUDE.md，這樣你就不會再犯同樣的錯誤。」
```

> Claude 非常擅長為自己編寫規則。你等於把「教它一次」變成「永久降低錯誤率」。

### 維護原則
1. **持續精簡** — 規則越精簡、可檢查、可執行越好
2. **可測量的改進** — 持續迭代，直到錯誤率明顯下降
3. **結構化組織** — CLAUDE.md 引用 notes/ 目錄，主檔保持乾淨

### 高級實踐
讓 Claude 維護 notes 目錄，每次 PR 後更新，CLAUDE.md 只保留指向。

---

## 4. 封裝 Skills 和 Commands

**自動化法則：** 一天做超過一次的事，就應該封裝成 skill 或 command。

### 實用 Skills 範例
- **/techdebt** — 每次工作階段結束執行，清理重複代碼、未使用變數、過時註解、臨時 workaround
- **/context-sync** — 整合過去 7 天的 Slack、Google Docs、Asana、GitHub 變更，生成單一上下文彙整
- **/analytics-agent** — 撰寫 dbt models、審查數據代碼、在 dev 環境測試變更

### 封裝方式
```bash
mkdir -p .claude/skills/techdebt
vim .claude/skills/techdebt/SKILL.md
git add .claude/skills/ && git commit -m "Add techdebt skill"
```

---

## 5. 自動化 Bug 修復

**核心原則：** 多數 bug 讓 Claude 自己修，你只要下達結果。

### 三種用法
1. **直接貼 Slack 討論** — 「這是 Slack 上的 bug 討論串：[貼上] 修好它。」
2. **CI 失敗直接修** — 「去修好那些失敗的 CI 測試。」
3. **分散式系統排查** — 「看這些 docker logs，找出問題並修復。」

### 關鍵技巧
- 講清楚成功條件（CI 全綠、測試通過、行為一致）
- 其餘細節交給 Claude 自行收斂
- 不要微觀管理每一個步驟

---

## 6. 進階 Prompting 技巧

### 技巧 1：讓 Claude 成為你的 Reviewer

```
「嚴格審查這些變更，在通過你的測試之前不准發 PR。」
「證明給我看這個是對的。比對 main 和 feature branch 的行為差異。」
```

### 技巧 2：推動更優解

```
「用現在掌握的所有資訊，砍掉重練，給我最優雅的方案。」
```

利用 Claude 在對話過程中積累的上下文理解。

### 技巧 3：減少歧義

```
❌ 「做一個登入功能」
✅ 「做一個登入功能，需求：
- 支援 Email + Password
- 錯誤 3 次鎖定 15 分鐘
- 記住登入狀態 30 天
- 驗證標準：正確密碼可登入、錯誤密碼顯示提示、鎖定期間拒絕、狀態持久化」
```

越具體輸出越好，模糊空間越少，產出越穩定。

---

## 7. 終端與環境設定

**推薦：** Ghostty 終端（同步渲染、24-bit 色彩、Unicode 支援）+ `/statusline` 顯示 context/branch/worktree。

**語音輸入：** 雙擊 fn 鍵，說話速度是打字的 3 倍，prompt 自然更詳細 = 更好的輸出。適合撰寫規格、描述重現步驟、列驗證清單。

詳見 [references/tools-environment-learning.md](references/tools-environment-learning.md)

---

## 8. Subagent 使用

### 三種用法
1. **投入更多算力** — 「分析這個複雜的資料結構並優化。use subagents」
2. **保持主 agent 上下文乾淨** — 派 subagent 掃描 repo、整理變更點、列回歸清單，主 agent 只需決策資訊
3. **路由安全檢查** — 透過 hook 把權限請求轉交給 Opus 4.5 掃描攻擊行為

### 深層意義
這是「agent 編排」思維：主 agent 協調決策，子 agent 執行收集資訊。

---

## 9. 數據分析整合

讓 Claude Code 透過 CLI 直接拉取和分析指標（BigQuery、PostgreSQL、MongoDB、Redis 等）。封裝成 skill 後，可一句話查詢過去 7 天的活躍度、錯誤率、響應時間並生成趨勢圖。Boris 本人已超過 6 個月沒寫過一行 SQL。

詳見 [references/tools-environment-learning.md](references/tools-environment-learning.md)

---

## 10. 學習輔助

四種方法：(1) `/config` 啟用 Explanatory 風格讓 Claude 解釋每次改動原因，(2) 生成視覺化 HTML 演示解釋不熟悉的代碼，(3) ASCII 圖表解釋工作流程，(4) 間隔重複學習法。把「改好了」變成「你知道為什麼要這樣改」的理解。

詳見 [references/tools-environment-learning.md](references/tools-environment-learning.md)

---

## 完整工作流程範例

**日常節奏摘要：**
- **開工：** `/context-sync` → `/plan` 今日目標 → 啟動多 worktree
- **執行中：** 卡住切 Plan Mode → 修正錯誤後更新 CLAUDE.md → 階段性測試 → 語音輸入寫規格
- **收尾：** `/techdebt` → 更新 notes → 「證明今天所有變更都正確」→ 審查通過才准發 PR

詳見 [references/daily-workflow-example.md](references/daily-workflow-example.md) — 完整時間表、bash 指令範例、常見問題 FAQ。

---

## 核心指標

### 團隊實踐成果

| 指標 | 改進 |
|------|------|
| 並行任務數 | 1 → 3-5 |
| 規劃投入時間 | +30% |
| 返工時間 | -60% |
| Bug 修復速度 | +3x |
| 代碼品質 | 可測量提升 |
| SQL 編寫時間 | -100%（6 個月未寫） |

---

## 參考資料

### 外部資源
- [Boris Cherny X Thread](https://x.com/bcherny/status/2017742741636321619)
- [Claude Code Workflows Documentation](https://github.com/anthropic/claude-code)
- [Parallel Workflows Guide](https://github.com/anthropic/claude-code/workflows)
- [Subagents Documentation](https://github.com/anthropic/claude-code/subagents)

### 詳細文檔（本 skill 附帶）
- [完整整合指南](references/complete-integration.md) - Boris 團隊 10 大技巧 + 個人 13 個技巧完整整合
- [實戰應用案例](references/boris-techniques-applied.md) - Telegram Bot 除錯案例，展示技巧實際應用
- [並行工作流設定](references/parallel-workflow-setup.md) - worktree 創建、alias、使用模式
- [終端/數據分析/學習](references/tools-environment-learning.md) - Ghostty、語音輸入、BigQuery、學習方法
- [日常節奏範例](references/daily-workflow-example.md) - 完整時間表 + FAQ

---

## See Also

- `ai-prompt-mastery` - 進階 prompting 技巧（Reviewer、證明、砍掉重練）
- `code-verification-loop` - 驗證迴圈（最重要技巧，2-3x 品質提升）
- `agentic-coding-complete` - Agentic Coding 方法論
- `skill-extractor` - 知識提取與 skill 創建

---

**作者註：**
這些技巧來自 Claude Code 團隊的實戰經驗。
不是理論，而是每天在用的工作方式。
適合你的做法需要實驗才知道。多嘗試，保留有效的，捨棄不適合的。

**核心精神：把 Claude Code 當成工作系統，而非聊天工具。**

---

## Merged Skills (archived)

The following skills have been merged into this guide:
- **advanced-workflows** — 多 Agent 協調除錯、自主 Test-Driven 修復迴圈、Serverless 架構審查
- **advanced-prompting-guide** — Reviewer mode、Proof requirements、完整重新設計策略、設定標準而非給指令
