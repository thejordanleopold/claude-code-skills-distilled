---
name: database-design
description: |
  Use when designing relational database schemas from requirements, normalizing existing schemas,
  planning zero-downtime migrations for large tables, implementing multi-tenancy patterns,
  designing audit trails or soft-delete strategies, configuring row-level security (RLS),
  planning index strategies, or generating TypeScript/Python types from schema. Use for schema
  normalization, relationship design, migration planning, index optimization, and data integrity.
---

# Database Design

Production-quality relational database design: schema, migrations, indexing, security, and multi-tenancy.

**Core principle:** Get the schema right before the application. Fixing schema design after data accumulates is expensive and risky.

## When to Use

- Designing tables for a new feature
- Reviewing a schema for normalization or performance problems
- Planning zero-downtime migrations on large tables
- Adding multi-tenancy to a single-tenant schema
- Implementing audit trails, soft deletes, or row-level security
- Choosing index strategy for slow queries

## When NOT to Use

- Writing application-level SQL queries (use sql-assistant)
- ORM configuration only
- NoSQL database design (different skill domain)

---

## Schema Design Fundamentals

### Normalization

**Goal:** Aim for 3NF by default. Denormalize only with measured justification.

- **1NF:** No repeating groups — atomic column values, unique rows
- **2NF:** All non-key columns depend on the entire primary key
- **3NF:** No transitive dependencies between non-key columns

### Data Type Choices

| Concept | Use | Avoid |
|---------|-----|-------|
| Primary keys | UUID/CUID (opaque, immutable) | Sequential integers (leaks count) |
| Money | `DECIMAL(19,4)` or integer cents | `FLOAT` (rounding errors) |
| Timestamps | `TIMESTAMPTZ` (timezone-aware) | `DATE` unless time is irrelevant |
| Enums | `CHECK` constraint + `VARCHAR`, or native enum | Free text (inconsistent values) |
| JSON blobs | `JSONB` in PostgreSQL (indexed) | `TEXT` or `VARCHAR` |
| Booleans | Native `BOOLEAN` | `0`/`1` without constraint |

---

## Core Design Patterns

### Soft Deletes

```sql
CREATE TABLE users (
  id        UUID PRIMARY KEY,
  email     VARCHAR(255) NOT NULL,
  deleted_at TIMESTAMPTZ,          -- NULL = active
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Always filter deleted in queries
SELECT * FROM users WHERE deleted_at IS NULL;

-- Partial index for performance
CREATE INDEX idx_users_active ON users(email) WHERE deleted_at IS NULL;
```

### Audit Trail

```sql
-- Lightweight: who/when on every table
created_by_id UUID NOT NULL REFERENCES users(id),
updated_by_id UUID NOT NULL REFERENCES users(id),
created_at    TIMESTAMPTZ DEFAULT NOW(),
updated_at    TIMESTAMPTZ DEFAULT NOW()

-- Full history: separate audit log table
CREATE TABLE task_audit_log (
  id          UUID PRIMARY KEY,
  task_id     UUID NOT NULL REFERENCES tasks(id),
  operation   VARCHAR(10),          -- INSERT, UPDATE, DELETE
  before_data JSONB,
  after_data  JSONB,
  changed_by  UUID NOT NULL REFERENCES users(id),
  changed_at  TIMESTAMPTZ DEFAULT NOW()
);
```

### Multi-Tenancy

Add `organization_id` to all tenant-scoped tables. Denormalize it (even into child tables) so RLS policies can be simple.

```sql
CREATE TABLE projects (
  id              UUID PRIMARY KEY,
  organization_id UUID NOT NULL REFERENCES organizations(id),
  name            VARCHAR(255) NOT NULL,
  UNIQUE(organization_id, name)  -- Scoped uniqueness
);

CREATE TABLE tasks (
  id              UUID PRIMARY KEY,
  organization_id UUID NOT NULL REFERENCES organizations(id),  -- denormalized
  project_id      UUID NOT NULL REFERENCES projects(id),
  title           VARCHAR(255)
);
```

### Optimistic Locking (Concurrent Updates)

```sql
CREATE TABLE accounts (
  id      UUID PRIMARY KEY,
  balance DECIMAL(19,2),
  version INT DEFAULT 1
);

-- Update only succeeds if version matches
UPDATE accounts
SET balance = balance - 100, version = version + 1
WHERE id = $1 AND version = $2;
-- If rows_affected == 0: conflict detected → retry
```

---

## Migration Planning

### Zero-Downtime: Expand-Contract Pattern

Never rename a column or change a type in one step on a live system.

```
Phase 1 (Expand):   Add new column alongside old — no downtime
Phase 2 (Backfill): Migrate data in batches of 5,000 rows
Phase 3 (Dual-write): App writes both old + new columns
Phase 4 (Cutover):  App reads new column only — deploy
Phase 5 (Contract): Drop old column after 48h stability
```

**Batch backfill (avoids table locks):**
```sql
UPDATE users SET full_name = name
WHERE id IN (SELECT id FROM users WHERE full_name IS NULL LIMIT 5000);
-- Repeat until: SELECT COUNT(*) FROM users WHERE full_name IS NULL = 0
```

### Migration Checklist

**Before:**
- [ ] Rollback script tested in staging
- [ ] Backup taken and restore verified
- [ ] Table size checked (large table → more careful approach)
- [ ] Lock contention plan (NOWAIT or statement_timeout)

**After:**
- [ ] All constraints in place
- [ ] Indexes created successfully
- [ ] `ANALYZE` run to update query planner statistics
- [ ] EXPLAIN plan confirms indexes are being used

---

## Index Strategy

### Decision Matrix

| Query Pattern | Index Type |
|--------------|-----------|
| `WHERE email = ?` | Single-column B-tree |
| `WHERE org_id = ? AND status = ?` | Composite B-tree (most selective first) |
| `WHERE deleted_at IS NULL` | Partial index |
| `WHERE created_at BETWEEN ? AND ?` | B-tree range |
| Full-text search | GIN (`to_tsvector`) |
| `SELECT id, name` without table lookup | Covering index with `INCLUDE` |

### Reading EXPLAIN Plans

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders WHERE customer_id = 123;
```

| Signal | Meaning | Action |
|--------|---------|--------|
| `Seq Scan` on large table | Missing index | Add index |
| `Nested Loop` with 1M+ rows | Missing join index | Add FK index |
| High `Buffers: reads` | Data not cached | Tune shared_buffers or query |
| Low `Buffers: hits` ratio | Cold cache | Normal on first run |

### Index Anti-Patterns

- Over-indexing (15+ indexes per table → slow writes)
- Foreign keys without indexes (slow JOINs and cascades)
- Redundant indexes (col1,col2) AND (col1) — second is redundant
- Non-sargable predicates: `WHERE YEAR(created_at) = 2025` (can't use index)

---

## Row-Level Security (RLS)

Enforce multi-tenancy at the database layer — defense-in-depth against application bugs.

```sql
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

-- Users see only their org's tasks
CREATE POLICY tasks_org_isolation ON tasks
  FOR ALL TO app_user
  USING (
    organization_id IN (
      SELECT organization_id FROM organization_members
      WHERE user_id = current_setting('app.current_user_id')::uuid
    )
  );

-- Soft-delete filter
CREATE POLICY tasks_no_deleted ON tasks
  FOR SELECT TO app_user
  USING (deleted_at IS NULL);

-- Set per-request context
SELECT set_config('app.current_user_id', $1, true);
```

**Critical:** Test RLS with a non-superuser role. Superuser bypasses all RLS policies.

---

## Type Generation

Derive TypeScript/Python types from schema to stay in sync:

```typescript
// Prisma schema → TypeScript types (auto-generated)
model Task {
  id             String    @id @default(cuid())
  organizationId String
  title          String
  deletedAt      DateTime?
  createdAt      DateTime  @default(now())
}
// Generates: type Task = { id: string; organizationId: string; ... }
```

---

## Common Mistakes

| Mistake | Impact |
|---------|--------|
| FK columns without indexes | Slow JOINs and cascade operations |
| Soft delete without partial index | Full table scan on every query |
| Mutable surrogate keys (email as PK) | Cascading updates across all FKs |
| `NOT NULL` column added without default | Breaks existing INSERT statements |
| No optimistic locking | Silent data loss from concurrent updates |
| RLS not tested with app_user role | Superuser bypasses policies — false safety |
| Sequential integer PKs | Leaks business data (user count, order volume) |
| Money stored as FLOAT | Rounding errors in financial calculations |

## Verification Checklist

- [ ] All tables have UUID/CUID primary keys
- [ ] All foreign key columns have indexes
- [ ] Schema normalized to 3NF (or denormalization justified)
- [ ] NOT NULL, UNIQUE, CHECK, FK constraints in place
- [ ] `created_at`, `updated_at` on all tables
- [ ] Soft delete pattern if data needs to be recoverable
- [ ] Audit trail for regulated domains
- [ ] `organization_id` on all tenant-scoped tables
- [ ] RLS policies tested with non-superuser role
- [ ] Partial indexes for soft-delete filters
- [ ] EXPLAIN plans show index usage on common queries
- [ ] Zero-downtime migration pattern for large table changes
- [ ] TypeScript/Python types generated from schema
