#!/usr/bin/env bash
# skill-scanner: full pattern battery for detecting malicious skill files
# Usage: bash scan-skills.sh [skills-dir]
#        bash scan-skills.sh --deobfuscate [skills-dir]

set -euo pipefail

SKILLS_DIR="${2:-${1:-$HOME/.claude/skills}}"
DEOBFUSCATE=false
[[ "${1:-}" == "--deobfuscate" ]] && DEOBFUSCATE=true

RED='\033[0;31m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; NC='\033[0m'
crit() { echo -e "${RED}[CRITICAL]${NC} $*"; }
high() { echo -e "${RED}[HIGH]${NC}     $*"; }
med()  { echo -e "${YELLOW}[MEDIUM]${NC}  $*"; }
low()  { echo -e "${CYAN}[LOW]${NC}     $*"; }

echo "=== Skill Scanner: $SKILLS_DIR ==="
echo ""

# ── 1. STRUCTURAL RED FLAGS ─────────────────────────────────────────────────

echo "── Structural Red Flags ──"

# Hook exploitation (CRITICAL)
grep -rn "^hooks:" "$SKILLS_DIR" --include="*.md" --include="*.yaml" --include="*.yml" \
  | while read line; do crit "Hook exploitation: $line"; done

# Inline command execution in SKILL.md (CRITICAL)
grep -rn '`!.\+`' "$SKILLS_DIR" --include="*.md" \
  | while read line; do crit "Pre-prompt command: $line"; done

# Remote exec (CRITICAL)
grep -rn 'curl[^|]*|[^|]*\(bash\|sh\)\|wget[^|]*|[^|]*\(bash\|sh\)' "$SKILLS_DIR" \
  --include="*.md" --include="*.sh" \
  | while read line; do crit "Remote exec (curl|bash): $line"; done

# Memory/config poisoning (CRITICAL)
grep -rn 'CLAUDE\.md\|claude_desktop_config\|\.claude/settings\|\.claude/CLAUDE' \
  "$SKILLS_DIR" --include="*.sh" --include="*.py" --include="*.js" --include="*.ts" \
  | while read line; do crit "Config poisoning target: $line"; done

# Symlinks to sensitive paths
find "$SKILLS_DIR" -type l 2>/dev/null | while read f; do
  target=$(readlink -f "$f" 2>/dev/null || readlink "$f")
  if echo "$target" | grep -qE '\.ssh|\.aws|\.gnupg|id_rsa|id_ed25519|\.env|credentials|\.netrc'; then
    crit "Symlink exfiltration: $f -> $target"
  fi
done

# conftest.py / pytest auto-execution (HIGH)
find "$SKILLS_DIR" -name "conftest.py" -o -name "pytest_plugins.py" 2>/dev/null \
  | while read f; do high "Test RCE (conftest.py): $f"; done

# npm postinstall hooks (HIGH)
find "$SKILLS_DIR" -name "package.json" 2>/dev/null | while read f; do
  if grep -qE '"postinstall"|"preinstall"|"prepare"' "$f"; then
    high "Supply chain hook (package.json): $f"
  fi
done

# Python supply chain hooks (HIGH)
find "$SKILLS_DIR" -name "setup.py" -o -name "setup.cfg" 2>/dev/null | while read f; do
  if grep -qE 'cmdclass|post_install' "$f"; then
    high "Supply chain hook (setup.py): $f"
  fi
done

# Binary/image files (MEDIUM)
find "$SKILLS_DIR" -name "*.png" -o -name "*.jpg" -o -name "*.gif" -o -name "*.webp" 2>/dev/null \
  | while read f; do med "Image file (check metadata): $f"; done

echo ""

# ── 2. PAYLOAD PATTERNS ──────────────────────────────────────────────────────

echo "── Payload Patterns ──"

# Credential access (CRITICAL)
grep -rn \
  -e '\.ssh/id_rsa\|\.ssh/id_ed25519\|\.ssh/authorized_keys' \
  -e '\.aws/credentials\|AWS_SECRET_ACCESS_KEY\|ANTHROPIC_API_KEY' \
  -e 'cat /etc/passwd\|cat /etc/shadow\|/proc/self/environ' \
  "$SKILLS_DIR" --include="*.sh" --include="*.py" --include="*.js" --include="*.md" \
  | while read line; do crit "Credential access: $line"; done

# Exfiltration channels (CRITICAL)
grep -rn \
  -e '/dev/tcp/\|\.ngrok\.\|requestbin\.com\|webhook\.site\|hookbin\.com' \
  -e 'nc -e\|ncat.*-e\|bash -i >& /dev/tcp' \
  "$SKILLS_DIR" --include="*.sh" --include="*.py" --include="*.js" \
  | while read line; do crit "Exfiltration channel: $line"; done

# Persistence mechanisms (HIGH)
grep -rn \
  -e 'crontab -\|>>.*\.bashrc\|>>.*\.zshrc\|>>.*\.profile' \
  -e 'launchctl.*load\|systemctl enable\|rc\.local' \
  -e '>>.*authorized_keys' \
  "$SKILLS_DIR" --include="*.sh" --include="*.py" \
  | while read line; do high "Persistence mechanism: $line"; done

# Base64 decode + execute pattern (MEDIUM)
grep -rn 'base64 -d\|base64 --decode\|b64decode\|atob(' \
  "$SKILLS_DIR" --include="*.sh" --include="*.py" --include="*.js" \
  | while read line; do med "Base64 decode (check if executed): $line"; done

# HTML comments with instruction text (LOW)
grep -rn '<!--' "$SKILLS_DIR" --include="*.md" \
  | grep -iE 'ignore|override|system|instructions|previous' \
  | while read line; do low "HTML comment with instructions: $line"; done

echo ""

# ── 3. DEOBFUSCATION SCAN ────────────────────────────────────────────────────

if [[ "$DEOBFUSCATE" == "true" ]]; then
  echo "── Deobfuscation Scan ──"
  python3 - "$SKILLS_DIR" <<'PYEOF'
import os, glob, sys

skill_dir = sys.argv[1]
BIDI = {0x202E,0x202D,0x202B,0x202A,0x202C,0x2066,0x2067,0x2068,0x2069,0x200F,0x200E}
ZWC  = {0x200B,0x200C,0x200D,0xFEFF,0x2060,0x180E}

found = False
for f in glob.glob(skill_dir + "/**/*", recursive=True):
    if not os.path.isfile(f):
        continue
    try:
        raw = open(f,"rb").read().decode("utf-8",errors="ignore")
        tags = [c for c in raw if 0xE0000<=ord(c)<=0xE007F]
        bidi = [c for c in raw if ord(c) in BIDI]
        zwc  = [c for c in raw if ord(c) in ZWC]
        if tags:
            hidden = ''.join(chr(ord(c)-0xE0000) for c in tags)
            print(f"\033[0;31m[CRITICAL]\033[0m Unicode tag chars: {f}")
            print(f"  Decoded: {repr(hidden[:200])}")
            found = True
        if bidi:
            print(f"\033[0;31m[HIGH]\033[0m     BiDi override chars: {f}")
            print(f"  Code points: {[hex(ord(c)) for c in bidi]}")
            found = True
        if len(zwc) > 3:
            print(f"\033[0;33m[MEDIUM]\033[0m  Zero-width chars ({len(zwc)}): {f}")
            found = True
    except Exception:
        pass

if not found:
    print("No deobfuscation issues detected.")
PYEOF
  echo ""
fi

# ── 4. SUMMARY ───────────────────────────────────────────────────────────────

echo "── Scan Complete ──"
echo "Run with --deobfuscate flag to also check for Unicode/BiDi obfuscation."
echo "See references/attack-vectors.md for remediation guidance per finding."
