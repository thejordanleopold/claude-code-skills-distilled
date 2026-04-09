---
name: skill-creation
description: |
  Use when creating a new Claude Code skill, editing or improving an existing skill, reviewing
  skill quality for discoverability and behavioral impact, structuring skills with subagent
  delegation, progressive disclosure, or phased execution. Triggers: "create a skill",
  "new skill", "edit skill", "skill quality", "SKILL.md", "skill description", "skill trigger",
  "CSO", "skill anatomy", "when to create a skill".
---

# Skill Creation

Create effective, discoverable, and reliable skills using a test-driven approach.

**Core principle:** Creating skills IS Test-Driven Development applied to process documentation. If you did not watch an agent fail without the skill, you do not know if the skill teaches the right thing.

## When to Use

- Creating a new skill for a recurring technique or workflow
- Editing an existing skill to improve quality or add missing patterns
- Reviewing a skill's description for CSO (triggering conditions, not workflow summary)
- Packaging skill content with progressive disclosure (SKILL.md + references/)
- Verifying a skill changes Claude's behavior before publishing

## When NOT to Use

- Project-specific conventions (put in CLAUDE.md instead)
- One-off solutions that won't recur across projects
- Mechanical constraints enforceable by linting or validation (automate it)
- Standard practices well-documented in official docs

## When to Create a Skill

**Create when:**
- Technique was not intuitively obvious
- You would reference this again across projects
- Pattern applies broadly (not project-specific)
- Others would benefit

---

## Skill Anatomy

```
skill-name/
  SKILL.md              # Main reference (required)
  scripts/              # Executable code
  references/           # Documentation loaded on demand
  assets/               # Files used in output (templates, fonts)
```

### SKILL.md Structure

```markdown
---
name: kebab-case-name
description: Use when [specific triggering conditions and symptoms]
allowed-tools:            # Optional: minimum tools needed
  - Read
  - Glob
---

# Skill Name

## Overview
What is this? Core principle in 1-2 sentences.

## When to Use
Bullet list with SYMPTOMS and use cases.

## When NOT to Use
Scenarios with named alternatives.

## Core Pattern / Process / Quick Reference
[Main content]

## Common Mistakes
What goes wrong + fixes.

## Verification
Checklist for output validation.
```

### Frontmatter Requirements

- **name:** Letters, numbers, and hyphens only. Verb-first active voice: `creating-skills` not `skill-creation`.
- **description:** Max 1024 characters total. Third-person, starts with "Use when..." Include specific symptoms, situations, contexts. **Never summarize the skill's workflow.**

---

## Claude Search Optimization (CSO)

The description field is the ONLY thing that controls when a skill activates.

### Critical Rule: Description = Triggering Conditions ONLY

```yaml
# BAD: Summarizes workflow — Claude may follow this instead of reading skill
description: Use when executing plans — dispatches subagent per task with code review

# GOOD: Just triggering conditions, no workflow summary
description: Use when executing implementation plans with independent tasks in the current session
```

**Why this matters:** Testing revealed that when a description summarizes workflow, Claude may follow the description as a shortcut instead of reading the full skill. A description saying "code review between tasks" caused Claude to do ONE review, even though the skill showed TWO reviews. Changing to just triggering conditions fixed it.

### Keyword Coverage

Use words Claude would search for:
- Error messages: "Hook timed out", "ENOTEMPTY", "race condition"
- Symptoms: "flaky", "hanging", "zombie", "pollution"
- Tools: Actual commands, library names, file types

---

## Progressive Disclosure

Skills use a three-level loading system:

1. **Metadata (name + description)** — Always in context (~100 words)
2. **SKILL.md body** — When skill triggers (target <500 lines)
3. **Bundled resources** — As needed (unlimited)

### Content Splitting Rules

| Content | Location |
|---------|----------|
| Principles, routing, quick references | SKILL.md (inline) |
| Code patterns under 50 lines | SKILL.md (inline) |
| Heavy reference (100+ lines) | references/ |
| Reusable scripts | scripts/ |
| Step-by-step process details | workflows/ |

All references must be one hop from SKILL.md. No reference chains (A → B → C).

---

## Workflow Skill Patterns

| Pattern | Use When | Key Feature |
|---------|----------|-------------|
| **Linear Progression** | Single path, same every time | Numbered phases with entry/exit criteria |
| **Routing** | Multiple independent paths | Routing table maps intent to workflow files |
| **Sequential Pipeline** | Dependent steps | Each stage feeds the next |
| **Safety Gate** | Destructive/irreversible actions | Two confirmation gates before execution |
| **Task-Driven** | Complex dependencies | Task tracking with dependency management |

### Phase Structure

Every phase needs:
- A number (Phase 1, Phase 2, ...)
- Entry criteria (what must be true before starting)
- Numbered actions (what to do)
- Exit criteria (how to know it is done)

Unnumbered prose instructions produce unreliable execution order.

---

## The TDD Process for Skills

### The Iron Law

```
NO SKILL WITHOUT A FAILING TEST FIRST
```

Write skill before testing? Delete it. Start over.

### RED-GREEN-REFACTOR for Skills

**RED (Baseline):**
Run pressure scenarios with a subagent WITHOUT the skill. Document:
- What choices did the agent make?
- What rationalizations did it use (verbatim)?
- Which pressures triggered violations?

**GREEN (Write Skill):**
Write the skill addressing those specific rationalizations. Run the same scenarios WITH the skill. Agent should now comply.

**REFACTOR (Close Loopholes):**
Agent found a new rationalization? Add explicit counter. Re-test until bulletproof.

---

## Bulletproofing Against Rationalization

### Close Every Loophole Explicitly

Do not just state the rule — forbid specific workarounds:

```markdown
Write code before test? Delete it. Start over.

**No exceptions:**
- Do not keep it as "reference"
- Do not "adapt" it while writing tests
- Delete means delete
```

### Build a Rationalization Table

Capture rationalizations from baseline testing:

| Excuse | Reality |
|--------|---------|
| "Too simple to test" | Simple code breaks. Test takes 30 seconds. |
| "I'll test if problems emerge" | Problems = agents cannot use skill. Test BEFORE deploying. |

---

## Anti-Pattern Quick Reference

| Anti-Pattern | Fix |
|-------------|-----|
| Missing When NOT to Use | Add with named alternatives |
| Monolithic SKILL.md (>500 lines) | Split into references/ and workflows/ |
| Reference chains (A → B → C) | All files one hop from SKILL.md |
| Unnumbered phases | Number every phase with entry/exit criteria |
| Missing exit criteria | Define what "done" means for every phase |
| No verification step | Add validation at end of every workflow |
| Description summarizes workflow | Description = triggering conditions only |
| Wrong tool for the job | Use Glob/Grep/Read, not Bash equivalents |
| Overprivileged tools | Remove tools not actually used |

---

## Quantitative Eval Framework

Before publishing any skill, verify it actually changes Claude's behavior:

1. **Run a baseline** — execute the target scenario WITHOUT the skill loaded. Document the output verbatim.
2. **Run with the skill** — execute the same scenario WITH the skill loaded.
3. **Score on 3–5 behavioral markers** — concrete, binary checks:
   - Does the specific framework or process appear in the output?
   - Is domain-specific vocabulary used correctly?
   - Is the output structured per the skill's specified format?
   - Are the required phases or steps present?
   - Are prohibited patterns absent?
4. **Target: >80% marker pass rate** before publishing. Below 80% means the skill content is too generic or the description isn't loading it reliably.
5. **If with-skill output equals baseline output**, the skill is not working — either the description needs sharper trigger conditions or the content needs to be more prescriptive.

---

## Description Optimization Loop

Treat the description as a retrieval query that must match how users actually phrase requests.

1. **Write 10 realistic trigger prompts** — things real users would type, not abstract descriptions of the skill.
2. **Test each**: does Claude load the skill for that prompt? Track pass/fail.
3. **Iterate on trigger terms** until ≥8/10 prompts activate the skill.

**Common failure:** description summarizes the workflow instead of listing trigger conditions.

```yaml
# BAD: workflow summary
description: "Covers the full lifecycle of skill development from drafting to publishing."

# GOOD: trigger conditions with keyword list
description: "Use when creating a new SKILL.md, editing an existing skill for quality or discoverability,
  or testing whether a skill changes Claude's behavior. Triggers: 'create a skill', 'edit skill',
  'skill description', 'SKILL.md', 'skill not triggering'."
```

---

## Skill Creation Checklist

### RED Phase
- [ ] Create pressure scenarios (3+ combined for discipline skills)
- [ ] Run scenarios WITHOUT skill — document baseline behavior verbatim
- [ ] Identify patterns in rationalizations/failures

### GREEN Phase
- [ ] Name uses only letters, numbers, hyphens
- [ ] YAML frontmatter with name and description (max 1024 chars)
- [ ] Description starts with "Use when..." — triggering conditions only
- [ ] Description in third person, no workflow summary
- [ ] Keywords throughout for search
- [ ] When to Use AND When NOT to Use sections
- [ ] Content addresses specific baseline failures from RED phase
- [ ] SKILL.md under 500 lines; heavy content in references/
- [ ] No broken file references; all links one hop from SKILL.md
- [ ] Run scenarios WITH skill — verify agents now comply

### REFACTOR Phase
- [ ] Identify new rationalizations from testing
- [ ] Add explicit counters for each
- [ ] Build rationalization table
- [ ] Create red flags list
- [ ] Re-test until bulletproof

### Deployment
- [ ] Validate frontmatter, naming, structure
- [ ] Commit skill and push
- [ ] Test one more time in clean context
- [ ] Do NOT batch-create multiple skills without testing each
