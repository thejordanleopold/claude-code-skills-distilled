#!/usr/bin/env bash
# audit-mcp-configs: find and analyze MCP server configurations across all agents
# Usage: bash audit-mcp-configs.sh [--json]

set -euo pipefail

JSON_OUTPUT=false
[[ "${1:-}" == "--json" ]] && JSON_OUTPUT=true

RED='\033[0;31m'; YELLOW='\033[0;33m'; GREEN='\033[0;32m'; NC='\033[0m'
crit() { echo -e "${RED}[CRITICAL]${NC} $*"; }
high() { echo -e "${RED}[HIGH]${NC}     $*"; }
med()  { echo -e "${YELLOW}[MEDIUM]${NC}  $*"; }
ok()   { echo -e "${GREEN}[OK]${NC}      $*"; }

echo "=== MCP Config Auditor ==="
echo ""

# ── Discover config files ──────────────────────────────────────────────────

declare -a CONFIG_FILES=()

# Tier 1 — most common
declare -a TIER1_PATHS=(
  "$HOME/.claude.json"
  "$HOME/Library/Application Support/Claude/claude_desktop_config.json"
  "$HOME/.config/Claude/claude_desktop_config.json"
  "$HOME/.cursor/mcp.json"
  "$HOME/.codeium/windsurf/mcp_config.json"
  "$HOME/Library/Application Support/Code/User/settings.json"
  "$HOME/.config/Code/User/settings.json"
  "$HOME/.gemini/settings.json"
)

# Tier 2
declare -a TIER2_PATHS=(
  "$HOME/.codex/config.json"
  "$HOME/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json"
  "$HOME/.continue/config.json"
  "$HOME/.config/zed/settings.json"
  "$HOME/.amp/config.json"
  "$HOME/.aws/amazonq/mcp.json"
  "$HOME/.config/goose/config.yaml"
  "$HOME/.kiro/settings/mcp.json"
)

for path in "${TIER1_PATHS[@]}" "${TIER2_PATHS[@]}"; do
  [[ -f "$path" ]] && CONFIG_FILES+=("$path")
done

# Project-level configs
while IFS= read -r f; do
  CONFIG_FILES+=("$f")
done < <(find . -maxdepth 3 \( -name "mcp.json" -o -name ".mcp.json" -o -name "mcp_config.json" \) 2>/dev/null)

# JSON files with mcpServers key anywhere
while IFS= read -r f; do
  [[ ! " ${CONFIG_FILES[*]} " =~ " $f " ]] && CONFIG_FILES+=("$f")
done < <(grep -rl '"mcpServers"' . --include="*.json" 2>/dev/null | head -5)

if [[ ${#CONFIG_FILES[@]} -eq 0 ]]; then
  echo "No MCP config files found."
  exit 0
fi

echo "Found ${#CONFIG_FILES[@]} config file(s):"
for f in "${CONFIG_FILES[@]}"; do echo "  $f"; done
echo ""

# ── Analyze each config ────────────────────────────────────────────────────

for config in "${CONFIG_FILES[@]}"; do
  echo "── $config ──"

  # Unpinned versions (rug pull risk)
  if grep -q '@latest\|"[^@"]*"$' "$config" 2>/dev/null; then
    if grep -qE '"command".*npx|"command".*pnpx' "$config" 2>/dev/null; then
      # Check if any npx command lacks a version pin
      if grep -E '"command"' "$config" | grep -qv '@[0-9]'; then
        high "Unpinned server version (rug pull risk): $config"
      fi
    fi
  fi

  # Plain HTTP (not HTTPS)
  if grep -qE '"url":\s*"http://' "$config" 2>/dev/null; then
    high "Plain HTTP MCP server (use HTTPS): $config"
    grep -n '"url".*http://' "$config" | head -3
  fi

  # Secrets in env block
  if grep -qiE '"(token|api_key|secret|password|key)":\s*"[^"]{8,}"' "$config" 2>/dev/null; then
    crit "Credentials in config file: $config"
    grep -niE '"(token|api_key|secret|password)"' "$config" | grep -v '""' | head -3
  fi

  # Tool description poisoning indicators
  if grep -qiE 'ignore|override|instead of|before responding|disregard|you must|you should' "$config" 2>/dev/null; then
    # Only flag if these appear in description/name fields (not comments)
    if grep -iE '"description".*ignore|"description".*override|"name".*ignore' "$config" 2>/dev/null; then
      crit "Possible description poisoning in $config"
      grep -niE '"description".*ignore|"description".*override' "$config" | head -3
    fi
  fi

  # URL fragment injection
  if grep -qE '"url".*#' "$config" 2>/dev/null; then
    med "URL with fragment in config (HashJack risk): $config"
    grep -nE '"url".*#' "$config" | head -3
  fi

  # Tool name shadowing — check for built-in name collisions
  for builtin in "read_file" "write_file" "bash" "edit" "computer_use" "execute"; do
    if grep -q "\"$builtin\"" "$config" 2>/dev/null; then
      high "Tool name shadows built-in '$builtin': $config"
    fi
  done

  # Count registered servers
  server_count=$(grep -c '"command"\|"url"' "$config" 2>/dev/null || echo "0")
  ok "$server_count server(s) registered"
  echo ""
done

# ── Aggregate summary ─────────────────────────────────────────────────────

echo "── Summary ──"
echo "Configs scanned: ${#CONFIG_FILES[@]}"
echo "For full poisoning pattern reference: see references/poisoning-patterns.md"
echo "For tool description semantic analysis: manually review each server's tool list"
echo ""
echo "Next steps:"
echo "  1. For each CRITICAL: rotate any exposed credentials immediately"
echo "  2. For unpinned servers: pin to exact version (e.g. @org/server@1.2.3)"
echo "  3. For live tool description audit: use 'agentseal scan-mcp --server <cmd>'"
