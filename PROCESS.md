# Distillation Process

How this library is built, maintained, and expanded. Reference this when adding new sources or cutting a new release.

---

## What This Library Is

A curated, synthesized collection of Claude Code skills — not a mirror. Every skill is rewritten to meet a strict quality bar: ≤300 lines, required structural sections, CSO-optimized frontmatter, and actionable checklists. Source material is raw material, not output.

---

## Phase 1: Source Discovery

Find skill repositories worth distilling from. Candidates come from:

- GitHub search: `claude skills`, `claude code skills`, `SKILL.md`
- Community lists (awesome-claude-code, etc.)
- Personal/private skill collections

For each candidate repo, scan for:
- Total skill count and domain coverage
- Signal density (concrete patterns vs. vague advice)
- Overlap with existing library (avoid duplication)
- Freshness (last updated, maintained)

**v1.0 sources:** 15 public GitHub repos, ~1,358 source SKILL.md files  
**v1.1 sources added:** `startup-iq` private (21 skills, frontend/design/media) + Darion private (70 skills, AI security/MCP/document processing/security roles)

---

## Phase 2: Triage — What to Distill

For every source skill, classify as: **New Skill**, **Enhancement to Existing**, or **Exclude**.

### Inclusion Criteria

| Criterion | Question |
|-----------|----------|
| Generalizable | Does this apply across projects, not just one product? |
| Non-obvious | Would a senior engineer already know this intuitively? |
| Actionable | Does it produce concrete output (code, checklist, decision)? |
| Non-overlapping | Does it cover ground not already in the library? |

### Exclusion Criteria (common reasons)

| Pattern | Reason to Exclude |
|---------|------------------|
| Product/persona-specific | NEO Gents operations, company-specific workflows |
| Life coaching or non-engineering | Family finance, mentorship roles |
| Requires specific installed tools | CLI-specific workflows tied to one binary |
| Pure Claude meta-behavior | Output enforcement, response formatting |
| Already covered well | Check if an existing skill absorbs 80%+ of the content |
| Duplicate with minor variation | If two source skills are near-identical, consolidate |

### Enhancement vs. New Skill Decision

**Enhance existing when:** new source adds a section, method, or checklist to a domain already covered. Keep total ≤300 lines — compress existing content to make room.

**Create new skill when:** domain has no coverage and meets all inclusion criteria.

---

## Phase 3: Distillation Rules

Every SKILL.md — new or enhanced — must follow these rules before being accepted.

### Required Structure

```markdown
---
name: kebab-case-name
description: |
  Use when [triggering conditions, symptoms, use cases]. Triggers:
  "keyword1", "keyword2", "keyword3".
---

# Skill Name

Brief overview + core principle (1-2 sentences).

## When to Use
- Bullet list of symptoms/situations

## When NOT to Use
- Alternatives named explicitly (not "use another skill")

## [Core Content — phases, patterns, reference tables, code examples]

## Verification Checklist
- [ ] item
```

### Hard Limits

- **≤300 lines** — non-negotiable. Compress to fit; never exceed.
- **Frontmatter description uses pipe `|`** for multiline — inline strings break Claude's parser.
- **Description = triggering conditions only** — never summarize the workflow in the description. If the description says what to do, Claude may follow the description instead of reading the skill body.
- **One code block minimum** — skills without examples are abstract advice, not reference.
- **Checklist required** — the exit criterion for every skill execution.

### Compression Techniques (when over 300 lines)

When adding content to a near-full skill, compress in this priority order:
1. ASCII art diagrams → single prose line
2. Redundant code examples → keep the most representative one
3. Tables with many rows → consolidate to prose with key examples
4. Compliance/regulatory tables → distill to 2-3 key rules
5. Overly verbose "rules" sections → consolidate parallel items

### CSO (Claude Search Optimization)

The description field is the only signal that controls when a skill loads. Test it:
- Write 10 realistic user prompts that should trigger this skill
- Check that ≥8/10 activate the skill
- Bad: workflow summary ("Dispatches subagents, runs reviews, integrates results")
- Good: symptom list ("Use when decomposing tasks across multiple agents. Triggers: 'parallel tasks', 'swarm', 'dispatch agents'")

---

## Phase 4: Execution — Parallel Agent Pattern

For large batches (4+ new skills or 4+ enhancements), use parallel agents to work faster without conflicts. The key rules:

1. **One agent per skill** — never two agents editing the same file
2. **File ownership is absolute** — map each agent to specific files before dispatching
3. **Max 8 concurrent agents** — beyond this, coordination overhead negates the gain
4. **Self-contained prompts** — each agent prompt includes: full task spec, source file paths to read, target file path to write, line limit constraint
5. **Batching**: run two batches of 4 for 8 new skills (Batch 1A: skills 1-4, Batch 1B: skills 5-8)

For enhancements, group non-overlapping skills per agent (e.g., B1 handles security-review + threat-modeling, B2 handles offensive-security + multi-agent-orchestration).

---

## Phase 5: Structural Audit

Before publishing, audit every skill in the library (not just new ones — enhancements can introduce regressions).

**7 conformance checks per skill:**

| Check | What to Verify |
|-------|----------------|
| Frontmatter | `name:` and `description:` present, pipe `|` for multiline |
| When to Use | `## When to Use` section exists |
| When NOT to Use | `## When NOT to Use` section exists with named alternatives |
| Code block | At least one ``` fenced code block |
| Checklist | At least one `- [ ]` item |
| Line count | `wc -l SKILL.md` ≤ 300 |
| Description CSO | Does not summarize workflow |

**All 7 must pass.** Fix failures before publishing.

---

## Phase 6: Sync and Publish

```bash
# 1. Sync skills directory to repo
rsync -av --delete ~/.claude/skills/ /tmp/claude-code-skills-distilled/skills/

# 2. Update README
#    - Update skill count (e.g., 31 → 39)
#    - Add new rows to category tables
#    - Add new sources to Sources table

# 3. Commit
git add -A
git commit -m "Add N new skills and enhance M existing skills (vX.Y)

Brief description of what changed.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"

# 4. Tag and push
git tag vX.Y
git push origin main --tags
```

---

## Phase 7: Memory Update

After publishing, update two files:

**`~/.claude/projects/-Users-jordanleopold/memory/skills-library.md`**
- Update total count in frontmatter description
- Update version tag URL
- Add new skills to their category sections
- Update source list

**`~/.claude/CLAUDE.md`**
- Update skill count in "Skills Library" section

---

## Release History

| Version | Date | Skills | What Changed |
|---------|------|--------|-------------|
| v1.0 | 2026-04 | 31 | Initial library: 15 public repos, all core engineering domains |
| v1.1 | 2026-04 | 39 | +8 new skills (animation, ai-security, mcp-development, document-processing, remotion, buttercut, expo-app-design, expo-tailwind); enhancements to 8 existing skills |

---

## Adding a Future Release

1. **Discover** new source repos or private collections
2. **Triage** each source skill (new / enhance / exclude)
3. **Plan** in plan mode — get approval before executing
4. **Execute** with parallel agents (batch by file ownership)
5. **Audit** all skills (not just new ones)
6. **Sync** to repo, update README, commit, tag, push
7. **Update** memory files and CLAUDE.md

Typical cadence: batch additions whenever 5+ new source skills are identified. Do not add skills one at a time — the audit + publish overhead is fixed cost, so batch for efficiency.
