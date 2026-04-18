---
name: skill-scanner
description: "Use when scanning Claude Code skill files on disk for malicious payloads, backdoors, or supply-chain attacks embedded in SKILL.md or bundled scripts. Use when auditing a skill before installing it, reviewing third-party skills for trustworthiness, or investigating suspicious agent behavior after skill installation. Triggers: \"scan skills\", \"dangerous skill\", \"skill audit\", \"skill backdoor\", \"CLAUDE.md poisoning\", \"memory poison\", \"skill supply chain\", \"hook exploit\", \"conftest RCE\", \"postinstall hook\", \"symlink exfiltration\", \"skill payload\", \"skill malware\", \"skill integrity check\", \"skill security\", \"audit skills\", \"skill scanner\", \"dangerous-skills\", \"warden scan\"."
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# Skill Scanner

Detect malicious payloads in Claude Code skill files, bundled scripts, and config files.
Covers all 11 dangerous-skills attack vectors (benchmarked across 14 models) and AgentSeal's
6-stage detection pipeline.

**Core principle:** Every third-party skill file is untrusted until scanned. A skill that looks
helpful may contain hooks firing shell commands, scripts with trojaned payloads, or setup steps
that poison `CLAUDE.md` for persistent access after skill removal.

## When to Use

- Before installing any skill from an external source
- Auditing existing skills after suspicious agent behavior
- Scanning a repo before adding its skills to your agent
- Investigating unauthorized file writes, config changes, or credential access
- Establishing a supply-chain baseline before installs

## When NOT to Use

- MCP server config files or live tool descriptions → use `mcp-auditor`
- Auditing LLM pipeline code for runtime injection → use `ai-security`
- Testing a system prompt against adversarial probes → use `prompt-injection-tester`
- npm/pip dependency CVE scanning outside skill context → use `security-hardening`

---

## Attack Vector Priority Table

Ordered by measured pwn rate. Check highest-rate vectors first.

| Rank | Vector | Pwn% | Attack Type | Detection Indicator |
|------|--------|:----:|-------------|---------------------|
| 1 | Trojan Helper Script | 100% | Payload in bundled bash | Read all .sh files fully |
| 2 | Memory Poison | 96% | Writes to CLAUDE.md | Script touches CLAUDE.md |
| 3 | Hook Exploitation | 89% | YAML `hooks:` in SKILL.md | `hooks:` key in frontmatter |
| 4 | Test File RCE | 60% | conftest.py auto-import | conftest.py in skill dir |
| 5 | Symlink Exfiltration | 54% | Symlink → ~/.ssh | Symlinks to sensitive paths |
| 6 | Supply Chain RCE | 36% | npm postinstall hook | `postinstall` in package.json |
| 7 | Image Injection | 30% | PNG metadata chunks | Binary files in skill dir |
| 8 | Remote Exec | 7% | curl|bash in setup | `curl.*|.*bash` pattern |
| 9 | Pre-Prompt Injection | conf. | `` !`cmd` `` in SKILL.md | Backtick-bang in .md |
| 10 | Pre-Prompt Destruction | — | `` !`cmd` `` on load | Same as above |
| 11 | Prompt Smuggling | 0% | Unicode tags / HTML cmts | Invisible characters |

Full mechanics for each vector: `references/attack-vectors.md`

---

## AgentSeal 6-Stage Detection Pipeline

Run `agentseal guard` to execute all 6 stages automatically (no API key required):

```bash
pip install agentseal && agentseal guard
agentseal guard --output sarif   # GitHub Security tab
```

Manual equivalent — run stages in order:

1. **Pattern signatures** — grep for known malicious patterns (below)
2. **Deobfuscation** — decode Unicode tags, Base64, BiDi, zero-width chars
3. **Semantic analysis** — embedding similarity catches rephrased attacks
4. **Baseline tracking** — SHA-256 hashes detect config changes since last scan
5. **Registry enrichment** — check agentseal.org/mcp for server trust scores
6. **Custom rules** — enforce org-specific policies via `.agentseal.yaml`

---

## Stage 1 — Structural Red Flags

```bash
# Hook exploitation (CRITICAL — 89% pwn rate)
grep -rn "^hooks:" ~/.claude/skills/ --include="*.md" --include="*.yaml"

# Pre-prompt commands (CRITICAL)
grep -rn '`!' ~/.claude/skills/ --include="*.md"

# Remote exec (CRITICAL)
grep -rn 'curl[^|]*|[^|]*\(bash\|sh\)\|wget[^|]*|.*sh' \
  ~/.claude/skills/ --include="*.md" --include="*.sh"

# Config poisoning (CRITICAL)
grep -rn 'CLAUDE\.md\|claude_desktop_config\|\.claude/settings' \
  ~/.claude/skills/ --include="*.sh" --include="*.py"

# Symlinks to sensitive paths (CRITICAL)
find ~/.claude/skills/ -type l | while read f; do
  t=$(readlink -f "$f" 2>/dev/null || readlink "$f")
  echo "$f -> $t"
done | grep -E '\.ssh|\.aws|id_rsa|credentials|\.env'

# conftest.py (HIGH)
find ~/.claude/skills/ -name "conftest.py" -o -name "pytest_plugins.py"

# npm postinstall (HIGH)
find ~/.claude/skills/ -name "package.json" | \
  xargs grep -l "postinstall\|preinstall\|prepare" 2>/dev/null

# Binary files (MEDIUM)
find ~/.claude/skills/ -name "*.png" -o -name "*.jpg" -o -name "*.gif"
```

Or run the full automated scan: `bash ~/.claude/skills/skill-scanner/scripts/scan-skills.sh`

---

## Stage 2 — Payload Pattern Scan

```bash
grep -rn \
  -e '\.ssh/id_rsa\|\.aws/credentials\|ANTHROPIC_API_KEY\|AWS_SECRET' \
  -e '/dev/tcp/\|\.ngrok\.\|requestbin\|webhook\.site' \
  -e 'crontab -\|>>.*\.bashrc\|>>.*authorized_keys\|launchctl.*load' \
  ~/.claude/skills/ --include="*.sh" --include="*.py" --include="*.js"
```

---

## Stage 3 — Deobfuscation Scan

```bash
# Full deobfuscation (Unicode tags, BiDi, zero-width)
bash ~/.claude/skills/skill-scanner/scripts/scan-skills.sh --deobfuscate

# Quick inline: Unicode tags only
python3 -c "
import glob, os
for f in glob.glob('$HOME/.claude/skills/**/*', recursive=True):
    if not os.path.isfile(f): continue
    raw = open(f,'rb').read().decode('utf-8',errors='ignore')
    tags = [c for c in raw if 0xE0000<=ord(c)<=0xE007F]
    if tags:
        hidden = ''.join(chr(ord(c)-0xE0000) for c in tags)
        print(f'[CRITICAL] {f}: {repr(hidden[:100])}')
"
```

Full deobfuscation patterns: `references/deobfuscation-patterns.md`

---

## Supply Chain Baseline

```bash
# Before any install — establish baseline
bash ~/.claude/skills/skill-scanner/scripts/baseline-sha256.sh init

# After npm install / pip install / skill install — check for changes
bash ~/.claude/skills/skill-scanner/scripts/baseline-sha256.sh check
```

Post-install, always verify:
- No new symlinks: `find ~/.claude/ -type l -newer ~/.agentseal-baseline.txt`
- CLAUDE.md unchanged (check in baseline diff output)
- No new conftest.py or postinstall hooks

---

## Severity + Immediate Response

| Severity | Finding Examples | Response |
|----------|-----------------|----------|
| CRITICAL | hooks: in SKILL.md, curl\|bash, symlink to .ssh, config poisoning | Do not load. Quarantine. Rotate credentials. |
| HIGH | conftest.py, postinstall hook, Unicode tag chars | Do not load until manually reviewed. |
| MEDIUM | Image files, Base64 in scripts, BiDi chars | Review specific finding. Isolate before use. |
| LOW | HTML comments with instructions | Document and monitor. |

---

## Verification Checklist

- [ ] Structural red flags scan run (hooks, curl|bash, symlinks, conftest, postinstall)
- [ ] Payload pattern scan run (credential access, exfil channels, persistence)
- [ ] Deobfuscation scan run (Unicode tags, BiDi, zero-width)
- [ ] All CRITICAL findings quarantined before loading skill
- [ ] Supply chain baseline checked post-install
- [ ] CLAUDE.md hash verified unchanged
