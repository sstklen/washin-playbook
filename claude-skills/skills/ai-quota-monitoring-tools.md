---
name: ai-quota-monitoring-tools
description: |
  三家 AI 訂閱（Claude Max + ChatGPT Pro + Google AI Ultra）的額度監控工具與實測數據。
  使用時機：(1) 想查看各 AI 服務的用量，(2) 需要判斷額度分配是否合理，
  (3) 需要安裝或使用 splitrail / ccusage，(4) 規劃每日 AI 額度使用策略。
  包含真實用量數據（2026 年 2 月）和各服務的配額機制說明。
version: 1.0.0
date: 2026-02-08
---

# AI 額度監控工具

## Problem

某開發者每月花較高金額在三家 AI 訂閱上，但無法一目了然地看到各家用量。
之前的「笨方法」是同時開三個視窗看額度頁面。

## Context / Trigger Conditions

- 想查看 Claude Code / Codex CLI / Gemini CLI 的用量
- 需要判斷哪家 AI 用太多或太少
- 規劃 AI 額度分配策略

## 監控工具

### 1. splitrail（一次看三家）

| 項目 | 詳情 |
|------|------|
| **位置** | `/opt/homebrew/bin/splitrail` |
| **版本** | v3.3.2 |
| **GitHub** | `Piebald-AI/splitrail`（102 stars） |
| **支援** | Claude Code + Codex CLI + Gemini CLI |

```bash
# 基本用法（TUI 介面）
splitrail

# JSON 輸出（自動化用）
splitrail --json

# MCP Server 模式
splitrail mcp
```

### 2. ccusage（Claude 專用詳細分析）

| 項目 | 詳情 |
|------|------|
| **用法** | `npx ccusage@latest` |
| **GitHub** | 10,413 stars |
| **功能** | 按天/專案/模型的詳細 token 用量 |

```bash
# 基本用法
npx ccusage@latest

# 指定日期範圍
npx ccusage@latest --from 2026-02-01 --to 2026-02-07
```

## 實測數據（2026 年 2 月 1-7 日）

| AI 服務 | 月費 | 本月已用（API 換算） | 用量評估 |
|---------|------|-------------------|---------|
| **Claude Code** | $100 | $605 | 用很兇（省了 $505） |
| **Codex CLI** | $200 | $2 | 幾乎沒動 |
| **Gemini CLI** | $250 | $1 | 幾乎沒動 |
| **合計** | **~$500+/month** | — | Codex + Gemini 浪費中 |

**關鍵發現：Codex + Gemini subscription 額度在空轉。**

## 各服務配額機制

### Claude Max ($100/月)

- 5 小時滾動窗口，約 225 則訊息
- claude.ai + Claude Code + Desktop **共用**同一個池
- 超限會降速，不會完全停用
- 配額不透明，Anthropic 不公布精確數字

### ChatGPT Pro ($200/月)

- 設計為「幾乎不會碰到限制」
- 5 小時窗口，Pro 約 180-900 則（本地+雲端共用）
- 配額不透明，OpenAI 不公布精確數字

### Google AI Ultra ($250/月)

- 官方文件說 2000 次/天
- 但用戶反映 2-3 小時就會耗盡
- 有每分鐘速率限制（RPM）
- 實際可用量遠低於官方數字

**重要：三家是各自獨立的額度池，互不影響。**

## Verification

```bash
# 驗證 splitrail 運作
splitrail --json | head -20

# 驗證 ccusage 運作
npx ccusage@latest --from $(date -v-7d +%Y-%m-%d) --to $(date +%Y-%m-%d)
```

## Notes

- splitrail 需要各 CLI 工具的認證已設定好（Claude Code 登入、Codex 登入等）
- ccusage 讀取本地 `~/.claude/` 目錄的日誌，不需要 API key
- 建議每週至少查看一次用量，避免浪費
- 離峰時段（06:00、23:00）使用不會影響白天工作配額
