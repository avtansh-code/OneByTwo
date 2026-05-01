# FR-AU-07: Session Persistence and Auto-Login

> Implementation-ready user story for session persistence and auto-login.
> Covers automatic session restoration on cold start and correct routing
> based on authentication and profile state.

---

## SRS Requirement ID(s)

FR-AU-07 (SRS section 4.1)

## Priority

**P0 — Must have**

## Story Points

2

## User Story

As a **returning user**,
I want the **app to remember my authenticated session**
so that **I do not need to re-enter my phone number and OTP every time I open
the app**.

## Preconditions

1. User has previously signed in via phone OTP (FR-AU-03/04/05).
2. Firebase Auth has persisted the session to disk (default SDK behaviour;
   no custom persistence layer).

---

## Acceptance Criteria

### Scenario 1 — Auto-login with completed profile

> Given a user signed in on a previous session and has a complete profile
> (Firestore user doc exists with `displayName`)
> When they open the app (cold start)
> Then they see the splash screen briefly, followed by the home placeholder
> screen, without re-entering OTP
> And `splash_auth_check_completed` fires with `result: 'home'`

### Scenario 2 — Cold start after sign-out

> Given a user has signed out (FR-AU-08)
> When they open the app
> Then they see the phone entry screen
> And `splash_auth_check_completed` fires with `result: 'phone'`

### Scenario 3 — Cold-start timeout recovery

> Given a user is mid-cold-start (auth state still loading)
> When 3 seconds elapse without resolution
> Then a "Having trouble?" recovery option appears on the splash screen
> And tapping it signs the user out and returns them to phone entry

### Scenario 4 — Persisted auth user without profile

> Given a persisted auth user exists but their Firestore user-doc is missing
> `displayName` (e.g., interrupted profile setup)
> When the app opens
> Then they are routed to the profile-setup screen (consistent with FR-AU-06)
> And `splash_auth_check_completed` fires with `result: 'profile_setup'`

### Scenario 5 (Negative) — Network outage on cold start

> Given a network outage on cold start
> When the app opens
> Then the app does NOT block forever waiting for Firestore
> And auth state from `firebase_auth` is local-disk-backed and sufficient to
> make the routing decision
> And the user-doc check uses the Firestore offline cache for a fast result
> And if neither network nor cache can resolve the user doc, the splash screen
> shows the "Having trouble?" recovery option after 3 seconds

---

## Telemetry Events

| Event name | Trigger | Parameters |
|---|---|---|
| `app_launched` | Splash screen mounts on cold start | `platform`, `app_version` |
| `splash_auth_check_started` | Auth state check begins | -- |
| `splash_auth_check_completed` | Auth state check resolves | `result`, `duration_ms` |
| `splash_auth_check_failed` | Auth state check fails (network error) | `error_type` |
| `splash_retry_tapped` | User taps Retry in error state | `attempt_number` |

---

## Invariant Applicability Assessment

| # | Invariant | Applicability |
|---|---|---|
| 1 | Money is integer paise | N/A. No monetary values in this story. |
| 2 | `simplifiedBalances` server-maintained | N/A. No balance reads or writes. |
| 3 | System share sheet only | N/A. No sharing in this story. |
| 4 | Single Firebase project | Applicable. Only the production Firebase project is configured. Testing uses the Firebase Emulator Suite. |

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
| Screen spec | `docs/design/06-screen-specs/01-05-auth-and-profile-setup.md` (SCR-01) |
| Wireframe | `docs/design/04-wireframes/auth-flow.md` (section 1, Splash Screen) |
| State management | `docs/design/07-technical/state-management.md` (section 2.1, `authStateProvider`) |
| Firestore schema | `docs/design/07-technical/firestore-schema.md` (`users/{userId}`) |
| Telemetry | `docs/design/07-technical/telemetry-plan.md` (section 1.2) |

---

## Implementation Notes

- Session persistence relies entirely on `firebase_auth`'s built-in disk
  persistence. No `shared_preferences`, `flutter_secure_storage`, or custom
  `SessionManager` class is used.
- The auth state is modelled as a sealed union:
  `AuthLoading | AuthUnauthenticated | AuthenticatedNoProfile | AuthenticatedWithProfile`.
- A `StreamProvider<AuthState>` combines `authStateChanges()` with a Firestore
  `snapshots()` listener on `users/{uid}` (switchMap semantics) to derive the
  routing state reactively.
- The splash screen (SCR-01) is shown during `AuthLoading`. A widget-level
  3-second timer triggers the "Having trouble?" recovery option.
- The auth gate uses `ValueKey` on `MaterialApp` keyed by auth state category
  to ensure the Navigator stack is fully cleared on state transitions.
- This PR pairs with FR-AU-08 (sign-out) to validate the full loop:
  sign in, auto-login on relaunch, sign out, cold start after sign-out.

---

## Architect Notes

### Auth State Provider Shape

The auth state is modelled as a Dart sealed union with four variants:

```
AuthState
  |-- AuthLoading        (cold-start, before SDK resolves)
  |-- AuthUnauthenticated (no Firebase user)
  |-- AuthenticatedNoProfile (user exists, no/incomplete Firestore doc)
  |-- AuthenticatedWithProfile (user exists, complete Firestore doc)
```

This sealed union scales cleanly when future states are needed (e.g.,
`AccountDeletionPending`, `AccountSuspended` for FR-AU-09).

### Router Integration

The auth gate is implemented directly in `OneBytwoApp` (a `ConsumerWidget`)
rather than via `go_router`, since `go_router` is not in the current
dependency set. The `MaterialApp` receives a `ValueKey('app-$stateCategory')`
that changes when the auth state category transitions. This forces Flutter to
unmount the old `MaterialApp` (and its entire Navigator stack) and create a
fresh one — ensuring no stale authenticated routes persist after sign-out, and
no stale unauthenticated routes persist after sign-in.

### Cold-Start Loading and 3-Second Escape Hatch

The `authStateNotifierProvider` is a `StreamProvider<AuthState>`. Before the
stream emits its first value, Riverpod wraps it in `AsyncLoading`, which
maps to `SplashScreen`. The 3-second "Having trouble?" recovery option is
implemented as a widget-level `Timer` in `SplashScreen`, NOT in the provider.
This keeps the provider purely data-driven and the timeout purely
presentational.

### Two-Step State Derivation (ADR-0007 Interaction)

The state derivation is a two-step process:

1. `FirebaseAuth.authStateChanges()` emits a `User?` — this tells us whether
   any authenticated user exists. This is local-disk-backed and resolves
   instantly on cold start (no network needed).
2. `FirebaseFirestore.collection('users').doc(uid).snapshots()` tells us
   whether the user has a complete profile. This uses the Firestore offline
   cache for fast resolution, with server-side fallback.

The provider uses switchMap semantics (manual `StreamSubscription` cancellation)
to ensure that when the auth user changes (sign-in, sign-out), the previous
Firestore doc listener is cancelled before a new one is established.

### No New ADR Required

No cold-start race condition or architectural subtlety has been surfaced that
warrants a new ADR. The design follows established patterns from PR #9
(ADR-0007, ADR-0008).
