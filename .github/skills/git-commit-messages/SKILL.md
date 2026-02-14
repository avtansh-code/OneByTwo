---
name: git-commit-messages
description: Guide for writing structured, consistent git commit messages in the One By Two app. Use this when committing code changes, generating commit messages, or reviewing commit history quality.
---

## Commit Message Format

Follow the **Conventional Commits** specification:

```
<type>(<scope>): <subject>

[optional body]

[optional footer(s)]
```

### Type (required)

| Type | When to Use | Example |
|------|------------|---------|
| `feat` | New feature or capability | `feat(expense): add itemized bill split` |
| `fix` | Bug fix | `fix(sync): resolve duplicate entries after reconnect` |
| `refactor` | Code change that neither fixes a bug nor adds a feature | `refactor(repo): extract offline-first write pattern` |
| `test` | Adding or updating tests only | `test(split): add edge cases for 3-way equal split` |
| `docs` | Documentation changes only | `docs(arch): update database schema for tags` |
| `style` | Formatting, linting, no code logic change | `style(dart): apply dart format to expense module` |
| `perf` | Performance improvement | `perf(list): use ListView.builder for expense history` |
| `ci` | CI/CD pipeline changes | `ci(actions): add Firebase emulator test job` |
| `build` | Build system or dependencies | `build(deps): upgrade riverpod to 2.5.0` |
| `chore` | Maintenance tasks, config, tooling | `chore(firebase): update security rules deployment` |

### Scope (recommended)

Use the primary module or feature area affected:

| Scope | Maps To |
|-------|---------|
| `auth` | Authentication, OTP, session |
| `expense` | Expense CRUD, splits, categories |
| `group` | Group management, members, roles |
| `balance` | Balance calculation, debt simplification |
| `settlement` | Settlement recording, settle-all |
| `sync` | Sync engine, queue, conflict resolution |
| `notification` | FCM, in-app notifications, nudge |
| `search` | Global search, filters, sort |
| `analytics` | Spending insights, charts |
| `receipt` | Receipt upload, OCR |
| `l10n` | Localization, translations |
| `theme` | Theming, dark mode, colors |
| `a11y` | Accessibility |
| `db` | Database schema, migrations, DAOs |
| `functions` | Cloud Functions (callable, triggers, scheduled) |
| `rules` | Firestore/Storage security rules |
| `logging` | Logging system, log outputs |
| `router` | Navigation, deep links |
| `deps` | Dependency updates |
| `actions` | GitHub Actions workflows |

### Subject (required)

- Use **imperative mood**: "add", "fix", "remove" — not "added", "fixed", "removed"
- Lowercase first letter, no period at end
- Max 72 characters
- Be specific: what changed and why it matters

**Good:**
```
feat(expense): add percentage split with largest remainder rounding
fix(balance): recalculate on expense soft-delete
perf(db): add composite index on (group_id, created_at)
```

**Bad:**
```
updated code                    ← too vague
Fix bug                         ← no scope, no detail
feat: stuff                     ← meaningless subject
Added the new feature for...    ← past tense, too long
```

### Body (optional, recommended for non-trivial changes)

- Separated from subject by a blank line
- Explain **what** and **why**, not how (the diff shows how)
- Wrap at 72 characters per line
- Reference requirement IDs when implementing features

```
feat(expense): add itemized bill split

Implement item-level splitting where individual items from a bill can
be assigned to specific participants. Tax and tip are distributed
proportionally to each person's subtotal using the Largest Remainder
Method.

Implements: EX-03
```

### Footer (optional)

```
# Breaking change
BREAKING CHANGE: balance pair key format changed from
"userA-userB" to "min(A,B)_max(A,B)"

# Issue/task references
Implements: EX-03
Fixes: #142
Closes: #155

# Co-authorship (always include for AI-assisted commits)
Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
```

## Multi-File Commit Guidelines

| Scenario | Approach |
|----------|----------|
| Feature spanning entity → DAO → repo → provider → screen | Single commit with `feat` type |
| Feature code + tests for that feature | Single commit (tests belong with the feature) |
| Unrelated bug fix discovered while working on a feature | Separate commit (`fix` type) |
| Formatting/lint fixes mixed with logic changes | Separate commit (`style` type first, then `feat`/`fix`) |
| Dependency update + code changes using new API | Single commit with `build` type if primarily about the upgrade |
| Database migration + new feature using new table | Single commit with `feat` type, mention migration in body |

## Sprint-Aligned Commits

When working through sprints from the implementation plan, reference task IDs:

```
feat(auth): implement phone OTP login flow

Set up Firebase Auth with phone/OTP verification. Includes OTP input
screen, resend timer, and error handling for invalid/expired codes.

Task: S1-04
Implements: UM-01, UM-03
```

## Commit Hygiene Rules

1. **Atomic commits** — each commit is a single logical change that compiles and passes tests
2. **No WIP commits** on main/develop — squash before merging
3. **No secrets** — ever, even if "just testing" (use `.env` files in `.gitignore`)
4. **Run before committing:**
   ```bash
   flutter analyze && flutter test
   ```
5. **Sign commits** when possible (`git commit -S`)

## Examples by Sprint Phase

```bash
# Sprint 1: Foundation
feat(auth): implement phone OTP authentication with Firebase Auth
chore(firebase): configure dev/staging/prod Firebase projects
build(deps): add riverpod, go_router, sqflite, freezed dependencies

# Sprint 3: Expenses
feat(expense): add expense entity, DAO, and repository with offline-first writes
feat(expense): implement equal split with remainder distribution
test(split): add unit tests for all split types with invariant checks

# Sprint 5: Sync
feat(sync): implement sync queue with exponential backoff retry
fix(sync): handle version conflict with user prompt for amount changes

# Sprint 8: Itemized
feat(expense): add itemized bill split with per-item participant assignment
docs(arch): update database schema for expense_items table

# Bug fixes
fix(balance): correct canonical pair key ordering for user IDs with underscores
fix(sync): clear retry count on successful sync after reconnect
```
