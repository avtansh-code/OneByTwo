# Test Strategy

Distilled from the SRS (sections 5.7, 10). This file is the authoritative reference
for QA, developer, and DevOps agents when writing or reviewing tests.

---

## Test Pyramid

| Level | Tooling | Coverage target | Owner |
|---|---|---|---|
| Unit tests | `flutter_test`, `mocktail`, `firebase-functions-test` | >= 70% of non-UI code | Flutter Dev, Functions Dev |
| Widget tests | `flutter_test`, `golden_toolkit` | Every reusable widget and key screen | Flutter Dev |
| Integration tests | `integration_test` + Firebase Emulator Suite | All critical user journeys | QA, Flutter Dev |
| Manual smoke tests | Real devices (Tier 1 matrix) | Pre-release sign-off | QA |

---

## Coverage Thresholds (CI-enforced)

- Non-UI code (repositories, services, models, algorithms): **>= 70%**.
- Overall project coverage: **>= 50%**.
- Simplified-debts module: **100% branch coverage** of the canonical test matrix.

---

## Simplified Debts — Canonical Test Matrix

The `recomputeSimplifiedBalances` Cloud Function and its pure-function core must pass
all of the following cases. These are required checks in the PR pipeline.

| Case | Description | Expected outcome |
|---|---|---|
| Empty | No expenses, no settlements. | `simplifiedBalances` is empty or all zeroes. |
| Single member | One member, one self-paid expense. | No debts; balances are zero. |
| Perfectly balanced | All members paid equally. | No debts; balances are zero. |
| Cyclic to zero | A owes B, B owes C, C owes A — net zero. | `simplifiedBalances` is empty. |
| 3-person canonical | A pays 600 for A, B, C (equal split). | B owes A 200, C owes A 200. |
| 5-person canonical | Mixed payers and splits across 5 members. | Minimised pairwise transfers; deterministic tie-breaking by ascending `userId`. |

---

## Critical User Journeys (Must-Pass in Integration)

1. First-time user: onboarding, phone OTP, profile setup, home dashboard.
2. Add friend by contact, add equally-split expense, verify simplified balance.
3. Create 4-person group, add unequal-split expense, settle one member.
4. Edit existing expense; verify balances and activity feed update.
5. Delete expense; verify recomputed simplified balances.
6. Push notification received (background + foreground); verify deep-link.
7. Offline: add expense without network, reconnect, verify sync and recomputation.
8. Dark mode: navigate every screen, verify legibility.
9. Large-data: 50+ expenses in a group; scroll performance and function SLA.
10. Account deletion: trigger flow, verify data anonymisation.
11. Share-sheet invite: correct text and deep link; system share sheet only.
12. Contact Support: mail composer with correct address and diagnostics; fallback dialog.

---

## Device and OS Coverage Matrix

| Tier | iOS | Android |
|---|---|---|
| Tier 1 (must pass) | iPhone 12, iPhone 14 (iOS 17) | Pixel 6 (Android 14), Samsung Galaxy A-series (Android 13) |
| Tier 2 (should pass) | iPhone SE 2nd gen (iOS 14) | Xiaomi Redmi (Android 11), low-end OEM (Android 8) |
| Tier 3 (best effort) | iPad portrait (post-v1.0) | Tablets (post-v1.0) |

---

## Non-Functional Testing

- **Performance:** cold-start, scroll FPS, memory — profiled with Flutter DevTools.
  Targets: cold start <= 3 s (P95), warm start <= 1 s, dashboard render <= 1.5 s.
- **Security:** Firestore rules tested with the rules-unit-testing emulator, including
  negative cases (client writing `simplifiedBalances` must be rejected).
- **Accessibility:** VoiceOver and TalkBack walkthroughs of all primary flows.
- **Localisation:** pseudolocalisation pass to catch hardcoded strings.

---

## Bug Severity Definitions

| Severity | Definition | SLA |
|---|---|---|
| S1 — Critical | Crash on launch, core flow blocked, data loss, wrong simplified balances. | Same-day hotfix. |
| S2 — Major | Feature broken, no workaround, affects many users. | Within 3 business days. |
| S3 — Minor | Feature broken with workaround; cosmetic but visible. | Next sprint. |
| S4 — Trivial | Polish, copy, edge-case visual. | Backlog. |
