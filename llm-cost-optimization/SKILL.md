---
name: llm-cost-optimization
description: "Use when needing to reduce LLM API spend, audit token usage, route tasks to cheaper models, implement prompt caching, batch LLM requests, track cost per feature or user, or design cost governance for AI products. Triggers: \"LLM costs\", \"token usage\", \"reduce AI spend\", \"model routing\", \"prompt caching\", \"cost per request\", \"LLM bill\", \"cheaper model\", \"batch API calls\", \"cost optimization\", \"AI budget\"."
---

# LLM Cost Optimization

Systematic framework for auditing, routing, caching, and governing LLM API spend.

**Core principle:** Measure first. Most teams can cut LLM costs 40-75% without quality regression by routing tasks to appropriate models and caching repeated computations.

## When to Use

- LLM API bills are growing faster than usage
- Launching a new AI feature and need to estimate/control costs
- Spending more than $1K/month on LLM APIs
- Users are hitting rate limits due to inefficient token usage
- Need to implement per-user or per-feature cost controls

## When NOT to Use

- Initial prototype with <$100/month spend (premature optimization)
- Quality is failing (fix quality first, then optimize cost)
- Prompt engineering improvements are still untapped

---

## Phase 1: Cost Audit

Before optimizing, understand where money goes.

### Instrument Every API Call

```typescript
async function callLLM(params: LLMParams): Promise<LLMResponse> {
  const response = await llm.complete(params);
  
  // Log cost metadata
  logger.info({
    model: params.model,
    feature: params.metadata.feature,       // "search", "chat", "summarize"
    userId: params.metadata.userId,
    inputTokens: response.usage.input_tokens,
    outputTokens: response.usage.output_tokens,
    estimatedCost: calculateCost(response.usage, params.model),
  });
  
  return response;
}
```

### Cost Breakdown Query

```sql
SELECT
  feature,
  model,
  SUM(input_tokens) AS total_input,
  SUM(output_tokens) AS total_output,
  SUM(estimated_cost) AS total_cost,
  COUNT(*) AS request_count,
  AVG(estimated_cost) AS cost_per_request
FROM llm_calls
WHERE created_at >= NOW() - INTERVAL '30 days'
GROUP BY feature, model
ORDER BY total_cost DESC;
```

**Find:** Top 20% of features consuming 80% of spend. Optimize those first.

---

## Phase 2: Model Routing

### Model Tier Reference (Anthropic, April 2026)

| Model | Input $/1M | Output $/1M | Best For |
|-------|-----------|------------|---------|
| Haiku 4.5 | ~$0.80 | ~$4 | Classification, extraction, tagging, routing |
| Sonnet 4.6 | ~$3 | ~$15 | Balanced: analysis, code, writing |
| Opus 4.6 | ~$15 | ~$75 | Complex reasoning, research, novel problems |

### Routing Rules

```typescript
function selectModel(task: string, qualityRequired: 'high' | 'standard' | 'low'): string {
  // Complex reasoning always uses best model
  if (['research', 'strategy', 'novel_problem'].includes(task)) {
    return 'claude-opus-4-6';
  }
  
  // Standard quality: balanced model
  if (qualityRequired === 'high' || ['code_review', 'analysis', 'writing'].includes(task)) {
    return 'claude-sonnet-4-6';
  }
  
  // Simple tasks: fast/cheap model
  // classification, extraction, summarization, tagging
  return 'claude-haiku-4-5';
}
```

### Fallback Chain (Quality-Gated)

```
Request → Haiku → Quality check passes? → Return
                → Quality check fails? → Sonnet → Quality check passes? → Return
                                                 → Quality check fails? → Opus → Return
```

Track fallback rate per task type. If Haiku fails >10%, update routing rules.

---

## Phase 3: Token Optimization

### Input Token Reduction

| Technique | Savings | How |
|-----------|---------|-----|
| Remove redundant context | 20-40% | Trim examples that add no signal |
| Compress few-shot examples | 10-20% | Shorter, denser examples |
| Reference instead of paste | 30-50% | "See section 3" vs pasting 500 words |
| Deduplicate instructions | 5-10% | Say each rule once |

### Output Token Reduction

| Technique | Savings | How |
|-----------|---------|-----|
| Length constraints | 20-30% | "Respond in under 100 tokens" |
| Structured output | 10-20% | JSON instead of prose |
| Stop sequences | Variable | Halt at logical endpoint |
| Fewer examples | 30-50% | 1 example vs 5 (if accuracy holds) |

### Sliding Context Window

For chat/conversation:
```
Full context (all history) → most accurate, highest cost
Sliding window (last N turns) → good accuracy, moderate cost  
Compressed history (summary + recent) → acceptable, low cost
```

Choose based on task criticality and budget.

---

## Phase 4: Caching

### Prompt Prefix Caching

Cache stable portions of the prompt (system prompt, knowledge base) to avoid re-tokenizing:

| Cache Type | Content | Estimated Savings |
|-----------|---------|------------------|
| System prompt | Persona + instructions | 100K tokens/day per app |
| Few-shot examples | Static examples | 50K tokens/day |
| Knowledge base | Reference docs | Variable, up to 90% |

Anthropic: cached input tokens cost ~10% of normal input tokens.

### Semantic Caching

Cache responses for semantically similar queries (not just exact matches):

```python
def get_with_semantic_cache(query: str, threshold: float = 0.95) -> str | None:
    query_embedding = embed(query)
    
    # Search cache for similar queries
    cached = vector_cache.query(query_embedding, k=1)
    if cached and cached[0].similarity > threshold:
        return cached[0].response
    
    # Cache miss — call LLM
    response = call_llm(query)
    vector_cache.insert(query_embedding, response)
    return response
```

**Cache TTL by query type:**
- Factual ("What is X?") → 7 days
- Procedural ("How do I Y?") → 30 days
- Creative ("Generate Z") → 1 day or never

---

## Phase 5: Batching

Route non-urgent work to batch APIs (typically 50% discount):

```python
# Submit batch job (asynchronous, up to 24hr turnaround)
batch = anthropic.messages.batches.create(requests=[
    {"custom_id": f"req-{i}", "params": {"model": "...", "messages": [...]}}
    for i in range(1000)
])

# Poll for completion
while batch.processing_status != "ended":
    time.sleep(60)
    batch = anthropic.messages.batches.retrieve(batch.id)
```

**Use batching for:**
- Content generation, classification, or analysis jobs
- Background processing (nightly reports, batch exports)
- Any work with latency tolerance >5 minutes

**Do NOT batch:**
- User-facing chat (needs <1s response)
- Real-time decisions (fraud, moderation)

---

## Phase 6: Cost Governance

### Budget Controls

```typescript
const budgets = {
  per_feature: {
    search: 5000,    // $5K/month
    chat: 8000,      // $8K/month
    reports: 2000,   // $2K/month
  },
  per_user_tier: {
    free:       0.10,   // $0.10/user/month
    pro:        3.00,   // $3/user/month
    enterprise: 25.00,  // $25/user/month
  },
};

// Alert when feature reaches 80% of budget
if (featureCostMtd > budgets.per_feature[feature] * 0.80) {
  alertSlack(`#ai-costs: ${feature} at 80% of monthly budget`);
}
```

### Cost vs Quality Decision Framework

| Use Case | Model | Caching | Batching | Cost/Request |
|----------|-------|---------|---------|-------------|
| Critical (financial, legal) | Opus | No | No | ~$0.10 |
| High (customer-facing) | Sonnet | Yes | No | ~$0.03 |
| Standard (internal) | Sonnet | Yes | Yes | ~$0.015 |
| Low (tagging, extraction) | Haiku | Yes | Yes | ~$0.004 |

---

## Common Anti-Patterns

| Anti-Pattern | Impact | Fix |
|---|---|---|
| One model for all tasks | 5-10x overspend | Route by task complexity |
| No cost instrumentation | Can't optimize what you can't see | Log all calls with feature/model metadata |
| Full context always | Token waste | Sliding window + references |
| No system prompt caching | Re-processing static content | Cache stable prefixes |
| All requests real-time | Missing 50% batch discount | Identify non-urgent work, batch it |
| No output length constraints | Token sprawl | Add `max_tokens` per task type |
| No quality baseline | Can't measure cost/quality tradeoff | Define accuracy targets before optimizing |

## Verification Checklist

**Visibility:**
- [ ] All LLM calls instrumented with feature, model, token counts, cost
- [ ] Monthly spend queryable by feature and model
- [ ] Top 3 cost drivers identified

**Routing:**
- [ ] Routing rules defined by task type and quality requirement
- [ ] Fallback chain implemented and fallback rate <10% per task

**Optimization:**
- [ ] Input token reduction applied to top cost drivers (>20% savings)
- [ ] System prompt caching enabled
- [ ] Output length constraints set per task type
- [ ] Batch processing for non-urgent work

**Governance:**
- [ ] Feature budgets defined and alerting at 80%
- [ ] Per-user-tier cost limits enforced
- [ ] Monthly cost review scheduled
- [ ] Quality metrics monitored alongside cost metrics
