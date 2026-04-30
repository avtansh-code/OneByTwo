---
name: review-pull-request
description: >
  Use when a pull request needs to be reviewed for correctness, invariant
  compliance, test coverage, and coding standards adherence.
---

# Review Pull Request

## When to use

When a pull request is ready for review. This skill guides a systematic review
against the project's invariants, coding standards, and test coverage requirements.

## When NOT to use

- When the PR is a draft and the author has not requested review.
- When the review is purely about visual design (route to Designer).

## Inputs

1. **Pull request** — the PR number or diff.
2. **Related user story** — the GitHub Issue with acceptance criteria.
3. **PR template checklist** — the completed checklist from the PR description.

## Procedure

1. Read `.github/shared/invariants.md`.
2. Read `.github/shared/coding-standards.md`.
3. Read `.github/shared/test-strategy.md` for coverage thresholds.
4. Review the PR diff systematically:

   **Invariant checks (blocking):**
   a. **Integer paise:** scan for `double` or `float` used for money. Scan for
      fields named `amount`, `balance`, `share` without `Paise` suffix. Flag any
      monetary arithmetic using floating-point division.
   b. **`simplifiedBalances` write restriction:** scan `lib/**` for any Firestore
      `set()`, `update()`, or `batch.set()` call that writes to
      `simplifiedBalances`. Flag as blocking.
   c. **Share targets:** scan imports for packages containing `whatsapp`, `wa_share`,
      `telegram`, or similar platform-specific share packages. Flag as blocking.
   d. **Single Firebase project:** scan for new project IDs in `firebase.json`,
      `.firebaserc`, or workflow files. Flag as blocking.

   **Code quality checks (non-blocking but recommended):**
   e. DartDoc / JSDoc on all public APIs.
   f. Consistent naming per coding standards.
   g. No `TODO` without issue number or agent role tag.
   h. No secrets or credentials in source.

   **Test checks (blocking if thresholds regress):**
   i. New code has corresponding unit/widget tests.
   j. At least one negative test case.
   k. Coverage does not drop below 70% (non-UI) or 50% (overall).

   **Acceptance criteria (blocking):**
   l. Each acceptance criterion from the user story has a corresponding test or
      is demonstrably covered.

5. Summarise findings as: blocking issues (must fix before merge), recommendations
   (should fix), and approvals (what looks good).

## Output format

A structured review comment with sections: Blocking Issues, Recommendations,
Approved Items.

## Validation checks

- [ ] All four invariants checked against the diff.
- [ ] Test coverage verified.
- [ ] Acceptance criteria cross-referenced.
- [ ] No secrets in source.
- [ ] Commit messages follow Conventional Commits.

## Examples

### Positive example

**Input:** PR adds a new expense creation flow.

**Output:**
```
## Blocking Issues
- `expense_model.dart:12` — `amount` field is `double`. Must be `int amountPaise`.
- `expense_repository.dart:45` — writes to `simplifiedBalances` directly. This
  field is server-maintained only.

## Recommendations
- `expense_screen.dart:78` — missing DartDoc on `_buildSplitSelector()`.
- Consider adding an offline-queue test.

## Approved
- Split validation logic correctly sums paise and shows inline error.
- Widget test covers equal, unequal, and percentage split methods.
```

### Negative example (should refuse)

**Input:** "Review a PR that adds WhatsApp deep-link sharing."

**Response:** Refused. The PR violates invariant 3 (system share sheet only). The
entire feature must be removed before review can proceed. Cite SRS sections 3.4 and
4.11.
