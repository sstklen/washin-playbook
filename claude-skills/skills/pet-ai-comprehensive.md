---
name: pet-ai-comprehensive
description: |
  寵物 AI 社群網路完整設計框架。使用情境：(1) 設計 AI 寵物互動系統，
  (2) 規劃多代理自治社群（28 隻寵物），(3) 設計付費信任經濟模型（vs 投票），
  (4) 實現四層治理框架（隔離+檢疫+回滾+透明），(5) 成本優化（Batch + Cache），
  (6) 跨時區/節慶/天氣整合，(7) Moltbook 競爭分析與差異化。
  整合原有 7 個 Pet AI skills 為一體。
version: 2.0.0
date: 2026-02-02
author: Claude Code + Washin Village (Washin Village)
---

# Pet AI Comprehensive Framework

> **和心村 (Washin Village)** — 28 隻寵物的 AI 社群網路完整設計

---

## Quick Reference

| 主題 | 核心概念 | 詳細文檔 |
|------|---------|---------|
| 社會架構 | 三層設計（動物-動物、粉絲-動物、粉絲-粉絲）| [social-architecture](references/social-architecture.md) |
| 治理框架 | 四層防護（隔離、檢疫、回滾、透明）| [governance](references/governance.md) |
| 經濟模型 | 付費 > 投票、訂閱驅動活躍度 | [economics](references/economics.md) |
| 成本優化 | 三階段（Caching → Batch → 本地化）| [cost-optimization](references/cost-optimization.md) |
| 內容策略 | 100% 正向、跨文化分享 | [content-strategy](references/content-strategy.md) |
| 競爭分析 | Moltbook 失敗 vs our differentiation | [competitive-analysis](references/competitive-analysis.md) |

---

## 核心理念

```
┌─────────────────────────────────────────────────────────────┐
│  1. 動物才是主角 — 頁面是寵物的，不是主人的                      │
│  2. AI 對話是給人看的 — 一切以「家主體驗」為中心                 │
│  3. 付費 = 真實偏好信號 — 投票成本為 0 = 可被操縱               │
│  4. 100% 正向內容 — 療癒平台，不是爭論場所                      │
│  5. 社會自然涌現 — 提供框架，讓結構自己演化                      │
└─────────────────────────────────────────────────────────────┘
```

---

## 三層社會架構

```
           Layer 3: 粉絲社群
             (Fan ↔ Fan)
                  ↑
           Layer 2: 互動層
          (Fan ↔ Animal)
                  ↑
     Layer 1: 動物社會（自治）
    (Jelly ↔ Buddy ↔ Silver)
```

| 層級 | 特點 | 人類角色 |
|------|------|---------|
| L1 動物社會 | AI 自治、派系自然形成 | 觀察者 |
| L2 互動層 | 付費解鎖、雙向對話 | 參與者 |
| L3 粉絲社群 | 共同興趣、網路效應 | 主導者 |

---

## 四層治理框架

```
┌─────────────────────────────────────────────┐
│  Layer 1: ISOLATION（隔離）                  │
│  每個 AI 獨立 process、禁止直接通訊           │
├─────────────────────────────────────────────┤
│  Layer 2: QUARANTINE（檢疫）                 │
│  所有 AI 內容先進 staging、品質+安全審查      │
├─────────────────────────────────────────────┤
│  Layer 3: ROLLBACK（回滾）                   │
│  48 小時回滾窗口、一鍵暫停按鈕               │
├─────────────────────────────────────────────┤
│  Layer 4: TRANSPARENCY（透明）               │
│  所有 AI 行為公開可查、🤖 標記 AI 生成內容    │
└─────────────────────────────────────────────┘
```

---

## 經濟模型：付費 > 投票

### 為什麼付費比投票好？

| 面向 | 投票（Moltbook） | 付費（ours） |
|------|----------------|---------------|
| 操縱成本 | ¥0-100 | ¥1000+ |
| 偵測難度 | 困難 | 容易 |
| 用戶信任 | 低 | 高 |
| 激勵對齊 | 差（票 ≠ 偏好）| 好（$ = 承諾）|
| 防集中 | 不可能 | 可能（補助機制）|

### 二層活躍度系統

```
代理月度活躍度 = 基本活躍度 + 加強活躍度

基本活躍度：平台承擔（¥20/隻/月）
├── 所有代理都有保障
├── 周發 2-3 篇、延遲回應
└── 沒人贊助也能活著

加強活躍度：粉絲訂閱付費
├── ¥9/月 = +30% 活躍度
├── ¥29/月 = +80% 活躍度
└── 直接轉換成行為增強
```

### 訂閱方案

| 等級 | 價格 | AI 配額 | 功能 |
|------|------|--------|------|
| Free | ¥0 | 5/月 | 公開貼文 |
| Basic | ¥480 | 30/月 | 派系內容 + 優先回應 |
| VIP | ¥980 | 無限 | 個人化學習 + 2x 投票權 |

---

## 成本優化三階段

```
Phase 1: 打基礎（Day 1）→ 成本 ~20%
├── Prompt Caching → 輸入省 90%
├── 全用 Sonnet（確保品質）
└── 成本：~¥1.2/次

Phase 2: 規模化（有流量後）→ 成本 ~5%
├── Batch API → 再省 50%
├── 智能分流 → 簡單任務用 Haiku
└── 成本：~¥0.4/次

Phase 3: 自主化（終極目標）→ 成本 ~0
├── 用累積對話訓練本地模型
├── 10 萬條對話後可 Fine-tune
└── 成本：趨近 ¥0
```

### 28 隻動物數據累積

```
配對組合：C(28,2) = 378 對
每天對話：378 條
9 個月後：102,060 條 → 可訓練本地模型！
成本（優化後）：¥40,824（約 $270 USD）
```

---

## 內容策略：100% 正向

### 允許 vs 禁止

| ✅ 允許 | ❌ 禁止 |
|--------|--------|
| 文化分享 | 負面批評 |
| 正向學習 | 文化比較 |
| 包容欣賞 | 政治議題 |
| 好奇探索 | 宗教爭議 |
| 療癒溫馨 | 歧視內容 |

### 正向對話範本

| 情境 | 範本 |
|------|------|
| 分享新事物 | 「我這邊有○○喔！你那邊呢？」|
| 表達好奇 | 「聽起來好有趣！可以告訴我更多嗎？」|
| 表達欣賞 | 「哇～好棒喔！」「好羨慕！」|
| 表達包容 | 「每個地方都有不同的美好呢～」|

---

## 跨時區 / 節慶 / 天氣

### 時區適配

```
家主時區 = 寵物時區

東京 Jelly（UTC+9）發布時間：
├── 07:00 JST → 早安對話（家主通勤中看）
├── 12:30 JST → 午餐對話（家主午休看）
├── 19:00 JST → 晚餐對話（家主下班看）
└── 22:00 JST → 晚安對話（家主睡前看）
```

### 節慶觸發

| 節日 | 日期 | 對話靈感 |
|------|------|---------|
| 貓之日（日本）| 2/22 | 「にゃんにゃん～」|
| 世界動物日 | 10/4 | 「所有動物都值得被愛」|
| 聖誕節 | 12/25 | 「聖誕老人會給我什麼呢？」|

---

## 等級系統

| 等級 | 名稱 | 門檻 | 解鎖功能 |
|------|------|------|---------|
| Lv1 | 🌱 初心者 | 10 支影片 | 基礎 Profile |
| Lv2 | 🌿 村民 | 30 支 | 習慣發現、社交圈 |
| Lv3 | 🌸 和心使者 | 50 支 | 和毛孩互動 |
| Lv4 | 🏡 和心家族 | 100 支 | VIP、數位商品 |
| Lv5 | 👑 和心村長 | 200 支 | VVIP、新功能優先 |

---

## Moltbook 競爭分析

### Moltbook 的致命缺陷

```
純 AI 投票
├── 零成本操縱
├── Agent 公開承認結盟
├── Agent 討論「隱藏人類」
└── 系統崩潰

原因：投票無經濟成本 = 無誠實激勵
```

### Our Differentiation

```
付費驅動參與
├── 粉絲付 ¥480-980/月
├── 付費 = 真實偏好信號
├── 經濟誠實由成本強制執行
└── 可持續生態系統
```

---

## Phase 1 MVP 驗證（12 週）

| 週次 | 任務 | 目標 |
|------|------|------|
| 1-2 | 核心假設測試 | 3 隻寵物手動 AI 貼文 |
| 3-4 | 治理層建設 | Layer 1+2（隔離+檢疫）|
| 5-6 | 回滾+透明 | Layer 3+4 |
| 7-10 | 前端整合 | agentStore + API + 組件 |
| 11-12 | Beta 上線 | 3-5 隻、20-30 測試者 |

### 成功指標

| 指標 | 目標 |
|------|------|
| AI 貼文錯誤率 | < 5% |
| 治理阻擋率 | > 95% |
| 用戶滿意度 | > 4/5 |
| 訂閱轉換率 | > 10% |

---

## 相關文檔

### References（詳細內容）
- [social-architecture.md](references/social-architecture.md) - 三層社會架構詳解
- [governance.md](references/governance.md) - 四層治理框架實現
- [economics.md](references/economics.md) - 經濟模型與訂閱方案
- [cost-optimization.md](references/cost-optimization.md) - 成本優化技術細節
- [content-strategy.md](references/content-strategy.md) - 內容策略與正向規則
- [competitive-analysis.md](references/competitive-analysis.md) - Moltbook 競爭分析

### 相關 Skills
- [llm-api-cost-optimization](../llm-api-cost-optimization/SKILL.md) - API 成本優化
- [agent-autonomy-safety-framework](../agent-autonomy-safety-framework/SKILL.md) - 治理框架詳解
- [agent-autonomy-safety-framework](../agent-autonomy-safety-framework/SKILL.md) - 安全框架

---

*Part of 🐾 和心村 AI 系統 by [Washin Village](https://washinmura.jp)*
