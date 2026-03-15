---
name: youtube-search-language-localization
description: |
  YouTube 搜尋結果的語言決定了內容的「視角」。使用時機：
  (1) 需要搜尋特定國家/地區的道地當地資訊，
  (2) 用中文搜尋日本景點只會找到外國觀光客視角的影片，
  (3) 建立旅遊/生活服務類 AI 需要推薦道地內容，
  (4) 發現搜尋結果都是特定語言的創作者而非當地人。
  核心發現：搜尋語言 ≠ 內容語言，而是「誰的視角」。
author: Claude Code
version: 1.0.0
date: 2026-02-06
---

# YouTube 搜尋語言本地化

## Problem

當用繁體中文搜尋日本景點（如「草津溫泉」），YouTube 會優先返回：
- 台灣旅遊 YouTuber 的影片
- 中國旅遊博主的影片
- 少數有中文字幕的日本影片

這些都是**外國觀光客視角**，而非**日本當地人的視角**。

**用戶原話**：「中文也都是外國觀光客」

## Context / Trigger Conditions

- 建立旅遊推薦系統，需要推薦道地的當地內容
- 搜尋結果全是同一種語言的創作者
- 需要「當地人怎麼介紹這個地方」而非「觀光客怎麼看這個地方」
- 用 Apify YouTube Scraper 或任何 YouTube 搜尋功能

## Solution

### 核心概念：搜尋語言決定「視角」

| 搜尋語言 | 視角 | 範例 |
|---------|------|------|
| `草津溫泉 旅行 攻略` | 台灣/中國觀光客 | 「我第一次來草津溫泉...」 |
| `草津温泉 観光 おすすめ` | 日本當地人 | 「地元の私がおすすめする...」 |
| `Kusatsu Onsen travel guide` | 歐美觀光客 | 「My trip to Japan...」 |

### 實作：中文→日文對照表

```typescript
/**
 * 繁體中文→日文地名對照表
 * 用日文搜尋才能找到道地的日本當地影片
 */
const LOCATION_TO_JAPANESE: Record<string, string> = {
  // 溫泉地
  '草津溫泉': '草津温泉',
  '草津': '草津温泉',
  '有馬溫泉': '有馬温泉',
  '有馬': '有馬温泉',
  '道後溫泉': '道後温泉',
  '銀山溫泉': '銀山温泉',
  '由布院': '由布院',
  '湯布院': '由布院',

  // 主要城市/觀光地
  '京都': '京都',
  '東京': '東京',
  '沖繩': '沖縄',
  '金澤': '金沢',
  '廣島': '広島',
  '輕井澤': '軽井沢',
  '富士山': '富士山',
  '河口湖': '河口湖',
};

/**
 * 將地點轉換為日文搜尋用語
 */
function toJapaneseSearchQuery(location: string): string {
  const japanese = LOCATION_TO_JAPANESE[location];
  if (japanese) {
    // 用日文搜尋：地名 + 観光 + おすすめ（推薦）
    return `${japanese} 観光 おすすめ`;
  }
  return `${location} 観光 旅行`;
}
```

### 日文搜尋關鍵字對照

| 中文 | 日文 | 用途 |
|------|------|------|
| 旅行 | 旅行 | 相同 |
| 攻略 | 完全ガイド | 完整指南 |
| 推薦 | おすすめ | 推薦 |
| 觀光 | 観光 | 觀光 |
| 美食 | グルメ | 美食 |
| 購物 | ショッピング | 購物 |
| 住宿 | 宿泊 / ホテル | 住宿 |
| 溫泉 | 温泉 | 注意：日文用「温」不是「溫」 |
| 穴場 | 穴場 | 私房景點 |
| 秘境 | 秘境 | 秘境 |

### 搜尋模式組合

```typescript
// 旅遊 vlog（個人分享）
`${地名} 旅行 vlog`

// 完整攻略（詳細指南）
`${地名} 観光 完全ガイド`

// 當地推薦（當地人視角）
`${地名} おすすめ 地元`

// 私房景點
`${地名} 穴場 スポット`

// 季節限定
`${地名} 紅葉 2024`  // 秋天紅葉
`${地名} 桜 花見`    // 春天櫻花
```

## Verification

1. 搜尋「草津温泉 観光 おすすめ」
2. 確認結果中有日文標題的影片（而非中文標題）
3. 確認創作者是日本人（頻道名是日文）
4. 影片內容是日文（或至少是日本視角）

## Example

**Before（中文搜尋）**:
```typescript
const searchQuery = `${specificLocation} 旅行 攻略`;
// 結果：台灣 YouTuber 的「草津溫泉兩天一夜攻略」
```

**After（日文搜尋）**:
```typescript
const japaneseQuery = toJapaneseSearchQuery(specificLocation);
// japaneseQuery = "草津温泉 観光 おすすめ"
// 結果：日本當地人的「草津温泉のおすすめスポット」
```

## Notes

### 這個概念也適用於其他國家

| 目的地 | 外國視角 | 當地視角 |
|--------|---------|---------|
| 日本 | 中文/英文搜尋 | 日文搜尋 |
| 韓國 | 中文/英文搜尋 | 韓文搜尋 |
| 泰國 | 中文/英文搜尋 | 泰文搜尋 |
| 法國 | 英文搜尋 | 法文搜尋 |

### 注意事項

1. **不是所有情況都需要當地語言**：如果用戶不懂日文，可能更適合看中文影片
2. **混合策略**：可以先搜日文找道地內容，再搜中文找有中文字幕的版本
3. **字幕過濾**：YouTube API 支援按字幕語言過濾，可以找「日文影片但有中文字幕」

### 進階：用 YouTube API 的 `relevanceLanguage` 參數

```typescript
// YouTube Data API v3
const params = {
  q: '草津温泉',
  relevanceLanguage: 'ja',  // 優先返回日文內容
  regionCode: 'JP',          // 優先返回日本地區的內容
};
```

但 Apify YouTube Scraper 不一定支援這些參數，所以**用日文關鍵字搜尋**是更可靠的方法。

## References

- YouTube Data API: [Search Parameters](https://developers.google.com/youtube/v3/docs/search/list)
- Apify YouTube Scraper: [streamers/youtube-scraper](https://apify.com/streamers/youtube-scraper)
