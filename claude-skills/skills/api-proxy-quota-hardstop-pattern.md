---
name: api-proxy-quota-hardstop-pattern
description: |
  API 代理/市集服務的額度管理架構模式：三層防護（Config → Middleware → Endpoint）+ 安全百分比。
  使用時機：
  1. 建立 API proxy/marketplace 需要管控上游 API 額度（防止帳號被封鎖）
  2. 混合免費+付費服務的額度統一管理
  3. 發現免費服務路徑缺少額度檢查（中間件遺漏）
  4. 需要區分 request-based vs char-based 額度追蹤
  5. 用戶說「額度不能耗盡」「防止帳號被封」「加硬停線」
  6. 服務分三類（有帳號/用自己 Key/無帳號），每類需要不同的安全策略
  7. 月度/終身額度追蹤 + JSON 持久化
  觸發信號：API proxy 開發、額度管理、free tier quota、帳號保護、硬停線。
  See also: api-security-audit-methodology（安全審計）、api-pool-token-pricing-methodology（代幣定價）
version: 1.0.0
date: 2026-02-11
---

# API Proxy 額度硬停線架構模式

## Problem

API 代理/市集服務持有大量外部 API Key（免費帳號），這些帳號都有額度限制。如果不設硬停線：
- 免費帳號額度用光 → 帳號被封鎖 → 所有依賴該 Key 的用戶受影響
- 付費 API（如 Anthropic）額度失控 → 直接虧錢
- 完全免費 API（如 Wikipedia）被濫用 → 被上游 ban IP

**實證數據：** 和心村 API 代購市集初期只有 8/18 個服務有額度追蹤，免費服務完全沒有額度檢查。

## Context / Trigger Conditions

- 正在建立 API proxy / marketplace 服務
- 系統對接多個上游 API，混合免費與付費
- 需要「額度不能完全耗盡」的安全策略
- 發現某些服務路徑沒有經過額度檢查
- 用戶說「帳號會不會被封」「要加限制」

## Solution

### 一、三層防護架構

```
Layer 1: CONFIG（定義限額）
    FREE_TIER_QUOTAS = { serviceId: { limit, unit, period, safetyPct } }
    ↓
Layer 2: MIDDLEWARE（攔截請求）
    checkFreeTierQuota(serviceId) → null = 放行 | string = 拒絕理由
    ↓
Layer 3: ENDPOINT（記錄使用量）
    recordQuotaUsage(serviceId, amount) → 成功回應前記錄
```

**關鍵設計決策：**
- `checkFreeTierQuota` 在請求**前**攔截（中間件層）
- `recordQuotaUsage` 在**成功回應前**記錄（端點層）
- 失敗的請求不計入額度（因為沒有消耗上游資源）

### 二、Config 層設計

```typescript
const FREE_TIER_QUOTAS: Record<string, {
  limit: number;       // 上游原始限額
  unit: string;        // 'requests' | 'chars' | 'pages'
  period: 'monthly' | 'lifetime';
  safetyPct: number;   // 有效限額 = limit * safetyPct
}> = {
  // ── 有帳號額度的 API（必須嚴格管控）──
  deepl:     { limit: 500000, unit: 'chars', period: 'monthly', safetyPct: 0.90 },
  groq:      { limit: 300000, unit: 'requests', period: 'monthly', safetyPct: 0.80 },

  // ── 用自己 API Key 的服務（有真實成本！）──
  generate:  { limit: 10000, unit: 'requests', period: 'monthly', safetyPct: 0.90 },

  // ── 無帳號 API（防濫用）──
  weather:   { limit: 100000, unit: 'requests', period: 'monthly', safetyPct: 0.90 },
};
```

**safetyPct 設定原則：**
| 上游特性 | safetyPct | 原因 |
|---------|-----------|------|
| 嚴格日限（如 Groq 14400/天） | 0.80 | 日限 → 月度計算有誤差，多留緩衝 |
| 寬鬆月限（如 DeepL 50 萬字/月） | 0.90 | 標準 10% 安全緩衝 |
| 終身限額（如 Firecrawl 500 頁） | 0.90 | 用完不可恢復，但 10% 足夠 |
| 有真實成本 | 0.90 | 成本可控，不需要額外緩衝 |

### 三、服務分類（三類管控策略）

| 類別 | 範例 | 成本 | 額度策略 |
|------|------|------|---------|
| **有帳號額度** | DeepL, Groq, Tavily, Brave | $0（免費帳號） | 嚴格管控，到 safetyPct 就停 |
| **用自己 Key** | Anthropic generate/vision | 真實 $$$ | 最嚴格，limit 直接對應成本上限 |
| **無帳號 API** | Weather, Wikipedia, IP-Geo | $0 | 防濫用為主，limit 設大一些 |

### 四、常見遺漏（坑）

#### 坑 1：免費服務路徑沒有額度檢查

```typescript
// ❌ 錯誤：免費服務只有 rate limit，沒有額度檢查
if (revenue === 0) {
  if (!recordUsage(...)) return 429;
  await next();  // 直接放行！
  return;
}

// ✅ 正確：免費服務也需要額度檢查
if (revenue === 0) {
  if (!recordUsage(...)) return 429;
  const quotaError = checkFreeTierQuota(serviceId);
  if (quotaError) return 429;
  await next();
  return;
}
```

**為什麼容易遺漏：** 因為免費服務「不收錢」，直覺上不需要額度管控。但上游有限額！

#### 坑 2：char-based 服務需要在端點層檢查

```typescript
// 中間件無法知道 text 長度，所以 char-based 服務跳過中間件檢查
const charBasedQuotas = ['deepl', 'elevenlabs'];
if (!charBasedQuotas.includes(serviceId)) {
  checkFreeTierQuota(serviceId);  // request-based 在此檢查
}

// char-based 在端點層檢查：
const quotaError = checkFreeTierQuota('deepl', text.length);
if (quotaError) { refund(); return 429; }
// ... 執行 API 呼叫 ...
recordQuotaUsage('deepl', text.length);
```

#### 坑 3：recordQuotaUsage 只在成功時調用

```typescript
// ✅ 正確：只有成功回應前才記錄
try {
  const result = await callUpstreamAPI();
  recordQuotaUsage('groq');  // 成功才記錄
  return c.json({ success: true, ... });
} catch (err) {
  autoRefund(c, 'groq');
  return c.json({ success: false, ... });  // 失敗不記錄
}
```

#### 坑 4：多成功路徑都要記錄

```typescript
// Wikipedia 有兩個成功路徑：直接查詢 + 搜尋 fallback
if (!res.ok) {
  // 搜尋 fallback
  const results = await searchWikipedia(query);
  recordQuotaUsage('wikipedia');  // 路徑 1
  return c.json({ type: 'search', results });
}
const summary = await res.json();
recordQuotaUsage('wikipedia');  // 路徑 2
return c.json({ type: 'summary', ... });
```

### 五、持久化設計

```typescript
interface QuotaUsage {
  monthly: Record<string, Record<string, number>>;  // { "2026-02": { groq: 1234 } }
  lifetime: Record<string, number>;                   // { firecrawl: 200 }
  lastUpdated: string;
}
// 儲存到 JSON 檔案，每次 recordQuotaUsage 後寫入
```

**月度自動重置：** 用 `YYYY-MM` 作為 key，不同月份自動開新計數器。

## Verification

```bash
# 1. 確認所有服務都在 FREE_TIER_QUOTAS 中
grep -c "limit:" src/api/proxy-handler.ts  # 預期 = 服務總數

# 2. 確認所有端點都有 recordQuotaUsage
grep -c "recordQuotaUsage" src/api/proxy-handler.ts  # 預期 >= 服務數

# 3. 確認免費服務中間件有 checkFreeTierQuota
grep -A5 "revenue === 0" src/api/proxy-handler.ts | grep "checkFreeTierQuota"

# 4. TS 無錯誤
bunx tsc --noEmit
```

## Example

**和心村 API 代購市集（2026-02-11）：**

```
初始狀態：8/18 服務有額度追蹤
├─ 免費服務（4個）：完全沒有額度檢查
├─ 付費服務中的 groq/mistral/gemini：沒有額度追蹤
├─ generate/vision（有真實成本）：沒有額度追蹤
└─ scrape（直接 fetch）：沒有額度追蹤

修復後：18/18 服務全覆蓋
├─ FREE_TIER_QUOTAS 新增 10 個服務
├─ 免費服務中間件新增 checkFreeTierQuota()
├─ 所有端點新增 recordQuotaUsage()（21 個調用點）
└─ 1 個 commit, 36 insertions, 1 deletion
```

## Notes

### 額度數值設定參考

| 服務 | 上游限額 | 我們的 limit | safetyPct | 有效限額 |
|------|---------|-------------|-----------|---------|
| Groq | 14400/天(~432K/月) | 300K | 0.80 | 240K |
| DeepL | 50 萬字元/月 | 500K | 0.90 | 450K |
| Mistral | 10 億 tokens/月 | 200K req | 0.90 | 180K |
| Gemini | 大方(Ultra) | 100K | 0.90 | 90K |
| Generate | 無限(付費) | 10K | 0.90 | 9K($20) |
| Vision | 無限(付費) | 5K | 0.90 | 4.5K($15) |
| Weather | 無限(免費) | 100K | 0.90 | 90K |

### 與安全審計的關係

額度管理不只是成本控制，也是安全防線：
- 防止攻擊者大量消耗上游資源（資源耗盡攻擊）
- 防止單一 Agent 壟斷所有額度
- 額度追蹤提供異常偵測的基礎數據

See also: `api-security-audit-methodology`（完整安全審計方法論）

## References

- [Hono Middleware Documentation](https://hono.dev/docs/guides/middleware)
- [OWASP API Security - Resource Limiting](https://owasp.org/API-Security/editions/2023/en/0xa4-unrestricted-resource-consumption/)
