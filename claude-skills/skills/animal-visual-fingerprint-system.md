---
name: animal-visual-fingerprint-system
description: |
  完整的動物個體辨識方法論：視覺指紋資料庫 + Few-Shot Learning + Ensemble 架構。
  使用時機：(1) 需要辨識相似動物個體（人類都分不清），(2) 訓練數據不足（< 100 張/動物），
  (3) 需要從 28 隻擴展到 10,000+ 隻寵物，(4) 傳統純視覺模型準確率不足（< 70%），
  (5) VLM 外觀分類錯誤（長毛判成短毛等）→ 視覺原型照片選擇問題，
  (6) 想用 Fine-tuning 提升辨識準確率但不確定方法和成本。
  核心方法：使用 Gemini Vision API 自動提取結構化特徵 → 建立視覺原型 → 訓練 Few-Shot 專家模型。
  v1.1.0 新增：視覺原型照片選擇標準、三層資料同步機制、多照片 VLM 策略（準確率 67%→100%）。
  成本：Gemini 比 Claude Vision 便宜 240 倍。準確率：67% → 92%（+25%）。
  涵蓋 Fine-tuning 策略（Gemini/OpenAI/LoRA）、訓練數據要求、成本估算。
author: Claude Code
version: 1.2.0
date: 2026-02-10
---

# 動物視覺指紋系統（Animal Visual Fingerprint System）

## Problem

傳統動物辨識系統面臨三大瓶頸：

1. **人類標註不可靠**：相似動物（Gold vs Jelly 都是虎斑白貓）連人類都分不清
2. **純視覺模型無法理解語義**：無法讀懂「額頭有粗 M 字型」「白色胸部面積大」
3. **固定類別難擴展**：從 28 隻 → 10,000 隻需要重新訓練整個模型

**實際案例（和心村 GAIA 系統）**：
- 單獨 EfficientNet: 67% 準確率
- Gold vs Jelly 混淆率: 32%
- 原因：兩者都是虎斑白貓，視覺特徵極度相似

## Context / Trigger Conditions

當你遇到以下情況時使用此 skill：

### 主要觸發條件

1. **相似動物辨識難題** — 人類標註員也分不清，傳統模型準確率 < 70%
2. **訓練數據不足** — 每隻動物 < 100 張照片，適合 Few-Shot Learning
3. **需要可擴展架構** — 從 28 隻到 10,000+ 隻，不想每次都重新訓練
4. **成本敏感** — 需要批量處理照片，Claude Vision API 太貴

### 次要觸發條件

- 需要建立「寵物身份證」系統（走失尋回、保險理賠）
- 需要跨角度穩定辨識（正面、側面、俯視、仰視）
- 需要處理困難場景（昏暗光線、部分遮擋）

## Solution

### 核心概念：視覺指紋（Visual Fingerprint）

不訓練「這是 Gold」，而是：

1. **提取結構化特徵**（如人類指紋）
2. **建立視覺原型**（Gold 的「身份證」）
3. **計算相似度**（新照片 vs 原型的距離）

---

### 三階段完整流程（摘要）

<!-- 完整實作代碼與流程詳見 references/ -->

#### 階段 1：建立視覺指紋資料庫（2-3 小時/動物）

用 Gemini 2.0 Flash Vision API 批量分析所有照片，提取結構化特徵（M 字型、白色面積、眼睛顏色等）。
- 成本：$0.015/110 張照片（僅 1.5 美分！）
- 對比 Claude Sonnet Vision: $0.55（貴 37 倍）

#### 階段 1.5：選擇視覺原型照片（v1.1.0 新增）

5 張標準原型：portrait / side / fullbody / **feature**（最重要：展示區分性特徵）/ daily。
- 關鍵教訓：Ace（長毛三色貓）因原型照片未展示蓬鬆尾巴 → 被錯誤分類為短毛貓。

#### 階段 2：建立視覺原型（1 小時/動物）

統計分析所有特徵 → 找出穩定特徵（如 M 字型 0.96 穩定性、白色胸部 0.93）。

#### 階段 3：訓練 Few-Shot 專家模型（4-6 小時/動物）

兩種方法：Siamese Network 或 Prototypical Network。
- 訓練數據：僅需 50 張（vs 傳統 10,000+ 張）
- 新動物不需重新訓練，只需計算新原型

詳見 [references/implementation-details.md](references/implementation-details.md)

---

### 完整混合架構（推薦！）

```
新照片
    ↓
【第 1 層】Gemini Vision 提取特徵（0.5 秒）
    ↓
【第 2 層】與視覺原型比對（0.01 秒）
    ↓
【第 3 層】Few-Shot 模型精確辨識（0.1 秒）
    ↓
【可選第 4 層】Gemini Vision 最終確認（2 秒，僅信心度 0.5-0.7 時）
```

**效能對比**：

| 方法 | 準確率 | 速度 | 成本/張 | 數據需求 |
|------|--------|------|---------|---------|
| 純 GAIA（EfficientNet）| 67% | 0.05s | $0 | 10K+ 張 |
| **混合方案（推薦）** | **92%** | **0.6s** | **$0.0015** | **50 張** |
| 純 Gemini Vision | 85% | 2.5s | $0.005 | 0 張（Zero-Shot）|

### 可擴展性：從 28 隻 → 10,000+ 隻

使用 FAISS 向量索引，查詢效能：
- 10,000 隻：0.01 秒 / 100,000 隻：0.05 秒 / 1,000,000 隻：0.5 秒
- 新動物加入：只需計算新原型（$0.015/動物）→ 不需要重新訓練

詳見 [references/implementation-details.md](references/implementation-details.md)

---

## Verification

驗收標準摘要：
1. 準確率 >= 90%（測試集）
2. 與最相似動物的區分度 >= 0.85
3. 跨角度穩定性 >= 0.80
4. 視覺指紋資料庫完整（fingerprint.json + prototype.json）
5. 專家模型訓練完成（expert_model.pth）

詳見 [references/verification-and-testing.md](references/verification-and-testing.md)

---

## Example

### Gold 實施案例摘要（7 天完成）

| 天數 | 工作 | 產出 |
|------|------|------|
| Day 1-2 | 視覺分析（59 張照片 + 51 支影片） | SOUL.md |
| Day 3 | Gemini Vision 批量分析 | gold_visual_fingerprint.json（$0.015）|
| Day 4 | 統計分析建立原型 | gold_prototype.json |
| Day 5 | 訓練 Few-Shot 模型 | 92% 準確率 |
| Day 6-7 | 測試與整合到 GAIA | 交叉驗證通過 |

**成果**：67% → **92%**（+25%），成本僅 $0.015

詳見 [references/gold-case-study.md](references/gold-case-study.md)

---

### 三層資料同步機制（v1.1.0 新增）

SOUL.md（語義層）、視覺原型（視覺層）、視覺指紋（數據層）必須保持一致。
更新任一層時，必須同時更新其他兩層，否則會導致分類錯誤。

### 多照片 VLM 策略（v1.1.0 新增）

單照片 VLM 分類不穩定（~67%），使用 5 張照片投票策略可達 **100%** 準確率。
- 初步分類用 Gemini（$0.00065/動物）
- 困難案例用多照片 Sonnet（$0.025/動物，100% 準確率）
- 信心度 < 0.8 時自動升級到 Sonnet

詳見 [references/data-sync-and-multi-photo-vlm.md](references/data-sync-and-multi-photo-vlm.md)

---

## Notes

### 成本策略摘要

- **批量特徵提取**：用 Gemini（$0.000125/張，便宜 38x）
- **精確分析**：用 Claude（準確率高 5%）
- **困難案例**：多照片 Sonnet（$0.025，100% 準確率）

### 困難動物（黑貓群組）

Tooth/Sirius/Suzu → 群組策略（統一辨識）+ 行為特徵輔助 + 時間序列追蹤

### 擴展路線圖

- Phase 1：和心村 28 隻（3-6 個月，~$50）
- Phase 2：外部寵物 100-200 隻（6-12 個月）
- Phase 3：全球平台 10,000+ 隻（12-24 個月，Freemium 商業化）

### Fine-tuning 整合

1. 先用本 skill 建立視覺指紋資料庫
2. 訓練時參考已整合的群組平衡策略
3. 整合到 GAIA 系統

詳見 [references/notes-cost-strategy-roadmap.md](references/notes-cost-strategy-roadmap.md)

---

## References

### 官方文檔
- [Gemini 2.0 Flash Pricing](https://ai.google.dev/pricing) - 圖片 $0.000125/張
- [Claude Sonnet 4 Pricing](https://docs.anthropic.com/pricing) - 圖片 $0.0048/張
- [FAISS Vector Search](https://github.com/facebookresearch/faiss) - 向量檢索庫

### 學術論文
- Petnow 99% 準確率論文（IEEE 2021）- 200K 數據 + Siamese Network
- Prototypical Networks (NIPS 2017) - Few-Shot Learning 原型網絡
- ArcFace Loss (CVPR 2019) - 度量學習

### 實測數據
- 和心村 GAIA v5.0.2 - EfficientNet 67% 準確率
- Gold 視覺分析（2026-02-03）- 59 張照片 + 51 支影片
- Gemini Vision 批量測試 - $0.015/110 張照片

### 相關 Skills
- 群組平衡訓練策略（已整合至本指南）
- `gemini-api-guide` - Gemini API 使用指南
- `vision-api-fastapi-integration` - Claude Vision 整合

---

## Quick Win: Few-Shot Comparison（零訓練方法）

> **2026-02-03 實測：100% 準確率（17/17 非目標動物正確識別）**

**核心洞察**：不要問「這是誰」，改問「這最像誰」。
- 直接判斷「是不是 Jelly」→ 10% 準確率
- 比較「最像誰」→ **100% 準確率**（非目標判斷）
- 成本：~$0.02（182 支影片）

**適用**：快速驗證影片分類、少量類別（4-10 隻）、不想訓練模型
**不適用**：100+ 隻動物、即時辨識、需要 95%+ 準確率

詳見 [references/few-shot-comparison-quick-win.md](references/few-shot-comparison-quick-win.md)

## Merged Skills (archived)

The following skills have been merged into this guide:
- **animal-recognition-finetuning** — Fine-tuning 策略（Gemini/OpenAI/LoRA）、訓練數據要求、成本估算、準確率提升路徑
