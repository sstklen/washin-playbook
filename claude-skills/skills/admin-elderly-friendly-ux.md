---
name: admin-elderly-friendly-ux
description: |
  把技術性後台介面改成非工程師也能輕鬆操作的版本。
  使用時機：(1) 後台配置頁面顯示技術 key 名而非中文描述，
  (2) 導航結構需要多次點擊才到常用功能，(3) 新功能被工程師以技術思維做完但管理者看不懂，
  (4) 業主說「老人友善」「看不懂」「工程師思維」時觸發。
  涵蓋：配置顯示反轉、導航扁平化、快捷入口、描述白話化。
version: 1.0.0
date: 2026-02-16
---

# 後台老人友善 UX 準則

## Problem

工程師做後台功能時，習慣用技術 key 當標題（如 `daily_base_income`），
中文描述放小字。導航也按技術分類（「進階設定」裡藏 5 個子頁籤）。
非工程師管理者要操作時，看不懂、找不到、不敢動。

## 準則（強制執行）

### 1. 配置顯示：人話優先

```
粗體大字 = description（中文說明）
小字灰色 = 技術 key（給工程師 debug 用）

例：
  🌾 每日保底收成 — 果農每天來就有基本收入    [開/關]
  feature.daily_base_income                   ← 小字

而非：
  daily_base_income                           [開/關]
  每日保底收成（每天首次訪問自動發放隨機 WT）  ← 小字
```

**代碼模式：**
```javascript
// 老人友善版（description 當標題）
'<div class="title">' + esc(item.description || item.key) + '</div>' +
'<div class="subtitle" style="font-size:0.8em;color:#555">' + esc(item.key) + '</div>'

// 工程師版（key 當標題）← 禁止
'<div class="title">' + esc(shortKey) + '</div>' +
'<div class="subtitle">' + esc(item.description) + '</div>'
```

### 2. 配置描述：白話文 + 預設值提示

```
工程師寫法 → 老人友善寫法

"每日保底收成最低 WT"
→ "每天最少給多少 WT（保底最低）"

"見習農夫門檻分數"
→ "升到「見習農夫」需要幾分（預設 50）"

"農夫等級：收入計分權重"
→ "等級計分：每賺 1 WT = 幾分（預設 1.0）"
```

**規則：**
- 功能開關加 emoji + 破折號說明（如 `🌾 每日保底收成 — 果農每天來就有基本收入`）
- 數值參數附上預設值（如「預設 50」）幫助判斷
- 用「多少」「幾」「需要」等口語詞
- display 類型明確列出選項含義（如「hidden 隱藏 / coming_soon 預告 / active 上線」）

### 3. 導航：常用功能一鍵直達

```
工程師版（要點 2 下）：
  總覽 | 鑰匙管理 | 社群經營 | 進階設定
                    └→ 果農    └→ 配置（藏第 3 層！）

老人友善版（點 1 下）：
  總覽 | 果農 | 邀請碼 | 配置 | 服務 | ⋯更多▾
                                        └→ 不常用的收起來
```

**規則：**
- 最常用的 4-5 個功能提升為獨立主頁籤
- 不常用功能收進「更多」下拉（但不刪除）
- Dashboard 放快捷入口大按鈕（含待處理 badge）
- 手機版用 3 列 grid（不是 2 列擠 6 個）

### 4. 快捷入口：Dashboard 大按鈕

在總覽頁面放 4 個大按鈕，讓管理者直接跳到最常做的事：

```html
<div class="quick-access"> <!-- 4 格 grid -->
  <div class="quick-card" onclick="switchTab('farmers')">
    👨‍🌾 審核果農
    <span class="badge">3 待審核</span>  <!-- 動態提醒 -->
  </div>
  ...
</div>
```

**badge 規則：** 有待處理事項時才顯示，沒有就空白。

### 5. 新功能整合檢查清單

工程師做完新功能後，必須檢查：

- [ ] Config 的 description 是白話中文嗎？（不是技術術語）
- [ ] 功能開關有 emoji 嗎？有一句話說明嗎？
- [ ] 數值參數附了預設值提示嗎？
- [ ] 後台能找到這個功能嗎？（點幾下到達？）
- [ ] 手機上看得清楚嗎？按得到嗎？（min-height: 48px）

## Verification

打開後台 → ⚙️ 配置 → 確認：
1. 看到的第一行是中文描述（不是 `daily.xxx`）
2. 技術 key 在下面小字灰色
3. 功能開關有 emoji

## Notes

- 此準則源自 2026-02-16 的 admin-ui 模組化（8,606 行 → 4,118 行）
- 與 `elderly-friendly-ssr-ui-optimization` skill 互補（那個管 CSS，這個管 UX 邏輯）
- 適用於所有 SSR 後台頁面（admin-ui.ts、my-orchard-page.ts）
