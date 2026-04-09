# Claude Code Skills Distilled

30 production-quality skills for [Claude Code](https://claude.ai/code), synthesized from 16 community skill repositories into focused, high-signal reference files.

## What Are Skills?

Claude Code skills are context files that load automatically when relevant tasks are detected. Each skill teaches Claude a specific engineering discipline — not just what to do, but how to reason through it.

Install by placing skill directories in `~/.claude/skills/`. Claude Code picks them up automatically.

## Skills (30 total)

### Planning & Architecture
| Skill | Triggers |
|-------|---------|
| `feature-planning` | Planning features, clarifying requirements, vertical slicing |
| `system-design` | Architecture design, ADRs, DDD, bounded contexts |

### Implementation
| Skill | Triggers |
|-------|---------|
| `coding-principles` | Implementation approach, complexity, dependencies, 12-factor |
| `api-design` | REST APIs, contract-first design, circuit breaker, Hyrum's Law |
| `refactoring` | Safe restructuring, Extract Method, Strangler Fig, code smells |

### Code Quality
| Skill | Triggers |
|-------|---------|
| `code-review` | Code review, PR feedback, 6-axis review framework |
| `code-standards` | Naming, complexity thresholds, anti-patterns, best practices |

### Testing
| Skill | Triggers |
|-------|---------|
| `tdd` | TDD, unit tests, RED-GREEN-REFACTOR, mocks vs fakes |
| `e2e-testing` | Playwright, integration tests, browser automation, property-based testing |

### Security
| Skill | Triggers |
|-------|---------|
| `threat-modeling` | STRIDE, attack surface, trust boundaries, DREAD scoring |
| `security-review` | OWASP Top 10, static analysis, vulnerability review, Semgrep |
| `security-hardening` | Security headers, rate limiting, secrets management, dependency audit |

### Performance
| Skill | Triggers |
|-------|---------|
| `frontend-performance` | Core Web Vitals, LCP/INP/CLS, bundle size, React re-renders |
| `backend-performance` | Slow APIs, N+1 queries, EXPLAIN plans, memory leaks |

### Design & UI
| Skill | Triggers |
|-------|---------|
| `design-system` | Design tokens, color palette, typography, DESIGN.md |
| `ui-components` | WCAG 2.1 AA, responsive design, component architecture |

### Shipping
| Skill | Triggers |
|-------|---------|
| `git-workflow` | Commits, branches, PRs, trunk-based development, worktrees |
| `deployment` | CI/CD, GitHub Actions, feature flags, canary releases, incidents |

### AI / LLM
| Skill | Triggers |
|-------|---------|
| `prompt-engineering` | Prompt optimization, few-shot design, structured output |
| `rag-and-vector-search` | RAG pipelines, embeddings, vector databases, chunking |
| `llm-cost-optimization` | Token optimization, model routing, prompt caching, cost governance |

### Data & Operations
| Skill | Triggers |
|-------|---------|
| `database-design` | Schema design, migrations, indexes, multi-tenancy, RLS |
| `observability` | OpenTelemetry, logging, metrics, tracing, alerting, dashboards |
| `compliance-and-governance` | SOC 2, ISO 27001, GDPR, gap analysis, evidence automation |
| `data-engineering` | ETL/ELT, data quality, dimensional modeling, analytics events |
| `workflow-automation` | Multi-step automation, Temporal, human-in-the-loop, Playwright |
| `third-party-integration` | External APIs, webhooks, Stripe, adapter pattern, idempotency |

### Meta
| Skill | Triggers |
|-------|---------|
| `debugging` | Bugs, failing tests, errors, production incidents |
| `multi-agent-orchestration` | Parallel agent dispatch, subagent coordination |
| `skill-creation` | Creating or editing Claude Code skills |

## Installation

```bash
# Clone into your Claude skills directory
git clone https://github.com/thejordanleopold/claude-code-skills-distilled ~/.claude/skills

# Or copy individual skills
cp -r claude-code-skills-distilled/debugging ~/.claude/skills/
```

## Design Principles

- **Focused** — each skill is 150–300 lines, covering one domain
- **Trigger-optimized** — descriptions are tuned for Claude's skill discovery (CSO)
- **Actionable** — concrete patterns and checklists, not vague advice
- **Honest about scope** — every skill has "When NOT to Use" with named alternatives

## Sources

Synthesized from 16 community repositories including trailofbits, gstack, alirezarezvani, snyk, agentic-framework, superpowers, karpathy, and more — distilled into a single coherent library.
