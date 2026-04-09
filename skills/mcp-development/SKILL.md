---
name: mcp-development
description: |
  Use when building MCP (Model Context Protocol) servers to expose tools, resources, or
  prompts to LLMs. Use when designing tool schemas, implementing TypeScript or Python MCP
  servers, writing tool descriptions for discoverability, creating evaluations for MCP
  effectiveness, or debugging MCP integrations. Triggers: "MCP server", "model context
  protocol", "build MCP", "MCP tool", "MCP development", "Claude tool", "tool server",
  "MCP SDK", "function calling server", "create MCP", "MCP integration".
---

# MCP Development

## When to Use

- Building a new MCP server to expose an API or service to LLMs (Claude, Cursor, etc.)
- Designing tool schemas, naming conventions, or descriptions for discoverability
- Implementing tool annotations, output schemas, or structured responses
- Debugging a broken MCP integration or improving tool quality
- Creating evaluations to measure how effectively an LLM uses your MCP server

## When NOT to Use

- **Consuming** a third-party API or service from within an agent — use `third-party-integration`
- **Coordinating multiple agents** that communicate via MCP — use `multi-agent-orchestration`
- **Auditing MCP server security** (auth, injection, sandboxing) — use `ai-security`

---

## Protocol Overview

MCP (Model Context Protocol) is an open standard that lets LLMs interact with external systems via a well-defined client-server protocol.

### Transports

| Transport | Use Case |
|-----------|----------|
| **stdio** | Local servers — process-to-process communication on the same machine |
| **SSE** (Server-Sent Events) | Remote servers with streaming responses; stateful sessions |
| **Streamable HTTP** | Remote servers; stateless JSON preferred for simpler scaling |

Prefer **streamable HTTP (stateless)** for remote production servers. Use **stdio** for local dev tools and CLI-based integrations.

### Primitives

- **Tools** — Functions the LLM can call (read data, trigger actions). The primary primitive.
- **Resources** — Static or dynamic content exposed for LLM context (files, configs, docs).
- **Prompts** — Reusable prompt templates the client can inject into conversations.

---

## SDK Selection

**TypeScript SDK (recommended)**
- Best AI code-gen support due to widespread TypeScript usage
- Static typing + Zod schemas catch errors at compile time
- Strong ecosystem: `@modelcontextprotocol/sdk`, `zod`, `tsx`
- Use for: production servers, remote APIs, anything that needs npm ecosystem

**Python SDK (FastMCP)**
- Better for data science / ML adjacent tools (pandas, numpy, etc.)
- Decorator-based registration is concise for simple tools
- Use Pydantic for input schemas instead of Zod
- Use for: local scripts, data pipelines, Python-native integrations

---

## 4-Phase Development Workflow

### Phase 1 — Research & Planning

1. **Read the MCP spec**: Start at `https://modelcontextprotocol.io/sitemap.xml`, fetch key pages with `.md` suffix
2. **Audit the target API**: List endpoints, auth methods, rate limits, and pagination patterns
3. **Decide tool scope**: Prioritize comprehensive API coverage over convenience wrappers; add workflow tools only where they provide clear LLM benefit
4. **Plan naming**: Use `noun_verb` convention (e.g., `issue_create`, `repo_list`, `file_read`)

### Phase 2 — Implementation

1. Set up project (TypeScript: `package.json`, `tsconfig.json`; Python: `pyproject.toml`)
2. Build shared infrastructure: API client, auth, error helpers, pagination utilities
3. Implement each tool with: Zod/Pydantic input schema, output schema, annotations, and actionable errors
4. Return both `content` (text/markdown) and `structuredContent` (JSON) when using TypeScript SDK

### Phase 3 — Review & Test

1. Run `npm run build` (TS) or `python -m py_compile` (Python) — zero compile errors required
2. Test interactively with MCP Inspector: `npx @modelcontextprotocol/inspector`
3. Check: no duplicated logic, consistent error handling, full type coverage, all tools have descriptions

### Phase 4 — Evaluations

Create an XML evaluation file with 10 complex, realistic QA pairs that test real tool use. See the Evaluation section below.

---

## Tool Design Principles

### API Coverage vs. Workflow Tools

Default to **comprehensive API coverage** — expose individual endpoints so agents can compose operations. Add higher-level workflow tools only when a common multi-step task would otherwise require excessive back-and-forth.

### Naming Convention: `noun_verb`

```
issue_create    issue_list    issue_close
repo_fork       repo_list     repo_get
file_read       file_write    file_delete
```

Consistent prefixes aid discoverability. Avoid vague names like `do_thing` or `handle_request`.

### Context Management

- Return **focused, relevant data** — not entire API responses
- Support **pagination** (`limit`, `cursor`) to avoid overwhelming context windows
- Include **filtering parameters** so agents can narrow results without multiple round trips
- Prefer structured JSON output so agents can extract fields programmatically

### Actionable Error Messages

Bad: `"Error: request failed"`
Good: `"Rate limit exceeded. Retry after 60 seconds. Reduce request frequency or cache results."`

Every error should tell the agent: what went wrong, why, and what to do next.

---

## Tool Annotations

Annotations communicate behavioral hints to MCP clients. Always declare them explicitly.

| Annotation | Type | Meaning |
|---|---|---|
| `readOnlyHint` | boolean | Tool does not modify state |
| `destructiveHint` | boolean | Tool may delete or overwrite data |
| `idempotentHint` | boolean | Calling multiple times has same effect as once |
| `openWorldHint` | boolean | Tool interacts with external/unpredictable systems |

### TypeScript Example — Read-Only Tool with Annotations

```typescript
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";

const server = new McpServer({ name: "github-mcp", version: "1.0.0" });

server.registerTool(
  "issue_list",
  {
    description:
      "List issues in a GitHub repository. Returns issue number, title, state, labels, and author. " +
      "Supports filtering by state (open/closed/all), label, and assignee. Paginates with limit/cursor.",
    inputSchema: z.object({
      owner: z.string().describe("Repository owner (username or org)"),
      repo: z.string().describe("Repository name"),
      state: z
        .enum(["open", "closed", "all"])
        .default("open")
        .describe("Filter by issue state"),
      label: z.string().optional().describe("Filter by label name"),
      limit: z
        .number()
        .int()
        .min(1)
        .max(100)
        .default(20)
        .describe("Number of issues to return (1-100)"),
      cursor: z.string().optional().describe("Pagination cursor from previous response"),
    }),
    annotations: {
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: true,
    },
  },
  async ({ owner, repo, state, label, limit, cursor }) => {
    // implementation
    const issues = await fetchIssues({ owner, repo, state, label, limit, cursor });
    return {
      content: [{ type: "text", text: formatIssuesMarkdown(issues) }],
      structuredContent: { issues, nextCursor: issues.nextCursor },
    };
  }
);
```

### TypeScript Example — Destructive Tool with Annotations

```typescript
server.registerTool(
  "issue_close",
  {
    description:
      "Close an open GitHub issue. Permanently changes issue state to closed. " +
      "Provide the issue number from issue_list. Cannot be undone via MCP.",
    inputSchema: z.object({
      owner: z.string().describe("Repository owner"),
      repo: z.string().describe("Repository name"),
      issue_number: z.number().int().positive().describe("Issue number to close"),
      comment: z
        .string()
        .optional()
        .describe("Optional comment to post before closing"),
    }),
    annotations: {
      readOnlyHint: false,
      destructiveHint: true,
      idempotentHint: true,   // closing an already-closed issue is safe
      openWorldHint: true,
    },
  },
  async ({ owner, repo, issue_number, comment }) => {
    if (comment) await postComment({ owner, repo, issue_number, body: comment });
    await closeIssue({ owner, repo, issue_number });
    return {
      content: [
        {
          type: "text",
          text: `Closed issue #${issue_number} in ${owner}/${repo}.`,
        },
      ],
    };
  }
);
```

---

## Evaluations

After implementing your server, create 10 evaluation QA pairs that test real multi-tool use.

### Requirements for Each Question

- **Independent** — not dependent on other questions or prior state
- **Read-only** — only non-destructive operations required to answer
- **Complex** — requires multiple tool calls and deep exploration
- **Realistic** — a real user would plausibly ask this
- **Verifiable** — single, unambiguous answer (string or number comparison)
- **Stable** — answer will not change over time

### XML Output Format

```xml
<evaluation>
  <qa_pair>
    <question>
      In the anthropics/evals repository, which contributor opened the most issues
      labeled "bug" in Q1 2024, and how many did they open?
    </question>
    <answer>janedoe:7</answer>
  </qa_pair>
  <!-- 9 more qa_pairs... -->
</evaluation>
```

---

## Common Mistakes

| Mistake | Problem | Fix |
|---|---|---|
| Too many tools (50+) | Overwhelms context window, hurts discoverability | Group related operations; max ~20-30 tools per server |
| Vague descriptions | Agent picks wrong tool or misuses parameters | Include what it returns, when to use it, and parameter examples |
| Generic error messages | Agent retries blindly or fails silently | Include error type, cause, and remediation in every error |
| Missing idempotency hint | Agent avoids retrying safe operations | Mark idempotent writes (`idempotentHint: true`) explicitly |
| No rate limiting | Server crashes under agent retry loops | Add per-tool rate limiting and return `Retry-After` in errors |
| Returning full API responses | Context window bloat, slow parsing | Filter to only the fields agents actually need |
| No pagination | Single tool call returns 1000+ items | Always support `limit` + `cursor` for list endpoints |

---

## Verification Checklist

- [ ] All tools have clear, specific descriptions (what it does, what it returns, when to use)
- [ ] All input fields have `.describe()` annotations in Zod / docstrings in Pydantic
- [ ] All tools declare `readOnlyHint`, `destructiveHint`, `idempotentHint`, `openWorldHint`
- [ ] List tools support pagination (`limit` + `cursor` or equivalent)
- [ ] Error messages are actionable — include cause and next steps
- [ ] `npm run build` (or `py_compile`) passes with zero errors
- [ ] Tested interactively via MCP Inspector
- [ ] No duplicated logic — shared utilities extracted
- [ ] Evaluation XML file created with 10 verified QA pairs
- [ ] Tool count is reasonable (under ~30) for context window constraints
