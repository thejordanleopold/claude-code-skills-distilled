---
name: mcp-auditor
description: |
  Use when auditing MCP server configurations for poisoned tool descriptions, malicious
  tool registrations, or exfiltration channels. Use when reviewing agent config files
  before adding a new MCP server, auditing live tool descriptions served by an MCP
  endpoint, or investigating suspicious tool behavior at runtime. Triggers: "MCP audit",
  "MCP poisoning", "tool description attack", "MCP config review", "tool shadowing",
  "rug pull", "HashJack", "MPMA", "MCP exfiltration", "mcp.json audit", "tool description
  injection", "cross-tool escalation", "MCP security", "audit MCP tools", "scan MCP",
  "MCP server review", "tool poisoning", "claude.json audit", "AgentSeal scan-mcp".
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# MCP Auditor

Detect poisoned tool descriptions, malicious tool registrations, and supply-chain risks
in MCP server configurations across 28 AI agents.

**Core principle:** MCP tool descriptions are instructions the agent reads before deciding
how to use a tool. Hidden instructions in descriptions are followed as authoritative guidance
— not treated as user-supplied data. Config file auditing and live tool description review
are distinct: do both.

## When to Use

- Before adding any new MCP server to any agent config
- After unexpected agent behavior involving tool calls
- Auditing config files inherited from another developer or repo
- Reviewing a live MCP server's tool descriptions before trusting it
- Checking for rug-pull risk (unpinned server versions)

## When NOT to Use

- MCP server *code* security (SQLi, cmd injection, input validation, URL allowlists, auth) → use `ai-security`
- Skill files containing MCP configs (scan the skill first) → use `skill-scanner`
- Threat modeling MCP trust boundaries in a new system design → use `threat-modeling`
- Supply chain / npm dependency audit of MCP server packages → use `security-hardening`

---

## Config File Locations — Tier 1 (check these first)

| Agent | Config Path |
|-------|-------------|
| Claude Code | `~/.claude.json` |
| Claude Desktop (macOS) | `~/Library/Application Support/Claude/claude_desktop_config.json` |
| Claude Desktop (Linux) | `~/.config/Claude/claude_desktop_config.json` |
| Cursor | `~/.cursor/mcp.json` |
| Windsurf | `~/.codeium/windsurf/mcp_config.json` |
| VS Code | `~/Library/Application Support/Code/User/settings.json` (key: `"mcpServers"`) |
| Gemini CLI | `~/.gemini/settings.json` |

Full 28-agent config paths (macOS/Linux/Windows): `references/agent-config-locations.md`

**Always check project-level configs too:**
```bash
find . -maxdepth 3 -name "mcp.json" -o -name ".mcp.json" -o -name "mcp_config.json" 2>/dev/null
grep -rl '"mcpServers"' . --include="*.json" 2>/dev/null | head -5
```

---

## Poisoning Pattern Quick-Reference

| Pattern | What It Does | Severity |
|---------|-------------|----------|
| **Description Poisoning** | Hidden instructions in tool descriptions | CRITICAL |
| **Result Injection** | Instructions in tool return values | CRITICAL |
| **Exfiltration via Tools** | Agent tricked into encoding data in tool calls | CRITICAL |
| **Schema Manipulation** | Widened parameters enabling injection | HIGH |
| **Cross-Tool Escalation** | Tool A result authorizes unintended Tool B use | HIGH |
| **Rug Pull** | Tool behavior changes after trust established | HIGH |
| **Tool Shadowing** | Malicious tool mimics built-in tool name | HIGH |
| **False Error Escalation** | Error response triggers privileged fallback | HIGH |
| **Cross-Tool Poisoning** | Tool A output poisons Tool B's input | HIGH |
| **MPMA** | Descriptions bias agent toward malicious tool | MEDIUM |
| **HashJack** | Instructions hidden after `#` in URLs | MEDIUM |

Full mechanics, indicators, and examples: `references/poisoning-patterns.md`

---

## Live Tool Description Audit Workflow

### Phase 1: Locate configs

```bash
bash ~/.claude/skills/mcp-auditor/scripts/audit-mcp-configs.sh
```

This finds all config files across Tier 1–3 agents, checks for:
- Unpinned server versions (rug pull risk)
- Plain HTTP endpoints
- Credentials in env blocks
- Description poisoning keywords
- Tool name conflicts with built-ins

### Phase 2: Enumerate tool descriptions

For each registered server, enumerate its tools:

```bash
# stdio server
agentseal scan-mcp --server "npx @org/mcp-server@1.2.3"

# SSE server
agentseal scan-mcp --sse http://localhost:3001/sse
```

Without AgentSeal, start the server and call `tools/list` via MCP protocol to get all tool names and descriptions.

### Phase 3: Analyze descriptions

For each tool description, check:

```bash
# Instruction-language patterns
echo "<description text>" | grep -iE \
  'ignore|override|instead|before responding|disregard|you must|always|never|do not tell'

# Exfiltration patterns
echo "<description text>" | grep -iE \
  'include.*credential|pass.*token|send.*key|http[s]?://'

# Authority claims
echo "<description text>" | grep -iE \
  'authorized|permission|required|compliance|legal|ceo|admin'
```

**Semantic check (beyond patterns):** Does the description do anything other than describe what the tool does, what parameters it accepts, and what it returns? Any imperative sentence targeting agent behavior is suspicious.

---

## Config Audit Checklist

**Per tool description:**
- [ ] Contains only functional documentation (what it does, params, return)
- [ ] No imperative instructions targeting agent behavior
- [ ] No exfiltration patterns (URLs, parameter-passing of agent data)
- [ ] No authority claims ("always use this", "required by policy")
- [ ] No name collision with built-in tools (read_file, bash, edit, computer_use)

**Per server config entry:**
- [ ] Version pinned (e.g., `@org/server@1.2.3`, not `@latest`)
- [ ] HTTPS (not HTTP) for SSE servers
- [ ] No credentials in `env` block — use system env vars
- [ ] Trust score checked at agentseal.org/mcp if it's a public server

**Cross-server:**
- [ ] No duplicate tool names across servers (shadowing risk)
- [ ] Loading order reviewed (first server registered typically wins name conflicts)

---

## Cross-Reference: ai-security MCP Checklist

This skill audits *configurations and descriptions*. For MCP server *code* security, the
`ai-security` skill owns these checks (see its "MCP Server Audit Checklist" section):

- Input validation (pydantic/zod schemas per parameter)
- No SQL injection (parameterized queries)
- No command injection (no `shell=True` with untrusted input)
- URL allowlist (block 127.0.0.1, 10.0.0.0/8, 169.254.x.x)
- Authentication (API key or mTLS on every MCP endpoint)
- Sandboxed code interpreters
- Rate limiting per agent/user
- Structured logging with secrets masked

---

## Finding Severity Guide

| Severity | Examples |
|----------|---------|
| CRITICAL | Instructions in tool descriptions; exfiltration via tool call params; result injection |
| HIGH | Unpinned versions; plain HTTP; tool name shadowing; schema accepts arbitrary strings |
| MEDIUM | MPMA preference language; HashJack URL fragments; credentials in env blocks |
| LOW | Missing tool scope declarations; overly broad descriptions |

---

## Verification Checklist

- [ ] All Tier 1 agent config files located and reviewed
- [ ] Project-level MCP configs checked
- [ ] `audit-mcp-configs.sh` run — no CRITICAL/HIGH findings
- [ ] Live tool descriptions enumerated and pattern-checked
- [ ] All server versions pinned to exact semver
- [ ] No tool name collisions with built-ins
- [ ] ai-security MCP checklist applied to server code (if you own it)
