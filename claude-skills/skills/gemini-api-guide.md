---
name: gemini-api-guide
description: |
  Google Gemini API 完整指南 — 涵蓋 SDK 遷移、錯誤排解、影片分析實戰。
  使用時機：
  1. 遇到 `404 model not found` 錯誤 — 模型名稱已更新（用 gemini-2.0-flash 不是 -exp）
  2. SDK 遷移痛點：從 `google.generativeai` 遷移到 `google.genai`（新 SDK）
  3. Unicode 路徑導致 API 呼叫失敗 — 日文/中文檔名需要 `urllib.parse.quote()` 編碼
  4. 影片多幀分析 — FFmpeg 提取關鍵幀 + Gemini multimodal 輸入
  5. 選擇 Gemini vs Claude 的決策：多模態（影片/PDF/圖片）選 Gemini、深度推理選 Claude
  觸發條件與症狀：
  - `google.generativeai` 的 import 報錯或功能缺失（需遷移到 google.genai）
  - API 回傳 404、400 錯誤（模型名稱過期或參數格式變更）
  - 含非 ASCII 字元的檔案路徑導致上傳失敗
  - 需要分析影片內容但不知道如何提取幀送入 API
  工具：Google Gemini API、google-genai SDK、FFmpeg、Python
  整合原有 3 個 Gemini skills（unicode-fix、sdk-migration、video-analysis）為一體。
version: 2.0.0
date: 2026-02-02
---

# Gemini API Guide

## Quick Reference

| 問題 | 解法 | 詳細 |
|------|------|------|
| 404 模型找不到 | `gemini-2.0-flash` (不是 `-exp`) | [sdk-migration](references/sdk-migration.md) |
| Unicode 路徑錯誤 | 用 `urllib.parse.quote()` | [unicode-fix](references/unicode-fix.md) |
| SDK 遷移 | `google.genai` (不是 `google.generativeai`) | [sdk-migration](references/sdk-migration.md) |
| 影片分析 | FFmpeg 提取 + multimodal 輸入 | [video-analysis](references/video-analysis.md) |

## References

- [unicode-fix.md](references/unicode-fix.md)
- [sdk-migration.md](references/sdk-migration.md)
- [video-analysis.md](references/video-analysis.md)
