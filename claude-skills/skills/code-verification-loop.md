---
name: code-verification-loop
description: |
  實施 Claude Code 驗證迴圈，Boris Cherny（創始人）強調的最重要技巧。
  使用時機：(1) 設定新專案的自動化測試，(2) 想要提升 2-3x 代碼品質，
  (3) Claude 修改代碼但無法自動驗證結果，(4) 需要建立持續反饋機制。
  核心概念：給 Claude 自動驗證工作的能力，形成持續改進迴圈。
author: Boris Cherny (Claude Code Team)
version: 1.1.0
date: 2026-02-10
---

# Claude Code 驗證迴圈

> "Probably the most important thing to get great results...
> give Claude a way to verify its work. If Claude has that feedback loop,
> it will **2-3x the quality** of the final result."
>
> -- Boris Cherny, Creator of Claude Code

---

## 問題

**Claude 寫代碼很快，但品質不穩定：**
- 有時一次到位
- 有時需要多次修正
- 難以確保所有邊界情況都處理
- 人工驗證耗時且容易遺漏

---

## Context / Trigger Conditions

**何時需要驗證迴圈：**

1. **專案初期設定** -- 新專案、建立品質標準、想要自動化驗證
2. **品質問題** -- 輸出不穩定、經常多次修正、遺漏邊界情況
3. **團隊協作** -- 多人使用 Claude Code、統一品質標準、可重複流程
4. **生產環境** -- 部署到生產、高可靠性需求、不能容忍錯誤

---

## 核心概念

### 什麼是驗證迴圈？

```
寫代碼 → 自動測試 → 看結果 → 修正 → 再測試
   ↑                                      ↓
   └──────────────────────────────────────┘
              持續迴圈直到通過
```

**關鍵特點：**
1. **自動化** - 不需人工確認
2. **即時反饋** - 立即知道結果
3. **持續迭代** - 失敗就繼續改
4. **明確標準** - 通過就是通過

---

## Solution

### 階段 1：識別驗證方式（按領域）

| 領域 | 驗證方式 | 工具 |
|------|---------|------|
| **前端** | 瀏覽器自動測試 | Playwright, Cypress |
| **後端** | 單元測試 + 整合測試 | Jest, Vitest, pytest |
| **API** | HTTP 請求測試 | curl, supertest |
| **腳本** | Bash 驗證 | test, assert |
| **全端** | CI/CD pipeline | GitHub Actions |
| **Worker** | 本地測試腳本 | 自定義腳本 |

### 階段 2：設定自動化測試

<!-- 詳細範例（Cloudflare Worker、Next.js、Python API）已拆到 references -->
詳見 [references/test-script-examples.md](references/test-script-examples.md)

**快速摘要：**
- **Cloudflare Worker** -- 用 bash + curl 測試健康檢查與訊息處理
- **Next.js** -- 用 vitest + playwright，設定 80% 覆蓋率門檻
- **Python API** -- 用 pytest + FastAPI TestClient

### 階段 3：整合到工作流

<!-- 詳細配置（Pre-commit Hook、CI/CD、CLAUDE.md 設定、對話用法）已拆到 references -->
詳見 [references/workflow-integration.md](references/workflow-integration.md)

**三種整合方式：**
- **方法 A：Pre-commit Hook** -- commit 前自動跑測試
- **方法 B：CI/CD Pipeline** -- push/PR 時 GitHub Actions 驗證
- **方法 C：CLAUDE.md 指令** -- 告訴 Claude 何時執行什麼驗證

### 階段 4：與 Claude 對話時使用

**基礎用法：** 在 prompt 中明確要求驗證

```
「修這個 Bug，並執行 ./test-worker.sh 驗證。
測試通過才能說完成。」
```

**進階用法：** 指定驗證標準 + 迭代要求

```
「修這個 Bug。
驗證標準：
1. 執行 ./test-worker.sh，所有測試通過
2. 不能引入新的失敗
3. 響應時間 <2 秒
失敗就繼續修，直到通過。」
```

---

## Verification

### 如何確認驗證迴圈有效？

**1. 觀察 Claude 的行為改變：**

| 狀態 | 行為 |
|------|------|
| Before（無驗證） | 寫代碼 → 說「完成」→ 可能有問題但不知道 |
| After（有驗證） | 寫代碼 → 自動測試 → 失敗則修正 → 通過才說「完成」 |

**2. 量化指標：**

| 指標 | 無驗證 | 有驗證 | 改善 |
|------|--------|--------|------|
| 一次成功率 | ~50% | ~85% | +70% |
| 平均修正次數 | 3-4 次 | 1-2 次 | -50% |
| Bug 遺漏率 | 高 | 低 | -70% |
| 整體品質 | 基準 | **2-3x** | +200% |

**3. 實際測試：** 故意引入錯誤，確認 Claude 能自動發現並修復。

---

## Example

### 完整範例：Telegram Bot 驗證迴圈

<!-- 完整端到端範例（測試腳本 + hook + 對話示範）已拆到 references -->
詳見 [references/telegram-bot-example.md](references/telegram-bot-example.md)

**範例涵蓋：**
1. 創建測試腳本（簡單訊息、複雜分析、錯誤處理三個測試）
2. Pre-commit hook 偵測 worker.js 變更自動觸發
3. Claude 對話中的實際使用流程展示

---

## Notes

### 關鍵成功因素

| 因素 | 正確做法 | 錯誤做法 |
|------|---------|---------|
| **自動化** | 自動驗證：快、可重複、可靠 | 人工驗證：慢、容易遺漏 |
| **全面性** | 測正常 + 邊界 + 錯誤 + 性能 + 安全 | 只測正常情況 |
| **即時反饋** | 寫完立即測試 | 等一天才發現問題 |
| **明確標準** | 「響應時間 <2 秒」 | 「要快」 |

### 常見問題

**Q: 設定測試很費時間？**
A: 初期投入，但之後每次修改都自動驗證。2-3x 品質提升值得投資。

**Q: 專案沒有測試框架？**
A: 從簡單的 bash 腳本開始：`curl -s http://localhost:3000/health | grep "OK"`

**Q: Claude 會自動執行測試嗎？**
A: 需要明確告訴它：「修改後執行 ./test.sh 驗證，測試通過才能說完成。」

**Q: 如何處理測試失敗？**
A: 讓 Claude 進入迭代迴圈：分析錯誤 → 修正 → 再驗證 → 重複直到通過。

### 進階技巧

<!-- 詳細配置與範例（分層驗證、覆蓋率、性能回歸、視覺回歸、整合其他技巧）已拆到 references -->
詳見 [references/advanced-techniques.md](references/advanced-techniques.md)

**摘要：**
- **分層驗證** -- 快速測試（每次改）、完整測試（PR 前）、E2E（部署前）
- **覆蓋率要求** -- lines/functions 80%、branches 75%
- **性能回歸** -- 基準值比對，超過 20% 即失敗
- **視覺回歸** -- Playwright screenshot 比對
- **整合其他技巧** -- 配合並行工作流、Plan Mode、CLAUDE.md

---

## 實施檢查清單

### 初期設定
- [ ] 識別專案的驗證方式
- [ ] 創建測試腳本或測試套件
- [ ] 設定 Pre-commit hook
- [ ] 在 CLAUDE.md 中記錄驗證標準

### 每次修改
- [ ] 修改代碼
- [ ] 執行自動驗證
- [ ] 分析結果
- [ ] 失敗 → 修正 → 再驗證
- [ ] 通過 → 完成

### 定期維護
- [ ] 更新測試覆蓋更多場景
- [ ] 調整性能基準
- [ ] 移除過時的測試
- [ ] 記錄常見失敗模式

---

## References

- [How Boris Uses Claude Code](https://howborisusesclaudecode.com/)
- [Boris Cherny on X: Verification is Key](https://x.com/bcherny/status/2007179861115511237)
- [Claude Code Documentation](https://docs.claude.com/claude-code)
- [Testing Best Practices 2026](https://testing-library.com/docs/guiding-principles/)

---

## See Also

- `code-assistant-advanced-workflow` - 完整工作流程（包含其他 9 個技巧）
- `agentic-coding-complete` - Agentic Coding 方法論
- `techdebt` - 技術債清理（驗證後的清理步驟）

---

**核心精神：**

> 給 Claude 驗證的能力 = 2-3x 品質提升
>
> 這不是可選的優化，
> 而是獲得優秀結果的必要條件。
