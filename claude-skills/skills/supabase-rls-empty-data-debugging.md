---
name: supabase-rls-empty-data-debugging
description: |
  診斷 Supabase RLS、Auth、PostgREST 查詢相關問題。使用時機：
  (1) 前端頁面載入成功但顯示「無法載入」或空列表，
  (2) 部分表有數據、部分表完全沒有（非全有或全無），
  (3) FastAPI backend 返回 401 但 Supabase Auth login 成功，
  (4) "42P17 infinite recursion detected in policy" 錯誤，
  (5) ".single()" 拋 PGRST116 或 ".maybe_single()" 拋 204 "Missing response"，
  (6) "invalid input syntax for type uuid" 錯誤，建立測試資料失敗，
  (7) 收到 Supabase 安全警告信 "policy_exists_rls_disabled" 或 "rls_disabled_in_public"，
  (8) 新建的表忘記啟用 RLS 導致資料完全暴露（任何人用 anon key 可讀寫）。
  涵蓋 RLS 診斷、Backend Proxy Pattern、JWT 驗證、PostgREST 查詢、測試資料建立、
  Supabase 安全審計回應。
author: Washin Village + Claude
version: 2.1.0
date: 2026-02-11
---

# Supabase RLS 空數據問題診斷

## Problem

前端應用使用 Supabase anon key 查詢數據時，頁面載入成功但返回空數據，
且沒有明確的錯誤訊息指向權限問題。這是 RLS（Row Level Security）啟用但
政策不完整的典型症狀。

## Context / Trigger Conditions

- 前端顯示「無法載入 XXX 列表」或顯示空表格
- **關鍵線索**：部分表有數據、部分表沒有（非全有或全無）
- 使用 Supabase `anon` key 的前端（Next.js、React 等）
- 沒有明確的 401/403 錯誤，只是空數據
- 後端直接用 SQL 或 service_role key 可以看到數據

## Solution

### 1. 診斷流程

**Step 1: 確認是 RLS 問題**

```sql
-- 在 Supabase SQL Editor 執行，檢查 RLS 狀態
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public';
```

如果 `rowsecurity = true` 但該表沒有對應的 SELECT 政策，就會返回空數據。

**Step 2: 檢查現有政策**

```sql
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
```

比對：
- 有數據的表 → 通常有 SELECT 政策
- 沒數據的表 → 可能缺少 SELECT 政策

**Step 3: 確認差異**

```sql
-- 找出啟用 RLS 但缺少 SELECT 政策的表
SELECT t.tablename
FROM pg_tables t
LEFT JOIN pg_policies p ON t.tablename = p.tablename AND p.cmd = 'SELECT'
WHERE t.schemaname = 'public'
  AND t.rowsecurity = true
  AND p.policyname IS NULL;
```

### 2. 解決方案

#### 方案 A: 添加 RLS 政策（推薦用於簡單場景）

```sql
-- 範例：讓 operators 可以查看所有工單
CREATE POLICY "Operators can view all tickets" ON tickets
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM operators WHERE user_id = auth.uid())
    );

-- 範例：讓 clients 只能看自己的訂單
CREATE POLICY "Clients can view own orders" ON orders
    FOR SELECT USING (
        client_id IN (SELECT id FROM clients WHERE user_id = auth.uid())
    );
```

#### 方案 B: Backend Proxy Pattern（推薦用於複雜場景）

當 RLS 政策變得複雜時，創建後端 API 端點使用 `service_role` key 繞過 RLS：

```python
# FastAPI 範例
from services.supabase import get_supabase_admin  # 使用 service_role key

@router.get("/dashboard/tickets")
async def list_tickets(current_user = Depends(require_operator)):
    """使用 service_role 繞過 RLS"""
    db = get_supabase_admin()  # admin client with service_role key
    result = db.table("tickets").select("*").execute()
    return result.data
```

前端改呼叫後端 API：

```typescript
// 之前：直接查詢 Supabase（被 RLS 阻擋）
const { data } = await supabase.from("tickets").select("*");

// 之後：通過後端 API
const response = await fetch("/api/v1/dashboard/tickets", {
  headers: { Authorization: `Bearer ${token}` }
});
const data = await response.json();
```

### 3. 診斷對照表

| 症狀 | 可能原因 | 解決方案 |
|------|---------|---------|
| 所有表都沒數據 | anon key 無效 或 RLS 全面阻擋 | 檢查環境變量 |
| 部分表有數據 | RLS 政策不完整 | 添加缺少的 SELECT 政策 |
| 後端有、前端沒有 | RLS 阻擋 anon key | Backend Proxy Pattern |
| 登入後有、登入前沒有 | 政策正確，需認證 | 預期行為 |

## Verification

```sql
-- 驗證政策已創建
SELECT tablename, policyname, cmd
FROM pg_policies
WHERE schemaname = 'public' AND cmd = 'SELECT';

-- 應該看到每個需要前端存取的表都有對應的 SELECT 政策
```

或測試 API 端點：
```bash
curl -H "Authorization: Bearer $TOKEN" \
  https://your-api.com/api/v1/dashboard/tickets
# 應返回數據而非空陣列
```

## Example

**實際案例**：ExampleApp OP Dashboard

**症狀**：
- `/suppliers` 頁面有數據 ✅
- `/tickets`、`/clients`、`/quotes` 頁面空白 ❌

**診斷**：
```sql
-- 檢查 schema.sql 發現
ALTER TABLE tickets ENABLE ROW LEVEL SECURITY;  -- RLS 啟用
-- 但沒有對應的 SELECT 政策給 operators

-- suppliers 表沒有啟用 RLS，所以有數據
```

**解決**：
1. 創建 `/apps/api/routers/dashboard.py` 使用 service_role key
2. 前端改呼叫 `/api/v1/dashboard/*` 端點
3. 同時準備 RLS 政策 SQL 供後續補齊

## Notes

- `service_role` key 必須只在後端使用，絕不暴露給前端
- Backend Proxy Pattern 需要額外的 JWT 認證保護
- 如果使用方案 A，記得為每種角色（operators、clients）創建對應政策
- RLS 政策中的 `auth.uid()` 需要用戶已登入才有值

## Variant: Supabase 安全審計 — RLS 未啟用（2026-02-11 新增）

### 問題（與主問題相反！）

| 主問題 | 這個 Variant |
|--------|-------------|
| RLS 開了但政策沒寫 → 數據太嚴（空的） | RLS 根本沒開 → 數據太鬆（全暴露） |
| 症狀：前端看不到數據 | 症狀：收到 Supabase 安全警告信 |
| 風險：功能壞了 | 風險：**安全漏洞** 🔴 |

### 觸發條件

- 收到 Supabase 信件：`"policy_exists_rls_disabled"` 或 `"rls_disabled_in_public"`
- Schema 新增了表但忘記加 `ENABLE ROW LEVEL SECURITY`
- `CREATE TABLE` 和 RLS 設定分開寫（常見於 AI 生成的 schema）

### 診斷

```sql
-- 找出所有沒有 RLS 的 public 表（結果應該是空的！）
SELECT tablename FROM pg_tables
WHERE schemaname = 'public' AND NOT rowsecurity
ORDER BY tablename;

-- 找出有政策但沒開 RLS 的表（最詭異的情況：寫了鎖但沒上）
SELECT DISTINCT p.tablename
FROM pg_policies p
JOIN pg_tables t ON p.tablename = t.tablename AND t.schemaname = 'public'
WHERE NOT t.rowsecurity;
```

### 修復模板

```sql
-- 1. 啟用 RLS
ALTER TABLE public.{表名} ENABLE ROW LEVEL SECURITY;

-- 2. 加基本政策（依角色選擇）

-- OP 可以查看和管理
CREATE POLICY "operators_manage_{表名}" ON {表名}
    FOR ALL USING (
        EXISTS (SELECT 1 FROM operators WHERE user_id = auth.uid())
    );

-- 客戶只能看自己的（透過 client_id 關聯）
CREATE POLICY "clients_view_own_{表名}" ON {表名}
    FOR SELECT USING (
        client_id IN (SELECT id FROM clients WHERE user_id = auth.uid())
    );

-- 純後端存取（不開放前端）— 只有 service_role 能存取
-- 不建立任何 policy = 前端完全看不到（最安全）
```

### 危險等級判斷

| 表內容 | 危險等級 | 處理 |
|--------|---------|------|
| API keys、tokens、secrets | 🔴 極危險 | 立即修復 + 檢查是否已洩漏 |
| Session、auth 資料 | 🔴 極危險 | 立即修復 |
| 財務資料（金額、交易） | 🟠 危險 | 當天修復 |
| 業務資料（訂單、客戶） | 🟡 中等 | 本週修復 |
| 公開資料（公告、FAQ） | 🟢 低風險 | 下次部署一起修 |

### 預防規則（強制！）

```sql
-- ✅ 正確：CREATE TABLE 和 RLS 是原子操作
CREATE TABLE new_table (...);
ALTER TABLE new_table ENABLE ROW LEVEL SECURITY;
CREATE POLICY "operators_manage_new_table" ON new_table
    FOR ALL USING (EXISTS (SELECT 1 FROM operators WHERE user_id = auth.uid()));

-- ❌ 錯誤：TODO 式的 RLS — 永遠不會做
CREATE TABLE new_table (...);
-- TODO: 加 RLS
```

### 驗證

```sql
-- 修復後確認：所有 public 表都有 RLS
SELECT tablename, rowsecurity
FROM pg_tables WHERE schemaname = 'public'
ORDER BY tablename;
-- 預期：全部 true，沒有例外
```

### 實際案例

**A real project (2026-02)**：Initial Commit（AI 生成）的 schema.sql 對 17 張表中的 10 張啟用了 RLS，漏掉了 7 張。其中 `api_keys` 表完全暴露 — 任何人用 anon key 就能讀取所有 API 金鑰。修復：migration `007_fix_missing_rls_security.sql`，啟用 7 張表 RLS + 新增 17 條政策。

---

## See Also

- RLS policy 自我參照導致 42P17 infinite recursion（已整合至本指南）
- 建立測試資料時繞過 RLS（已整合至本指南）

## References

- [Supabase RLS 官方文檔](https://supabase.com/docs/guides/auth/row-level-security)
- [PostgreSQL RLS](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)

## Merged Skills (archived)

The following skills have been merged into this guide:
- **supabase-auth-fastapi-jwt-integration** — FastAPI backend 拒絕 Supabase Auth tokens，使用 Admin API 驗證和 app_metadata.role
- **supabase-auth-test-data-seeding** — 在 auth.users 建立測試帳號，UUID 格式陷阱，繞過 RLS
- **supabase-maybe-single-204-error** — postgrest-py ".maybe_single()" 拋 204 "Missing response" 錯誤
- **supabase-postgrest-single-query-error** — ".single()" 拋 PGRST116 異常，".maybe_single()" 返回 None 而非物件
- **supabase-rls-infinite-recursion** — RLS policy 自我參照導致 42P17 infinite recursion 錯誤
