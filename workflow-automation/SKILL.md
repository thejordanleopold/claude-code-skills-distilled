---
name: workflow-automation
description: "Use when designing or implementing automated workflows, task coordination systems, or multi-step process automation. Use when defining workflows as specs before implementing, handling human-in-the-loop approval steps, managing task dependencies, automating browser interactions, or building retry and error recovery into automated processes. Triggers: \"workflow\", \"automation\", \"automate this process\", \"task coordination\", \"approval flow\", \"browser automation\", \"spec-driven\", \"dependency management\", \"orchestration\"."
---

# Workflow Automation

Design and implement reliable automated workflows with clear specs, error recovery, and human checkpoints.

**Core principle:** Define the workflow as a spec before writing code. A workflow you can't describe in plain steps will be impossible to debug when it fails at step 7 of 12.

## When to Use

- Automating multi-step business processes
- Coordinating tasks with dependencies between them
- Building approval or human-in-the-loop flows
- Automating browser-based interactions
- Adding retry and recovery to existing automation

## When NOT to Use

- Single API calls (use api-design skill)
- CI/CD pipelines (use deployment skill)
- Data pipelines (use data-engineering skill)
- Multi-agent AI orchestration (use multi-agent-orchestration skill)

---

## Spec-Driven Workflow Design

Define behavior in plain language before writing a single line of code:

```yaml
# workflow: user-onboarding.yaml
name: user-onboarding
description: Onboard a new user from signup to first value

steps:
  - id: create_account
    action: create_user_record
    inputs: [email, name, plan]
    on_failure: abort

  - id: send_welcome_email
    action: send_email
    template: welcome
    depends_on: [create_account]
    on_failure: continue  # non-critical

  - id: provision_workspace
    action: create_workspace
    depends_on: [create_account]
    on_failure: abort
    retry:
      max_attempts: 3
      backoff: exponential

  - id: human_review
    action: request_approval
    assignee: trust_and_safety_team
    depends_on: [provision_workspace]
    timeout: 48h
    on_timeout: escalate

  - id: activate_account
    action: set_account_active
    depends_on: [human_review]
    condition: "human_review.approved == true"
```

The spec defines: steps, dependencies, failure modes, retry strategy, and human checkpoints — before any implementation.

---

## Workflow Patterns

### Linear (Sequential Steps)

```python
def run_workflow(context):
    context = step_one(context)
    context = step_two(context)
    context = step_three(context)
    return context
```

Use when: steps must execute in strict order with no branching.

### Parallel (Independent Steps)

```python
import asyncio

async def run_parallel_workflow(context):
    results = await asyncio.gather(
        step_a(context),
        step_b(context),
        step_c(context),
    )
    return merge_results(results)
```

Use when: steps are independent and can run concurrently to reduce total time.

### Event-Driven

```python
@workflow.on_event('order.placed')
async def handle_order(event: OrderPlacedEvent):
    await reserve_inventory(event.order_id)
    await charge_payment(event.order_id)
    await send_confirmation(event.customer_id)
```

Use when: workflows are triggered by external events rather than direct calls.

---

## Task Coordination with Dependencies

```python
# Temporal workflow (Python SDK)
from temporalio import workflow, activity

@workflow.defn
class OnboardingWorkflow:
    @workflow.run
    async def run(self, input: OnboardingInput) -> OnboardingResult:
        # Sequential with retry
        user = await workflow.execute_activity(
            create_user,
            input,
            retry_policy=RetryPolicy(max_attempts=3, backoff_coefficient=2.0),
            start_to_close_timeout=timedelta(seconds=30),
        )
        
        # Parallel steps
        workspace, email_sent = await asyncio.gather(
            workflow.execute_activity(provision_workspace, user.id,
                start_to_close_timeout=timedelta(minutes=2)),
            workflow.execute_activity(send_welcome_email, user.email,
                start_to_close_timeout=timedelta(seconds=10)),
        )
        
        return OnboardingResult(user=user, workspace=workspace)
```

---

## Error Handling and Retry

### Retry Strategy

```python
from dataclasses import dataclass
from datetime import timedelta

@dataclass
class RetryConfig:
    max_attempts: int = 3
    base_delay_seconds: float = 1.0
    max_delay_seconds: float = 60.0
    backoff_multiplier: float = 2.0
    retryable_errors: tuple = (NetworkError, TimeoutError, RateLimitError)
    # Never retry: ValidationError, AuthError, NotFoundError

def execute_with_retry(fn, config: RetryConfig = RetryConfig()):
    for attempt in range(1, config.max_attempts + 1):
        try:
            return fn()
        except config.retryable_errors as e:
            if attempt == config.max_attempts:
                raise
            delay = min(
                config.base_delay_seconds * (config.backoff_multiplier ** (attempt - 1)),
                config.max_delay_seconds
            )
            time.sleep(delay + random.uniform(0, 0.1 * delay))  # jitter
```

### Idempotency

Every workflow step must be safely re-runnable:

```python
async def send_welcome_email(user_id: str):
    # Check if already sent before sending
    if await email_log.exists(user_id=user_id, template='welcome'):
        return  # Already sent — skip
    
    await email_service.send(user_id, template='welcome')
    await email_log.record(user_id=user_id, template='welcome')
```

Use idempotency keys for external API calls:
```python
stripe.PaymentIntent.create(
    amount=1000,
    currency='usd',
    idempotency_key=f"payment-{order_id}",  # Safe to retry
)
```

---

## Human-in-the-Loop

```python
@workflow.defn
class ContentModerationWorkflow:
    @workflow.run
    async def run(self, content_id: str):
        # Auto-screen first
        auto_result = await workflow.execute_activity(auto_screen, content_id)
        
        if auto_result.requires_human_review:
            # Wait for human signal (up to 48 hours)
            approval = await workflow.wait_condition(
                lambda: self.approval_received,
                timeout=timedelta(hours=48)
            )
            
            if not approval:
                await workflow.execute_activity(escalate, content_id)
                return
        
        await workflow.execute_activity(publish_content, content_id)
    
    @workflow.signal
    def approve(self, approved: bool):
        self.approval_received = True
        self.approved = approved
```

---

## Browser Automation

Use Playwright for reliable browser automation. Pattern: launch headless Chromium → fill login form → `wait_for_url` on redirect → navigate → trigger download → `wait_for_download()`. Always use `data-testid` selectors over CSS classes.

Use when: internal tooling with no API, legacy systems, scheduled dashboard reports. **When an API exists, always prefer it over scraping.**

---

## Workflow Testing

```python
# Test individual steps in isolation
def test_provision_workspace_is_idempotent():
    result_1 = provision_workspace(user_id='user-123')
    result_2 = provision_workspace(user_id='user-123')  # Re-run
    assert result_1.workspace_id == result_2.workspace_id

# Test failure recovery
def test_retry_on_network_error(mock_api):
    mock_api.side_effect = [NetworkError(), NetworkError(), success_response]
    result = execute_with_retry(lambda: call_api())
    assert result == success_response
    assert mock_api.call_count == 3
```

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| No spec before implementation | Write the step-by-step spec first |
| Non-idempotent steps | Check-before-act pattern for every step |
| Silent step failures | Each step must succeed or raise — no swallowed exceptions |
| No timeout on human steps | Always set a timeout with escalation path |
| Missing retry for transient errors | Add retry with exponential backoff + jitter |
| Scraping when an API exists | Always check for an API first |

## Verification Checklist

- [ ] Workflow defined as spec before implementation
- [ ] Every step is idempotent (safe to re-run)
- [ ] Retry configured for transient errors (network, rate limit, timeout)
- [ ] Human steps have timeouts with escalation paths
- [ ] Failed steps are logged with context (step name, input, error)
- [ ] Dead letter queue or alerting for permanently failed workflows
- [ ] Steps tested in isolation
- [ ] Idempotency tested (re-running produces same result)
