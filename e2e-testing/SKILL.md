---
name: e2e-testing
description: |
  Use when writing end-to-end tests, browser automation with Playwright, integration tests
  hitting real databases, API integration testing, testing complete user flows, managing test
  data lifecycle, or applying property-based testing. Triggers: "e2e test", "end-to-end",
  "Playwright", "browser test", "integration test", "user flow test", "API test", "test data",
  "Cypress", "property-based testing", "fuzz testing".
---

# E2E and Integration Testing

End-to-end browser testing and integration testing for complete user flows.

**Core principle:** E2E tests verify real behavior in a real environment. They are expensive to write and maintain — use them only for critical paths.

## When to Use

- Testing complete user flows (login → create → verify)
- Browser automation with Playwright or Cypress
- API integration tests hitting a real test database
- Property-based testing for complex input spaces

## When NOT to Use

- Unit testing individual functions (use tdd skill)
- Performance testing (use frontend/backend-performance skills)
- Visual regression testing in isolation (different toolchain)

---

## Test Pyramid Position

| Level | Use E2E For | Count |
|-------|------------|-------|
| **E2E** | Critical user flows, smoke tests | 5% |
| **Integration** | API endpoints, DB queries, multi-service | 15% |
| **Unit** | Business logic, functions, modules | 80% |

E2E tests are slow, brittle, and expensive. Cover the 3-5 most critical flows. Everything else: unit and integration.

---

## Playwright Setup

```typescript
// playwright.config.ts
import { PlaywrightTestConfig } from '@playwright/test';

const config: PlaywrightTestConfig = {
  testDir: './tests/e2e',
  timeout: 30_000,
  retries: process.env.CI ? 2 : 0,
  use: {
    baseURL: process.env.TEST_BASE_URL || 'http://localhost:3000',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    trace: 'retain-on-failure',
  },
  projects: [
    { name: 'chromium', use: { browserName: 'chromium' } },
    { name: 'firefox', use: { browserName: 'firefox' } },
  ],
};

export default config;
```

---

## Page Object Model

Abstract browser interactions from test logic:

```typescript
// pages/TaskPage.ts
export class TaskPage {
  constructor(private page: Page) {}

  async goto() {
    await this.page.goto('/tasks');
  }

  async createTask(title: string, dueDate?: string) {
    await this.page.click('[data-testid="create-task-btn"]');
    await this.page.fill('[data-testid="task-title"]', title);
    if (dueDate) await this.page.fill('[data-testid="due-date"]', dueDate);
    await this.page.click('[data-testid="submit-task"]');
  }

  async getTaskTitles(): Promise<string[]> {
    return this.page.locator('[data-testid="task-title"]').allTextContents();
  }

  async waitForTaskVisible(title: string) {
    await this.page.waitForSelector(`text="${title}"`);
  }
}

// tests/e2e/tasks.spec.ts
test('user can create and view a task', async ({ page }) => {
  const taskPage = new TaskPage(page);
  await taskPage.goto();
  await taskPage.createTask('Write documentation');
  await taskPage.waitForTaskVisible('Write documentation');
  
  const titles = await taskPage.getTaskTitles();
  expect(titles).toContain('Write documentation');
});
```

---

## Selector Strategy

| Priority | Selector | Why |
|----------|---------|-----|
| **1st choice** | `data-testid="create-btn"` | Stable, intent-revealing, not coupled to style |
| **2nd choice** | ARIA role: `getByRole('button', { name: 'Create' })` | Semantic, accessible |
| **3rd choice** | Text: `getByText('Submit')` | Readable but brittle if text changes |
| **Avoid** | CSS class: `.btn-primary` | Breaks on style refactor |
| **Never** | XPath | Fragile, unreadable |

Add `data-testid` attributes in production code for test stability.

---

## Test Data Management

### Lifecycle Rules

```typescript
// Use beforeEach for clean state
test.beforeEach(async ({ request }) => {
  await request.post('/test/reset-db');  // Reset to known state
});

// Or use database transactions (rollback after each test)
test.beforeEach(async () => {
  await db.beginTransaction();
});

test.afterEach(async () => {
  await db.rollback();
});
```

### Data Builders

```typescript
// builder pattern for test data
function buildTask(overrides: Partial<Task> = {}): Task {
  return {
    id: 'task-' + Math.random().toString(36).slice(2),
    title: 'Default Task',
    status: 'pending',
    userId: 'user-123',
    createdAt: new Date(),
    ...overrides,
  };
}

// Use in tests
const task = buildTask({ title: 'My specific task', status: 'complete' });
```

**Rules:**
- Each test creates its own data — never share mutable state between tests
- Clean up after (or before) each test
- Never use production data in tests
- Realistic but not real (fake names, emails, etc.)

---

## API Integration Testing

Test the full HTTP stack against a real test database:

```typescript
// tests/integration/tasks.test.ts
describe('POST /api/tasks', () => {
  beforeEach(async () => {
    await db.migrate.latest();
    await db('tasks').delete();
  });

  it('creates a task and returns 201', async () => {
    const response = await request(app)
      .post('/api/tasks')
      .set('Authorization', `Bearer ${testToken}`)
      .send({ title: 'New task', userId: 'user-123' });

    expect(response.status).toBe(201);
    expect(response.body.data.title).toBe('New task');
    expect(response.headers.location).toMatch(/\/api\/tasks\/.+/);
  });

  it('returns 422 when title is missing', async () => {
    const response = await request(app)
      .post('/api/tasks')
      .set('Authorization', `Bearer ${testToken}`)
      .send({});

    expect(response.status).toBe(422);
    expect(response.body.error.code).toBe('VALIDATION_ERROR');
  });
});
```

---

## Property-Based Testing

Test invariants over large random input spaces:

```typescript
import fc from 'fast-check';

// Property: calculateTax(subtotal, rate) is always non-negative
test('tax is never negative', () => {
  fc.assert(
    fc.property(
      fc.float({ min: 0 }),   // any non-negative subtotal
      fc.float({ min: 0, max: 1 }),  // any rate 0-100%
      (subtotal, rate) => {
        const tax = calculateTax(subtotal, rate);
        return tax >= 0;
      }
    )
  );
});

// Property: parsing and serializing is lossless
test('JSON round-trip preserves task', () => {
  fc.assert(
    fc.property(
      fc.record({ title: fc.string(), status: fc.constantFrom('pending', 'done') }),
      (task) => {
        const serialized = JSON.stringify(task);
        const parsed = JSON.parse(serialized);
        return parsed.title === task.title && parsed.status === task.status;
      }
    )
  );
});
```

Use when: complex input validation, parsing/serialization, mathematical invariants, data transformations.

---

## Browser Security Boundaries

Playwright tests run with real browser security:

```typescript
// Cross-origin requests: configure CORS in test environment
// Cookies: use context.addCookies() not document.cookie
// localStorage: use page.evaluate() or page.addInitScript()
// Auth: use storageState to reuse authenticated sessions

// Save auth state once, reuse across tests (faster than re-logging in)
const authFile = 'tests/.auth/user.json';
setup('authenticate', async ({ page }) => {
  await page.goto('/login');
  await page.fill('[name=email]', 'test@example.com');
  await page.fill('[name=password]', 'password');
  await page.click('[type=submit]');
  await page.context().storageState({ path: authFile });
});

// In tests:
test.use({ storageState: authFile });
```

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Too many E2E tests | Unit test the logic; E2E only for critical flows |
| Shared mutable test data | Each test creates its own data, cleans up after |
| CSS class selectors | Use `data-testid` or ARIA roles |
| Hard-coded wait times (`wait 2000ms`) | Use `waitForSelector` or `waitForResponse` |
| Tests that pass in isolation but fail in sequence | Clean DB state before each test |
| No retries in CI | Set `retries: 2` in CI environment |

## Verification Checklist

- [ ] E2E tests cover the 3-5 most critical user flows only
- [ ] Page Object Model separates selectors from assertions
- [ ] All selectors use `data-testid` or ARIA roles
- [ ] Test data created fresh before each test, cleaned after
- [ ] No `page.waitForTimeout()` — use event-based waits
- [ ] Auth state reused across tests (not re-logging in each time)
- [ ] CI retries configured (`retries: 2`)
- [ ] Screenshots and traces captured on failure
- [ ] Property-based tests for complex input validation
