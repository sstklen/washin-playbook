---
name: skill-format-standard
description: |
  Claude Code Skills 官方格式規範 + 完整創建工作流。使用時機：(1) 創建新的 Claude Code Skill，
  (2) 重構現有 skill 為官方格式，(3) 提交 skill 到 awesome-claude-skills，
  (4) 發現可重用知識想封裝為 skill，(5) 需要 step-by-step skill 創建流程，
  (6) 需要品質檢查 gates 和常見模式。
  包含 YAML frontmatter 必填欄位、目錄結構、references/ 引用方式、創建工作流。
author: Claude Code
version: 1.0.0
date: 2026-01-30
---

# Claude Code Skill 官方格式規範

## Problem

創建的 Skill 無法被 Claude Code 正確載入，或提交到社群清單時被拒絕。
常見錯誤：`No valid skills found. Skills require a SKILL.md with name and description.`

## Context / Trigger Conditions

- 創建新的 Claude Code Skill
- 重構 `*.skill.md` 單檔為目錄結構
- 提交 PR 到 awesome-claude-skills
- 看到錯誤 "No valid skills found"

## Solution

### 1. 必須使用 YAML Frontmatter

```yaml
---
name: skill-name              # 必填！kebab-case
description: |                # 必填！語義描述，用於搜尋匹配
  詳細描述 skill 的用途、觸發條件、解決什麼問題。
  包含關鍵字讓 semantic matching 能找到這個 skill。
argument-hint: [arg1|arg2]    # 選填：參數提示
---
```

### 2. 目錄結構

```
skill-name/
├── SKILL.md          ← 主檔案（必須叫這個名字！）
├── references/       ← 詳細參考內容
│   ├── topic-a.md
│   └── topic-b.md
└── examples/         ← 範例檔案
    └── example.md
```

### 3. 引用 references（重要！）

SKILL.md 必須用 markdown 連結引用 references，否則不會被載入：

```markdown
## Additional Resources

- For details, see [references/topic-a.md](references/topic-a.md)
- For examples, see [examples/example.md](examples/example.md)
```

### 4. SKILL.md 保持精簡

- 主檔案控制在 500 行以內
- 詳細內容放到 references/
- 範例放到 examples/

## Verification

```bash
# 確認結構正確
ls skill-name/SKILL.md && head -20 skill-name/SKILL.md

# 確認有 YAML frontmatter
grep -A5 "^---" skill-name/SKILL.md | head -10
```

## Example

見 [references/example-structure.md](references/example-structure.md)

## Notes

- 檔名必須是 `SKILL.md`，不是 `skill-name.skill.md`
- `name` 欄位使用 kebab-case
- `description` 要包含足夠的關鍵字讓 semantic matching 能找到
- 舊格式 `*.skill.md` 單檔需要遷移到目錄結構

## References

- Claude Code Skills 官方文檔
- awesome-claude-skills 提交指南

## Merged Skills (archived)

The following skills have been merged into this guide:
- **skill-creation-workflow** — 完整的 skill 創建工作流程（step-by-step、品質 gates、常見模式）
