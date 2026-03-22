---
name: pull-request-workflow
description: "Complete pull request workflow — branch naming, PR creation, description templates, review process, merge strategy, and PR size guidelines. All code changes must go through PRs."
---

# Pull Request Workflow

Complete PR-based development workflow for the **One By Two** Flutter + Firebase expense splitting app. All code must go through PRs — direct pushes to main are not allowed.

---

## 1. Golden Rule: No Direct Pushes to Main

```text
⛔ NEVER push directly to main or develop
✅ ALL changes go through Pull Requests
✅ ALL PRs must pass CI checks before merge
✅ ALL PRs must have at least 1 approval
✅ ALL PRs must be up-to-date with target branch
```

Branch protection is enforced via GitHub settings on `main` and `develop`.

---

## 2. Branch Naming Convention

```text
{type}/{sprint}-{task-id}-{short-description}

Types:
  feature/  — New feature development
  fix/      — Bug fixes
  hotfix/   — Critical production fixes (targets main directly)
  refactor/ — Code improvement (no behavior change)
  test/     — Adding or fixing tests
  docs/     — Documentation changes
  ci/       — CI/CD pipeline changes
  chore/    — Dependencies, tooling, config

Examples:
  feature/S0-theme-design-system
  feature/S1-auth-otp-flow
  feature/S3-01-expense-domain-layer
  fix/BUG-42-split-rounding-error
  hotfix/BUG-99-balance-sign-flipped
  test/S3-split-algorithm-edge-cases
  ci/add-coverage-gate-to-pr-pipeline
  docs/update-database-schema
```

---

## 3. PR Creation Workflow

```text
1. CREATE branch from develop (or main for hotfix):
   git checkout develop
   git pull origin develop
   git checkout -b feature/S3-01-expense-domain-layer

2. IMPLEMENT the feature (commit as you go):
   git add -A
   git commit -m "feat(expenses): add Expense entity with freezed"
   git commit -m "feat(expenses): add ExpenseRepository interface"
   git commit -m "test(expenses): add unit tests for Expense entity"

3. PUSH branch:
   git push -u origin feature/S3-01-expense-domain-layer

4. CREATE PR via GitHub CLI:
   gh pr create \
     --title "feat(expenses): add Expense domain layer" \
     --body-file .github/PULL_REQUEST_TEMPLATE.md \
     --base develop \
     --assignee @me \
     --label "sprint:S3,layer:domain"

5. WAIT for CI checks to pass (all 7 jobs)

6. REQUEST review (or auto-assigned)

7. ADDRESS review feedback (push new commits)

8. MERGE via squash merge (after approval + CI green)
```

---

## 4. PR Description Template

The PR template is saved as `.github/PULL_REQUEST_TEMPLATE.md` and is automatically populated when creating a PR via the GitHub UI or with `--body-file`.

The template includes sections for:

- **Summary** — what the PR does
- **Sprint & Task** — traceability
- **Type of Change** — feature, fix, refactor, etc.
- **Changes Made** — bullet list
- **Architecture Layer** — domain, data, presentation, core, firebase, CI/CD
- **Testing** — unit, widget, integration, coverage
- **Money Handling** — paise-only, split verification, remainder tests
- **Offline Behavior** — offline support, sync indicators
- **Checklist** — analyze, format, dartdoc, l10n, secrets, changelog
- **Screenshots / Evidence** — before/after for UI changes

---

## 5. PR Size Guidelines

| Size   | Lines Changed | Guidance                                      |
|--------|--------------|-----------------------------------------------|
| **XS** | < 50         | Ideal for fixes, config changes               |
| **S**  | 50-200       | Good for a single feature layer               |
| **M**  | 200-500      | Acceptable for a complete feature              |
| **L**  | 500-1000     | Split if possible, needs thorough review       |
| **XL** | > 1000       | ⚠️ Must split. Too large for effective review. |

**Rules:**

- Prefer smaller, focused PRs over large omnibus PRs
- One PR per task/feature is ideal
- A full Clean Architecture feature can be split into:
  1. PR 1: Domain layer (entity + interface + use case)
  2. PR 2: Data layer (model + mapper + source + repo)
  3. PR 3: Presentation layer (providers + screens + widgets)
  4. PR 4: Tests (if not included in above PRs)

---

## 6. Draft PRs

Use draft PRs for work-in-progress:

```bash
gh pr create --draft --title "WIP: feat(expenses): add expense flow"
```

- Draft PRs run CI but don't require reviews
- Convert to ready when complete: `gh pr ready`
- Use for: early feedback, CI verification, team visibility

---

## 7. Review Process

```text
PR Author:
  → Creates PR with description filled out
  → Assigns reviewer(s)
  → Ensures CI is green before requesting review

Reviewer (code-reviewer agent or human):
  → Checks the code review checklist (critical + important items)
  → Leaves actionable comments with suggested fixes
  → Approves or requests changes
  → Never approves if critical issues exist

PR Author:
  → Addresses all comments
  → Pushes fixes as new commits (don't force-push during review)
  → Re-requests review

Merge:
  → Squash merge to keep clean history
  → PR title becomes the squash commit message
  → Delete source branch after merge
```

---

## 8. Merge Strategy

- **Default: Squash and merge** — all PR commits squashed into one clean commit
- **Commit message:** PR title is used (must follow conventional commits format)
- **Branch deletion:** Auto-delete source branch after merge
- **Merge requirements:** All CI checks green + 1 approval + branch up-to-date

```bash
# Merge via CLI
gh pr merge --squash --delete-branch

# If branch is behind:
git checkout feature/my-branch
git rebase develop  # or: git merge develop
git push --force-with-lease
```

---

## 9. Conflict Resolution

```text
When PR has merge conflicts:
1. git checkout feature/my-branch
2. git fetch origin
3. git rebase origin/develop
4. Resolve conflicts in each file
5. git add <resolved-files>
6. git rebase --continue
7. git push --force-with-lease
```

**Rules:**

- Always rebase on latest develop before merge
- Never force-push to main or develop
- Use `--force-with-lease` (not `--force`) on feature branches

---

## 10. PR Labels

| Label                          | Meaning                    |
|--------------------------------|----------------------------|
| `sprint:S0` through `sprint:S9` | Sprint identifier          |
| `layer:domain`                 | Domain layer changes       |
| `layer:data`                   | Data layer changes         |
| `layer:presentation`           | Presentation layer changes |
| `layer:core`                   | Core utilities             |
| `layer:firebase`               | Cloud Functions / rules    |
| `priority:P0` through `priority:P3` | Bug severity         |
| `type:feature`                 | New feature                |
| `type:fix`                     | Bug fix                    |
| `type:hotfix`                  | Critical production fix    |
| `type:refactor`                | Refactoring                |
| `type:test`                    | Test addition              |
| `type:docs`                    | Documentation              |
| `type:ci`                      | CI/CD changes              |

---

## 11. GitHub CLI Cheat Sheet

```bash
# Create PR
gh pr create --title "feat(scope): description" --base develop

# List open PRs
gh pr list

# Check PR status (CI checks)
gh pr checks

# View PR diff
gh pr diff

# Merge PR (squash)
gh pr merge --squash --delete-branch

# Request review
gh pr edit --add-reviewer username

# Create draft PR
gh pr create --draft

# Mark draft as ready
gh pr ready
```
