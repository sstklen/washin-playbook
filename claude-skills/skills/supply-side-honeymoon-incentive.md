---
name: supply-side-honeymoon-incentive
description: |
  API 共享池 / 雙邊市場中激勵新供應者（新貢獻者）的「甜蜜期」設計模式。
  使用時機：
  1. 設計 API Key Pool 或資源共享池，需要鼓勵新人投入資源
  2. 雙邊市場供給側冷啟動 — 新供應者需要立即看到回報
  3. 現有系統用「觀察期懲罰」（降低收益）對待新人，效果適得其反
  4. 需要加權路由但不想改動 round-robin 核心邏輯
  5. 需要安全閥防止新資源擠壓舊資源
  核心技術：虛擬插槽展開（Virtual Slot Expansion）+ 安全閥 + 可調參數。
  See also: api-pool-token-pricing-methodology, token-economics-audit-methodology
author: Claude Code
version: 1.0.0
date: 2026-02-11
---

# 供給側甜蜜期激勵模式（Supply-Side Honeymoon Incentive）

## Problem

在 API 共享池或雙邊市場中，新供應者（貢獻 API Key 的人）放入資源後，
如果沒有立即看到回報（被使用、賺取 Token），就會失去動力離開。

**反模式（常見錯誤）：**
- 用「觀察期」懲罰新人（前 24h 只給半額收益）
- 理由是「防弊」「確認品質」
- 結果：新人體驗極差 → 「怎麼這麼少？」→ 不再投入

**正確模式：**
- 用「甜蜜期」獎勵新人（前 72h 優先被使用）
- 讓新人立刻看到自己的資源「正在被用」「正在賺錢」
- 結果：「賺好多！我再去申請其他家的 Key 好了」→ 正向飛輪

## Context / Trigger Conditions

- 建立 API Key 共享池 / 資源市場
- 需要激勵供給側（貢獻者）而非需求側（使用者）
- 用戶說「新人放了資源卻感覺沒人用」「怎麼讓新人願意繼續投入」
- 系統使用 round-robin 路由，需要加權但不想大改架構
- 需要在「激勵新人」和「保護老用戶」之間取得平衡

## Solution

### 核心機制：虛擬插槽展開（Virtual Slot Expansion）

**原理：** 不改變 round-robin 的核心邏輯，只在選擇池中把甜蜜期資源重複 N 份。

```typescript
// 常數（全部可調）
const HONEYMOON_HOURS = 72;           // 甜蜜期時長
const HONEYMOON_WEIGHT = 3;           // 路由權重倍數
const HONEYMOON_MAX_SLOT_RATIO = 0.5; // 安全閥上限

// 判斷是否在甜蜜期
function getHoneymoonWeight(key: ApiKey): number {
  if (!key.honeymoonUntil) return 1;
  return new Date(key.honeymoonUntil) > new Date() ? HONEYMOON_WEIGHT : 1;
}

// 建立加權插槽（核心）
function buildWeightedSlots(activeKeys: ApiKey[]): ApiKey[] {
  const weights = activeKeys.map(k => getHoneymoonWeight(k));
  const totalSlots = weights.reduce((sum, w) => sum + w, 0);
  const honeymoonSlots = weights.reduce((sum, w) => sum + (w > 1 ? w : 0), 0);
  const normalSlots = totalSlots - honeymoonSlots;

  // 安全閥：蜜月插槽不超過 50%
  let adjustedWeights = weights;
  if (normalSlots > 0 && honeymoonSlots > 0) {
    const ratio = honeymoonSlots / totalSlots;
    if (ratio > HONEYMOON_MAX_SLOT_RATIO) {
      const maxHoneymoon = normalSlots; // 50:50
      const scale = maxHoneymoon / honeymoonSlots;
      adjustedWeights = weights.map(w =>
        w > 1 ? Math.max(2, Math.round(w * scale)) : w
      );
    }
  }

  // 展開為陣列
  const slots: ApiKey[] = [];
  for (let i = 0; i < activeKeys.length; i++) {
    for (let j = 0; j < adjustedWeights[i]; j++) {
      slots.push(activeKeys[i]);
    }
  }
  return slots;
}

// 使用時只改一行（零侵入）
// 原本：const idx = index % activeKeys.length;
// 改成：
const weightedSlots = buildWeightedSlots(activeKeys);
const idx = index % weightedSlots.length;
const chosen = weightedSlots[idx];
```

### 效果分佈表

| 場景 | 新資源流量占比 | 舊資源流量占比 | 安全閥 |
|------|--------------|--------------|--------|
| 1 新 + 5 舊 | **37.5%** | 各 12.5% | 不觸發 |
| 1 新 + 2 舊 | **50.0%** | 各 25.0% | 觸發 → 縮減 |
| 3 新 + 1 舊 | 各 **28.6%** | 14.3% | 觸發 → 大幅縮減 |
| 全部都新 | 平均分配 | — | 不需要 |

### 安全閥設計

**為什麼需要安全閥：**
如果 10 個新人同時湧入，沒有安全閥的話老用戶流量會被壓到極低 → 老用戶不滿。

**運作方式：**
- 計算蜜月插槽佔總插槽比例
- 超過 50% → 等比縮減所有蜜月 Key 的權重（但最低保證 2x）
- 確保老用戶至少保有 50% 的總流量

### 可選附加：收益倍率

甜蜜期可以額外加上收益倍率（如 1.5x），但這**不是核心機制**：
- 核心是「被選中的頻率更高」（加權路由）
- 收益倍率是錦上添花，設成 1.0 即關閉

### 防弊措施

| 攻擊 | 防禦 |
|------|------|
| 移除 Key 再重新放 → 無限蜜月 | 用 addedAt 判斷，同一 Key 只給一次 |
| 自己用自己的 Key 自刷 | caller === contributor → 拒絕計分 |
| 大量新 Key 擠壓老 Key | 50% 安全閥 |
| 無限累積 | 日上限 cap |

## Verification

```bash
# 用 TypeScript/Bun 跑獨立測試腳本驗證分佈
# 模擬 100 次路由選擇，計算各 Key 被選中次數
# 1新+5舊 場景：新 Key 應被選中 ~37.5%
# 安全閥場景：蜜月佔比 > 50% 時應觸發縮減
```

## Example

**場景：Bob 放了 1 把 Brave Search Key，池裡已有 5 把舊 Key**

放 Key 那一刻：
- 獲得初始 Bonus：40 WT
- 蜜月啟動（72h）

Day 1-3（蜜月期）：
- 路由權重 3x → 流量占 37.5% → ~38 calls/day
- 每 call：3 × 0.85 × 1.5 = 3.83 WT
- 日收（受 cap）：100 WT/day
- 3 天合計：40 + 300 = **340 WT**

Day 4+（正常期）：
- 路由回到 16.7% → ~17 calls/day
- 每 call：3 × 0.85 = 2.55 WT
- 日收：43.4 WT/day

## Notes

### 關鍵學習：理解用戶真正需求

用戶說「甜蜜期」時，容易誤解為「每次賺更多」（收益加倍），
但用戶真正要的是「被選中的頻率更高」（加權路由）。

- 用戶的心理模型：「我放了 Key → 有人在用 → WT 在進帳 → 值得繼續投入」
- 重點是「被使用的頻率」，不是「每次賺多少」
- 收益加成只是附帶功能，可保留為可調參數

### 設計哲學

- 懲罰不如獎勵：觀察期 0.5x → 甜蜜期 1.5x（心理翻轉）
- 零侵入改動：只改 round-robin 的選擇池，不改核心邏輯
- 全部可調：時長、權重、安全閥比例、收益倍率都是常數
- 時間自動過期：不需要手動管理，到時間自動恢復正常

### 適用範圍

- API Key 共享池
- 算力共享市場
- 內容創作平台（新創作者曝光加成）
- 任何需要激勵供給側的雙邊市場

### See also

- `api-pool-token-pricing-methodology` — Token 定價方法論
- `token-economics-audit-methodology` — Token 經濟審計
- `api-proxy-quota-hardstop-pattern` — 額度管理
