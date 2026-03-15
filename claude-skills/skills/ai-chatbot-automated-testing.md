---
name: ai-chatbot-automated-testing
description: |
  自動化測試 AI Chatbot 並迭代優化 Prompt 的完整方法論。使用時機：
  (1) Bot 回覆品質不穩定，需要系統化測試，
  (2) 需要用「難搞客戶」persona 測試 Bot 極限，
  (3) 想要自動化 prompt 優化流程（測試→分析→修改→重測），
  (4) 設定「世界級標準」（90分+）而非低標及格（60分），
  (5) 檔案有多個 prompt 時需要精確匹配正確的 prompt。
  核心發現：「嫌貨才是買貨人」— 服務好難搞客戶才是金鑰匙價值。
author: Claude Code
version: 1.0.0
date: 2026-02-06
---

# AI Chatbot 自動化測試與優化

## Problem

AI Chatbot 開發常見的問題：
1. 手動測試耗時且覆蓋不全
2. 不知道 Bot 對「難搞客戶」表現如何
3. Prompt 優化靠感覺，沒有量化標準
4. 及格線設太低（60分），服務品質不夠好

## Context / Trigger Conditions

使用此 skill 當：
- Bot 上線後收到負面反饋
- 需要系統化驗證 Bot 品質
- 想要自動化 prompt 優化流程
- 設計服務「有錢但難搞」的客戶的 Bot

## Solution

### 1. 設計難搞客戶 Persona

```typescript
interface CustomerPersona {
  id: string;
  name: string;
  type: string;  // 例：「安靜奢華型」「重複造訪型」
  dialogueScript: {
    opening: string;           // 開場白
    responses: {
      tooLong: string;         // Bot 回覆太長時
      tooGeneric: string;      // Bot 回覆太籠統時
      selfDeprecating: string; // Bot 自我否定時
      satisfied: string;       // 滿意時
    };
    dealBreakers: string[];    // 絕對禁忌詞
  };
  successCriteria: {
    maxTurns: number;          // 最多幾則對話要滿意
    mustInclude: string[];     // 必須包含的關鍵詞
    mustNotInclude: string[];  // 絕對不能有的詞
  };
}
```

### 2. 評分函數

```typescript
function evaluateBotResponse(persona, botResponse, turnNumber) {
  let score = 100;
  const issues = [];

  // 1. 字數限制
  if (botResponse.length > 50) {
    issues.push(`回覆太長 (${botResponse.length} 字)`);
    score -= 30;
  }

  // 2. 禁止元素
  for (const forbidden of persona.successCriteria.mustNotInclude) {
    if (botResponse.includes(forbidden)) {
      issues.push(`包含禁止元素: "${forbidden}"`);
      score -= 20;
    }
  }

  // 3. 自我否定（最嚴重）
  const selfDeprecating = ['哈哈', '😅', '我剛才', '我腦袋短路'];
  for (const phrase of selfDeprecating) {
    if (botResponse.includes(phrase)) {
      issues.push(`自我否定: "${phrase}"`);
      score -= 25;
    }
  }

  return { score, issues };
}
```

### 3. 自動優化迴圈

```typescript
// 設定高標準
const PASS_THRESHOLD = 90;  // 世界級標準，不是 60 分及格
const MAX_ITERATIONS = 10;

for (let round = 1; round <= MAX_ITERATIONS; round++) {
  // 1. 測試所有 persona
  const results = await testAllPersonas(currentPrompt);

  // 2. 計算平均分數
  const avgScore = calculateAverage(results);

  // 3. 全部通過？
  if (avgScore >= PASS_THRESHOLD) {
    console.log('🎉 世界級標準達成！');
    break;
  }

  // 4. 分析問題並生成修改建議
  const suggestions = await analyzeAndSuggestChanges(results);

  // 5. 更新 Prompt
  currentPrompt = updatePrompt(currentPrompt, suggestions);
}
```

### 4. 多 Prompt 檔案的精確匹配

**問題**：當檔案有多個 `system:` prompt 時，簡單正則會匹配錯誤的 prompt。

**解法**：用唯一標識符（開頭文字）來定位：

```typescript
// ❌ 錯誤：會匹配到第一個找到的 prompt
const match = content.match(/system: `([\s\S]*?)`,\s*messages:/);

// ✅ 正確：用開頭文字精確匹配
const match = content.match(/system: `(你是專業旅遊顧問[\s\S]*?)`,\s*messages:/);
```

### 5. 世界級標準 vs 及格標準

| 標準 | 分數 | 適用場景 |
|------|------|---------|
| 及格 | 60 | 內部測試、MVP |
| 良好 | 75 | 一般用戶 |
| 優秀 | 85 | 付費用戶 |
| **世界級** | **90+** | **高端客戶、奧客** |

**關鍵洞察**：「嫌貨才是買貨人」— 難搞的客戶往往是最有價值的客戶。
服務好他們，他們會死心塌地跟著你，還會介紹朋友。

## Verification

1. 執行自動化測試腳本
2. 確認所有 persona 平均分數 >= 90
3. 檢查對話範例，確認 Bot 回覆符合預期

## Example

**ExampleApp Bot 測試結果**：

```
🧪 測試 安靜奢華型 (林董)... 平均分數: 85.0 ✅
🧪 測試 體驗學習型 (張教授)... 平均分數: 100.0 ✅
🧪 測試 社群炫耀型 (Celine)... 平均分數: 100.0 ✅
🧪 測試 放鬆療癒型 (陳總)... 平均分數: 100.0 ✅
🧪 測試 多代家庭型 (王媽媽)... 平均分數: 92.5 ✅
🧪 測試 重複造訪型 (黃先生)... 平均分數: 100.0 ✅

📊 平均分數: 96.3 — 世界級標準達成！
```

**對話範例**：
```
👤 林董：問這麼多幹嘛，你是專業的還是我是專業的？
🤖 Bot：讓我調整。想放空還是體驗文化？

（不道歉、不自我否定、簡潔有力）
```

## Notes

### 6 種難搞客戶類型

1. **安靜奢華型**：低調有錢，討厭「熱門」「必去」
2. **體驗學習型**：知識份子，要「真正的師傅」不是「觀光體驗」
3. **社群炫耀型**：KOL，要「獨家」「沒人知道」的地方
4. **放鬆療癒型**：壓力大的人，說「放空」就不要推活動
5. **多代家庭型**：帶老人小孩，需要無障礙、不走路
6. **重複造訪型**：日本通，熱門景點都去過，要秘境

### 相關 Skills

- `ai-chatbot-persona-design` - Chatbot 人格設計
- `ai-prompt-mastery` - Prompt 優化策略

## References

- ExampleApp Bot 實際測試案例（2026-02-06）
- 「嫌貨才是買貨人」商業智慧
