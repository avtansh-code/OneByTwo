# FR-AU-08: Sign Out from Profile Screen

> Implementation-ready user story for the sign-out flow.
> Covers the sign-out row on the Profile screen, confirmation dialog,
> session teardown, and telemetry.

---

## SRS Requirement ID(s)

FR-AU-08 (SRS section 4.1)

## Priority

**P0 — Must have**

## Story Points

2

## User Story

As an **authenticated user**,
I want to **sign out of the app from the Profile screen**
so that **I can end my session or allow another person to sign in on the same
device**.

## Preconditions

1. User is authenticated and has a completed profile (FR-AU-06).
2. User can reach the Profile screen.

---

## Acceptance Criteria

### Scenario 1 — Confirmation dialog appears

> Given the user is on the Profile screen
> When they tap the "Sign Out" row
> Then a confirmation dialog appears with title "Sign out?" and body "Are you
> sure you want to sign out? You will need to verify your phone number again to
> sign back in."
> And a "Cancel" outlined button and a "Sign Out" danger filled button are shown

### Scenario 2 — Sign-out confirmed

> Given the sign-out confirmation dialog is shown
> When the user taps the "Sign Out" button
> Then `firebase_auth.signOut()` is called
> And the app routes to the phone entry screen
> And no authenticated screens remain in history (no "back" navigation into a
> signed-out home)
> And `sign_out_completed` telemetry event fires

### Scenario 3 — Route stack cleared

> Given sign-out has just completed
> When the user views the route stack (e.g., presses back)
> Then no authenticated screens remain — the phone entry screen is the root
> And this is verified by the auth gate reactively observing `authStateChanges()`
> (no manual `Navigator.popUntil` is used)

### Scenario 4 (Negative) — Sign-out cancelled

> Given the sign-out confirmation dialog is shown
> When the user taps "Cancel"
> Then the dialog is dismissed
> And they remain on the Profile screen
> And no `sign_out_completed` event is recorded
> And `sign_out_cancelled` telemetry event fires

### Scenario 5 (Negative) — Sign-out failure

> Given the sign-out confirmation dialog is shown and the user taps "Sign Out"
> When `firebase_auth.signOut()` throws an error
> Then the dialog is dismissed
> And a snackbar error "Could not sign out. Please try again." is shown
> And the user remains on the Profile screen

---

## Telemetry Events

| Event name | Trigger | Parameters |
|---|---|---|
| `sign_out_completed` | User signs out successfully | -- |
| `sign_out_cancelled` | User cancels the sign-out dialog | -- |

---

## Invariant Applicability Assessment

| # | Invariant | Applicability |
|---|---|---|
| 1 | Money is integer paise | N/A. No monetary values in this story. |
| 2 | `simplifiedBalances` server-maintained | N/A. No balance reads or writes. |
| 3 | System share sheet only | N/A. No sharing in this story. |
| 4 | Single Firebase project | Applicable. `signOut()` is called on the single production `FirebaseAuth` instance. |

---

## Definition of Done

Reference: `docs/design/08-plan/definition-of-ready-and-done.md`

- [ ] Code merged to `main` via approved PR.
- [ ] Unit and widget tests written and passing.
- [ ] Integration tests passing against Firebase Emulator Suite.
- [ ] QA reviewed and verified acceptance criteria (including negative cases).
- [ ] Telemetry events in place and firing correctly.
- [ ] Accessibility verified (semantic labels, screen-reader, focus order).
- [ ] Dark mode checked (WCAG AA contrast ratios).
- [ ] Invariant compliance confirmed (all four).
- [ ] Documentation updated (if applicable).
- [ ] No open S1 or S2 bugs.

---

## Invariant Compliance

- [ ] Money values are integer paise (invariant 1) — N/A, no monetary values.
- [ ] No client writes to `simplifiedBalances` (invariant 2) — N/A.
- [ ] Uses system share sheet only (invariant 3) — N/A.
- [ ] Single Firebase project (invariant 4) — compliant, production only.

---

## Design Artefact References

| Artefact | Path |
|---|---|
| Screen spec | `docs/design/06-screen-specs/23-28-settle-activity-profile.md` (SCR-26, Sign Out Flow) |
| Wireframe | `docs/design/04-wireframes/profile-and-support.md` (section 1, destructive zone) |
| Telemetry | `docs/design/07-technical/telemetry-plan.md` (section 1.7) |

---

## Implementation Notes

- Sign-out calls `PhoneAuthRepository.signOut()` which delegates to
  `FirebaseAuth.instance.signOut()`.
- The auth state provider listens to `authStateChanges()`. When `signOut()`
  completes, the stream emits `null`, the provider transitions to
  `AuthUnauthenticated`, and the auth gate reactively routes to phone entry.
- Route stack is cleared implicitly by the auth gate's `ValueKey` on
  `MaterialApp` — no explicit `Navigator.popUntil` or `pushAndRemoveUntil`
  is needed.
- The confirmation dialog uses the platform's `AlertDialog` (per SCR-26 spec).
  "Cancel" is an outlined button in `textSecondary`; "Sign Out" is a filled
  button in `danger`.
- Sign-out does NOT clear local Firestore cache — the Firestore SDK manages
  its own cache lifecycle and security rules re-validate on next sign-in.
- Sign-out does NOT clean up FCM tokens — that is the notifications PR's
  responsibility (deferred per scope exclusion).
- Account deletion is FR-AU-09 (P1, future PR) and is explicitly out of scope.
- This PR creates a minimal Profile placeholder screen with only the sign-out
  row and basic profile header. The full Profile View/Edit is FR-PR-01 (PR #12).
