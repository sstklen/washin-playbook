---
name: unified-ai-agent-architecture
description: |
  設計統一 AI Agent 架構，將多個分散的 AI 引擎（預判、推薦、匹配、學習、評分）
  整合為單一智慧中樞。使用時機：(1) 有多個獨立的 AI 功能需要協調，
  (2) API 端點需要調用多個 AI 引擎，(3) 想要簡化外部接口但保留內部複雜性，
  (4) 需要讓 AI 能力「內化」而非分開調用。核心概念：單例模式 + 統一入口 + 自動執行。
author: Claude Code
version: 1.0.0
date: 2026-02-05
---

# 統一 AI Agent 架構模式

## Problem

當系統有多個獨立的 AI 引擎時（例如：預判引擎、推薦引擎、匹配引擎、學習引擎），
每個 API 端點都需要分別調用這些引擎，導致：

1. **代碼重複** — 每個端點都要寫調用邏輯
2. **不一致** — 不同端點可能漏掉某些引擎
3. **難以維護** — 新增引擎時要修改所有端點
4. **缺乏協調** — 各引擎之間的結果無法整合

## Context / Trigger Conditions

當你遇到以下情況時，使用這個模式：

- 有 3+ 個獨立的 AI 功能需要在同一個請求中執行
- 用戶說「這些全部都要內化在 Agent 裡面」
- 需要讓多個 AI 能力看起來像「一個聰明的 Agent」
- 想要簡化外部 API 但保留內部複雜性
- 需要讓 AI 能力自動執行，不需要外部顯式調用

## Solution

### 1. 設計統一 Agent 類別

```typescript
/**
 * 統一 AI Agent - 所有智慧的單一入口
 *
 * 🧠 本能（自動運作，不需要呼叫）：
 *   - 預判引擎：收到請求就自動預判
 *   - 推薦引擎：自動推薦相關選項
 *   - 匹配引擎：自動找到最適合的資源
 *   - 學習引擎：自動記錄並改進
 */
export class UnifiedAgent {
  private static instance: UnifiedAgent;

  // 單例模式確保狀態共享
  public static getInstance(): UnifiedAgent {
    if (!UnifiedAgent.instance) {
      UnifiedAgent.instance = new UnifiedAgent();
    }
    return UnifiedAgent.instance;
  }

  /**
   * 統一處理入口 — 所有智慧自動執行
   */
  async processRequest(request: Request): Promise<ProcessingResult> {
    const startTime = Date.now();

    // ===== 1. 自動執行所有 AI 能力 =====
    const anticipation = await this.anticipate(request);
    const recommendations = await this.recommend(request);
    const matching = await this.match(request);
    const qualityPrediction = this.predictQuality(request);
    const insights = this.findInsights(request);

    // ===== 2. 生成統一報告 =====
    const briefing = this.generateBriefing(
      anticipation,
      recommendations,
      matching,
      qualityPrediction
    );

    return {
      request_id: this.generateId(),
      processing_time_ms: Date.now() - startTime,
      anticipation,
      recommendations,
      matching,
      quality_prediction: qualityPrediction,
      insights,
      briefing,
    };
  }

  /**
   * 學習入口 — 服務完成後自動學習
   */
  async learn(input: LearningInput): Promise<LearningResult> {
    // 記錄結果、分析準確度、生成改進建議
    return this.learningEngine.process(input);
  }

  // 內部方法：各個 AI 能力
  private async anticipate(request: Request) { /* ... */ }
  private async recommend(request: Request) { /* ... */ }
  private async match(request: Request) { /* ... */ }
  private predictQuality(request: Request) { /* ... */ }
  private findInsights(request: Request) { /* ... */ }
}

// 匯出單例
export const unifiedAgent = UnifiedAgent.getInstance();

// 便捷函數
export async function processRequest(request: Request) {
  return unifiedAgent.processRequest(request);
}
```

### 2. 簡化 API 端點

```typescript
// 之前：分散調用
export async function POST(req: NextRequest) {
  const anticipation = generateAnticipationNotes(request);
  const recommendations = generateRecommendations(request);
  const matching = matchSuppliers(request);
  const content = generateContent(anticipation, recommendations, matching);
  // ... 複雜的整合邏輯
}

// 之後：統一入口
export async function POST(req: NextRequest) {
  const result = await processAgentRequest(body);

  // 所有 AI 分析結果已經整合好了
  const orderData = {
    metadata: {
      ai_analysis: {
        anticipation: result.anticipation,
        recommendations: result.recommendations,
        matching: result.supplier_matching,
        quality_prediction: result.quality_prediction,
      }
    }
  };

  // 使用 Agent 生成的完整報告
  await db.from('tickets').insert({
    content: result.op_briefing,  // AI 自動生成
  });
}
```

### 3. 設計完整的結果類型

```typescript
interface AgentProcessingResult {
  // 基本資訊
  request_id: string;
  processed_at: string;
  processing_time_ms: number;

  // 各 AI 能力的結果
  anticipation: {
    report: AnticipationReport;
    critical_items: AnticipationNote[];
    highlights: string[];
  };

  recommendations: {
    highly_recommended: Recommendation[];
    recommended: Recommendation[];
    total_value: number;
  };

  supplier_matching: {
    best_match: Match | null;
    alternatives: Match[];
    capability_gaps: string[];
  };

  quality_prediction: {
    expected_score: number;
    confidence: number;
    risk_factors: string[];
    success_factors: string[];
  };

  learning_insights: {
    relevant_patterns: string[];
    similar_cases: number;
    success_rate: number;
  };

  // 統一輸出
  op_briefing: string;  // 給內部人員的完整報告
  external_response: ExternalResponse;  // 給外部的回應
}
```

## Verification

整合完成後，驗證：

1. **API 端點簡化** — 原本調用 5+ 個引擎的代碼，現在只需要 1 行
2. **TypeScript 編譯通過** — `npx tsc --noEmit` 無錯誤
3. **結果完整** — 所有 AI 能力的結果都在 `AgentProcessingResult` 中
4. **日誌正確** — Console 顯示 Agent 處理各步驟的記錄

## Example

### ExampleApp Concierge Network 案例

**問題**：系統有 5 個獨立的 AI 引擎：
- 預判引擎 (Anticipation Engine)
- 加值服務推薦 (Value-Added Services)
- 供應商匹配 (Supplier Matching)
- 學習引擎 (Learning Engine)
- 品質評分 (Quality Scoring)

**用戶要求**：「這些全部都要內化在 ExampleApp AI Agent 裡面」

**解決方案**：

```typescript
// /lib/ai/golden-key-agent.ts
export class GoldenKeyAgent {
  async processRequest(request: OrderCreateRequest): Promise<AgentProcessingResult> {
    console.log(`🔑 ExampleApp Agent 開始處理...`);

    // 所有能力自動執行
    const anticipation = generateAnticipationNotes(...);
    const recommendations = generateServiceRecommendationsForOrder(...);
    const matching = await this.matchSuppliers(...);
    const quality = this.predictQuality(...);
    const insights = this.findRelevantInsights(...);

    // 生成完整報告
    const briefing = this.generateOpBriefing(...);

    return { anticipation, recommendations, matching, quality, insights, briefing };
  }
}

export const goldenKeyAgent = GoldenKeyAgent.getInstance();
export async function processAgentRequest(request) {
  return goldenKeyAgent.processRequest(request);
}
```

```typescript
// /api/v1/external/orders/route.ts
export async function POST(req: NextRequest) {
  // 統一入口：一行代碼獲得所有 AI 分析
  const agentResult = await processAgentRequest(body);

  // 使用結果
  const orderData = {
    metadata: { ai_analysis: agentResult }
  };

  await db.from('tickets').insert({
    content: agentResult.op_briefing,  // AI 生成的報告
  });
}
```

## Notes

### 設計原則

1. **單例模式** — 確保學習狀態和統計數據在所有調用間共享
2. **自動執行** — 外部只需調用一個方法，所有能力自動運作
3. **完整結果** — 返回結構化的完整結果，包含給內部和外部的不同格式
4. **便捷函數** — 提供 `processAgentRequest()` 等簡化調用

### 常見陷阱

- **類型導入錯誤** — 確保從 schema 層導入類型，而非從使用層
- **循環依賴** — Agent 可能依賴多個引擎，注意 import 順序
- **狀態管理** — 單例模式要注意並發安全（Node.js 單線程通常無問題）

### 適用場景

- 禮賓/旅遊服務系統
- 電商推薦系統
- 智慧客服系統
- 任何需要多個 AI 能力協調的應用

### See Also

- `agent-autonomy-safety-framework` — 偏好交換 API 設計
- `multi-agent-workflow-design` — 多 Agent 專案開發

## References

- ExampleApp Concierge Network 專案實作 (2026-02-05)
- Les Clefs d'Or 金鑰匙服務哲學
