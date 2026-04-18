---
name: git-workflow
description: "Use when committing code, creating or managing branches, using git worktrees for parallel work, cleaning up merged branches, finishing a development branch, or applying trunk-based development discipline. Triggers: \"commit\", \"branch\", \"git\", \"merge\", \"PR\", \"pull request\", \"worktree\", \"git cleanup\", \"stale branches\", \"squash merge\", \"how to commit\", \"commit message\"."
---

# Git Workflow

Trunk-based development with atomic commits, disciplined branching, and safe branch cleanup.

**Core principle:** `main` is always deployable. Every commit is a complete, tested unit.

## When to Use

- Making commits (structure and message)
- Creating and managing feature branches
- Running parallel work with git worktrees
- Cleaning up merged or stale branches
- Finishing a development branch (merge/PR/discard options)

## When NOT to Use

- CI/CD pipeline configuration (use deployment skill)
- Deployment and release management (use deployment skill)

---

## Trunk-Based Development

```
main ──●──●──●──●──●──  (always deployable)
        ╲      ╱
         ●──●─╱    <-- short-lived feature branches (1-3 days max)
```

- `main` is always in a deployable state
- Feature branches live 1-3 days maximum
- No long-lived feature branches
- Merge frequently, in small increments

---

## Atomic Commits

Each commit does one logical thing. It is complete, tested, and passes CI.

### Commit Message Format

```
<type>: <short description> (50 chars max)

<optional body — the WHY, not the WHAT>
(72 chars per line)
```

**Types:** `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `perf`

```
feat: add task creation endpoint with validation

Validates title length (max 200 chars) and due date (must be future).
Required by mobile team for the v2.1 launch next week.
```

### Good vs Bad Commits

```
# Good: atomic, complete, descriptive
a1b2c3d feat: add task creation endpoint with validation
d4e5f6g test: add unit tests for task creation validation
g7h8i9j feat: add task creation UI form

# Bad: everything in one commit
x1y2z3a Add task feature, fix sidebar bug, update deps, refactor utils
```

### Commit Discipline

```
Work pattern: Implement slice → Test → Verify → Commit → Next slice
```

- ~50-200 lines per commit
- Never "WIP" commits on shared branches
- If a commit message needs "and" — split it

---

## Branching Strategy

```
main (always deployable)
  +-- feature/task-creation    (1-3 days)
  +-- fix/duplicate-tasks      (hours)
  +-- refactor/auth-middleware  (1-2 days)
```

**Naming:** `feature/<desc>`, `fix/<desc>`, `chore/<desc>`, `refactor/<desc>`, `docs/<desc>`

**Rules:**
- One concern per branch
- Branch from latest `main`
- Merge back to `main` within 1-3 days
- Delete branch after merge

---

## Git Worktrees (Parallel Work)

Run multiple branches simultaneously without stashing:

```bash
# Create worktrees for parallel features
git worktree add ../project-feature-a feature/task-creation
git worktree add ../project-feature-b feature/user-settings

# List active worktrees
git worktree list

# Remove when done
git worktree remove ../project-feature-a
```

**Safety rules:**
- Verify worktree directory is in `.gitignore` before creating project-local worktrees
- Run `npm install` (or equivalent) in new worktree
- Run tests to establish clean baseline before starting work

---

## Finishing a Development Branch

When implementation is complete and tests pass, choose one of 4 options:

| Option | When |
|--------|------|
| **1. Merge locally** | Small team, no PR review needed |
| **2. Push and create PR** | Code review required |
| **3. Keep branch as-is** | Work in progress, coming back |
| **4. Discard** | Spike or experiment, not keeping |

```bash
# Option 1: Merge locally
git checkout main
git merge --no-ff feature/task-creation
git branch -d feature/task-creation

# Option 2: Push and open PR
git push -u origin feature/task-creation
gh pr create --title "Add task creation" --body "..."

# Option 4: Discard
git checkout main
git branch -D feature/task-creation
```

---

## Safe Branch Cleanup

### Phase 1: Fetch and Prune

```bash
git fetch --prune  # Remove remote-tracking branches that no longer exist on remote
```

### Phase 2: Group by Prefix, Then Categorize

Group branches by prefix BEFORE categorizing — this prevents treating two independent `feature/` branches as superseding each other:

```bash
git branch -a | sort  # Groups feature/*, fix/*, chore/* together visually
```

| Category | Meaning | Delete? |
|----------|---------|---------|
| **SAFE_TO_DELETE** | Fully merged into default branch | Yes (`git branch -d`) |
| **SQUASH_MERGED** | Work incorporated via squash merge | Yes (`git branch -D`) |
| **SUPERSEDED** | Older iteration, newer branch has the work | Yes (`git branch -D`) |
| **UNPUSHED_WORK** | Has commits not pushed to remote | Keep |
| **LOCAL_WORK** | Unique commits not in any remote branch | Keep |

### Phase 3: Detection Commands

```bash
# Branches merged into main (safe to delete)
git branch --merged main

# Check if branch has unique commits vs main
git log main..feature/old-branch --oneline

# Check if branch is squash-merged (work incorporated but not standard merge)
git cherry -v main feature/old-branch  # Empty = all commits in main
```

### Phase 4: Two Confirmation Gates

**Gate 1 — Show, don't delete:**
```bash
echo "Branches to delete:"
echo "  $safe_branches" | tr ' ' '\n'
echo "Confirm deletion? (y/N)"
```

**Gate 2 — Execute only after explicit confirmation:**
```bash
git branch -d $branch    # Safe delete (fails if unmerged work)
git branch -D $branch    # Force delete (squash-merged only — confirm first)
```

Report what was deleted, what was skipped, and why.

**Never touch protected branches:** `main`, `master`, `develop`, `release/*`, `production`

---

## Common Rationalizations to Reject

| Rationalization | Reality |
|----------------|---------|
| "I'll commit when the feature is done" | One giant commit is impossible to review, debug, or revert |
| "I'll clean up the branch later" | Branches multiply; clean up on merge |
| "This doesn't need a PR" | Code review catches things authors miss |
| "I'll squash everything into one commit" | Multiple logical commits are easier to bisect |

## Verification Checklist

**Commits:**
- [ ] Commit message follows format (`type: description`)
- [ ] Message body explains WHY if non-obvious
- [ ] Each commit is atomic (one logical change)
- [ ] Tests pass before committing

**Branches:**
- [ ] Branch named descriptively (`feature/`, `fix/`, `refactor/`)
- [ ] Branched from latest main
- [ ] Branch age <3 days
- [ ] Deleted after merge

**Cleanup:**
- [ ] `git fetch --prune` run
- [ ] Merged branches identified with `git branch --merged`
- [ ] No branches older than 30 days without active work
- [ ] Protected branches not touched
