---
name: api-pool-token-pricing-methodology
description: |
  API 共享池內部代幣的美元定價方法論。使用時機：
  1. 設計 API 共享池的內部代幣（如 API Platform）需要錨定美元價值
  2. 池子裡混合免費與付費 API，需要統一定價
  3. 需要決定代幣的初始價值（Phase 1 定價）
  4. 設計 Level 乘數的交叉補貼結構
  5. 評估定價高低對雙邊市場的影響
  6. 用multi-agent research（Gemini 搜市場價 + Codex 搜方法論）取得可靠定價數據
  核心發現：用中位數而非平均數、加服務費溢價、免費 API 不等於零價值。
  已在 API Platform v1.6 規格書中實際驗證。
version: 1.0.0
date: 2026-02-11
---

# API 共享池內部代幣定價方法論

## Problem

設計一個 API 共享池（多個 API Key 匯集成資源池），需要一個內部代幣作為交易媒介。
代幣需要錨定美元價值，但池子裡 70% 免費 API、30% 付費 API，價差極大
（Weather ~$0 vs Claude $36/1000次），難以統一定價。

## Context / Trigger Conditions

- 正在設計 API 共享池或 API marketplace 的 token 經濟
- 需要為混合免費/付費 API 池定出統一代幣價值
- 設計 Level 分級乘數（不同等級 API 消費不同數量代幣）
- 需要在「用戶不心痛」與「貢獻者有感」之間找甜蜜點
- Phase 1 定價，未來過渡到市場定價

## Solution

### 核心公式：成本中位數 + 池子服務費

```
步驟 1：調查所有 API 的市場公開定價（per 1000 calls）
步驟 2：取中位數（不是平均數！因為 LLM 極端值拉高平均）
步驟 3：加上池子服務費溢價 50-100%

1 Token = 中位數 × (1 + 服務費率)
```

### 為什麼不能用平均數

```
16 個 API 每次呼叫市場價（排序後）：
  $0        (Wikipedia)
  $0.000258 (CoinGecko)
  $0.001    (Gemini Flash)
  $0.0015   (GPT-4o-mini)
  $0.00264  (Groq)          ← 中位數附近
  $0.003    (Brave Search)  ← 中位數附近
  $0.008    (Tavily)
  $0.025    (DeepL)
  $0.036    (Claude Sonnet)
  $0.054    (Perplexity)

  平均數 = $0.009  ← 被 Claude/Perplexity 拉高
  中位數 = $0.003  ← 反映多數 API 的真實價位
```

### 關鍵發現

1. **免費 API ≠ 零價值**：有配額稀缺性、整合便利、機會成本
2. **不能用訂閱費 ÷ 呼叫次數**：用官方 per-call/per-token 定價
3. **Level 乘數是刻意的交叉補貼**：免費 API 偏貴（賺利潤）、付費 API 打折（吸客）
4. **定價過高/過低都是死亡螺旋**：甜蜜點 = 用戶不心痛 + 貢獻者有感

### multi-agent research method

```
同時派出交叉驗證：
  Gemini CLI → 搜 16 個 API 的市場公開定價
  Codex CLI → 搜業界定價方法論（RapidAPI、OpenRouter）
  Explorer Agent → 掃代碼確認完整 API 清單
```

### 服務費溢價依據

| 平台 | 模式 | 溢價 |
|------|------|------|
| RapidAPI | 訂閱制 + 超額計費 | 20-30% |
| OpenRouter | 預付 credits | 10-20% |
| API 共享池 | 代幣制 | 50-100%（含配額管理 + 跨服務兌換）|

## Verification

1. **用戶體驗測試**：100 WT 體驗金能試用 15+ 個 API → 合理
2. **貢獻者動力**：一把免費 Key 月收入 50-200 WT（$0.25-1.00）→ 有感
3. **交叉補貼平衡**：Lv.1 使用量 > Lv.4 的 3 倍 → 自然打平

## Example

API Platform v1.6 實際案例：
```
16 API、70% 免費 → 中位數 $0.003 → +60% 服務費 → 1 WT = $0.005
Level: Tier 0=免費, Lv.1=1WT, Lv.2=2WT, Lv.3=3WT, Lv.4=5WT
v1.5 的 $0.006（拍腦袋）→ v1.6 的 $0.005（multi-agent research）
```

## Notes

- Phase 1 定價是暫時的，Phase 2 開放兌換後市場自動定價
- 每季度重算，新增/移除 API 時也需重算
- 交叉補貼是雙邊市場標準做法（Uber、遊戲、超市都這樣做）
- 不要追求精確，Phase 1 目標是大致合理
- See also: `token-economics-audit-methodology`, `llm-api-cost-optimization`
