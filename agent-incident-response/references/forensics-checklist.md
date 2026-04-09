# Forensics Evidence Collection Checklist

Systematic evidence collection for agent security incidents. Preserve before remediating.

---

## Pre-Forensics: Preserve State

Before changing anything, capture the current state:

```bash
# Snapshot all ~/.claude/ file hashes
find ~/.claude/ -type f | sort | while read f; do
  shasum -a 256 "$f" 2>/dev/null
done > /tmp/incident-snapshot-$(date +%Y%m%d-%H%M%S).txt

# Capture running processes
ps aux > /tmp/incident-processes-$(date +%Y%m%d-%H%M%S).txt

# Capture environment (redact secrets before sharing)
env | grep -viE "key|token|secret|password" > /tmp/incident-env-$(date +%Y%m%d-%H%M%S).txt
```

---

## Evidence Categories

### 1. File System Evidence

```bash
# All files modified in the last 24 hours under ~/.claude/
find ~/.claude/ -mtime -1 -type f | sort

# All files modified in the last 7 days
find ~/.claude/ -mtime -7 -type f | sort

# New symlinks (not in baseline)
find ~/.claude/ -type l | while read f; do
  echo "$f -> $(readlink -f $f 2>/dev/null || readlink $f)"
done

# New conftest.py files
find ~/.claude/ -name "conftest.py" -mtime -7

# Unexpected binary files
find ~/.claude/ -name "*.png" -o -name "*.jpg" -o -name "*.so" -o -name "*.dylib" | \
  sort | while read f; do echo "$f: $(file $f 2>/dev/null | head -1)"; done
```

### 2. Config File Evidence

```bash
# Capture all config state at time of incident
for f in \
  ~/.claude/CLAUDE.md \
  ~/.claude/settings.json \
  ~/.claude.json \
  "$HOME/Library/Application Support/Claude/claude_desktop_config.json" \
  ~/.cursor/mcp.json \
  ~/.codeium/windsurf/mcp_config.json; do
  if [[ -f "$f" ]]; then
    echo "=== $f ==="
    cat "$f"
    echo ""
  fi
done
```

### 3. Skill File Evidence

```bash
# Capture all SKILL.md files and scripts for review
find ~/.claude/skills/ -name "SKILL.md" | while read f; do
  echo "=== $f ==="
  head -30 "$f"  # frontmatter + first section
  echo ""
done

# Check all shell scripts in skills
find ~/.claude/skills/ -name "*.sh" | while read f; do
  echo "=== $f ==="
  cat "$f"
  echo ""
done
```

### 4. Network Evidence

```bash
# macOS: DNS queries in last hour (shows external connections attempted)
log show --predicate 'category == "dns"' --last 1h 2>/dev/null | \
  grep -v "apple\|icloud\|localhost\|local\b" | tail -50

# Active connections at time of detection
ss -tnp 2>/dev/null || netstat -tnp 2>/dev/null

# macOS: network traffic by process
nettop -P -n 2>/dev/null | head -20
```

### 5. Process Evidence

```bash
# macOS: recently launched processes
log show --predicate 'eventMessage contains "spawn" OR eventMessage contains "exec"' \
  --last 1h 2>/dev/null | grep -v "kernel\|launchd\|WindowServer" | tail -50

# Shell history with timestamps (zsh)
fc -l -t '%Y-%m-%d %H:%M:%S' -100 2>/dev/null || tail -200 ~/.zsh_history
```

### 6. Deobfuscation Evidence

Run the full deobfuscation scan and capture output:

```bash
bash ~/.claude/skills/skill-scanner/scripts/scan-skills.sh --deobfuscate \
  2>&1 | tee /tmp/incident-deobfuscation-$(date +%Y%m%d).txt
```

---

## Credential Exposure Assessment

For each credential the agent had access to, determine exposure window:

| Credential | Source | Last Rotated | Agent Had Access Since | Exposure Window |
|------------|--------|-------------|----------------------|-----------------|
| (fill in) | env var / config / vault | | | |

**Rotation priority:**
1. API keys with write/delete permissions
2. Credentials for external services (payment, email, auth)
3. Read-only API keys
4. Internal service tokens

---

## Root Cause Attribution

Match evidence to attack vector:

| Finding | Likely Vector | Reference |
|---------|--------------|-----------|
| CLAUDE.md modified | Memory poison (96%) | attack-vectors.md #1 |
| `hooks:` in SKILL.md frontmatter | Hook exploitation (89%) | attack-vectors.md #3 |
| conftest.py in skill dir | Test RCE (60%) | attack-vectors.md #4 |
| Symlink to ~/.ssh or ~/.aws | Symlink exfil (54%) | attack-vectors.md #5 |
| package.json with postinstall | Supply chain RCE (36%) | attack-vectors.md #6 |
| PNG/image in skill dir | Image injection (30%) | attack-vectors.md #7 |
| curl\|bash in setup step | Remote exec (7%) | attack-vectors.md #8 |
| Unicode tag chars in file | Prompt smuggling | attack-vectors.md #11 |
| Instructions in MCP tool description | Description poisoning | mcp-auditor/references/poisoning-patterns.md #1 |

---

## Chain of Custody

If this incident has legal, compliance, or HR implications, maintain chain of custody:

1. Do not modify original evidence files
2. Work from copies (`cp -r ~/.claude/ /tmp/incident-evidence-$(date +%Y%m%d)/`)
3. Hash all evidence files: `shasum -a 256 /tmp/incident-evidence-*`
4. Document who accessed evidence and when
5. Store evidence in a location the compromised agent cannot reach
