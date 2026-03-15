---
name: bun-sqlite-like-parameter-binding
description: |
  Fix for bun:sqlite parameter binding silently failing on LIKE, GLOB, INSTR queries.
  Use when: (1) db.query(sql, [params]).get() returns null/empty for LIKE queries but
  sqlite3 CLI returns correct results, (2) parameterized LIKE queries return 0 rows in
  bun:sqlite, (3) inline SQL LIKE works but parameterized version doesn't.
  Root cause: bun:sqlite db.query() second argument doesn't properly bind parameters
  for pattern-matching operators. Must use db.prepare(sql).get(params) instead.
version: 1.0.0
date: 2026-02-18
---

# bun:sqlite LIKE Parameter Binding Bug

## Problem

`bun:sqlite` 的 `db.query(sql, [params]).get()` 和 `.all()` 對 LIKE/GLOB/INSTR 等模式匹配查詢的參數綁定**靜默失敗** — 不報錯，但永遠返回 0 結果。

這個 bug 極其隱蔽：
- 不拋出任何錯誤
- `db.query()` 對簡單 `WHERE col = ?` 也可能失敗
- `sqlite3` CLI 查詢完全正常
- 內嵌字串 `LIKE "%keyword%"` 也正常
- 只有參數化的 `db.query(sql, [?]).get()` 靜默返回空

## Context / Trigger Conditions

- 使用 `bun:sqlite`（不是 better-sqlite3、不是 node:sqlite）
- 查詢包含 `LIKE ?`、`GLOB ?`、`INSTR(col, ?)` 等模式匹配
- `db.query(sql, [params]).get()` 或 `.all()` 返回 null / 空陣列
- 但在 `sqlite3` CLI 或用內嵌字串查詢時結果正確
- **錯誤訊息：無！** 這是靜默失敗

## Solution

**一律使用 `db.prepare(sql).get(params)` 而非 `db.query(sql, [params]).get()`**

```typescript
// ❌ 錯誤 — 參數綁定對 LIKE 靜默失敗
const row = db.query(
  `SELECT * FROM table WHERE col LIKE ?`,
  [`%keyword%`]
).get();
// row === null（即使 DB 有匹配記錄）

// ✅ 正確 — db.prepare() 參數綁定正常
const row = db.prepare(
  `SELECT * FROM table WHERE col LIKE ?`
).get(`%keyword%`);
// row === { ... }（正確返回匹配記錄）
```

**完整對照表：**

| 方法 | LIKE 參數綁定 | 簡單 WHERE = | 推薦 |
|------|-------------|-------------|------|
| `db.query(sql, [params]).get()` | **靜默失敗** | 可能失敗 | **禁用** |
| `db.query(sql, [params]).all()` | **靜默失敗** | 可能失敗 | **禁用** |
| `db.prepare(sql).get(params)` | 正常 | 正常 | **推薦** |
| `db.prepare(sql).all(params)` | 正常 | 正常 | **推薦** |
| `db.run(sql, [params])` | 正常 | 正常 | INSERT/UPDATE 用 |

## Verification

```typescript
import { Database } from "bun:sqlite";

const db = new Database(":memory:");
db.run("CREATE TABLE test (name TEXT)");
db.run("INSERT INTO test VALUES ('hello world')");

// 驗證 bug 存在
const buggy = db.query("SELECT * FROM test WHERE name LIKE ?", ["%hello%"]).get();
console.log("db.query LIKE:", buggy); // null（bug！）

// 驗證修復有效
const fixed = db.prepare("SELECT * FROM test WHERE name LIKE ?").get("%hello%");
console.log("db.prepare LIKE:", fixed); // { name: "hello world" }（正確！）
```

## Example

**實際案例：L4 Task Engine 的 lookupLearning()**

```typescript
// 修復前 — lookupLearning 自 L4 建立以來從未成功過（靜默失敗）
function lookupLearning(goal: string): LearningRecord | null {
  const likePattern = `%${keywords}%`;
  const row = db.query(
    `SELECT * FROM task_learning WHERE goal_keywords LIKE ? ORDER BY quality_score DESC LIMIT 1`,
    [likePattern]
  ).get() as any;
  // row 永遠是 null！學習記憶功能形同虛設
  return row ? parse(row) : null;
}

// 修復後 — 學習記憶正常命中
function lookupLearning(goal: string): LearningRecord | null {
  const likePattern = `%${keywords}%`;
  const row = db.prepare(
    `SELECT * FROM task_learning WHERE goal_keywords LIKE ? ORDER BY quality_score DESC LIMIT 1`
  ).get(likePattern) as any;
  // row 正確返回匹配記錄！score=0.88
  return row ? parse(row) : null;
}
```

## Notes

- 這個 bug 在 bun v1.x 就存在，截至 2026-02-18（bun 1.2.x）仍未修復
- `db.run()` 的參數綁定似乎不受影響（INSERT/UPDATE 正常）
- 建議：在所有 bun:sqlite 專案中全域搜尋 `db.query(` 並替換為 `db.prepare(`
- 這是 bun:sqlite 特有的問題，better-sqlite3 和 node:sqlite 沒有此 bug
- 相關 skill: `bun-sqlite-test-infrastructure`, `bun-sqlite-transaction-await-crash`

## Diagnostic Steps

如果懷疑遇到此 bug：

1. 用 `sqlite3` CLI 跑同一條 SQL — 如果 CLI 有結果但程式碼沒有，很可能是此 bug
2. 將 LIKE 參數直接內嵌到 SQL 字串中測試 — 如果內嵌有結果，確認是此 bug
3. 將 `db.query()` 改成 `db.prepare()` — 如果改完有結果，100% 確認是此 bug

## References

- bun:sqlite 官方文檔: https://bun.sh/docs/api/sqlite
- Commit 940ce29: 修復 lookupLearning 的 LIKE 查詢
- Error Log: ~/.claude/error-log.md (2026-02-18 bun:sqlite LIKE 查詢參數綁定 bug)
