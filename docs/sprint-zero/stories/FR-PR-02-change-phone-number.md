# FR-PR-02: Change Phone Number

> Implementation-ready user story for changing the signed-in user's phone number
> through an OTP re-verification flow, reachable from the Edit Profile screen.
> Reuses the existing auth phone-entry and OTP screens (FR-AU-01..05) for the
> first time outside sign-in, and resolves SCR-26 Open Question #1.

---

## SRS Requirement ID(s)

FR-PR-02 (SRS section 4.2, line 175)

## Priority

**P1 — Should have**

## Story Points

5

## User Story

As a **signed-in user**,
I want to **change my phone number through an OTP re-verification flow**
so that **I can keep my account reachable on my current number without losing my
data or friendships**.

## Preconditions

1. User is authenticated and has a `users/{userId}` document in Firestore
   (FR-AU-06, shipped).
2. The Edit Profile screen is available (FR-PR-01, shipped).
3. The auth phone-entry and OTP-entry flow is available for reuse
   (FR-AU-01..05, shipped).
4. The Firestore Security Rules `phoneNumber`-immutability relaxation is in place
   (Architect dependency) so the freshly-verified number can be written.

---

## Acceptance Criteria

### AC-1 — Change phone number (happy path, two-OTP re-verification)

> Given the signed-in user is on the Edit Profile screen, where the phone number
> row now shows a tappable "Change Phone Number" affordance
> When they tap it, re-verify their CURRENT number by requesting and entering a
> correct OTP (re-authentication leg), then enter a valid new +91 10-digit number,
> request its OTP, and enter the correct code (new-number leg)
> Then the client calls
> `currentUser.updatePhoneNumber(PhoneAuthProvider.credential(verificationId, smsCode))`
> for the new number and it succeeds
> And the client forces `currentUser.getIdToken(true)` to refresh the
> `phone_number` token claim before writing Firestore
> And `users/{userId}.phoneNumber` is updated to the new `+91…` value with a fresh
> `updatedAt` server timestamp
> And the Profile View and Edit Profile screen reflect the new number via the
> existing real-time listener
> And an `OBTSnackbar(message: "Phone number updated", type: success)` is shown
> And the `phone_change_completed` telemetry event fires

The re-authentication leg is part of the normal happy path because FR-AU-07
persists the session and auto-logs in, so the last sign-in is usually older than
Firebase's recent-login window.

### AC-2 (Negative) — Invalid or non-+91 new number blocked

> Given the user is on the new-number entry step (the +91 prefix is locked, as in
> sign-in)
> When they enter a value that is not a valid 10-digit Indian mobile number (fails
> `validateIndianMobile`)
> Then an inline error "Please enter a valid 10-digit mobile number." is shown
> below the field
> And no OTP is requested and no Firebase or Firestore call is made

### AC-3 (Negative) — Wrong OTP on the new number

> Given the user has requested an OTP for a valid new number
> When they enter an incorrect 6-digit code and Firebase returns
> `invalid-verification-code`
> Then the error maps to `AuthError.invalidOtp` and its message "That code does
> not match. Please check and try again." is shown
> And the user can retry by re-entering the code without restarting the flow
> And a `phone_change_failed` event fires with `error_code: "invalid_otp"`

### AC-4 (Negative) — New number already linked to another account

> Given the user enters and verifies an OTP for a new number that is already
> linked to a different account
> When `currentUser.updatePhoneNumber(...)` returns `credential-already-in-use`
> Then the error maps to the existing `AuthError.credentialInUse` copy "This phone
> number is already linked to another account. Please contact support."
> And `users/{userId}.phoneNumber` is unchanged
> And a `phone_change_failed` event fires with `error_code: "credential_in_use"`

### AC-5 (Negative / load-bearing) — Recent-login requirement handled via re-authentication

> Given the user's last sign-in is older than Firebase's recent-login window (the
> common case under FR-AU-07 auto-login)
> When the change is attempted and Firebase would otherwise raise
> `requires-recent-login`
> Then the flow first completes the re-authentication leg —
> `reauthenticateWithCredential(...)` against the CURRENT number using the SCR-28
> "Step B: Re-authentication" pattern (current number pre-filled and read-only →
> Send OTP → OTP entry → advance on success) — and then proceeds to verify and
> apply the new number
> And if re-authentication itself cannot complete, a NEW
> `AuthError.requiresRecentLogin` variant surfaces with British copy (for example:
> "For your security, please verify your current number again before changing it.")
> And a `phone_change_failed` event fires with `error_code: "requires_recent_login"`
> only when re-authentication cannot be completed

### AC-6 (Negative) — Same number as current is blocked without an OTP

> Given the user is on the new-number entry step
> When they enter their existing phone number (the composed `+91…` equals the
> authenticated `currentUser.phoneNumber`)
> Then an inline error "This is already your phone number." is shown
> And no OTP is requested and no Firebase or Firestore call is made (no pointless
> OTP, no no-op write)

### AC-7 (Negative / Security) — Arbitrary phoneNumber write rejected by Security Rules

> Given an attacker with a valid auth token crafts a Firestore SDK write to their
> own `users/{userId}` document that sets `phoneNumber` to an arbitrary value that
> does NOT match their freshly-verified `request.auth.token.phone_number`
> When the write request reaches Firestore
> Then the Firestore Security Rules reject the write
> And the document remains unchanged
> (Verified by Firestore Security Rules unit tests against the emulator in
> `functions/test/firestore-rules/users-update.test.ts`.)

---

## Telemetry Events

All events are PII-free; the phone number (old or new) must NEVER be a parameter
(SRS section 5.4, line 308). To be added to
`docs/design/07-technical/telemetry-plan.md` §1.7 by the Flutter Dev.

| Event name | Parameters | Trigger |
|---|---|---|
| `phone_change_started` | — | User opens the Change Phone Number flow from Edit Profile |
| `phone_change_otp_requested` | `leg` (`"reauth"` / `"new_number"`) | An OTP is requested for either the re-authentication leg or the new number |
| `phone_change_completed` | — | `updatePhoneNumber` succeeds and the Firestore write completes |
| `phone_change_failed` | `error_code` (`"invalid_otp"` / `"credential_in_use"` / `"requires_recent_login"` / `"network_failure"` / `"unknown"`) | A Firebase or Firestore step fails after an OTP was requested |

Pure client-side validation rejections (AC-2 invalid number, AC-6 same number) do
not emit `phone_change_failed`; they surface inline before any OTP request,
mirroring the sign-in flow. As implemented, `error_code` carries the
`AuthError.name` (camelCase, e.g. `invalidOtp` / `credentialInUse` /
`requiresRecentLogin`), consistent with the existing `otp_send_failed` /
`otp_verification_failed` events, plus `sync_failed` for a failed Firestore sync —
the snake_case literals above are illustrative. No parameter ever carries PII.

---

## Invariant Applicability Assessment

| # | Invariant / constraint | Applicability |
|---|---|---|
| 1 | Money is integer paise | N/A. No monetary surface in this story; do not add balances. |
| 2 | `simplifiedBalances` server-maintained | N/A. This story does not touch `simplifiedBalances`. |
| 3 | System share sheet only | N/A. No sharing in this story. |
| 4 | Single Firebase project | Applicable. All auth, Firestore, and rules testing target the single production project `onebytwo-avtanshgupta`; pre-merge testing uses the Firebase Emulator Suite (project `demo-onebytwo`) per ADR-0003. |
| C1 | +91-only authentication (SRS section 3.4, line 133) | Applicable. The new number reuses the +91-locked entry and `validateIndianMobile`; international numbers are not accepted. |
| C2 | No PII in telemetry (SRS section 5.4, line 308) | Applicable. No phone number (old or new) may be logged as an event parameter. |

---

## Definition of Done

Reference: `docs/design/08-plan/definition-of-ready-and-done.md`

- [ ] Code merged to `main` via approved PR.
- [ ] Unit and widget tests written and passing (validation, two-OTP flow, error
      mapping, same-number block).
- [ ] Integration tests passing against the Firebase Emulator Suite.
- [ ] Firestore Security Rules tests verify AC-7 (arbitrary `phoneNumber` write
      rejected; matching token write allowed) in
      `functions/test/firestore-rules/users-update.test.ts`.
- [ ] QA reviewed and verified acceptance criteria (including all negative cases).
- [ ] Telemetry events in place and firing correctly, with no PII parameters.
- [ ] Accessibility verified (semantic labels, screen-reader, focus order on the
      reused phone and OTP screens).
- [ ] Dark mode checked (WCAG AA contrast ratios).
- [ ] Invariant compliance confirmed (all four) plus the +91-only and PII
      constraints.
- [ ] Documentation updated (telemetry plan §1.7; auth error codes for the new
      variant).
- [ ] No open S1 or S2 bugs.

---

## Invariant Compliance

- [ ] Money values are integer paise (invariant 1) — N/A, no monetary values.
- [ ] No client writes to `simplifiedBalances` (invariant 2) — N/A.
- [ ] Uses system share sheet only (invariant 3) — N/A.
- [ ] Single Firebase project (invariant 4) — compliant, production only; emulator
      for tests.

---

## Design Artefact References

| Artefact | Path |
|---|---|
| Edit Profile entry point | `docs/design/06-screen-specs/23-28-settle-activity-profile.md` (SCR-26) |
| Resolved open question | `docs/design/06-screen-specs/23-28-settle-activity-profile.md` (SCR-26 Open Questions, item 1, line 521) |
| Re-authentication pattern | `docs/design/06-screen-specs/23-28-settle-activity-profile.md` (SCR-28) and `docs/design/04-wireframes/profile-and-support.md` (Step B: Re-authentication) |
| Reused phone-entry / OTP flow | `lib/features/auth/` (FR-AU-01..05) |
| Auth error codes | `docs/design/07-technical/auth-error-codes.md` |
| Firestore schema | `docs/design/07-technical/firestore-schema.md` (`users/{userId}`) |
| Telemetry plan | `docs/design/07-technical/telemetry-plan.md` (§1.7) |
| Client-side write decision | `.github/shared/decision-log.md` (ADR-0008) |

---

## Responsible Agents

| Agent | Responsibility |
|---|---|
| Architect | `firestore.rules` relaxation to allow the `phoneNumber` change only to `request.auth.token.phone_number`; ADR; client contract for the mutate-current-user path; re-authentication state machine design |
| Flutter Dev | Repository `updatePhoneNumber` + `reauthenticateWithCredential`; new `AuthError.requiresRecentLogin` variant and mapping; change-phone controller/flow; gated `UserRepository` write with forced `getIdToken(true)` token refresh; Edit Profile entry point and screen states; telemetry; unit and widget tests |
| Functions Dev | Firestore Security Rules tests in `functions/test/firestore-rules/users-update.test.ts` (AC-7) |
| QA | Verify all ACs and invariants, +91 validation, rules behaviour, test coverage, accessibility, and telemetry PII-freeness |
| Designer | Confirm reuse of the existing phone-entry and OTP screens with profile-scoped copy (or raise a focused SCR note); accessibility sign-off |

---

## Implementation Notes

- **Resolves SCR-26 Open Question #1**
  (`docs/design/06-screen-specs/23-28-settle-activity-profile.md`, line 521): the
  Edit Profile screen gains a real, tappable "Change Phone Number" affordance
  (row/button). This replaces today's read-only phone field whose helper text
  reads "Phone number cannot be changed from here."
  (`lib/features/profile/presentation/edit_profile_screen.dart`, lines 140-161).
  The read-only field is superseded by the new entry point.
- **Reuse, do not fork.** The new-number step reuses the existing auth phone-entry
  screen (+91 prefix locked, 10-digit validation via `validateIndianMobile`,
  composing `+91${digits}` exactly as `phone_entry_controller.dart` does) and the
  existing 6-digit OTP-entry screen. This is the first reuse of that flow OUTSIDE
  sign-in; the screens should be parameterised with profile-scoped copy rather
  than duplicated.
- **Mechanism (precise).** On the new number, the client calls
  `currentUser.updatePhoneNumber(PhoneAuthProvider.credential(verificationId, smsCode))`
  — the mutate-current-user path. It must NOT call `signInWithCredential` (which
  would sign in / switch accounts). Note the existing
  `PhoneAuthRepository.verifyOtp` deliberately uses `signInWithCredential` for
  sign-in; a distinct repository method is required here so sign-in behaviour is
  untouched.
- **`requires-recent-login` is the common path, not an edge case.** Because
  FR-AU-07 persists the session and auto-logs in, the last sign-in is normally
  older than Firebase's ~5-minute recent-login window. The flow therefore performs
  a two-OTP re-authentication: first `reauthenticateWithCredential(...)` against
  the user's CURRENT number, then `updatePhoneNumber(...)` for the NEW number. The
  re-auth screen follows the SCR-28 "Step B: Re-authentication" pattern: current
  number pre-filled and read-only, Send OTP, OTP entry, advance on success. A new
  `AuthError.requiresRecentLogin` variant (mapping Firebase `requires-recent-login`,
  currently unmapped and falling through to `unknown`) is added for the case where
  re-authentication itself cannot complete; see
  `docs/design/07-technical/auth-error-codes.md`.
- **"Same number as current" decision (PM call).** Entering the user's existing
  number is blocked at the new-number entry step with the inline message "This is
  already your phone number." The composed `+91…` is compared against the
  authenticated `currentUser.phoneNumber` before any OTP is requested. This avoids
  a pointless OTP round-trip, a no-op Firestore write, and a confusing
  `credential-already-in-use` error from Firebase. It is treated as client-side
  validation (like the invalid-number case) and does not emit a
  `phone_change_failed` telemetry event.
- **Firestore sync (client write, gated).** On success the client writes the new
  `users/{userId}.phoneNumber` with a fresh `updatedAt`. This depends on the
  Architect-owned Firestore Security Rules relaxation that allows the `phoneNumber`
  change ONLY when it equals `request.auth.token.phone_number` (the freshly-verified
  auth phone). The client MUST force `currentUser.getIdToken(true)` AFTER
  `updatePhoneNumber` and BEFORE the Firestore write, so the `phone_number` token
  claim the rules read is fresh. Per ADR-0008, this is a client-side Firestore
  write — no Cloud Function is introduced for the sync.
- **Friendships are unaffected.** Existing friendships are UID-keyed, so no
  contact-matching migration is required; the user simply becomes discoverable by
  the new number going forward. Nothing in the friends feature changes.
- **No new dependency.** `firebase_auth` already provides `updatePhoneNumber`,
  `reauthenticateWithCredential`, and `PhoneAuthProvider.credential`; no new plugin
  and no `ios/Podfile.lock` change are needed.

---

## Out of Scope

- International or multi-number support — permanently out; authentication is
  +91-only (SRS section 3.4, line 133; SRS section 12.3). One number per account.
- Any friendship or contact-matching migration — existing friendships are
  UID-keyed and unaffected; change nothing in the friends feature.
- Account deletion (FR-AU-09) — a separate P1 story; this story only changes the
  number.
- A Cloud Function for the `phoneNumber` sync — the client-side write is preferred
  per ADR-0008.

---

## Dependencies

| Dependency | Status |
|---|---|
| FR-PR-01 — Edit Profile screen | Shipped |
| Auth phone-entry + OTP flow (FR-AU-01..05) | Shipped |
| `firestore.rules` `phoneNumber`-immutability relaxation (change allowed only to `request.auth.token.phone_number`) | Required (Architect) |
| `firebase_auth` (provides `updatePhoneNumber` / `reauthenticateWithCredential`) | Already a dependency (no new plugin, no `ios/Podfile.lock` change) |
