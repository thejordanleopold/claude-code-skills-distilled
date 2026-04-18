---
name: security-review
description: "Use when auditing code for security vulnerabilities, running static analysis with Semgrep or CodeQL, reviewing against OWASP Top 10:2025, performing variant analysis after a finding, checking constant-time cryptographic code, auditing input validation, authentication, session management, or reviewing for insecure defaults and sharp edges. Triggers: \"security audit\", \"security review\", \"OWASP\", \"vulnerability\", \"static analysis\", \"semgrep\", \"injection\", \"SQL injection\", \"XSS\", \"auth vulnerability\", \"insecure default\"."
---

# Security Review

Systematic code-level security analysis: OWASP Top 10, static analysis, variant analysis, and cryptographic review.

**Core principle:** Every finding requires a concrete exploit scenario. Pattern matches without proven impact are not findings.

## When to Use

- Auditing code for specific vulnerability classes
- Running Semgrep/CodeQL static analysis
- Reviewing auth, session, or input handling code
- After finding one vulnerability (variant analysis)
- Reviewing cryptographic code for timing side-channels

## When NOT to Use

- System-level threat modeling (use threat-modeling skill)
- Dependency vulnerability scanning (use security-hardening skill)
- Compliance gap analysis (use compliance-and-governance skill)

---

## Phase 1: Static Analysis

### Semgrep

```bash
semgrep scan \
  --config p/security-audit \
  --config p/owasp-top-ten \
  --severity HIGH --severity CRITICAL \
  --metrics=off \
  --json -o results.json .
```

Always use `--metrics=off` during audits.

**Key rulesets by language:**

| Language | Official | Third-Party |
|----------|----------|-------------|
| Python | `p/python`, `p/django` | `trailofbits` |
| JavaScript/TypeScript | `p/javascript`, `p/typescript`, `p/react` | `trailofbits` |
| Go | `p/golang` | `trailofbits` |
| Java | `p/java` | `trailofbits` |

For injection (SQLi, SSRF, path traversal): use taint-mode rules — they track data from source to sink through function calls.

**Test-driven rule creation:** Write test cases BEFORE writing the rule pattern.
1. Define true positives (code that should match) and true negatives (safe code that must not match)
2. Run `semgrep --test` to verify: iterate on the AST pattern until all tests pass
3. For data-flow vulnerabilities, use `mode: taint` with explicit `sources` and `sinks`
4. Only finalize the rule after the test suite is green — pattern-first rules have high FP rates

### CodeQL (Deep Analysis)

```bash
codeql database create codeql.db --language=javascript
codeql database analyze codeql.db \
  javascript-security-extended.qls \
  --format=sarif-latest -o results.sarif
```

**Zero findings needs investigation, not celebration.** Zero results can indicate poor database quality or missing data flow models.

---

## ASVS 5.0 Verification Levels

| Level | Scope | Applies To |
|-------|-------|-----------|
| L1 | Basic security controls (auditable externally) | All applications |
| L2 | Defense-in-depth, security by design | Apps with sensitive data, B2B, regulated industries |
| L3 | Advanced controls, formal verification | Critical infrastructure, healthcare, finance, IoT |

Start every audit at L1. Escalate to L2/L3 based on data sensitivity and threat model. L3 requires formal cryptographic review.

---

## Phase 2: OWASP Top 10:2025

| # | Vulnerability | Quick Check |
|---|--------------|-------------|
| A01 | Broken Access Control | Deny by default? Server-side enforcement? Resource ownership verified? |
| A02 | Security Misconfiguration | Defaults changed? Debug mode off? Minimal feature set? |
| A03 | Supply Chain Failures | Dependencies pinned? Integrity verified? Audited? |
| A04 | Cryptographic Failures | TLS 1.2+? AES-256-GCM? Argon2/bcrypt for passwords? |
| A05 | Injection | Parameterized queries? Input validated? Safe APIs used? |
| A06 | Insecure Design | Rate limiting? Threat modeled? Security controls in design? |
| A07 | Auth Failures | MFA available? Session invalidated on logout? Rate limiting on auth? |
| A08 | Integrity Failures | Packages signed? CDN uses SRI? Deserialization safe? |
| A09 | Logging Failures | Security events logged? Structured format? Alerting configured? |
| A10 | Exception Handling | Fail-closed? Internals hidden from users? Errors logged with context? |

---

## Phase 3: Input Validation Checklist

```
[ ] All user input validated server-side (never trust client-side only)
[ ] Parameterized queries for all DB access (never string concatenation)
[ ] Input length limits enforced
[ ] Allowlist validation preferred over denylist
[ ] File uploads: type, size, magic bytes checked; stored outside webroot
[ ] HTML output: escaped or sanitized before rendering
[ ] No eval()/exec() on user input
[ ] Template injection impossible (no user-controlled template strings)
```

---

## Phase 4: Authentication and Session Review

```
[ ] Passwords: Argon2id or bcrypt (rounds >= 12), never MD5/SHA1
[ ] Session tokens: 128+ bits entropy, httpOnly, Secure, SameSite=Strict
[ ] Sessions invalidated on logout (server-side invalidation)
[ ] MFA available for sensitive operations
[ ] Rate limiting on /login, /register, /forgot-password
[ ] Access tokens: short-lived (15 min); refresh tokens: rotated on use
[ ] No credentials in URLs, query params, or logs
[ ] Password reset tokens: single-use, expire in 1 hour
```

---

## Phase 5: Insecure Defaults Detection

Find fail-open vulnerabilities — where missing config makes the app run insecurely:

```python
# FAIL-OPEN (CRITICAL): App runs with weak secret when env var missing
SECRET_KEY = os.environ.get('SECRET_KEY') or 'default-secret'

# FAIL-SECURE (SAFE): App crashes if secret missing
SECRET_KEY = os.environ['SECRET_KEY']
```

**Detection patterns (grep these):**
```bash
# Fallback secrets
grep -r "getenv.*) or ['\"]" src/
grep -r "ENV.*|| ['\"]" src/

# Hardcoded credentials
grep -r "password.*=.*['\"][^'\"]{8,}['\"]" src/
grep -r "secret.*=.*['\"][^'\"]{8,}['\"]" src/

# Weak defaults
grep -r "DEBUG.*=.*true" src/
grep -r "verify.*=.*false" src/
```

---

## Phase 6: Sharp Edges Analysis

**Pit of Success** — secure usage must be the path of least resistance. Evaluate through three adversary lenses:
- **Scoundrel**: Can a malicious developer disable security via configuration?
- **Lazy Developer**: Does copy-pasting the first example produce insecure code?
- **Confused Developer**: Can parameters be swapped without type errors, producing silent misuse?

| Category | Example | Risk | Fix |
|----------|---------|------|-----|
| Algorithm footguns | JWT `alg: none`, `hash("crc32", $password)` | Wrong algorithm silently accepted | Allowlist algorithms |
| Dangerous defaults | `timeout=0` (no timeout), `verify=False` (skip TLS) | Security disabled by default | Secure defaults only |
| Primitive vs Semantic APIs | `encrypt(msg, bytes, bytes)` — key/nonce swappable | Silent misuse with no type error | Named parameters or wrapper types |
| Configuration cliffs | `verify_ssl: false` disables all cert validation | One flag nukes entire security layer | Granular options; warn on disable |
| Silent failures | Auth check returns `true` on exception | Fail-open | Fail-closed on error |
| Stringly-typed security | `permissions = "read,write,admin"` | Easy to misparse or inject | Use typed enums or arrays |

**Edge case probing:** For every security-relevant parameter, ask: What happens with `0`, `""`, `null`, `[]`, `-1`? Is the default the most secure option?

---

## Phase 7: Constant-Time Analysis

For code handling secrets, tokens, or passwords:

| Problem | Vulnerable Code | Fix |
|---------|----------------|-----|
| Early-exit comparison | `if (token === expected)` | `crypto.timingSafeEqual(Buffer.from(token), Buffer.from(expected))` |
| Branching on secret | `if (secretBit) doA() else doB()` | Constant-time selection |
| Weak RNG for tokens | `Math.random()`, `rand()` | `crypto.randomBytes()`, `os.urandom()` |

```typescript
// Safe string comparison (Node.js)
import { timingSafeEqual } from 'crypto';

function safeCompare(a: string, b: string): boolean {
  const bufA = Buffer.from(a);
  const bufB = Buffer.from(b);
  if (bufA.length !== bufB.length) return false;
  return timingSafeEqual(bufA, bufB);
}
```

---

## Variant Analysis

When you find one vulnerability, systematically search for similar instances using this 5-step workflow:

```
1. Understand root cause — identify the exact condition and data flow, not just the symptom
2. Create an exact match — write a pattern that matches only the known instance; confirm it fires
3. Identify abstraction points — what can be generalized? (variable name, function, call site, module)
4. Generalize one element at a time — change one thing per iteration; re-run and review new matches
5. Triage — stop when false positive rate exceeds 50%; document and prioritize real findings
```

Search the ENTIRE codebase, not just the module where the original was found.
One confirmed SQL injection often has 5+ variants across different query paths.
Use Semgrep for fast pattern matching; escalate to CodeQL for interprocedural data flow.

---

## False Positive Filtering

**Never report:**
- Test fixtures, example files, documentation examples
- Dependency CVEs with CVSS <4.0 and no known exploit
- Secrets committed and removed in same initial-setup PR

**Verification requirements before reporting:**
- **Secrets:** Validate key format. Do NOT test against live APIs.
- **Injection:** Trace from user input to dangerous sink. Confirm no sanitization in path.
- **Auth bypass:** Prove the bypass works with a concrete example.

**Confidence scoring:**

| Score | Meaning | Report |
|-------|---------|--------|
| 9-10 | Verified by reading specific code | Report normally |
| 7-8 | High confidence pattern match | Report normally |
| 5-6 | Moderate, could be false positive | Report with caveat |
| ≤4 | Low confidence | Don't report (or note as question) |

---

## Red Flags (Immediate Investigation)

- User input passed directly to SQL, shell, or HTML
- Secrets in source code or commit history
- API endpoints without authentication or authorization
- Wildcard CORS (`*`) in production
- No rate limiting on auth endpoints
- Stack traces exposed to users
- `eval()`/`exec()` processing user or LLM output
- Webhook endpoints without signature verification
- Fail-open error handlers: `catch { return true }`
- `${{ github.event.* }}` in CI/CD prompt fields

## Verification Checklist

- [ ] Static analysis run (Semgrep + language-appropriate rulesets)
- [ ] All A01-A10 OWASP items checked
- [ ] Input validation at all user-facing boundaries
- [ ] Auth and session checklist completed
- [ ] Insecure defaults scan performed
- [ ] Variant analysis done for any confirmed finding
- [ ] Constant-time comparisons used for all secrets
- [ ] Every finding verified with concrete exploit scenario
- [ ] False positives filtered before reporting
