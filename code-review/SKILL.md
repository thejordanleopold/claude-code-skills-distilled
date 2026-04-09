---
name: code-review
description: |
  Use when reviewing code, giving feedback on a PR, auditing a codebase for quality problems,
  or evaluating code before submitting. Triggers: "review this", "code review", "review this PR",
  "give me feedback on this code", "audit this code", "what's wrong with this",
  "is this implementation good", "critique this", "check this for issues".
---

# Code Review

Systematic code review across six dimensions with confidence-scored findings.

**Core principle:** A finding without a severity and a concrete fix is noise. Every issue needs: what, why it matters, and how to fix it.

## When to Use

- Reviewing a PR before merge
- Auditing existing code for quality problems
- Giving structured feedback on someone's implementation
- Self-reviewing before submitting

## When NOT to Use

- Security-only audit (use security-review skill)
- Performance-only audit (use frontend-performance or backend-performance skill)
- Refactoring existing code (use refactoring skill)

---

## The 6-Axis Framework

Rate each dimension and note specific findings:

| Axis | What to Evaluate |
|------|-----------------|
| **Correctness** | Does it do what it claims? Edge cases handled? Concurrency safe? |
| **Security** | Input validated? Auth checked? No injection vectors? Secrets safe? |
| **Performance** | N+1 queries? Unbounded loops? Missing indexes? Memory leaks? |
| **Readability** | Names reveal intent? Functions do one thing? Complexity justified? |
| **Maintainability** | Tests present? Error states handled? No magic constants? |
| **Architecture** | Right abstraction level? Follows existing patterns? Coupling minimal? |

---

## Risk Classification

### HIGH — Block merge, fix before shipping

- Incorrect behavior on valid input
- Security vulnerability (injection, auth bypass, data exposure)
- Data loss or corruption possibility
- Crash on expected inputs
- Breaking change without versioning

### MEDIUM — Fix before or shortly after shipping

- Unhandled edge cases (error, empty, concurrent)
- Misleading names that will cause future bugs
- Missing tests for critical paths
- Performance problem that will matter at scale
- Inconsistent with established patterns

### LOW — Fix when convenient

- Naming improvements
- Redundant code
- Minor style inconsistencies
- Optimization in non-critical paths
- Comment improvements

---

## Adversarial Analysis (3 Personas)

After the 6-axis review, think from these perspectives:

### Persona 1: The Attacker

- What happens if every input is malicious?
- Can I bypass authentication or authorization?
- Can I inject code via any input field?
- Can I cause a denial of service?
- Can I read data I shouldn't?

### Persona 2: The User

- What happens when the network is slow or fails?
- What error does the user see when this fails?
- What if the user does something unexpected (refresh mid-flow, double-click)?
- What if the user's data is empty, very large, or unusual?

### Persona 3: The Future Maintainer

- If I come back to this in 6 months, will I understand it?
- If I need to add a feature, where do I make the change?
- If this breaks at 3am, will the logs tell me what happened?
- If requirements change, how many places need updating?

---

## Confidence Scoring

Score each finding before reporting it:

| Score | Meaning | Report |
|-------|---------|--------|
| 9-10 | Verified by reading specific code path | Report with full detail |
| 7-8 | High confidence, clear pattern match | Report normally |
| 5-6 | Moderate, could be false positive | Report with caveat |
| 3-4 | Low confidence | Mention as question, not finding |
| 1-2 | Speculation | Only if critical severity |

**Rule:** Do not report a finding you haven't traced. Pattern matching without code tracing is noise.

---

## Multi-Model Review Pattern

For critical code, run independent reviews from multiple perspectives:

```
Pass 1: Correctness — does it do what it says?
Pass 2: Security — can it be exploited?
Pass 3: Architecture — does it fit the system?
```

Separate passes catch different things. A reviewer focused on architecture misses security; one focused on security misses architecture.

---

## Finding Format

Each finding:
```
[SEVERITY] [Axis] Short title

Location: file.ts:42

Problem: [What is wrong and why it matters]

Evidence: [Specific code that demonstrates the issue]

Fix: [Concrete recommendation]
```

---

## Review Checklist

**Correctness:**
- [ ] Logic handles empty, null, and boundary values
- [ ] Concurrent access is safe (no race conditions)
- [ ] Error paths return/throw appropriate values
- [ ] Function does what its name says

**Security:**
- [ ] All user input validated server-side
- [ ] No SQL/command/template injection vectors
- [ ] Auth and authz checks present on all sensitive operations
- [ ] No secrets in code or logs

**Performance:**
- [ ] No N+1 query patterns
- [ ] No unbounded data fetches
- [ ] No synchronous blocking in async context
- [ ] Memory not growing unboundedly

**Readability:**
- [ ] Names reveal intent (no single-letter variables except loop indices)
- [ ] Functions do one thing and are <50 lines
- [ ] No magic numbers (use named constants)
- [ ] Complex logic has explanatory comments

**Maintainability:**
- [ ] Tests cover happy path and important edge cases
- [ ] Loading, error, and empty states all handled
- [ ] No copy-paste duplication
- [ ] No dead code

**Architecture:**
- [ ] Follows established patterns in the codebase
- [ ] Dependencies point the right direction
- [ ] Coupling is minimal (changes here don't cascade everywhere)
- [ ] Abstraction level is appropriate (not over- or under-engineered)
