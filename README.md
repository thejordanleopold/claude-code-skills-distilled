# Claude Code Skills Distilled

31 production-quality skills for [Claude Code](https://claude.ai/code), synthesized from 16 community skill repositories into focused, high-signal reference files.

## What Are Skills?

Claude Code skills are context files that load automatically when relevant tasks are detected. Each skill teaches Claude a specific engineering discipline — not just what to do, but how to reason through it.

Install by placing skill directories in `~/.claude/skills/`. Claude Code picks them up automatically.

## Installation

```bash
# Clone into your Claude skills directory
git clone https://github.com/thejordanleopold/claude-code-skills-distilled ~/.claude/skills

# Or copy individual skills
cp -r claude-code-skills-distilled/debugging ~/.claude/skills/
```

## Skills (31 total)

Every skill is also a slash command — type `/skill-name` to invoke directly, or let Claude auto-load it when your prompt matches its triggers.

### Planning & Architecture

| Skill | Description | When to use |
|---------|-------------|-------------|
| `/feature-planning` | Clarifies requirements, slices vertically, asks 1–5 forcing questions before writing a line of code | Starting a feature with unclear or underspecified scope |
| `/system-design` | Produces ADRs, bounded contexts, trust boundaries, and explicit trade-off analysis | Designing a new system, service, or major architectural component |

### Implementation

| Skill | Description | When to use |
|---------|-------------|-------------|
| `/coding-principles` | Applies surgical changes, goal-driven execution, simplicity-first, and 12-factor discipline | Deciding how to approach an implementation or reviewing complexity decisions |
| `/api-design` | Contract-first REST design with Hyrum's Law, circuit breakers, idempotency, and health checks | Designing or reviewing API endpoints |
| `/refactoring` | Applies Extract Method, Strangler Fig, and Two Hats Rule without changing behavior | Restructuring legacy or messy code safely |

### Code Quality

| Skill | Description | When to use |
|---------|-------------|-------------|
| `/code-review` | 6-axis review (correctness, security, performance, readability, maintainability, architecture), tests first | Reviewing a PR or requesting a structured code audit |
| `/code-standards` | Naming conventions, complexity thresholds, Two Hats Rule, and automated quality gates | Checking whether code meets team or project standards |

### Testing

| Skill | Description | When to use |
|---------|-------------|-------------|
| `/tdd` | RED-GREEN-REFACTOR cycle, Prove-It Pattern for bugs, Mock at Boundaries Only, `[unit] should [behavior] when [condition]` naming | Writing tests or fixing any bug |
| `/e2e-testing` | Playwright with Page Object Model, `page.route()` API mocking, `axe-playwright` accessibility testing | Testing complete user flows or automating browser interactions |

### Security

| Skill | Description | When to use |
|---------|-------------|-------------|
| `/threat-modeling` | STRIDE analysis, DREAD scoring, trust boundary mapping, agentic AI threat vectors | Before writing any auth, authorization, or data handling code |
| `/security-review` | OWASP Top 10:2025, ASVS 5.0 levels, Semgrep/CodeQL, variant analysis, constant-time crypto | Auditing code for specific vulnerability classes |
| `/security-hardening` | Security headers, rate limiting, secrets management, container hardening, Terraform/K8s IaC security | Hardening an application, service, or infrastructure configuration |
| `/offensive-security` | Recon, web app attacks, Linux/Windows privesc, Active Directory, password attacks, lateral movement, cloud/container offensive | Authorized penetration testing, CTF challenges, or red team exercises |

### Performance

| Skill | Description | When to use |
|---------|-------------|-------------|
| `/frontend-performance` | Core Web Vitals (LCP/INP/CLS), bundle analysis, React re-render diagnosis, Lighthouse CI | Web vitals are failing or the frontend feels slow |
| `/backend-performance` | N+1 detection, EXPLAIN plans, index strategy, memory leaks, API latency budgets | APIs are slow or database queries are underperforming |

### Design & UI

| Skill | Description | When to use |
|---------|-------------|-------------|
| `/design-system` | Design tokens (primitive → semantic → component), color constraints, typography, spacing, DESIGN.md | Establishing the visual design language for a product |
| `/ui-components` | WCAG 2.1 AA accessibility, focus management, responsive design, AI slop anti-patterns | Building or reviewing UI components |

### Shipping

| Skill | Description | When to use |
|---------|-------------|-------------|
| `/git-workflow` | Atomic commits, trunk-based development, prefix-grouped branch cleanup, two-gate confirmation for destructive ops | Committing, branching, or cleaning up stale branches |
| `/deployment` | CI/CD quality gates, GitHub Actions, canary releases, feature flag lifecycle, incident management | Setting up or improving a deployment pipeline |

### AI / LLM

| Skill | Description | When to use |
|---------|-------------|-------------|
| `/prompt-engineering` | Few-shot design, chain-of-thought, structured output, system prompt architecture, A/B testing prompts | Designing or improving a prompt for an LLM |
| `/rag-and-vector-search` | Chunking strategy, embedding model selection, vector DB setup, RAGAS evaluation | Building a RAG pipeline or semantic search system |
| `/llm-cost-optimization` | Model routing, prompt caching, token auditing, cost governance per query | LLM API costs are too high or growing unsustainably |

### Data & Operations

| Skill | Description | When to use |
|---------|-------------|-------------|
| `/database-design` | Schema normalization, zero-downtime migrations, RLS, multi-tenancy, index strategy | Designing or reviewing a relational database schema |
| `/observability` | OpenTelemetry, RED/USE metrics, structured logs, distributed tracing, alert runbooks | Adding monitoring to a service or debugging a production incident blind |
| `/compliance-and-governance` | SOC 2, ISO 27001, GDPR, gap analysis, evidence collection automation | Preparing for a compliance audit or certification |
| `/data-engineering` | ELT pipelines, idempotent loads, data quality validation, dimensional modeling, analytics events | Building data pipelines or warehouse integrations |
| `/workflow-automation` | Spec-driven workflow design, Temporal SDK, human-in-the-loop with timeouts, idempotent steps | Automating a multi-step business process |
| `/third-party-integration` | Adapter pattern, webhook signature verification, Stripe idempotency, resilient API clients | Integrating with external APIs, payment processors, or webhook endpoints |

### Meta

| Skill | Description | When to use |
|---------|-------------|-------------|
| `/debugging` | 4-phase root cause investigation, Stop-the-Line rule, structured debug report. No fixes before diagnosis | Before proposing any fix for a bug, error, crash, or unexpected behavior |
| `/multi-agent-orchestration` | Parallel dispatch, swarm pattern, file ownership, conflict prevention, subagent prompt structure | Decomposing a task across multiple agents working concurrently |
| `/skill-creation` | CSO-optimized descriptions, TDD for documentation, progressive disclosure with `references/` | Creating or improving a Claude Code skill |

## Design Principles

- **Focused** — each skill is 150–300 lines, covering one domain
- **Trigger-optimized** — descriptions are tuned for Claude's skill discovery (CSO)
- **Actionable** — concrete patterns and checklists, not vague advice
- **Honest about scope** — every skill has "When NOT to Use" with named alternatives

## Sources

Synthesized and distilled from 15 community repositories:

| Repository | Author |
|-----------|--------|
| [agent-skills](https://github.com/addyosmani/agent-skills) | addyosmani |
| [claude-agentic-framework](https://github.com/dralgorhythm/claude-agentic-framework) | dralgorhythm |
| [claude-skills](https://github.com/alirezarezvani/claude-skills) | alirezarezvani |
| [awesome-claude-skills](https://github.com/ComposioHQ/awesome-claude-skills) | ComposioHQ |
| [gstack](https://github.com/garrytan/gstack) | garrytan |
| [andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills) | forrestchang |
| [mastra skills](https://github.com/mastra-ai/skills) | mastra-ai |
| [claude-code-owasp](https://github.com/agamm/claude-code-owasp) | agamm |
| [playwright-skill](https://github.com/lackeyjb/playwright-skill) | lackeyjb |
| [secskills](https://github.com/trilwu/secskills) | trilwu |
| [studio-recipes](https://github.com/snyk/studio-recipes) | snyk |
| [stitch-skills](https://github.com/google-labs-code/stitch-skills) | google-labs-code |
| [superpowers](https://github.com/obra/superpowers) | obra |
| [skills](https://github.com/trailofbits/skills) | trailofbits |
| [ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) | nextlevelbuilder |
