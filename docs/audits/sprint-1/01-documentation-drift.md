# Phase 1 — Documentation Drift Audit

**Date:** 2026-05-02
**Lead:** Architect
**Consulting:** PM

---

## 1.1 Screen Specs vs Implementation

| # | Location | Drift Description | Severity | Recommended Action | Owner |
|---|---|---|---|---|---|
| S1 | `docs/design/06-screen-specs/01-05-auth-and-profile-setup.md` (SCR-01, lines 14-107) | **Splash screen timeout mismatch.** Spec requires minimum 1500 ms display time. Implementation uses a 3-second timeout. Spec defines an error state with "Retry" button on network failure; implementation shows "Having trouble? Sign out and start over" link after timeout instead of network error detection. | Medium | Backlog — splash screen behaviour is functional; the timeout difference is cosmetic. Network-error retry can be added when connectivity monitoring is implemented in a later sprint. Update spec to reflect the shipped 3-second timeout or update code to 1500 ms — PM to decide. | PM |
| S2 | `docs/design/06-screen-specs/01-05-auth-and-profile-setup.md` (SCR-02, lines 110-206) | **Onboarding screen (SCR-02) not implemented.** Spec describes 3 illustrated onboarding slides. Implementation routes directly from splash to phone entry. **Not a Sprint 1 delivery gap** — SCR-02 was never listed in `sprint-1-plan.md` stories. However, the spec has no deferral marker. | Low | Fix now — add a deferral note to the screen spec: "SCR-02 deferred to a future sprint. App routes directly from splash to phone entry in Sprint 1." | Architect |
| S3 | `docs/design/06-screen-specs/01-05-auth-and-profile-setup.md` (SCR-03, lines 209-315) | **Phone entry: OTP send error display method.** Spec requires a snackbar when OTP send fails. Implementation shows inline error text instead. | Medium | Backlog — inline error is functional and arguably better UX for this context. PM to decide whether to align with spec or update spec. | PM |
| S4 | `docs/design/06-screen-specs/01-05-auth-and-profile-setup.md` (SCR-03) | **Phone entry: live formatting missing.** Spec requires live "XXXXX XXXXX" formatting on the input field. Implementation shows raw 10-digit input. | Low | Backlog — formatting is a polish item. Sprint 2 can address. | Flutter Dev |
| S5 | `docs/design/06-screen-specs/01-05-auth-and-profile-setup.md` (SCR-04, lines 318-446) | **OTP resend exhausted message text mismatch.** Spec: "Maximum resend attempts reached. Please try again later." Code: "Too many attempts. Please wait a few minutes before trying again." | Low | Backlog — both messages communicate the same intent. Align text to spec during the next touch of the OTP screen. | Flutter Dev |
| S6 | Profile Setup (SCR-05) | No drift found. All requirements met: display name, avatar, photo picker, character counter, validation, loading state, PopScope. | — | None | — |

---

## 1.2 Firestore Schema vs Implementation

| # | Location | Drift Description | Severity | Recommended Action | Owner |
|---|---|---|---|---|---|
| F1 | `functions/src/simplified-debts/function.ts:134` vs `docs/design/07-technical/firestore-schema.md:108,140` | **Critical field name mismatch: `paidBy` vs `payerId`.** Schema doc defines `payerId` for expense documents. Cloud Function reads `data.paidBy`. This will cause a runtime `TypeError` when Sprint 2 expenses are created with the schema-compliant field name. The canonical test suite passes because test fixtures likely use the same wrong field name. | **High** | **Fix now** — align the function code to use `payerId` (the schema is authoritative). Update test fixtures to match. Verify all tests pass after rename. | Functions Dev |
| F2 | `firestore.rules` (lines 148-160) | **Group create validation missing `adminId` check.** Schema doc declares `adminId` as required on groups. `isValidGroupCreate()` does not validate its presence or enforce that the caller is the admin. The update rule (line 169-170) assumes `adminId` exists. | Medium | Backlog — groups are Sprint 3 scope. The rules are not exercised until then. Fix when the groups feature is implemented. | Architect |
| F3 | Dart model coverage | **Only `UserModel` exists.** Expense, settlement, friendship, and group Dart models are absent. **Not drift** — these collections are Sprint 2+ scope. The schema doc describes the full v1.0 target, not Sprint 1 deliverables. | — | Accept — models will be created when their features are implemented. | — |

---

## 1.3 Cloud Functions Catalogue vs Implementation

| # | Location | Drift Description | Severity | Recommended Action | Owner |
|---|---|---|---|---|---|
| C1 | `docs/design/07-technical/cloud-functions-catalogue.md` (section 1) | **Trigger type mismatch.** Catalogue describes `recomputeSimplifiedBalances` as an "internal module" invoked within Firestore transactions by `onExpenseWrite`/`onSettlementWrite`. Actual implementation exports it as `onCall({region: REGION}, ...)` — an HTTPS Callable function. | **High** | **Fix now** — update catalogue section 1 to accurately describe the function as an HTTPS Callable. Note that the internal-module integration with trigger functions is planned for Sprint 2 (FR-SE-03/04). | Architect |
| C2 | `docs/design/07-technical/cloud-functions-catalogue.md` (sections 2-7) | **Five of seven documented functions not implemented.** Catalogue advertises `onExpenseWrite`, `onSettlementWrite`, `onUserDelete`, `acceptGroupInvite`, `revokeGroupInvite`, `sendReminderNotification`. Only `recomputeSimplifiedBalances` is shipped. Catalogue reads as if all functions exist. | **High** | **Fix now** — add a Status column to the catalogue TOC table indicating `shipped` vs `planned` for each function, with target sprint. This prevents Sprint 2 agents from assuming these functions exist. | Architect |
| C3 | `docs/design/07-technical/cloud-functions-catalogue.md` (section 1, input/output) | **Cross-reference to non-existent functions.** Catalogue says the module "is invoked within a Firestore transaction by `onExpenseWrite` and `onSettlementWrite`". These functions do not exist. Engineers reading the catalogue may make incorrect assumptions. | Medium | Fix now — folded into C1 and C2 fixes. Clarify that trigger functions are planned, not shipped. | Architect |

---

## 1.4 State Management Doc vs Implementation

| # | Location | Drift Description | Severity | Recommended Action | Owner |
|---|---|---|---|---|---|
| M1 | `docs/design/07-technical/state-management.md:51` vs `lib/features/auth/application/auth_state_provider.dart:98` | **Provider naming: doc-vs-code mismatch.** State-management doc specifies `authStateProvider`. Code declares `authStateNotifierProvider`. Code is a `StreamProvider`, not a `StateNotifier`, making the "Notifier" suffix misleading. Both docs and code should call it `authStateProvider`. | **High** | **Fix now** — rename `authStateNotifierProvider` to `authStateProvider` in code. This is a `StreamProvider`; the current name falsely implies `StateNotifier`. Update all 10+ references across `lib/`. | Flutter Dev |
| M2 | `docs/design/07-technical/state-management.md:67,69,383` vs `lib/features/auth/application/` | **Doc-vs-doc naming inconsistency.** State-management doc uses `phoneEntryNotifierProvider`, `otpNotifierProvider`, `profileSetupNotifierProvider`. Feature-PR conventions doc (ratified) uses `phoneEntryControllerProvider`. Code matches conventions doc. The state-management doc has drifted from the ratified conventions. | Medium | Fix now — update state-management doc to use the `*ControllerProvider` names that match the ratified conventions and shipped code. The conventions doc is authoritative. | Architect |
| M3 | State-management doc (sections 2.3-2.10) | **Future provider trees not yet implemented.** Doc describes ~85 providers for Friends, Groups, Expenses, etc. None exist in code. **Not drift** — these are Sprint 2+ scope. | — | Accept — expected for Sprint 1 boundary. | — |
| M4 | `lib/features/auth/data/phone_auth_repository.dart`, `user_repository.dart` | **Provider location: feature-level vs core-level.** State-management doc section 4 says app-scoped providers live outside the feature tree (e.g., `lib/core/`). `firebaseFirestoreProvider`, `firebaseStorageProvider`, and `phoneAuthRepositoryProvider` are declared in `features/auth/data/`. | Low | Backlog — relocate to `lib/core/providers/` during Sprint 2 when more features need these providers. Currently only auth uses them, so feature-level location is pragmatic. | Flutter Dev |

---

## 1.5 Telemetry Plan vs Implementation

| # | Location | Drift Description | Severity | Recommended Action | Owner |
|---|---|---|---|---|---|
| T1 | `lib/features/auth/application/otp_entry_controller.dart:133` vs `docs/design/07-technical/telemetry-plan.md:52` | **Event name mismatch.** Code fires `signup_otp_screen_viewed`. Plan specifies `otp_screen_viewed`. | Medium | Fix now — rename to `otp_screen_viewed` to match plan. The `signup_` prefix is non-standard and not in the naming convention. | Flutter Dev |
| T2 | `docs/design/07-technical/telemetry-plan.md:23` | **`signup_completed` event missing from code.** Plan defines this as a core funnel event (fires when OTP verified and session created for a first-time user). Not logged anywhere in the codebase. | **High** | **Fix now** — this is a core funnel event per SRS section 5.10. Without it, the signup funnel cannot be measured. Add to the OTP verification success path for first-time users. | Flutter Dev |
| T3 | `lib/features/auth/application/otp_entry_controller.dart` | **`signup_otp_submitted` event not in plan.** Code fires this event but it has no corresponding entry in the telemetry plan. | Low | Fix now — either add to telemetry plan (if intentional) or remove from code (if accidental). Likely intended as `otp_verification_started` per plan. | Architect |
| T4 | Telemetry plan (section 1.2) | **Several planned Sprint 1 events not firing.** Missing from code: `otp_send_requested`, `phone_entry_viewed`, `phone_validation_failed`, `otp_verification_started`. | Medium | Backlog — these are secondary funnel events. They enhance analytics but do not block Sprint 2. Add during the next touch of auth screens. | Flutter Dev |
| T5 | `otp_verification_succeeded` event | **Parameter type mismatch.** Code logs `is_new_user` as `int` (0/1). Plan specifies `bool`. | Low | Backlog — Firebase Analytics coerces types; functional impact is minimal. Fix during next touch. | Flutter Dev |
| T6 | ADR-0007 consequence | **Telemetry plan not updated per ADR-0007.** ADR-0007 decided that `signup_started` fires on valid submission, not screen mount. The plan still shows the old trigger description ("User reaches the phone-entry screen from onboarding"). | Medium | Fix now — update telemetry plan section 1.1 to reflect ADR-0007 decision. | Architect |

---

## 1.6 Missing Architectural Decision Records

| # | Location | Drift Description | Severity | Recommended Action | Owner |
|---|---|---|---|---|---|
| A1 | `lib/features/auth/domain/auth_state.dart` (PR #10/11) | **Missing ADR: sealed-union auth state pattern.** The `AuthState` sealed class (`AuthLoading`, `AuthUnauthenticated`, `AuthenticatedNoProfile`, `AuthenticatedWithProfile`) solves the cold-start race condition. This is a generic pattern for future state machines. Not captured as an ADR. | **High** | **Fix now** — create ADR-0009: "Sealed-Union Auth State Pattern for Cold-Start Race Handling". This is the template for all future auth-gated flows. | Architect |
| A2 | `firestore.rules` (lines 117, 163) (PR #12) | **Missing ADR: field-level Firestore rules using `affectedKeys()`.** The `request.resource.data.diff(resource.data).affectedKeys()` pattern prevents client writes to protected fields. Used for `simplifiedBalances` enforcement. Template for future collections. | Medium | **Fix now** — create ADR-0010: "Field-Level Firestore Rules Using affectedKeys()". Cheap to write, high value for Sprint 2 when friendships and expenses rules are authored. | Architect |
| A3 | `functions/src/simplified-debts/` (PR #11/12) | **Missing ADR: Cloud Function module layout.** Separation of `algorithm.ts` (pure), `function.ts` (boundary), `index.ts` (wiring). Template for every future function. | **High** | **Fix now** — create ADR-0011: "Cloud Function Module Layout: Pure Algorithm + Function Boundary". Sprint 2 functions will copy this pattern; having the ADR prevents ad hoc divergence. | Architect |

---

## 1.7 Feature PR Conventions Accuracy

| # | Location | Drift Description | Severity | Recommended Action | Owner |
|---|---|---|---|---|---|
| P1 | `docs/patterns/feature-pr-conventions.md` section 3 | **Cloud Functions testing layers undocumented.** PR #12 established a 5+ layer testing pattern (algorithm unit, algorithm property, handler, rules, integration). Not mentioned in the conventions doc. | Medium | Backlog — add a Cloud Functions testing section to the conventions doc. Reference PR #12 as the exemplar. | Architect |
| P2 | `docs/patterns/feature-pr-conventions.md` section 1 | **Cloud Function module layout undocumented.** The `algorithm.ts` / `function.ts` / `index.ts` structure is not in the conventions doc. Covered by proposed ADR-0011 (finding A3). | Medium | Backlog — add to conventions doc after ADR-0011 is written. | Architect |
| P3 | Feature folder compliance | **Fully compliant.** `lib/features/auth/` and `lib/features/profile/` follow the prescribed layout. Test mirrors are correct. Commit messages follow Conventional Commits. | — | None | — |

---

## Summary

| Category | High | Medium | Low | Total |
|---|---|---|---|---|
| Screen specs (1.1) | 0 | 2 | 3 | 5 |
| Firestore schema (1.2) | 1 | 1 | 0 | 2 |
| Cloud Functions catalogue (1.3) | 2 | 1 | 0 | 3 |
| State management (1.4) | 1 | 1 | 1 | 3 |
| Telemetry (1.5) | 1 | 2 | 2 | 5 |
| Missing ADRs (1.6) | 2 | 1 | 0 | 3 |
| PR conventions (1.7) | 0 | 2 | 0 | 2 |
| **Total** | **7** | **10** | **6** | **23** |

### Preliminary Triage (Phase 6 will finalise)

**Fix now candidates (11):** F1 (paidBy bug), C1 (catalogue trigger type), C2 (catalogue
status column), M1 (authStateProvider rename), M2 (state-management doc names), T1
(otp event name), T2 (signup_completed missing), T6 (telemetry plan ADR-0007 update),
A1 (ADR-0009), A2 (ADR-0010), A3 (ADR-0011), S2 (onboarding deferral marker).

**Backlog candidates (9):** S1, S3, S4, S5, M4, T4, T5, P1, P2.

**Accept candidates (3):** F3, M3, P3.
