---
name: agentic-coding-complete
description: |
  Agentic Coding 完整指南：技術實踐 + 心態轉變 + 理論實戰對照。
  使用時機：(1) 設計 AI 輔助開發工作流，(2) 理解五大原則（Context、Planning、Debugging、Verifiability、Automation），
  (3) 實施三層驗證框架（Silen + Anthropic + Karpathy），(4) IDE + Agent 協作配置，
  (5) 學完 AI 課程（如吳恩達 Agentic AI）想落實到工作流，(6) 理解宣告式 vs 命令式 prompting，
  (7) Maker vs Code Writer 類型定位與槓桿效應設計。整合所有 Agentic Coding 知識為完整系統。
version: 2.1.0
date: 2026-02-10
---

# Agentic Coding Complete Guide

> 方法論 + 實現 + 經驗 = 完整系統

---

## Quick Reference

| 主題 | 重點 | 詳細 |
|------|------|------|
| 五大原則 | Context, Planning, Debug, Verify, Automate | [five-principles](references/five-principles.md) |
| 三層驗證 | Silen + Anthropic + Karpathy | [three-layer-verification](references/three-layer-verification.md) |
| IDE + Agent | Split-screen 協作工作流 | [ide-agent-workflow](references/ide-agent-workflow.md) |
| 代碼審查 | claude -p 新上下文審查 | [anthropic-verification](references/anthropic-verification.md) |

---

## 核心五大原則

> 基於 Silen Naihin（Cursor 前 0.01% 用戶）+ Anthropic 官方實踐

### 1. Context Management（上下文管理）

```
問題：長對話累積雜訊 → 記憶污染
解法：一個對話 = 一個任務，AI 自動管理清理
實現：使用率 > 70% 時自動存檔 + 摘要 + 清理
```

### 2. Planning First（規劃優先）

```
問題：邊做邊想 → 範圍蔓延和返工
解法：先問「不要做什麼」比「要做什麼」更重要
實現：複雜決策用 think/ultrathink，先定義成功標準
```

### 3. Smart Debugging（智能除錯）

```
問題：同一方法試 5+ 次 → 浪費時間
解法：失敗 3 次 → 自動換方法
實現：
  - 失敗 1-2：微調當前方法
  - 失敗 3：完全換方向
  - 仍卡住：新對話（心理重置）
```

### 4. Verifiability（可驗證性）

```
問題：「我改好了」但沒驗證 → 隱藏 bug
解法：不審查代碼，驗證行為
實現：
  - UI：截圖驗證
  - API：實際請求
  - 邏輯：測試執行
  - 重構：先寫測試
```

### 5. Automation（自動化）

```
問題：重複 prompt、重複流程
解法：頻繁 prompt → CLI 命令，頻繁流程 → agent
實現：痛點 → 文檔 + skill，累積可重用知識
```

---

## 官方驗證流程

> Anthropic 團隊：100% 代碼由 Claude 生成，每日 20+ PR

### claude -p 新上下文審查

```bash
# 1. Claude 生成代碼
# 2. 本地測試通過
# 3. 新上下文審查（關鍵！）
claude -p "
審查這段代碼，檢查：
1. 過度複雜化
2. 死代碼 / 未完成重構
3. 測試覆蓋缺口
4. 性能問題

[貼上代碼或 git diff]
"

# 4. 修復問題
# 5. 再次測試 + commit
```

**為什麼新上下文有效：**
- 無疲勞：沒有分析同一代碼數小時
- 不同注意力：乾淨的工作記憶
- 新視角：類似不同人的代碼審查
- 高命中率：第二遍捕獲 ~70% 問題

### Block-at-Submit Hook

```bash
# .claude/hooks/pre-commit-verify.sh
#!/bin/bash
npm test
if [ $? -ne 0 ]; then
  echo "❌ 測試失敗，無法 commit"
  exit 1
fi
echo "✅ 測試通過"
exit 0
```

---

## IDE + Agent 協作

> 「不需要 IDE 了」是錯的。IDE 變得更重要。

### Split-Screen 設置

```
左螢幕 (50%): Claude Code
  - Session 1: 功能開發
  - Session 2: 測試
  - Session 3: Bug 調查

右螢幕 (50%): IDE
  - 開啟生成的代碼文件
  - 即時運行測試
  - 檢查輸出
  - 視覺檢查
```

### 工作流循環

```
1. Claude Code: "生成功能 X"
   ↓ Agent 生成代碼
2. IDE: 運行測試
   ↓ 通過/失敗
3. Claude Code: "測試顯示問題 Y，修復它"
   ↓ Agent 改進
4. IDE: 驗證輸出符合規格
   ↓ 視覺檢查
5. 完成? → 部署
   未完成? → 迭代
```

### 何時用哪個工具

| 用 Claude Code | 用 IDE |
|----------------|--------|
| 代碼生成 | 視覺檢查 |
| 算法開發 | 測試執行 |
| 重構 | 輸出驗證 |
| 測試框架 | 性能分析 |
| 大規模改動 | 神秘 bug 調試 |

---

## 三層驗證框架

### 為什麼需要三層？

單一來源有幫助。但三個獨立來源從不同角度驗證相同原則？那就是你找到真正有效的東西。

```
Layer 1: 方法論 (Silen Naihin)
   ↓ 回答：「什麼原則應指導 LLM 編碼？」

Layer 2: 實現 (Anthropic 官方)
   ↓ 回答：「如何實際執行這些原則？」

Layer 3: 經驗 (Andrej Karpathy)
   ↓ 回答：「頂級工程師這樣做會發生什麼？」
   ↓
完整系統理解
```

### 一致性驗證

| 概念 | Silen | Anthropic | Karpathy | 狀態 |
|------|-------|-----------|----------|------|
| 代碼審查 ≠ 行為驗證 | ✓ | ✓ | ✓ | 強 |
| 上下文很重要 | ✓ | ✓ | ✓ | 強 |
| 規劃減少返工 | ✓ | ✓ | ✓ | 強 |
| 自動化是關鍵 | ✓ | ✓ | ✓ | 強 |
| IDE 仍有用 | - | ✓ | ✓ | 強 |
| 新上下文有幫助 | ✓ | ✓ | ✓ | 強 |

---

## 完整工作流範例

### 一小時功能實現

```
08:00 Claude Code (左):
      "構建用戶認證功能"
      ↓ Agent 生成 200 行

08:10 IDE (右):
      - 快速掃描：Imports, 結構看起來不錯
      - 運行測試：Auth 流程正常
      - 檢查：沒有明顯 bug

08:20 Claude Code (左):
      "添加速率限制"
      ↓ Agent 添加防護代碼

08:25 IDE (右):
      - 測試：速率限制正確阻擋
      - 檢查：錯誤訊息清晰

08:30 IDE (右):
      - 運行完整測試套件：150 測試通過
      - 性能：50ms auth 延遲
      - 檢查：無回歸

08:35 部署 ✓
```

**結果：35 分鐘 = 1-2 天手動編碼品質**

---

## 紅旗（不要做什麼）

### 基於所有三個來源

❌ **不要：** 假設 AI 代碼總是正確的
✅ **要：** 用測試和 IDE 檢查驗證行為

❌ **不要：** 堆積長上下文
✅ **要：** 定期重置和摘要

❌ **不要：** 給 AI 逐步命令
✅ **要：** 定義成功標準，讓它找出步驟

❌ **不要：** 重複失敗後期待快速修復
✅ **要：** 失敗 3 次後換方法

❌ **不要：** 不理解就交出代碼
✅ **要：** 用 IDE 保持視覺知情

---

## References

- [five-principles.md](references/five-principles.md) - Silen Naihin 五大原則詳解
- [three-layer-verification.md](references/three-layer-verification.md) - 三層驗證框架完整說明
- [ide-agent-workflow.md](references/ide-agent-workflow.md) - IDE + Agent 協作模式
- [anthropic-verification.md](references/anthropic-verification.md) - Anthropic 官方實踐

---

## Merged Skills (archived)

The following skills have been merged into this guide:

- **agentic-ai-course-to-practice** — 吳恩達 Agentic AI 課程理論對照 Claude Code 實戰，識別已運用技巧與缺口，反思方法論避免過度工程化
- **agentic-mindset-for-humans** — Agentic 時代人類心態轉變，宣告式 vs 命令式 prompting，Maker vs Code Writer 類型定位與槓桿效應設計

---

*Part of 🥋 AI Dojo Series by [Washin Village](https://washinmura.jp)*
