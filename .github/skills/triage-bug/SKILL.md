---
name: triage-bug
description: >
  Use when a bug report needs to be classified by severity, root cause area
  identified, and assigned to the appropriate developer agent.
---

# Triage Bug

## When to use

When a bug report has been filed and needs severity classification, root cause
analysis, reproduction confirmation, regression-test guidance, and assignment.

## When NOT to use

- When the issue is a feature request (use `new-user-story` instead).
- When the issue is already triaged and assigned.

## Inputs

1. **Bug report** — the GitHub Issue filed using `.github/ISSUE_TEMPLATE/bug_report.md`.
2. **Reproduction steps** — from the reporter.
3. **Device and OS information** — from the bug report template.

## Procedure

1. Classify severity using the bug report template and SRS section 10.5:

   | Severity | Definition | SLA |
   |---|---|---|
   | S1 — Critical | Crash on launch, data loss, core flow blocked, or wrong simplified balances. | Same-day hotfix. |
   | S2 — Major | Feature broken with no workaround. | Within 3 business days. |
   | S3 — Minor | Feature broken with a workaround or visible cosmetic issue. | Next sprint. |
   | S4 — Trivial | Polish or low-risk edge-case visual issue. | Backlog. |

2. Identify the root-cause area and route to the correct agent:

   | Root cause area | Examples | Agent |
   |---|---|---|
   | Flutter feature/UI | activity, auth, expenses, friends, notifications, profile, reminders, settlements, shell | Flutter Dev |
   | Groups client UI | A report expects real group screens | PM/Orchestrator: groups is not a built client feature; `lib/features/groups/` is README/.gitkeep and shell has a placeholder |
   | Cloud Functions | `recomputeSimplifiedBalances`, `onExpenseWriteFriendship`, `onSettlementWrite`, `lookupUserByPhoneNumber`, `sendReminderNotification` | Functions Dev |
   | Security rules/schema | Firestore/Storage allow/deny failures, `simplifiedBalances` write restriction, group/friendship schema | Architect |
   | CI/CD/emulators | GitHub Actions, Firebase Emulator Suite, `.firebaserc` single-project guard | DevOps |
   | Test gap only | Missing regression coverage with no product code defect | QA |

3. Check invariant implications:
   a. Wrong money, fractional money, or paise/rupee conversion outside UI →
      invariant 1.
   b. Client writing `simplifiedBalances` → invariant 2.
   c. Platform-specific sharing → invariant 3.
   d. Wrong or extra Firebase project → invariant 4.
4. Recommend the regression test location:
   a. Flutter widget/unit bug → `test/features/<feature>/..._test.dart`.
   b. Flutter invariant 1/2 contract → `test/features/<feature>/*_boundary_contract_test.dart`.
   c. Functions unit/trigger bug → `functions/test/<module>/*.test.ts`.
   d. Simplified-debts bug → `functions/test/simplified-debts/*.test.ts` and,
      if persistence is involved, `functions/test/integration/*.integration.test.ts`.
   e. Rules bug → `functions/test/firestore-rules/` or
      `functions/test/storage-rules/`.
   f. Emulator journey bug → `functions/test/integration/*.integration.test.ts`;
      Flutter flow stubs live under `test/integration/<feature>/`.
5. Assign to the appropriate agent and label with severity. If S1, flag for
   immediate hotfix and notify DevOps.
6. Assign the issue to a sprint milestone by SLA, per
   `.github/shared/milestone-tracking.md`: S1 / S2 to the current active sprint,
   S3 to the next sprint, S4 to `Post-v1.0` unless a sprint is already committed.

## Output format

A triage comment on the GitHub Issue with: severity, root cause area, assigned
agent, invariant implications, regression-test location, sprint milestone, and
recommended fix approach.

## Validation checks

- [ ] Severity matches the bug report template definitions.
- [ ] Root cause area maps to the real feature/function set.
- [ ] Groups status is handled correctly when relevant.
- [ ] Assigned to the correct agent.
- [ ] Invariant implications are noted.
- [ ] Regression-test location is specified.
- [ ] The issue is assigned to a sprint milestone by SLA per
      `.github/shared/milestone-tracking.md`.
- [ ] S1 bugs are flagged for immediate action.

## Examples

### Positive example

**Input:** Bug report: "Friend balance shows 150.5 instead of 150.50 after adding
an expense of 301 rupees split between two people."

**Triage output:**
- Severity: S1 if persisted/displayed balance is wrong; otherwise S3 if only
  cosmetic formatting with correct paise storage.
- Root cause: Flutter formatter or split calculation.
- Invariant: potential invariant 1 issue.
- Assigned to: Flutter Dev.
- Regression test: `test/features/expenses/..._test.dart` plus a boundary
  contract if a write path changed.

### Negative example (should refuse)

**Input:** "Triage: the app does not have group creation screens."

**Response:** This is not a bug against the current client feature set. Groups
are not built as a client feature; `lib/features/groups/` contains only
README/.gitkeep and the shell has a placeholder. Route as a feature request or
backlog item, not a defect.
