---
name: pull-request-management
description: Guide for creating, reviewing, and managing pull requests in the One By Two app. Use this when asked to create a PR for the current branch, review a PR, check PR status, or manage PR workflows.
---

## Creating a Pull Request

When asked to create a PR for the current branch:

### 1. Gather Context

```bash
# Current branch and remote
git branch --show-current
git remote -v | head -1   # extract owner/repo

# Commits since main
git log --oneline main..HEAD

# Ensure pushed
git push origin $(git branch --show-current)
```

### 2. PR Title Format

Use Conventional Commits format: `<type>(<scope>): <summary>`

| Type | When |
|------|------|
| `feat` | New feature |
| `fix` | Bug fix |
| `refactor` | Restructuring, no behavior change |
| `ci` | CI/CD changes |
| `docs` | Documentation only |
| `test` | Tests only |
| `chore` | Dependencies, config, tooling |

Scopes: `auth`, `expenses`, `groups`, `sync`, `firestore`, `ui`, `functions`, `actions`

### 3. PR Description Template

```markdown
## Summary
Brief description of what and why.

## Changes
- Key changes grouped by area

## Testing
- [ ] `flutter analyze` — zero warnings
- [ ] `flutter test` — all pass
- [ ] Manual testing (if UI changes)

## Screenshots
(Before/after for UI changes)

## Notes
Caveats, follow-ups, reviewer guidance.
```

### 4. Create via GitHub MCP

Extract owner/repo from `git remote -v`, then use GitHub MCP tools to create the PR.

**Rules:**
- Base branch: `main` (unless specified)
- Link issues: "Closes #N" or "Fixes #N" in description
- Use draft for WIP

---

## Reviewing a Pull Request

When asked to review PR #N:

### 1. Gather PR Data (parallel calls)

```
pull_request_read (method: get)              → title, author, description, branch
pull_request_read (method: get_diff)         → full diff
pull_request_read (method: get_files)        → changed files list
pull_request_read (method: get_status)       → CI check results
```

### 2. Apply Review Checks

| Priority | Check |
|----------|-------|
| 🔴 Blocker | Money as `double`, hard deletes, PII in logs, missing auth, domain importing Flutter |
| 🟠 Important | Missing `syncStatus`, uncaught exceptions, missing Result pattern, hardcoded strings |
| 🟡 Suggestion | Missing `const`, log level mismatch, missing duration logging |

**Also check:**
- `.g.dart`/`.freezed.dart` regenerated if models changed
- ARB files updated if new user-facing strings
- Tests included for new features
- DB migration added if schema changed

### 3. Output Format

```
## PR Review: <title>

### Verdict: LGTM / Changes Requested / Needs Discussion

### 🔴 Blockers
[file:line] Description → Why → Fix

### 🟠 Important
[file:line] Description

### 🟡 Suggestions
[file:line] Description

### ✅ What Looks Good
- Positive callouts
```

---

## Getting PR Status

When asked for PR status, gather all data and present a dashboard:

### 1. Collect Data (parallel calls)

```
pull_request_read (method: get)                → metadata
pull_request_read (method: get_status)         → CI checks
pull_request_read (method: get_reviews)        → review verdicts
pull_request_read (method: get_review_comments)→ open threads
pull_request_read (method: get_files)          → change stats
```

### 2. If CI Failed

Use `get_job_logs` with the failed job ID to extract the error cause.

### 3. Present Dashboard

```
## PR #N: <title>
**Status:** Open | **CI:** ✅ Passing | **Reviews:** 1 approved

| Field | Value |
|-------|-------|
| Branch | `feature/x` → `main` |
| Author | @username |
| Files | 12 changed (+340, −85) |
| CI | ✅ Analyze · ✅ Test · ✅ Build Android · ⏳ Build iOS |
| Reviews | ✅ @reviewer approved |
| Threads | 2 resolved, 1 open |

### Open Threads
1. [file.dart:42] "Comment text" — @reviewer (unresolved)

### Failed Checks
❌ Build Android — `google-services.json missing` (see logs)
```

---

## Listing Pull Requests

```
Use: list_pull_requests (state: "open" | "closed" | "all")

Present as:
| PR | Title | Author | State | CI | Updated |
|----|-------|--------|-------|-----|---------|
| #5 | feat(auth): phone OTP | @user | Open | ✅ | 2h ago |
```

---

## Searching Pull Requests

```
Use: search_pull_requests
- By author: query "author:username"
- By label: query "label:bug"
- By text: query "fix sync in:title"
- Combined: query "author:username is:open"
```

---

## Quick Reference: MCP Tools

| Task | Tool | Parameters |
|------|------|------------|
| PR details | `pull_request_read` | method: `get` |
| PR diff | `pull_request_read` | method: `get_diff` |
| Changed files | `pull_request_read` | method: `get_files` |
| CI status | `pull_request_read` | method: `get_status` |
| Review comments | `pull_request_read` | method: `get_review_comments` |
| Reviews | `pull_request_read` | method: `get_reviews` |
| PR comments | `pull_request_read` | method: `get_comments` |
| List PRs | `list_pull_requests` | state, sort, direction |
| Search PRs | `search_pull_requests` | query, owner, repo |
| Workflow runs | `actions_list` | method: `list_workflow_runs` |
| Failed job logs | `get_job_logs` | job_id or run_id + failed_only |
