---
name: api-security-audit-methodology
description: |
  API 後端安全審計的完整方法論，含 30+ 個漏洞模式 + 多輪迭代審查策略 + multi-agent cross-verification + 共用安全模組模式。
  使用時機：
  1. API 代理/市集服務上線前安全審查（Hono、Express、Fastify 等）
  2. 發現 SSRF、XSS、錯誤資訊洩漏等漏洞需要系統化修復
  3. 單次審查找不到所有問題，需要多輪迭代策略（至少 3 輪）
  4. 用戶說「檢查安全」「會不會被駭」「上線前再看看」
  5. 需要多個 AI（Claude + Codex + Gemini）交叉驗證安全問題
  6. Server-rendered HTML 的 Stored XSS 防禦（Admin + Public 頁面都需要 esc()）
  7. SSRF 完整防護（302 redirect bypass、IPv4-mapped IPv6、DNS rebinding、cloud metadata）
  8. 錯誤訊息洩漏上游 API 細節（err.message 直接暴露）
  9. 中間件順序 DoS（recordUsage 在 preCharge 之前 → 空帳號刷爆全域 rate limit）
  10. 服務停用路由陷阱（從服務登記移除 → 中間件 404 擋住優雅降級端點 410）
  11. 字元型免費額度一次耗盡攻擊（DeepL 50萬字/月 → 單次請求無長度限制 → 一次吃光）
  12. upstream error text 未截斷 → log 膨脹 + 資訊洩漏
  13. 密碼/密鑰比對用 === → timing attack 繞過
  14. Rate limit 依賴 x-forwarded-for → IP 偽造繞過
  15. Stripe metadata 存 API Key → webhook 外洩
  觸發信號：上線前審查、安全加固、API proxy 開發、外部 Key 管理系統。
  16. 無限推薦裂變鏈（referral/MLM 無深度限制 → 1 碼 3^N 帳戶指數爆炸）
  17. Admin 密碼接受 URL query string（c.req.query('admin_key') → 密碼記錄到存取日誌）
  18. PROXY_ADMIN_KEY 空值 safeCompare（env 未設 || '' → 空字串比對可能通過）
  19. Admin middleware 信任 x-forwarded-for 做暴力防護 IP（攻擊者偽造 XFF 繞過鎖定）
  觸發信號：上線前審查、安全加固、API proxy 開發、外部 Key 管理系統、推薦碼/MLM 經濟系統。
  See also: security-for-non-engineers（非工程師安全說明）、parallel-quality-audit-workflow（通用品質審查）、token-economics-audit-methodology（Token 經濟審計）
  20. Server-rendered `<script>` 標籤中嵌入用戶資料時，`replace(/'/g, "\\'")` 不夠 → `</script>` 注入繞過
  21. 完整 API Key 注入到 DOM（page source 可見）→ 返回遮罩版本
  觸發信號：上線前審查、安全加固、API proxy 開發、外部 Key 管理系統、推薦碼/MLM 經濟系統、Server-Rendered HTML inline script。
  See also: security-for-non-engineers（非工程師安全說明）、parallel-quality-audit-workflow（通用品質審查）、token-economics-audit-methodology（Token 經濟審計）、template-literal-inline-js-escaping（模板字面量 JS 轉義）
version: 1.3.0
date: 2026-02-18
---

# API 安全審計方法論

## Problem

API 後端服務（特別是代理/市集類型）通常持有大量外部 API Key、使用者帳戶餘額、管理員憑證等敏感資料。單次安全審查往往只能發現 60-70% 的漏洞。即使使用最強 AI 模型，每輪審查仍會遺漏問題。

**實證數據：** 和心村 API 代購市集經過 9 輪審查，每輪都發現前輪遺漏的新問題，共找到 50+ 個安全漏洞。

**關鍵發現（2026-02-12 實戰）：** 多輪迭代審計是必須的，不是可選的。一次審查絕對找不完所有問題：
- 第 1 輪：基礎問題（crypto.randomBytes、URL 不放密碼）
- 第 2 輪：深度代碼問題（Host header bypass、file write race、memory limits）
- 第 3 輪：最終掃描才發現的（timingSafeEqual、SSRF 完整封鎖、CSP）
每一輪都能找到上一輪遺漏的問題。

## Context / Trigger Conditions

- API proxy / marketplace 服務即將上線
- 系統持有第三方 API Keys（Anthropic、OpenAI、Groq 等）
- Server-rendered HTML（非 SPA 框架）的 Admin / Public 頁面
- 使用 `fetch()` 代理外部請求（SSRF 風險）
- 有帳戶餘額系統（信用經濟）
- 用戶說「這個安全嗎」「上線前幫我看看」「會不會被駭」

## Solution

### 一、多輪迭代審查策略（最少 3 輪，理想 5 輪）

**核心發現：單次審查不夠，每輪都會有遺漏。**

**最少 3 輪策略（2026-02-12 實戰驗證）：**

```
Round 1: 基礎安全掃描
    → crypto.randomBytes 取代 Math.random
    → URL/環境變數不放密碼
    → 基本 SSRF 防護（127.0.0.1、10.x）
    → 基本 XSS 防護（escapeHtml）
    → 發現 70% 的 CRITICAL 問題

Round 2: 深度代碼審查
    → Host header bypass 修復
    → File write race conditions
    → Memory limits 檢查
    → Middleware 順序問題
    → 發現 20% 的 HIGH 問題（邏輯層面）

Round 3: 最終安全掃描（Sub-Agent 新 context）
    → timingSafeEqual 取代 === 比對密碼/密鑰
    → SSRF 完整封鎖（IPv6、cloud metadata、編碼繞過）
    → CSP + HSTS headers
    → Error message 不洩漏內部資訊
    → Rate limit IP 來源用 server.requestIP 而非 header
    → 發現 10% 的 MEDIUM/HIGH 問題（細節層面）
```

**理想 5 輪策略（更大型專案）：**

```
Round 1-3: （同上）
Round 4: 全 Opus 模型 3 並行 Agents
    → 邏輯漏洞（redirect bypass、path injection）
    → 商業邏輯問題（double refund、race conditions）
Round 5: multi-agent cross-verification（Claude + Codex + Gemini）
    → 每個 AI 找到其他兩個沒看到的問題
```

**關鍵：每輪修復後，重新審查修復本身有沒有引入新問題。**

**從 B- 升到 A- 的關鍵修復清單：**
- ✅ timingSafeEqual（密碼/金鑰比對防 timing attack）
- ✅ SSRF 完整封鎖（IPv6、cloud metadata、編碼繞過）
- ✅ Rate limit IP 來源用 requestIP 而非 x-forwarded-for
- ✅ CSP + HSTS headers
- ✅ Error message 不洩漏內部資訊
- ✅ Stripe metadata 不放 API Key

### 二、共用安全模組模式（2026-02-12 新增）

**核心發現：重複的安全邏輯應該立即提取為共用模組，避免遺漏和不一致。**

**實戰經驗：** 今晚發現多處需要 timingSafeEqual、SSRF 檢查、API Key 提取等重複邏輯，若每處手寫容易有遺漏。

#### 推薦共用模組清單

| 模組 | 用途 | 範例檔名 |
|------|------|---------|
| **安全比對** | 密碼/金鑰比對防 timing attack | `safe-compare.ts` |
| **SSRF 防護** | 完整 SSRF 封鎖清單（IP、域名、協議） | `ssrf-guard.ts` |
| **API Key 提取** | 統一處理多來源 API Key（header、body、query） | `extract-api-key.ts` |
| **輸入消毒** | 統一 sanitize 用戶輸入 | `sanitize.ts` |
| **安全錯誤處理** | 過濾錯誤訊息防資訊洩漏 | `safe-error.ts` |
| **數值驗證** | 防止 NaN/Infinity 注入 | `safe-number.ts` |

#### 實作範例

```typescript
// safe-compare.ts — 防 timing attack 的安全比對
import { timingSafeEqual } from 'crypto';

export function safeCompare(a: string, b: string): boolean {
  if (typeof a !== 'string' || typeof b !== 'string') return false;
  if (a.length !== b.length) return false;

  const bufA = Buffer.from(a, 'utf8');
  const bufB = Buffer.from(b, 'utf8');

  try {
    return timingSafeEqual(bufA, bufB);
  } catch {
    return false;
  }
}

// ssrf-guard.ts — 完整 SSRF 封鎖
export function validateUrlSafety(url: string): string | null {
  try {
    const parsed = new URL(url);

    // 1. 只允許 http/https
    if (!['http:', 'https:'].includes(parsed.protocol)) {
      return `Dangerous protocol: ${parsed.protocol}`;
    }

    // 2. 黑名單域名
    const hostname = parsed.hostname.toLowerCase();
    const blockedDomains = [
      'localhost', '127.0.0.1', '0.0.0.0',
      'metadata.google.internal',
      '169.254.169.254', // AWS/GCP metadata
      // DNS rebinding 域名
      '.nip.io', '.sslip.io', '.xip.io'
    ];

    for (const blocked of blockedDomains) {
      if (hostname === blocked || hostname.endsWith(blocked)) {
        return `Blocked domain: ${hostname}`;
      }
    }

    // 3. IPv4 私有範圍
    if (/^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.)/.test(hostname)) {
      return `Private IPv4: ${hostname}`;
    }

    // 4. IPv6（含 ::ffff: mapped）
    if (hostname.includes(':')) {
      const normalized = normalizeIPv6(hostname);
      if (normalized.startsWith('::1') ||
          normalized.startsWith('::ffff:127') ||
          normalized.startsWith('::ffff:10') ||
          normalized.startsWith('::ffff:172') ||
          normalized.startsWith('::ffff:192.168') ||
          normalized.startsWith('fc') ||
          normalized.startsWith('fe80')) {
        return `Private IPv6: ${normalized}`;
      }
    }

    return null; // 安全
  } catch (e) {
    return `Invalid URL: ${e.message}`;
  }
}

// extract-api-key.ts — 統一 API Key 提取
export function extractApiKey(c: Context): string | null {
  // 1. Authorization header
  const authHeader = c.req.header('Authorization');
  if (authHeader?.startsWith('Bearer ')) {
    return authHeader.substring(7);
  }

  // 2. X-API-Key header
  const apiKeyHeader = c.req.header('X-API-Key');
  if (apiKeyHeader) return apiKeyHeader;

  // 3. Body (POST/PUT)
  const body = c.req.valid('json') as any;
  if (body?.apiKey) return body.apiKey;

  // 4. Query (GET)
  const query = c.req.query('apiKey');
  if (query) return query;

  return null;
}

// safe-number.ts — 防止 NaN/Infinity 注入
export function safeNum(val: unknown, def: number, min: number, max: number): number {
  const n = typeof val === 'number' ? val : Number(val);
  if (!Number.isFinite(n)) return def;
  return Math.min(Math.max(n, min), max);
}

// 浮點數金額的低風險修復（不改資料格式）
export function roundUSD(n: number): number {
  return Math.round(n * 1_000_000) / 1_000_000;
}
```

**使用模式：**
```typescript
// 所有需要比對密碼的地方
import { safeCompare } from '@/utils/safe-compare';
if (!safeCompare(inputPassword, storedPassword)) { ... }

// 所有接受 URL 的端點
import { validateUrlSafety } from '@/utils/ssrf-guard';
const error = validateUrlSafety(userProvidedUrl);
if (error) return c.json({ error }, 400);
```

### 三、30+ 個漏洞模式速查表

#### SSRF（Server-Side Request Forgery）完整防護

| 繞過技巧 | 檢查方式 | 防禦 |
|---------|---------|------|
| 直接內部 IP | `127.0.0.1`, `10.x`, `172.16-31.x`, `192.168.x` | IP 範圍黑名單 |
| localhost 別名 | `0177.0.0.1`, `0x7f.0.0.1`, `2130706433` | 所有格式都擋 |
| IPv6 | `::1`, `fc00::/7`, `fe80::/10` | IPv6 檢查 |
| **IPv4-mapped IPv6** | `::ffff:127.0.0.1`, **`::ffff:172.16.x`** | **容易遺漏！** |
| 302 Redirect | 請求合法 URL → 302 到內部 IP | `redirect: 'manual'` |
| DNS Rebinding | 第一次解析合法 → 第二次解析內部 | Cloudflare 代理 |
| Cloud Metadata | `169.254.169.254`, `metadata.google.internal` | 明確擋 |
| 危險協議 | `file://`, `ftp://`, `gopher://`, `data:` | 只允許 http/https |

**最佳實踐：抽取 `validateUrlSafety()` 共用函數，所有 URL 入口都呼叫。**

```typescript
function validateUrlSafety(url: string): string | null {
  // 1. 解析 URL（失敗 = 拒絕）
  // 2. 檢查協議（只允許 http/https）
  // 3. 檢查 hostname 黑名單（含別名）
  // 4. 檢查 IPv4 私有範圍
  // 5. 檢查 IPv6（含 ::ffff: mapped）
  // 6. 回傳 null = 安全，字串 = 拒絕理由
}
```

#### Stored XSS 防禦（Server-Rendered HTML）

| 問題 | 解法 |
|------|------|
| Server 端輸出用戶資料 | `escapeHtml()` 處理 `& < > " '` |
| Client 端 DOM 插入 | `document.createTextNode()` 而非 innerHTML |
| **每個獨立 HTML 頁面** | **都需要自己的 `esc()` 函數定義！** |
| 雙重 escape | 已 escape 的資料不要再 escape |
| **`<script>` 標籤中嵌入值** | **`escapeJsString()` — 不能只 escape 單引號！** |
| **完整 API Key 注入 DOM** | **用遮罩版本 `wv_xxxx...last4`** |

**常見遺漏：** Admin 頁面有 `esc()`，但 Public Join 頁面忘了加。

#### `<script>` 標籤內嵌值的 XSS 防禦（2026-02-18 新增）

**問題：** Server-rendered HTML 中 `<script>` 標籤內嵌入用戶資料時，只用 `replace(/'/g, "\\'")` 是不夠的。

**攻擊向量：**
```
用戶名 = "test</script><script>alert(1)//"
↓ replace(/'/g, "\\'") 不處理 </script> 標籤
↓ 生成的 HTML：
<script>
  var userName = 'test</script><script>alert(1)//';
</script>
↓ 瀏覽器解析時 </script> 結束第一個腳本塊
↓ 第二個 <script>alert(1)//... 被執行 → XSS！
```

**為什麼 `replace(/'/g, "\\'")` 不夠：**
1. 只處理單引號 — 缺少 `</script>` 閉合標籤注入
2. 缺少反斜線轉義 — `\'` 可被 `\\` 反消
3. 缺少換行、Tab、Unicode 等特殊字元處理

**正確解法 — `escapeJsString()`：**
```typescript
/** JS 字串轉義 — 安全嵌入 <script> 標籤（防 </script> 注入 + XSS） */
function escapeJsString(s: string): string {
  // JSON.stringify 處理所有特殊字元：引號、反斜線、換行、Tab、Unicode
  const inner = JSON.stringify(s).slice(1, -1);
  // 額外防禦：</script> 標籤閉合注入
  return inner.replace(/<\//g, '<\\/');
}
```

**為什麼 `JSON.stringify().slice(1,-1)` 有效：**
- `JSON.stringify("a'b\"c")` → `"a'b\"c"` — 自動轉義引號
- `JSON.stringify("a\\b")` → `"a\\\\b"` — 自動轉義反斜線
- `JSON.stringify("a\nb")` → `"a\\nb"` — 自動轉義換行
- `.slice(1, -1)` — 去掉外層雙引號，得到安全的字串內容
- `.replace(/<\//g, '<\\/')` — `</` 變成 `<\/`，防止 `</script>` 注入

**使用範例：**
```typescript
// Server-rendered HTML 模板中：
const html = `
<script>
  var __state = {
    userName: '${escapeJsString(userName)}',
    apiKey: '${escapeJsString(maskedApiKey)}'
  };
</script>`;
```

**附加安全措施 — API Key 遮罩：**
```typescript
// ❌ 危險：完整 API Key 注入 DOM（page source 可見）
existingApiKey = acct.api_key;

// ✅ 安全：只顯示遮罩版本
existingApiKey = acct.api_key.slice(0, 7) + '...' + acct.api_key.slice(-4);
// 結果："wv_xxxx...ab12"
```

#### 錯誤資訊洩漏

| 問題 | 解法 |
|------|------|
| `catch(err) { return err.message }` | 上游 API 錯誤暴露給用戶 |
| 解法 | `safeError()` 只允許已知安全的模式通過 |

```typescript
function safeError(err: unknown): string {
  const msg = err instanceof Error ? err.message : 'Unknown error';
  // 只允許通用模式（「Service unavailable」「Rate limited」）
  // 阻擋含 API key、內部路徑、堆疊追蹤的訊息
  const safePatterns = [/rate limit/i, /timeout/i, /unavailable/i, ...];
  for (const p of safePatterns) { if (p.test(msg)) return msg; }
  return 'Service temporarily unavailable'; // 預設安全回應
}
```

#### 其他重要模式

| # | 漏洞 | 解法 |
|---|------|------|
| 1 | Admin header auth bypass | 移除 header auth，只用 HttpOnly session cookie |
| 2 | Admin fail-open（未設密碼=開放） | 未設密碼 → `process.exit(1)` |
| 3 | `Math.random()` 生成 API Key | `crypto.randomBytes(24).toString('base64url')` |
| 4 | Path injection（voiceId） | 正則驗證 `/^[a-zA-Z0-9]{5,50}$/` |
| 5 | Deposit Infinity / NaN | `isFinite(amount) && amount > 0 && amount <= 1000` |
| 6 | 無 double-refund 防護 | `Set<string>` 追蹤已退款 chargeId |
| 7 | URL 參數注入（weather/exchange） | 數值用 `Number()` + 範圍驗證，貨幣用 `/^[A-Z]{3}$/` |
| 8 | 業務端點無 auth（/usage） | 檢查每個端點是否需要認證 |
| 9 | 帳戶名無長度限制 | `name.trim().length <= 100` |
| 10 | audit limit NaN | `parseInt` 結果 NaN 時 fallback 預設值 |
| **11** | **密碼/金鑰用 === 比對** | **`crypto.timingSafeEqual()` 防 timing attack** |
| **12** | **Rate limit 依賴 x-forwarded-for** | **用 Bun `server.requestIP(req)` 取得真實 IP** |
| **13** | **Stripe metadata 存 API Key** | **絕不放敏感資料到 metadata（webhook 可見）** |
| **14** | **浮點數金額精度問題** | **運算後 `roundUSD()`，不改資料格式** |
| **15** | **缺少 CSP + HSTS headers** | **`helmet()` middleware 或手動設定** |
| **16** | **推薦碼/MLM 無深度限制** | **`generation` 欄位追蹤世代深度 + `maxGeneration` 限制** |
| **17** | **Admin 密碼接受 query string** | **只從 `header('x-admin-key')` 讀取，刪除 `query('admin_key')`** |
| **18** | **env 未設 `\|\| ''` 空字串比對** | **先 `if (!ENV_VAR) return 403`，再 `safeCompare`** |
| **19** | **Admin IP 用 XFF 做暴力防護** | **Admin middleware 只用 `requestIP()` + `CF-Connecting-IP`** |
| **20** | **`<script>` 內嵌值只 escape 單引號** | **`escapeJsString()` 用 `JSON.stringify` — 防 `</script>` 注入** |
| **21** | **完整 API Key 注入 DOM** | **用遮罩版本（`key.slice(0,7)+'...'+key.slice(-4)`）** |

#### Bun Server 專屬模式（2026-02-12）

**問題：** Hono `c.req.header('x-forwarded-for')` 可被偽造，Rate limiting 會失效。

**解法：** 在 Bun `export default` entry point 用 `server.requestIP(req)` 取得真實 IP，傳遞給 Hono。

```typescript
// index.ts — Bun entry point
export default {
  fetch(req: Request, server: any) {
    const ip = server?.requestIP?.(req);
    return app.fetch(req, {
      remoteIP: ip?.address || 'unknown'
    });
  }
};

// middleware.ts — Hono middleware
app.use('*', async (c, next) => {
  const realIP = c.env.remoteIP as string;
  // 用 realIP 做 rate limiting，而非 x-forwarded-for
  await next();
});
```

**為什麼重要：**
- x-forwarded-for header 可被用戶偽造 → 繞過 rate limit
- Bun `server.requestIP()` 是 native API → 從 TCP 層取得真實 IP
- 這是 Bun 和 Hono 兩層架構的正確整合方式

### 三之二、經濟系統紅隊攻擊模式（2026-02-18 新增）

**核心發現：** 推薦碼/MLM/裂變系統的「金額限制」和「次數限制」不夠，必須有**深度限制**。

#### 無限推薦裂變鏈攻擊

```
攻擊：1 顆 $100 種子碼 → 3 個帳戶（Gen1）→ 9 個（Gen2）→ 27 個（Gen3）→ ...
結果：$100 投入 → 3^N 帳戶 → 理論上無限 USDC
```

**防禦模式：generation 世代追蹤**
```sql
-- DB migration：新增 generation 欄位
ALTER TABLE invitations ADD COLUMN generation INTEGER NOT NULL DEFAULT 0;
-- 0=Admin 種子碼, 1=第一代, 2=第二代...
```

```typescript
// 兌換時：讀取世代 → 限制深度
const currentGen = invite.generation ?? 0;
const maxGen = getConfig('max_generation', 3);
if (currentGen + 1 > maxGen) {
  // 不產碼（切斷鏈條），但仍可兌換獲得餘額
  log.info(`世代上限 ${maxGen}，不再產碼`);
}
```

#### Admin 端點數值注入三件套

| 攻擊 | 為什麼繞過 | 正確防禦 |
|------|----------|---------|
| `creditAmount: "NaN"` | `Number("NaN")` → NaN 通過 `typeof === 'number'` | `Number.isFinite(val)` |
| `creditAmount: "Infinity"` | 通過 `> 0` 檢查 | `Number.isFinite(val)` |
| `creditAmount: 0.0001` | 通過 `> 0` 但低於最小有意義金額 | 明確最低額 `>= 0.01` |

**關鍵：** 靜默 fallback（`val || defaultVal`）比直接拒絕更危險 — 攻擊者不知道被擋了什麼。

#### 環境變數空值 safeCompare

```typescript
// ❌ 危險：PROXY_KEY 未設定 → safeCompare(userInput, '')
if (adminKey && safeCompare(adminKey, process.env.PROXY_KEY || '')) { ... }

// ✅ 安全：先檢查 env 存在
const KEY = process.env.PROXY_KEY;
if (adminKey && KEY && safeCompare(adminKey, KEY)) { ... }
```

### 四、multi-agent cross-verification方法（仍然有效）

```bash
# 1. Claude Code（orchestrator自己）— 架構 + 邏輯審查
# 手動逐個端點檢查，特別是修復後新引入的問題

# 2. Codex（OpenAI）— 程式碼層面 SSRF + 邊界值
codex exec "以安全研究員角色審查 src/api/proxy-handler.ts，
  找出 SSRF 繞過（含 IPv4-mapped IPv6）、
  邊界值問題、競態條件" --skip-git-repo-check --sandbox read-only

# 3. Gemini（Google）— 商業邏輯 + 未保護端點
gemini -p "審查 src/api/proxy-handler.ts 的商業邏輯安全：
  所有端點是否都有適當認證？
  有沒有可以繞過付費的路徑？"
```

**每個 AI 都有盲點：**
- Claude：容易漏掉 `::ffff:172.x` 這種組合格式
- Codex：找到 Claude 漏掉的 IPv6 mapped 問題
- Gemini：找到 `/usage` 端點未認證（商業邏輯問題）

### 五、驗證腳本模板

```bash
# SSRF 測試
curl -s -X POST http://localhost:3000/api/proxy/scrape \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"url":"http://127.0.0.1:3000/admin"}' | jq .error

# XSS 測試
curl -s -X POST http://localhost:3000/admin/join/apply \
  -H "Content-Type: application/json" \
  -d '{"name":"<script>alert(1)</script>","contact":"test"}'
# 檢查 response 中 < 變成 &lt;

# 錯誤洩漏測試
curl -s -X POST http://localhost:3000/api/proxy/groq \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"messages":[]}' | jq .error
# 不應包含上游 API 的錯誤細節

# 暴力破解防護
for i in {1..5}; do
  curl -s -X POST http://localhost:3000/admin/login \
    -H "Content-Type: application/json" \
    -d '{"password":"wrong"}'
done
# 第 4 次應回傳 429

# 無 auth 端點掃描
for endpoint in /health /usage /services; do
  echo "--- $endpoint ---"
  curl -s http://localhost:3000/api/proxy$endpoint | head -100
done
```

## Verification

1. **全掃明文 Key：** `grep -c "gsk_\|sk-\|AIza\|BSA\|tvly-\|fc-\|CG-" data/key-store/services.json` → 0
2. **Admin 無 header bypass：** `curl -H "x-admin-password: xxx" /admin/api/services` → 401
3. **所有 catch 無 err.message：** `grep -c "err\.message\|error\.message" src/api/*.ts` → 0（只有 safeError 內部使用）
4. **SSRF 全路徑防護：** 測試 localhost、127.0.0.1、::1、::ffff:127.0.0.1、169.254.169.254
5. **XSS 兩頁都防護：** Admin HTML 和 Join HTML 都有 `esc()` 函數

## Example

**和心村 API 代購市集安全審計實績（2026-02-11）：**

```
初始狀態：安全評分 1.4/10
├─ 11+ 外部 API Key 明文儲存
├─ Admin 密碼可被 header bypass
├─ 無 SSRF 防護
├─ 無 XSS 防護
└─ 無 rate limiting

5 輪審查後：安全評分 ~8/10
├─ Round 1-2: 基礎加密 + 認證修復（Phase 1-4 計畫）
├─ Round 3: 6 個問題（SSRF 不完整、err.message、deposit Infinity）
├─ Round 4: 9 個問題（302 redirect bypass、Math.random、path injection）
├─ Round 5: 2 個問題（::ffff:172.x、/usage 無 auth）
└─ 總計：25 個漏洞全部修復

3 次 commit：b785239 → c54765f → 25b00e3
修改檔案：api-proxy.ts、admin-ui.ts、billing.ts
```

**Production API Platform 最終安全掃描（2026-02-12）：**

```
起點：安全評分 B-（70/100）
├─ Round 1: 基礎掃描（crypto.randomBytes、URL 不放密碼）
├─ Round 2: 深度審查（Host header bypass、file write race）
└─ Round 3: 最終掃描（Sub-Agent 新 context）
    └─ 發現 6 個 MEDIUM/HIGH 問題：
        1. timingSafeEqual（密碼比對 timing attack）
        2. SSRF 完整封鎖（IPv6、cloud metadata、編碼繞過）
        3. Rate limit 用 requestIP 而非 x-forwarded-for
        4. CSP + HSTS headers
        5. Error message 不洩漏內部資訊
        6. Stripe metadata 不放 API Key

結果：安全評分 A-（85/100）
修復檔案：src/utils/safe-compare.ts、src/utils/ssrf-guard.ts、index.ts（Bun entry）
共用模組：4 個（safeCompare、validateUrlSafety、extractApiKey、roundUSD）
關鍵發現：Bun server.requestIP() 是取得真實 IP 的正確方式
```

**從 B- 升到 A- 的 6 個關鍵修復：**
1. ✅ timingSafeEqual 取代 === 比對（防 timing attack）
2. ✅ SSRF 完整封鎖（IPv6、cloud metadata、DNS rebinding）
3. ✅ Rate limit IP 來源用 Bun requestIP（不可偽造）
4. ✅ CSP + HSTS headers
5. ✅ Error message 不洩漏內部資訊
6. ✅ Stripe metadata 不放敏感資料

**共用安全模組模式成效：**
- 重複邏輯提取為 4 個共用模組
- 避免手寫導致的遺漏和不一致
- 未來新功能直接 import，不需重複審查

## Notes

### 常見遺漏排名

1. **IPv4-mapped IPv6**（`::ffff:172.16.x`）— 4 輪都沒抓到，第 5 輪才被 Codex 發現
2. **IPv6 未壓縮格式**（`0:0:0:0:0:ffff:7f00:1`）— 即使修了 `::ffff:` 也會被繞過，需要 `normalizeIPv6()` 先標準化
3. **DNS rebinding 域名**（`*.nip.io`, `*.sslip.io`, `*.xip.io`）— 解析到內部 IP 的公開域名
4. **NaN/Infinity 數值注入** — `Math.min(NaN, 8192)` = `NaN` 直接傳到上游 API，需要 `safeNum()` helper
5. **Public 頁面的 esc() 函數** — Admin 有但 Join 頁面忘了加
6. **302 Redirect SSRF bypass** — 即使 URL 檢查通過，fetch 會跟隨 redirect 到內部 IP
7. **API Key 放 URL query string** — CDN/WAF/日誌會記錄 URL，Key 易外洩
8. **Set.clear() 雙退款窗口** — refundedCharges 一次清空 = 舊 chargeId 可重新退款
9. **Math.random() 用於安全用途** — 看起來像隨機但不是密碼學安全
10. **`<script>` 標籤內嵌值只 escape 單引號** — `replace(/'/g, "\\'")` 漏掉 `</script>` 注入 + 反斜線反消 + Unicode → 用 `JSON.stringify().slice(1,-1).replace(/<\//g, '<\\/')`
11. **完整 API Key 注入 page source** — 回訪用戶的 server-rendered HTML 直接含完整 Key → 改用遮罩版本

### 部署前仍需處理（超出代碼審計範圍）

- DNS rebinding → Cloudflare 代理
- X-Forwarded-For 信任 → 反向代理配置
- CSP headers → 需重構 inline scripts
- Race condition → mutex（多進程時）

### 防禦工具函數模板（R11 驗證有效）

```typescript
// IPv6 標準化（防止未壓縮格式繞過 SSRF 檢查）
function normalizeIPv6(addr: string): string {
  let norm = addr.replace(/^\[|\]$/g, '').toLowerCase();
  if (norm.includes('::')) {
    const parts = norm.split('::');
    const left = parts[0] ? parts[0].split(':') : [];
    const right = parts[1] ? parts[1].split(':') : [];
    const middle = Array(Math.max(0, 8 - left.length - right.length)).fill('0');
    norm = [...left, ...middle, ...right].map(g => g || '0').join(':');
  }
  const groups = norm.split(':');
  if (groups.length !== 8) return addr;
  if (groups.every(g => parseInt(g, 16) === 0)) return '::';
  if (groups.slice(0, 7).every(g => parseInt(g, 16) === 0) && parseInt(groups[7], 16) === 1) return '::1';
  if (groups.slice(0, 5).every(g => parseInt(g, 16) === 0) && parseInt(groups[5], 16) === 0xffff) {
    return `::ffff:${groups[6]}:${groups[7]}`;
  }
  return groups.map(g => g.replace(/^0+/, '') || '0').join(':');
}

// 安全數值解析（防止 NaN/Infinity 注入上游 API）
function safeNum(val: unknown, def: number, min: number, max: number): number {
  const n = typeof val === 'number' ? val : Number(val);
  if (!Number.isFinite(n)) return def;
  return Math.min(Math.max(n, min), max);
}
```

### 迭代審查的收益遞減

| 輪次 | 發現數 | 嚴重度 |
|------|--------|--------|
| Round 1-2 | 8 | 多為 CRITICAL |
| Round 3 | 6 | HIGH + MEDIUM |
| Round 4 | 9 | HIGH（含 1 CRITICAL） |
| Round 5 | 2 | HIGH |
| Round 6-10 | 13 | MEDIUM + LOW |
| Round 11（五路紅隊）| 20（修 6） | 2 CRITICAL + 4 HIGH |
| Round 12（實彈滲透測試）| 5（全修） | 2 CRITICAL + 3 HIGH |

**建議：5 輪是最佳投入產出比。但實彈滲透測試（Round 12）在所有靜態審查之後仍找到 2 個 CRITICAL — 說明靜態分析有盲區，實際打 API 才能驗證。**

## References

- [OWASP SSRF Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html)
- [OWASP XSS Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html)
- [Node.js crypto.randomBytes](https://nodejs.org/api/crypto.html#cryptorandombytessize-callback)
- [Hono Web Framework Security](https://hono.dev/docs/guides/best-practices)
