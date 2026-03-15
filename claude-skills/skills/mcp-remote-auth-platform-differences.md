---
name: mcp-remote-auth-platform-differences
description: |
  MCP Server 付費認證在不同 AI 客戶端的差異。Use when:
  (1) 建立需要 API Key 認證的付費 MCP Server，
  (2) Claude Desktop 連不上需要 header 的遠端 MCP，
  (3) 需要為不同客戶端（Claude Desktop / Claude Code / Cursor）提供安裝指南。
  關鍵發現：Claude Desktop 遠端 MCP 只支援 authless 和 OAuth，不支援自訂 HTTP header。
  解法：使用 npx mcp-remote bridge 或 stdio 本地模式。
author: Claude Code
version: 1.0.0
date: 2026-02-14
---

# MCP Remote Auth Platform Differences

## Problem

Building a paid MCP Server that requires API key authentication, but different AI
clients handle HTTP headers differently. Claude Desktop specifically does NOT support
custom HTTP headers for remote MCP servers, causing paid tools to fail with 401.

## Context / Trigger Conditions

- Built a paid MCP Server requiring `Authorization: Bearer wv_xxx` header
- Free MCP Server works fine (authless)
- Paid MCP Server returns 401 when used from Claude Desktop
- Works from Claude Code or direct HTTP clients
- Users report "paid tools don't work" on Claude Desktop

## Solution

### Platform Authentication Matrix

| Platform | Free MCP (authless) | Paid MCP (needs API key) |
|----------|-------------------|------------------------|
| **Claude Code** (CLI) | ✅ HTTP URL | ✅ HTTP + `--header` flag |
| **Claude Desktop** (App) | ✅ Connectors (authless) | ❌ No custom headers → use bridge |
| **Cursor / Windsurf** | ✅ HTTP URL | ⚠️ Varies — check IDE support |
| **Any HTTP client** | ✅ POST endpoint | ✅ Standard HTTP headers |

### Claude Desktop Workaround: npx mcp-remote bridge

Since Claude Desktop only supports authless and OAuth for remote servers
(configured via Settings > Connectors), use `mcp-remote` as a stdio bridge:

```json
{
  "mcpServers": {
    "my-free-server": {
      "url": "https://api.example.com/mcp/free"
    },
    "my-paid-server": {
      "command": "npx",
      "args": [
        "mcp-remote",
        "https://api.example.com/mcp/proxy",
        "--header",
        "Authorization:Bearer YOUR_API_KEY"
      ]
    }
  }
}
```

### Claude Code: Native header support

```bash
# Free server (no auth)
claude mcp add my-free --transport http https://api.example.com/mcp/free

# Paid server (with API key)
claude mcp add my-paid --transport http \
  --header "Authorization: Bearer YOUR_API_KEY" \
  https://api.example.com/mcp/proxy
```

### Cursor / IDE: Try native or use bridge

```bash
# If IDE supports headers, use direct URL
# If not, use npx bridge:
npx mcp-remote https://api.example.com/mcp/proxy --header "Authorization:Bearer KEY"
```

## Verification

1. Free server: `curl -s -o /dev/null -w "%{http_code}" https://api.example.com/mcp/free` → 406 (needs POST)
2. Paid without auth: `curl -s https://api.example.com/mcp/proxy` → 401
3. Paid with auth: `curl -s -H "Authorization: Bearer wv_xxx" https://api.example.com/mcp/proxy` → 406 (needs POST, auth OK)

## Example

Washin Village MCP Server `/mcp` landing page provides:
- 4 tabs: Claude Desktop / Claude Code / Cursor / HTTP
- Each tab shows the correct auth method for that platform
- "Getting Started" section: create account → get key → configure → use
- Price badges on each tool card

## Notes

- Claude Desktop uses Settings > Connectors for remote MCP, NOT `claude_desktop_config.json`
- The `mcp-remote` npm package acts as a stdio-to-HTTP bridge
- For OAuth-based auth, Claude Desktop supports it natively (callback: `https://claude.ai/api/mcp/auth_callback`)
- Consider offering both stdio and HTTP modes for maximum compatibility
- Include `create_account` and `check_balance` tools in your MCP for self-service onboarding

## See Also

- `hono-subrouter-route-conflict` — Hono sub-router path conflicts
- `mcp-http-adapter-pattern` — MCP HTTP adapter architecture

## References

- [Claude Desktop Remote MCP Servers](https://support.claude.com/en/articles/11503834-building-custom-connectors-via-remote-mcp-servers)
- [FastMCP Issue #1789 - No custom headers in config](https://github.com/jlowin/fastmcp/issues/1789)
- [Claude Code MCP Docs](https://code.claude.com/docs/en/mcp)
- [MCP HTTP Transport Spec](https://modelcontextprotocol.io/docs/develop/connect-local-servers)
