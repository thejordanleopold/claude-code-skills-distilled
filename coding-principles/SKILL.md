---
name: coding-principles
description: |
  Use when making implementation decisions, deciding how to structure code, choosing between
  simple and clever approaches, managing dependencies, applying 12-factor principles, handling
  destructive operations safely, or applying incremental delivery discipline. Use when starting
  to implement a feature and needing a guiding framework for day-to-day coding decisions.
  Triggers: "how should I write this", "should I abstract this", "is this too complex",
  "what dependencies should I use", "incremental delivery", "simplicity", "YAGNI".
---

# Coding Principles

Day-to-day engineering discipline for writing code that is simple, correct, and maintainable.

**Core principle:** The best code is code you don't write. The second best is code that is obvious.

## When to Use

- Starting implementation of a feature
- Deciding whether to abstract or generalize
- Choosing or evaluating dependencies
- Applying 12-factor app principles
- Reviewing your own code before submitting

## When NOT to Use

- Architectural decisions spanning multiple systems (use system-design)
- API/interface design (use api-design)
- Refactoring existing code (use refactoring)

---

## Simplicity First

### The Complexity Budget

Every feature starts with zero complexity credit. Each abstraction costs from that budget.

**Prefer earlier in this hierarchy:**
1. Delete the code entirely (best)
2. Inline the logic — no abstraction
3. Simple function — one level of indirection
4. Module with clear interface
5. Framework or library (last resort)

### Scope Discipline

| Request | Do it? | Rule |
|---------|--------|------|
| "Make it configurable" | Only with 2+ actual callers today | |
| "Add a hook for future" | Only if future use is confirmed | |
| "Generalize this" | Only with 3+ concrete cases | |
| "Error handling for X" | Only if X can actually happen | |

**Three concrete cases before abstracting. One case stays inline.**

### What Not to Write

- Error handling for things that cannot happen
- Validation for internal function arguments
- Feature flags for changes you're making now
- Backwards-compat shims for code with no callers
- Helpers used by exactly one call site
- Comments that describe what the code does (make the code say it)

---

## Incremental Delivery

### Commit Discipline

```
Work pattern: Implement slice → Test → Verify → Commit → Next slice
```

- Each commit: one logical change, passing tests, ~50-200 lines
- Never "WIP" commits on shared branches
- Commit message states WHY, not WHAT (the diff shows what)

```
feat: add task creation endpoint with validation

Validates title length and due date before persisting.
Required by mobile team for v2.1 launch.
```

### Vertical Slices

Build end-to-end features, not horizontal layers:

```
❌ Week 1: all DB models, Week 2: all services, Week 3: all endpoints
✅ Day 1: create task (full stack), Day 2: list tasks, Day 3: complete task
```

Each slice is working, tested, and deployable.

---

## Dependency Management

### Decision Matrix

| Factor | Use | Avoid |
|--------|-----|-------|
| Lines replaced | 100+ lines | < 20 lines |
| Maintenance activity | Active, recent commits | Abandoned (>1yr) |
| Download count | 100k+/week | < 1k/week |
| License | MIT/Apache | GPL/AGPL (check) |
| Security history | Clean | Multiple CVEs |

### Rules

- One dependency per job — not 3 libraries doing date formatting
- Pin exact versions in production (`4.17.21` not `^4.17.21`)
- Audit before adding: `npm audit`, check last commit, check issues
- Prefer native platform APIs when sufficient
- Small utility (<100 lines)? Copy and own it instead

---

## Destructive Command Awareness

Before any write/delete/update, answer:

1. **Reversible?** — Soft delete vs hard delete. Archive vs purge.
2. **Blast radius?** — One record? All records? Cascading effects?
3. **Confirmation gate?** — For bulk operations, require explicit confirmation.

```typescript
// Safe: soft delete with recovery path
await task.update({ deletedAt: new Date() });

// Dangerous: hard delete — require explicit opt-in
if (!options.force) {
  throw new Error('Pass { force: true } to permanently delete');
}
await task.destroy();
```

For bulk operations (>100 records), always preview before executing:
```typescript
const count = await Task.count({ where: filter });
console.log(`Will delete ${count} tasks. Pass confirm: true to proceed.`);
if (!options.confirm) return;
```

---

## 12-Factor App

| Factor | Practice |
|--------|---------|
| **Config** | Environment variables only. Never config in code. |
| **Processes** | Stateless. Session in DB/cache, never in-process memory. |
| **Dependencies** | Explicit in package.json. Nothing assumed from environment. |
| **Backing services** | DB, cache, queue as attached resources via URL/env. |
| **Build/run** | Strict separation. Build once, run many environments. |
| **Disposability** | Fast startup (<5s), graceful shutdown (drain in-flight). |
| **Dev/prod parity** | Same backing services in dev and prod (Docker Compose). |
| **Logs** | Stdout only. App never writes log files. |
| **Admin processes** | Run as one-off commands in same environment as app. |

---

## Common Rationalizations to Reject

| Rationalization | Reality |
|----------------|---------|
| "I'll refactor it later" | You won't. Write it right the first time. |
| "This abstraction will pay off" | Only with 3+ concrete uses. |
| "It's just a small exception" | Exceptions compound into architecture. |
| "I'll add tests after" | Tests reveal design problems. Write them first. |
| "It's obvious, no comment needed" | Future you at 2am disagrees. |

## Verification Checklist

- [ ] Simplest solution chosen (not cleverest)
- [ ] No "just in case" code
- [ ] No helpers used by exactly one call site
- [ ] No feature flags for immediate changes
- [ ] Dependencies audited before adding
- [ ] Exact versions pinned
- [ ] Destructive operations have confirmation gates
- [ ] Config in environment variables (nothing hardcoded)
- [ ] App is stateless (session not in-process)
- [ ] Commits are atomic and have meaningful messages
