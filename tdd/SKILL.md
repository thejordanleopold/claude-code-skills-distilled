---
name: tdd
description: |
  Use when writing unit tests, practicing test-driven development, fixing bugs with the
  Prove-It Pattern, applying RED-GREEN-REFACTOR discipline, choosing between mocks and stubs,
  designing the test pyramid, running mutation testing, or verifying test coverage. Triggers:
  "write tests", "TDD", "unit test", "test this function", "RED-GREEN-REFACTOR", "failing test",
  "mock vs stub", "test coverage", "test pyramid", "mutation testing".
---

# TDD — Test-Driven Development

Write tests first. The tests define the contract; the code fulfills it.

**Core principle:** Tests are not a safety net for code. Tests are the specification. Code is the implementation of the spec.

## When to Use

- Writing any non-trivial function or module
- Fixing a bug (Prove-It Pattern)
- Defining the behavior of a new API or interface
- Verifying test quality with mutation testing

## When NOT to Use

- End-to-end browser automation (use e2e-testing skill)
- Integration tests hitting real databases (use e2e-testing skill)
- Exploratory spikes (write the spike, then delete and TDD the real implementation)

---

## RED-GREEN-REFACTOR

The canonical cycle. Do not skip or combine steps.

### RED — Write a Failing Test

```typescript
// Write the test FIRST. It must fail (RED).
it('returns null when user not found', async () => {
  const repo = new InMemoryUserRepository([]);
  const result = await repo.findById('nonexistent-id');
  expect(result).toBeNull();
});
```

**Verify it fails for the RIGHT reason** — the failure message should indicate the feature is missing, not a syntax error or import problem.

### GREEN — Write Minimum Code to Pass

```typescript
// Write the MINIMUM code to make the test pass.
// Not the correct code — the minimum code.
async findById(id: string): Promise<User | null> {
  return this.users.find(u => u.id === id) ?? null;
}
```

If you wrote code before writing the test: **delete it. Start over.** There are no exceptions.

### REFACTOR — Improve Structure (Tests Still Green)

```typescript
// Clean up now that the behavior is locked in by tests.
// Tests run after every change. If they go red: revert the refactor.
async findById(id: UserId): Promise<User | null> {
  return this.users.find(u => u.id === id) ?? null;
}
```

---

## The Prove-It Pattern (Bug Fixes)

Every bug fix starts with a test that reproduces the bug:

```
1. Write a test that demonstrates the bug (it must fail — RED)
2. Verify the test fails for the right reason (bug, not test error)
3. Fix the code (GREEN)
4. Verify the test passes
5. Run full test suite — no regressions

NEVER fix a bug without a test first.
If you "fix" it without a test, the bug will return.
```

---

## Test Pyramid

| Level | Coverage | Speed | Count |
|-------|----------|-------|-------|
| **Unit** | One function/module | <10ms | 80% |
| **Integration** | Multiple components together | <500ms | 15% |
| **E2E** | Full stack, real browser | >1s | 5% |

Most tests should be unit tests. E2E tests are expensive and brittle — use sparingly for critical paths only.

---

## Mocks vs Stubs vs Fakes

| Type | What | When |
|------|------|------|
| **Stub** | Returns fixed values | When you don't care about interactions |
| **Mock** | Verifies interactions | When the call itself matters (emails sent, events fired) |
| **Fake** | Working implementation (InMemory) | When you need realistic behavior without I/O |
| **Spy** | Records real calls | When you want to observe without replacing |

```typescript
// Stub: fixed return value
const emailService = { send: jest.fn().mockResolvedValue(undefined) };

// Mock: verifies the call happened
expect(emailService.send).toHaveBeenCalledWith(
  'user@example.com',
  'Task created'
);

// Fake: realistic in-memory implementation
class InMemoryTaskRepository implements TaskRepository {
  private tasks: Task[] = [];
  async save(task: Task) { this.tasks.push(task); }
  async findById(id: string) { return this.tasks.find(t => t.id === id) ?? null; }
}
```

**Rule — Mock at Boundaries Only:**

| Layer | Test Double | Why |
|-------|-------------|-----|
| Databases / repositories | Fake (in-memory) | Not a boundary — internal infrastructure |
| External APIs | Mock or Fake client | Boundary — controls are external |
| Email / SMS / push | Mock | Boundary — verify the send happened |
| File system | Fake (in-memory FS) | Not a boundary — implementation detail |
| Internal modules | Real implementation | Not a boundary — use the real thing |

Mock at the boundary of your system. Never mock your own domain objects.

---

## Test Structure (AAA Pattern)

**Test naming:** `[unit] should [behavior] when [condition]`
Examples: `createUser should throw when email is duplicate`, `calculateTax should return 0 when subtotal is 0`

```typescript
it('calculateTax should return 8.00 when subtotal is 100 and rate is 8%', () => {
  // Arrange
  const subtotal = 100.00;
  const taxRate = 0.08;

  // Act
  const tax = calculateTax(subtotal, taxRate);

  // Assert
  expect(tax).toBeCloseTo(8.00, 2);
});
```

Each test: one behavior, one assertion cluster. If the test name contains "and", split it.

---

## Test Coverage Requirements

| Code Type | Minimum Coverage |
|-----------|-----------------|
| Business logic / domain | 90%+ |
| API handlers | 80%+ |
| Utility functions | 90%+ |
| UI components | 70%+ |
| Infrastructure adapters | 60%+ |

**Coverage is a floor, not a goal.** 90% coverage with weak tests is worse than 70% with strong tests.

### Mutation Testing

Verify that your tests actually catch bugs:

```bash
# Install and run stryker (JavaScript)
npx stryker run

# Or jest-mutating
npx jest-mutating --testPathPattern="src/domain/**"
```

**Mutation score:** % of inserted bugs caught by tests. Target >70%.

If a mutant survives (test didn't catch the bug), either:
1. Add a test case that would fail with the mutant
2. Accept the gap (not all code paths need testing)

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Writing code before tests | Delete the code. Start with RED. |
| Tests that never fail | Verify RED before writing GREEN |
| Testing implementation details | Test behavior (what), not internals (how) |
| Mocking everything | Use Fakes for storage; only Mock side effects |
| One giant test | One test per behavior, AAA structure |
| Skipping refactor step | Technical debt accumulates without refactor phase |
| Ignoring mutation score | Coverage without mutation testing = false confidence |

## Verification Checklist

- [ ] Tests written BEFORE production code (RED seen for each test)
- [ ] Each test: one behavior, descriptive name (`does X when Y`)
- [ ] Happy path, empty/null, boundary, and error cases covered
- [ ] Fakes used for repositories; mocks only for verified side effects
- [ ] AAA structure in each test (Arrange, Act, Assert)
- [ ] No test depends on another test (order-independent)
- [ ] Mutation score >70% for business logic
- [ ] Bug fixes include a reproducing test (Prove-It Pattern)
- [ ] Full test suite green after refactor step
