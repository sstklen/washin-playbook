---
name: try-catch-const-block-scope-trap
description: |
  Fix misleading 503/500 errors caused by JavaScript/TypeScript `const` or `let` variables
  declared inside a `try` block being referenced in the `catch` block. The variable is
  block-scoped to `try` and does NOT exist in `catch`, causing a silent ReferenceError
  that gets swallowed by a global error handler, producing a completely unrelated error message.
  Use when:
  (1) API endpoint returns 503 "service unavailable" but the service is actually online,
  (2) Error only occurs when upstream API fails (happy path works fine),
  (3) catch block references a variable declared with const/let inside the try block,
  (4) Global error handler catches ReferenceError and returns generic 500/503,
  (5) Multiple endpoints have the same pattern — systemic bug that spreads via copy-paste.
  Related: pre-deduct-phantom-refund-prevention (different try/catch scope issue).
author: Claude Code
version: 1.0.0
date: 2026-02-19
---

# Try/Catch Const Block Scope Trap

## Problem

In JavaScript/TypeScript, `const` and `let` are **block-scoped**. A `try` block and its
`catch` block are **separate blocks**. Variables declared with `const`/`let` inside `try`
are NOT accessible in `catch`.

When the code in `try` succeeds, the variable is used and discarded — no problem.
When `try` throws (e.g., API timeout), execution jumps to `catch`, which tries to
reference the variable — **ReferenceError**. This error is then caught by a global
error handler, which returns a generic 503/500 with a completely misleading message.

**Why this is insidious:**
- Build/compile passes (TypeScript doesn't catch this in all cases)
- Happy path tests pass (catch is never reached)
- Only manifests when the upstream service **actually fails**
- Error message has nothing to do with the real cause
- Spreads via copy-paste across multiple endpoints

## Context / Trigger Conditions

- **Symptom**: API endpoint returns 503 "service unavailable" or similar generic error
- **Timing**: Only when upstream API fails (timeout, 5xx, network error)
- **Happy path**: Works perfectly — the bug is invisible during normal operation
- **Error log**: May show `ReferenceError: <varName> is not defined` if you look carefully
- **Pattern**: `const key = getKey(...)` inside `try`, `reportKeyResult(key)` in `catch`
- **Framework**: Any JavaScript/TypeScript — Hono, Express, Fastify, etc.
- **Spread**: Copy-paste propagation — if one endpoint has it, check ALL similar endpoints

## Solution

### Step 1: Identify the Pattern

Search for variables declared inside `try` that are referenced in `catch`:

```bash
# 搜尋 try 內的 const/let 宣告
rg "try\s*\{" --multiline -A 5 | grep "const \|let "

# 搜尋 catch 內引用的變數
rg "catch.*\{" --multiline -A 10 | grep "reportKeyResult\|logError\|cleanup"
```

### Step 2: Fix — Move Declaration Before Try

```typescript
// ❌ BUGGY: const 在 try 內，catch 無法存取
proxy.post('/service', async (c) => {
  try {
    const apiKey = getKeyOrEnv('service', 'SERVICE_API_KEY');
    const res = await fetch(url, { headers: { Authorization: apiKey } });
    // ...
  } catch (err: any) {
    reportKeyResult('service', apiKey, false);  // ❌ ReferenceError!
    return c.json({ error: 'failed' }, 500);
  }
});

// ✅ FIXED: let 在 try 外面，catch 可以安全存取
proxy.post('/service', async (c) => {
  let apiKey: string | null = null;  // 移到 try 外面
  try {
    apiKey = getKeyOrEnv('service', 'SERVICE_API_KEY');
    const res = await fetch(url, { headers: { Authorization: apiKey } });
    // ...
  } catch (err: any) {
    if (apiKey) reportKeyResult('service', apiKey, false);  // ✅ 安全
    return c.json({ error: 'failed' }, 500);
  }
});
```

### Step 3: Add Null Guard

Always add `if (variable)` guard in catch, because the variable might be null if
`getKey()` itself threw before assignment completed.

### Step 4: Audit ALL Similar Endpoints

This bug spreads via copy-paste. When you find one instance, **immediately search
for all similar endpoints**:

```bash
# 找所有 try 內宣告 + catch 引用的模式
rg "const \w+Key = " path/to/proxy.ts
# 然後檢查每個對應的 catch block
```

## Verification

1. **Build passes**: `bun build` / `tsc` — should pass (but it passed before too)
2. **Simulate upstream failure**: Call the endpoint while upstream is down
3. **Check error response**: Should get a proper error message, NOT a generic 503
4. **Run stability test**: Hit the endpoint multiple times — all should return consistently

## Example

**Real case**: 5 proxy endpoints in `api-proxy.ts` (Cohere, Mistral, Serper,
Gemini, ElevenLabs) all had `const xxxKey` in `try` and `reportKeyResult(xxxKey)` in
`catch`. During a P3 exam, when Cohere API returned an error, the catch block triggered
ReferenceError → global handler returned "所有引擎暫時無法服務" (503) — a message
that had NOTHING to do with the actual problem.

**Discovery**: Noticed Cohere scored 21/100 in P3 exam (Q1 and Q3 both 503) but scored
100% in P4 stability exam. Investigated why same endpoint fails under different conditions.
The P3 exam sends more complex prompts that occasionally timeout, triggering the catch block.

**Impact**: Fixed all 5 endpoints, Cohere P3 score jumped from 21 → 88.

## Notes

- **TypeScript limitation**: TS does not always flag this as an error because `catch` can
  reference outer-scope variables — the problem is that `try` and `catch` are sibling blocks,
  not parent-child
- **var vs const/let**: `var` is function-scoped and WOULD work across try/catch (but don't
  use `var` — use `let` with declaration before `try` instead)
- **ESLint rule**: `no-unsafe-finally` catches some scope issues but NOT this specific pattern.
  Consider a custom lint rule if this is a recurring problem.
- **See also**: `pre-deduct-phantom-refund-prevention` — a related try/catch scope issue
  where the scope is too WIDE (includes pre-payment validation), vs this issue where a
  variable doesn't EXIST in catch scope at all
