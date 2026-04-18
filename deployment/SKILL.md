---
name: deployment
description: "Use when configuring CI/CD pipelines, deploying to production, implementing feature flags, monitoring canary releases, setting up GitHub Actions, managing rollbacks, configuring observability for deployments, or responding to production incidents. Triggers: \"deploy\", \"CI/CD\", \"pipeline\", \"release\", \"feature flag\", \"canary\", \"rollback\", \"GitHub Actions\", \"ship\", \"production\", \"incident\", \"monitoring deployment\", \"deployment strategy\"."
---

# Deployment

CI/CD pipelines, deployment strategies, canary monitoring, and incident response.

**Core principle:** Every deploy is reversible. If you cannot roll back, you are not ready to ship.

## When to Use

- Configuring CI/CD quality gates
- Deploying a new service or feature
- Implementing feature flags for safe releases
- Monitoring a canary release
- Rolling back a bad deploy
- Responding to a production incident

## When NOT to Use

- Git commits and branching (use git-workflow skill)
- Production observability setup (use observability skill)

---

## CI/CD Quality Gate Pipeline

No gate can be skipped. Every PR goes through all stages.

```
Pull Request Opened
    |
  LINT CHECK       (eslint, prettier)
    | pass
  TYPE CHECK       (tsc --noEmit)
    | pass
  UNIT TESTS       (jest/vitest)
    | pass
  BUILD            (npm run build)
    | pass
  INTEGRATION      (API/DB tests)
    | pass
  SECURITY AUDIT   (npm audit --audit-level=high)
    |
  Ready for review
```

### GitHub Actions Configuration

```yaml
name: CI
on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '22'
          cache: 'npm'
      - run: npm ci
      - run: npm run lint
      - run: npx tsc --noEmit
      - run: npm test -- --coverage
      - run: npm run build
      - run: npm audit --audit-level=high
```

---

## Ship Workflow (Code to Production)

### Pre-flight Checklist

- [ ] On feature branch (not main)
- [ ] All tests pass locally
- [ ] `git status` clean
- [ ] Rebased on latest main

### Steps

1. **Merge base branch** — `git fetch origin main && git merge origin/main --no-edit`
2. **Run full test suite** against merged code
3. **Create PR** — structured body with what changed and test plan
4. **Wait for CI** — all gates must pass
5. **Merge** — squash or merge commit per team convention
6. **Monitor deploy** — watch CI/CD, check health endpoint

---

## Feature Flags

Decouple deployment from release. Code ships off, gets turned on gradually.

### Flag Lifecycle

```
DEPLOY with flag OFF     → Code in production, inactive
ENABLE for team/beta     → Internal testing in production
GRADUAL ROLLOUT          → 5% → 25% → 50% → 100%
MONITOR at each stage    → Watch error rate, latency, user feedback
CLEAN UP                 → Remove flag and dead code within 2 weeks of 100%
```

### Implementation

```typescript
// Simple environment-based flag
if (featureFlags.isEnabled('new-checkout-flow', { userId })) {
  return renderNewCheckout();
}
return renderLegacyCheckout();

// Percentage rollout
function isEnabled(flag: string, context: { userId: string }): boolean {
  const rollout = config.flags[flag]?.rolloutPercent ?? 0;
  const hash = murmurhash(context.userId + flag) % 100;
  return hash < rollout;
}
```

**Rules:**
- Every flag has an owner and a cleanup date (max 2 weeks after 100%)
- Remove dead code when removing the flag (don't leave both paths)
- Never use flags as permanent A/B test infrastructure

---

## Rollback Strategy

Define rollback plan before every deploy.

| Situation | Rollback Method | Time |
|-----------|----------------|------|
| Feature flag controlled | Disable flag | <1 minute |
| Recent deploy (< 1 hour) | Redeploy previous release | <5 minutes |
| Database migration involved | Run migration rollback | <15 minutes |
| Data corruption detected | Restore from backup | <60 minutes |

### Rollback Triggers

Roll back immediately if:
- Error rate increases >2x baseline
- p95 latency increases >50%
- User-reported issues spike
- Data integrity issues detected
- Health check returns non-200

```bash
# Redeploy previous version (example: Railway, Heroku, etc.)
git revert HEAD --no-edit
git push origin main
# CI deploys the revert

# Or: re-trigger previous successful deploy in CI/CD platform
```

---

## Post-Deploy Verification (First Hour)

```
1. Health endpoint returns 200 (within 2 minutes of deploy)
2. Error monitoring: no new error types spiking
3. Latency: p95 not regressed vs pre-deploy baseline
4. Critical user flow: manually verify end-to-end
5. Logs flowing (structured JSON, no unexpected ERROR level spikes)
6. Rollback mechanism tested (know how to do it if needed)
```

---

## Environment Management

```
.env.example    → Committed (template with placeholder values)
.env            → NOT committed
CI secrets      → Stored in GitHub Secrets / vault
Prod secrets    → Stored in deployment platform secrets manager
```

**Environment variable precedence:**
```
Production platform secrets → CI/CD platform secrets → .env.local → .env
```

**Never:**
- Commit real secrets (even in private repos)
- Use production credentials in development
- Share secrets via Slack, email, or chat

---

## Incident Management

### Severity Levels

| Level | Impact | Response Time |
|-------|--------|--------------|
| SEV1 | Complete outage | Immediate — all hands |
| SEV2 | Major degradation (>20% users) | <15 minutes |
| SEV3 | Minor degradation | <1 hour |
| SEV4 | Low impact, workaround available | Next business day |

### Incident Response Process

1. **Detect** — monitoring alert or customer report
2. **Triage** — assess severity, assign incident commander
3. **Communicate** — status page, stakeholder update
4. **Investigate** — check recent changes, review logs and metrics
5. **Mitigate** — rollback, feature flag off, or hotfix
6. **Resolve** — confirm fix working, monitor for recurrence
7. **Learn** — blameless postmortem within 48 hours

### Blameless Postmortem Template

```markdown
## Incident: [Title]
**Date:** YYYY-MM-DD | **Duration:** Xh Ym | **Severity:** SEV[N]

## Timeline
- HH:MM — Event 1
- HH:MM — Event 2

## Root Cause
[What actually caused the incident]

## Contributing Factors
[What made it worse or harder to detect]

## What Went Well
[Detection speed, response coordination, etc.]

## Action Items
| Item | Owner | Due Date |
|------|-------|---------|
| Add alert for X | @person | YYYY-MM-DD |
```

---

## Pre-Launch Checklist

**Code:**
- [ ] All tests pass, no CI failures
- [ ] Build succeeds with no warnings
- [ ] Code reviewed and approved

**Security:**
- [ ] No secrets in code or environment config files
- [ ] `npm audit` shows no Critical/High
- [ ] Auth and input validation in place
- [ ] Rate limiting on auth endpoints

**Infrastructure:**
- [ ] Environment variables set in production
- [ ] Database migrations applied and tested
- [ ] Health check endpoint responding

**Operations:**
- [ ] Rollback plan documented and tested
- [ ] Monitoring and alerting configured
- [ ] On-call rotation knows about the deploy

## Common Rationalizations to Reject

| Rationalization | Reality |
|----------------|---------|
| "CI is too slow, I'll skip it" | Optimize the pipeline — never skip it |
| "It works in staging, it'll work in production" | Production has different data and traffic |
| "Rolling back is admitting failure" | Rolling back is responsible engineering |
| "We'll add monitoring after launch" | You need monitoring to know if launch succeeded |
