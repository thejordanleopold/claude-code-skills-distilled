---
name: third-party-integration
description: "Use when integrating with external APIs, payment processors (Stripe), webhooks, or third-party services. Use when implementing API clients with authentication and rate limiting, handling webhooks with signature verification and idempotency, writing contract tests for external services, or isolating third-party dependencies behind adapters. Triggers: \"Stripe\", \"payment integration\", \"webhook\", \"third-party API\", \"external service\", \"API client\", \"integrate with\", \"signature verification\", \"idempotency key\"."
---

# Third-Party Integration

Integrate reliably with external APIs and services: adapters, webhooks, payments, and testing.

**Core principle:** Treat every third-party API as unreliable. It will go down, change, rate-limit you, and send duplicate webhooks. Design for all of it.

## When to Use

- Integrating with any external API or service
- Implementing webhook receivers
- Adding payment processing (Stripe)
- Isolating third-party code behind an interface
- Writing tests for code that calls external services

## When NOT to Use

- Internal service-to-service calls (use api-design skill)
- Database connections (use database-design skill)

---

## Integration Architecture

### Anti-Corruption Layer (Adapter Pattern)

Never let third-party models bleed into your domain. Always translate at the boundary.

```typescript
// External: Stripe's model
interface StripePaymentIntent {
  id: string;
  amount: number;
  currency: string;
  status: 'requires_payment_method' | 'succeeded' | 'canceled';
}

// Internal: your domain model
interface Payment {
  id: PaymentId;
  amountCents: number;
  currency: string;
  status: 'pending' | 'complete' | 'failed';
}

// Adapter: translates at the boundary
class StripePaymentAdapter {
  toDomain(intent: StripePaymentIntent): Payment {
    return {
      id: new PaymentId(intent.id),
      amountCents: intent.amount,
      currency: intent.currency,
      status: this.mapStatus(intent.status),
    };
  }

  private mapStatus(stripeStatus: string): Payment['status'] {
    const map: Record<string, Payment['status']> = {
      'succeeded': 'complete',
      'requires_payment_method': 'pending',
      'canceled': 'failed',
    };
    return map[stripeStatus] ?? 'pending';
  }
}
```

### Interface First

Define your own interface before integrating:

```typescript
// Define what YOU need — not what Stripe provides
interface PaymentService {
  charge(params: ChargeParams): Promise<Payment>;
  refund(paymentId: PaymentId, amountCents: number): Promise<void>;
  getPayment(paymentId: PaymentId): Promise<Payment>;
}

// Production implementation
class StripePaymentService implements PaymentService { ... }

// Test implementation
class FakePaymentService implements PaymentService { ... }
```

---

## API Client Patterns

### Authentication

```typescript
// Bearer token (most common)
headers: { Authorization: `Bearer ${apiKey}` }

// API Key in header
headers: { 'X-API-Key': apiKey }

// Basic auth
headers: { Authorization: `Basic ${Buffer.from(`${key}:${secret}`).toString('base64')}` }
```

### Resilient API Client

```typescript
class ApiClient {
  constructor(
    private baseUrl: string,
    private apiKey: string,
    private timeout = 10_000,
  ) {}

  async request<T>(path: string, options: RequestOptions = {}): Promise<T> {
    const url = `${this.baseUrl}${path}`;
    
    const response = await fetch(url, {
      ...options,
      headers: {
        'Authorization': `Bearer ${this.apiKey}`,
        'Content-Type': 'application/json',
        ...options.headers,
      },
      signal: AbortSignal.timeout(this.timeout),
    });

    if (response.status === 429) {
      const retryAfter = Number(response.headers.get('Retry-After') ?? 1);
      await sleep(retryAfter * 1000);
      return this.request(path, options);  // Retry once
    }

    if (!response.ok) {
      throw new ApiError(response.status, await response.text(), url);
    }

    return response.json();
  }
}
```

### Rate Limiting

Handle 429s with `Retry-After` (shown in resilient client above). For concurrent request limiting, use `p-limit` or `bottleneck` in production rather than a hand-rolled queue.

---

## Webhook Handling

### Signature Verification (Stripe example)

Always verify the signature before processing. An unverified webhook endpoint can be exploited.

```typescript
app.post('/webhooks/stripe',
  express.raw({ type: 'application/json' }),  // Raw body required for verification
  async (req, res) => {
    const sig = req.headers['stripe-signature'] as string;
    
    let event: Stripe.Event;
    try {
      event = stripe.webhooks.constructEvent(req.body, sig, process.env.STRIPE_WEBHOOK_SECRET!);
    } catch (err) {
      logger.warn('Invalid webhook signature', { err });
      return res.status(400).send('Webhook signature verification failed');
    }

    // Acknowledge immediately — process async
    res.status(200).json({ received: true });
    
    await processWebhookEvent(event);
  }
);
```

### Idempotency

Webhooks are delivered at-least-once. Always deduplicate:

```typescript
async function processWebhookEvent(event: Stripe.Event) {
  // Check if already processed
  const processed = await db.query(
    'SELECT id FROM webhook_events WHERE event_id = $1',
    [event.id]
  );
  if (processed.rows.length > 0) {
    logger.info('Duplicate webhook — skipping', { eventId: event.id });
    return;
  }

  // Process
  await handleEvent(event);

  // Record as processed
  await db.query(
    'INSERT INTO webhook_events (event_id, type, processed_at) VALUES ($1, $2, NOW())',
    [event.id, event.type]
  );
}
```

---

## Payment Integration (Stripe)

### Idempotent Charge

```typescript
async function chargeCustomer(order: Order): Promise<Payment> {
  const intent = await stripe.paymentIntents.create(
    {
      amount: order.totalCents,
      currency: 'usd',
      customer: order.stripeCustomerId,
      payment_method: order.paymentMethodId,
      confirm: true,
      metadata: { order_id: order.id },
    },
    {
      idempotencyKey: `charge-${order.id}`,  // Safe to retry on network error
    }
  );

  return paymentAdapter.toDomain(intent);
}
```

### Subscription Lifecycle

Key webhooks: `customer.subscription.created` → provision, `invoice.payment_succeeded` → extend access, `invoice.payment_failed` → dunning email, `customer.subscription.deleted` → revoke access. States: `trialing → active → past_due → canceled/unpaid`.

---

## Testing Third-Party Integrations

### Fake Implementation for Unit Tests

```typescript
class FakePaymentService implements PaymentService {
  private payments = new Map<string, Payment>();

  async charge(params: ChargeParams): Promise<Payment> {
    const payment: Payment = {
      id: new PaymentId(`pay_fake_${Date.now()}`),
      amountCents: params.amountCents,
      currency: params.currency,
      status: 'complete',
    };
    this.payments.set(payment.id.value, payment);
    return payment;
  }

  async getPayment(id: PaymentId): Promise<Payment> {
    return this.payments.get(id.value) ?? throw new NotFoundError();
  }
}

// Usage in tests
const paymentService = new FakePaymentService();
const orderService = new OrderService(paymentService);
await orderService.checkout(order);
```

---

## Common Failure Modes

| Failure | Detection | Fix |
|---------|-----------|-----|
| Duplicate webhooks | Duplicate data in DB | Idempotency check on event ID before processing |
| Signature verification skipped | Forged events accepted | Always verify before any processing |
| No timeout on API calls | Requests hang indefinitely | Set `AbortSignal.timeout(10_000)` |
| Third-party model in domain | Domain breaks when provider changes schema | Adapter layer translates at boundary |
| API key in source code | Key exposed in git history | Environment variables only; use `.env` |
| No retry on network error | Transient failures become permanent | Retry with backoff for 5xx and network errors |

## Verification Checklist

- [ ] All third-party models translated at boundary (adapter pattern)
- [ ] Own interface defined before integrating (for testability)
- [ ] Webhook signatures verified before processing
- [ ] Webhook handler deduplicates by event ID
- [ ] Webhook responds 200 immediately, processes async
- [ ] API calls have timeouts (10s default)
- [ ] Idempotency keys used for payment/state-changing calls
- [ ] Rate limiting handled (429 → retry with Retry-After)
- [ ] API keys in environment variables, never in code
- [ ] Fake implementation exists for unit testing
- [ ] Sandbox/test mode used in staging and development
