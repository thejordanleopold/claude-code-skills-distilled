---
name: observability
description: "Use when setting up monitoring, logging, tracing, or instrumentation for a production service, adding observability to a new service, debugging a production incident without enough visibility, designing alerting rules, reducing alert fatigue, or building oncall dashboards. Triggers: \"observability\", \"monitoring\", \"logging\", \"tracing\", \"OpenTelemetry\", \"metrics\", \"alerting\", \"dashboard\", \"distributed tracing\", \"structured logs\", \"oncall\", \"no visibility into\"."
---

# Observability

Implement production-grade observability: logs, metrics, and traces that make systems debuggable and alertable.

**Core principle:** You cannot debug what you cannot observe. Instrument before you need it.

## When to Use

- Adding observability to a new service
- Production incident where you can't diagnose root cause
- Setting up alerting that fires on real problems (not noise)
- Designing distributed tracing across microservices
- Building dashboards for oncall monitoring

## When NOT to Use

- Deployment pipelines (use deployment skill)
- Performance optimization (observability informs it, but use backend-performance or frontend-performance skill)
- Security monitoring/SIEM (overlaps but distinct domain)

---

## The Three Pillars

### 1. Logs — Discrete Events

```json
{
  "timestamp": "2026-04-08T12:00:00Z",
  "level": "error",
  "message": "Order processing failed",
  "traceId": "abc123def456",
  "spanId": "span789",
  "service": "order-processor",
  "userId": "user-123",
  "orderId": "order-456",
  "error": {
    "type": "PaymentGatewayError",
    "message": "Gateway timeout after 5000ms"
  }
}
```

**Rules:**
- Always structured JSON — never unstructured strings
- Always include `traceId` for correlation across services
- Log to stdout only — never write log files from the app
- Include context (userId, resourceId) not just the event

### 2. Metrics — Numeric Measurements Over Time

```
http_requests_total{method="GET", status="200", endpoint="/api/orders"} 1234
http_request_duration_seconds{quantile="0.95", endpoint="/api/orders"} 0.23
database_connections_active{pool="primary"} 42
```

**Naming convention (Prometheus):**
- `namespace_subsystem_unit_total` for counters
- `_seconds` for durations, `_bytes` for sizes
- No suffix for gauges

**Cardinality warning:** Never use high-cardinality values as labels (user IDs, request IDs). Each unique label combination creates a new time series.

### 3. Traces — Request Flow Through Services

```
Trace: abc123 (50ms total)
├── API Gateway [0-50ms]
│   ├── Auth Service [0-10ms]
│   └── Order Service [10-50ms]
│       └── DB Query: SELECT orders [30-48ms]  ← bottleneck
```

---

## OpenTelemetry Setup

### Node.js/TypeScript

```typescript
import { NodeSDK } from '@opentelemetry/sdk-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';

const sdk = new NodeSDK({
  traceExporter: new OTLPTraceExporter({ url: 'http://collector:4318/v1/traces' }),
  serviceName: 'order-service',
  instrumentations: [getNodeAutoInstrumentations()],
});
sdk.start();
```

### Manual Instrumentation

```typescript
import { trace, metrics } from '@opentelemetry/api';

const tracer = trace.getTracer('order-module');
const meter = metrics.getMeter('order-module');
const orderCounter = meter.createCounter('orders_processed_total');

async function processOrder(orderId: string) {
  const span = tracer.startSpan('processOrder', {
    attributes: { 'order.id': orderId },
  });
  try {
    // business logic
    orderCounter.add(1, { status: 'success' });
  } catch (err) {
    span.recordException(err as Error);
    orderCounter.add(1, { status: 'error' });
    throw err;
  } finally {
    span.end();
  }
}
```

### Trace Context Propagation

Pass trace ID across service boundaries — never break the trace chain.

```typescript
// HTTP (W3C Trace Context header)
fetch('http://payments-service/charge', {
  headers: { 'traceparent': `00-${traceId}-${spanId}-01` },
});

// Message queue — add to message metadata
const message = { body: payload, metadata: { traceparent: traceId } };
```

---

## RED Method (Services)

Apply to every user-facing service:

| Signal | Metric | Alert Threshold |
|--------|--------|----------------|
| **Rate** | `http_requests_total` (req/sec) | Drop >50% from baseline |
| **Errors** | `http_requests_total{status=~"5.."}` | Error rate >1% for 5min |
| **Duration** | `http_request_duration_seconds` p95 | p95 >1s for 10min |

```yaml
# Prometheus alert rules
- alert: HighErrorRate
  expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.01
  for: 5m
  labels: { severity: critical }
  annotations:
    summary: "Error rate {{ $value | humanizePercentage }} on {{ $labels.service }}"
    runbook: https://wiki/runbooks/high-error-rate

- alert: SlowRequests
  expr: histogram_quantile(0.95, http_request_duration_seconds) > 1.0
  for: 10m
```

## USE Method (Infrastructure)

Apply to every resource (CPU, memory, disk, DB connections):

| Signal | Metric | Alert Threshold |
|--------|--------|----------------|
| **Utilization** | `cpu_usage_percent` | >80% sustained |
| **Saturation** | `cpu_run_queue_length` | Queue >4 sustained |
| **Errors** | `disk_io_errors_total` | Any non-zero |

---

## Alerting Strategy

### What Makes a Good Alert

- **Actionable** — someone can do something specific right now
- **Urgent** — warrants waking someone up (or near-real-time response)
- **Specific** — clear what's wrong and where

```yaml
# Good alert template
alert: ServiceHighErrorRate
expr: rate(http_requests_total{service="order-api", status=~"5.."}[5m]) > 0.05
for: 5m
labels:
  severity: critical
  service: order-api
  runbook: https://wiki/runbooks/high-error-rate
annotations:
  summary: "High error rate on {{ $labels.service }}: {{ $value | humanizePercentage }}"
```

### Runbook Elements (Every Alert Must Have One)

1. **Symptom** — what the alert detects
2. **Root causes** — common causes ranked by probability
3. **Investigation steps** — exact commands to run
4. **Mitigation** — immediate actions (scale, drain, rollback)
5. **Resolution** — permanent fix
6. **Escalation** — when to involve other teams

### What NOT to Alert On

- Metrics during expected traffic spikes
- Transient errors that self-recover in <1min
- Low-severity issues with no immediate action
- Noisy metrics that fire >3x/week with false positives

Build dashboards for observation. Alert only for action items.

---

## Dashboard Layout

Standard layout for any production service:

```
Row 1 (RED):    Request Rate | Error Rate | p50/p95/p99 Latency
Row 2 (USE):    CPU Utilization | Memory | DB Connections | Queue Depth
Row 3 (Ops):    Active Alerts | Recent Deployments | Dependency Status
Row 4 (Detail): Top Endpoints by Error | Slow Queries | Log Volume
```

---

## Common Failure Patterns

| Problem | Symptom | Fix |
|---------|---------|-----|
| Missing trace IDs | Can't correlate logs across services | Generate at entry point, propagate via headers |
| Cardinality explosion | Thousands of metric series, slow queries | Remove high-cardinality labels (user ID, request ID) |
| Alert fatigue | Oncall ignores alerts | Raise thresholds, require sustained duration |
| Silent failures | Error rate 0% but users complain | Add synthetic monitoring, check client-side errors |
| Trace gaps | Spans missing between services | Verify W3C propagation headers in all clients |

## AI Agent Observability

Standard observability covers services. AI agents require behavioral baselining on top of it.

### Behavioral Baselining

Establish baseline during **shadow mode (weeks 1–4)**: collect data with no automated response — observation only. Capture these 7 observables per agent session:

| Observable | Description |
|------------|-------------|
| Tool calls/min | Rate of tool invocations |
| Distinct customer records accessed | Scope of data access per session |
| Distinct database tables touched | Breadth of schema access |
| Tokens/call (input + output) | Context consumption per invocation |
| Distinct external API hosts called | External surface area |
| Session runtime hours | Duration and time-of-day pattern |
| Error rate | Failed tool calls as % of total |

### Anomaly Detection

**3σ threshold:** flag any observable that exceeds 3 standard deviations from its baseline mean. Normal variation stays below this threshold; spikes above it warrant investigation.

### Severity Classification

| Severity | Examples |
|----------|---------|
| **HIGH** | Customer data accessed outside authorized scope; unexpected external API host called |
| **MEDIUM** | Tool call frequency 2–3× baseline |
| **LOW** | Token usage drift >20% week-over-week |

### Response Cadence

- **HIGH**: real-time alerting — act immediately
- **MEDIUM / LOW**: weekly review cadence — no paging

---

## Verification Checklist

- [ ] Trace context propagates through all services (verify with sample trace)
- [ ] All logs include `traceId` for correlation
- [ ] RED metrics alerting configured for every service
- [ ] USE metrics monitoring CPU, memory, connections
- [ ] Every alert has a runbook URL
- [ ] No high-cardinality label values in metrics
- [ ] Dashboard shows RED metrics on top row
- [ ] Synthetic health check hits critical user flows every 1min
- [ ] Alert noise reviewed: no alert firing >3x/week without action taken
- [ ] AI agent behavioral baseline established (7 observables captured during shadow mode weeks 1–4)
- [ ] 3σ anomaly thresholds configured per agent with HIGH/MEDIUM/LOW severity classification
