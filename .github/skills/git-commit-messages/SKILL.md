---
name: git-commit-messages
description: "Conventional Commits format guide for the One By Two project. Defines types, scopes, subject rules, and examples for consistent commit messages."
---

# Git Commit Messages

## Format

```text
type(scope): subject

[optional body]

[optional footer(s)]
Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
```

---

## Types

| Type | When | Example |
|------|------|---------|
| `feat` | New feature | `feat(expenses): add percentage split algorithm` |
| `fix` | Bug fix | `fix(balances): correct rounding in 3-way split` |
| `refactor` | Code change (no feature/fix) | `refactor(core): extract AmountFormatter utility` |
| `test` | Adding/fixing tests | `test(splits): add edge cases for single participant` |
| `docs` | Documentation only | `docs(schema): update balance collection fields` |
| `perf` | Performance improvement | `perf(list): use ListView.builder for expense list` |
| `ci` | CI/CD changes | `ci: add coverage gate to PR pipeline` |
| `build` | Build system changes | `build(android): update minSdk to 35` |
| `chore` | Other changes (deps, configs) | `chore: update dependencies` |
| `style` | Formatting (no logic change) | `style: run dart format` |

---

## Scopes

Scopes map to app modules. Use the most specific scope that applies:

| Scope | Module |
|-------|--------|
| `auth` | Authentication (login, OTP, profile) |
| `groups` | Group management |
| `expenses` | Expense CRUD and split logic |
| `friends` | Friend pairs and 1:1 expenses |
| `settlements` | Settlements and payments |
| `balances` | Balance calculation and display |
| `notifications` | Push and in-app notifications |
| `analytics` | Spending analytics and charts |
| `search` | Global search and filters |
| `core` | Core utilities, errors, extensions |
| `theme` | Theme, colors, typography |
| `l10n` | Localization (ARB files) |
| `firebase` | Cloud Functions, rules, Firebase config |
| `ci` | CI/CD pipelines and workflows |

### Rules

- Scope is **optional** but strongly encouraged.
- Use lowercase, no spaces.
- If a change spans multiple modules, use the primary module or omit the scope.
- CI-only changes can use `ci` as both type and scope: `ci: add coverage gate`.

---

## Subject Rules

1. **Imperative mood:** "add feature" not "added feature" or "adding feature"
2. **Lowercase first letter:** "add" not "Add"
3. **No period at end:** "add feature" not "add feature."
4. **Max 72 characters:** Keep it concise
5. **Describe what changed,** not what you did

### Good vs. Bad

| ❌ Bad | ✅ Good |
|--------|---------|
| `Added new split feature` | `add percentage split algorithm` |
| `Fixing the bug` | `correct rounding in 3-way split` |
| `Updated tests.` | `add edge cases for single participant` |
| `Changes` | `extract AmountFormatter utility` |
| `WIP` | `add skeleton for itemized split screen` |

---

## Body Guidelines

- Explain **why** the change was made (the diff shows **what**).
- Wrap at **72 characters** per line.
- Separate from subject with a **blank line**.
- Use bullet points for multiple reasons.

```text
feat(expenses): add itemized bill splitting

Implement per-item assignment to users with automatic
sum validation. Uses Largest Remainder Method for fair
distribution of remainders.

- Items can be assigned to one or more users
- Unassigned items are split equally among all members
- Total of item amounts must equal expense total
```

---

## Footer

### Breaking Changes

```text
feat(auth): switch from email to phone-only authentication

BREAKING CHANGE: Email login is no longer supported.
Users must re-authenticate with phone number.
```

### Issue References

```text
Closes #123
Fixes #456
Refs #789
```

### Co-authored-by

Always include when Copilot assists:

```text
Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
```

---

## Complete Examples

### Feature

```text
feat(expenses): add itemized bill splitting

Implement per-item assignment to users with automatic
sum validation. Uses Largest Remainder Method for fair
distribution of remainders.

Closes #42
Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
```

### Bug Fix

```text
fix(balances): correct canonical pair ordering for friend balance

The friend pair ID was not consistently using lexicographic
ordering, causing duplicate balance documents. Now always
uses min(userA, userB)_max(userA, userB).

Fixes #78
Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
```

### Refactor

```text
refactor(core): extract AmountFormatter from expense widgets

Move Indian number formatting (lakhs/crores) into a
dedicated utility class. Eliminates duplicate formatting
logic across 7 widget files.

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
```

### Performance

```text
perf(groups): lazy-load member avatars in group list

Replace eager loading of all member avatars with
on-demand loading using CachedNetworkImage. Reduces
initial group list load time by ~40% for groups with
10+ members.

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
```

### CI

```text
ci: add Firestore rules test to PR pipeline

Run security rules unit tests on every PR targeting
main. Fails the build if any rule test fails.

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
```

### Breaking Change

```text
feat(sync): migrate offline queue from Hive to Drift

Replace Hive-based sync queue with Drift (SQLite) for
better query support and transaction safety.

BREAKING CHANGE: Existing offline queue entries in Hive
will be lost on upgrade. Users should sync all pending
changes before updating.

Closes #112
Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
```

---

## Squash Merge Convention

When a PR is merged via squash merge, the **PR title becomes the commit message** on the target branch. Therefore:

- PR titles MUST follow conventional commit format: `type(scope): subject`
- Individual commits on the feature branch are squashed away
- Write good PR titles — they become the permanent history

Example:

- Feature branch has 5 commits: "wip", "add entity", "fix test", "cleanup", "final"
- PR title: `feat(expenses): add Expense domain layer with split algorithms`
- After squash merge, develop branch gets ONE commit: `feat(expenses): add Expense domain layer with split algorithms`

---

## Quick Reference

```text
feat(scope): add new capability
fix(scope): correct broken behavior
refactor(scope): restructure without behavior change
test(scope): add or update tests
docs(scope): update documentation
perf(scope): improve performance
ci: update CI/CD pipeline
build(scope): change build configuration
chore: maintenance task
style: formatting only
```
