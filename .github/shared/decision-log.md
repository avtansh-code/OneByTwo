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

## ADR-0012: Sprint 1 Boundary Audit — Accepted Trade-Offs

**Status:** Accepted

### Context

The Sprint 1 boundary audit (2026-05-02) identified several items that are
intentional trade-offs or acceptable current states of the codebase. They are
documented here so future audits do not re-open them as defects.

### Accepted Items

- Dart models currently exist only for `UserModel`; expense, settlement,
  friendship, and group models are deferred until their corresponding Sprint 2+
  features are implemented — Phase 1.2, finding F3.
- The provider tree documents the full v1.0 target state, but only the auth and
  profile slices were implemented in Sprint 1. Roughly 5 of about 90 documented
  providers exist today; the remainder will be built sprint-by-sprint —
  Phase 1.4, finding M3.
- The Cloud Functions test pyramid is intentionally security-heavy, with rules
  tests accounting for roughly 48% of coverage effort rather than a more typical
  ~20%. This is justified by Invariant 2, which requires strong enforcement that
  `simplifiedBalances` remains server-maintained and client-read-only —
  Phase 2.4, finding PY2.
- The field-level `affectedKeys()` diff pattern has not been promoted to a fifth
  invariant. ADR-0010 captures the pattern adequately today, and promotion would
  be premature until more collections, including groups, rely on it —
  Phase 3.4, finding INV4.

### Consequences

These items are accepted as-is. They should not be flagged in future audits
unless circumstances change; for example, if a deferred model becomes necessary
for an in-scope feature and still does not exist, that would become a new
finding rather than a known acceptance.

### Alternatives Considered

- Recording the items only in the audit summary: rejected because accepted
  trade-offs should live in the durable decision log.
- Creating one ADR per finding: rejected because the findings share the same
  acceptance rationale and are easier to maintain as a single note.

---

## ADR-0013: Contact Matching Strategy — Local Intersection vs Server-Side Matching

**Status:** Accepted

### Context

PR #31 introduces a contact picker for the Add Friend flow (FR-FR-01). When the
user selects a contact, the app must determine whether that person is already a
One By Two user. Two broad strategies exist for performing this match:

1. **Local matching:** contacts remain on-device; lookup is performed by querying
   Firestore for the selected phone number.
2. **Server-side matching:** the device uploads phone numbers (raw or hashed) to
   a Cloud Function that returns the intersection with registered users.

The choice has significant privacy, complexity, and scalability implications.

### Decision

**Option A — Local matching** is adopted.

Device contacts are loaded into memory via the platform contact-picker API and
are never uploaded to any server. When the user selects a contact, the app
queries Firestore by `phoneNumber` (a single document read per selection) to
determine whether the contact is a registered One By Two user. For "show me
which of my contacts are already on One By Two" views, the app loads the
user's own friends list (which is small) and intersects it locally against
contacts in memory. Broad-stroke "discover all One By Two users in my entire
address book" is explicitly out of scope for v1.0.

The Firestore `users` collection is already queryable by `phoneNumber` (per the
schema established in PR #9), so no additional indexes or schema changes are
required.

### Consequences

- **Privacy-preserving by default.** Contact data never leaves the device. No
  PII is batched, transmitted, or stored server-side for matching purposes.
- **No Cloud Function dependency.** The matching path is a direct Firestore
  query, removing a potential latency and failure point.
- **Scaling trade-off accepted.** Intersecting a friends list against a large
  on-device contact list could become slow on cold devices when contact counts
  exceed roughly 1,000. This is an acceptable trade-off; the v1.0 user base is
  well below this threshold, and the operation is infrequent.
- **Hand-off contract from the contact picker.** When the user selects a
  contact, the picker exposes only the selected contact's data to the calling
  controller:

  ```
  selectedContact: { displayName: String, phoneNumbers: List<String> }
  ```

  Phone numbers are E.164 normalised (e.g. `+91XXXXXXXXXX`). The full contact
  list never crosses the picker boundary; only the single selected contact does.
  The boundary-contract test (Phase 5, item 6) will assert this contract.
- **PII handling posture.** The commitment that PII stays on-device is
  documented in `docs/design/07-technical/pii-handling.md` and enforced by
  PII-leak tests. This posture is not promoted to a fifth formal invariant at
  this time. Consistent with the reasoning applied in ADR-0012 (where
  `affectedKeys()` was not promoted to a fifth invariant because promotion
  would be premature), the PII handling pattern should prove stable across at
  least two to three PII-touching features before elevation is considered.

### Alternatives Considered

- **Server-side matching (Option B):** phone numbers (or hashed phone numbers)
  are batched and sent to a Cloud Function that performs the intersection and
  returns matching user IDs. This approach scales better at large contact-list
  sizes and can implement privacy-preserving variants such as hashing,
  k-anonymity, or Bloom filters. However, it was rejected for v1.0 because:
  (a) PII transits to the server even when hashed, making the privacy posture
  harder to walk back later; (b) it adds Cloud Function complexity (deployment,
  monitoring, error handling) that is not justified at current scale; and
  (c) the local matching approach is sufficient for the v1.0 user base.
- **Hybrid approach (local with server fallback):** rejected for unnecessary
  complexity when local matching alone meets v1.0 requirements.

### Implication for PR #31

- The controller receives `selectedContact` as
  `{ displayName: String, phoneNumbers: List<String> }` with E.164 normalised
  phone numbers.
- The full contact list is never exposed beyond the picker boundary.
- The boundary-contract test (Phase 5, item 6) will mock the contact-picker
  return value and assert that only the single selected contact's
  `displayName` and `phoneNumbers` are visible to downstream code.

---

## ADR-0014: Cross-User Lookup for Contact Matching — Cloud Function Gateway

**Status:** Accepted

### Context

ADR-0013 chose local matching: contacts stay on-device, and the app queries
Firestore by phone number to determine whether a selected contact is a
registered One By Two user. PR #31 (contact picker UI) is merged; PR #32
implements matching and friendship creation.

The current `users` read rule in `firestore.rules` (line 13) is:

```
allow read: if request.auth != null && request.auth.uid == userId;
```

This means clients can only read their own document. To perform a phone-number
lookup against another user's document, the read rule must be relaxed or the
query must be routed through a trusted server component. The choice has direct
security and privacy implications because One By Two uses phone-only
authentication — confirming that a phone number is registered on the platform
is inherently sensitive.

Three approaches were evaluated.

### Decision

**Option C — Cloud Function gateway** is adopted.

A new callable Cloud Function `lookupUserByPhoneNumber` accepts a single E.164
phone number and returns a minimal response shape:

```
Input:  { phoneNumber: string }       // E.164 format, e.g. "+91XXXXXXXXXX"
Output: { matched: false }
     or { matched: true, displayName: string, photoUrl: string | null, otherUserId: string }
```

The function **never** returns `phoneNumber`, `fcmTokens`, `notificationPrefs`,
`locale`, `createdAt`, `updatedAt`, or any field beyond `matched`,
`displayName`, `photoUrl`, and `otherUserId`. The `otherUserId` is included
because the calling user needs it to create the friendship document.

**Rate limiting:** each authenticated user is limited to 100 lookups per hour.
The rate-limit counter is stored in Firestore at
`_rateLimits/{userId}/lookups`. If the limit is exceeded, the function returns
a `RATE_LIMITED` error. This prevents bulk enumeration of the user base.

**Logging:** each lookup is logged with a hashed phone number (never raw) for
abuse detection and audit purposes.

**Firestore rules:** the `users` collection read rule remains restrictive for
client queries. Clients may read only their own document or documents of users
they share a friendship or group with. The Cloud Function's service account
bypasses Security Rules (as all Admin SDK calls do), so the function can
perform the phone-number lookup without relaxing client-facing rules.

### Consequences

- A new Cloud Function `lookupUserByPhoneNumber` is added, following the
  three-module layout established in ADR-0011 (`algorithm.ts`, `function.ts`,
  `index.ts`).
- The function is deployed to `asia-south1` (Mumbai), consistent with all
  existing Cloud Functions.
- The matching repository on the client wraps the Cloud Function call via
  `FirebaseFunctions.httpsCallable('lookupUserByPhoneNumber')`, abstracting
  the network boundary from the UI layer.
- Cold-start latency (~200-400ms) and warm latency (~50-100ms) are acceptable
  for a user-initiated action (tapping a contact to check membership).
- The `_rateLimits` collection is internal infrastructure. Security Rules deny
  all client reads and writes to `_rateLimits/{document=**}`.
- The `users` read rule is tightened from "owner only" to "owner OR users who
  share a friendship or group." This supports displaying friend/group-member
  names and avatars in the UI without additional Cloud Function calls, while
  still preventing arbitrary cross-user reads.

### Alternatives Considered

**Option A — Open phone-number query against users collection:** allow any
authenticated user to query `users` where `phoneNumber == X`. This is the
simplest approach — a single Firestore round-trip with no Cloud Function
dependency. Splitwise and most expense-share apps use this pattern. However,
it makes the user base trivially enumerable: any authenticated user with a
list of phone numbers can confirm which numbers are registered on One By Two.
For a phone-only-auth app, this is a meaningful privacy risk. The query is
trivially scriptable and cannot be rate-limited at the Firestore rules layer.
Rejected for insufficient privacy protection.

**Option B — Restricted query (only existing friendships/group members):**
allow reading user documents only for people the caller already shares a
friendship or group with. This provides strong privacy but is functionally
broken for the matching use case: you cannot find someone to friend if the
rule requires you to already be friends. The approach is logically circular
and unusable for contact matching. Rejected as non-functional.

### Implication for PR #32

1. A Cloud Function `lookupUserByPhoneNumber` is added in PR #32. It follows
   the three-module layout (ADR-0011) and is deployed to `asia-south1`.
2. The function accepts `{ phoneNumber: string }` (E.164) and returns either
   `{ matched: false }` or
   `{ matched: true, displayName: string, photoUrl: string | null, otherUserId: string }`.
   No other user fields are ever returned.
3. The matching repository on the client wraps the Cloud Function call,
   exposing a typed `Future<MatchResult>` to the controller layer. The UI
   layer does not interact with `FirebaseFunctions` directly.
4. Rate-limit policy: 100 lookups per user per hour, enforced by the Cloud
   Function using a counter at `_rateLimits/{userId}/lookups`. Exceeding the
   limit returns a `RATE_LIMITED` error.
5. The `users` read rule is updated: clients may read their own document OR
   documents of users they share a friendship or group with. Direct
   phone-number queries against the `users` collection remain blocked for
   clients.

---
