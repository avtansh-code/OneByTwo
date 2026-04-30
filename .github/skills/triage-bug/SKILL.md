---
name: triage-bug
description: >
  Use when a bug report needs to be classified by severity, root cause area
  identified, and assigned to the appropriate developer agent.
---

# Triage Bug

## When to use

When a bug report has been filed and needs severity classification, root cause
analysis, reproduction confirmation, and assignment to the correct developer.

## When NOT to use

- When the issue is a feature request (use `new-user-story` instead).
- When the issue is already triaged and assigned.

## Inputs

1. **Bug report** — the GitHub Issue filed using the `bug_report` template.
2. **Reproduction steps** — from the reporter.
3. **Device and OS information** — from the bug report template.

## Procedure

1. Read the bug report and reproduction steps.
2. Classify severity per SRS section 10.5:

   | Severity | Definition | SLA |
   |---|---|---|
   | S1 — Critical | Crash on launch, core flow blocked, data loss, wrong simplified balances. | Same-day hotfix. |
   | S2 — Major | Feature broken, no workaround, affects many users. | Within 3 business days. |
   | S3 — Minor | Feature broken with workaround; cosmetic but visible. | Next sprint. |
   | S4 — Trivial | Polish, copy, edge-case visual. | Backlog. |

3. Identify the root cause area:
   a. **Client UI** — routing, widget rendering, state management → Flutter Dev.
   b. **Client data** — Firestore reads, offline cache, models → Flutter Dev.
   c. **Cloud Functions** — simplified-debts computation, triggers → Functions Dev.
   d. **Security rules** — access denied errors, validation failures → Architect.
   e. **CI/CD** — build failures, deployment issues → DevOps.
   f. **Schema** — missing fields, wrong types → Architect.
4. Check if the bug involves an invariant violation:
   a. Wrong balance due to floating-point money? → invariant 1.
   b. Client writing simplifiedBalances? → invariant 2.
   c. Platform-specific share? → invariant 3.
   d. Wrong Firebase project? → invariant 4.
5. Assign to the appropriate agent and label with severity.
6. If S1, flag for immediate hotfix and notify DevOps.

## Output format

A triage comment on the GitHub Issue with: severity, root cause area, assigned
agent, invariant implications (if any), and recommended fix approach.

## Validation checks

- [ ] Severity is assigned per SRS section 10.5 definitions.
- [ ] Root cause area is identified.
- [ ] Assigned to the correct agent.
- [ ] Invariant implications are noted.
- [ ] S1 bugs are flagged for immediate action.

## Examples

### Positive example

**Input:** Bug report: "Group balance shows 150.5 instead of 150.50 after adding
an expense of 301 rupees split among 2 people."

**Triage output:**
- Severity: S1 (wrong balance display — potential data integrity issue).
- Root cause: likely floating-point division in the UI formatter or the split
  calculation is using `double` instead of integer paise.
- Invariant: potential violation of invariant 1 (money as integer paise).
- Assigned to: Flutter Dev (if UI formatter) or Functions Dev (if backend
  computation).
- Recommended fix: verify `amountPaise` is stored as 30100 (integer), verify
  split is [15050, 15050], verify formatter divides by 100 and formats with 2
  decimal places.

### Negative example (should refuse)

**Input:** "Triage: the app does not support Hindi language."

**Response:** Refused. Hindi localisation is listed in SRS section 12.3 as out of
scope for v1.0. This is a feature request, not a bug. File as a post-v1.0
enhancement.
