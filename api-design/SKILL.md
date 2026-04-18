---
name: api-design
description: "Use when designing APIs, defining interfaces, choosing between REST and alternatives, applying Hyrum's Law, designing resilience patterns (circuit breaker, retry with backoff, health checks), writing API contracts, or reviewing API design for consistency and correctness. Triggers: \"design an API\", \"API design\", \"REST API\", \"interface design\", \"HTTP endpoints\", \"contract-first\", \"Hyrum's Law\", \"circuit breaker\", \"retry logic\", \"health check endpoint\"."
---

# API Design

Contract-first interface design with REST conventions, resilience patterns, and Hyrum's Law awareness.

**Core principle:** Every behavior you expose becomes a contract. Design the smallest observable surface area you're willing to support forever.

## When to Use

- Designing new API endpoints
- Designing function/class interfaces
- Adding resilience (circuit breaker, retry) to service calls
- Reviewing API design for consistency
- Writing health check endpoints

## When NOT to Use

- Database schema design (use database-design skill)
- System-level architectural decisions (use system-design skill)

---

## Contract-First Design

Define the interface before implementing it:

```typescript
// Step 1: Define the contract
interface TaskRepository {
  findById(id: TaskId): Promise<Task | null>;
  save(task: Task): Promise<void>;
  delete(id: TaskId): Promise<void>;
  findByUser(userId: UserId, options?: QueryOptions): Promise<Task[]>;
}

// Step 2: Implement for production
class PostgresTaskRepository implements TaskRepository { ... }

// Step 3: Implement for tests
class InMemoryTaskRepository implements TaskRepository { ... }
```

**Why:** Forces you to think from the caller's perspective before the implementer's.

---

## REST Conventions

### URL Structure

```
Collections:  GET    /tasks          — list
              POST   /tasks          — create

Resources:    GET    /tasks/:id      — read
              PUT    /tasks/:id      — replace (all fields)
              PATCH  /tasks/:id      — partial update
              DELETE /tasks/:id      — delete

Nested:       GET    /users/:id/tasks — tasks owned by user
```

**Rules:**
- Plural nouns for collections (`/tasks` not `/task`)
- Never verbs in URLs (`/tasks` not `/getTasks`)
- Nested resources for ownership (`/users/:id/tasks`)
- Query params for filtering, sorting, pagination — never in body

### HTTP Status Codes

| Code | When |
|------|------|
| 200 OK | Successful GET, PATCH, PUT |
| 201 Created | Successful POST (include `Location` header) |
| 204 No Content | Successful DELETE |
| 400 Bad Request | Malformed request, invalid JSON |
| 401 Unauthorized | Missing or invalid authentication |
| 403 Forbidden | Authenticated but not authorized |
| 404 Not Found | Resource doesn't exist |
| 409 Conflict | State conflict (duplicate, version mismatch) |
| 422 Unprocessable | Valid JSON but fails business validation |
| 429 Too Many Requests | Rate limit exceeded |
| 500 Internal Server Error | Unexpected server error |
| 503 Service Unavailable | Dependency down, circuit open |

### Request/Response Shape

```typescript
// List response: always paginated
GET /tasks?status=pending&limit=20&cursor=abc123
{
  "data": [...],
  "pagination": {
    "cursor": "xyz789",
    "hasMore": true,
    "total": 142
  }
}

// Error response: consistent shape
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Title is required",
    "field": "title"
  }
}
```

---

## Hyrum's Law

> "With a sufficient number of users of an API, all observable behaviors will be depended on by somebody."

**Implications for design:**

| Behavior | Risk |
|---------|------|
| Adding validation (rejecting inputs you previously accepted) | Breaking change |
| Changing error message text | Breaking for code that parses messages |
| Changing response field order | Breaking for code that assumes order |
| Adding a new required field | Breaking for code that doesn't send it |
| Changing response time characteristics | Breaking for code with timing dependencies |

**Practice:** Before exposing any behavior, ask: "Am I willing to support this forever?"

### Designing the Smallest Surface

- Accept the most general type, return the most specific
- Use opaque IDs (strings) not sequential integers
- Version your API from day one (`/v1/tasks`)
- Never remove fields — deprecate and maintain
- Document what you guarantee, not what happens to work

---

## Interface Design Rules

| Rule | Example |
|------|---------|
| Accept most general, return most specific | Accept `string`, return `UserId` |
| Fail fast at boundaries | Validate at entry points, trust internal code |
| No boolean parameters | `render(true, false)` → `render({ visible: true, modal: false })` |
| One thing per function | If name contains "and", split it |
| Max 4 parameters | More → options object |
| Consistent return types | Don't return `User` sometimes and `null` other times for same method |

---

## Resilience Patterns

### Circuit Breaker

Stops cascading failures when a dependency is down:

```typescript
class CircuitBreaker {
  private failures = 0;
  private lastFailure?: Date;
  private state: 'CLOSED' | 'OPEN' | 'HALF_OPEN' = 'CLOSED';

  constructor(private threshold = 5, private timeoutMs = 30_000) {}

  async call<T>(fn: () => Promise<T>): Promise<T> {
    if (this.state === 'OPEN') {
      const elapsed = Date.now() - this.lastFailure!.getTime();
      if (elapsed < this.timeoutMs) throw new CircuitOpenError();
      this.state = 'HALF_OPEN';
    }
    try {
      const result = await fn();
      this.failures = 0;
      this.state = 'CLOSED';
      return result;
    } catch (err) {
      this.failures++;
      this.lastFailure = new Date();
      if (this.failures >= this.threshold) this.state = 'OPEN';
      throw err;
    }
  }
}
```

### Retry with Exponential Backoff

```typescript
async function withRetry<T>(
  fn: () => Promise<T>,
  { maxAttempts = 3, baseDelayMs = 100, maxDelayMs = 5000 } = {}
): Promise<T> {
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (err) {
      if (attempt === maxAttempts) throw err;
      const jitter = Math.random() * 100;
      const delay = Math.min(baseDelayMs * 2 ** (attempt - 1) + jitter, maxDelayMs);
      await new Promise(r => setTimeout(r, delay));
    }
  }
  throw new Error('Unreachable');
}
```

**Retry only for:** Network timeout, 429 (rate limit), 503 (unavailable).
**Never retry:** 400, 401, 403, 404, 422 (these won't change on retry).

### Health Check Endpoint

Every service must expose `/health`:

```typescript
app.get('/health', async (req, res) => {
  const checks = await Promise.allSettled([
    db.query('SELECT 1').then(() => ({ status: 'ok' })),
    redis.ping().then(() => ({ status: 'ok' })),
  ]);

  const results = {
    database: checks[0].status === 'fulfilled' ? 'ok' : 'error',
    cache: checks[1].status === 'fulfilled' ? 'ok' : 'error',
  };

  const healthy = Object.values(results).every(v => v === 'ok');
  res.status(healthy ? 200 : 503).json({
    status: healthy ? 'ok' : 'degraded',
    checks: results,
    timestamp: new Date().toISOString(),
    version: process.env.APP_VERSION,
  });
});
```

---

## Verification Checklist

**REST:**
- [ ] URLs use plural nouns, no verbs
- [ ] HTTP status codes match semantics
- [ ] List endpoints are paginated with cursor/limit
- [ ] Error responses have consistent shape with `code`, `message`
- [ ] Breaking changes are versioned (`/v2/`)

**Interface design:**
- [ ] Contract defined before implementation
- [ ] Parameters ≤ 4 (or options object)
- [ ] No boolean parameters
- [ ] Single responsibility per function
- [ ] Test implementation (InMemory/Fake) exists alongside production implementation

**Resilience:**
- [ ] Circuit breaker on all external service calls
- [ ] Retry only on transient errors (not 4xx)
- [ ] Health check endpoint at `/health` with dependency checks
- [ ] Timeouts set on all outbound requests

**Hyrum's Law:**
- [ ] No sequential integer IDs exposed externally
- [ ] Versioning strategy defined from day one
- [ ] Only behaviors you intend to maintain are documented
