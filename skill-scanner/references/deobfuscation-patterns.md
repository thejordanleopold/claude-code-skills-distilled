# Deobfuscation Patterns

Detection patterns for encoding and obfuscation techniques used to hide malicious instructions in skill files.

---

## 1. Unicode Tag Characters (CRITICAL)

Unicode tag characters (U+E0000–U+E007F) are invisible in all standard text editors and markdown renderers. They can encode arbitrary ASCII text — e.g., the tag equivalent of "ignore previous instructions" looks like an empty string to the human reviewer.

**Detection:**
```python
#!/usr/bin/env python3
import os, glob, sys

skill_dir = os.path.expanduser("~/.claude/skills/")
for f in glob.glob(skill_dir + "**/*", recursive=True):
    if not os.path.isfile(f):
        continue
    try:
        content = open(f, "rb").read().decode("utf-8", errors="ignore")
        tags = [(i, hex(ord(c))) for i, c in enumerate(content) if 0xE0000 <= ord(c) <= 0xE007F]
        if tags:
            print(f"[CRITICAL] Unicode tag chars: {f}")
            print(f"  {len(tags)} chars at positions: {[p for p,_ in tags[:5]]}{'...' if len(tags)>5 else ''}")
            # Decode the hidden message
            hidden = ''.join(chr(ord(c) - 0xE0000) for c in content if 0xE0000 <= ord(c) <= 0xE007F)
            print(f"  Hidden text: {repr(hidden[:200])}")
    except Exception:
        pass
```

**Unicode tag block reference:**
```
U+E0000  TAG NULL
U+E0001  LANGUAGE TAG
U+E0020  TAG SPACE
U+E0041  TAG LATIN CAPITAL LETTER A  (maps to 'A')
U+E0061  TAG LATIN SMALL LETTER A    (maps to 'a')
U+E007F  CANCEL TAG
```

To decode: subtract 0xE0000 from the code point to get the ASCII character.

---

## 2. BiDi (Bidirectional Text) Override Characters (HIGH)

Right-to-left override characters can reverse the visual display of text, making malicious code appear as something else when rendered. Also used to inject instructions that parse differently at the byte level vs. the display level.

**Dangerous code points:**
```
U+202E  RIGHT-TO-LEFT OVERRIDE (RLO)   — reverses display direction
U+202D  LEFT-TO-RIGHT OVERRIDE (LRO)   — forces LTR display
U+202B  RIGHT-TO-LEFT EMBEDDING (RLE)
U+202A  LEFT-TO-RIGHT EMBEDDING (LRE)
U+202C  POP DIRECTIONAL FORMATTING (PDF)
U+2066  LEFT-TO-RIGHT ISOLATE
U+2067  RIGHT-TO-LEFT ISOLATE
U+2068  FIRST STRONG ISOLATE
U+2069  POP DIRECTIONAL ISOLATE
U+200F  RIGHT-TO-LEFT MARK
U+200E  LEFT-TO-RIGHT MARK
```

**Detection:**
```python
BIDI_CHARS = {0x202E, 0x202D, 0x202B, 0x202A, 0x202C, 0x2066, 0x2067, 0x2068, 0x2069, 0x200F, 0x200E}

for f in glob.glob(skill_dir + "**/*", recursive=True):
    if not os.path.isfile(f):
        continue
    try:
        content = open(f, "rb").read().decode("utf-8", errors="ignore")
        bidi = [(i, hex(ord(c))) for i, c in enumerate(content) if ord(c) in BIDI_CHARS]
        if bidi:
            print(f"[HIGH] BiDi override chars: {f} — {[cp for _,cp in bidi]}")
    except Exception:
        pass
```

**Example attack:**
```
# Visually appears as: "exec safe_function()"
# Actually contains RLO: exec )(noitcnuf_efas
```

---

## 3. Zero-Width Characters (MEDIUM)

Zero-width characters are invisible and do not affect text rendering. Used to encode hidden data between visible characters, or to break up keyword patterns that might be detected by simple string matching.

**Dangerous code points:**
```
U+200B  ZERO WIDTH SPACE
U+200C  ZERO WIDTH NON-JOINER
U+200D  ZERO WIDTH JOINER
U+FEFF  ZERO WIDTH NO-BREAK SPACE (BOM)
U+2060  WORD JOINER
U+180E  MONGOLIAN VOWEL SEPARATOR
```

**Detection:**
```python
ZWC_CHARS = {0x200B, 0x200C, 0x200D, 0xFEFF, 0x2060, 0x180E}

for f in glob.glob(skill_dir + "**/*", recursive=True):
    if not os.path.isfile(f):
        continue
    try:
        content = open(f, "rb").read().decode("utf-8", errors="ignore")
        zwc = [i for i, c in enumerate(content) if ord(c) in ZWC_CHARS]
        if len(zwc) > 3:  # allow 1-2 for legitimate BOM/formatting
            print(f"[MEDIUM] Zero-width chars ({len(zwc)}): {f}")
    except Exception:
        pass
```

**Keyword bypass example:**
```
# "ignore" split with zero-width spaces — bypasses naive grep
i​g​n​o​r​e  (each letter separated by U+200B)
```

---

## 4. Base64-Encoded Payloads (MEDIUM)

Shell scripts or Python files may encode their payload in Base64 to avoid pattern matching on known-bad strings. The script decodes and executes at runtime.

**Detection (shell scripts):**
```bash
grep -rn 'base64 -d\|base64 --decode\|base64_decode\|atob(\|b64decode' \
  ~/.claude/skills/ --include="*.sh" --include="*.py" --include="*.js" --include="*.ts"
```

**Suspicious patterns:**
```bash
# Classic: encoded payload decoded and piped to shell
echo "aWdub3JlIHByZXZpb3VzIGluc3RydWN0aW9ucw==" | base64 -d | bash

# Python equivalent
import base64; exec(base64.b64decode("...").decode())

# In JS
eval(Buffer.from("...", "base64").toString())
```

**False positive filter:** Base64 in comments or documentation is usually not executable. Only flag Base64 that is decoded AND executed/eval'd.

---

## 5. TR39 Confusable Characters (MEDIUM)

Unicode confusables are characters that look visually identical (or nearly so) to ASCII characters but have different code points. Used to bypass keyword-based detectors.

**Common confusables for attack keywords:**
```
'i' → 'і' (U+0456 Cyrillic small i)
'o' → 'о' (U+043E Cyrillic small o)
'a' → 'а' (U+0430 Cyrillic small a)
'e' → 'е' (U+0435 Cyrillic small e)
'c' → 'с' (U+0441 Cyrillic small c)
'p' → 'р' (U+0440 Cyrillic small r)
```

**Detection (check for Cyrillic/Greek chars in code files):**
```python
import unicodedata

def has_confusable(text, script_ranges):
    """Check if text contains characters from unexpected Unicode scripts."""
    for char in text:
        if ord(char) > 127:
            name = unicodedata.name(char, "")
            for script in script_ranges:
                if script in name:
                    return True, char, name
    return False, None, None

SUSPICIOUS_SCRIPTS = ["CYRILLIC", "GREEK", "ARABIC", "FULLWIDTH"]
```

**Practical check:**
```bash
# Find non-ASCII chars in shell scripts and Python files
grep -Prn '[^\x00-\x7F]' ~/.claude/skills/**/*.sh ~/.claude/skills/**/*.py 2>/dev/null
```

---

## 6. HTML Comments in Markdown (LOW)

HTML comments in Markdown are not rendered in standard viewers. Used to embed instructions that some LLMs read from raw Markdown.

**Detection:**
```bash
grep -rn '<!--' ~/.claude/skills/ --include="*.md" | grep -v '^.*<!--\s*$'
```

**Note:** Current pwn rate is 0% for this technique. Flag as LOW but investigate any HTML comments that contain instruction-like text (imperative sentences, references to "previous instructions", capability descriptions).

---

## 7. Full Scan — Combined One-Pass Script

See `scripts/scan-skills.sh` for the complete automated scan that runs all the above checks.

To run the Python deobfuscation scan in one pass:
```bash
python3 ~/.claude/skills/skill-scanner/scripts/scan-skills.sh --deobfuscate
```

Or inline:
```python
python3 - <<'EOF'
import os, glob, unicodedata

skill_dir = os.path.expanduser("~/.claude/skills/")
BIDI = {0x202E,0x202D,0x202B,0x202A,0x202C,0x2066,0x2067,0x2068,0x2069,0x200F,0x200E}
ZWC  = {0x200B,0x200C,0x200D,0xFEFF,0x2060,0x180E}

for f in glob.glob(skill_dir + "**/*", recursive=True):
    if not os.path.isfile(f): continue
    try:
        raw = open(f,"rb").read().decode("utf-8",errors="ignore")
        tags = [c for c in raw if 0xE0000<=ord(c)<=0xE007F]
        bidi = [c for c in raw if ord(c) in BIDI]
        zwc  = [c for c in raw if ord(c) in ZWC]
        if tags:
            hidden = ''.join(chr(ord(c)-0xE0000) for c in tags)
            print(f"[CRITICAL] Unicode tags {f}: {repr(hidden[:100])}")
        if bidi:
            print(f"[HIGH]     BiDi chars   {f}: {[hex(ord(c)) for c in bidi]}")
        if len(zwc)>3:
            print(f"[MEDIUM]   Zero-width   {f}: {len(zwc)} chars")
    except: pass
EOF
```
