---
name: prompt-engineering
description: |
  Use when optimizing prompts for clarity or performance, designing reusable prompt templates,
  implementing few-shot or chain-of-thought patterns, evaluating LLM output quality, versioning
  and A/B testing prompts, designing system prompts for AI agents, or establishing prompt
  governance. Use for prompt optimization, LLM evaluation frameworks, structured output design,
  agent system prompt design, and ReAct/Plan-Execute reasoning patterns.
---

# Prompt Engineering

Design, optimize, and evaluate prompts for consistent, high-quality LLM output.

**Core principle:** The clearest prompt wins. Specificity, structure, and examples consistently outperform clever prompting tricks.

## When to Use

- Improving an existing prompt's accuracy, consistency, or cost
- Creating reusable prompt templates for teams
- Designing in-context learning patterns (few-shot, chain-of-thought)
- Building system prompts for agentic systems
- A/B testing different prompt formulations
- Evaluating and measuring LLM output quality
- Establishing prompt versioning and governance

## When NOT to Use

- General code writing (use implementation-best-practices)
- RAG pipeline design (use rag-and-vector-search)
- LLM cost reduction without quality focus (use llm-cost-optimization)

---

## Pattern Selection Matrix

| Pattern | When to Use | Cost |
|---------|-------------|------|
| **Zero-shot** | Simple, well-defined tasks | Lowest |
| **Few-shot** | Complex tasks, consistent format required | Low |
| **Chain-of-Thought** | Reasoning, math, multi-step logic | Medium |
| **Role Prompting** | Expertise or specific perspective required | Low |
| **Structured Output** | Need parseable JSON/XML responses | Low |
| **ReAct** | Tool-using agents (Thought→Action→Observation) | Medium |
| **Plan-Execute** | Multi-step research or task execution | High |

---

## Prompt Optimization Workflow

### Step 1: Baseline Analysis

Before changing anything:
- Count current tokens
- Identify redundancy (repeated instructions)
- Run 10+ test cases, record outputs

### Step 2: Issue Identification

| Symptom | Root Cause | Fix |
|---------|-----------|-----|
| Inconsistent output format | No format specified | Add explicit schema or example |
| Off-topic responses | Missing constraints | Add "Do not..." guardrails |
| Too verbose | No length constraint | Add "Respond in under X tokens" |
| Wrong interpretation | Ambiguous verbs | Replace "analyze" with "list the top 3 X by Y metric" |
| Hallucination | No grounding | Add "Only use information from the provided context" |

### Step 3: Apply Optimizations (in order)

1. **Role context** — `"You are a senior security engineer..."`
2. **Explicit task** — numbered, specific instructions
3. **Output format** — JSON schema, section headers, or example
4. **Constraints** — length, tone, what NOT to do
5. **Few-shot examples** — 3-5 diverse, realistic examples
6. **Format enforcement** — `"Respond ONLY with valid JSON. Start with {"`

### Step 4: Validate

- Run both old and new prompts against the same test cases
- Compare: token count, output consistency, accuracy
- Statistical test if >50 samples

---

## Prompt Template Pattern

```markdown
You are [ROLE/PERSONA].

Your task: [EXPLICIT DESCRIPTION — numbered steps]

Context:
[CONTEXT_BLOCK]

Examples:
Input: [example input]
Output: [example output — exact format]

Constraints:
- [What NOT to do]
- [Length limit]
- [Tone/style requirement]

Output format:
[JSON schema or example structure]
```

---

## Few-Shot Example Design

Choose 3-5 examples covering:

| Type | Purpose |
|------|---------|
| Simple/basic | Shows fundamental pattern |
| Complex/edge case | Demonstrates nuance |
| Boundary/negative | What NOT to output |
| Domain-specific | Realistic real-world case |

**Critical:** All examples must use the exact same output format. Inconsistent examples produce inconsistent outputs.

---

## Structured Output Design

```
Step 1: Define schema
  {"summary": "string", "sentiment": "positive|negative|neutral", "confidence": 0-1}

Step 2: Include in prompt
  "Respond with JSON: summary (str, <200 chars), sentiment (enum), confidence (0-1)"

Step 3: Add format enforcement
  "CRITICAL: Respond ONLY with valid JSON. No markdown. Start with {"

Step 4: Test — parse 10 outputs as JSON. Must be 100% success rate.
```

---

## System Prompt Design for Agents

```markdown
You are [AGENT_NAME], a [TYPE] designed to [PRIMARY_PURPOSE].

Core Responsibilities:
1. [Responsibility 1]
2. [Responsibility 2]

Available Tools:
- tool_name: [what it does, when to use it]

Decision Rules:
1. [When to use Tool A vs Tool B]
2. [When to escalate to user]

Guardrails:
- Never [dangerous action]
- Always [safety behavior]
- If [edge case condition], then [specific action]
```

**ReAct pattern for tool-using agents:**
```
Thought: [Reason about what to do]
Action: [Call a tool]
Observation: [Tool result]
[Repeat if needed]
Final Answer: [Response]
```

---

## Evaluation Framework

### Quality Metrics

| Metric | Measurement | Target |
|--------|-------------|--------|
| **Correctness** | % matching gold-standard answers | >90% |
| **Consistency** | Same input → same format (5 runs) | 100% format match |
| **Faithfulness** | Answer grounded in context (NLI check) | >90% |
| **Token efficiency** | Tokens per quality unit | Minimize |

### A/B Testing Process

1. Create two variants (e.g., with/without few-shot)
2. Generate 50+ outputs from each
3. Score on correctness, length, consistency
4. t-test for statistical significance
5. Winner informs next iteration

---

## Version Control

```
Prompt: sentiment-classifier
Version: 1.2.3  |  Date: 2026-04-08
Changes:
  - Added enum constraint for sentiment values
  - Removed verbose preamble (-45 tokens)
  - Added 1 new edge-case example
Metrics:
  - Accuracy: 94% (↑ from 91%)
  - Tokens: 312 (↓ from 357)
```

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Vague instructions ("Be helpful") | Specific numbered steps |
| No output format | Add JSON schema or example |
| Redundant context | Consolidate, remove repetition |
| Only happy-path test cases | Test edge cases and negatives |
| Inconsistent few-shot examples | Uniform format across all examples |
| No constraints | Add explicit "do not" guardrails |

## Verification Checklist

- [ ] Task is explicitly defined (not vague verbs)
- [ ] Output format specified (schema or example)
- [ ] Role/persona included
- [ ] Few-shot examples present for complex tasks
- [ ] Constraints listed (length, scope, what not to do)
- [ ] Format enforcement added
- [ ] Tested with 10+ varied inputs
- [ ] 100% output format validation pass rate
- [ ] Token count reasonable (<2K for prompt itself)
- [ ] Prompt versioned with timestamp and metrics
