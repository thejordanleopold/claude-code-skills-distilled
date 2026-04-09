---
name: feature-planning
description: |
  Use when starting a new feature, clarifying requirements before writing code, deciding scope,
  creating a vertical slice delivery plan, or determining what not to build. Triggers:
  "plan this feature", "how should I approach", "what should we build", "clarify requirements",
  "break this down", "scope this", "what's the MVP", "where do I start", "think before coding".
---

# Feature Planning

Structured thinking before coding. The goal is to arrive at the smallest useful slice with clear success criteria before writing a single line.

**Core principle (Karpathy):** The best code is code you don't write. The second best is code that solves the right problem.

## When to Use

- Starting any non-trivial feature (>2 hours of work)
- Requirements are ambiguous or underspecified
- Multiple implementation approaches exist
- Scope is unclear (what's in vs out)
- Need to break a large feature into deliverable slices

## When NOT to Use

- Trivial bug fixes with obvious solutions
- One-line changes
- Architecture decisions spanning multiple systems (use system-design skill)

---

## Phase 1: Clarify (Before Anything Else)

Answer these before touching code:

### Karpathy's 3 Forcing Questions

1. **What is the simplest possible solution?** — Not the cleverest. The one a junior could maintain.
2. **What are the failure modes?** — What breaks when inputs are wrong, services fail, or state is corrupt?
3. **What is the contract?** — What does this feature promise to users and callers? What can they rely on?

If you cannot answer all three, you are not ready to plan.

### gstack Q1-Q6 Analysis

| Question | Purpose |
|----------|---------|
| Q1: What problem are we solving? | Validate the need actually exists |
| Q2: Who is the user? | Ground decisions in real usage patterns |
| Q3: What's the simplest solution that works? | Prevent over-engineering |
| Q4: What are the failure modes? | Design for reality, not the happy path |
| Q5: What does success look like? | Define done before starting |
| Q6: What are we NOT building? | Scope discipline — what's explicitly excluded |

Write answers down. Q3 and Q4 are non-negotiable.

### Clarification Format for Underspecified Requests

When a request is underspecified, ask the minimum set of questions needed:
- 1-5 questions maximum in the first pass
- Numbered questions with lettered options; **bold the recommended choice**
- Include a fast-path: "Reply `defaults` to accept all recommended choices"
- After answers, restate chosen options in plain language to confirm

Example:
```
1) Scope?  **a) Minimal change** / b) Refactor area / c) Not sure
2) Compat? **a) Current defaults** / b) Older versions / c) Not sure

Reply: defaults (or 1a 2b)
```

While waiting for answers: you may do low-risk discovery (read configs, inspect repo structure) but do not edit files or produce a plan that depends on unknowns.

---

## Phase 2: Scope Discipline

### What to Include vs Exclude

| Request | Include? | Rule |
|---------|---------|------|
| "Make it configurable" | Only if 2+ callers need different values today | |
| "Add a hook for future use" | Only if future use is confirmed and imminent | |
| "Generalize this" | Only with 3+ concrete cases in hand | |
| "Add error handling for X" | Only if X can actually happen at runtime | |
| "Support Y format too" | Only if a real user needs Y today | |

**The rule:** Three concrete cases before abstracting. One concrete case stays specific.

---

## Phase 3: Vertical Slicing

Never build horizontal layers. Build vertical slices that are working end-to-end.

```
BAD (horizontal):
  Week 1: All database models
  Week 2: All service layer
  Week 3: All API endpoints
  Week 4: All UI

GOOD (vertical):
  Day 1: User can create a task (full stack, minimal)
  Day 2: User can list tasks
  Day 3: User can complete tasks
  Day 4: User can delete tasks
```

Each slice: working, tested, deployable. No half-built layers.

### Walking Skeleton

Start with the thinnest possible E2E path:
- No business logic — just wiring
- Proves the architecture works before investing in features
- Real data flowing through real components
- Deployable immediately

---

## Phase 4: The Plan

Write a plan with:

```markdown
## Feature: [Name]

**Problem:** [One sentence — what user pain does this solve?]
**Success:** [Observable, measurable outcome]
**Out of scope:** [Explicitly excluded]

## Slices (in priority order)

### Slice 1: [Title]
- What the user can do after this slice
- Files to create/modify: [list]
- Definition of done: [observable behavior]

### Slice 2: [Title]
...
```

---

## Common Rationalizations to Reject

| Rationalization | Reality |
|----------------|---------|
| "While I'm in here, I'll also..." | Scope creep starts here. Finish the slice first. |
| "This abstraction will pay off later" | Only with 3+ concrete uses. |
| "I'll add tests after" | Tests reveal design problems. Write them first. |
| "It's obvious, no need to clarify" | Assumptions misalign silently for days. |
| "I'll generalize it now to save time" | You won't need the generalization. |

## Verification Checklist

Before writing code:
- [ ] Q1-Q6 answered in writing
- [ ] Simplest solution identified (not cleverest)
- [ ] Failure modes listed (network, invalid input, concurrent access)
- [ ] Contract defined (what does the feature promise?)
- [ ] Scope explicitly bounded (what's NOT included)
- [ ] Deliverable sliced vertically (each slice is end-to-end working)
- [ ] Walking skeleton identified (thinnest useful E2E path)
- [ ] Definition of done is observable and unambiguous
