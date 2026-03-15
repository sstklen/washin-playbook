---
name: techdebt
description: |
  技術債清理指令。使用時機：(1) 工作階段結束前清理代碼，(2) 發現重複代碼需要重構，
  (3) PR 提交前確保代碼整潔，(4) 定期維護代碼品質。自動找出並消除：重複代碼、
  未使用變數、過時註解、可合併函數、臨時 workaround。來自 Boris Cherny 的團隊實踐。
author: Claude Code Team
version: 1.0.0
date: 2026-02-02
---

# Tech Debt 清理

> 每次工作結束都清理技術債，不要累積

## 使用方式

```bash
/techdebt
```

或在 Claude Code 中直接說：「執行 techdebt 清理」

---

## 檢查清單

### 1. 重複代碼（DRY 違反）

**檢查：**
```
- 相同或相似的程式碼片段
- 可以提取為共用函數的邏輯
- 重複的驗證邏輯
- 重複的錯誤處理
```

**行動：**
- 提取共用函數
- 創建可重用的 utility
- 建立統一的錯誤處理機制

---

### 2. 未使用的代碼

**檢查：**
```
- 未使用的變數
- 未呼叫的函數
- 過時的 import
- 死代碼路徑
- 註解掉但未刪除的舊代碼
```

**行動：**
- 刪除未使用的變數和函數
- 清理 imports
- 移除註解掉的舊代碼（應該靠 git history）

---

### 3. 可合併的函數

**檢查：**
```
- 功能相似的多個函數
- 可以用參數統一的函數
- 只有微小差異的函數
```

**行動：**
- 合併為單一函數，用參數控制行為
- 建立通用接口

---

### 4. 過時的註解

**檢查：**
```
- 與代碼不符的註解
- TODO/FIXME 已完成但未刪除
- 過度明顯的註解（註解即代碼內容）
- 時間過期的註解（「暫時的」已經存在 6 個月）
```

**行動：**
- 更新不符的註解
- 刪除已完成的 TODO
- 移除明顯註解，讓代碼自解釋

---

### 5. 臨時 Workaround

**檢查：**
```
- 標記為「臨時」的解決方案
- Hack 或 quick fix
- 繞過正常流程的代碼
- 硬編碼的值（應該是配置）
```

**行動：**
- 替換為正式解決方案
- 將硬編碼值移到配置
- 移除 hack，實現正確邏輯

---

### 6. 代碼風格不一致

**檢查：**
```
- 縮排不一致
- 命名約定不一致
- 引號風格不一致（單引號 vs 雙引號）
- 函數風格不一致（箭頭函數 vs 普通函數）
```

**行動：**
- 統一代碼風格
- 運行 linter/formatter
- 遵循專案約定

---

### 7. 性能問題

**檢查：**
```
- 不必要的循環巢狀
- 可以並行但串行執行的操作
- 重複計算相同結果
- 未使用的資料庫查詢
```

**行動：**
- 優化演算法複雜度
- 使用並行處理（Promise.all）
- 加入快取機制
- 移除不必要的查詢

---

### 8. 錯誤處理不足

**檢查：**
```
- 缺少 try-catch
- 錯誤訊息不清楚
- 未處理的 Promise rejection
- 沒有回退機制
```

**行動：**
- 加入適當的錯誤處理
- 改進錯誤訊息
- 處理所有 Promise
- 實現回退邏輯

---

## 實施步驟

### 階段 1：自動檢測
```bash
# 運行 linter
npm run lint

# 檢查未使用的 exports
npx ts-prune

# 檢查重複代碼
npx jscpd .

# 檢查代碼複雜度
npx complexity-report src/
```

### 階段 2：人工審查
```
1. 掃描所有 TODO/FIXME
2. 查找「temporary」「hack」「workaround」關鍵字
3. 檢查最近修改的檔案
4. 審查長函數（>50 行）
```

### 階段 3：執行清理
```
1. 先運行測試，確保有覆蓋
2. 進行重構
3. 再運行測試，確保沒破壞功能
4. Commit 變更
```

---

## 自動化腳本

**package.json:**
```json
{
  "scripts": {
    "techdebt:check": "npm run lint && npx ts-prune && npx jscpd .",
    "techdebt:fix": "npm run lint:fix && npm run format"
  }
}
```

**使用：**
```bash
npm run techdebt:check  # 檢查
npm run techdebt:fix    # 自動修復
```

---

## 團隊實踐

### Boris Cherny 的做法
- **頻率：** 每次工作階段結束
- **時間：** 5-10 分鐘
- **原則：** 離開時代碼要比開始時更乾淨

### 判斷標準
一天做超過一次 techdebt → 應該：
1. 自動化檢測
2. 設定 pre-commit hook
3. 整合到 CI pipeline

---

## 實例

### 實例 1：Telegram Bot 優化

**Before（1050 行）：**
```javascript
// 重複的 KV 讀取邏輯
async function getHistory1() { ... }
async function getHistory2() { ... }
async function getHistory3() { ... }

// 串行讀取
for (let id of ids) {
  await kv.get(id);
}
```

**After（589 行）：**
```javascript
// 統一的並行讀取
async function getConversationHistoryFast() {
  const promises = ids.map(id => kv.get(id));
  return await Promise.all(promises);
}
```

**結果：**
- 代碼減少 44%
- 性能提升 27x
- 可維護性提升

---

### 實例 2：清理 TODO

**Before：**
```javascript
// TODO: 這是臨時解法，之後要改用正確的 API
const data = hardcodedData;

// FIXME: 這個 hack 很醜，但先這樣
if (workaround) { ... }

// TEMP: 測試用，記得刪掉
console.log('debug info');
```

**After：**
```javascript
// 使用正確的 API
const data = await api.getData();

// 實現正確邏輯
if (properCondition) { ... }

// 移除調試代碼（或使用 logger）
```

---

## 指標追蹤

### 建議追蹤的指標

| 指標 | 目標 | 衡量方式 |
|------|------|---------|
| 代碼行數 | 持續減少 | `git diff --stat` |
| 重複率 | <3% | jscpd 報告 |
| 未使用 export | 0 | ts-prune |
| TODO 數量 | <10 | `grep -r "TODO"` |
| 平均函數長度 | <30 行 | complexity-report |
| Lint 警告 | 0 | eslint --quiet |

### 記錄改進
```bash
# 記錄清理前後
echo "$(date): Lines: $(find src -name '*.ts' | xargs wc -l | tail -1)" >> .techdebt-log
```

---

## 常見問題

### Q: 多久做一次 techdebt？
A: **每次工作結束前**，5-10 分鐘即可。

### Q: 會不會影響進度？
A: 相反，定期清理能：
- 減少後續除錯時間
- 提升開發速度
- 降低認知負擔

### Q: 舊代碼也要清嗎？
A: **童子軍規則**：
> 離開時，代碼要比你來時更乾淨

不需要全部重構，但碰到的地方要清理。

---

## 自動化增強

### Pre-commit Hook

**.git/hooks/pre-commit:**
```bash
#!/bin/bash

echo "🧹 Running techdebt check..."

# Run linter
npm run lint --quiet || exit 1

# Check for common issues
if grep -r "console.log" src/; then
  echo "❌ Found console.log in src/"
  exit 1
fi

if grep -r "TODO\|FIXME\|HACK" src/ | wc -l | grep -v "^[0-9]$"; then
  echo "⚠️  Many TODOs found. Consider cleaning up."
fi

echo "✅ Techdebt check passed"
```

### CI Integration

**.github/workflows/techdebt.yml:**
```yaml
name: Tech Debt Check

on: [pull_request]

jobs:
  techdebt:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: npm install
      - run: npm run techdebt:check
      - run: npx ts-prune
      - run: npx jscpd . --threshold 3
```

---

## 延伸閱讀

- **Code Quality Tools:**
  - [ESLint](https://eslint.org/)
  - [ts-prune](https://github.com/nadeesha/ts-prune)
  - [jscpd](https://github.com/kucherenko/jscpd)
  - [SonarQube](https://www.sonarqube.org/)

- **相關 Skills:**
  - `code-assistant-advanced-workflow` - 完整工作流程
  - `code-simplifier` - 代碼簡化工具
  - `everything-claude-code:refactor-cleaner` - 重構清理專家

---

**核心精神：**
> 技術債不是「之後再處理」
> 而是「現在就不要產生」

每次離開時，留下比來時更乾淨的代碼。
