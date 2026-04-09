# MCP Server Config Locations — 28 AI Agents

Config file paths for every major AI agent. Run `audit-mcp-configs.sh` to scan all automatically.

---

## Tier 1: Most Common (check these first)

| Agent | macOS | Linux | Windows |
|-------|-------|-------|---------|
| **Claude Code** | `~/.claude.json` | `~/.claude.json` | `%APPDATA%\Claude\claude.json` |
| **Claude Desktop** | `~/Library/Application Support/Claude/claude_desktop_config.json` | `~/.config/Claude/claude_desktop_config.json` | `%APPDATA%\Claude\claude_desktop_config.json` |
| **Cursor** | `~/.cursor/mcp.json` | `~/.cursor/mcp.json` | `%APPDATA%\Cursor\mcp.json` |
| **Windsurf** | `~/.codeium/windsurf/mcp_config.json` | `~/.codeium/windsurf/mcp_config.json` | `%APPDATA%\Codeium\windsurf\mcp_config.json` |
| **VS Code** | `~/Library/Application Support/Code/User/settings.json` | `~/.config/Code/User/settings.json` | `%APPDATA%\Code\User\settings.json` |
| **Gemini CLI** | `~/.gemini/settings.json` | `~/.gemini/settings.json` | `%APPDATA%\gemini\settings.json` |

**VS Code key in settings.json:** `"mcpServers"` or `"github.copilot.chat.mcpServers"`

---

## Tier 2: Common (check next)

| Agent | Config Path |
|-------|-------------|
| **Codex CLI** | `~/.codex/config.json` |
| **Cline** | VS Code extension storage: `~/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json` |
| **Roo Code** | VS Code extension storage: `...rooveterinaryinc.roo-cline/settings/cline_mcp_settings.json` |
| **Kilo Code** | VS Code extension storage: `...kilocode.kilo-code/settings/cline_mcp_settings.json` |
| **Copilot CLI** | `~/.config/gh-copilot/config.yml` |
| **Aider** | `~/.aider.conf.yml` (MCP via `.env` or config) |
| **Continue** | `~/.continue/config.json` |
| **Zed** | `~/.config/zed/settings.json` → `"context_servers"` key |
| **Amp** | `~/.amp/config.json` |

---

## Tier 3: Extended (comprehensive audit)

| Agent | Config Path |
|-------|-------------|
| **Amazon Q** | `~/.aws/amazonq/mcp.json` |
| **Junie** (JetBrains) | `~/.config/JetBrains/junie/mcp_config.json` |
| **Goose** | `~/.config/goose/config.yaml` |
| **Kiro** | `~/.kiro/settings/mcp.json` |
| **OpenCode** | `~/.config/opencode/config.json` |
| **OpenClaw** | `~/.openclaw/config.json` |
| **Crush** | `~/.crush/mcp.json` |
| **Qwen Code** | `~/.qwen/mcp_config.json` |
| **Grok CLI** | `~/.grok/config.json` |
| **Visual Studio** (AI Toolkit) | `%APPDATA%\Microsoft\VisualStudio\AI\mcp_config.json` |
| **Kimi CLI** | `~/.kimi/config.json` |
| **Trae** | `~/.trae/mcp_config.json` |
| **MaxClaw** | `~/.maxclaw/config.json` |

---

## Project-Level MCP Configs (always check)

Many agents also support project-scoped MCP configs:
```
./.mcp.json
./.claude/settings.json
./.cursor/mcp.json
./.vscode/mcp.json
```

These override user-level configs and are often introduced via git (supply chain vector).

```bash
# Find all project-level MCP configs in current directory tree
find . -name "mcp.json" -o -name "mcp_config.json" -o -name ".mcp.json" 2>/dev/null | head -20
grep -r '"mcpServers"' . --include="*.json" -l 2>/dev/null | head -10
```

---

## JSON Structure Reference

Most agents use one of two config shapes:

**Claude Desktop / Claude Code style:**
```json
{
  "mcpServers": {
    "server-name": {
      "command": "npx",
      "args": ["@org/server@1.2.3"],
      "env": {}
    }
  }
}
```

**SSE style:**
```json
{
  "mcpServers": {
    "server-name": {
      "url": "http://localhost:3001/sse"
    }
  }
}
```

**Red flags in config structure:**
- `"command": "npx @org/server"` — no version pinned (rug pull risk)
- `"url": "http://..."` — plain HTTP (not HTTPS)
- `"env": {"TOKEN": "..."}` — secrets in config files
- Servers with `@latest` in args
