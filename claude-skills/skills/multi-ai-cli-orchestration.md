---
name: multi-ai-cli-orchestration
description: |
  用 Claude Code 當總指揮，整合 OpenAI Codex CLI + Google Gemini CLI 的多 AI 編碼工作流。
  使用時機：(1) 用戶有多個 AI 訂閱想充分利用，(2) 根據任務特性選最適合的 AI，
  (3) 並行使用三個 AI 加速開發，(4) 需要結構化辯論從多角度分析策略問題（用戶說「你們討論一下」），
  (5) 將商業洞察發展為可發表理論框架（驗證原創性、命名、學術壓力測試、多語發表）。
  包含：自動路由決策樹、benchmark 數據、四輪辯論法（提案→質疑→深度重提→整合）、
  理論開發七階段流水線（驗證→原創性調查→命名→學術壓力測試→撰寫→事實查核→發表）。
author: Washin Village + Claude Code
version: 2.1.0
date: 2026-02-10
---

# Multi-AI CLI Orchestration

## Problem

用戶同時擁有多個 AI 訂閱（Claude Max、ChatGPT Pro、Google AI Ultra），
但只在 Claude Code 裡工作，無法有效利用其他 AI 的額度和能力。
每個 AI 都有獨特優勢，但缺乏統一的調度方式。

**v2.0 新增：** Claude Code 自動判斷任務特性，不需要用戶指定用哪個 AI。

## Context / Trigger Conditions

當你遇到以下情況時使用此模式：

1. **多訂閱用戶**：同時有 Claude、OpenAI、Google 的付費方案
2. **任務多樣性**：不同任務適合不同 AI（推理 vs 批量 vs 多模態）
3. **額度優化**：想充分利用每個平台的額度，不浪費
4. **並行需求**：想同時讓多個 AI 幫忙加速

---

## Part 1：三大 AI 完整模型清單（2026-02 最新）

### Anthropic Claude 模型家族

| 模型 | API ID | Context | 最大輸出 | 價格 ($/M tokens) | 特色 |
|------|--------|---------|---------|-----------------|------|
| **Opus 4.6** ⭐ | `claude-opus-4-6` | 200K / 1M(beta) | 128K | $5 / $25 | 最強推理+編碼，支持 adaptive thinking |
| **Sonnet 4.5** | `claude-sonnet-4-5` | 200K / 1M(beta) | 64K | $3 / $15 | 速度與智慧最佳平衡 |
| **Haiku 4.5** | `claude-haiku-4-5` | 200K | 64K | $1 / $5 | 最快速，近前沿智慧 |
| Opus 4.5 (legacy) | `claude-opus-4-5` | 200K | 64K | $5 / $25 | 上一代旗艦 |
| Sonnet 4 (legacy) | `claude-sonnet-4-0` | 200K / 1M(beta) | 64K | $3 / $15 | |
| Haiku 3 (legacy) | `claude-3-haiku-20240307` | 200K | 4K | $0.25 / $1.25 | 最便宜 |

**Claude 獨特能力：**
- Extended Thinking（深度思考模式）：所有 4.x 模型支持
- Adaptive Thinking（自適應思考）：只有 Opus 4.6 支持
- 1M context window beta：Opus 4.6 + Sonnet 4.5 支持
- Batch API 50% 折扣
- Prompt Caching 最多省 90%

### OpenAI GPT / Codex 模型家族

| 模型 | 用途 | Context | 價格 ($/M tokens) | 特色 |
|------|------|---------|-----------------|------|
| **GPT-5.2** ⭐ | 最新旗艦 | ~128K | ~$2 / $10 | 數學推理 100% AIME |
| **GPT-5.2-Codex** | Codex CLI 專用 | ~128K | 含在 Pro 方案 | 專為 agentic coding 優化 |
| **GPT-5** | 上一代旗艦 | ~128K | $1.25 / $10 | |
| GPT-5-mini | 輕量版 | ~128K | 較便宜 | |
| GPT-4.1 | 穩定版 | 128K | ~$2 / $8 | |
| GPT-4.1 mini | 輕量穩定 | 128K | 更便宜 | |
| **o3** | 推理模型 | - | ~$10/M | 深度推理 |
| o4-mini | 輕量推理 | - | ~$5/M | |

**OpenAI 獨特能力：**
- Codex Cloud Agent：可在雲端背景跑長時間任務（1-30 分鐘）
- GitHub Actions 原生整合
- `codex exec` 非互動模式 + `--full-auto` 全自動
- GPT-5.2-Codex 專門訓練於真實 SWE 任務

### Google Gemini 模型家族

| 模型 | API ID | Context | 價格 ($/M tokens) | 特色 |
|------|--------|---------|-----------------|------|
| **Gemini 3 Pro** ⭐ | `gemini-3-pro-preview` | 1M in / 65K out | $2 / $12 | 世界最強多模態理解 |
| **Gemini 3 Flash** | `gemini-3-flash-preview` | 1M in / 65K out | 較便宜 | 速度+規模+前沿智慧 |
| **Gemini 2.5 Pro** | `gemini-2.5-pro` | 1M in / 65K out | $1.25 / $10 | 複雜代碼+數學+STEM |
| **Gemini 2.5 Flash** | `gemini-2.5-flash` | 1M in / 65K out | ~$0.15 / $0.60 | 最佳性價比 |
| Gemini 2.5 Flash-Lite | `gemini-2.5-flash-lite` | 1M in / 65K out | $0.10 / $0.40 | 最便宜 |

**Gemini 獨特能力：**
- **1M token context window**：原生支持（不是 beta）
- **多模態輸入**：文字 + 圖片 + 影片 + 音訊 + PDF
- **Google Search Grounding**：搜尋整合
- **超大免費額度**：1000 req/day（個人帳號）
- 200K 以下 context 價格正常，超過 200K 價格 x2

---

## Part 2：Benchmark 戰力對照（2026-02）

### SWE-bench Verified（真實軟體工程任務）

| 排名 | 模型 | 分數 | 備註 |
|------|------|------|------|
| 1 | Claude Opus 4.5 | 74.6% - 80.9% | 不同測試環境有差異 |
| 2 | GPT-5.2 | 75.4% - 80.0% | SWE-bench Pro 56.4% 最強 |
| 3 | Gemini 3 Flash | 76.2% | 效率最高（代碼最精簡） |
| 4 | Gemini 2.5 Pro | 63.8% | 上一代 |

### CLI 工具實戰對比

| 指標 | Claude Code | Codex CLI | Gemini CLI |
|------|------------|-----------|------------|
| **完成速度** | 1 小時 17 分 ⚡ | 中等 | 2 小時 2 分 |
| **代碼生成速度** | 1200 行/5 分鐘 | ~200 行/10 分鐘 | 中等 |
| **自主性** | 全自主 ✅ | 全自主 ✅ | 需要手動引導 ⚠️ |
| **代碼品質** | 高（但較冗長） | 中等 | 高（最精簡） |
| **Terminal Bench** | 第 3 名 | 第 19 名 | 中等 |
| **Context Window** | 200K / 1M beta | ~192K | 1M 原生 ✅ |
| **免費使用** | ❌ 需訂閱 | ❌ 需 Pro | ✅ 1000 req/day |

### 代碼品質特性

| 特性 | Claude | Codex | Gemini |
|------|--------|-------|--------|
| **Pass Rate** | 83.62% 最高 | 中等 | 81.72% |
| **代碼冗長度** | 高（639K 行） | 中等 | 低（最精簡）⭐ |
| **認知複雜度** | 高 | 中 | 低 ⭐ |
| **特色** | 什麼都能做，品質最穩 | GitHub 整合最好 | 精簡又正確 |

---

## Part 3：🧠 自動路由決策樹（Claude Code 內建規則）

**Claude Code 看到任務時，自動按以下邏輯分配：**

```
收到任務
    │
    ├─ 需要「深度推理」？（架構設計、複雜 bug、安全審查）
    │   └─ → Claude 自己做（Opus 4.6 extended thinking）
    │
    ├─ 需要「看圖片/影片/PDF」？
    │   └─ → 派 Gemini（1M context + 原生多模態）
    │       └─ 少量？gemini -p
    │       └─ 大量？gemini -m gemini-2.5-flash -p（便宜）
    │
    ├─ 需要「大規模代碼修改」？（重構、遷移、批量修正）
    │   └─ → 派 Codex（codex exec --full-auto，雲端自主跑）
    │
    ├─ 需要「搜尋最新資訊」？
    │   └─ → 派 Gemini（Google Search Grounding）
    │
    ├─ 需要「讀超大 codebase」？（> 200K tokens）
    │   └─ → 派 Gemini（1M context 原生支持，不用 beta）
    │
    ├─ 需要「Code Review」？
    │   └─ → 三個都跑，整合意見（三重保險）
    │
    ├─ 需要「快速原型」？
    │   └─ → 派 Codex（一次生成完整方案）
    │
    ├─ 需要「精簡代碼」？（低複雜度、好維護）
    │   └─ → 派 Gemini（它寫的代碼最精簡）
    │
    ├─ 需要「CI/CD 整合」？
    │   └─ → 派 Codex（GitHub Actions 原生整合）
    │
    └─ 一般任務？
        └─ → Claude 自己做（最穩定、最可靠）
```

### 特性 → AI 對照表（Claude Code 自動參考）

| 任務特性 | 首選 | 備選 | 原因 |
|---------|------|------|------|
| 🧠 深度推理/規劃 | **Claude** | - | Opus 4.6 adaptive thinking 無敵 |
| 🏗️ 架構設計 | **Claude** | - | 穩定、可靠、不出錯 |
| 🔒 安全審查 | **Claude** | - | 推理能力最可信賴 |
| 🐛 複雜 Debug | **三個並行** | Claude 為主 | 三個方向同時查 |
| 📦 大規模重構 | **Codex** | Claude | 雲端 agent 跑 1-30 分鐘 |
| 🔄 批量修正 | **Codex** | Gemini | --full-auto 全自動 |
| 🖼️ 圖片分析 | **Gemini** | Claude | 多模態+便宜 |
| 🎬 影片分析 | **Gemini** | - | 只有 Gemini 原生支持 |
| 📄 PDF 分析 | **Gemini** | Claude | 原生 PDF 支持+1M context |
| 📚 讀大型 codebase | **Gemini** | Claude(1M beta) | 1M context 原生 |
| 🔍 搜尋最新資訊 | **Gemini** | Claude | Google Search Grounding |
| ✨ 精簡代碼 | **Gemini** | - | 它寫的代碼最精簡 |
| 🚀 快速原型 | **Codex** | Claude | 一次完整生成 |
| 🔗 GitHub CI/CD | **Codex** | - | GitHub Actions 原生整合 |
| 📝 Code Review | **三個輪流** | - | 不同視角抓不同 bug |
| 📖 文件生成 | **Gemini** | Claude | 免費額度大、長文生成佳 |
| 💰 省成本任務 | **Gemini** | - | Flash-Lite $0.10/M 最便宜 |
| ⚡ 需要最快速度 | **Claude** | - | 1200 行/5 分鐘 |

### 具體模型選擇（進階路由）

```
需要便宜？
├─ 超便宜 → Gemini 2.5 Flash-Lite ($0.10/M)
├─ 便宜+品質 → Gemini 2.5 Flash ($0.15/M)
├─ Claude 便宜 → Haiku 4.5 ($1/M)
└─ 批量折扣 → Claude Batch API (-50%) 或 Prompt Caching (-90%)

需要最強？
├─ 推理+編碼 → Claude Opus 4.6
├─ 數學推理 → GPT-5.2（AIME 100%）
├─ 多模態理解 → Gemini 3 Pro
└─ 長文理解 → Gemini 2.5 Pro（1M native）

需要最快？
├─ 極速回覆 → Claude Haiku 4.5
├─ 快+便宜 → Gemini 2.5 Flash-Lite
└─ 快+品質 → Claude Sonnet 4.5
```

---

## Part 4：安裝與使用

### CLI 工具安裝

```bash
# Claude Code - 通常已安裝
# 確認: claude --version

# OpenAI Codex CLI
brew install --cask codex
# 或: npm install -g @openai/codex
# 第一次執行 `codex` 會要求登入 ChatGPT 帳號

# Google Gemini CLI
brew install gemini-cli
# 或: npm install -g @google/gemini-cli
# 用 Google 帳號登入，免費額度: 60 req/min, 1000 req/day
```

### 非互動模式命令（關鍵！）

| CLI | 互動模式 | 腳本模式（非互動） | 輸出格式 |
|-----|---------|------------------|---------|
| **Claude Code** | `claude` | `claude -p "指令"` | 純文字 |
| **Codex CLI** | `codex` | `codex exec "指令" --json` | JSON events |
| **Gemini CLI** | `gemini` | `gemini -p "指令" --output-format json` | JSON |

#### Codex CLI 腳本模式
```bash
# 基本用法
codex exec "修復所有 ESLint 錯誤" --full-auto

# 帶 JSON 輸出 + 儲存結果
codex exec "重構 src/utils.ts" --json --output-last-message result.txt

# 指定工作目錄
codex exec "跑所有測試" --cd /path/to/project

# 恢復之前的任務
codex exec resume [SESSION_ID]

# 安全等級控制
codex exec "修改代碼" --sandbox workspace-write  # 預設：只能寫工作區
codex exec "分析代碼" --sandbox read-only         # 只讀（最安全）
```

#### Gemini CLI 腳本模式
```bash
# 基本用法
gemini -p "解釋這個 codebase 的架構"

# JSON 輸出
gemini -p "分析效能瓶頸" --output-format json

# 指定便宜模型
gemini -m gemini-2.5-flash -p "快速回答這個問題"

# 指定最強模型
gemini -m gemini-3-pro-preview -p "深度分析這段代碼"

# 串流輸出（適合長任務）
gemini -p "跑測試並部署" --output-format stream-json

# 包含多個目錄（讀大型 codebase）
gemini --include-directories ../lib,../docs -p "分析跨模組依賴"
```

### Claude Code 自動調度（推薦方式）

用戶只需要跟 Claude Code 說話，Claude Code 自動判斷：

```
用戶說：「幫我看這 50 張貓的照片」
Claude Code 自動：gemini -p "分析這些圖片..." --output-format json

用戶說：「幫我把整個 src/ 重構」
Claude Code 自動：codex exec "重構 src/ 目錄..." --full-auto

用戶說：「這個架構安全嗎？」
Claude Code 自動：自己分析（Opus 4.6 最可靠）

用戶說：「幫我查這個 bug」
Claude Code 自動：三個一起查，整合結果
```

---

## Part 5：成本優化策略

### 價格對照表

| 操作 | Claude (Opus 4.6) | OpenAI (GPT-5) | Gemini (2.5 Flash) | 最便宜 |
|------|-------------------|----------------|-------------------|--------|
| 100K input | $0.50 | $0.125 | $0.015 | Gemini ⭐ |
| 10K output | $0.25 | $0.10 | $0.006 | Gemini ⭐ |
| 典型對話 | ~$0.75 | ~$0.225 | ~$0.021 | Gemini ⭐ |

### 智能成本策略

```
高價值任務（用最強的）：
├─ 架構決策 → Claude Opus 4.6（值得花錢）
├─ 安全審查 → Claude Opus 4.6（不能出錯）
└─ 複雜 Debug → Claude + Codex + Gemini（三重保險）

中價值任務（用平衡的）：
├─ 日常開發 → Claude Sonnet 4.5（速度+品質）
├─ Code Review → 輪流用三個
└─ 文件生成 → Gemini 2.5 Pro

低價值/大量任務（用最便宜的）：
├─ 批量分析 → Gemini 2.5 Flash-Lite ($0.10/M)
├─ 圖片分類 → Gemini 2.5 Flash
├─ 簡單問答 → Claude Haiku 4.5 ($1/M)
└─ Batch 處理 → Claude Batch API (-50%)
```

---

## Verification

安裝後驗證三個 CLI 都能工作：

```bash
# 測試 Claude Code
claude -p "說 hello" && echo "✅ Claude OK"

# 測試 Codex CLI
codex exec "echo hello" && echo "✅ Codex OK"

# 測試 Gemini CLI
gemini -p "說 hello" && echo "✅ Gemini OK"
```

## Notes

- **Codex CLI 的 `--full-auto` 模式**會自動讀寫檔案，注意安全性
- **Gemini CLI 免費額度**：60 req/min, 1000 req/day（個人 Google 帳號）
- **Gemini 3 Pro Preview 是付費限定**，沒有免費額度
- **Benchmark 分數會變動**：不同測試環境的分數有差異，以趨勢為準
- **CLI 工具快速演進**：2025-2026 年三家 CLI 工具更新頻繁，定期檢查最新版本
- **Claude Code 是最穩定的 CLI**：自主性最高、速度最快、不需手動引導
- **Gemini CLI 需要較多引導**：複雜任務時可能需要手動介入
- **Codex CLI Terminal Bench 較低**：但雲端 agent 模式是獨特優勢
- 相關 skill：`multi-agent-workflow-design`（API 層面的成本優化）
- 相關 skill：`multi-agent-workflow-design`（Claude 內部多 agent 設計）

## References

- [OpenAI Codex CLI GitHub](https://github.com/openai/codex)
- [Codex CLI exec 命令參考](https://developers.openai.com/codex/cli/reference/)
- [Google Gemini CLI GitHub](https://github.com/google-gemini/gemini-cli)
- [Gemini CLI 官方文檔](https://developers.google.com/gemini-code-assist/docs/gemini-cli)
- [Claude Models Overview](https://platform.claude.com/docs/en/about-claude/models/overview)
- [Gemini Models](https://ai.google.dev/gemini-api/docs/models)
- [Claude Code vs Codex vs Gemini CLI - Educative](https://www.educative.io/blog/claude-code-vs-codex-vs-gemini-code-assist)
- [Claude Opus 4.5 vs GPT-5.2 vs Gemini 3 - Composio](https://composio.dev/blog/claude-4-5-opus-vs-gemini-3-pro-vs-gpt-5-codex-max-the-sota-coding-model)
- [SWE-bench Leaderboard](https://llm-stats.com/benchmarks/swe-bench-verified)
- [Sonar Code Quality Report](https://www.sonarsource.com/blog/new-data-on-code-quality-gpt-5-2-high-opus-4-5-gemini-3-and-more/)
- [AI Dev Tool Power Rankings 2026](https://blog.logrocket.com/ai-dev-tool-power-rankings/)

---

## Merged Skills (archived)

The following skills have been merged into this guide:

- **multi-ai-structured-debate** — 結構化辯論法（四輪迭代：提案→質疑→用戶反饋→深度重提），從膚淺共識推進到深度洞察
- **multi-ai-theory-development-pipeline** — 理論開發七階段流水線（驗證→原創性調查→命名→學術壓力測試→撰寫→事實查核→多語發表），將商業洞察升級為可發表理論
