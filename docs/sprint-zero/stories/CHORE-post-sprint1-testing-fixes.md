# CHORE: Post-Sprint-1 Testing Fixes

> Chore story capturing three non-cosmetic findings from Sprint 1 testing that
> must be resolved before Sprint 2 opens. Covers boundary-contract test
> conventions, emulator project ID enforcement, and per-feature coverage gate
> enforcement.

---

## SRS Requirement ID(s)

- SRS section 5.7 (coverage thresholds)
- SRS section 9.1 (single Firebase project, emulator usage)
- Invariant #4 (single Firebase project)
- `docs/patterns/feature-pr-conventions.md` (PR conventions)

## Priority

**P0 — Must have** (blocks Sprint 2 opening)

## Story Points

5

## User Story

As a **contributor**,
I want **boundary-contract test conventions, emulator project ID enforcement,
and coverage gate enforcement**
so that **the bug class exposed by PR #29 is prevented, Invariant #4 is
mechanically enforced for emulator usage, and SRS section 5.7 coverage
thresholds are hard gates**.

## Preconditions

1. Sprint 1 testing complete.
2. 294 automated tests passing on `main`.
3. PR #29 (OTP resend hotfix) merged — the one-line fix changing
   `_phoneNumber` to `'+91$_phoneNumber'` in `OtpEntryController.resend()`.

---

## Acceptance Criteria

### Fix 1 — Boundary-Contract Tests

**Scenario 1.1 (positive — conventions doc updated):**

> Given a controller calls into a repository
> When the conventions doc (`docs/patterns/feature-pr-conventions.md`) is
> consulted
> Then it specifies that boundary-contract tests are required

**Scenario 1.2 (positive — auth boundary-contract test exists):**

> Given the auth controller calls the auth repository with a phone number
> When the boundary-contract test pattern is followed
> Then at least one test asserts the repository receives `'+91XXXXXXXXXX'`
> format, not `'XXXXXXXXXX'`

**Scenario 1.3 (negative — raw format rejected by convention):**

> Given a contributor writes a new controller-to-repository integration
> without a boundary-contract test
> When the PR is reviewed against the conventions doc
> Then the reviewer can cite the "Boundary-Contract Tests" subsection as
> grounds for requesting changes

### Fix 2 — Emulator Project ID Enforcement

**Scenario 2.1 (negative — missing `--project` flag rejected):**

> Given an agent invokes `firebase emulators:start` without `--project`
> When the PreToolUse hook runs
> Then the invocation is rejected with a clear message naming Invariant #4
> and the wrapper script

**Scenario 2.2 (positive — wrapper reads from `.firebaserc`):**

> Given a developer runs `scripts/dev/start-emulators.sh`
> When `.firebaserc` has a valid `default` alias
> Then the emulators start with that project ID

**Scenario 2.3 (negative — missing or demo alias refused):**

> Given `.firebaserc` lacks a `default` alias or the default alias is
> `demo-*`
> When `scripts/dev/start-emulators.sh` runs
> Then the script refuses to start with a clear error

### Fix 3 — Coverage Gate Enforcement

**Scenario 3.1 (positive — lefthook per-feature enforcement):**

> Given a Flutter file at `lib/features/X/` is changed and pushed
> When the lefthook pre-push hook runs
> Then it executes scoped coverage on that feature and fails the push if
> coverage < 70%

**Scenario 3.2 (negative — CI fails on per-feature regression):**

> Given a PR is opened that drops `lib/features/auth/**` coverage to 65%
> When the PR pipeline runs
> Then the coverage-gate job fails with a clear message naming the offending
> folder and the actual vs expected percentage

**Scenario 3.3 (positive — docs-only push skips gate):**

> Given a docs-only push is made (no feature folder changes)
> When the lefthook pre-push hook runs
> Then the coverage gate is skipped gracefully

**Scenario 3.4 (positive — all thresholds met, job passes):**

> Given the coverage-gate CI job runs
> When overall Flutter coverage is >= 50% and all feature folders are >= 70%
> Then the job passes

---

## Invariant Compliance

| # | Invariant | Applicability |
|---|---|---|
| 1 | Money is integer paise | **N/A.** No monetary values in this chore. |
| 2 | `simplifiedBalances` server-maintained | **N/A.** No Firestore writes in this chore. |
| 3 | System share sheet only | **N/A.** No sharing in this chore. |
| 4 | Single Firebase project | **APPLIES.** Fix 2 directly enforces this invariant by ensuring the emulator wrapper and the PreToolUse hook prevent invocations against an incorrect or missing project ID. |

---

## Definition of Done

Reference: `docs/design/08-plan/definition-of-ready-and-done.md`

- [ ] Code merged to `main` via approved PR.
- [ ] `docs/patterns/feature-pr-conventions.md` contains a "Boundary-Contract
      Tests" subsection with the required pattern and an auth example.
- [ ] At least one boundary-contract test exists asserting `'+91XXXXXXXXXX'`
      format at the controller-to-repository boundary.
- [ ] `scripts/dev/start-emulators.sh` reads project ID dynamically from
      `.firebaserc` via `jq`.
- [ ] `scripts/dev/start-emulators.sh` refuses to start when `.firebaserc`
      lacks a valid `default` alias or uses a `demo-*` alias.
- [ ] PreToolUse hook (`block-second-firebase-project.sh`) rejects
      `firebase emulators:start` invocations missing `--project`.
- [ ] Developer docs updated for the emulator wrapper changes.
- [ ] CI coverage-gate job enforces >= 70% per feature folder under
      `lib/features/*/` and >= 50% overall.
- [ ] Lefthook pre-push hook enforces >= 70% scoped coverage on changed
      feature folders and skips gracefully for docs-only pushes.
- [ ] All existing tests still passing (no regressions).
- [ ] QA reviewed and verified acceptance criteria (including negative cases).
- [ ] No open S1 or S2 bugs.

---

## Out of Scope

- Implementing new feature code (this is a chore story).
- Changing the OTP resend fix itself (already merged in PR #29).
- Adding boundary-contract tests to features other than auth (deferred to
  each feature's own story).
- Automating the boundary-contract test check in CI (manual review convention
  for now).

---

## Dependencies

| Dependency | Status |
|---|---|
| PR #29 — OTP resend hotfix | Merged |
| Sprint 1 test suite (294 tests) | Passing |
| `.firebaserc` exists in repo root | Present |
| `scripts/dev/start-emulators.sh` exists | Present |
| `docs/patterns/feature-pr-conventions.md` exists | Present |

---

## References

| Artefact | Path |
|---|---|
| SRS | `docs/OneByTwo_Requirements_Spec.md` — sections 5.7, 9.1 |
| Invariants | `.github/shared/invariants.md` — Invariant #4 |
| DoR / DoD | `docs/design/08-plan/definition-of-ready-and-done.md` |
| Feature PR conventions | `docs/patterns/feature-pr-conventions.md` |
| Test strategy | `.github/shared/test-strategy.md` |
| Emulator wrapper | `scripts/dev/start-emulators.sh` |
| Hook registry | `.github/hooks/hooks.json` |
