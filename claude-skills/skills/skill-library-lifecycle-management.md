---
name: skill-library-lifecycle-management
description: |
  Skills 庫批量優化與生命週期管理的完整工作流。使用時機：
  (1) Skills 數量超過 Anthropic 建議的 20-50 個上限，需要精簡，
  (2) 需要合併多個相似 skills 為一個主力 skill，
  (3) 合併後需要修復跨引用（broken cross-references），
  (4) 定期審計 skills 品質（禁用詞、行數、重複內容），
  (5) 用多 Agent 並行處理大量 skill 檔案編輯。
  基於 Anthropic 官方 Progressive Disclosure 架構設計，實戰驗證：102 → 49 skills。
author: Claude Code
version: 1.0.0
date: 2026-02-10
---

# Skills 庫生命週期管理

## Problem

Claude Code Skills 庫隨時間增長到 100+ 個，超過 Anthropic 建議的 20-50 上限。每個 skill 的 YAML frontmatter（~100 tokens）在 semantic matching 時都會被載入，造成效能浪費和匹配精準度下降。

## Context / Trigger Conditions

- Skills 數量 > 50 個，需要精簡
- 多個 skills 涵蓋相似主題（如 5 個 Supabase 相關 skills）
- 審計發現 YAML `name` 含禁用詞（"claude"/"anthropic"）
- 合併 skills 後出現 broken cross-references
- 定期維護（每季度或 skills 達到閾值時）

## Solution

### 理論基礎：Anthropic Progressive Disclosure

```
Level 1: YAML frontmatter（name + description）
         → 永遠載入，每個 ~100 tokens
         → 數量越多 = 越浪費 + 匹配越不精準

Level 2: SKILL.md body
         → 只在 semantic match 時載入

Level 3: references/ 子目錄
         → 只在 SKILL.md 中被引用時載入
```

**核心原則：description 是王道。** 合併時，把被合併 skills 的觸發條件吸收進主力 skill 的 description。

### Step 1: 審計（Audit）

```bash
# 1. 計算總數
find ~/.claude/skills -name "SKILL.md" -not -path "*/_archive/*" | wc -l

# 2. 找禁用詞（name 欄位不得含 "claude"/"anthropic"）
rg "^name:.*claude|^name:.*anthropic" ~/.claude/skills/*/SKILL.md

# 3. 找超長 skills（> 500 行）
for f in ~/.claude/skills/*/SKILL.md; do
  lines=$(wc -l < "$f")
  [ "$lines" -gt 500 ] && echo "$lines $f"
done | sort -rn

# 4. 找主題重疊的 skills（關鍵字聚類）
rg -l "supabase" ~/.claude/skills/*/SKILL.md  # 重複出現 = 可能合併
```

### Step 2: 規劃合併群組

**聚類規則：**

| 情況 | 處理 |
|------|------|
| 2-3 個高度相關 | Deep merge（重寫結構） |
| 3-5 個同領域 | Light merge（擴展 description + 加 Merged Skills 段落） |
| 完全冗餘 | 直接 archive |
| 獨立有價值 | 保留不動 |

**Light Merge 模式（最常用）：**

1. 選定主力 skill（最完整、最常用的那個）
2. 擴展主力 skill 的 YAML description，吸收次要 skills 的觸發條件
3. 在主力 skill 底部加 `## Merged Skills (archived)` 段落
4. 將次要 skills 移至 `_archive/` 目錄

```markdown
## Merged Skills (archived)

The following skills have been merged into this guide:
- **secondary-skill-name** — 一句話描述原有功能
- **another-skill-name** — 一句話描述原有功能
```

### Step 3: 執行合併（Multi-Agent 並行）

**適合場景：** 10+ 個合併群組，使用 Sub-Agent 並行處理

```
Main Agent (Opus): 規劃群組、分配任務、驗證結果
├─ Agent A (Sonnet): 處理群組 1-4（deep merge）
├─ Agent B (Sonnet): 處理群組 5-8（light merge）
├─ Agent C (Sonnet): 處理群組 9-12
├─ Agent D (Sonnet): 處理群組 13-16
└─ Agent E (Sonnet): 處理群組 17-20
```

**注意事項：**
- Sub-Agent 可能因 token 耗盡而只完成部分工作 → Main Agent 接手未完成的群組
- 檔案移動（`mv`）需 Main Agent 直接執行（Sub-Agent 可能無權限）
- 每個 Agent 使用 `run_in_background: true` 以並行執行

### Step 4: 交叉引用修復（Critical！）

合併後，活躍 skills 中可能引用了已封存的 skill 名稱。必須分 3 類處理：

| 引用類型 | 位置 | 處理方式 |
|---------|------|---------|
| **A. Merged Skills 段落** | `## Merged Skills (archived)` | **保持不動**（文檔紀錄） |
| **B. Body 交叉引用** | `See also`、內文提及、表格 | **更新為新主力 skill 名稱** |
| **C. 自引用** | Skill 引用自己已合併的內容 | **標註「已整合至本指南」** |

**搜尋 broken references：**

```bash
# 建立封存名稱清單
archived_names=$(ls ~/.claude/skills/_archive/ | tr '\n' '|' | sed 's/|$//')

# 在活躍 skills 中搜尋
rg "$archived_names" ~/.claude/skills/*/SKILL.md \
  --glob '!_archive/**' -n
```

**修復範例：**

```markdown
# B 類：更新引用
# 修復前
- See also: `old-archived-skill-name` — 相關功能
# 修復後
- See also: `new-primary-skill-name` — 相關功能

# C 類：自引用
# 修復前
- See also: `my-own-merged-skill` — 子功能描述
# 修復後
- 子功能描述（已整合至本指南）
```

**別忘了 CLAUDE.md！** 全域設定檔中也可能引用封存的 skill 名稱。

### Step 5: 最終驗證

```bash
# 確認活躍 skills 數量在目標範圍
find ~/.claude/skills -name "SKILL.md" -not -path "*/_archive/*" | wc -l
# 期望：20-50

# 確認 broken references 只出現在 Merged Skills 段落
rg "$archived_names" ~/.claude/skills/*/SKILL.md \
  --glob '!_archive/**' -n
# 每個結果都應該在 "Merged Skills (archived)" 段落內

# 確認 CLAUDE.md 無殘留引用
rg "$archived_names" ~/.claude/CLAUDE.md
# 期望：No matches found
```

## Verification

1. **數量檢查：** `find` 計數在 20-50 範圍
2. **引用完整性：** 活躍 skills 中無 broken cross-references（Merged Skills 段落除外）
3. **CLAUDE.md 檢查：** 全域設定無殘留舊引用
4. **封存完整性：** `_archive/` 中所有檔案完好保存

## Example

**實戰記錄（2026-02-08～10，和心村專案）：**

```
初始狀態：102 個 skills

Step 1 審計結果：
├─ 9 個含禁用詞（name 含 "claude"/"anthropic"）
├─ 7 個超過 500 行
└─ 93 個超過建議上限 50

Step 2 規劃：
├─ 9 個重命名（Step 1）
├─ 6 個直接封存（冗餘）
└─ 20 個合併群組（93 → 49）

Step 3 執行：
├─ 5 個 Sonnet Sub-Agents 並行合併
├─ 2 個 Agents token 耗盡 → Main Agent 接手
└─ 44 個次要 skills 移至 _archive/

Step 4 交叉引用修復：
├─ 3 個 Sub-Agents 並行（F: 7檔, G: 7檔, H: 6檔）
├─ 34 處 broken references 修復
└─ CLAUDE.md 中 2 處引用更新

最終狀態：49 個活躍 skills（-52%）
封存保留：50 個（知識完整保存）
Token 節省：~5,300 tokens/次 semantic matching
```

## Notes

### 合併群組規劃技巧

- 每組 2-5 個最合適，超過 5 個考慮拆分
- 選最完整的 skill 做主力，而非最新的
- Description 要吸收所有次要 skills 的觸發關鍵字

### Multi-Agent 注意事項

- Agent 可能 token 耗盡 → 準備 Main Agent fallback 計畫
- 檔案系統操作（mv, mkdir）由 Main Agent 執行
- 使用 mapping table 確保所有 Agents 對照一致的新舊名稱

### 維護頻率建議

| 觸發條件 | 行動 |
|---------|------|
| Skills > 50 | 啟動完整優化流程 |
| Skills > 40 | 快速審計，標記可合併候選 |
| 新增 5+ skills | 檢查有無重疊 |
| 每季度 | 輕量審計 |

### 與其他 Skills 的關係

- `skill-format-standard` — 單個 skill 的格式規範（創建）
- `skill-extractor` — 從工作中提取新 skill（Claudeception）
- 本 skill — 整個 skills 庫的批量維護與生命週期管理

## References

- [Anthropic: Complete Guide to Building Skills for Claude](https://claude.com/skills-guide) — Progressive Disclosure 架構
- [Claude Code Skills Documentation](https://docs.anthropic.com/claude/docs/skills)
