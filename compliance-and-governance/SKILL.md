---
name: compliance-and-governance
description: "Use when preparing for SOC 2 Type I or Type II audits, implementing ISO 27001 ISMS, achieving GDPR compliance, conducting gap analysis against compliance frameworks, mapping controls to audit criteria, collecting and automating audit evidence, designing continuous compliance monitoring, or managing vendor risk assessments. Apply to SaaS companies, regulated industries, or any organization requiring third-party security or privacy assurance."
---

# Compliance and Governance

Frameworks and operational guidance for SOC 2, ISO 27001, GDPR, and accessibility compliance.

**Core principle:** Compliance built into daily operations beats point-in-time audit preparation. Automate evidence collection before you need it.

## When to Use

- Enterprise customer requires SOC 2 report
- Entering a regulated industry (healthcare, finance, government)
- GDPR obligations triggered by EU user data
- Preparing for ISO 27001 certification
- Conducting gap analysis against a compliance framework
- Building automated evidence collection

## When NOT to Use

- Security vulnerability remediation (use security-hardening skill)
- WCAG implementation in UI components (use ui-components skill)
- Internal policy writing without compliance framework context

---

## SOC 2

### Type I vs Type II

| Aspect | Type I | Type II |
|--------|--------|---------|
| What it tests | Control design at a point in time | Design AND operation over 6-12 months |
| Timeline | 4-6 weeks prep + audit | 6-12 month observation + audit |
| Cost | $20K-$50K | $30K-$100K+ |
| Use when | First compliance milestone, fast enterprise sales | Mature orgs, stringent customer requirements |

### Trust Service Criteria (TSC)

**Security (CC1-CC9) is mandatory.** Others optional but often requested.

| Criteria Group | Focus |
|---------------|-------|
| **CC1** Control Environment | Integrity, ethics, org structure |
| **CC2** Communication | Info quality, internal/external comms |
| **CC3** Risk Assessment | Risk ID, fraud risk, change impact |
| **CC4** Monitoring | Ongoing monitoring, deficiency evaluation |
| **CC5** Control Activities | Policies, procedures, tech controls |
| **CC6** Logical & Physical Access | Auth, provisioning, encryption |
| **CC7** System Operations | Vulnerability mgmt, incident response |
| **CC8** Change Management | Change authorization, testing, approval |
| **CC9** Risk Mitigation | Vendor/partner risk management |

Optional: Availability (A1), Confidentiality (C1), Processing Integrity (PI1), Privacy (P1-P8).

### Control Matrix

Every control needs:

```
Control ID:         SEC-001
TSC Mapping:        CC6.1, CC6.2
Description:        MFA is required for all privileged access
Type:               Preventive
Owner:              Security Engineering
Frequency:          Continuous
Evidence:           IAM policy config, MFA enforcement logs
Testing Procedure:  Auditor verifies MFA required via identity provider config
```

### Evidence Automation

| Control Area | Evidence | Automation |
|---|---|---|
| Access reviews | Quarterly user access reports | Scheduled IAM exports + email workflow |
| Change management | PR history, deployment logs | Git + CI/CD pipeline logs |
| Vulnerability management | Scan reports, patch SLA tracking | Scheduled scans, automated reports |
| Incident response | Incident tickets, postmortems | Alert system → ticket creation |
| Encryption | Config screenshots, key rotation logs | IaC snapshots, HSM audit logs |
| Employee training | Completion records | LMS export, e-signature tracking |
| Vendor assessments | SOC 2 reports, questionnaires | Vendor registry with renewal reminders |

### Pre-Audit Readiness (4-6 Weeks Before)

- [ ] All controls documented with owner, frequency, evidence type
- [ ] Evidence collected for full observation period (Type II)
- [ ] Gaps remediated
- [ ] Policies signed within last 12 months
- [ ] Access reviews completed per scheduled frequency
- [ ] Critical/high vulnerabilities patched per SLA
- [ ] Incident response plan tested within last 12 months
- [ ] DR/BCP tested and documented
- [ ] All vendor assessments current

---

## ISO 27001

### ISMS Lifecycle

```
Plan  → Define scope, risk assessment, security policy, controls
Do    → Implement controls, security awareness training
Check → Internal audit, incident analysis, metrics review
Act   → Corrective actions, management review, continuous improvement
```

### Risk Assessment

```
1. Asset inventory (systems, data, services)
2. Threat analysis (unauthorized access, malware, outages, human error)
3. Vulnerability assessment (unpatched systems, weak config, training gaps)
4. Risk score = Likelihood (1-5) × Impact (1-5)
5. Risk treatment: Accept | Mitigate | Transfer | Avoid
```

| Score | Treatment | Timeline |
|-------|-----------|---------|
| 20-25 (Critical) | Immediate mitigation | <2 weeks |
| 15-19 (High) | Planned remediation | <30 days |
| 10-14 (Medium) | Scheduled work | <90 days |
| <10 (Low) | Accept or monitor | Next cycle |

### Statement of Applicability (SoA)

Document which ISO 27002 controls apply and why:

```
Control A.8.1 Access Control Policy
  Applicable: Yes
  Justification: Required to manage user access to production systems
  Implementation: IAM policies enforced via Okta + AWS IAM
```

Mark non-applicable controls with clear justification (e.g., "Physical security outsourced to cloud provider").

### Certification Stages

- **Stage 1 (Documentation):** ISMS scope, risk assessment, SoA, policy reviewed
- **Stage 2 (Implementation, 6+ months operation required):** Controls verified operational, evidence reviewed
- **Annual surveillance:** Focused review of key controls, corrective actions

---

## GDPR

### Legal Bases (Must document for EVERY processing activity)

| Basis | When | Example |
|-------|------|---------|
| Consent (6.1.a) | Explicit opt-in obtained | Marketing emails, analytics |
| Contract (6.1.b) | Necessary to perform service | Order fulfillment, billing |
| Legal Obligation (6.1.c) | Law requires it | Tax records, employment |
| Legitimate Interests (6.1.f) | Org interest + balancing test | Fraud prevention, security |

### Data Subject Rights (30-day response, extendable to 90)

| Right | Article | Obligation |
|-------|---------|-----------|
| Access | 15 | Provide copy of personal data + processing info |
| Rectification | 16 | Correct inaccurate data |
| Erasure | 17 | Delete data (with legal obligation exceptions) |
| Portability | 20 | Provide data in machine-readable format |
| Objection | 21 | Stop processing based on legitimate interests |

**Build a process:** Intake form → identity verification → 30-day clock → fulfillment.

### Records of Processing Activities (RoPA — Art. 30)

For each processing activity document:
- Purpose, legal basis, categories of personal data
- Who has access (internal teams, vendors)
- Retention period
- Security measures

### Breach Notification (Art. 33-34)

| Timeline | Action |
|----------|--------|
| Without undue delay (72hr target) | Notify supervisory authority if risk to individuals |
| Without undue delay | Notify affected data subjects if high risk |
| 30 days | Final investigation report to regulator |

Log ALL breaches even if not reportable.

### DPIA Required When

- Systematic monitoring at scale
- Large-scale processing of special categories (health, biometric)
- Automated decisions with legal/significant effect
- New technology with unclear privacy implications

---

## Gap Analysis Methodology

### Four-Step Process

1. **Document current controls** — inventory all policies, procedures, technical controls
2. **Map to requirements** — align each control to SOC 2 TSC, ISO 27001 Annex A, GDPR articles
3. **Identify gaps** — missing, design gaps, operating gaps, partial implementation
4. **Prioritize remediation** — Critical (<2 weeks), High (<30 days), Medium (<90 days), Low (next cycle)

### Gap Types

| Type | Definition | Auditor Impact |
|------|-----------|----------------|
| Missing control | No control exists for criterion | Critical finding |
| Design gap | Control doesn't adequately address criterion | Major finding |
| Operating gap | Control designed right but not consistently executed | Major finding |
| Partial | Control exists but evidence is incomplete | Minor finding |

---

## Continuous Compliance

### From Point-in-Time to Ongoing

| Aspect | Point-in-Time | Continuous |
|--------|--------------|-----------|
| Evidence | Manual before audit | Automated, always available |
| Detection | Found during audit | Real-time drift alerts |
| Prep burden | 4-8 week scramble | Always ready |

### Implementation

```
1. Automate evidence: cron exports, IaC snapshots, API integrations
2. Centralize: evidence repository with timestamps (evidence/access/, evidence/change/, etc.)
3. Alert on drift: notify when controls fall out of compliance
4. Review cadence: monthly control owner check-in, quarterly steering review
```

### Vendor Management

| Tier | Data Access | Assessment Frequency |
|------|-------------|---------------------|
| Critical | Processes customer data | Annual + continuous monitoring |
| High | Accesses customer environment | Annual |
| Medium | Indirect access | Annual |
| Low | No data access | Biennial |

Maintain a vendor registry with risk tier, last assessment date, and SOC 2 report status.

---

## Common Anti-Patterns

| Anti-Pattern | Fix |
|---|---|
| Annual scramble for audit evidence | Automate evidence collection continuously |
| Copy-pasted generic policies | Tailor to actual technology and processes |
| SOC 2 treated as a project | Build compliance into daily operations |
| Vendor assessments missing | Maintain vendor registry with renewal dates |
| RLS/security theater (controls on paper only) | Verify operating effectiveness |
| GDPR rights process undocumented | Build intake form + 30-day tracking workflow |

## Verification Checklist

**SOC 2:**
- [ ] Control matrix complete (owner, frequency, evidence for each criterion)
- [ ] Evidence automated and centralized
- [ ] Access reviews executed per schedule
- [ ] Vendor assessments current for all critical/high vendors
- [ ] Incident response plan tested within 12 months

**ISO 27001:**
- [ ] Risk assessment complete and dated
- [ ] Statement of Applicability reviewed
- [ ] ISMS scope documented
- [ ] Internal audit completed
- [ ] Management review conducted

**GDPR:**
- [ ] RoPA complete for all processing activities
- [ ] Legal basis documented for each activity
- [ ] Data subject rights process documented and tested
- [ ] DPIAs completed for high-risk processing
- [ ] Breach response process documented
- [ ] Vendor DPAs signed

**General:**
- [ ] Continuous evidence collection automated
- [ ] Compliance dashboard visible to security/engineering leadership
- [ ] Quarterly compliance review scheduled
