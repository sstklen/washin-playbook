---
name: multi-agent-tdz-trap
description: |
  Fix for "Cannot access 'X' before initialization" ReferenceError caused by
  multi-agent code insertion in the same function scope. Use when: (1) multiple
  background agents edit the same long function/middleware, (2) one agent inserts
  code that references a variable identifier before a `const/let` declaration
  written by another agent or existing code, (3) the error only appears at runtime
  (not build time) because JavaScript `const` hoisting creates a Temporal Dead Zone
  (TDZ) across the entire block scope. Common in Hono/Express middleware chains
  where early-return bypass blocks reference variables declared later.
author: Claude Code
version: 1.0.0
date: 2026-02-20
---

# Multi-Agent TDZ Trap in Shared Function Scopes

## Problem

When multiple background agents (or an agent + human) independently edit the same
long function (e.g., a 200+ line Hono middleware), one agent may insert code that
references a variable identifier that another agent declared with `const` or `let`
later in the same block scope. JavaScript hoists `const`/`let` declarations to the
top of their block scope but leaves them in the "Temporal Dead Zone" until the
declaration line is reached. Any reference to the identifier before that line throws
`ReferenceError: Cannot access 'X' before initialization`.

**This is invisible at build time** — Bun, esbuild, and TypeScript will not catch it.
It only crashes at runtime when the affected code path executes.

## Context / Trigger Conditions

- **Error message**: `Cannot access 'apiKey' before initialization` (or any variable name)
- **Runtime only**: Build passes with zero errors
- **Multiple agents**: Two or more agents edited the same file concurrently
- **Long functions**: Middleware or handler functions >100 lines with multiple early-return paths
- **Pattern**: Agent A inserts an early-return block referencing `someVar`, while
  `const someVar = ...` exists later in the same function (from Agent B or existing code)

## Solution

### 1. Identify the TDZ conflict

Search for ALL `const`/`let` declarations of the variable in the same function scope:

```bash
# Find all declarations of the variable in the file
grep -n 'const apiKey\|let apiKey' src/api/proxy-handler.ts
```

### 2. Check if any early-return block references the variable

The dangerous pattern:

```typescript
// ❌ WRONG — Agent A inserted this early-return block
if (someCondition) {
  c.set('apiKey', apiKey || 'default');  // References `apiKey` identifier → TDZ!
  await next();
  return;
}

// ... 50 lines later ...

const apiKey = extractApiKey(c);  // ← This creates the TDZ for the ENTIRE function
```

### 3. Fix: Use string literals or independent variables

```typescript
// ✅ CORRECT — Use string literals, not variable identifiers
if (someCondition) {
  c.set('apiKey', 'chief-pass');  // String literal, no variable reference
  await next();
  return;
}

// ... later ...
const apiKey = extractApiKey(c);  // TDZ doesn't affect string arguments
```

### 4. Prevention: Review multi-agent edits

After multiple agents edit the same file:
1. **Grep for duplicate patterns**: Look for the same variable name in inserted blocks
2. **Check function boundaries**: Ensure each agent's changes don't leak scope
3. **Test the exact code path**: The TDZ only triggers when the early-return path runs

## Verification

1. Deploy and test the specific code path (not just build)
2. Check Docker/server logs for `Cannot access 'X' before initialization`
3. Confirm the variable is only referenced AFTER its `const`/`let` declaration

## Example

**Real case from production-api (2026-02-20):**

Background Agent A inserted a "village chief free pass" block at line 2049:
```typescript
if (isChief && revenue > 0) {
  c.set('apiKey', apiKey || 'chief');  // ← TDZ! `apiKey` declared at line 2076
  await next();
  return;
}
```

While `const apiKey = extractApiKey(c)` existed at line 2076 in the same middleware function.

**Symptoms:**
- `bun build` passed with 0 errors
- Docker container started normally
- Every paid API call returned 503 with "Cannot access 'apiKey' before initialization"
- The error message gave NO line number or stack trace in the logs

**Fix:** Removed the duplicate block (there was a correct version at line 2074 that
used `c.set('apiKey', 'chief-pass')` with a string literal instead).

## Notes

- `c.set('key', value)` where `'key'` is a **string** does NOT trigger TDZ
- `c.set('key', apiKey || 'default')` where `apiKey` is a **variable identifier** DOES trigger TDZ
- This is NOT a TypeScript/ESLint error — it's a JavaScript runtime semantic
- `var` declarations do NOT have this problem (they're hoisted with `undefined`),
  but `const`/`let` DO
- Particularly dangerous in Hono middleware where `proxy.use('/*', async (c, next) => { ... })`
  can span hundreds of lines with multiple early-return paths

## See also

- `hono-subrouter-route-conflict` — Related TDZ issue with lazy getters
- `typescript-circular-dependency` — Similar error message but different root cause (imports)
