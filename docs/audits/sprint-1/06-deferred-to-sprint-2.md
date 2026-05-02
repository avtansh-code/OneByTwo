# Deferred to Sprint 2

Items from the Sprint 1 boundary audit (Bucket B) that should be addressed during
Sprint 2 as chore work or folded into feature PRs at natural moments.

Source: `docs/audits/sprint-1/00-triage-summary.md`

---

## Code Chores

| ID | Item | Natural Moment | Owner |
|---|---|---|---|
| M1 | Rename `authStateNotifierProvider` → `authStateProvider` (10+ files) | Standalone chore PR early in Sprint 2 | Flutter Dev |
| T3 | Clarify `signup_otp_submitted` event (not in telemetry plan) | Next OTP screen touch | Flutter Dev |
| T4 | Add missing secondary telemetry events (`otp_send_requested`, `phone_entry_viewed`, etc.) | Next auth screen touch | Flutter Dev |
| T5 | Fix `is_new_user` parameter type (int → bool) | Next OTP controller touch | Flutter Dev |
| M4 | Relocate core providers to `lib/core/providers/` | When Sprint 2 features need shared providers | Flutter Dev |
| SC1 | Add concurrent submit guard test for phone entry | Next phone entry touch | Flutter Dev |
| SC3 | Add `MAX_SAFE_INTEGER` overflow test for algorithm | Standalone chore or expense PR | Functions Dev |

## Documentation Chores

| ID | Item | Natural Moment | Owner |
|---|---|---|---|
| CV2 | Add coverage section to PR description template | Before Sprint 2 PR #15 | QA |
| S1 | Splash screen timeout/error alignment (PM decision) | Sprint 2 polish | PM |
| S3 | Phone entry OTP error: inline vs snackbar (PM decision) | Sprint 2 polish | PM |
| S4 | Phone entry live formatting (XXXXX XXXXX) | Sprint 2 polish | Flutter Dev |
| S5 | OTP resend exhausted message text alignment | Next OTP touch | Flutter Dev |
| SR8 | Expense event naming asymmetry (decide convention) | Before first expense PR | PM |
| CN3 | Jest config separation in conventions doc | Folded into CN1 (done in PR #14) | — |
| CN4 | CF-specific PR checklist items | Sprint 2 CF PR | Architect |

## Dependency Upgrades

| ID | Item | Timeline | Owner |
|---|---|---|---|
| D1 | Riverpod 3.x migration (2.x → 3.x) | Dedicated chore PR, Sprint 2 or 3 | Flutter Dev |
| D2 | `share_plus` upgrade (10 → 13) | Before first share-using PR | Flutter Dev |
| D4 | `build_runner` upgrade (discontinued transitives) | When convenient | Flutter Dev |
| D5 | `firebase-functions` 7.x evaluation | Before Sprint 2 CF work | Functions Dev |
| D6 | npm audit moderate vulnerabilities (resolve via upgrade) | When firebase-admin/functions upgraded | DevOps |
| D7 | Jest 30, TypeScript 6, ESLint 9 major bumps | When convenient | Functions Dev |

## Test Coverage Gaps (for unshipped features)

| ID | Item | Timeline | Owner |
|---|---|---|---|
| R1-R2 | Friendship rules create/update validation tests | Sprint 2 friendship PR | QA |
| R3 | Friendship delete deny test | Sprint 2 friendship PR | QA |
| R4-R5 | Group rules create/update validation tests | Sprint 3 groups PR | QA |
| R6 | Group delete deny test | Sprint 3 groups PR | QA |
| R7 | Storage rules file-size constraint test | Sprint 2 chore | QA |
| R8 | Storage rules content-type constraint test | Sprint 2 chore | QA |
| SC2 | OTP auto-retrieval timeout test | Android auto-read refinement | Flutter Dev |
| SC4 | Large group (100+) scalability test | Sprint 3 groups | Functions Dev |

## Infrastructure

| ID | Item | Timeline | Owner |
|---|---|---|---|
| RT2 | Add CI step duration logging for trend monitoring | Sprint 2 | DevOps |
| PY3 | Expand integration tests for Sprint 2 cross-feature flows | Sprint 2 | QA |
| INV2 | Share-sheet verification tests | When sharing features are implemented | QA |
| S2_sec | Release pipeline secrets (Google Play, TestFlight) | Before Sprint 6 | DevOps |
| SR12 | DPDP compliance legal sign-off scheduling | Before Sprint 6 | PM |
