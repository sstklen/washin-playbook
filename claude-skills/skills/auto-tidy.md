---
name: auto-tidy
description: |
  零操作專案檔案整理工具。說「晚安」就自動整理你的專案。
  使用時機：
  1. 結束工作時說「goodnight」「晚安」「88」— 自動輕度清理 + 道別
  2. 中途說「save」「存檔」— 輕度清理 + 進度摘要
  3. 說「tidy up」或 `/tidy --full` — 深度完整整理
  觸發條件與症狀：
  - 專案根目錄出現 .pyc、.DS_Store、__pycache__、node_modules 等垃圾檔案
  - 檔案放錯資料夾（如程式碼放在 docs/、文檔放在 src/）
  - INDEX.md 或 CLAUDE.md 過時，需要更新
  - Session 結束前想確保專案狀態乾淨
  功能：清理垃圾檔案、更新索引、移動錯放檔案、偵測重複檔案（deep 模式）
argument-hint: [--light|--full|goodnight|save]
version: 1.0.0
date: 2026-02-10
---

# Auto-Tidy 🧹

> Zero-effort file organization — Say "goodnight" and your project gets organized automatically.

## Quick Reference

### Triggers

| Action | What Happens |
|--------|--------------|
| "Goodnight!" / "晚安" / "88" | ⚡ Light cleanup + goodbye |
| "Save" / "存檔" | ⚡ Light cleanup + progress summary |
| "Tidy up" | ⚡ Light cleanup |
| `/tidy --full` | 🔍 Deep cleanup |

### Light vs Deep

| | ⚡ Light | 🔍 Deep |
|---|---------|---------|
| **Time** | < 30 seconds | 1-5 minutes |
| Clean garbage | ✅ | ✅ |
| Update index | ✅ | ✅ |
| Move files | ❌ | ✅ |
| Detect duplicates | ❌ | ✅ |

## Safety Rules

- ❌ Never auto-deletes non-temporary files
- ❌ Never touches `.git`, `node_modules`
- ❌ Never moves files being edited
- ✅ Always asks before moving files
- ✅ Always logs operations for undo

## Standard Structure

Auto-Tidy organizes into this structure:

```
project/
├── 00-research/          # 📚 Research
├── 01-knowledge/         # 🧠 Knowledge base
├── 02-ideation/          # 💡 Ideas & drafts
├── 03-specs/             # 📋 Specifications
├── src/                  # 💻 Source code
├── tests/                # 🧪 Tests
├── docs/                 # 📖 Documentation
├── _archive/             # 📦 Archived
├── _temp/                # 🗑️ Temporary
└── CLAUDE.md             # 📍 Project memory
```

## Additional Resources

- For cleanup rules, see [references/cleanup-rules.md](references/cleanup-rules.md)
- For trigger phrases, see [references/triggers.md](references/triggers.md)

## Related Skills

- **agentic-coding-complete** — Foundation (environment tools + development principles)
- **project-index** — Auto-generate project index

---

*Part of 🥋 AI Dojo Series by [Washin Village](https://washinmura.jp) 🐾*
