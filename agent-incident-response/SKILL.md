---
name: agent-incident-response
description: "Use when an AI agent has been compromised, behaved unexpectedly, executed unauthorized actions, or may have had credentials exposed. Use when CLAUDE.md was modified without authorization, a skill executed a malicious payload, an agent accessed files outside its scope, or suspicious tool calls were detected. Triggers: \"agent compromised\", \"agent behaved unexpectedly\", \"suspicious agent behavior\", \"CLAUDE.md modified\", \"skill executed payload\", \"agent accessed credentials\", \"unauthorized tool calls\", \"agent incident\", \"agent compromise response\", \"agent forensics\", \"credential exposed by agent\", \"agent wrote unexpected files\", \"memory poisoned\", \"hook fired\", \"agent anomaly\"."
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# Agent Incident Response

Post-compromise response for AI agent security incidents. Covers containment, forensics,
recovery, and post-incident hardening.

**Core principle:** Assume breach. Act on the worst-case scope until forensics narrows it.
Speed of containment limits blast radius — rotate credentials before investigating root cause.

## When to Use

- Agent accessed files, credentials, or APIs outside its expected scope
- CLAUDE.md, settings.json, or agent config was modified unexpectedly
- A skill executed a script that wasn't expected or authorized
- Unusual tool call patterns detected (off-hours, wrong scope, high frequency)
- Any confirmed finding from `skill-scanner` or `mcp-auditor`
- Credential may have been exposed in agent output or logs

## When NOT to Use

- Proactive scanning for threats (before incident) → use `skill-scanner` or `mcp-auditor`
- Testing prompt injection resistance → use `prompt-injection-tester`
- Runtime behavioral monitoring of deployed agents → use `ai-security`
- General application security incident (non-agent) → use `security-hardening`

---

## Incident Severity Classification

Classify first — determines response speed.

| Severity | Indicators | Response SLA |
|----------|-----------|--------------|
| **P0 — Critical** | Credentials confirmed exposed/exfiltrated; CLAUDE.md/settings.json modified; data sent to external URL | Immediate — within 15 min |
| **P1 — High** | Agent accessed out-of-scope files/APIs; suspicious payload executed; hook fired without authorization | Within 1 hour |
| **P2 — Medium** | Anomalous tool call pattern; unexpected file writes within scope; skill scanner finding not yet exploited | Within 4 hours |
| **P3 — Low** | Suspicious pattern but no confirmed access; potential deobfuscation finding; MEDIUM skill-scanner finding | Next maintenance window |

---

## Phase 1: Immediate Containment (P0/P1 — do before forensics)

**1.1 Kill the agent session**
```bash
# Claude Code: close the session
# For deployed agents: stop the process
kill $(pgrep -f "claude\|agent") 2>/dev/null
```

**1.2 Rotate potentially exposed credentials — do not wait for forensics**

Credentials the agent had access to (check all):
```bash
# List what the agent could see
cat ~/.claude.json | python3 -m json.tool | grep -i "key\|token\|secret\|password" 2>/dev/null
cat ~/.claude/settings.json 2>/dev/null
env | grep -iE "api_key|secret|token|password|anthropic|openai|aws|github"
```

For each credential found: **revoke immediately, rotate, update in vault**. Do not verify whether it was actually accessed first — the blast radius of waiting exceeds the cost of rotation.

**1.3 Isolate modified configs**
```bash
# Check if baseline exists and diff it
bash ~/.claude/skills/skill-scanner/scripts/baseline-sha256.sh check 2>/dev/null || \
  echo "No baseline — compare manually"

# Manual critical file check
for f in ~/.claude/CLAUDE.md ~/.claude/settings.json \
  "$HOME/Library/Application Support/Claude/claude_desktop_config.json"; do
  [[ -f "$f" ]] && echo "=== $f ===" && cat "$f"
done
```

---

## Phase 2: Forensics (establish what happened)

**2.1 Timeline reconstruction**

```bash
# Files modified in the last 24 hours in ~/.claude/
find ~/.claude/ -newer ~/.agentseal-baseline.txt -type f 2>/dev/null | sort
# Or by modification time
find ~/.claude/ -mtime -1 -type f | sort

# Shell history around the incident window
tail -200 ~/.zsh_history 2>/dev/null || tail -200 ~/.bash_history 2>/dev/null

# System file access log (macOS)
log show --predicate 'process == "claude"' --last 1h 2>/dev/null | tail -50
```

**2.2 Scope the access — what did it read/write?**

```bash
# Files accessed by the agent process (macOS — requires sudo)
sudo fs_usage -f filesys -e claude 2>/dev/null | head -100

# Network connections made
netstat -an 2>/dev/null | grep ESTABLISHED
# Or check DNS (macOS)
log show --predicate 'category == "dns"' --last 1h 2>/dev/null | grep -v "apple\|icloud\|local" | tail -30
```

**2.3 CLAUDE.md integrity check**

```bash
# Check for injected content
cat ~/.claude/CLAUDE.md
# Look for: new instructions, shell commands, external URLs, authority claims
# Flag: anything that wasn't there before or references external resources

# Check for invisible characters
python3 -c "
content = open('$HOME/.claude/CLAUDE.md', 'rb').read().decode('utf-8', errors='ignore')
tags = [c for c in content if 0xE0000 <= ord(c) <= 0xE007F]
bidi = [c for c in content if ord(c) in {0x202E,0x202D,0x202B,0x202A}]
if tags: print(f'CRITICAL: Unicode tag chars in CLAUDE.md: {len(tags)} chars')
if bidi: print(f'CRITICAL: BiDi override chars in CLAUDE.md')
if not tags and not bidi: print('No invisible characters detected')
"
```

**2.4 Identify root cause skill/vector**

```bash
# Run full skill scanner to find the attack vector
bash ~/.claude/skills/skill-scanner/scripts/scan-skills.sh --deobfuscate

# Check recently modified skills
find ~/.claude/skills/ -mtime -7 -name "*.md" -o -name "*.sh" | sort
```

See `references/forensics-checklist.md` for complete evidence collection procedure.

---

## Phase 3: Recovery

**3.1 CLAUDE.md recovery**

```bash
# If poisoned — restore clean version
# Option A: restore from git if tracked
cd ~/.claude && git diff CLAUDE.md && git checkout CLAUDE.md

# Option B: manually remove injected content and verify
# After editing: re-check for invisible chars (step 2.3)
```

**3.2 Quarantine or remove malicious skill**

```bash
# Move to quarantine — do not delete yet (preserve for investigation)
mkdir -p ~/.claude/quarantine/$(date +%Y%m%d)
mv ~/.claude/skills/<malicious-skill>/ ~/.claude/quarantine/$(date +%Y%m%d)/

# Verify skill is no longer loadable
ls ~/.claude/skills/
```

**3.3 MCP config audit**

After any agent compromise, audit all MCP configs:
```bash
bash ~/.claude/skills/mcp-auditor/scripts/audit-mcp-configs.sh
```

**3.4 Rebuild baseline after recovery**

```bash
# Once all changes are confirmed clean — reset baseline
bash ~/.claude/skills/skill-scanner/scripts/baseline-sha256.sh init
echo "New baseline established: $(date)"
```

---

## Phase 4: Post-Incident Hardening

After recovery, address the root cause permanently:

| Root Cause | Hardening Action |
|------------|-----------------|
| Memory-poison skill installed | Enforce skill-scanner before any install; audit all existing skills |
| Hook exploit in SKILL.md | Add CLAUDE.md guardrail: refuse `hooks:` without confirmation |
| Credential in env/config | Move to secret manager; audit all configs for plain-text secrets |
| Symlink exfiltration | Run `find ~/.claude/skills/ -type l` regularly; block symlinks to sensitive dirs |
| conftest.py RCE | Add conftest.py to post-install scan checklist |
| MCP tool poisoning | Pin all server versions; add `mcp-auditor` to MCP onboarding checklist |
| Prompt injection via indirect | Apply ai-security untrusted-data wrapping to all agent inputs |

**Update your runbook:** Add the specific vector that succeeded to your `skill-scanner` custom rules (`.agentseal.yaml`) so it's caught before install next time.

---

## Incident Report Template

```markdown
## Agent Security Incident — [DATE]

**Severity:** P0 / P1 / P2 / P3
**Detected:** [How was it found — anomaly, scan, user observation]
**Attack vector:** [Which of the 11 vectors — e.g., memory-poison, hook exploit]
**Skill/server involved:** [Name of malicious skill or MCP server]

### Timeline
- [Time]: [What happened]
- [Time]: [Containment action taken]
- [Time]: [Credentials rotated]
- [Time]: [Recovery complete]

### Scope
- Files accessed: [list]
- Credentials exposed: [list — already rotated]
- External connections: [any outbound calls]
- Data exfiltrated: [confirmed / not confirmed]

### Root Cause
[1-2 sentences on how the payload got in and what it did]

### Remediation
- [ ] Credentials rotated
- [ ] Malicious skill quarantined
- [ ] CLAUDE.md restored clean
- [ ] Baseline rebuilt
- [ ] Custom rule added to prevent recurrence

### Post-Incident Actions
[What was added to prevent this class of attack recurring]
```

---

## Verification Checklist

- [ ] Agent session terminated
- [ ] All potentially exposed credentials rotated
- [ ] Baseline diff run — all unexpected changes identified
- [ ] CLAUDE.md inspected for poisoning and invisible characters
- [ ] Root cause skill/vector identified via skill-scanner
- [ ] Malicious skill quarantined (not deleted)
- [ ] MCP configs audited post-incident
- [ ] Baseline rebuilt after clean recovery
- [ ] Incident report completed
- [ ] Post-incident hardening applied
