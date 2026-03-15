---
name: claude-code-dual-install-update-fix
description: |
  Fix Claude Code update not taking effect due to dual installations (native + npm).
  Use when: (1) `npm install -g @anthropic-ai/claude-code@latest` succeeds but `claude --version`
  still shows old version, (2) model aliases (sonnet/opus) still point to old models after update,
  (3) `which claude` points to `~/.local/bin/claude` (native install) instead of npm global path.
  Root cause: native installer (`~/.local/bin/claude` symlink) takes PATH priority over
  npm global install (`/opt/homebrew/bin/claude`), so npm update changes the wrong binary.
version: 1.0.0
date: 2026-02-19
---

# Claude Code Dual Installation Update Fix

## Problem

Running `npm install -g @anthropic-ai/claude-code@latest` reports success and installs
the latest version, but `claude --version` still shows the old version. Model aliases
(e.g., `sonnet`) still point to older models (e.g., Sonnet 4.5 instead of 4.6).

## Context / Trigger Conditions

- `npm install -g @anthropic-ai/claude-code@latest` says "changed X packages" but version unchanged
- `claude --version` shows old version (e.g., 2.1.37) while npm shows latest (e.g., 2.1.47)
- `which claude` returns `~/.local/bin/claude` (NOT `/opt/homebrew/bin/claude`)
- `/model` in Claude Code shows old model aliases
- User originally installed Claude Code via standalone installer (curl method), then tried npm update

## Diagnosis

```bash
# Step 1: Check which binary is actually running
which claude
# If output is ~/.local/bin/claude -> native install (NOT npm)

# Step 2: Check the symlink
ls -la ~/.local/bin/claude
# Shows: ~/.local/bin/claude -> ~/.local/share/claude/versions/X.X.X

# Step 3: Check npm global version (the one that WAS updated but isn't being used)
npm list -g @anthropic-ai/claude-code

# Step 4: Compare
claude --version          # OLD version (native)
npm list -g ... version   # NEW version (npm, unused)
```

## Solution

### Correct Update Method (for native install)

```bash
# Use Claude Code's built-in self-update
claude update
```

This updates the native installation at `~/.local/share/claude/versions/` and
re-points the symlink.

### Cleanup: Remove Duplicate npm Installation

```bash
# After native update succeeds, remove the leftover npm install
npm -g uninstall @anthropic-ai/claude-code
```

### Alternative: Switch to npm-only (if preferred)

```bash
# Remove native install
rm ~/.local/bin/claude
rm -rf ~/.local/share/claude/versions/

# Then use npm going forward
npm install -g @anthropic-ai/claude-code@latest
```

## Verification

```bash
# After update, verify
claude --version    # Should show latest (e.g., 2.1.47)
which claude        # Should show single location

# After restarting Claude Code session:
/model              # sonnet should point to latest (e.g., Sonnet 4.6)
/status             # Shows current model info
```

## Key Insight

Claude Code has two installation methods that use DIFFERENT binary locations:

| Method | Binary Location | Update Command |
|--------|----------------|----------------|
| Native (standalone installer) | `~/.local/bin/claude` (symlink) | `claude update` |
| npm global | `/opt/homebrew/bin/claude` (or npm global path) | `npm install -g @anthropic-ai/claude-code@latest` |

When both exist, `~/.local/bin/` typically has higher PATH priority, so the native
version "wins". Running `npm install -g` updates the npm copy that never gets executed.

## Notes

- `claude update` will detect the mismatch and warn about multiple installations
- It also fixes the config to match the actual installation method
- After a major model release (e.g., Sonnet 4.6), the model alias mapping is
  bundled with the Claude Code version, so an outdated binary = outdated aliases
- See also: `llm-model-version-migration-2026` for model version API name changes

## References

- [Claude Code Model Configuration](https://code.claude.com/docs/en/model-config)
- [Anthropic: Introducing Claude Sonnet 4.6](https://www.anthropic.com/news/claude-sonnet-4-6)
