# Branch Protection Configuration

This document describes the branch protection rules for the `main` branch.
These rules ensure that no code merges to `main` without passing all required
quality gates.

---

## Required status checks

The following status checks must pass before a pull request can be merged to
`main`. Each corresponds to a job in `.github/workflows/pr.yml`.

| Status check name | Job key | Purpose |
|---|---|---|
| PR Title Lint | `pr-title-lint` | Enforces Conventional Commits format on the PR title (which becomes the squash-merge commit message). |
| Flutter Lint & Test | `flutter-checks` | Dart formatting, static analysis, unit/widget tests, and an early overall coverage signal. |
| Cloud Functions Lint & Test | `functions-checks` | ESLint, TypeScript compilation, and Cloud Functions unit tests. |
| Integration Tests (Emulator Suite) | `integration-tests` | End-to-end tests running against the Firebase Emulator Suite. |
| **Coverage Gate (SRS 5.7)** | `coverage-gate` | **Authoritative** per-feature and per-module coverage enforcement. Added by this PR. |
| Build Android (debug) | `build-android` | Debug APK build to catch Android build regressions early. |
| Build iOS (no signing) | `build-ios` | Unsigned iOS build to catch iOS build regressions early. |

---

## How to configure in GitHub UI

1. Navigate to the repository on GitHub.
2. Go to **Settings** then **Branches**.
3. Under **Branch protection rules**, click **Edit** next to the `main` rule
   (or **Add rule** if none exists, setting the branch name pattern to `main`).
4. Enable **Require status checks to pass before merging**.
5. Enable **Require branches to be up to date before merging**.
6. In the status check search box, search for and add each of the following:
   - `PR Title Lint`
   - `Flutter Lint & Test`
   - `Cloud Functions Lint & Test`
   - `Integration Tests (Emulator Suite)`
   - `Coverage Gate (SRS 5.7)`
   - `Build Android (debug)`
   - `Build iOS (no signing)`
7. Click **Save changes**.

Note: status check names must match the `name:` field in each job definition,
not the job key. GitHub discovers available check names after the workflow has
run at least once on the repository.

---

## Coverage enforcement architecture

Coverage is enforced at two layers:

### 1. Lefthook pre-push gate (early warning)

Configured in `lefthook.yml`. Runs **scoped** coverage checks only on
feature/module folders touched by the push. This keeps push-time fast while
catching regressions before they reach CI. Developers can bypass with
`git push --no-verify` when genuinely needed.

### 2. GitHub Actions coverage-gate job (authoritative)

Configured in `.github/workflows/pr.yml` as the `coverage-gate` job. Runs
after `flutter-checks` and `functions-checks` complete. This is the
**authoritative** enforcement of SRS section 5.7 thresholds:

| Scope | Threshold |
|---|---|
| Per-feature folder (`lib/features/<feature>/`) | >= 70% line coverage |
| Per-module folder (`functions/src/<module>/`) | >= 70% line coverage |
| Overall Flutter | >= 50% line coverage |
| Overall Cloud Functions | >= 50% line coverage |
| `functions/src/simplified-debts/` | 100% canonical test matrix (validated by `npm run test:canonical`, not Istanbul branch metric) |

The `coverage-gate` job is a **required status check** on `main`. PRs cannot
merge until it passes.

---

## Changing thresholds

Coverage thresholds are mandated by SRS section 5.7 and Definition of Done
section 2. They are **not project-configurable** — changing them requires a
formal SRS amendment. The current thresholds were validated during Sprint 1
(see pre-flight verification in the PR that introduced the coverage gate).

---

## Cross-references

- SRS section 5.7: coverage requirements.
- SRS section 9.2: PR pipeline design.
- `docs/patterns/feature-pr-conventions.md` section "Enforced coverage
  thresholds": describes the two-layer enforcement model.
- `.github/shared/test-strategy.md`: test pyramid and coverage thresholds.
- `lefthook.yml`: pre-push scoped coverage gate.
- `.github/workflows/pr.yml`: `coverage-gate` job definition.
