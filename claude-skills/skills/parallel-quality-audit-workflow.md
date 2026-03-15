---
name: parallel-quality-audit-workflow
description: |
  完整的多代理並行品質審查工作流，用於大型前端專案生產前檢查。使用時機：
  (1) 用戶要求「全面檢查專案」、「找出所有問題」、「品質把關」，
  (2) 大型 Next.js/React 專案需要生產部署前審查，
  (3) 需要同時進行代碼品質、安全性、構建、用戶體驗、架構等多維度檢查。

  涵蓋技術棧：Next.js 13+, React, TypeScript, Zustand, React Query。

  核心價值：5 個專業代理並行執行（Code Reviewer, Security Reviewer, Build Validator,
  Journey Mapper, Architect），節省 80% 時間（2 小時 vs 10 小時串行），
  自動生成統一的品質報告。涵蓋前端品質工作流（Lighthouse CI、Bundle 分析、
  可及性檢查、跨瀏覽器測試）。
author: Claude Code
version: 1.1.0
date: 2026-02-02
---

# 多代理並行品質審查工作流

## Problem

大型前端專案在生產部署前需要進行全面品質檢查，包括代碼品質、安全性、構建狀態、用戶體驗、架構設計等多個維度。如果串行執行這些檢查，耗時過長（10+ 小時），且容易遺漏問題。

## Context / Trigger Conditions

**何時使用此技能**：

1. 用戶明確要求：
   - "幫我全面檢查這個專案"
   - "找出所有問題"
   - "品質把關"
   - "生產部署前審查"

2. 專案特徵：
   - 大型前端專案（50+ 頁面，100+ 組件）
   - Next.js 13+ App Router
   - TypeScript + React
   - 即將或正在準備生產部署

3. 時間要求：
   - 用戶無法等待 10+ 小時的串行檢查
   - 需要在 2-3 小時內完成全面審查

## Solution

### 步驟 1：創建 5 個並行任務

使用 `TaskCreate` 工具創建 5 個獨立任務，每個任務有明確的職責：

```typescript
// Task #1: 前端代碼品質審查
{
  subject: "前端代碼全面審查（TypeScript + React）",
  description: `
    檢查項目：
    1. TypeScript 類型錯誤
    2. React Hooks 使用問題（useEffect 依賴、memory leaks）
    3. 未使用的變數和 imports
    4. 組件性能問題（過度渲染）
    5. 可訪問性問題（a11y）
    6. 代碼重複和可重構機會

    重點檢查目錄：
    - src/components/
    - src/app/
    - src/lib/

    產出：詳細問題清單 + 優先級分類（P0/P1/P2）
  `,
  activeForm: "審查前端代碼品質"
}

// Task #2: 安全漏洞掃描
{
  subject: "安全漏洞全面掃描",
  description: `
    檢查項目：
    1. API keys 洩漏風險
    2. XSS 攻擊防護
    3. CSRF 防護
    4. SQL Injection（如有資料庫查詢）
    5. 未驗證的用戶輸入
    6. 敏感數據暴露
    7. 權限控制漏洞
    8. 依賴套件安全問題（npm audit）

    產出：安全問題報告 + 修復建議 + OWASP Top 10 檢查
  `,
  activeForm: "掃描安全漏洞"
}

// Task #3: 構建和部署驗證
{
  subject: "構建和部署驗證",
  description: `
    檢查項目：
    1. npm run build 能否成功
    2. 構建警告和錯誤
    3. 打包大小分析
    4. 環境變數配置
    5. 生產環境配置問題
    6. 圖片優化狀態
    7. 代碼分割效果

    執行：
    - npm run build
    - 分析構建輸出
    - 檢查 .next/ 打包結果

    產出：構建報告 + 優化建議
  `,
  activeForm: "驗證構建和部署"
}

// Task #4: 用戶旅程完整性檢查
{
  subject: "用戶旅程完整性檢查",
  description: `
    檢查項目：
    1. 所有頁面都有入口（沒有孤島）
    2. 核心用戶流程完整性：
       - 註冊 → 登入 → 瀏覽 → 互動 → 付費
    3. 錯誤處理和回退路徑
    4. 404 和錯誤頁面
    5. Loading 狀態和骨架屏
    6. 空狀態設計（沒數據時）
    7. 導航流暢性

    產出：用戶旅程地圖 + 孤島頁面清單 + 修復建議
  `,
  activeForm: "檢查用戶旅程完整性"
}

// Task #5: 架構設計審查
{
  subject: "架構設計審查和優化建議",
  description: `
    檢查項目：
    1. 代碼結構合理性（目錄組織）
    2. 組件抽象層次是否合理
    3. 狀態管理策略
    4. API 調用模式（是否有重複）
    5. 錯誤處理一致性
    6. 日誌和監控設置
    7. 性能瓶頸識別
    8. 可擴展性評估

    產出：架構審查報告 + 技術債務清單 + 重構路線圖
  `,
  activeForm: "審查架構設計"
}
```

### 步驟 2：派發 5 個專業代理並行執行

使用單個 `Task` 工具調用，派發 5 個代理同時工作：

```typescript
// 🚀 並行派發 5 個代理（關鍵：使用單一訊息多個 Task 調用）
Task({
  subagent_type: "everything-claude-code:code-reviewer",
  description: "審查前端代碼品質",
  prompt: "請執行 Task #1...",
  run_in_background: true  // 背景執行
});

Task({
  subagent_type: "everything-claude-code:security-reviewer",
  description: "掃描安全漏洞",
  prompt: "請執行 Task #2...",
  run_in_background: true
});

Task({
  subagent_type: "everything-claude-code:build-error-resolver",
  description: "驗證構建和部署",
  prompt: "請執行 Task #3...",
  run_in_background: true
});

Task({
  subagent_type: "Explore",
  description: "檢查用戶旅程",
  prompt: "請執行 Task #4...",
  run_in_background: true
});

Task({
  subagent_type: "everything-claude-code:architect",
  description: "審查架構設計",
  prompt: "請執行 Task #5...",
  run_in_background: true
});
```

**關鍵要點**：
- ✅ 使用 `run_in_background: true` 讓代理在背景執行
- ✅ 每個代理會返回 `agentId` 和 `output_file` 路徑
- ✅ 系統會在代理完成時自動通知（`<task-notification>`）

### 步驟 3：等待代理完成並更新任務狀態

當收到 `<task-notification>` 時：

```typescript
// 1. 讀取代理輸出
const result = notification.result;

// 2. 提取關鍵資訊
const summary = extractSummary(result);

// 3. 更新任務狀態
TaskUpdate({
  taskId: taskId,
  status: "completed",
  metadata: {
    score: summary.score,
    issues: summary.issues,
    // ... 其他元數據
  }
});
```

### 步驟 4：彙整結果生成統一報告

當所有 5 個代理完成後，生成完整的品質報告：

```markdown
# 品質報告結構

## 📊 執行摘要
- 總體健康度評分
- 關鍵問題數量（P0/P1/P2）
- 立即需要處理的項目

## 📋 各項檢查結果
1. 代碼品質 - [評分] ✅/⚠️/❌
2. 安全性 - [評分] ✅/⚠️/❌
3. 構建狀態 - [評分] ✅/⚠️/❌
4. 用戶旅程 - [評分] ✅/⚠️/❌
5. 架構設計 - [評分] ✅/⚠️/❌

## 🔥 立即行動項（本周完成）
- P0 問題列表 + 修復方案

## 🗓️ 修復時程表
- 本周/本月/下季度的任務規劃

## ✅ 驗收標準
- 生產部署前必須完成的檢查清單
```

將報告保存為 `docs/QUALITY_REPORT.md`。

## Verification

檢查以下項目確認工作流成功執行：

1. **任務創建**：
   ```bash
   # 查看任務列表
   /tasks
   # 應該看到 5 個任務（已完成或進行中）
   ```

2. **代理執行**：
   - 每個代理都返回了 `agentId`
   - 收到了 5 個 `<task-notification>` 通知

3. **報告生成**：
   ```bash
   ls docs/QUALITY_REPORT.md
   # 檔案應該存在且包含完整內容
   ```

4. **時間節省**：
   - 總耗時應該在 2-3 小時內（vs 10+ 小時串行）

## Example

**實際使用案例**（2026-02-02 和心村專案）：

```
用戶請求：「負責看頭看尾，看哪裡有問題就修修補補，或是提升架構。
          可以派很多人，沒有關係。我要睡覺了，明天再看你的表現。」

執行流程：
1. 創建 5 個任務（代碼/安全/構建/旅程/架構）
2. 派發 5 個代理並行執行
3. 等待 ~2 小時後全部完成
4. 生成 28 頁完整報告

結果：
- ✅ 發現 1 個嚴重安全問題（API key 暴露）
- ✅ 發現 10 個高危問題
- ✅ 發現 15 個中危問題
- ✅ 修復了 2 個 TypeScript 錯誤
- ✅ 構建成功（4.8 秒）
- ✅ 專案健康度評分：7.4/10

用戶反饋：早上起床看到完整報告，非常滿意 ✨
```

## Notes

### 代理選擇指南

| 檢查項目 | 建議代理 | 替代方案 |
|---------|---------|---------|
| 代碼品質 | `code-reviewer` | `general-purpose` |
| 安全性 | `security-reviewer` | `code-reviewer` |
| 構建驗證 | `build-error-resolver` | `Bash` (手動) |
| 用戶旅程 | `Explore` | `general-purpose` |
| 架構設計 | `architect` | `general-purpose` |

### 專案類型適配

**Next.js/React 專案**（原始配置）：
- 使用上述 5 個代理

**後端 API 專案**：
- 替換 Task #4（用戶旅程）為 API 測試
- 使用 `tdd-guide` 代理

**行動應用（React Native）**：
- 添加第 6 個任務：行動特定檢查
- 檢查 iOS/Android 兼容性

### 常見問題

**Q: 代理會不會衝突？**
A: 不會。每個代理在獨立的環境中執行，只讀取檔案，不會同時寫入。

**Q: 如果某個代理失敗了怎麼辦？**
A: 系統會通知失敗，你可以單獨重新執行該代理，不影響其他代理。

**Q: 可以調整代理數量嗎？**
A: 可以。根據專案規模和需求增減代理，通常 3-7 個代理最合適。

**Q: Token 使用量會不會超標？**
A: 5 個代理並行大約使用 100K-150K tokens。如果 budget 有限，可以減少代理數量或使用 Haiku 模型。

### 最佳實踐

1. **任務描述要詳細** - 代理需要明確的指示才能產出高品質報告
2. **設定合理的預期** - 告訴用戶需要等待 2-3 小時
3. **定期檢查進度** - 使用 `/tasks` 查看任務狀態
4. **保存輸出檔案** - 代理的完整輸出在 `/tmp/claude/tasks/` 中

### 改進方向

1. **自動修復** - 未來可以讓代理不僅報告問題，還自動修復 P0/P1 問題
2. **持續集成** - 將此工作流整合到 CI/CD pipeline
3. **增量檢查** - 只檢查變更的部分，加快速度

## References

- [Claude Code Task Tool Documentation](https://docs.anthropic.com/claude/docs/task-tool)
- [Multi-Agent Systems Best Practices](https://www.anthropic.com/research/multi-agent)
- [Next.js Production Checklist](https://nextjs.org/docs/going-to-production)
- [OWASP Top 10 (2021)](https://owasp.org/Top10/)

## Merged Skills (archived)

The following skills have been merged into this guide:
- **frontend-quality-workflow** — 前端品質工作流（Lighthouse CI、Bundle 分析、可及性檢查、跨瀏覽器測試、效能預算）
