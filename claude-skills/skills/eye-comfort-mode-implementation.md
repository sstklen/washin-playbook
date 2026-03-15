---
name: eye-comfort-mode-implementation
description: |
  實作護眼模式（Eye Comfort Mode）的完整方案。使用情境：(1) 用戶抱怨配色太亮或太刺眼，
  (2) 需要添加護眼/夜間/低對比主題切換，(3) 想要用 CSS 變數實現主題切換而不需重寫樣式。
  涵蓋護眼配色科學原理、CSS 變數覆蓋模式、React Hook + localStorage 持久化。
author: Claude Code
version: 1.0.0
date: 2026-02-03
---

# 護眼模式實作指南

## Problem

用戶長時間使用 App 後眼睛疲勞，要求「護眼模式」或「舒適配色」。需要：
- 不重寫所有樣式的情況下切換主題
- 記住用戶偏好（關閉 App 後仍有效）
- 符合護眼科學原理的配色調整

## Context / Trigger Conditions

- 用戶說「眼睛看起來會累」、「配色太亮」、「太刺眼」
- 需要添加主題切換功能（護眼、深色、高對比等）
- 已有完整的設計系統（CSS 變數定義的色彩）
- 使用 Next.js + Tailwind CSS 或類似技術棧

## Solution

### 1. 護眼配色科學原理

| 調整項目 | 原因 | 調整幅度 |
|----------|------|----------|
| **降低飽和度** | 高飽和色彩更刺激視覺神經 | -30% 到 -40% |
| **中性化暖色** | 過黃的色調會造成視覺疲勞 | 減少黃色偏向 |
| **柔和對比度** | 高對比會造成眼睛頻繁調節 | 文字色稍淡 |
| **減輕陰影** | 陰影過重增加視覺複雜度 | 透明度降低 |

### 2. CSS 變數覆蓋模式

在 `globals.css` 中添加護眼模式變數覆蓋：

```css
/* 護眼模式變數覆蓋 */
.eye-comfort,
[data-theme="eye-comfort"] {
  /* 背景色 - 更中性的灰白，減少黃色 */
  --background-primary: #F8F7F5;
  --background-warm: #F5F2ED;

  /* 文字色 - 稍微降低對比度 */
  --text-primary: #6B5D4F;    /* 原本 #8B7355 */
  --text-secondary: #8A7D70;  /* 原本 #A89080 */

  /* 強調色 - 降低飽和度 */
  --accent-green: #94B094;    /* 原本 #7BA87B */
  --accent-yellow: #E8E2D8;   /* 原本 #E8D4A8 */

  /* 陰影 - 更柔和 */
  --shadow-sm: 0 2px 8px rgba(107, 93, 79, 0.05);
  --shadow-md: 0 4px 16px rgba(107, 93, 79, 0.07);
}
```

**關鍵技巧**：
- 使用 `[data-theme="eye-comfort"]` 選擇器，可通過 JS 動態切換
- 同時支援 `.eye-comfort` class，方便局部使用
- 只覆蓋需要調整的變數，其他繼承默認值

### 3. React Hook + localStorage 持久化

```typescript
// hooks/useEyeComfort.ts
"use client";

import { useState, useEffect, useCallback } from "react";

const STORAGE_KEY = "app-eye-comfort";

export function useEyeComfort() {
  const [isEyeComfort, setIsEyeComfort] = useState(false);
  const [isLoaded, setIsLoaded] = useState(false);

  // 初始化：讀取用戶偏好
  useEffect(() => {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (stored === "true") {
      setIsEyeComfort(true);
      document.documentElement.setAttribute("data-theme", "eye-comfort");
      document.documentElement.classList.add("eye-comfort");
    }
    setIsLoaded(true);
  }, []);

  // 切換護眼模式
  const toggleEyeComfort = useCallback(() => {
    setIsEyeComfort((prev) => {
      const newValue = !prev;
      localStorage.setItem(STORAGE_KEY, String(newValue));

      if (newValue) {
        document.documentElement.setAttribute("data-theme", "eye-comfort");
        document.documentElement.classList.add("eye-comfort");
      } else {
        document.documentElement.removeAttribute("data-theme");
        document.documentElement.classList.remove("eye-comfort");
      }

      return newValue;
    });
  }, []);

  return { isEyeComfort, isLoaded, toggleEyeComfort };
}
```

**關鍵技巧**：
- `isLoaded` 狀態避免 SSR/CSR 水合時的閃爍
- 同時設置 `data-theme` 屬性和 class，增加選擇器靈活性
- 使用 `document.documentElement` 確保全局生效

### 4. 切換組件範例

```tsx
// components/EyeComfortToggle.tsx
"use client";

import { Eye, EyeOff } from "lucide-react";
import { useEyeComfort } from "@/hooks/useEyeComfort";

export function EyeComfortToggle() {
  const { isEyeComfort, isLoaded, toggleEyeComfort } = useEyeComfort();

  // 載入中顯示骨架
  if (!isLoaded) {
    return <div className="animate-pulse h-6 w-12 rounded-full bg-gray-200" />;
  }

  return (
    <button
      onClick={toggleEyeComfort}
      className={`relative w-12 h-7 rounded-full transition-all ${
        isEyeComfort ? "bg-green-500" : "bg-gray-300"
      }`}
      aria-label={isEyeComfort ? "關閉護眼模式" : "開啟護眼模式"}
    >
      <span
        className={`absolute top-0.5 w-6 h-6 rounded-full bg-white shadow transition-all ${
          isEyeComfort ? "left-[22px]" : "left-0.5"
        }`}
      >
        {isEyeComfort ? (
          <Eye className="w-4 h-4 text-green-500 m-1" />
        ) : (
          <EyeOff className="w-4 h-4 text-gray-400 m-1" />
        )}
      </span>
    </button>
  );
}
```

## Verification

1. 開啟護眼模式後，檢查 `<html>` 元素是否有 `data-theme="eye-comfort"` 屬性
2. 關閉瀏覽器後重新打開，確認設定被記住
3. 視覺檢查：背景應更中性、文字對比度降低、整體更柔和

## Example

**實際配色轉換表**：

| 元素 | 原本（水彩風） | 護眼版本 | 調整說明 |
|------|-------------|---------|---------|
| 背景黃 | `#F5E6C8` | `#F5F2ED` | 中性化 |
| 深黃色 | `#E8D4A8` | `#E8E2D8` | 降飽和 |
| 草地綠 | `#7BA87B` | `#94B094` | 降飽和 |
| 主文字 | `#8B7355` | `#6B5D4F` | 降對比 |

## Notes

- **不要過度降低對比度**：WCAG 建議正文至少 4.5:1 對比度
- **考慮系統偏好**：可以讀取 `prefers-color-scheme` 或 `prefers-contrast` 媒體查詢
- **與深色模式共存**：可以組合使用 `[data-theme="eye-comfort"].dark`
- **測試真實設備**：不同螢幕色溫差異大，建議多設備測試

## References

- [WCAG 對比度指南](https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html)
- [眼睛疲勞與螢幕色彩研究](https://www.aao.org/eye-health/tips-prevention/computer-usage)
- [CSS prefers-color-scheme](https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-color-scheme)
