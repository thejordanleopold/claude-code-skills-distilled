---
name: e2e-testing
description: "Use when writing end-to-end tests, browser automation with Playwright, integration tests hitting real databases, API integration testing, testing complete user flows, managing test data lifecycle, or applying property-based testing. Triggers: \"e2e test\", \"end-to-end\", \"Playwright\", \"browser test\", \"integration test\", \"user flow test\", \"API test\", \"test data\", \"Cypress\", \"property-based testing\", \"fuzz testing\"."
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

Test invariants over large random input spaces using `fast-check`. Write one `fc.assert(fc.property(arbitraries, (input) => invariant))` per property. Use when: input validation, parsing/serialization, mathematical invariants. Target: `calculateTax` always returns `>= 0`; JSON round-trip preserves all fields; sort is idempotent.

---

## API Mocking with page.route()

Use `page.route()` to intercept API calls — avoids real network I/O in E2E tests:

```typescript
test('shows error banner on API failure', async ({ page }) => {
  // Intercept before navigating
  await page.route('**/api/tasks', route =>
    route.fulfill({ status: 500, body: JSON.stringify({ error: 'Server error' }) })
  );

  await page.goto('/tasks');
  await expect(page.locator('[data-testid="error-banner"]')).toBeVisible();
});
```

Use when: testing error states, slow-network scenarios, or avoiding rate limits in CI.

---

## Accessibility Testing

```typescript
import AxeBuilder from '@axe-core/playwright';

test('checkout flow is accessible', async ({ page }) => {
  await page.goto('/checkout');

  const results = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa'])
    .analyze();

  expect(results.violations).toEqual([]);
});
```

Run axe on every critical flow. Violations include ARIA errors, contrast failures, and missing labels. Pair with WCAG 2.1 AA from the ui-components skill.

---

## Auth State Reuse

```typescript
// Save auth once, reuse across tests (avoids re-logging in each time)
setup('authenticate', async ({ page }) => {
  await page.goto('/login');
  await page.fill('[name=email]', 'test@example.com');
  await page.fill('[name=password]', 'password');
  await page.click('[type=submit]');
  await page.context().storageState({ path: 'tests/.auth/user.json' });
});

test.use({ storageState: 'tests/.auth/user.json' });
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
