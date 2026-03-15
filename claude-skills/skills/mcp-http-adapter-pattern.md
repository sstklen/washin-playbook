---
name: mcp-http-adapter-pattern
description: |
  Convert any existing REST API into MCP-native tools by building a thin HTTP adapter server. This pattern keeps business logic centralized while exposing API endpoints as Claude-accessible tools. Includes MCP server architecture, stdio testing patterns, paid API integration guidelines, and HTTP Streamable Transport for remote access (Hono/Bun/Deno). Use when: (1) building MCP-over-HTTP endpoints for remote AI agents, (2) "Not Acceptable: Client must accept both application/json and text/event-stream" error, (3) dual-mode MCP server (stdio + HTTP), (4) CORS issues with mcp-session-id headers.
argument-hint: |
  [api-url|api-port|endpoints] — use for proxy-wrapping existing APIs
version: 1.1.0
date: 2026-02-12
---

# MCP-HTTP-Adapter Pattern: Wrapping REST APIs as MCP Tools

## Overview

Instead of duplicating business logic, build a **thin MCP server that acts as an HTTP client** to your existing REST API. This gives you MCP tool access while keeping all logic centralized.

```
Claude Desktop / Cursor / Cline
    ↓ MCP Protocol (stdio)
thin-mcp-server.ts (~350 lines, pure tool adapters)
    ↓ HTTP POST/GET (fetch)
existing-rest-api (localhost:PORT, all business logic)
    ↓
Upstream services
```

## When to Use This Pattern

✅ **Perfect for:**
- You already have a working REST API
- You want Claude/Cursor/Cline to call it
- Business logic is complex (credit system, rate limiting, refund)
- You want to reuse the API across multiple clients

❌ **Not ideal for:**
- Building MCP tools from scratch (just write native tools directly)
- Stateless single-endpoint proxies (overhead too high)
- APIs that need WebSocket/streaming (MCP tools are request-response only)

## Architecture

### 1. MCP Server Structure (pure tool definitions)

```typescript
// src/mcp/server.ts
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio";
import { Tool, Server } from "@modelcontextprotocol/sdk/types";

const API_BASE = "http://localhost:3000";
const API_KEY = process.env.MY_API_KEY;

const server = new Server({
  name: "api-proxy",
  version: "1.0.0",
});

// Tool definitions (no business logic)
const tools: Tool[] = [
  {
    name: "get_weather",
    description: "Get current weather at latitude/longitude. FREE.",
    inputSchema: {
      type: "object",
      properties: {
        latitude: { type: "number", description: "Latitude (-90 to 90)" },
        longitude: { type: "number", description: "Longitude (-180 to 180)" },
      },
      required: ["latitude", "longitude"],
    },
  },
  // ... more tools
];

// Tool execution (thin HTTP adapter)
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    const result = await callProxy(name, args, false); // free tool
    return {
      content: [{ type: "text", text: JSON.stringify(result) }],
    };
  } catch (err) {
    return {
      content: [{ type: "text", text: JSON.stringify({ error: err.message }) }],
      isError: true,
    };
  }
});

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools,
}));

// Connect via stdio
const transport = new StdioServerTransport();
server.connect(transport);

// Helper: call the underlying HTTP API
async function callProxy(endpoint, args, requireAuth) {
  const res = await fetch(`${API_BASE}/api/proxy/${endpoint}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(requireAuth && API_KEY ? { Authorization: `Bearer ${API_KEY}` } : {}),
    },
    body: JSON.stringify(args),
    signal: AbortSignal.timeout(30000),
  });

  const data = await res.json();

  // Graceful error handling
  if (!res.ok) {
    if (res.status === 401) {
      return {
        success: false,
        error: "Unauthorized",
        howToFix: "Add MY_API_KEY to Claude Desktop config",
      };
    } else if (res.status === 402) {
      return {
        success: false,
        error: "Insufficient credits",
        howToFix: "Use check_balance and deposit_credits tools",
      };
    }
  }

  return data;
}
```

### 2. Claude Desktop Config

```json
{
  "mcpServers": {
    "api-proxy": {
      "command": "bun",
      "args": ["run", "/path/to/src/mcp/server.ts"],
      "env": {
        "MY_API_KEY": "sk-xxxx-your-key"
      }
    }
  }
}
```

## Testing MCP Servers via stdin

MCP uses **stdio transport**, so test by piping JSON-RPC messages:

### Basic: Check tool list

```bash
printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}\n{"jsonrpc":"2.0","id":2,"method":"notifications/initialized"}\n{"jsonrpc":"2.0","id":3,"method":"tools/list"}\n' \
  | bun run src/mcp/server.ts 2>/dev/null \
  | tail -1 \
  | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin), indent=2))"
```

**What's happening:**
1. `initialize` — handshake with server (MUST be first)
2. `notifications/initialized` — tell server client is ready (MUST be second)
3. `tools/list` — get available tools (now safe to call)
4. `2>/dev/null` — suppress MCP debug logs (stderr), keep protocol (stdout)
5. `tail -1` — get only last JSON-RPC message (avoid multi-line noise)
6. `python3` — pretty-print the JSON response

### Advanced: Call a tool and parse result

```bash
printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}\n{"jsonrpc":"2.0","id":2,"method":"notifications/initialized"}\n{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"get_weather","arguments":{"latitude":35.1,"longitude":140.1}}}\n' \
  | bun run src/mcp/server.ts 2>/dev/null \
  | tail -1 \
  | python3 -c "import sys,json; r=json.load(sys.stdin); print(json.dumps(json.loads(r['result']['content'][0]['text']), indent=2))"
```

**Key gotchas:**
- ⚠️ Tool result is **doubly-wrapped**: `result.content[0].text` contains JSON string — must parse twice with `json.loads()`
- ⚠️ Order matters: `initialize` → `notifications/initialized` → tools/list/call
- ⚠️ If you send `notifications/initialized` before `initialize` finishes, you get harmless `Method not found` (ignore it, ordering still matters)
- ⚠️ Use `2>/dev/null` to hide stderr debug output

### One-liner tester function (bash)

```bash
test-mcp() {
  local tool=$1
  local args=$2
  printf "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{},\"clientInfo\":{\"name\":\"test\",\"version\":\"1.0\"}}}\n{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"notifications/initialized\"}\n{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":{\"name\":\"$tool\",\"arguments\":$args}}\n" \
    | bun run src/mcp/server.ts 2>/dev/null \
    | tail -1 \
    | python3 -c "import sys,json; r=json.load(sys.stdin); print(json.dumps(json.loads(r['result']['content'][0]['text']), indent=2))"
}

# Usage:
test-mcp get_weather '{"latitude":35.1,"longitude":140.1}'
test-mcp check_balance '{}'
```

## Paid API Integration

For APIs with credit/auth systems:

### Tool Design (3-tier approach)

```typescript
const tools: Tool[] = [
  // Tier 1: Free (no auth)
  {
    name: "get_weather",
    description: "Get weather. FREE.",
    // ...
  },

  // Tier 2: Account management (read-only, free)
  {
    name: "check_balance",
    description: "Check your account credit balance. FREE.",
    inputSchema: { type: "object", properties: {} },
  },

  // Tier 3: Paid tools (requires API key + balance)
  {
    name: "analyze_image",
    description: "AI image analysis. PAID: $0.05 per call. Requires account.",
    inputSchema: {
      type: "object",
      properties: {
        image_url: { type: "string" },
        analysis_type: { type: "string" },
      },
    },
  },
];

// Tool execution with auth checking
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  // Free tools never need auth
  if (["get_weather", "check_balance"].includes(name)) {
    return callProxy(name, args, false);
  }

  // Paid tools require API key
  if (!API_KEY) {
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify({
            error: "No API key found",
            howToFix: "Add MY_API_KEY to Claude Desktop config",
          }),
        },
      ],
      isError: true,
    };
  }

  return callProxy(name, args, true);
});
```

### Environment setup

```json
{
  "mcpServers": {
    "api-proxy": {
      "command": "bun",
      "args": ["run", "/path/to/src/mcp/server.ts"],
      "env": {
        "MY_API_KEY": "sk-xxxx-your-key-here"
      }
    }
  }
}
```

### API key sourcing (recommended order)

```typescript
const API_KEY =
  process.env.MY_API_KEY || // MCP config env vars
  process.env.ANTHROPIC_MY_KEY || // fallback env
  null;
```

## Error Handling Best Practices

### Pattern: Graceful failures with `howToFix`

```typescript
async function callProxy(endpoint, args, requireAuth) {
  try {
    const res = await fetch(`${API_BASE}/api/proxy/${endpoint}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...(requireAuth && API_KEY
          ? { Authorization: `Bearer ${API_KEY}` }
          : {}),
      },
      body: JSON.stringify(args),
      signal: AbortSignal.timeout(30000),
    });

    const data = await res.json();

    // Handle auth errors
    if (res.status === 401) {
      return {
        success: false,
        error: "Unauthorized",
        howToFix:
          "This tool requires API key. Add MY_API_KEY to Claude Desktop config.",
      };
    }

    // Handle insufficient credits
    if (res.status === 402) {
      return {
        success: false,
        error: "Insufficient credits",
        howToFix:
          "Check balance with check_balance tool, then use deposit_credits to add credits.",
      };
    }

    return data;
  } catch (err) {
    if (err.name === "AbortError") {
      return {
        success: false,
        error: "Request timeout (30s)",
        howToFix: "API server may be overloaded. Try again in a moment.",
      };
    }

    return {
      success: false,
      error: `Connection failed: ${err.message}`,
      howToFix: "Is the REST API server running? Check: curl http://localhost:3000/health",
    };
  }
}
```

**Key principles:**
- Never throw; always return `{ success: false, error: ..., howToFix: ... }`
- Include actionable guidance in `howToFix`
- Handle timeout separately from connection errors
- Let Claude see the error and decide next steps

## Testing Checklist

```
□ Tool registration: Verify all tools appear in tools/list
□ Free tools: Call each free tool, check real API response
□ Auth: Try calling paid tool WITHOUT API key, verify 401 message
□ Credit system: Create account, check balance, verify deposit
□ Insufficient balance: Try paid tool with $0 balance, verify 402 message
□ Result parsing: Verify tool output is valid JSON (not wrapped in extra quotes)
□ Error handling: Unplug API server, verify graceful "Connection failed" message
□ Timeout: Test with very slow upstream API (>30s), verify timeout error
```

## File Structure

```
project/
├── src/
│   └── mcp/
│       ├── server.ts          # MCP server (tool defs + HTTP adapter)
│       └── types.ts           # TypeScript interfaces for API responses
├── claude-desktop-config.json # MCP registration
├── test/
│   └── mcp.test.sh           # Testing scripts
└── README.md
```

## Common Pitfalls

| Mistake | Problem | Fix |
|---------|---------|-----|
| Business logic in MCP server | Hard to test, duplication | Keep MCP server thin, all logic in REST API |
| Missing `howToFix` in errors | User confused | Every error must have `howToFix` field |
| Tool result is JSON string, not object | Double-parse issue | Return `{ type: "text", text: JSON.stringify(...) }` |
| No timeout on fetch | Hangs forever if API crashes | Add `signal: AbortSignal.timeout(30000)` |
| API key in code | Security leak | Always use `process.env.MY_API_KEY` |
| Forgot `notifications/initialized` in test | Method not found errors | Always send: initialize → notifications/initialized → tools/list |
| Tool descriptions too vague | Claude makes bad decisions | Include pricing, auth requirements in description |

## Variant: HTTP Streamable Transport (Remote Access)

> Added v1.1.0 (2026-02-12) — Verified with `@modelcontextprotocol/sdk` v1.26.0 + Hono + Bun

### Problem

stdio transport only works locally (Claude Desktop spawns child process). Remote AI agents
need HTTP access to MCP tools.

### Solution: Dual-Mode Factory Pattern

Refactor the MCP server into a **factory function** that both stdio and HTTP modes can share:

```typescript
// src/mcp/proxy-mcp-server.ts
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';

// Factory — exported for HTTP mode
export function createProxyMcpServer(apiKey?: string): McpServer {
  const key = apiKey || process.env.MY_API_KEY || '';
  const server = new McpServer({ name: 'proxy', version: '1.0.0' });
  _registerTools(server, key);
  _registerResources(server);
  return server;
}

function _registerTools(server: McpServer, apiKey: string): void {
  // All tool registrations here
  // Pass apiKey to helper functions via closure
  server.tool('my_tool', 'desc', { ... }, async (args) => {
    const result = await callProxy('endpoint', args, true, apiKey);
    return toMcpResult(result);
  });
}

// stdio mode — only runs when executed directly
const isDirectRun = process.argv[1]?.includes('proxy-mcp-server');
if (isDirectRun) {
  async function main() {
    const server = createProxyMcpServer();
    const transport = new StdioServerTransport();
    await server.connect(transport);
  }
  main().catch(console.error);
}
```

### HTTP Route Module (Hono)

```typescript
// src/mcp/mcp-http-routes.ts
import { Hono } from 'hono';
import { WebStandardStreamableHTTPServerTransport }
  from '@modelcontextprotocol/sdk/server/webStandardStreamableHttp.js';
import { createMyMcpServer } from './my-mcp-server';
import { createProxyMcpServer } from './proxy-mcp-server';

export function createMcpRoutes(): Hono {
  const mcp = new Hono();

  // Stateless: fresh transport + server per request
  mcp.all('/free', async (c) => {
    const transport = new WebStandardStreamableHTTPServerTransport();
    const server = createMyMcpServer();
    await server.connect(transport);
    return transport.handleRequest(c.req.raw); // c.req.raw = Web Standard Request
  });

  mcp.all('/proxy', async (c) => {
    const apiKey = c.req.header('Authorization')?.replace('Bearer ', '')
                   || c.req.header('x-api-key');
    const transport = new WebStandardStreamableHTTPServerTransport();
    const server = createProxyMcpServer(apiKey);
    await server.connect(transport);
    return transport.handleRequest(c.req.raw);
  });

  return mcp;
}
```

### CORS Configuration (Critical!)

MCP HTTP Transport requires specific CORS headers. Without these, browser-based
MCP clients will fail:

```typescript
app.use('*', cors({
  origin: '*',
  allowMethods: ['GET', 'POST', 'DELETE', 'OPTIONS'],  // DELETE needed for session cleanup
  allowHeaders: [
    'Content-Type', 'Authorization',
    'mcp-session-id',          // MCP session tracking
    'mcp-protocol-version',    // MCP version negotiation
    'Last-Event-ID',           // SSE reconnection
    'x-api-key',               // Alternative API key header
  ],
  exposeHeaders: ['mcp-session-id', 'mcp-protocol-version'],  // Client needs to read these
  maxAge: 86400,
}));
```

### Testing HTTP MCP Endpoints

```bash
# CRITICAL: Must include Accept header!
# Without it → -32000 "Not Acceptable: Client must accept both application/json and text/event-stream"
curl -X POST http://localhost:3000/mcp/free \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"test","version":"1.0.0"}}}'

# Expected response (SSE format):
# event: message
# data: {"result":{"protocolVersion":"2025-03-26","capabilities":{...},"serverInfo":{...}},"jsonrpc":"2.0","id":1}
```

### Claude Desktop HTTP Config

```json
{
  "mcpServers": {
    "washin-free": { "url": "https://api.example.com/mcp/free" },
    "washin-proxy": { "url": "https://api.example.com/mcp/proxy" }
  }
}
```

### Gotchas (Verified 2026-02-12)

| Gotcha | Error / Symptom | Fix |
|--------|----------------|-----|
| Missing Accept header | `-32000 Not Acceptable` | Add `Accept: application/json, text/event-stream` |
| Missing CORS headers | Browser CORS error | Add `mcp-session-id`, `mcp-protocol-version`, `Last-Event-ID` to allowHeaders |
| apiKey name shadowing | Tool input `{ apiKey }` shadows factory's `apiKey` | Use destructuring rename: `{ apiKey: inputKey }` |
| isDirectRun missing | stdio starts when imported for HTTP | Add `process.argv[1]?.includes('filename')` guard |
| Protocol version | Old `2024-11-05` rejected | Use `2025-03-26` with SDK v1.26.0+ |
| Response format | SSE `event: message\ndata: {...}` not plain JSON | Parse SSE format in tests |
| SDK example location | Hard to find | `node_modules/@modelcontextprotocol/sdk/dist/esm/examples/server/honoWebStandardStreamableHttp.js` |

## References

- [MCP SDK Documentation](https://modelcontextprotocol.io/docs)
- [Stdio Transport](https://modelcontextprotocol.io/docs/concepts/transports#stdio-transport)
- [HTTP Streamable Transport](https://modelcontextprotocol.io/docs/concepts/transports#streamable-http)
- [Tool Use Pattern](https://modelcontextprotocol.io/docs/concepts/tools)
- SDK Hono example: `@modelcontextprotocol/sdk/dist/esm/examples/server/honoWebStandardStreamableHttp.js`

## Related Skills

- `multi-ai-cli-orchestration` — Routing complex tasks to specialized AI tools
- `systematic-debug` — Debugging large codebases with structured approach
- `api-design-patterns` — REST API design for LLM integration

---

**Example implementation:** [api-proxy MCP server](https://github.com/example/api-proxy-mcp)
