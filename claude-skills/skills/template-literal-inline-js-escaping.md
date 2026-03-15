---
name: template-literal-inline-js-escaping
description: |
  Fix silent page failures caused by JavaScript syntax errors in inline <script> blocks
  generated from TypeScript/JavaScript template literals (backtick strings).
  Use when: (1) Page shows infinite loading spinner with no console errors,
  (2) Inline JS inside server-rendered HTML never executes,
  (3) onclick handlers with quotes break inside template-literal-generated HTML,
  (4) bun build or esbuild reports "Unterminated string literal" or "Expected ';'"
  in extracted script blocks.
  Root cause: \' inside backticks outputs ' (not \'), and \n outputs real newline.
  Fix: use \\' and \\n instead.
author: Claude Code
version: 1.1.0
date: 2026-02-16
---

# Template Literal Inline JS Escaping

## Problem

When generating HTML pages with inline `<script>` blocks using TypeScript/JavaScript
template literals (backtick `` ` `` strings), escape sequences behave differently than
in regular strings. This causes silent JavaScript syntax errors that prevent the entire
script from parsing — the page loads HTML but no JS executes, typically showing an
infinite loading spinner with zero console errors.

## Context / Trigger Conditions

- **Symptom**: Page shows loading state forever, no JS runs, no console errors
- **Symptom variant**: Page loads HTML skeleton but all data cards show `-`, tabs don't switch, no interactivity
- **Architecture**: Server-side HTML generation using template literals (e.g., Hono `c.html()`)
- **Pattern**: Inline `<script>` containing JS strings with quotes or escape sequences
- **Frameworks**: Hono, Express, Koa, or any server returning template literal HTML
- **Critical trap**: `bun build` passes, server starts fine, no runtime errors — bug ONLY appears in browser
- **Specific triggers**:
  - `onclick="fn('value')"` inside a template literal single-quoted string
  - `confirm('message\ndetails')` where `\n` should be a literal `\n` in output
  - String concatenation with `\n` for multiline confirm/alert messages
  - Any inline event handler with quoted arguments

## Solution

### The Escaping Rules

Inside a template literal (backtick string), escape sequences are interpreted by the
template literal parser FIRST, then output to HTML:

| You write (in TS)   | Template literal outputs | JS sees        | Result    |
|---------------------|-------------------------|----------------|-----------|
| `\'`                | `'`                     | String break   | **BUG** ❌ |
| `\\'`               | `\'`                    | Escaped quote  | **OK** ✅  |
| `\n`                | actual newline           | Broken string  | **BUG** ❌ |
| `\\n`               | `\n`                    | Newline escape | **OK** ✅  |
| `\\\\`              | `\\`                    | Backslash      | **OK** ✅  |

### Fix Pattern

```typescript
// ❌ WRONG — \' becomes ' in output, breaking the JS string
const html = `<script>
  html += '<button onclick="fn('+id+',\'water\',this)">';
  if(!confirm('Are you sure?\nThis cannot be undone')) return;
</script>`;

// ✅ CORRECT — \\' becomes \' in output, properly escaping in JS
const html = `<script>
  html += '<button onclick="fn('+id+',\\'water\\',this)">';
  if(!confirm('Are you sure?\\nThis cannot be undone')) return;
</script>`;
```

### Automated Detection

Extract inline scripts and syntax-check them:

```bash
# 1. Download the page
curl -s http://localhost:3000/page > /tmp/page.html

# 2. Extract script blocks
python3 -c "
import re
with open('/tmp/page.html') as f:
    html = f.read()
scripts = re.findall(r'<script>(.*?)</script>', html, re.DOTALL)
for i, s in enumerate(scripts):
    with open(f'/tmp/script-{i}.js', 'w') as f:
        f.write(s)
    print(f'Script {i}: {len(s)} chars')
"

# 3. Syntax check with bun
bun build /tmp/script-0.js --outdir /tmp/check 2>&1

# Look for: "Unterminated string literal" or "Expected ';'"
```

### Grep Pattern to Find Bugs

```bash
# Find potential escaping issues in template literals generating HTML
# Look for \' not preceded by another \ (inside ORCHARD_HTML or similar blocks)
grep -n "onclick=.*\\\\'" src/api/admin.ts | grep -v "\\\\\\\\'
"
```

## Verification

1. Extract the `<script>` content from the served HTML
2. Run `bun build extracted.js --outdir /tmp/check`
3. Should output `Bundled 1 module` with zero errors
4. Page should load and execute JS (no more infinite spinner)

## Example

**Real case from production API project (2026-02-15):**

The `/my-orchard` page was stuck at "載入果園中..." forever. No errors in browser console.

**Root cause**: 5 JavaScript syntax errors in the inline script generated from a TypeScript
template literal:

1. `neighborHelp('+id+',\'water\',this)` → `\'` became `'`, breaking string
2. `neighborHelp('+id+',\'bug\',this)` → same issue
3. `alert(\'即將開放購買！\')` × 2 → same issue
4. `confirm('...?\n...')` → `\n` became actual newline, breaking string

**Fix**: Changed all `\'` to `\\'` and `\n` to `\\n`.

**Impact**: Entire `<script>` block (47K chars) failed to parse, so `init()` never ran.

### Variant: Admin Panel total failure (2026-02-16)

The `/admin` page (村長後台) showed HTML skeleton but all stats showed `-`, no tab switching,
no data loaded — the entire management system was non-functional.

**Root cause**: 6 instances of `\n` (should be `\\n`) in airdrop confirm message strings
(lines 4037-4048 of admin-ui.ts):

```typescript
// ❌ BUG — \n in template literal becomes real newline
var confirmMsg = '確定要觸發批次空投？\n\n';
confirmMsg += '📌 指定發放給 ' + selectedIds.length + ' 位用戶\n';

// ✅ FIX
var confirmMsg = '確定要觸發批次空投？\\n\\n';
confirmMsg += '📌 指定發放給 ' + selectedIds.length + ' 位用戶\\n';
```

**Why this was missed by ALL verification layers**:
1. `bun build` — PASSED (server-side TS is valid)
2. Server startup — PASSED (no runtime errors)
3. Code review agents — MISSED (they checked logic, not escaping)
4. Verification squad — MISSED (they verified feature completeness, not browser-side syntax)

**Key lesson**: The ONLY way to catch this class of bug is:
- Extract the served HTML's `<script>` content and syntax-check it, OR
- Actually open the page in a browser and check the console

## Notes

- This is especially dangerous because there are NO error messages — the browser silently
  fails to parse the script block and the page just shows its initial HTML state
- The bug only manifests in the served HTML, not in the TypeScript source code, making it
  hard to spot during code review
- When writing inline JS in template literals, prefer using HTML entities (`&#39;` for `'`)
  or `&quot;` for quotes in onclick handlers to avoid the double-escaping confusion entirely
- Consider using a pre-commit hook that extracts inline scripts and syntax-checks them

## See Also

- `docker-static-asset-copy-gotcha` — Another case where local dev works but deployed fails silently
