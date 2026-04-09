---
name: backend-performance
description: |
  Use when diagnosing slow API responses, fixing N+1 query problems, optimizing database
  queries, adding indexes, debugging memory leaks, profiling server-side code, setting API
  latency budgets, or detecting performance regressions. Triggers: "slow API", "slow query",
  "N+1", "database performance", "N+1 queries", "memory leak", "backend performance",
  "profiling", "API latency", "EXPLAIN plan", "missing index", "unbounded fetch".
---

# Backend Performance

Measure, diagnose, and fix server-side performance: database queries, API latency, memory leaks.

**Core principle:** Measure the specific path. "The API is slow" is not a diagnosis. "The GET /tasks endpoint at p95 is 2.3s due to an N+1 query on task.assignee" is.

## When to Use

- API endpoint latency is unacceptably high
- Database queries are slow or timing out
- Memory usage grows without bound
- Suspecting N+1 queries or missing indexes
- Setting latency budgets and regression detection

## When NOT to Use

- Frontend/browser performance (use frontend-performance skill)
- Initial development without any measured problem
- Premature optimization (measure first)

---

## Measurement First

### Establish Baseline

Before any change, record:
- Metric value at p50, p95, p99
- Measurement method (tool, sample size, date, commit hash)

After optimization, compare with the same method.

### Diagnosis Decision Tree

```
API is slow
  |
  ├── WHERE is the time spent?
  │     ├── Database queries → EXPLAIN plan, slow query log
  │     ├── External API calls → tracing, timeout analysis
  │     ├── CPU computation → profiling tool
  │     └── Memory pressure / GC → heap profiling
  |
  ├── WHAT is the specific number? (p95 = 2.3s)
  |
  └── FIX the specific root cause → measure again
```

---

## Profiling Tools

| Language | Tool | What It Shows |
|----------|------|--------------|
| Node.js | `--prof` + `node --prof-process` | V8 CPU sampling flamegraph |
| Node.js | Clinic.js (`clinic doctor`) | CPU, memory, event loop lag |
| Python | `cProfile` + `snakeviz` | Function call time |
| Go | `pprof` | CPU, heap, goroutine stacks |
| Java | async-profiler | CPU, memory, locks |
| Ruby | `stackprof` | CPU sampling |

---

## Database Query Optimization

### Reading EXPLAIN Plans (PostgreSQL)

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT t.*, u.name FROM tasks t JOIN users u ON t.user_id = u.id
WHERE t.org_id = $1 AND t.status = 'pending';
```

| Signal | Problem | Fix |
|--------|---------|-----|
| `Seq Scan` on large table | Missing index | Add index |
| `Nested Loop` with 1M+ rows | Missing FK index | Add index on join column |
| High `Buffers: reads` vs `hits` | Cold cache or too much data | Tune query, add index, add cache |
| `Filter` removing many rows | Index not selective enough | Composite index |

### Finding Slow Queries

```sql
-- PostgreSQL: top slow queries
SELECT query, mean_exec_time, calls, total_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 20;

-- Enable slow query log (MySQL)
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 0.5;  -- log queries > 500ms
```

---

## N+1 Query Problem

### Detection

```
// N+1 pattern: 1 query + N queries
// Log: SELECT * FROM tasks (1 query)
//      SELECT * FROM users WHERE id = 1
//      SELECT * FROM users WHERE id = 2
//      ... (N more queries)
```

### Fix: Eager Loading

```typescript
// N+1: separate query per task
const tasks = await Task.findAll();
for (const task of tasks) {
  task.user = await User.findById(task.userId);  // N queries!
}

// Fix: single JOIN query
const tasks = await Task.findAll({
  include: [{ model: User }],  // 1 query with JOIN
});
```

### Fix: DataLoader (Batching)

```typescript
import DataLoader from 'dataloader';

const userLoader = new DataLoader(async (ids: readonly string[]) => {
  const users = await User.findAll({ where: { id: [...ids] } });
  return ids.map(id => users.find(u => u.id === id) ?? null);
});

// Now batched automatically: 1 query for N users
const user = await userLoader.load(task.userId);
```

---

## Index Strategy

### When to Add an Index

Add an index on any column that appears in:
- `WHERE` clause on tables with >10k rows
- `JOIN ON` (always index foreign keys)
- `ORDER BY` (for avoiding filesort)
- `GROUP BY` (for covering the group)

```sql
-- Foreign key index (add if missing)
CREATE INDEX idx_tasks_user_id ON tasks(user_id);

-- Composite index for multi-column WHERE
CREATE INDEX idx_tasks_org_status ON tasks(org_id, status);

-- Partial index for soft-delete pattern
CREATE INDEX idx_tasks_active ON tasks(id) WHERE deleted_at IS NULL;
```

### Index Anti-Patterns

- Over-indexing: >15 indexes on one table (slow writes)
- Indexing low-cardinality columns (boolean, status with 2 values — check selectivity)
- Non-sargable predicates: `WHERE YEAR(created_at) = 2025` (can't use index)

---

## Unbounded Data Fetches

```typescript
// DANGEROUS: fetches entire table
const tasks = await Task.findAll();

// SAFE: always paginate
const tasks = await Task.findAll({
  where: { orgId },
  limit: Math.min(Number(req.query.limit) || 20, 100),
  offset: (Number(req.query.page) || 0) * limit,
  order: [['createdAt', 'DESC']],
});
```

**Rule:** Every list query needs a `LIMIT`. Max limit should be enforced server-side (not just relied on from client).

---

## Memory Leak Detection

### Indicators

- Heap grows monotonically over hours (not just during traffic spikes)
- GC runs more frequently but reclaims less over time
- RSS keeps growing after traffic drops

### Profiling

```javascript
// Node.js: track heap over time
setInterval(() => {
  const { heapUsed, heapTotal, rss } = process.memoryUsage();
  console.log({
    heapUsed: Math.round(heapUsed / 1024 / 1024) + 'MB',
    heapTotal: Math.round(heapTotal / 1024 / 1024) + 'MB',
    rss: Math.round(rss / 1024 / 1024) + 'MB',
  });
}, 30_000);
```

### Common Leak Sources

| Source | Pattern | Fix |
|--------|---------|-----|
| Event listeners | `emitter.on()` without `off()` | Always remove listeners in cleanup |
| Closures | Callback holding reference to large object | Release reference when done |
| Unbounded cache | `Map` or `{}` that grows forever | Use LRU cache with max size |
| Timers | `setInterval` without `clearInterval` | Always clear in cleanup/teardown |
| Circular references | Object A holds B, B holds A | Use WeakMap for back-references |

---

## API Latency Budgets

| Metric | Target | Alert |
|--------|--------|-------|
| p50 | < 100ms | > 200ms |
| p95 | < 500ms | > 1s |
| p99 | < 2s | > 5s |
| Error rate | < 0.1% | > 1% |

### Regression Detection

| Metric | Alert Threshold |
|--------|----------------|
| p95 latency | +50% vs baseline |
| Error rate | +2x baseline |
| Database query time | +100% vs baseline |
| Memory usage | +25% vs baseline sustained |

---

## Caching Strategy

```typescript
// Redis caching with TTL
async function getUser(id: string): Promise<User> {
  const cached = await redis.get(`user:${id}`);
  if (cached) return JSON.parse(cached);
  
  const user = await db.findUser(id);
  await redis.setex(`user:${id}`, 300, JSON.stringify(user));  // 5min TTL
  return user;
}
```

**Cache invalidation rules:**
- Invalidate on write, not on read
- TTL-based expiry as safety net
- Cache computed results, not raw DB results
- Never cache: user-specific auth state, sensitive PII without encryption

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Optimizing without measuring | Profile and measure first |
| N+1 without ORM eager loading | Use include/join or DataLoader |
| No pagination on list endpoints | Always add LIMIT, enforce max |
| Missing FK indexes | Every FK column needs an index |
| Caching everything | Cache computed/expensive data only |
| Ignoring GC pressure | Monitor heap growth, not just RSS |

## Verification Checklist

- [ ] p50/p95/p99 baselines recorded before optimization
- [ ] EXPLAIN plans reviewed for all slow queries (no Seq Scan on large tables)
- [ ] N+1 queries eliminated (DataLoader or eager loading)
- [ ] All list endpoints paginated with enforced max limit
- [ ] Foreign key columns indexed
- [ ] Memory usage stable over time (no monotonic growth)
- [ ] Latency budgets defined with alerting
- [ ] Cache implemented for expensive, frequently-read data
- [ ] Regression thresholds set (+50% p95 → alert)
