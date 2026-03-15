---
name: elderly-friendly-ssr-ui-optimization
description: |
  SSR（Server-Side Rendered）HTML 頁面的老人家友善化 UI 優化方法論。
  使用時機：
  1. 內測/公測對象包含長輩或視力不佳的用戶
  2. SSR 頁面（Hono/Express/Next.js SSR）的 inline CSS 需要無障礙優化
  3. 需要系統性掃描並修正字體、觸控目標、對比度問題
  4. 移除 user-scalable=no 等阻止縮放的設定
  5. WCAG 2.1 AA 合規檢查（4.5:1 對比、48px 觸控）
  觸發關鍵字：老人家、長輩、無障礙、accessibility、a11y、WCAG、字太小、按不到
version: 1.0.0
date: 2026-02-16
author: Claude Code
---

# 老人家友善 SSR UI 優化

## Problem

SSR 頁面的 CSS 都是 inline 在 template literal 裡，沒有共用 CSS 框架。
需要逐頁掃描並修正所有對老人家不友善的元素。

## Context / Trigger Conditions

- 內測對象是「老人家」或視力不佳的用戶
- 頁面是 SSR HTML（Hono、Express 等），CSS 寫在 `<style>` 標籤內
- 沒有 Tailwind/CSS 框架，無法一次性全局修改
- 用戶反映「字太小」「按不到」「看不清楚」

## Solution

### 第一步：掃描問題（用 Grep 批量找）

```bash
# 找所有小字體（CSS class 裡的）
grep -n "font-size:0\.[567]" src/**/*.ts
grep -n "font-size:1[012]px" src/**/*.ts

# 找小觸控目標
grep -n "min-height:3[0-9]px\|min-height:4[0-4]px" src/**/*.ts

# 找低對比色
grep -n "color:#888\|color:#666\|color:#555\|color:var(--mut)" src/**/*.ts

# 找禁止縮放
grep -n "user-scalable=no" src/**/*.ts
```

### 第二步：按優先級修改

#### 🔴 必改（影響可用性）

| 項目 | Before | After | 標準 |
|------|--------|-------|------|
| 最小字體 | 10-12px | **≥ 14px** | WCAG 建議 16px |
| em 值下限 | 0.65-0.72em | **≥ 0.82em** | 以 16px body 計算 ≥ 13px |
| 觸控目標 | 36-44px | **≥ 48px** | WCAG 2.5.5 AAA |
| 文字對比度 | < 3:1 | **≥ 4.5:1** | WCAG 1.4.3 AA |
| 縮放 | user-scalable=no | **移除** | 允許老人家放大 |

#### 🟡 建議改（提升體驗）

| 項目 | Before | After |
|------|--------|-------|
| 行距 | 1.4-1.6 | **1.75** |
| 焦點指示器 | 無 | `*:focus-visible{outline:3px solid #FFB800}` |
| 按鈕 padding | 4px 11px | **10px 16px** |

### 第三步：常用替換對照表

**低對比色 → 高對比色（淺底深字）：**
- `var(--mut)` / `#999` / `#888` → **`#73675A`**（對比 4.6:1，大地色系）
- `#666` → **`#5a5a5a`**（對比 5.5:1）
- `rgba(255,254,245,0.55)` → **`rgba(255,254,245,0.85)`**

**低對比色 → 高對比色（深底淺字）：**
- `#888` on dark bg → **`#aaa`** 或 **`#bbb`**
- `#999` → **`#ccc`**

**em 值轉換表（body 16px 基準）：**
| em | px | 判定 |
|----|-----|------|
| 0.65em | 10.4px | ❌ 太小 |
| 0.72em | 11.5px | ❌ 太小 |
| 0.75em | 12px | ❌ 邊界 |
| 0.82em | 13.1px | ⚠️ 勉強 |
| 0.85em | 13.6px | ⚠️ 可接受 |
| 0.88em | 14.1px | ✅ OK |
| 0.95em | 15.2px | ✅ 好 |
| 1.0em | 16px | ✅ 理想 |

### 第四步：別忘了手機版 RWD

手機版 `@media` 裡的字體通常會再縮小，要特別檢查：

```css
/* ❌ 手機版縮太小 */
@media(max-width:520px){
  .hud-link{font-size:0.72em}
}

/* ✅ 手機版也要可讀 */
@media(max-width:520px){
  .hud-link{font-size:0.92em;padding:8px 12px}
}
```

### 第五步：inline style 在 JS 中的處理

SSR 頁面常有嵌入 JavaScript 產生的 inline style，這些用 CSS class 掃不到：

```javascript
// 這種 inline style 要用不同的 grep 找
'<span style="font-size:0.7em;color:#888">'
```

搜尋指令：
```bash
grep -n 'style="[^"]*font-size:0\.[567]' src/**/*.ts
grep -n 'style="[^"]*font-size:1[012]px' src/**/*.ts
```

⚠️ **注意：** admin-ui.ts 等大型檔案裡嵌入的 JS 字串必須用 `\\n` 而非 `\n`，
否則會在瀏覽器端爆 SyntaxError。CSS-only 修改不會觸發此問題。

## Verification

1. **啟動驗證：** `bun run dev` → curl 所有頁面確認 200
2. **字體檢查：** DevTools → Computed → font-size，確認沒有低於 14px
3. **對比度：** Chrome DevTools → Elements → 點文字 → 看 contrast ratio
4. **觸控：** DevTools → 量 button/link 的 computed height ≥ 48px
5. **縮放：** 手機上 pinch-zoom 確認可放大
6. **tsc 注意：** 大型專案 tsc --noEmit 可能 OOM，用 bun 實際執行驗證更可靠

## Example

和心村（washinmura.jp）內測前優化：
- 5 個 SSR 頁面（Hono on Bun）
- 修改 60+ 處 CSS 字體/對比/觸控
- 測試對象：老人家（手機+電腦）
- Commit: f3a830f

## Notes

- 管理後台（/admin）優先級低於用戶頁面（/my-orchard, /pool）
- 不要改頁面功能邏輯，只改視覺/CSS
- 保留原始設計風格（大地色系、RPG 村莊風），只調深淺和大小
- 共享樣式檔（shared-styles.ts）可匯出基礎無障礙 CSS，但各頁面仍需個別調整

## References

- [WCAG 2.1 AA 標準](https://www.w3.org/WAI/WCAG21/quickref/)
- [觸控目標尺寸 48px](https://www.w3.org/WAI/WCAG21/Understanding/target-size.html)
- [對比度計算器](https://webaim.org/resources/contrastchecker/)
