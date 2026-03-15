---
name: github-action-security-hardening
description: |
  GitHub Action (composite type) pre-release security hardening checklist.
  Use when: (1) building a composite GitHub Action with shell scripts,
  (2) embedding Python/Node in bash entrypoints, (3) handling user-provided
  error logs or CI output, (4) posting PR comments from Action output,
  (5) publishing to GitHub Marketplace. Covers shell injection prevention,
  secret redaction, ID masking, JSON parse optimization, PR comment dedup,
  and Marketplace publishing requirements (2FA, Developer Agreement).
author: Claude Code
version: 1.0.0
date: 2026-02-22
---

# GitHub Action Security Hardening (Composite Type)

## Problem
Composite GitHub Actions using shell scripts have multiple security and robustness
pitfalls that are easy to miss during development but immediately visible to
engineers reviewing your source code on GitHub.

## Context / Trigger Conditions
- Building a composite GitHub Action (`runs.using: 'composite'`)
- Shell script (entrypoint.sh) embeds Python/Node for JSON processing
- Action handles CI error logs that may contain secrets
- Action posts comments on PRs via GitHub API
- Publishing Action to GitHub Marketplace

## Solution

### 1. Shell Injection in Embedded Python (CRITICAL)

**Bad** — shell variables interpolated into Python triple-quotes:
```bash
COMMENT_BODY=$(python3 -c "
root_cause = '''$ROOT_CAUSE'''
fix_desc = '''$FIX_DESC'''
print(json.dumps({'body': root_cause}))
")
```
If `$ROOT_CAUSE` contains `'''`, Python syntax breaks. If it contains `'; os.system('...'); '`, it's code injection.

**Good** — pass via environment variables:
```bash
export ROOT_CAUSE FIX_DESC
COMMENT_BODY=$(python3 -c "
import json, os
root_cause = os.environ.get('ROOT_CAUSE', '')
fix_desc = os.environ.get('FIX_DESC', '')
print(json.dumps({'body': root_cause}))
")
```

### 2. Secret Redaction (Must Match README Claims)

If README says "secrets are automatically filtered", the code MUST do it:

```bash
sanitize_secrets() {
  sed -E \
    -e 's/(api[_-]?key|apikey|secret|token|password|passwd|pwd|auth)(["\x27: =]+)[^ "\x27,}{)]+/\1\2***REDACTED***/gi' \
    -e 's/ghp_[A-Za-z0-9]{36}/ghp_***REDACTED***/g' \
    -e 's/gho_[A-Za-z0-9]{36}/gho_***REDACTED***/g' \
    -e 's/sk-[A-Za-z0-9]{20,}/sk-***REDACTED***/g' \
    -e 's/Bearer [A-Za-z0-9._-]+/Bearer ***REDACTED***/g'
}
ERROR_TEXT=$(echo "$ERROR_TEXT" | sanitize_secrets)
```

### 3. ID/Credential Masking in Logs

Never print full IDs in CI logs (they're public for public repos):

```bash
mask_id() {
  local id="$1"
  local len=${#id}
  if [ "$len" -le 4 ]; then echo "****"
  else echo "****${id: -4}"; fi
}
echo "Claw ID: $(mask_id "$CLAW_ID")"  # Shows: ****ab12
```

### 4. Single-Pass JSON Parsing

**Bad** — 8 separate python3 invocations to parse the same JSON:
```bash
STATUS=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))")
SOURCE=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin).get('source',''))")
# ... 6 more calls
```

**Good** — one call, eval the output:
```bash
eval "$(echo "$BODY" | python3 -c "
import sys, json, shlex
d = json.load(sys.stdin)
r = d.get('result', {})
for k, v in {'STATUS': d.get('status',''), 'SOURCE': d.get('source','')}.items():
    print(f'{k}={shlex.quote(v)}')
")"
```

### 5. PR Comment Deduplication

Without dedup, re-running CI posts duplicate comments:

```bash
# Check for existing comment
EXISTING_ID=$(curl -s \
  -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/$REPO/issues/$PR/comments?per_page=100" \
  | python3 -c "
import sys, json
for c in json.load(sys.stdin):
    if 'YOUR_UNIQUE_MARKER' in c.get('body', ''):
        print(c['id']); break
")

if [ -n "$EXISTING_ID" ]; then
  # PATCH to update existing
  curl -s -X PATCH ... "issues/comments/$EXISTING_ID" -d "$BODY"
else
  # POST new comment
  curl -s -X POST ... "issues/$PR/comments" -d "$BODY"
fi
```

### 6. Unique EOF Delimiter

GitHub Actions multi-line outputs use heredoc delimiters. If API response contains your delimiter, output breaks:

```bash
# Bad: static delimiter
echo "fix<<YANHUI_EOF"

# Good: unique per-run
EOF_MARKER="YANHUI_EOF_$$"
echo "fix<<$EOF_MARKER"
```

### 7. GitHub Marketplace Publishing Requirements

Two non-obvious blockers:
1. **2FA Required** — Account must have two-factor authentication enabled BEFORE you can publish
2. **Developer Agreement** — Must accept GitHub Marketplace Developer Agreement (web UI only, no API)
3. **Branding Required** — `action.yml` must have `branding.icon` and `branding.color`

Flow: Accept Agreement → Enable 2FA → Create Release → Check "Publish to Marketplace" → Select category

## Verification

- [ ] No shell variables directly interpolated into Python/Node code strings
- [ ] `sanitize_secrets()` function exists and is called before sending data externally
- [ ] User IDs/credentials never printed in full in CI logs
- [ ] JSON parsed in single invocation, not N separate calls
- [ ] PR comments use find-and-update pattern (idempotent)
- [ ] Multi-line output delimiters include `$$` or unique suffix
- [ ] README security claims match actual code behavior

## Notes
- `python3` is available on all `ubuntu-latest` runners; no need for `jq`
- `shlex.quote()` in Python properly escapes for shell eval
- GitHub Marketplace 2FA requirement is not documented prominently — you only discover it on the release page
- For the `github-token` input, default to `${{ github.token }}` but allow override (some users need PAT for cross-repo)
- Composite actions don't need Docker; they run directly in the runner's shell
