---
name: l4-overnight-training-diagnostics
description: |
  L4 Task Engine 通宵批量訓練的診斷方法論和瓶頸分析。
  使用時機：
  1. 執行 L4 批量訓練（多輪重複任務測試學習記憶效果）
  2. 診斷品質下降原因（rate limit vs 學習系統 vs L2 工具）
  3. 規劃訓練參數（間隔、輪數、題庫設計）
  4. 分析 Groq/Claude 合成引擎的 rate limit 行為
version: 1.0.0
date: 2026-02-19
---

# L4 通宵訓練診斷方法論

## Problem
L4 Task Engine 需要批量訓練來建立學習記憶庫，但連續訓練會觸發上游 API rate limit，
導致品質急劇下降。需要區分「學習系統問題」vs「基礎設施問題」。

## Context / Trigger Conditions
- 執行 L4 批量訓練（24+ 任務 × 多輪）
- 品質分數在中後期突然從 0.85 降到 0.30
- 出現「整合引擎暫時不可用」錯誤
- "Failed to parse JSON" 超時錯誤（109-120s）
- 學習命中率高但品質反而低

## Solution

### 1. 訓練參數設計

| 參數 | 建議值 | 原因 |
|------|--------|------|
| 任務間隔 | ≥180s（非 90s） | 90s 在 R2 就開始 rate limit |
| 輪數 | 2-3 輪 | R1 建記憶，R2 驗證學習效果，R3 容易全面 rate limit |
| 題庫大小 | 12-16 題（非 24 題） | 減少每輪任務量，降低 rate limit 風險 |
| 重複題 | 4-6 題 | 用於驗證學習記憶是否生效 |

### 2. 品質下降診斷流程

```
品質突然下降？
├─ 檢查錯誤訊息
│  ├─ "整合引擎暫時不可用" → Groq 合成引擎 rate limit
│  ├─ "Failed to parse JSON" + 120s → VPS 超時
│  └─ 品質 0.30 + "步驟 5/5" → L2 工具正常但合成失敗
│
├─ 檢查 L2 工具成功率（/api/v2/task/stats）
│  ├─ smart-search 100% → L2 搜尋沒問題
│  ├─ smart-read 94%+ → L2 讀取正常
│  └─ 工具都正常 → 問題在 synthesize 或 evaluate
│
└─ 結論
   ├─ L2 工具正常 + 合成失敗 → 上游 AI API rate limit
   ├─ L2 工具失敗 → 搜尋/讀取 API rate limit
   └─ 學習命中但品質低 → 合成步驟的問題，不是學習系統的問題
```

### 3. 合成引擎 Rate Limit 時間線（實測數據）

| 時間點 | Groq 狀態 | Claude Haiku 狀態 |
|--------|-----------|------------------|
| 0-60 min (R1) | 正常 | 正常 |
| 60-120 min (R2) | 偶爾超時 | 偶爾失敗 |
| 120-180 min (R3) | 全面 rate limit | 全面失敗 |

### 4. 解決方案優先順序

1. **合成引擎多級 fallback**：Claude → Groq Key1 → Key2 → Key3 → 拼接原始結果
2. **增加訓練間隔**：90s → 180s
3. **減少每輪題目**：24 → 12-16
4. **分時段訓練**：分 2 晚跑，每晚 1.5 小時

### 5. 學習記憶效果基準（實測）

| 輪次 | 學習命中率 | 品質影響 |
|------|-----------|---------|
| R1 | 14% | 基線 0.85 |
| R2 | 100% | +0.05 ~ +0.40（排除 rate limit） |
| R3 | 100% | 被 rate limit 掩蓋，實際效果不明 |

最大品質提升：**+0.40**（market-trends 類別，from 0.48 to 0.88）

## Verification
- 檢查 `/api/v2/task/stats` 的 toolRanking → L2 成功率
- 檢查 `/api/v2/task/learning` → 學習記憶筆數和品質
- grep "整合引擎暫時不可用" 在訓練 log 中的出現頻率
- 比較 R1 vs R2 的同類別品質分數（排除 0.30 的 rate limit 影響）

## Example
```bash
# 訓練完成後的快速診斷
grep -c "✨命中" /tmp/l4-training-vps.log   # 學習命中次數
grep -c "✅ 成功" /tmp/l4-training-vps.log  # 成功次數
grep -c "❌ 錯誤" /tmp/l4-training-vps.log  # 錯誤次數
grep "整合引擎" /tmp/l4-training-vps.log    # 合成引擎失敗

# VPS 端確認
curl -s -H "Authorization: Bearer API_KEY" https://api.example.com/api/v2/task/stats
curl -s -H "Authorization: Bearer API_KEY" https://api.example.com/api/v2/task/learning?limit=5
```

## Notes
- VPS 有 3 把 Groq key（村長池/村營池/果農池）自動輪轉，但連續 2hr+ 使用 3 把都會 rate limit
- Claude Haiku 是合成引擎的第一選擇，但 ANTHROPIC_API_KEY 也有 rate limit
- 學習記憶用 LIKE '%keywords%' 匹配，未來改 Embedding 向量會更精準
- 品質 0.30 = synthesize 失敗的預設最低分，不代表 L2 工具沒做事（步驟可能 5/5 成功）
- 最佳策略被自動記錄：`smart-search→smart-search→smart-search→smart-read→smart-llm`（8 次勝出）
