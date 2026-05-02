# Decision Log

Architecture Decision Records (ADRs) for the One By Two project.

Each ADR follows the standard format: Context, Decision, Consequences, Alternatives
Considered.

---

## ADR-0001: Simplified Debts Is the Sole Debt Mechanism

**Status:** Accepted

### Context

Expense-sharing apps typically offer both a raw "who paid whom" view and an optional
simplified-debts view. Maintaining two parallel representations increases code
complexity, creates confusion when users see different numbers on different screens,
and doubles the surface area for bugs — any error in the simplification algorithm
would contradict the raw view.

One By Two targets casual and power users in India who want a clear, single answer to
"who owes whom how much." Offering two views adds cognitive load without meaningful
benefit for the v1.0 target audience.

### Decision

Simplified Debts is the sole debt mechanism. The raw payer-to-payee debt graph is
not exposed in the UI. All "who owes whom" views, the Home dashboard, and the Settle
Up flow read from the server-maintained `simplifiedBalances` field.

### Consequences

- The `simplifiedBalances` field is the single source of truth for balance display.
- The Cloud Function `recomputeSimplifiedBalances` must be correct and well-tested;
  there is no fallback view if it produces incorrect output.
- The expense and settlement log is retained as an immutable audit trail, enabling
  full recomputation if the algorithm needs to be corrected.
- Future versions may expose a raw ledger view, but it is out of scope for v1.0.

### Alternatives Considered

- Dual view (raw + simplified): rejected for complexity and UX confusion.
- Client-side simplification: rejected because non-deterministic results across
  devices would cause user complaints.

---

## ADR-0002: Money Stored as Integer Paise

**Status:** Accepted

### Context

Floating-point arithmetic introduces rounding errors that accumulate over many
transactions. In financial applications, even a single-paisa discrepancy can erode
user trust and cause splits that do not sum to the total.

### Decision

All monetary values throughout the system — Firestore documents, Cloud Functions,
Dart models, API payloads — are stored and transmitted as `int` (Dart) or `number`
(TypeScript) representing **paise** (1 INR = 100 paise). Conversion to rupees with
two decimal places and the Indian numbering system happens exclusively at the UI
layer via a shared formatter.

### Consequences

- All developers must use integer arithmetic for money. No `double` or `float`.
- Split validation logic must verify that split shares (in paise) sum exactly to the
  expense amount (in paise).
- The UI formatter is the only place where division by 100 occurs.

### Alternatives Considered

- Store as `double` and round: rejected due to cumulative rounding errors.
- Store as string: rejected for complexity in arithmetic operations.
- Use a `Decimal` library: rejected as over-engineering for single-currency INR.

---

## ADR-0003: Single Firebase Project; Emulator Suite for Non-Production

**Status:** Accepted

### Context

Multi-environment setups (dev, staging, production) provide isolation but add
operational complexity, cost, and configuration drift risk. One By Two is a v1.0
product with a small team; the overhead of multiple Firebase projects is not
justified.

### Decision

There is exactly one Firebase project: **production**. All local development and CI
testing uses the Firebase Emulator Suite. No staging or development Firebase projects
are created.

### Consequences

- All CI pipelines must spin up the Emulator Suite for integration tests.
- Feature flags via Firebase Remote Config are used to gate risky features in
  production.
- Deployment to production requires manual approval via GitHub Environments.
- A staged rollout strategy (10%, 50%, 100%) mitigates blast radius.
- If the product grows significantly, a staging project may be reconsidered in a
  future ADR.

### Alternatives Considered

- Three projects (dev, staging, production): rejected for cost and complexity.
- Two projects (staging, production): rejected for same reasons at v1.0 scale.

---

## ADR-0004: Riverpod 2.x for State Management

**Status:** Accepted

### Context

Flutter offers several state management solutions. The SRS specifies "Riverpod 2.x
(or BLoC if architect prefers)" (section 5.7). A decision must be recorded.

### Decision

Use Riverpod 2.x as the sole state management solution.

### Rationale

- Riverpod is compile-safe and does not depend on `BuildContext` for provider access,
  making it easier to test and refactor.
- Riverpod 2.x supports code generation (`riverpod_generator`) for reduced
  boilerplate.
- The team is starting fresh with no legacy BLoC code to maintain.
- PR #4 successfully used `StateNotifierProvider` for the phone entry controller,
  confirming the pattern works well in practice.

### Consequences

- All state lives in Riverpod providers, organised by feature folder.
- Developers must follow the Riverpod documentation and conventions for
  `AsyncNotifier`, `StreamProvider`, and `FutureProvider`.

### Alternatives Considered

- BLoC: viable but more verbose; would require separate event/state classes for
  every interaction.
- Provider (predecessor to Riverpod): rejected as Riverpod is its spiritual
  successor with better testing support.
- GetX: rejected for lack of type safety and community controversy.

---

## ADR-0005: System Share Sheet Only, No Platform-Specific Share Targets

**Status:** Accepted

### Context

Users expect to share invite links and balance summaries with friends. The question
is whether to deep-link to specific apps (WhatsApp, Telegram) or use the platform's
native share sheet.

### Decision

All outbound sharing uses the platform's system share sheet exclusively. The app
does not target, deep-link to, or import packages for any specific messaging app.

### Consequences

- The user chooses the channel (SMS, WhatsApp, Telegram, email, etc.) via the OS
  share picker.
- No third-party share SDKs are added as dependencies.
- Pre-tool-use hooks block imports of platform-specific share packages.
- Future versions may add specific integrations (e.g., UPI deep links for
  settlement) but sharing remains system-sheet-only for v1.0.

### Alternatives Considered

- WhatsApp as default share target: rejected per SRS section 12.2. Coupling to a
  single platform limits reach and introduces a maintenance burden.
- Multiple deep-link targets (WhatsApp + Telegram + SMS): rejected for scope and
  complexity.

---

## ADR-0006: Support via mailto Link with Address in Firebase Remote Config

**Status:** Accepted

### Context

Users need a way to contact support. Options range from a simple email link to
full helpdesk integrations (Freshdesk, Zoho Desk, Intercom). For v1.0, the product
team decided to keep it simple.

### Decision

The Profile screen includes a "Contact Support" action that opens the device's
default mail client via a `mailto:` URL. The email body is pre-filled with
diagnostic context (userId, app version, OS, device model). The support email
address is read from Firebase Remote Config so it can be changed without an app
update.

### Consequences

- No third-party helpdesk SDK dependency.
- The support email address can be rotated without a client release.
- If no mail client is configured on the device, a fallback dialog shows the
  support email address with a "Copy" button (FR-SH-04).
- If support volume justifies it, a dedicated helpdesk can be considered
  post-v1.0 (SRS section 12.3).

### Alternatives Considered

- Freshdesk / Zoho Desk integration: rejected for v1.0 scope and dependency weight.
- In-app contact form: rejected; adds UI complexity without clear benefit over email.
- No support channel: rejected; users must have a path to report issues.

---

## ADR-0007: `signup_started` Event Fires on Valid Phone Number Submission

**Status:** Accepted

### Context

The telemetry plan (`docs/design/07-technical/telemetry-plan.md`, section 1.1) defines
`signup_started` as firing "when the user reaches the phone-entry screen from
onboarding." The user story (`docs/sprint-zero/first-story-FR-AU-01.md`, scenario 1)
defines it as firing "when the user taps Continue with a valid number." These are
different funnels: the former measures intent to sign up, the latter measures valid
submission.

PR #4 implemented the story file's definition. The contradiction was surfaced during
the PR #4 retrospective.

### Decision

`signup_started` fires on valid phone number submission (user taps Continue with a
valid 10-digit number), not on screen mount. This aligns with the user story and
matches the implementation shipped in PR #4.

A separate event, `phone_entry_viewed`, fires on screen mount and captures the
"reached the signup screen" funnel. This event is specified in the screen spec
(SCR-03) and will be implemented in PR #6 or PR #7.

### Consequences

- The telemetry plan (design document) must be updated to align with this decision.
  **Escalated:** the telemetry plan is a design document and requires explicit
  approval before modification.
- The `signup_started` trigger in `docs/design/07-technical/telemetry-plan.md` section
  1.1 should be changed from "User reaches the phone-entry screen from onboarding" to
  "User taps Continue with a valid 10-digit number on the phone-entry screen."
- `phone_entry_viewed` captures the screen-mount funnel and must be implemented
  alongside the other SCR-03 events.

### Alternatives Considered

- Fire on screen mount (telemetry plan's original definition): rejected because it
  conflates "opened the screen" with "started signing up." Users who open the screen
  and navigate away have not meaningfully started signup.
- Fire on both mount and submit with different event names: this is effectively the
  chosen approach — `phone_entry_viewed` for mount, `signup_started` for submit.

---

## ADR-0008: User Document Creation — Client-Side Write at Profile Setup

**Status:** Accepted

### Context

When a new user completes phone authentication for the first time and reaches the
profile-setup screen (FR-AU-06), the system must create the `users/{userId}`
Firestore document. Two approaches were evaluated: a client-side write performed by
the Flutter app during profile setup, and a server-side write performed by a Cloud
Function triggered by `auth.user().onCreate()`.

The key question is whether the user document constitutes user-authored data (which
the client may write, subject to Security Rules) or derived/protected data (which
must be written exclusively by a Cloud Function).

### Decision

The Flutter app creates the `users/{userId}` document via a single Firestore `set()`
call when the user submits the profile-setup form. The document is written with the
typed shape defined in `docs/design/07-technical/firestore-schema.md`.

Fields written at creation time:

| Field | Source | Type |
|---|---|---|
| `phoneNumber` | `FirebaseAuth.currentUser.phoneNumber` | `string` |
| `displayName` | Form input | `string` |
| `photoUrl` | Storage upload result, or `null` | `string \| null` |
| `fcmTokens` | Empty array `[]` | `array` |
| `createdAt` | Server timestamp | `timestamp` |
| `updatedAt` | Server timestamp | `timestamp` |
| `notificationPrefs` | Default map `{ newExpense: true, settlement: true, reminder: true }` | `map` |
| `locale` | `'en-IN'` (per ARCH-EXT-04) | `string` |

Firestore Security Rules enforce that `request.auth.uid == userId` and that the
document does not already exist (creation is one-shot).

**Reasoning:**

- The user document is user-authored data, not derived or protected state.
- Invariant #2 mandates server-side writes only for `simplifiedBalances` (derived
  state). The user document is not derived state; it does not fall under this
  invariant.
- Adding a Cloud Function on the critical first-signup path would introduce cold-start
  latency and an eventual-consistency window between auth completion and user-document
  availability, with no compensating benefit.
- Firestore Security Rules can enforce field presence, types, and ownership at the
  rules layer, providing adequate protection against malformed writes.

### Consequences

- The profile-setup screen is solely responsible for creating the user document. No
  Cloud Function is involved in user-document creation.
- Firestore Security Rules must validate field presence, field types, and the
  ownership constraint (`request.auth.uid == userId`) for `create` operations on
  `users/{userId}`. This is the primary line of defence against malformed documents.
- There is no eventual-consistency window on signup: the user document is available
  immediately after the `set()` call resolves, and subsequent screens can read it
  without polling or retry logic.
- If a future requirement demands server-derived fields on the user document (e.g., a
  computed trust score), a Cloud Function can be added to update those specific fields
  without changing the creation strategy. The creation remains client-side; the
  server would perform a subsequent `update()`.
- Integration tests must cover the one-shot creation constraint: a second `set()` call
  for the same `userId` must be rejected by Security Rules.

### Alternatives Considered

**Option B — Cloud Function on `auth.user().onCreate()`:** A Cloud Function fires
when Firebase Auth creates a new user and writes a minimal skeleton `users/{userId}`
document containing `phoneNumber` and `createdAt`. The profile-setup screen then
performs a separate `update()` to add `displayName` and optionally `photoUrl`.

This option was rejected for the following reasons:

- Cold-start latency on the critical first-signup path. The user would land on the
  profile-setup screen before the Cloud Function has finished executing, requiring
  polling or retry logic to wait for the skeleton document.
- Two writes instead of one, increasing Firestore write costs and complexity.
- The eventual-consistency window between auth completion and document availability
  would require defensive client-side code (loading states, retries, error handling
  for a missing document), adding complexity to the profile-setup screen with no
  user-facing benefit.
- The user document is not derived state. Server-side creation solves a security
  problem that the project invariants do not define and that Security Rules already
  address adequately.

### Implication for PR #9

1. The profile-setup screen writes the full `users/{userId}` document via a single
   Firestore `set()` call, using the field shape specified above.
2. Firestore Security Rules must enforce: (a) `request.auth.uid == userId`,
   (b) the document must not already exist for `create` operations, (c) all required
   fields are present and correctly typed.
3. Storage Security Rules must allow authenticated users to write to
   `avatars/{userId}` only when their UID matches `userId`.
4. Integration tests must verify: (a) a first-time user successfully creates the
   document, (b) a returning user skips profile setup and is not prompted to create
   the document again, (c) a duplicate creation attempt is rejected by Security
   Rules.

---

## ADR-0009: Sealed-Union Auth State Pattern for Cold-Start Race Handling

**Status:** Accepted

### Context

When the app launches, Firebase Auth state resolves asynchronously. The profile-
setup and home screens depend on knowing both (a) whether the user is
authenticated and (b) whether they have a complete profile document. A simple
boolean `isLoggedIn` is insufficient — there are four distinct states during
cold start: loading, unauthenticated, authenticated but no profile, and
authenticated with profile.

### Decision

Use a Dart sealed class `AuthState` with four subtypes: `AuthLoading`,
`AuthUnauthenticated`, `AuthenticatedNoProfile`, `AuthenticatedWithProfile`.
The `authStateProvider` (`StreamProvider`) emits these states by combining
`FirebaseAuth.authStateChanges()` with a Firestore document existence check.
The app's root widget pattern-matches on the sealed type to determine the
correct route.

### Consequences

- All auth-gated navigation uses exhaustive pattern matching on the sealed type,
  eliminating impossible states.
- Future state machines (e.g., onboarding, payment) should follow the same
  sealed-union pattern.
- The pattern was established in PR #10 (FR-AU-06) and refined in PR #11
  (FR-AU-07/08).

### Alternatives Considered

- Boolean flags (`isLoggedIn`, `hasProfile`): rejected because combinations
  create impossible states.
- Enum without data: rejected because some states carry associated data (e.g.,
  `AuthenticatedWithProfile` carries the `UserModel`).

---

## ADR-0010: Field-Level Firestore Security Rules Using affectedKeys()

**Status:** Accepted

### Context

Firestore documents may contain a mix of user-editable fields (e.g.,
`displayName`) and server-managed fields (e.g., `simplifiedBalances`).
Invariant 2 requires that `simplifiedBalances` is never written by clients. A
blanket deny on update would prevent users from editing their own fields. The
rules must selectively allow updates to some fields while denying writes to
protected fields.

### Decision

Use `request.resource.data.diff(resource.data).affectedKeys()` in Firestore
Security Rules to inspect which fields a client write attempts to modify. Deny
any write that includes a protected field in the affected set. Example:
`!request.resource.data.diff(resource.data).affectedKeys().hasAny(['simplifiedBalances'])`.

### Consequences

- Every Firestore collection with mixed user-authored and server-managed fields
  must use this pattern in its update rule.
- Protected fields are enumerated explicitly in the rule — adding a new
  protected field requires a rule update.
- The pattern was established in PR #12 (FUNC-01/Firestore rules) for both
  `friendships` and `groups` collections.
- Negative tests must verify that writes to protected fields are rejected.

### Alternatives Considered

- Separate subcollections for server-managed data: rejected for query complexity
  and cost.
- Field masks in client SDK: rejected because Security Rules are the
  enforcement boundary, not client-side conventions.

---

## ADR-0011: Cloud Function Module Layout — Pure Algorithm Plus Function Boundary

**Status:** Accepted

### Context

Cloud Functions that perform complex business logic (e.g., simplified-debts
computation) benefit from separating the pure algorithm from the Firebase-
dependent boundary code. This enables algorithm testing without the Firebase
SDK, clearer responsibility boundaries, and reuse of the algorithm in different
trigger contexts.

### Decision

Every Cloud Function follows a three-module layout:

- `algorithm.ts` — pure business logic with no Firebase imports. Input and
  output are plain TypeScript types. Fully testable with standard Jest.
- `function.ts` — function boundary: input validation, Firestore reads/writes,
  error mapping, logging. Imports the algorithm module. Testable with mocked
  Firestore.
- `index.ts` — wiring: exports the callable/trigger function, injects
  dependencies, pins the region to `asia-south1`.

### Consequences

- Algorithm unit tests achieve 100% coverage without Firebase emulators.
- Function boundary tests mock Firestore for speed and isolation.
- Integration tests run against the full emulator suite.
- The five-layer test pyramid (algorithm unit, algorithm property, boundary,
  rules, integration) follows from this separation.
- The pattern was established in PR #12 (FUNC-01) with
  `simplified-debts/algorithm.ts`, `function.ts`, and `index.ts`.

### Alternatives Considered

- Single-file function: rejected for testability and clarity. Mixing Firestore
  calls with algorithm logic creates tight coupling.
- Two-file split (algorithm + handler): rejected because the wiring (region
  pinning, export) deserves its own file to keep the boundary clean.

---
