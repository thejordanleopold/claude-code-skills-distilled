---
name: security-hardening
description: |
  Use when hardening application configuration, implementing security headers, adding rate
  limiting, managing secrets and environment variables, auditing dependencies for vulnerabilities,
  assessing supply chain risk, responding to leaked secrets, or implementing defense-in-depth
  architecture. Triggers: "harden", "security headers", "CSP", "HSTS", "rate limiting",
  "secrets management", "dependency audit", "npm audit", "supply chain", "leaked secret".
---

# Security Hardening

Defense-in-depth configuration, secrets management, dependency auditing, and incident response for leaked credentials.

**Core principle:** Every layer of defense buys time and limits blast radius. No single control is sufficient.

## When to Use

- Adding security headers to a new service
- Implementing rate limiting on auth endpoints
- Auditing or configuring secrets management
- Running dependency vulnerability scans
- Responding to a leaked credential
- Reviewing supply chain risk of dependencies

## When NOT to Use

- Code-level security review (use security-review skill)
- Threat modeling (use threat-modeling skill)
- Compliance framework mapping (use compliance-and-governance skill)

---

## Defense-in-Depth Layers

```
+--------------------------------------+
|  Perimeter: WAF, DDoS, Bot Detection |
+--------------------------------------+
|  Network: Firewall, Zero-Trust, VPN  |
+--------------------------------------+
|  Application: Auth, Headers, Input   |
+--------------------------------------+
|  Data: Encryption, Key Management   |
+--------------------------------------+
```

Each layer assumes the one above it has failed.

---

## Security Headers

```typescript
import helmet from 'helmet';

app.use(helmet());
app.use(helmet.contentSecurityPolicy({
  directives: {
    defaultSrc: ["'self'"],
    scriptSrc: ["'self'"],
    styleSrc: ["'self'", "'unsafe-inline'"],  // only if needed
    imgSrc: ["'self'", "data:", "https:"],
    connectSrc: ["'self'"],
    fontSrc: ["'self'"],
    objectSrc: ["'none'"],
    upgradeInsecureRequests: [],
  },
}));
```

### Required Headers Checklist

| Header | Value | Purpose |
|--------|-------|---------|
| `Content-Security-Policy` | See above | Prevents XSS, data injection |
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains` | Forces HTTPS |
| `X-Frame-Options` | `DENY` or `SAMEORIGIN` | Prevents clickjacking |
| `X-Content-Type-Options` | `nosniff` | Prevents MIME sniffing |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | Limits referrer data |
| `Permissions-Policy` | `camera=(), microphone=(), geolocation=()` | Restricts browser APIs |

---

## Rate Limiting

```typescript
import rateLimit from 'express-rate-limit';

// Auth endpoints: strict
app.use('/api/auth/', rateLimit({
  windowMs: 15 * 60 * 1000,  // 15 minutes
  max: 10,                     // 10 attempts per window
  message: { error: 'Too many attempts. Try again in 15 minutes.' },
  standardHeaders: true,
  legacyHeaders: false,
}));

// General API: lenient
app.use('/api/', rateLimit({
  windowMs: 1 * 60 * 1000,   // 1 minute
  max: 100,
}));
```

**Endpoints requiring strict rate limiting:**
- `POST /auth/login`
- `POST /auth/register`
- `POST /auth/forgot-password`
- `POST /auth/reset-password`
- Any endpoint that sends emails or SMS

---

## Secrets Management

### Environment Variable Rules

```
.env.example    → Committed (template with placeholder values)
.env            → NOT committed (real secrets)
.env.local      → NOT committed (local overrides)
```

**.gitignore must include:**
```
.env
.env.*
!.env.example
*.pem
*.key
*.p12
```

### Fail-Secure Pattern

```python
# SAFE: App fails if secret missing
SECRET_KEY = os.environ['SECRET_KEY']
DATABASE_URL = os.environ['DATABASE_URL']

# DANGEROUS: App runs with insecure default
SECRET_KEY = os.environ.get('SECRET_KEY') or 'default'
```

### Pre-commit Check

```bash
# Add to pre-commit hook or CI
git diff --cached | grep -iE "password|secret|api_key|token|AKIA|sk-|ghp_|Bearer"
```

---

## Dependency Vulnerability Auditing

| Ecosystem | Command | Frequency |
|-----------|---------|-----------|
| npm | `npm audit --audit-level=high` | Every CI run |
| Python | `pip-audit` | Every CI run |
| Ruby | `bundle audit` | Every CI run |
| Go | `govulncheck ./...` | Every CI run |
| Rust | `cargo audit` | Every CI run |

### Audit Triage Decision Tree

```
Vulnerability found
  ├── Severity: Critical/High
  │     ├── Reachable in production? → Fix immediately
  │     ├── Dev-only dependency? → Fix soon, not a blocker
  │     ├── Fix available? → Update to patched version
  │     └── No fix available? → Replace dependency or document risk
  ├── Severity: Medium → Fix in next release cycle
  └── Severity: Low → Track, fix during regular maintenance
```

---

## Supply Chain Risk Assessment

For every new dependency, evaluate:

| Risk Factor | Question | Flag If |
|-------------|---------|---------|
| Maintainer count | Who maintains this? | Single maintainer |
| Activity | When was the last commit? | >1 year inactive |
| Popularity | How widely used? | <1k downloads/week |
| Security history | Past CVEs? | Multiple CVEs |
| High-risk features | FFI, eval, shell exec? | Yes — review carefully |
| Maintainer identity | Anonymous/pseudonymous? | Yes — extra scrutiny |

---

## Incident Response: Leaked Secrets

If a secret (API key, password, token) is found in code or commit history:

### Immediate (within 1 hour)

1. **Revoke** the credential immediately — assume it was accessed
2. **Rotate** — generate a new credential
3. **Do NOT** just push a new commit that deletes it — it's in git history

### History Cleanup

```bash
# Use git-filter-repo (recommended over BFG)
pip install git-filter-repo

git filter-repo --path-glob '*.env' --invert-paths
# OR replace the specific string
git filter-repo --replace-text <(echo 'OLD_SECRET_VALUE==>REDACTED')

# Force push all branches
git push --force --all
git push --force --tags
```

### Investigation (within 24 hours)

4. **Audit exposure window** — When was the secret committed? Was repo public at any time?
5. **Check for abuse** — Review the credential provider's audit logs for unauthorized use
6. **Notify** — If there's any evidence of unauthorized access, follow breach notification procedures

### Prevention

- Add `git-secrets` or `gitleaks` as pre-commit hook
- Enable GitHub secret scanning on all repos
- Rotate all credentials on a schedule (90-day max for long-lived tokens)

---

## CORS Configuration

```typescript
import cors from 'cors';

// Production: explicit allowlist
app.use(cors({
  origin: ['https://app.company.com', 'https://www.company.com'],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

// NEVER in production:
app.use(cors({ origin: '*' }));  // Allows any origin
```

---

## Compliance Quick Reference

| Control | GDPR | HIPAA | PCI-DSS | SOC 2 |
|---------|------|-------|---------|-------|
| Encryption at rest | Required | Required | Required | Required |
| Encryption in transit (TLS) | Required | Required | Required | Required |
| Access control | Required | Required | Required | Required |
| Audit logging | Required | Required | Required | Required |
| Breach notification | 72 hours | Yes | Yes | Yes |

---

## Red Flags

Investigate immediately:
- Wildcard CORS (`*`) in production
- No rate limiting on authentication endpoints
- Secrets in code (even if "old" or "test")
- `npm audit` reporting Critical/High with no tracking issue
- Single-maintainer dependency with >10k downloads/week (high-value target)
- `verify: false` or `ssl: false` in any production config

## Verification Checklist

**Headers:**
- [ ] CSP configured (no `unsafe-eval` without justification)
- [ ] HSTS with `includeSubDomains`
- [ ] X-Frame-Options set
- [ ] X-Content-Type-Options: nosniff

**Rate Limiting:**
- [ ] Auth endpoints limited (10 req/15min)
- [ ] General API limited (100 req/min)

**Secrets:**
- [ ] .env not committed; .env.example committed
- [ ] All secrets fail-secure (crash if missing)
- [ ] Pre-commit secret scanning hook installed
- [ ] No secrets in git history

**Dependencies:**
- [ ] `npm audit` (or equivalent) in CI, blocking on High+
- [ ] New dependencies supply-chain-assessed before adding
- [ ] Lock file committed and up-to-date

**CORS:**
- [ ] Explicit allowlist, not wildcard
- [ ] Credentials flag only if needed
