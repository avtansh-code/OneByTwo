---
name: commit-and-branch-strategy
description: "Branch management, protection rules, merge workflows, hotfix process, and advanced git operations for the One By Two project. All code goes through PRs — no direct pushes to main."
---

# Commit & Branch Strategy

> Complements the `git-commit-messages` skill (commit message format) with branch
> management, protection rules, merge workflows, and advanced git operations.

---

## 1. Branch Architecture

```text
main ─────────────────────────────────────────────────►
  │                                    ▲
  │                                    │ (release merge)
  ▼                                    │
develop ──────────────────────────────────────────────►
  │        ▲       │        ▲       │        ▲
  │        │       │        │       │        │
  ▼        │       ▼        │       ▼        │
feature/S0-* ──┘  feature/S1-* ──┘  feature/S2-* ──┘
                                    
main ◄── hotfix/BUG-99-* (emergency fixes bypass develop)
```

**Branch roles:**

| Branch | Purpose | Created from | Merges into |
|--------|---------|-------------|-------------|
| `main` | Production-ready code. Tagged with version numbers. Protected. | — | — |
| `develop` | Integration branch. All feature branches merge here. Protected. | `main` | `main` (releases) |
| `feature/*` | Individual feature/task branches. Created from develop, merged back via PR. | `develop` | `develop` |
| `fix/*` | Bug fix branches. Created from develop. | `develop` | `develop` |
| `hotfix/*` | Emergency fixes. Created from main, merged to BOTH main and develop. | `main` | `main` + `develop` |
| `test/*` | Test-only branches. Created from develop. | `develop` | `develop` |
| `ci/*` | CI/CD changes. Created from develop. | `develop` | `develop` |
| `docs/*` | Documentation changes. Created from develop. | `develop` | `develop` |

---

## 2. Branch Protection Rules

### `main` branch

```yaml
Protection Rules:
  require_pull_request:
    required_approving_review_count: 1
    dismiss_stale_reviews: true
    require_code_owner_reviews: false
  require_status_checks:
    strict: true  # Branch must be up-to-date
    checks:
      - analyze-and-format
      - test-and-coverage
      - security-scan
      - architecture-compliance
      - cloud-functions-check
      - firestore-rules-test
      - build-check
  require_linear_history: true  # Squash merge only
  allow_force_pushes: false
  allow_deletions: false
  require_conversation_resolution: true
```

### `develop` branch

```yaml
Protection Rules:
  require_pull_request:
    required_approving_review_count: 1
  require_status_checks:
    strict: true
    checks:
      - analyze-and-format
      - test-and-coverage
      - security-scan
      - architecture-compliance
      - cloud-functions-check
      - firestore-rules-test
      - build-check
  require_linear_history: true
  allow_force_pushes: false
```

---

## 3. Daily Development Workflow

```bash
# 1. Start your day — sync with latest
git checkout develop
git pull origin develop

# 2. Create feature branch
git checkout -b feature/S3-01-expense-domain-layer

# 3. Work and commit incrementally
git add -A
git commit -m "feat(expenses): add Expense entity with freezed"

git add -A
git commit -m "feat(expenses): add ExpenseRepository interface"

# 4. Push and create PR
git push -u origin feature/S3-01-expense-domain-layer
gh pr create --title "feat(expenses): add Expense domain layer" --base develop

# 5. After PR approved and merged (squash)
git checkout develop
git pull origin develop
git branch -d feature/S3-01-expense-domain-layer  # delete local branch
```

---

## 4. Release Workflow

```bash
# 1. All sprint work merged to develop
# 2. Create release PR: develop → main
gh pr create --title "release: v1.2.0" --base main --head develop

# 3. Final testing on develop
# 4. Merge PR (squash merge)
# 5. Tag the release on main
git checkout main
git pull origin main
git tag -a v1.2.0 -m "Release v1.2.0: Sprint 3 features"
git push origin v1.2.0  # Triggers release pipeline
```

---

## 5. Hotfix Workflow (Emergency P0 Fixes)

```bash
# 1. Branch from main (not develop!)
git checkout main
git pull origin main
git checkout -b hotfix/BUG-99-balance-sign-flipped

# 2. Fix and test
git commit -m "fix(balances): correct sign in friend pair balance

The canonical pair ordering was inconsistent, causing the
balance sign to flip for some friend pairs.

Fixes #99"

# 3. PR to main (fast-track: 1 reviewer)
gh pr create --title "fix(balances): BUG-99 correct friend balance sign" --base main

# 4. After merge to main, tag patch version
git checkout main && git pull
git tag -a v1.2.1 -m "Hotfix: BUG-99 friend balance sign"
git push origin v1.2.1

# 5. ALSO merge hotfix into develop (don't lose the fix!)
git checkout develop && git pull
git merge main
git push origin develop
# OR: cherry-pick the specific commit
```

---

## 6. Commit Best Practices

**Atomic commits:**

- Each commit should be a single logical change
- Should compile and pass tests on its own (if possible)
- Don't mix feature code with formatting/refactoring

**Commit frequency:**

- Commit after completing each meaningful unit of work
- Don't accumulate all changes into one mega-commit
- A feature branch should typically have 3-10 commits

**Good commit sequence for a feature:**

```text
feat(expenses): add Expense entity with freezed
feat(expenses): add ExpenseRepository interface and use cases
feat(expenses): add ExpenseModel and mapper
feat(expenses): add ExpenseFirestoreSource
feat(expenses): add ExpenseRepositoryImpl
test(expenses): add unit tests for Expense entity and use cases
feat(expenses): add expense Riverpod providers
feat(expenses): add AddExpenseScreen UI
test(expenses): add widget tests for AddExpenseScreen
```

---

## 7. Advanced Git Operations

**Rebase feature branch on latest develop:**

```bash
git checkout feature/my-branch
git fetch origin
git rebase origin/develop
# Resolve conflicts if any
git push --force-with-lease  # Safe force push (only on feature branches!)
```

**Interactive rebase to clean up commits (before PR review):**

```bash
git rebase -i HEAD~5  # Squash/reword last 5 commits
# Mark commits as 'squash' or 'fixup' to combine
# Mark as 'reword' to change message
```

**Cherry-pick a specific commit:**

```bash
git cherry-pick <commit-sha>  # Apply a single commit to current branch
```

**Undo last commit (keep changes):**

```bash
git reset --soft HEAD~1  # Undo commit, keep staged changes
```

**Rules:**

- ⛔ NEVER `git push --force` on main or develop
- ✅ Use `--force-with-lease` on feature branches only
- ⛔ NEVER rebase main or develop
- ✅ Rebase feature branches on develop freely

---

## 8. Git Hooks (Recommended Local Setup)

```bash
# .git/hooks/pre-commit (or use husky/lefthook)
#!/bin/sh
dart format --set-exit-if-changed .
flutter analyze --fatal-infos
```

```bash
# .git/hooks/commit-msg
#!/bin/sh
# Validate conventional commit format
commit_msg=$(cat "$1")
pattern="^(feat|fix|refactor|test|docs|perf|ci|build|chore|style)\(.*\): .+"
if ! echo "$commit_msg" | grep -qE "$pattern"; then
  echo "❌ Commit message must follow: type(scope): subject"
  exit 1
fi
```

---

## 9. Stale Branch Cleanup

```bash
# List merged branches
git branch --merged develop | grep -v "main\|develop"

# Delete merged local branches
git branch --merged develop | grep -v "main\|develop" | xargs git branch -d

# Delete remote branches (already merged and deleted on GitHub)
git remote prune origin
```
