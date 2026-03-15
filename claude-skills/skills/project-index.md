---
name: project-index
description: |
  自動生成專案索引（PROJECT_INDEX.json），讓 AI 找檔案從 5 分鐘降到 2 秒。
  掃描專案結構、關鍵檔案、統計資訊，產出結構化 JSON 索引。
  使用時機：
  1. 新專案開工，需要快速建立 AI 可讀的檔案地圖
  2. 專案太大，AI 反覆搜尋浪費時間和 context
  3. 團隊成員需要快速了解專案結構
  4. CLAUDE.md 中缺少檔案導覽資訊
  5. 需要更新過期的專案索引（新增/刪除檔案後）
  觸發信號：AI 多次用 Glob/Grep 找同一類檔案、
  「這個專案有哪些檔案」「專案結構是什麼」、
  新 clone 的 repo 缺少文檔。
  產出：PROJECT_INDEX.json（含 structure、key files、stats）。
argument-hint: [--quick|--full|update]
version: 1.0.0
date: 2026-02-10
---

# Project Index 🔍

> Auto-generate project index — AI finds files instantly, no more digging around.

## Quick Reference

### Commands

| Command | What It Does |
|---------|--------------|
| `/index` | Generate/update index |
| `/index --quick` | Quick scan (main files only) |
| `/index --full` | Full scan (includes functions, classes) |
| "Update project index" | Natural language trigger |

### Generated Output

Creates `PROJECT_INDEX.json` at project root:

```json
{
  "project": "my-project",
  "generated": "2026-01-30T12:00:00Z",
  "structure": {
    "source": ["src/**/*.ts"],
    "tests": ["tests/**/*.test.ts"],
    "docs": ["docs/**/*.md"]
  },
  "key_files": {
    "entry_point": "src/index.ts",
    "config": ["package.json", "tsconfig.json"]
  },
  "stats": {
    "total_files": 150,
    "by_type": { ".ts": 45, ".tsx": 30 }
  }
}
```

## How It Works

1. **Scan** — Find all files (exclude .git, node_modules)
2. **Categorize** — Group by location and extension
3. **Identify** — Detect entry points, configs, key files
4. **Generate** — Write PROJECT_INDEX.json

## After Index Generated

AI can instantly answer:
- "Find files related to [keyword]"
- "Show all test files"
- "What was modified recently?"
- "Open the spec document"

## Additional Resources

- For index structure details, see [references/index-structure.md](references/index-structure.md)
- For categorization rules, see [references/categorization.md](references/categorization.md)

## Related Skills

- **agentic-coding-complete** — Foundation (environment tools + development principles)
- **auto-tidy** — Calls `/index` after cleanup

---

*Part of 🥋 AI Dojo Series by [Washin Village](https://washinmura.jp) 🐾*
