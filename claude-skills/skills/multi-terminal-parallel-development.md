---
name: multi-terminal-parallel-development
description: |
  多終端 Claude Code 並行開發的最佳實踐。使用時機：
  1. 用戶要求「開多個終端機同時做事」或「multi-agent orchestration」
  2. 需要一晚上完成大量開發工作（10+ commits）
  3. 前端/後端/安全需要同時進行
  4. 用戶要無人值守讓 AI 自己做完
  涵蓋：水平分工（不同模組）+ 垂直分工（Builder+Reviewer 流水線）。
  來源：production-api 專案實戰（一晚 12+ commits，3 終端並行）。
  已合併原 dual-claude-pipeline skill 內容。
version: 1.0.0
date: 2026-02-12
author: Washin Village + Claude
---

# 多終端 Claude Code 並行開發指南

> 實戰驗證：3 終端同時工作，一晚完成 12+ commits，加速 4-6 倍

---

## 總覽：三終端架構

```
┌───────────────────────────────────────────┐
│          T3 — orchestrator                │
│  分派任務、審查品質、安全掃描、處理衝突      │
│  模式：互動模式（手動操控）                  │
├───────────────────┬───────────────────────┤
│  T1 — 後端兵      │  T2 — 前端兵           │
│  API、伺服器邏輯   │  UI、頁面、樣式        │
│  無人值守          │  無人值守              │
└───────────────────┴───────────────────────┘
```

**啟動：**
```bash
# T1/T2（無人值守）
cd /path/to/project && claude --dangerously-skip-permissions
# T3（orchestrator）
cd /path/to/project && claude
```

---

## 一、任務分配原則

### 核心鐵律：不改同一個檔案

```
✅ T1 → src/api/stripe.ts    T2 → src/app/dashboard/page.tsx
❌ T1 → src/http-server.ts   T2 → src/http-server.ts  → 必衝突！
```

| 分配方式 | 衝突風險 | 適用場景 |
|---------|---------|---------|
| 前端/後端分開 | 低 | Web 應用 |
| 模組分開 | 最低 | 微服務 |
| 新檔案為主 | 零 | 任何場景 |
| 同檔不同時段 | 中 | 不得已時 |

### 高衝突檔案（只給一個終端）

```
- 主路由（http-server.ts, app.ts, index.ts）
- 設定檔（package.json, tsconfig.json, .env）
- 共用型別（types.ts, interfaces.ts）
- 全域樣式（globals.css, tailwind.config.ts）
- DB schema（schema.prisma, migrations/）
```

### 波次拆分範例

```
第一波：T1 → Smart Gateway API（新檔案）  T2 → Landing Page（獨立頁面）
第二波：T1 → Stripe 付款（API routes）    T2 → Dashboard（獨立頁面）
第三波：T1 → E2E 測試                    T2 → 安全修復
收尾：  T3 → 部署配置 + 最終審查
```

---

## 二、指令格式（複製貼上就能跑）

### 指令模板

```markdown
## 任務：[清楚的任務名稱]

### 目標
[一句話說明]

### 規則
- 繁體中文註解
- 不要安裝新的外部框架
- 不要修改 [禁止碰的檔案]
- commit message 格式：feat/fix/chore: 描述

### 要建立/修改的檔案
1. `src/api/stripe.ts` — Stripe 付款 API
2. `src/lib/pricing.ts` — 價格計算邏輯

### 具體要求
[詳細需求，含代碼範例或介面定義]

### 驗證步驟
1. `bun run build` — 編譯通過
2. `bun run test` — 測試通過
3. `git add -A && git commit -m "feat: 描述"`
```

### 好指令 vs 壞指令

```
❌「幫我做 Stripe 付款功能」

✅「在 src/api/stripe.ts 建立 Stripe Checkout Session API。
  - 端點：POST /api/checkout
  - 接受 { priceId: string, quantity: number }
  - 回傳 { sessionUrl: string }
  - 環境變數用 STRIPE_SECRET_KEY
  - 不要碰 http-server.ts
  - 完成後跑 bun run build
  - commit: feat: add stripe checkout API」
```

### 常用規則速查（按需附上）

```
通用：禁 any、API Key 用環境變數、build 通過才 commit
前端：Tailwind CSS、手機優先、next/image + next/link
後端：外部呼叫加 try-catch、統一回傳格式 { success, data?, error? }
```

---

## 三、orchestrator（T3）的職責

### 巡邏指令（每 5-10 分鐘）

```bash
git log --oneline -10    # 查進度
git status               # 查未 commit 改動
git diff --stat          # 查改了什麼
```

### 判斷進度

```
git status 有未 commit 改動？
├─ 1-2 檔案 → 可能做完忘 commit → 提醒
├─ 5+ 檔案  → 還在做 → 等一下
└─ build 產物 → build 可能失敗 → 去看 error
```

### 每波結束審查

1. `git log` — 確認 commits 進去了
2. `bun run build` — 整體編譯通過
3. 快速 code review — 掃關鍵檔案
4. 安全掃描 — 硬編碼密碼、敏感 log、未過濾輸入
5. `git status` 乾淨
6. 準備下一波指令

### 安全掃描（T1/T2 工作時同步跑）

```
用 background agent 掃描：
1. .ts/.tsx 中硬編碼字串（password, secret, key, token）
2. eval() 或 innerHTML
3. SQL 字串拼接
4. .env 被 git 追蹤
發現問題列出，等 T1/T2 做完後統一修
```

---

## 四、衝突避免策略

### 預防

1. 開始前列出所有要改的檔案
2. 畫出每個終端碰哪些檔案
3. 有重疊就重新分配
4. 大檔案（300+ 行）只給一個終端

### 大檔案處理

```
解法 A：只讓一個終端碰（T1 改 http-server.ts、T2 改其他）
解法 B：先拆再改（orchestrator先拆成 routes/api.ts + routes/pages.ts）
```

### 新檔案策略（零衝突保證）

```
✅ T1 建 src/lib/sanitize.ts   T2 建 src/components/PricingCard.tsx
❌ T1 改 src/lib/utils.ts       T2 也改 src/lib/utils.ts
```

### 衝突處理

```
1. git diff --name-only --diff-filter=U   # 看衝突在哪
2. 保留最新版本或手動合併
3. 把衝突檔案加入「只給一個終端」清單
```

---

## 五、無人值守模式

### 啟動前確認

- [ ] 指令夠具體（檔案路徑、規則、驗證步驟）
- [ ] 不碰其他終端正在改的檔案
- [ ] 包含 build 驗證步驟
- [ ] 包含 commit 指令
- [ ] .env 存在且正確

### `--dangerously-skip-permissions` 安全守則

1. 只在開發環境用
2. 指令寫「不要刪除現有檔案」
3. 指令列出「只能修改這些檔案」
4. orchestrator定期巡邏 `git status` / `git log`

### 長任務指令範例

```markdown
## 任務：建立完整的 Dashboard 頁面

### 步驟
1. 建立 src/app/dashboard/page.tsx
2. 建立 src/components/dashboard/UsageChart.tsx
3. 建立 src/components/dashboard/BillingInfo.tsx
4. 每完成一個元件跑 `bun run build`
5. 全部完成：`git add -A && git commit -m "feat: add dashboard page"`

### 規則
- Tailwind CSS、繁體中文 UI、不碰 src/api/、不裝新套件
- Mock 數據用 const

### 完成後
build 通過 → commit → 印出「任務完成」→ 等待下一個指令
```

---

## 六、波次管理與用戶溝通

### 節奏

```
第一波（基礎建設）→ orchestrator審查 → 第二波（核心功能）→ orchestrator審查 → 第三波（收尾）→ 最終審查
```

### 時間表參考

```
21:00  規劃 + 拆分波次
21:15  第一波啟動
21:45  審查 → 第二波
22:30  審查 → 第三波
23:15  最終審查 + 部署
```

### 用戶溝通

```
「做完了嗎？」→ 報告完成了幾個 commit、做了什麼、品質沒問題
「再派工作！」→ 給出下一波的 T1/T2 指令
「我想睡了」 → 確保剩餘任務能無人值守、明天跑 git log 看成果
```

---

## 七、品質把關

### commit message 格式

```
<type>: <description>
type: feat / fix / chore / test / docs / style / refactor
```

### 每個任務最低驗證

1. `bun run build` 通過
2. 無 TypeScript 錯誤
3. 自行 commit

### 常見問題預防

| 問題 | 指令中寫 |
|------|---------|
| any 類型 | 「禁止 any」 |
| 忘記錯誤處理 | 「外部呼叫加 try-catch」 |
| 硬編碼 URL | 「URL 從環境變數讀」 |
| 忘記 commit | 指令最後給 commit 指令 |

---

## 八、進階技巧

### 四終端模式

T4 測試兵 — T1/T2 做完一波後同步寫測試（API 測試 + E2E 測試）

### git worktree（終極解法）

```bash
git worktree add ../project-backend feature/backend
git worktree add ../project-frontend feature/frontend
# 各自獨立目錄，零衝突，最後 merge
```

### 漸進式分配

一次一個任務，做完確認再派下一個。避免第一個失敗導致後續全歪。

### 緊急煞車

```
溫和：輸入新指令覆蓋
強硬：Ctrl+C → git checkout .
保險：git stash 保存後再決定
```

---

## 九、檢查清單

**開始前：**
- [ ] git 狀態乾淨
- [ ] 任務拆成 3-5 波、T1/T2 不碰同檔案
- [ ] 識別高衝突檔案
- [ ] 準備好詳細指令

**每波結束：**
- [ ] git log 確認 commits
- [ ] build 通過、git status 乾淨
- [ ] code review + 安全掃描

**全部結束：**
- [ ] 完整 build + test
- [ ] 安全掃描通過
- [ ] 部署配置正確
- [ ] .env.example 更新

---

## 十、實戰案例：production-api（2026-02-12）

| 波次 | T1（後端） | T2（前端） | T3（orchestrator） |
|------|-----------|-----------|-----------|
| 1 | Smart Gateway API | Landing Page | 分派 + 巡邏 |
| 2 | Stripe 付款 API | Dashboard | 安全掃描 |
| 3 | E2E 測試 | 安全修復 | 最終審查 |
| 4 | — | — | 部署配置 |

**教訓：**
1. http-server.ts 1200+ 行 — 多人改必衝突，下次先拆分
2. 新檔案策略有效 — sanitize.ts 等零衝突
3. 指令太模糊 → T2 用了不想要的框架
4. T1 曾 commit 編譯不過的代碼 → build 驗證必須
5. 最後一波確保能無人值守（用戶想睡覺）

**效率：** 3 終端 x 4 小時 = 12 人時，單人需 2-3 天，加速 4-6 倍

---

## 十一、垂直分工模式（Builder + Reviewer）

> 原 `dual-claude-pipeline` skill 精華，已合併至此

**與水平分工的差別：**
- 水平（上述章節）：T1 做後端、T2 做前端，各做各的
- 垂直（本節）：T1 寫骨架（Builder）、T2 Review+修+收尾（Reviewer），同一功能分階段

### 角色

| 角色 | 職責 | 模型 |
|------|------|------|
| **Builder** | 快速產出功能骨架（架構+主要邏輯），不管安全/邊界/細節 | Sonnet 4.6 |
| **Reviewer** | 安全掃描→邏輯審查→收尾整合→驗證 | Opus 4.6 |

### 交接單（必須！）

Builder 完成後在 `_temp/handoff.md` 留下：新增/修改檔案清單、DB 變更、已知 TODO、自己不確定的地方、測試方式。

### Reviewer 審查順序

1. **安全掃描** — innerHTML/XSS、SQL injection、auth、敏感資料
2. **邏輯正確** — Smoke test、重複 pattern、race condition、錯誤處理
3. **收尾整合** — sitemap、robots.txt、CLAUDE.md、死 import
4. **驗證** — build、HTTP 200、API 格式、錯誤情境

### 配比

| 配比 | 建議 |
|------|------|
| 1:1 | 新手入門、品質要求高 |
| **2:1** | **最佳** — 2 寫手 + 1 審查官 |
| 3:1 | 要錯開完成時間（給不同大小任務） |

### 反模式

- ❌ 兩人同時改同一檔案 → 先 commit 再改
- ❌ Reviewer 重寫架構 → 只修問題，架構回報管理者
- ❌ 不留交接單 → 永遠留 handoff.md
- ❌ Builder 花時間在細節 → 先讓車能跑，再讓車漂亮

**實戰數據（2026-02-19）：** 6 檔 2292 行，Builder 30min + Reviewer 20min = 50min（等效單人 2-3 hr，加速 3-4x）

---

## 相關 Skills

- [multi-agent-workflow-design](../multi-agent-workflow-design/SKILL.md) — 單終端 sub-agent 並行
- [multi-ai-cli-orchestration](../multi-ai-cli-orchestration/SKILL.md) — Claude + Codex + Gemini multi-agent orchestration
- [parallel-quality-audit-workflow](../parallel-quality-audit-workflow/SKILL.md) — 並行品質審查
