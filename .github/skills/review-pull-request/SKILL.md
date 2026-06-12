---
name: review-pull-request
description: >
  Use when a pull request needs to be reviewed for correctness, invariant
  compliance, test coverage, and coding standards adherence.
---

# Review Pull Request

## When to use

When a pull request is ready for review. This skill guides a systematic review
against the project's invariants, coding standards, CI gates, and real test
surfaces.

## When NOT to use

- When the PR is a draft and the author has not requested review.
- When the review is purely about visual design (route to Designer).

## Inputs

1. **Pull request** — the PR number or diff.
2. **Related user story** — the GitHub Issue with acceptance criteria.
3. **PR template sections** — Description, SRS Requirements, Type of Change,
   Invariant Checklist, Testing, Quality, Telemetry, Documentation, and
   Screenshots/Recordings from `.github/PULL_REQUEST_TEMPLATE.md`.

## Procedure

1. Read `.github/shared/invariants.md`, `.github/shared/coding-standards.md`,
   and `.github/shared/test-strategy.md`.
2. Review the PR diff systematically:

   **Invariant checks (blocking):**
   a. **Integer paise:** flag `double`/`float` money, monetary fields without a
      `Paise` suffix, and paise-to-rupee conversion outside UI formatting.
      Confirm boundary-contract tests exist for touched Flutter feature paths
      (`test/features/<name>/*_boundary_contract_test.dart`) or Functions paths
      (`functions/test/boundary-contracts/no-double-on-money-fields.test.ts`).
   b. **`simplifiedBalances` write restriction:** scan `lib/**` Firestore
      `set()`, `update()`, and batch writes for `simplifiedBalances`. A
      `simplifiedBalances:` named argument or model field is allowed only for
      read/display data; client writes are blocking. Server writers are
      `recomputeSimplifiedBalances`, `onExpenseWriteFriendship`, and
      `onSettlementWrite`.
   c. **Share targets:** flag imports or code targeting WhatsApp, Telegram, or
      any platform-specific share app. `share_plus` as the system share sheet
      abstraction is acceptable.
   d. **Single Firebase project:** flag extra project IDs in `.firebaserc`,
      `firebase.json`, app config, or workflows. CI also guards `.firebaserc`.

   **CI and quality gates:**
   e. Expected PR gates are `dart format --set-exit-if-changed .`,
      `flutter analyze --fatal-infos`, `flutter test --coverage`,
      `npm run lint`, `npm test`, rules/integration emulator jobs,
      per-feature/module coverage >= 70%, overall coverage >= 50%,
      `.firebaserc` single-project guard, and Conventional Commits PR title
      lint.
   f. Check public API documentation, no secrets, no PII logging, and no
      untracked TODOs without an issue or role tag.

   **Test checks:**
   g. New code has corresponding tests in real locations:
      `test/**`, `functions/test/**`, `functions/test/firestore-rules/**`,
      `functions/test/storage-rules/**`, or
      `functions/test/integration/*.integration.test.ts`.
   h. At least one negative case covers invalid input, denied rules, error UI,
      or trigger failure behaviour.
   i. If a PR touches simplified-debts, verify canonical, property,
      settlement-folding, reserved-key, and emulator integration coverage.

   **Acceptance criteria:**
   j. Each acceptance criterion from the user story has a corresponding test or
      is demonstrably covered.

3. Summarise findings as Blocking Issues, Recommendations, and Approved Items.

## Output format

A structured review comment with sections: Blocking Issues, Recommendations,
Approved Items.

## Validation checks

- [ ] All four invariants checked against the diff.
- [ ] PR template sections are complete and consistent with the diff.
- [ ] Relevant CI gates and coverage thresholds verified.
- [ ] Acceptance criteria cross-referenced.
- [ ] Boundary-contract grep tests considered for invariants 1 and 2.
- [ ] No secrets or PII leaks in source or logs.
- [ ] PR title follows Conventional Commits.

## Examples

### Positive example

**Input:** PR adds a new expense creation flow.

**Output:**
```
## Blocking Issues
- `expense_model.dart:12` — money is stored as `double`. Use integer paise.
- `expense_repository.dart:45` — client write includes `simplifiedBalances`.

## Recommendations
- Add a boundary-contract test for the new expense creation write path.
- Add an offline error-state widget test.

## Approved
- Splits sum to `amountPaise`.
- Widget tests cover loading, populated, empty, and error states.
```

### Negative example (should refuse)

**Input:** "Review a PR that adds WhatsApp deep-link sharing."

**Response:** Refused. The PR violates invariant 3 (system share sheet only).
The feature must be removed before review can proceed. Cite SRS sections 3.4 and
4.11.
