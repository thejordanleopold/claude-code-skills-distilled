---
name: code-standards
description: |
  Use when evaluating whether code meets quality standards, checking naming conventions,
  assessing complexity thresholds, identifying anti-patterns, understanding what good code
  looks like, or applying quality standards to your own code before submitting. Triggers:
  "is this code good", "code quality", "does this follow best practices", "naming conventions",
  "is this too complex", "code standards", "what makes good code", "anti-patterns".
---

# Code Standards

What production-quality code looks like. Use this as a quality bar for writing and evaluating code.

**Core principle:** Code is read far more often than it is written. Optimize for the reader.

## When to Use

- Evaluating your own code before submitting a PR
- Establishing standards for a codebase or team
- Identifying quality problems in existing code
- Answering "is this good enough?"

## When NOT to Use

- Conducting a full code review (use code-review skill)
- Refactoring existing code (use refactoring skill)

---

## Naming Standards

| Element | Rule | Example |
|---------|------|---------|
| Functions/methods | Verb + noun, reveals what it does | `fetchUserById`, `calculateTax`, `validateEmail` |
| Boolean variables | `is`, `has`, `can`, `should` prefix | `isValid`, `hasPermission`, `canEdit` |
| Classes | Noun, PascalCase | `UserRepository`, `PaymentService` |
| Constants | SCREAMING_SNAKE_CASE | `MAX_RETRY_ATTEMPTS`, `DEFAULT_TIMEOUT_MS` |
| Generic params | T for type, K/V for key/value | `function find<T>(items: T[]): T` |
| Test names | `it("does X when Y")` | `it("returns null when user not found")` |

**Banned patterns:**
- Single-letter variables outside loop indices (`i`, `j`, `k` in loops only)
- Abbreviations that aren't industry-standard (`usr`, `mgr`, `tmp`)
- Generic names: `data`, `info`, `stuff`, `helper`, `util`, `manager`
- Misleading names: a function that does Y but is called `doX`

---

## Complexity Thresholds

| Element | Threshold | Action if Exceeded |
|---------|-----------|-------------------|
| Function length | 50 lines | Extract to sub-functions |
| File length | 300 lines | Split into modules |
| Parameters | 4 | Use options object |
| Cyclomatic complexity | 10 | Simplify logic |
| Nesting depth | 3 levels | Early returns, extract functions |
| Class methods | 10 | Single Responsibility violation — split |

---

## Anti-Pattern Reference

### Code Smells to Eliminate

| Smell | Example | Fix |
|-------|---------|-----|
| **Magic numbers** | `if (status === 3)` | `if (status === OrderStatus.CANCELLED)` |
| **Boolean parameters** | `render(true, false, true)` | Named options object or separate functions |
| **Commented-out code** | `// old code here` | Delete it (git has history) |
| **Deep nesting** | 4+ levels of if/for | Early returns, extract functions |
| **God function** | 200 lines doing everything | Single Responsibility — extract |
| **Shotgun surgery** | One change requires edits in 7 files | Wrong abstraction boundary |
| **Inappropriate intimacy** | Class A accesses Class B's private data | Encapsulation violation — add methods |
| **Primitive obsession** | `string` used for userId, email, and slug interchangeably | Value objects |

### Two Hats Rule

Never mix refactoring and optimization in the same session.
- **Hat 1: Refactoring** — change structure, NOT behavior. Tests must pass unchanged.
- **Hat 2: Optimization** — improve performance, NOT structure. Benchmarks required.

When switching hats: commit first, then switch context.

### The Worst Offenders

```typescript
// BANNED: Error silencing
try { doThing(); } catch (e) { /* ignore */ }
// FIX: At minimum, log. At most, handle.

// BANNED: Non-null assertion without justification
const user = getUser()!;
// FIX: const user = getUser() ?? throw new Error('...')

// BANNED: any type
function process(data: any): any { ... }
// FIX: explicit types or generics

// BANNED: Mutable global state
let currentUser = null;  // module-level
// FIX: pass through function parameters or use proper context

// BANNED: Function with side effects and a name implying pure query
function getUserName(id: string): string {
  logger.audit(`Name lookup: ${id}`);  // side effect!
  return db.get(id).name;
}
// FIX: separate concerns or document the side effect
```

### Performance Anti-Patterns

| Pattern | Fix |
|---------|-----|
| N+1 queries (DB call in a loop) | Batch fetch before loop; use eager loading |
| Blocking I/O in async handler (`readFileSync`, `execSync`) | Use async equivalents |
| No pagination (`SELECT *` returning all rows) | Add `LIMIT` / cursor pagination |
| O(n²) algorithm (nested loops over same data) | HashMap or sort + single pass |

---

## Function Quality Standards

A good function:
- Does **one thing** — can be described in a single sentence without "and"
- Has a **clear name** — caller doesn't need to read the body
- Has **4 or fewer parameters** — more → use options object
- Handles its **error cases explicitly** — no silent failures
- Has **no unexpected side effects** — if it has side effects, name makes it clear

```typescript
// Bad: does multiple things, unclear, silent failure
function process(d: any, f: boolean) {
  try {
    db.save(d);
    if (f) sendEmail(d.email, 'done');
  } catch {}
}

// Good: single responsibility, clear name, typed, explicit errors
async function saveTaskAndNotify(task: Task, notify: boolean): Promise<void> {
  await taskRepository.save(task);
  if (notify) {
    await emailService.sendTaskCreated(task.assignee.email, task);
  }
}
```

---

## Error Handling Standards

```typescript
// Every async function either returns a result or throws a typed error

// Bad: returns null on failure (caller must remember to check)
async function getUser(id: string): Promise<User | null> {
  try { return await db.findUser(id); }
  catch { return null; }
}

// Good: throws on not-found, caller can rely on non-null return
async function getUser(id: string): Promise<User> {
  const user = await db.findUser(id);
  if (!user) throw new NotFoundError(`User ${id} not found`);
  return user;
}

// Bad: catch-all silence
try { await riskyOperation(); } catch (e) { /* ignore */ }

// Good: explicit handling
try {
  await riskyOperation();
} catch (err) {
  if (err instanceof NetworkError) {
    logger.warn('Network error, retrying', { err });
    await retry(riskyOperation);
  } else {
    logger.error('Unexpected error', { err });
    throw err;  // re-throw unknown errors
  }
}
```

---

## Testing Standards

Every non-trivial function needs tests covering:

| Case | Why |
|------|-----|
| Happy path | Proves basic functionality |
| Empty/null input | Most common source of bugs |
| Boundary values | Off-by-one errors |
| Error conditions | Verifies graceful failure |
| Concurrent execution | For async/shared-state code |

```typescript
describe('calculateTax', () => {
  it('returns 0 for zero subtotal', () => { ... });
  it('applies rate to positive subtotal', () => { ... });
  it('throws for negative subtotal', () => { ... });
  it('handles floating point precision correctly', () => { ... });
});
```

---

## Common Rationalizations to Reject

| Rationalization | Reality |
|----------------|---------|
| "It's obvious what this does" | Future you at 2am disagrees |
| "I'll clean it up later" | Later is never scheduled |
| "It's just a quick fix" | Quick fixes compound into legacy debt |
| "The tests are too hard to write" | The code is too hard to test — simplify it |
| "It works, don't touch it" | Working ≠ correct; correct ≠ maintainable |

### Automated Quality Gates (by phase)

| Phase | Checks |
|-------|--------|
| Pre-commit | Lint + format + type check + secret scan |
| CI pipeline | Lint + secret scan + vulnerability scan + tests |
| Continuous | Dependency updates + security advisories |

## Verification Checklist

- [ ] All names reveal intent (no abbrevations, no generic names)
- [ ] No function longer than 50 lines
- [ ] No file longer than 300 lines
- [ ] No magic numbers (use named constants)
- [ ] No boolean function parameters
- [ ] No error silencing (every catch either handles or re-throws)
- [ ] No commented-out code
- [ ] Every function does one thing
- [ ] Parameters ≤ 4 (or options object used)
- [ ] Tests cover happy path, empty/null, error conditions
