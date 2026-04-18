---
name: data-engineering
description: "Use when designing or building data pipelines, ETL/ELT workflows, or data infrastructure. Use when implementing data quality checks, schema validation, or deduplication. Use when modeling data for analytics (fact/dimension tables, star schema), setting up orchestration with Airflow or dbt, troubleshooting pipeline failures, or instrumenting analytics events. Triggers: \"data pipeline\", \"ETL\", \"ELT\", \"batch job\", \"streaming\", \"data quality\", \"dbt\", \"Airflow\", \"data model\", \"star schema\", \"analytics events\", \"event tracking\"."
---

# Data Engineering

Build reliable data pipelines with proven patterns for architecture, quality, modeling, and instrumentation.

**Core principle:** Pipelines fail silently. Instrument everything, validate at every boundary, and make failures loud and recoverable.

## When to Use

- Designing batch or streaming data pipelines
- Implementing data quality and validation frameworks
- Building dimensional models (star schema, fact/dimension tables)
- Setting up orchestration (Airflow, dbt, Dagster)
- Troubleshooting pipeline failures or late-arriving data
- Designing analytics event schemas

## When NOT to Use

- Simple CRUD database operations (use database-design skill)
- User-facing API design (use api-design skill)
- Real-time ML inference pipelines (specialized domain)

---

## Architecture Decisions

### Batch vs Streaming

| Criteria | Batch | Streaming |
|----------|-------|-----------|
| Latency | Hours to days | Seconds to minutes |
| Reprocessing | Re-run the job | Replay from event log |
| Complexity | Simpler for complex transforms | Higher operational overhead |
| Cost | Lower (scheduled compute) | Higher (always-on infra) |
| Use when | Reports, daily aggregations, ML training | Fraud detection, live dashboards, alerts |

**Default to batch.** Switch to streaming only when latency requirements genuinely demand it.

### Data Warehouse vs Lakehouse

| Approach | When |
|----------|------|
| **Data Warehouse** (Snowflake, BigQuery, Redshift) | Structured data, SQL-first, business reporting |
| **Lakehouse** (Delta Lake, Iceberg on S3) | Mixed structured/unstructured, ML workloads, high volume |

---

## ETL/ELT Patterns

### ELT (Modern Default)

Load raw data first, transform in the warehouse using SQL:

```sql
-- dbt model: marts/orders_daily.sql
WITH raw_orders AS (
  SELECT * FROM {{ ref('stg_orders') }}
  WHERE deleted_at IS NULL
),
daily_agg AS (
  SELECT
    DATE_TRUNC('day', created_at) AS order_date,
    COUNT(*) AS order_count,
    SUM(amount_cents) / 100.0 AS revenue
  FROM raw_orders
  GROUP BY 1
)
SELECT * FROM daily_agg
```

### Idempotent Batch Jobs

Every pipeline run must be safely re-runnable:

```python
def run_pipeline(date: str):
    # DELETE before INSERT — idempotent
    db.execute("DELETE FROM orders_daily WHERE order_date = %s", [date])
    
    rows = extract(date)
    transformed = [transform(r) for r in rows]
    db.executemany("INSERT INTO orders_daily VALUES (%s, %s, %s)", transformed)
    
    log.info(f"Loaded {len(transformed)} rows for {date}")
```

---

## Data Quality Framework

Validate at every boundary — never assume upstream data is clean.

### Validation Layers

```python
def validate_batch(df: pd.DataFrame, schema: dict) -> ValidationResult:
    errors = []
    
    # 1. Schema: expected columns present
    missing = set(schema['required_columns']) - set(df.columns)
    if missing:
        errors.append(f"Missing columns: {missing}")
    
    # 2. Nullability: no nulls in required fields
    for col in schema['not_null']:
        null_count = df[col].isnull().sum()
        if null_count > 0:
            errors.append(f"{col}: {null_count} unexpected nulls")
    
    # 3. Freshness: data isn't stale
    max_date = df['created_at'].max()
    if (datetime.now() - max_date).hours > 26:
        errors.append(f"Data is stale: last record at {max_date}")
    
    # 4. Volume: row count within expected range
    if not (schema['min_rows'] <= len(df) <= schema['max_rows']):
        errors.append(f"Row count {len(df)} outside expected range")
    
    return ValidationResult(passed=len(errors) == 0, errors=errors)
```

### Dead Letter Queue

Never lose records silently:

```python
def process_records(records):
    success, failed = [], []
    for record in records:
        try:
            result = transform_and_load(record)
            success.append(result)
        except Exception as e:
            failed.append({
                'record': record,
                'error': str(e),
                'timestamp': datetime.now().isoformat(),
                'pipeline': 'orders-etl',
            })
    
    if failed:
        dead_letter_queue.send_batch(failed)
        alert(f"{len(failed)} records failed — sent to DLQ")
    
    return success
```

---

## Dimensional Modeling

### Star Schema

```sql
-- Fact table: one row per event, FK references to dimensions
CREATE TABLE fact_orders (
  order_id       UUID PRIMARY KEY,
  customer_key   INT REFERENCES dim_customers(customer_key),
  product_key    INT REFERENCES dim_products(product_key),
  date_key       INT REFERENCES dim_date(date_key),
  amount_cents   INT NOT NULL,
  quantity       INT NOT NULL
);

-- Dimension: slowly changing (Type 2 — keep history)
CREATE TABLE dim_customers (
  customer_key   SERIAL PRIMARY KEY,  -- surrogate key
  customer_id    UUID NOT NULL,        -- natural key
  name           VARCHAR(255),
  email          VARCHAR(255),
  tier           VARCHAR(50),
  valid_from     TIMESTAMPTZ NOT NULL,
  valid_to       TIMESTAMPTZ,          -- NULL = current record
  is_current     BOOLEAN DEFAULT TRUE
);
```

### Slowly Changing Dimensions (SCD)

| Type | Strategy | When |
|------|----------|------|
| Type 1 | Overwrite — no history | Non-analytic attributes (phone number) |
| Type 2 | New row with valid_from/valid_to | Need full history (customer tier, pricing) |
| Type 3 | Add "previous_value" column | Only need one historical value |

---

## Analytics Instrumentation

### Event Schema Design

```typescript
// Standard event envelope — consistent across all events
interface AnalyticsEvent {
  event_id: string;          // UUID, for deduplication
  event_name: string;        // snake_case: "task_created"
  timestamp: string;         // ISO 8601
  user_id: string;
  session_id: string;
  properties: Record<string, unknown>;
}

// Specific event
const event: AnalyticsEvent = {
  event_id: crypto.randomUUID(),
  event_name: 'task_created',
  timestamp: new Date().toISOString(),
  user_id: user.id,
  session_id: session.id,
  properties: {
    task_id: task.id,
    project_id: task.projectId,
    has_due_date: task.dueDate !== null,
    source: 'web',
  },
};
```

### Property Naming Rules

- `snake_case` for all property names
- Boolean properties: `is_`, `has_`, `can_` prefix
- IDs: `_id` suffix (`user_id`, `task_id`)
- Timestamps: `_at` suffix (`created_at`, `completed_at`)
- Counts: `_count` suffix (`item_count`)
- Amounts: include unit (`amount_cents`, `duration_ms`)

---

## Pipeline Testing

```python
# Unit test: transformation logic
def test_calculate_revenue():
    input_rows = [
        {'order_id': '1', 'amount_cents': 1000, 'status': 'complete'},
        {'order_id': '2', 'amount_cents': 500,  'status': 'refunded'},  # excluded
    ]
    result = calculate_revenue(input_rows)
    assert result == 10.00  # only completed orders

# Integration test: pipeline idempotency
def test_pipeline_is_idempotent():
    run_pipeline('2026-04-08')
    count_after_first = db.scalar("SELECT COUNT(*) FROM orders_daily WHERE order_date = '2026-04-08'")
    
    run_pipeline('2026-04-08')  # re-run
    count_after_second = db.scalar("SELECT COUNT(*) FROM orders_daily WHERE order_date = '2026-04-08'")
    
    assert count_after_first == count_after_second  # idempotent
```

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Non-idempotent pipelines | DELETE then INSERT, or MERGE/UPSERT |
| No validation at ingestion | Validate schema, nulls, freshness, volume before loading |
| Silent failures | Dead letter queue + alerting on any DLQ write |
| Natural keys as dimension PKs | Use surrogate keys; natural keys change |
| No data lineage | Tag tables with source, pipeline, last_run |
| Transforming in application code | Push transforms to the warehouse (ELT) |

## Verification Checklist

- [ ] Pipeline is idempotent (safe to re-run for the same date/partition)
- [ ] Data validated at ingestion (schema, nulls, freshness, volume)
- [ ] Failed records go to dead letter queue with error context
- [ ] Late-arriving data handled (partition by event time, not load time)
- [ ] Dimensional model uses surrogate keys, not natural keys
- [ ] SCD strategy documented for each dimension
- [ ] Analytics events use consistent schema and naming conventions
- [ ] Pipeline tested for idempotency and correctness
- [ ] Alerts fire on: validation failure, row count anomaly, stale data
