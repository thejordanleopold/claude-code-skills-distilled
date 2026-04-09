---
name: system-design
description: |
  Use when designing system architecture, making architectural decisions, writing Architecture
  Decision Records (ADRs), applying Domain-Driven Design (DDD) patterns, decomposing a system
  into bounded contexts or services, designing component boundaries and interfaces, evaluating
  architectural trade-offs, or planning a major technical direction change. Triggers: "design
  the architecture", "system design", "ADR", "bounded context", "how should I structure the system",
  "microservices vs monolith", "event-driven", "trade-offs".
---

# System Design

Architectural thinking for systems that need to scale, evolve, and be maintained by teams.

**Core principle:** Good architecture makes change cheap. Bad architecture makes every change expensive.

## When to Use

- Designing a new system or major subsystem
- Evaluating whether to split a monolith
- Choosing between architectural patterns
- Writing an ADR for a significant decision
- Designing service boundaries and communication patterns
- Planning event-driven vs synchronous architecture

## When NOT to Use

- Single feature planning (use feature-planning skill)
- Database schema design (use database-design skill)
- API endpoint design (use api-design skill)

---

## Architectural Decision Records (ADRs)

Document significant architectural decisions. An undocumented decision is a mystery for the next engineer.

### When to Write an ADR

- Decision is hard to reverse
- Affects multiple teams or components
- Has meaningful trade-offs worth recording
- Future engineers would otherwise be confused by the choice

### ADR Template

```markdown
# ADR-[N]: [Short title of decision]

**Status:** Proposed | Accepted | Deprecated | Superseded by ADR-[M]
**Date:** YYYY-MM-DD
**Deciders:** [Names or teams]

## Context
[What situation are we in? What problem needs solving? What forces are at play?]

## Decision
[What have we decided to do?]

## Rationale
[Why this option? What alternatives were considered and why rejected?]

## Consequences
**Good:** [Benefits of this decision]
**Bad:** [Downsides, constraints, or risks introduced]
**Neutral:** [Changes that are neither good nor bad]
```

---

## System Decomposition

### Start with Business Domains

Before technical decomposition, map business domains:

1. **Identify core domains** — what the business does (e.g., Order Management, Inventory, Payments)
2. **Identify supporting domains** — what enables core (e.g., Notifications, Auth, Analytics)
3. **Identify generic domains** — solved by external tools (e.g., Email, Billing, Auth providers)

Invest engineering effort proportional to business value. Core domains get custom solutions. Generic domains get third-party tools.

### Bounded Contexts (DDD)

A bounded context is a clear boundary within which a model has a specific meaning.

```
Order Context:          "Order" means a customer purchase with items, payment, address
Inventory Context:      "Order" means a replenishment request to a supplier
Fulfillment Context:    "Order" means a pick-pack-ship job in the warehouse
```

The same word means different things in different contexts. That's normal. Don't force one unified model.

**Context Map:** Draw how contexts relate:
- **Partnership** — teams coordinate closely, ship together
- **Customer-Supplier** — one context depends on another's API
- **Anti-corruption Layer** — translation between incompatible models
- **Published Language** — shared, well-documented interface (OpenAPI spec)

### Aggregate Design

An aggregate is a cluster of objects treated as a unit for data consistency:

```
Order (aggregate root)
  └── OrderItem (entity, belongs to Order)
  └── ShippingAddress (value object)
  └── PaymentReference (value object, ID only — no details)
```

**Rules:**
- Only aggregate roots have repositories
- External references use IDs only (not embedded objects)
- Aggregates enforce their own invariants (business rules)
- Keep aggregates small — one aggregate per transaction

---

## Architectural Patterns

### Monolith vs Services

| Situation | Start Here |
|-----------|-----------|
| New product, team <10 | Modular monolith |
| Well-understood domain boundaries | Services |
| Different scaling requirements per domain | Services |
| Organizational boundaries already exist | Services |
| Still discovering the domain | Monolith until stable |

**Rule:** Extract to services only when you have real pain — deploy coupling, scaling divergence, team autonomy issues. Not before.

### Communication Patterns

| Pattern | When | Trade-offs |
|---------|------|-----------|
| **Synchronous REST/gRPC** | Request needs immediate response | Simple, coupled availability |
| **Async messaging (events)** | Decoupled, fire-and-forget | Complex, eventual consistency |
| **Event sourcing** | Full audit trail required, CQRS | High complexity, powerful |
| **Saga pattern** | Distributed transactions | Complex coordination, resilient |

### Sync vs Async Decision

Use async (events/queues) when:
- Caller doesn't need the result immediately
- Operation might take >500ms
- Multiple consumers of the same event
- Downstream failures shouldn't block the caller

Use sync (REST/gRPC) when:
- Caller needs immediate response
- Transaction must be atomic
- One consumer only

---

## Trade-off Analysis Framework

For every significant architectural decision, evaluate:

| Dimension | Question |
|-----------|---------|
| **Consistency** | Does every node see the same data at the same time? |
| **Availability** | Does the system respond even if some nodes fail? |
| **Partition tolerance** | Does the system work despite network splits? |
| **Latency** | How fast does it need to be? What's acceptable? |
| **Scalability** | What scale is actually expected in 12-24 months? |
| **Operational complexity** | Can the team maintain this? |
| **Reversibility** | How hard is it to change this decision later? |

**CAP theorem:** In a distributed system, you can only guarantee 2 of: Consistency, Availability, Partition Tolerance.

---

## Design Principles

### Single Responsibility

Every module, service, and component has one reason to change. If you need to change a module for two different business reasons, split it.

### Dependency Rule (Clean Architecture)

Dependencies point inward:
```
UI → Application Logic → Domain → (nothing)
Infrastructure → Domain
```

Domain never depends on infrastructure. Infrastructure adapters implement domain interfaces.

### Anti-Corruption Layer

When integrating with legacy systems or external APIs with messy models, translate at the boundary:

```typescript
// External: messy legacy schema
interface LegacyOrder { ord_no: string; cust_id: number; itm_list: string }

// Internal: clean domain model
interface Order { id: OrderId; customerId: CustomerId; items: OrderItem[] }

// Anti-corruption layer translates
class LegacyOrderAdapter {
  toDomain(legacy: LegacyOrder): Order {
    return {
      id: new OrderId(legacy.ord_no),
      customerId: new CustomerId(String(legacy.cust_id)),
      items: this.parseItems(legacy.itm_list),
    };
  }
}
```

---

## Verification Checklist

Before finalizing architecture:
- [ ] Business domains identified and mapped
- [ ] Bounded contexts defined with explicit boundaries
- [ ] ADR written for each significant decision
- [ ] Trade-offs explicitly listed (not just benefits)
- [ ] Dependency directions are intentional (no circular deps)
- [ ] Integration points use anti-corruption layers where models differ
- [ ] Communication pattern chosen with justification (sync vs async)
- [ ] Operational complexity realistic for team size
- [ ] Rollback plan exists if the architecture decision proves wrong
