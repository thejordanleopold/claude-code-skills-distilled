---
name: threat-modeling
description: |
  Use when performing threat modeling, identifying attack surfaces, mapping trust boundaries,
  applying STRIDE analysis, scoring threats with DREAD, classifying data sensitivity, or
  designing security controls for a new system. Use before writing security code, when
  onboarding to a new codebase's security posture, or when preparing for a security review.
  Triggers: "threat model", "attack surface", "STRIDE", "trust boundary", "security design",
  "what could go wrong", "security risks", "data classification".
---

# Threat Modeling

Identify threats before looking at code. Understanding what can go wrong is prerequisite to designing what prevents it.

**Core principle:** Find design-level threats first. Code-level vulnerabilities are easier to fix than architecture-level ones.

## When to Use

- Starting a new system or major feature
- Before writing any authentication, authorization, or data handling code
- Preparing for a penetration test or security audit
- Onboarding to a codebase's security posture

## When NOT to Use

- Code-level security review (use security-review skill)
- Dependency vulnerability scanning (use security-hardening skill)
- Compliance gap analysis (use compliance-and-governance skill)

---

## Phase 1: System Decomposition

Before analyzing threats, understand the system.

### 1.1 Map Entry Points

Everything that accepts external input:
- HTTP API endpoints (REST, GraphQL, WebSocket)
- Form handlers and file uploads
- Webhook receivers
- Message queue consumers
- Admin interfaces
- CLI interfaces
- Background job triggers

### 1.2 Draw Trust Boundaries

A trust boundary is where data crosses privilege levels:

```
[Internet] → [Load Balancer] → [API Gateway] → [Service] → [Database]
              ↑ trust boundary              ↑ trust boundary
          (untrusted → semi-trusted)   (semi-trusted → trusted)
```

**Key boundaries:**
- Public internet → internal services
- User data → admin data
- Tenant A data → Tenant B data
- Frontend → backend
- Service → service (in microservices)

### 1.3 Trace Data Flows

For each piece of sensitive data, trace its path:
1. **Entry** — where does it come in?
2. **Processing** — what transforms it?
3. **Storage** — where is it persisted?
4. **Egress** — where does it go out?

### 1.4 Data Classification

| Class | Examples | Handling |
|-------|---------|---------|
| **Restricted** | PII, credentials, payment, PHI | Encrypt at rest and in transit, audit all access |
| **Confidential** | API keys, business data, employee data | Encrypt in transit, access controls |
| **Internal** | Logs, metrics, internal docs | Access controls |
| **Public** | Marketing content, public APIs | No special handling |

---

## Phase 2: STRIDE Analysis

For each entry point and trust boundary, evaluate all six threat categories:

| Category | Threat | Key Question | Default Mitigation |
|----------|--------|-------------|-------------------|
| **S**poofing | Impersonating a user or system | Can an attacker forge identity? | Strong auth, MFA, mutual TLS |
| **T**ampering | Unauthorized modification | Can request parameters be altered? | Input validation, HMAC, parameterized queries |
| **R**epudiation | Denying actions occurred | Can a user deny a transaction? | Audit logging, tamper-evident logs |
| **I**nfo Disclosure | Leaking sensitive data | Do errors expose internals? | Encryption, output sanitization, minimal error detail |
| **D**enial of Service | Making system unavailable | Can one user exhaust resources? | Rate limiting, circuit breakers, quotas |
| **E**levation of Privilege | Gaining unauthorized access | Can a user become admin? | Least privilege, input validation, RBAC |

### STRIDE Worksheet

For each entry point, fill in:

```
Entry Point: POST /api/tasks
S: Can an attacker forge another user's identity? → JWT without expiry check? →
T: Can task data be tampered with in transit? → HTTPS enforced? →
R: Is task creation logged with attribution? → Audit log present? →
I: Do error messages reveal internal state? → Stack traces exposed? →
D: Can one user flood task creation? → Rate limiting present? →
E: Can a regular user create tasks as admin? → Authorization check present? →
```

---

## Phase 3: DREAD Scoring

Score each identified threat to prioritize:

| Factor | Score 1-5 |
|--------|---------|
| **D**amage | How severe is the impact? (1=minimal, 5=catastrophic) |
| **R**eproducibility | How reliably can this be exploited? (1=hard, 5=trivial) |
| **E**xploitability | Skill required to exploit? (1=expert only, 5=no skill) |
| **A**ffected users | How many users impacted? (1=one, 5=all) |
| **D**iscoverability | How easy to find? (1=hidden, 5=obvious) |

**Total score = sum of 5 factors (5-25)**

| Score | Priority |
|-------|---------|
| 20-25 | Critical — fix before launch |
| 15-19 | High — fix in current sprint |
| 10-14 | Medium — fix in next release |
| 5-9 | Low — fix when convenient |

---

## Phase 4: Agentic AI Security (OWASP Agentic AI)

When reviewing AI agent systems — these are distinct from traditional web app threats:

| Risk | Description | Mitigation |
|------|-------------|------------|
| **ASI01 Goal Hijack** | Prompt injection alters agent objectives | Input sanitization, goal boundary enforcement |
| **ASI02 Tool Misuse** | Tools used in unintended ways | Least privilege, validate I/O before execution |
| **ASI03 Supply Chain** | Compromised plugins/MCP servers | Verify signatures, sandbox, allowlist only |
| **ASI04 Code Execution** | Unsafe AI-generated code executed | Sandbox execution, human approval for destructive ops |
| **ASI05 Data Exfiltration** | Agent leaks data through tool calls | Monitor outbound data, restrict tool scopes |

**CI/CD-specific agent attack vectors:**
- `${{ github.event.* }}` in prompt fields (prompt injection via PR titles)
- `eval()`/`exec()` consuming AI output (arbitrary code execution)
- `pull_request_target` with PR checkout (privilege escalation)
- Wildcard tool allowlists (permission scope too broad)

---

## Threat Model Document

Output of threat modeling:

```markdown
# Threat Model: [System Name]

## Scope
[What is included in this threat model]

## System Overview
[Architecture diagram reference, key components]

## Entry Points
[List of all external-facing inputs]

## Trust Boundaries
[List with diagram]

## Data Classification
[What data exists and its sensitivity level]

## Threats (STRIDE + DREAD)

### T1: [Threat Name]
- Category: [S/T/R/I/D/E]
- Entry point: [where]
- DREAD score: [N]/25
- Current mitigations: [what exists]
- Gaps: [what's missing]
- Recommended controls: [specific fixes]

## Security Controls Summary
[Table of controls by threat]
```

---

## Verification Checklist

- [ ] All entry points enumerated (API, forms, webhooks, queues, admin)
- [ ] Trust boundaries drawn and reviewed
- [ ] Data classified by sensitivity
- [ ] STRIDE analysis completed for each boundary
- [ ] Each threat DREAD-scored
- [ ] Critical and High threats have assigned owners and deadlines
- [ ] Agentic AI threats evaluated (if system uses LLM agents)
- [ ] Threat model document written and reviewed
- [ ] Controls traced to specific threats (coverage matrix)
