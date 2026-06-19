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

### Relationship to ADR-0014

ADR-0013 governs **bulk PII handling**: device contacts are never uploaded to
any server, matching is performed locally, and the contact picker exposes only
the single selected contact to downstream code.

ADR-0014 governs the **individual user lookup mechanism**: once a single phone
number has been selected on-device, how does the app determine whether that
number belongs to a registered One By Two user? ADR-0014 answers this
sub-question by routing the lookup through a Cloud Function gateway
(`lookupUserByPhoneNumber`) rather than a direct client-side Firestore query.
This preserves the restrictive `users` read rule while still enabling contact
matching.

The two decisions sit at different layers of the same problem. ADR-0013's
constraint that contacts never leave the device as bulk data remains binding.
ADR-0014's Cloud Function accepts only a single phone number per invocation,
which is consistent with that constraint.

Note: the "No Cloud Function dependency" consequence listed above was written
before the Security Rules analysis (PR #32) revealed that cross-user reads are
blocked for clients. ADR-0014's Cloud Function gateway is a conscious
refinement of the lookup mechanism, not a contradiction of the local-matching
strategy.

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

### Relationship to ADR-0013

ADR-0013 establishes the higher-level contact-matching strategy: contacts
remain on-device, no bulk upload occurs, and matching is scoped to individual
selections. ADR-0014 refines the implementation mechanism for that individual
lookup. Where ADR-0013 described "queries Firestore by `phoneNumber`",
ADR-0014 specifies that this query is routed through a Cloud Function
gateway — not executed as a direct client-side Firestore read — because the
`users` Security Rules restrict cross-user reads.

Together, the two ADRs form the complete contact-matching architecture:
ADR-0013 defines what data stays on-device (bulk contacts) and what may be
looked up (a single selected phone number); ADR-0014 defines how that lookup
is performed (Cloud Function, rate-limited, with minimal response shape).

---

## ADR-0015: Phone Number Change via Re-verification (FR-PR-02)

**Status:** Accepted

### Context

FR-PR-02 (SRS section 4.2, line 175, P1) lets a signed-in user change their phone
number. Three forces shaped the design:

1. The operation must mutate the *current* account, not sign in. Firebase exposes
   `currentUser.updatePhoneNumber(PhoneAuthCredential)` for exactly this; the
   sign-in path (`signInWithCredential`, used by `PhoneAuthRepository.verifyOtp`)
   would create or switch accounts and is wrong here.
2. `updatePhoneNumber` raises `requires-recent-login` when the last sign-in is
   older than Firebase's recent-login window. Because FR-AU-07 persists the session
   and auto-logs in, this is the **common** path, not an edge case.
3. `users/{uid}.phoneNumber` was immutable on update (`isValidUserUpdate()` asserted
   `data.phoneNumber == prev.phoneNumber`). The client must be able to persist the
   new number, but only the genuinely re-verified one.

### Decision

- **Two-OTP, proactive re-authentication.** The flow always re-verifies the
  CURRENT number first (`reauthenticateWithCredential`), then verifies the NEW
  number and calls `updatePhoneNumber`. Re-authenticating refreshes the recent-login
  window, so the subsequent `updatePhoneNumber` does not raise
  `requires-recent-login`. This is preferred over a reactive
  (try-update, catch, re-auth, retry) shape because it yields a working result for
  the session-persisted majority without a mid-flow credential-consumption retry.
- **Interface Segregation.** The mutate-current-user operations live on a new
  `PhoneAccountRepository` (`lib/features/auth/data/phone_account_repository.dart`),
  distinct from the sign-in `PhoneAuthRepository`. Its `requestOtp` handles Android
  instant verification by handing the auto-retrieved credential to an
  `onAutoRetrieved` callback (which re-authenticates / updates the current user) —
  it NEVER calls `signInWithCredential`, so auto-retrieval cannot switch accounts,
  and the flow can never get stuck on a loading state when no SMS code is sent.
  Keeping the interfaces separate also avoids forcing the 13 existing sign-in test
  fakes to implement change-phone methods they never exercise.
- **Relaxed, narrowly-scoped Security Rule (ADR-0010 pattern preserved).**
  `isValidUserUpdate()` changes the `phoneNumber` clause from
  `data.phoneNumber == prev.phoneNumber` to
  `(data.phoneNumber == prev.phoneNumber || data.phoneNumber == request.auth.token.phone_number)`.
  Every other immutability and shape check is unchanged: `createdAt` stays
  immutable, the `hasOnly` key whitelist, the displayName / photoUrl /
  notificationPrefs / locale validators, and `updatedAt == request.time` all hold.
  An arbitrary `phoneNumber` (not the freshly-verified token phone) is still
  rejected.
- **Token-refresh-before-write ordering.** After `updatePhoneNumber` succeeds the
  client forces `currentUser.getIdToken(true)` BEFORE writing
  `users/{uid}.phoneNumber`, so `request.auth.token.phone_number` reflects the NEW
  number when the relaxed rule evaluates. The Firestore write itself is a
  client-side `UserRepository.updatePhoneNumber` (ADR-0008), not a Cloud Function —
  Firebase has no native "phone changed" trigger and a callable would be
  over-engineering.

### Consequences

- The new number must be a valid +91 10-digit mobile (reuses `validateIndianMobile`;
  SRS line 133); international numbers remain out of scope.
- The re-auth target number is sourced from Firebase Auth
  (`currentUser.phoneNumber`) — the authoritative number
  `reauthenticateWithCredential` runs against — not the Firestore users-doc copy.
- **Known limitation (S3 follow-up):** the change spans two systems (Firebase Auth,
  then the Firestore users-doc). If `updatePhoneNumber` succeeds but the gated
  Firestore write fails persistently and the user abandons the flow at
  `syncPending`, Auth holds the NEW number while the users-doc still shows the OLD
  one. The account stays fully usable (friendships are UID-keyed) and the displayed
  number is the stale doc value; a follow-up reconciliation (detect
  `auth.phoneNumber != users.phoneNumber` on launch and re-attempt the sync) is
  tracked separately. `user-mismatch` is mapped to `AuthError.requiresRecentLogin`
  so the re-entry path surfaces a clear message rather than a generic error.
- Existing friendships are UID-keyed and unaffected — no contact-matching migration.
  The user becomes discoverable by the new number going forward (ADR-0013/0014).
- Functions Dev adds `users-update.test.ts` cases: a change to the token phone is
  allowed; a change to an arbitrary phone is rejected; other immutable-field changes
  remain rejected.
- Telemetry is PII-free: the number is never an event parameter (SRS section 5.4).
- No new Cloud Function, collection, index, or Flutter plugin; `firebase_auth`
  already provides the required APIs (no `ios/Podfile.lock` change).

### Alternatives Considered

- **Reactive re-auth (update first, catch `requires-recent-login`).** Rejected:
  for the session-persisted majority it always fails first, consumes an OTP, and
  needs a more complex retry; the proactive flow is simpler and always works.
- **Callable Cloud Function for the Firestore sync.** Rejected as over-engineering;
  the client write gated by the relaxed rule is consistent with ADR-0008.
- **Adding the methods to `PhoneAuthRepository`.** Rejected: it would force all 13
  sign-in fakes to implement change-phone methods and risks coupling the sign-in
  auto-verify behaviour into the change flow.

---

## ADR-0016: Account Deletion Cascade — Delete-vs-Anonymise via a users-doc Tombstone (FR-AU-09)

**Status:** Accepted

### Context

FR-AU-09 (SRS section 4.1, line 168, P1) lets a signed-in user permanently delete
their account. The requirement text is precise about the split: the operation
"anonymises their data in shared groups and removes personal records within 30
days." SRS section 5.5 (line 318) reinforces this under the DPDP Act 2023 — the
right to delete requires removal or anonymisation of all personal data within 30
days. SRS sections 7.1 (line 405) and 7.3 (line 473) place account deletion among
the heavy operations that must run as a Cloud Function so the client cannot bypass
invariants.

The user-facing flow is specified in SCR-28 Part B (the five-step Warning ->
Re-auth -> Confirm -> Processing -> Success route). Step D calls a single Cloud
Function `deleteUserAccount`; this ADR defines that function's contract and,
critically, the data-fate matrix it implements.

The design tension is the One By Two data model itself. A user's records fall into
two disjoint classes:

1. **Personal records** that belong to the user alone — their profile, activity
   feed, rate-limit counters, avatar, and the Firebase Auth identity.
2. **Shared records** that are co-owned with another member — friendships, the
   expenses and settlements inside them, receipts, and the derived
   `simplifiedBalances`. Hard-deleting these would corrupt the surviving member's
   balance and history, which they have an equal claim to and which FR-AU-09
   explicitly says to preserve ("balances will be preserved for other members",
   SCR-28 Step A copy).

Three further forces shaped the design:

- **Invariant 2** makes `simplifiedBalances` server-maintained and written solely
  by the recompute core. The deletion function runs under the Admin SDK and so
  *could* write the field, which makes accidental mutation a real, high-severity
  risk.
- The client already renders missing display names as `displayName ?? 'Unknown'`
  at three call sites. The design has to choose how a deleted user surfaces in the
  surviving member's UI without a client change.
- The re-authentication step (SCR-28 Step B) is the same proactive phone
  re-verification primitive that ADR-0015 (FR-PR-02) introduced, raising the
  question of whether to reuse or fork it.

### Decision

`deleteUserAccount` partitions every record that touches the departing user into
exactly one of three fates. The matrix is the core decision; the points below
justify it and pin the callable contract.

| Fate | Records | Mechanism |
|---|---|---|
| **DELETE** (personal) | `activity/{uid}` document and its `items/**` subcollection; `_rateLimits/{uid}/**`; the Storage object `avatars/{uid}`; the Firebase **Auth** record. | Hard delete. `admin.auth().deleteUser(uid)` runs **last**. |
| **TOMBSTONE** (identity) | `users/{uid}` | The document is **replaced** with the PII-free shell `{ displayName: 'Deleted User', deletedAt: <serverTimestamp> }`. |
| **PRESERVE / no-op** (shared) | `friendships/{*}` the user belongs to, their `expenses` subcollections, the related top-level `settlements`, and `receipts/friendships/{fid}/{expenseId}`. | The function does nothing. The surviving member keeps the exact balance and history they had. |

- **The tombstone is the anonymisation mechanism.** Replacing `users/{uid}` with
  the name-only shell strips `phoneNumber`, `photoUrl`, `fcmTokens`,
  `notificationPrefs`, and `locale`, removing every personal field (this is how
  FR-AU-09's "removes personal records" and the SRS section 5.5 / DPDP 2023 erasure
  duty are met) while leaving a resolvable identity. Anonymisation in shared
  contexts is delivered **entirely** by this single write — never by mutating any
  friendship, expense, settlement, or balance.
- **Invariant 2 boundary — deliberate preservation (the highest-risk
  regression).** `deleteUserAccount` runs under the Admin SDK and is therefore
  *technically* able to write `simplifiedBalances`. It must **never** recompute,
  zero, or strip `simplifiedBalances` on a surviving friendship. The sole writer of
  `simplifiedBalances` values remains the recompute core
  (`functions/src/simplified-debts/function.ts`; Invariant 2). An integration test
  must assert that a surviving member's `simplifiedBalances` map is **byte-for-byte
  identical** before and after their counterparty deletes their account.
- **"Unknown" vs "Deleted User" — option (b), no client change.** The three
  name-fallback sites (`friends_list_provider.dart:109`,
  `friend_detail_provider.dart:289`, `activity_feed_screen.dart:297`) already
  coalesce with `displayName ?? 'Unknown'`. Because the tombstone sets
  `displayName: 'Deleted User'`, those sites render "Deleted User" with **no client
  edit**, while a genuinely absent users-doc still renders "Unknown". The two
  outcomes are intentionally distinct; the client requires no change for this
  feature.
- **"30 days" is a synchronous hard-delete for v1.0.** The cascade runs
  synchronously inside the callable — no scheduler, no grace period, no background
  reaper — which is the simplest mechanism, adds no new infrastructure, and matches
  the SCR-28 Step D contract (the client awaits one call and shows success on
  return). "30 days" becomes user-facing copy and a safety ceiling, not a delay.
  The soft-delete tombstone plus a scheduled `onSchedule` reaper and a reversible
  grace period (SCR-28 Account Deletion Open Questions 1-3) are **deferred to a
  future issue**.
- **Idempotency, step ordering, and batching.**
  - *Ordering:* delete Firestore data -> delete Storage -> delete Auth **last**.
    While the Auth record exists the caller can re-authenticate and retry the whole
    cascade; once Auth is gone the account is unreachable, so deleting it last keeps
    every partial-failure state recoverable.
  - *Idempotency:* every step treats already-absent state as success.
    `auth/user-not-found`, a missing users or activity document, an absent
    rate-limit path, and a missing avatar object are all swallowed as no-ops, so a
    re-run converges.
  - *Batching:* the subcollection deletes use Firestore `recursiveDelete`
    (BulkWriter under the hood), which handles the 500-write `WriteBatch` cap and is
    safe to re-run (SCR-28 edge cases 3 and 4).
- **`deleteUserAccount` callable contract.** HTTPS callable, region `asia-south1`,
  pinned via the `REGION` constant exported from `functions/src/index.ts`. Input:
  none — the subject is `request.auth.uid`, so a user can only delete themselves.
  Output: `{ success: true }`. The auth check runs **first**: a missing
  `request.auth.uid` throws
  `HttpsError("unauthenticated", ..., { errorCode: "UNAUTHENTICATED" })` before any
  read or write. **Recent-login (re-auth) enforcement runs next, server-side**: the
  caller's `request.auth.token.auth_time` (Unix seconds, refreshed by the SCR-28
  Step B re-authentication) must be within a five-minute window, else the handler
  throws
  `HttpsError("failed-precondition", ..., { errorCode: "REAUTH_REQUIRED" })`. A
  missing `auth_time` claim is treated as not-recently-authenticated. This makes the
  Step B re-auth gate **defence-in-depth** rather than client-only — a direct
  callable invocation with a stale (but unexpired) token cannot bypass it for this
  irreversible operation. Any unexpected error throws
  `HttpsError("internal", ..., { errorCode: "INTERNAL" })`. Structured logs hash
  the uid via `functions/src/utils/id-hash.ts` `hashId` (`uidHash`); the raw uid
  and phone number are never logged, and the uid is redacted from any SDK error
  message before logging (SRS section 5.4; ADR-0013). The boundary follows
  `functions/src/send-reminder-notification/function.ts` — a handler factory with
  injected dependencies (including an injectable clock for the `auth_time` check)
  for testability, wired to an `onCall` export in `index.ts`. The codes are
  catalogued in `docs/design/07-technical/cloud-functions-error-codes.md`
  section 2.
- **Re-authentication reuse.** SCR-28 Step B reuses the FR-PR-02
  `PhoneAccountRepository` (ADR-0015) as a **re-auth-only** path — `requestOtp` +
  `reauthenticate` / `reauthenticateWithCredential`, with the target number read
  from `currentPhoneNumber`. It does not update a number, so no extension or fork is
  needed, and it must **never** call `signInWithCredential` (which would switch
  accounts). +91 numbers only.
- **Storage personal-vs-shared split.** Personal — **delete** `avatars/{uid}`.
  Shared — **preserve** `receipts/friendships/{fid}/{expenseId}`, which belongs to
  the surviving friendship and its other member. (The group-receipt path is
  forward-compat only; see below.)
- **Client delete stays denied.** `firestore.rules` already denies client deletes
  on `users` (line 46), `friendships` (line 127), and `settlements` (line 495) with
  `allow delete: if false`; the Admin SDK bypasses Security Rules, so the cascade
  needs no rule relaxation. **The rules do not change.** A rules test must confirm
  that a client `delete` on `users/{uid}` and on a `friendships/{fid}` document
  stays rejected. Adding any client-side `allow delete` is explicitly forbidden — it
  would breach the server-only deletion boundary FR-AU-09 depends on.
- **Groups forward-compat.** `groups/{groupId}` exists in the schema but has no
  client UI and no live data in v1.0. The function implements the **friendship axis
  fully** and **preserves the group axis by omission** — it never touches
  `groups/{groupId}` or any group-context settlement, signposted by an explanatory
  comment in `function.ts` (a plain comment, not an issue-tagged `TODO`). A future
  group member tombstones identically, with group `simplifiedBalances` preserved by
  the same Invariant 2 discipline, when the Sprint 3 Groups epic lands. This ADR
  does **not** authorise building the Groups epic.

### Consequences

- A new callable `deleteUserAccount` is added under `functions/src/`, following the
  ADR-0011 module layout and the reminder-callable boundary pattern. Functions Dev
  owns the implementation and its tests; the Architect owns this contract.
- **Architectural firsts:** the first cascade-delete fan-out Cloud Function; the
  first use of `admin.auth().deleteUser(...)`; the first reuse of the FR-PR-02
  re-auth surface outside change-phone; and the first server-side write adjacent to
  `simplifiedBalances` that **deliberately preserves** it rather than producing it.
- **Required tests** (Functions Dev / QA):
  - Integration — a surviving member's `simplifiedBalances` is byte-for-byte
    unchanged after their counterparty deletes their account.
  - Integration — idempotent re-run: invoking the cascade twice, or after a
    simulated partial failure, converges, treating `auth/user-not-found` and missing
    docs/objects as success.
  - Integration — `users/{uid}` is replaced by
    `{ displayName: 'Deleted User', deletedAt }`, with `phoneNumber`, `photoUrl`,
    `fcmTokens`, `notificationPrefs`, and `locale` all absent.
  - Rules — a client `delete` on `users/{uid}` and on `friendships/{fid}` remains
    rejected.
- **No client change** is required for name resolution; the three fallback sites
  already render "Deleted User" from the tombstone and "Unknown" from a genuinely
  absent doc.
- **No Security Rules, index, or schema-shape change.** The tombstone is a narrower
  users-doc, not a new collection, and the cascade runs entirely under the Admin
  SDK.
- Telemetry stays PII-free: SCR-28 emits `delete_account_*` events with no phone
  number or raw uid (SRS section 5.4); function logs carry only `uidHash`.
- **Deferred to a future issue:** SCR-28 Account Deletion Open Questions 1-3
  (grace-period reversal, confirmation SMS, audit-log collection) and the
  soft-delete-plus-reaper mechanism.
- **Accepted limitation:** because the cascade is synchronous, a network loss during
  SCR-28 Step D can leave the function completing server-side after the client times
  out (SCR-28 edge case 3); the user discovers the completed deletion on next launch
  via an Auth error. The idempotent design makes a client retry safe even if the
  first run partially completed.

### Relationship to prior ADRs

- **ADR-0015 (FR-PR-02 phone change)** supplies the re-auth primitive. ADR-0016
  reuses `PhoneAccountRepository` in a read-only re-verification mode — `requestOtp`
  + `reauthenticate`, never `updatePhoneNumber`, never `signInWithCredential` —
  showing the Interface Segregation choice in ADR-0015 generalises beyond
  change-phone.
- **ADR-0011 (module layout)** and the reminder callable: ADR-0016 follows the same
  pure-logic-plus-boundary split and handler-factory-with-injected-deps pattern, so
  the cascade is unit-testable without live Firebase.
- **ADR-0008 (client-side user-doc writes)** and **ADR-0010 (field-level rules):**
  deletion is the deliberate exception — the only deletion writer is the trusted
  server and `allow delete: if false` for clients stands unchanged. ADR-0016 fixes
  that the client never deletes.
- **ADR-0001 / Invariant 2 (`simplifiedBalances` server-only):** ADR-0016 is the
  first server-side actor to sit beside the field and intentionally not touch it.
  Where the recompute core is the sole producer of balance values, the cascade is a
  deliberate non-producer; anonymisation comes from the users-doc tombstone, keeping
  the surviving member's balances byte-for-byte intact.
- **ADR-0013 / ADR-0014 (PII-safe logging, server-gated cross-user operations):**
  ADR-0016 continues both — uids are hashed via `hashId` before logging, and the
  sensitive multi-record operation runs server-side under the Admin SDK rather than
  as client writes.

---

## ADR-0017: Current-Month Spend Breakdown — Friendship Fan-Out and `fl_chart` (FR-HD-03)

**Status:** Accepted

### Context

FR-HD-03 (SRS section 4.8, line 248, P1) replaces the `SpendingBreakdownPlaceholderCard`
under the Home dashboard's "This Month" header with a real current-month spend summary
and a per-category breakdown chart. It is the last open Home-dashboard requirement;
FR-HD-01/02 (#62) and FR-HD-04 (#57) closed the rest.

The central architectural problem is that **no cross-friendship expense read path
exists**. Every prior expense read is scoped to a single friendship
(`ExpenseRepository.watchExpensesByFriendship`, over `friendships/{fid}/expenses`).
FR-HD-03 needs the **signed-in user's own spend**, grouped by `ExpenseCategory`, for the
**current calendar month computed in IST** (SRS section 5.9), folded across **all** the
caller's friendships.

Four standing forces shape the design:

- **Invariant 1 (integer paise).** This is a monetary surface. Every category subtotal
  and the month total must be an integer `*Paise` sum; the only paise-to-rupee
  conversion is `formatInrFromPaise(int)` at the widget layer, and chart geometry is a
  derived integer-paise ratio. No `double`, no inline `/ 100`.
- **The membership-gated read rules.** `firestore.rules` line 294 gates expense reads
  with `allow read: if isCallerFriendshipMember()`, where membership is resolved by a
  `get()` of the **parent friendship's** `memberIds`. Expense documents carry no member
  field of their own.
- **Invariant 2 (`simplifiedBalances` server-only) — adjacent, not applicable.**
  FR-HD-03 reads `expenses` and must never read or derive from `simplifiedBalances`:
  spend is the user's expense share, not a balance.
- **iOS plugin-stability history.** The repository hard-pins `device_info_plus`
  (12.3.0) and `connectivity_plus` (6.x) because native-plugin upgrades have broken the
  CI "Build iOS (no signing)" job. FR-HD-03 introduces the first charting library;
  whether it adds a CocoaPod governs whether `ios/Podfile.lock` must change.

This ADR ratifies the read path, the aggregation semantics, the IST boundary, the domain
and provider shape, the charting library, the index decision, and the new telemetry
event. It binds the Designer (Phase 3) and the Flutter Dev (Phase 4). It does not
authorise the Sprint 3 Groups epic or any denormalised-rollup Cloud Function.

### Decision

**1. Read path — friendship fan-out; `collectionGroup` and a rollup function both
rejected for v1.0.** The aggregation provider reuses `friendsListProvider` for the
caller's `friendshipId`s and, for each, issues a one-shot read of that friendship's
current-month, non-deleted expenses through a new injectable repository method, then
aggregates. A `collectionGroup('expenses')` query is rejected: because expenses carry no
member field and the rules scope reads on **parent-friendship** membership via `get()`,
a collection-group query cannot be constrained to the caller's friendships without a
schema change (denormalising a participant field onto every expense), which is a larger,
higher-risk security surface and out of scope. A denormalised monthly-spend rollup
maintained by a Cloud Function trigger is rejected for v1.0: a much larger change and a
new server writer. The **group axis is stubbed** (an explanatory comment plus this note),
exactly as `topBalancesProvider` stubbed groups.

**2. Aggregation semantics — the user's own share, by category, in the IST month,
integer paise.** "Spend" is the signed-in user's **own `sharePaise`**, summed per
`ExpenseCategory`, for the current calendar month in IST. It is **never** the full
`amountPaise`. The provider remains a pure derived consumer of `friendsListProvider`:
for a friendship whose counterparty is `FriendListItem.otherUserId`, the user's share for
an expense is the sum of `split.sharePaise` over the splits whose `userId != otherUserId`.
Under the Security Rules' guarantee that an expense's split members are a subset of the
two friendship members (`areSplitMembers`), this is identically "the split entry whose
`userId == currentUserId`" as the story specifies — but it is computed from data already
on `friendsListProvider`, so the provider need not re-read the scoped
`currentUserIdProvider` (see point 4). An expense the user is not a split member of
contributes `0`. Soft-deleted expenses (`deleted == true`) are excluded by the query
filter; prior- and future-month expenses contribute nothing. When the month total is
`0`, the card shows the empty state and no chart. All arithmetic is integer paise;
per-segment percentages are derived ratios (`categoryPaise / monthTotalPaise`) computed
at render time and are not money.

**3. IST month boundary — fixed +05:30, computed as absolute instants.** IST
(`Asia/Kolkata`) is a fixed `+05:30` offset with no DST, so no `timezone`/`intl`
initialisation is required. The window is computed purely:

- Derive the current IST calendar month `(Y, M)` from
  `DateTime.now().toUtc().add(05:30)`.
- `monthStartUtc = DateTime.utc(Y, M, 1).subtract(05:30)` — the first instant of the IST
  month as an absolute UTC instant.
- `nextMonthStartUtc = DateTime.utc(Y, M + 1, 1).subtract(05:30)` — Dart rolls month 13
  into the next January, so December is handled.

The per-friendship query carries the lower bound
`where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStartUtc))`; the pure
reducer applies both bounds, including an expense iff
`!date.isBefore(monthStartUtc) && date.isBefore(nextMonthStartUtc)` (`DateTime.isBefore`
compares absolute instants irrespective of the `isUtc` flag). For June 2026 this yields
`monthStartUtc = 2026-05-31T18:30:00Z` (equivalent to `2026-06-01T00:00:00+05:30`): an
expense at `2026-05-31T23:00 IST` is excluded and one at `2026-06-01T00:30 IST` is
included, matching AC-5.

**4. Domain and provider shape.** Two immutable, integer-paise domain value objects:
`CategorySpend { ExpenseCategory category; int totalPaise }` and
`MonthlySpendBreakdown { List<CategorySpend> categories; int monthTotalPaise }`, where
`categories` holds only non-zero categories sorted by descending paise. The boundary
math and the fold live in pure, separately-tested domain functions
(`currentMonthWindowIst(DateTime now)` and an `aggregateMonthlySpend(...)` reducer). The
provider is `monthlySpendBreakdownProvider`, a one-shot
`FutureProvider<MonthlySpendBreakdown>` that awaits `friendsListProvider`, fans out the
per-friendship fetch with `Future.wait`, and reduces. It declares
`dependencies: [friendsListProvider]` — it watches the scoped `friendsListProvider` and
lists exactly that; it does not list the transitive `currentUserIdProvider` (which it
does not directly read, per point 2). A reactive multi-stream merge is noted as a future
enhancement; the one-shot fan-out is simpler, testable, and refreshes when the friends
list changes or the provider is invalidated (the Retry path). The new read method extends
`ExpenseStore` and `ExpenseRepository` as a one-shot
`Future<List<ExpenseDoc>> fetchExpensesInMonth({required String friendshipId, required DateTime monthStartUtc})`
using `.get()` and reusing `ExpenseDoc.fromMap`, mirroring `watchExpensesByFriendship`'s
shape (equality on `deleted`, range and `orderBy` on `date` descending). Because the card
lives inside the dashboard's populated state, `friendsListProvider` is already resolved
when the card mounts, so the provider's loading/error reflect only the fan-out.

**5. Charting library — `fl_chart`, and a correction to the prompt's Podfile.lock
claim.** The chart uses `fl_chart`, pinned `^1.2.0` with an inline comment in
`pubspec.yaml`. **Correction:** the canonical prompt asserts an `ios/Podfile.lock` change
is *required* for the charting plugin; this is **incorrect for `fl_chart`
specifically**. `fl_chart` is pure Dart — its only dependencies are `equatable`,
`flutter`, and `vector_math`, it declares no `flutter: plugin:` block, and it ships no
native iOS/Android code, so it adds **no CocoaPod and does not change
`ios/Podfile.lock`** (unlike the Firebase/native plugins that motivated the existing hard
pins). `fl_chart` requires Flutter >= 3.27.4 / Dart >= 3.6.2; the repository is on
Flutter 3.44.2 / Dart 3.12.2 and `pubspec.yaml` declares `sdk: ^3.11.0`, so it is
compatible. The Flutter Dev must still run `flutter pub get` and `cd ios && pod install`,
confirm `ios/Podfile.lock` is unchanged, and commit it **only if** it changes (it will
not for `fl_chart`). A hand-rolled `CustomPainter` donut is rejected: it adds rendering
and bespoke accessibility code to avoid a pure-Dart, low-risk dependency.
**Accessibility:** the chart is decorative; meaning is carried by a per-segment
`Semantics` label of the form "category, rupee amount, percentage" (rupees via
`formatInrFromPaise`) plus a legend — never by colour alone (SCR-06; SRS section 5.6).

**6. Index — no new index, no rules change.** The existing `firestore.indexes.json`
composite index `{ collectionGroup: "expenses", queryScope: COLLECTION, fields: [deleted ASC, date DESC] }`
covers the per-friendship query (an equality on `deleted` plus a range and `orderBy` on
`date`) **provided the query orders by `date` descending**. The Flutter Dev must
therefore order by `date` descending (also matching `watchExpensesByFriendship`). No new
index is required, no `firestore.rules` change is required, and the Schema-Change
deploy-before-client ordering is moot because there is no schema change.

**7. Telemetry — one new PII-free event.** `home_spending_breakdown_viewed`, single
parameter `category_count` (`int`, `0..8` — the number of non-zero categories rendered,
`0` in the empty state). It fires **once per dashboard mount**, on the **first terminal
render** of the breakdown card, in both the populated and empty sub-states, and **never**
on the loading or error sub-states. The single-fire gate lives in a dedicated
breakdown-card `ConsumerStatefulWidget` (its terminal sub-state has a separate data
lifecycle from the balances axis that drives `home_viewed`), mirroring the existing
`_loggedView` boolean. The event-name and parameter-key constants extend `HomeTelemetry`
(`spendingBreakdownViewed`, `paramCategoryCount`). The event must be **declared** in
`telemetry-plan.md` section 1.3 alongside the six existing `home_*` events. No `uid`,
`friendshipId` (raw or hashed), display name, photo URL, phone number, or raw
rupee/paise value may ever be a parameter (SRS line 308; ADR-0013); no hashing is needed
because no hashable identifier is emitted.

**8. Card placement and invariants.** The card stays in the dashboard's populated state
for v1.0 (matching the placeholder it replaces); the narrow "spend-but-zero-overall-
balance" edge — a settled-up user who sees the dashboard's empty state and therefore no
breakdown — is an accepted v1.0 limitation tracked as a follow-up. Invariant 1 is
critical and enforced throughout; Invariant 2 is not applicable (the feature never reads
`simplifiedBalances`); Invariant 3 is not applicable (no sharing or export); Invariant 4
is reinforced (the fan-out and all testing target the single project via the emulator).

### Consequences

- New files land under `lib/features/home/` (a domain model and pure aggregator, the
  application provider, and the presentation card, chart, and category-colour palette),
  plus a one-shot read method added to the expenses feature's `ExpenseStore` /
  `ExpenseRepository`. The category-colour palette is feature-local with brightness-aware
  light/dark `static const` maps — not a `ThemeExtension` (the codebase avoids
  `ThemeExtension` per `tokens.md`); the Designer owns the colour values (dark-mode-safe,
  WCAG 2.1 AA).
- **Architectural firsts:** the first cross-friendship expense read; the first charting
  library; the first Home provider that derives from `expenses` rather than
  `simplifiedBalances`; and the first newly-declared telemetry event of the recent PRs.
- **Read cost.** The fan-out issues N month-bounded one-shot reads (one per friendship)
  on each dashboard view. This is acceptable for v1.0; if production telemetry shows the
  cost is material, a denormalised monthly-rollup is filed as a FUTURE optimisation issue
  (not built here).
- **Required tests** (Flutter Dev / QA): pure-reducer and window unit tests
  (multi-friendship fold, user-share-not-total, the exact IST boundary, prior-month and
  deleted exclusion, single-category degenerate, all-eight including `other`, descending
  sort, empty/zero); provider fan-out tests over recording fakes overriding
  `currentUserIdProvider` and `friendsListProvider`; widget tests (loading skeleton,
  empty card, populated chart + legend + total, error Retry/Contact Support, per-segment
  Semantics, single-fire telemetry including `category_count: 0` and the no-fire-on-error
  case); and the Invariant-1 boundary-contract grep plus the Invariant-2 negative-guard
  grep extended over the new files. Per-feature coverage >= 70%.
- **No Cloud Function, `firestore.rules`, `firestore.indexes.json`, or schema-shape
  change.** The store method is faked in provider tests exactly as
  `watchExpensesByFriendship` is (no `fake_cloud_firestore`); deleted-exclusion is a
  query-filter contract verified at the store/emulator level.
- **Relationship to prior ADRs.** ADR-0002 / Invariant 1: this monetary surface sums the
  user's share in integer paise and never floats it. ADR-0004 (Riverpod) and the
  FR-HD-01/02 notes: the provider mirrors the `dependencies: [friendsListProvider]`
  derived-provider pattern of `overallNetBalanceProvider` / `topBalancesProvider`.
  ADR-0013 (PII-safe telemetry): the event carries only `category_count`. ADR-0001 /
  Invariant 2: like ADR-0016, this feature sits adjacent to balance data and deliberately
  does not touch `simplifiedBalances` — spend is computed from `expenses` alone.

### Alternatives Considered

- **`collectionGroup('expenses')` single query** — rejected: expenses carry no member
  field and the rules gate reads on parent-friendship membership, so the query cannot be
  membership-scoped without denormalising a participant field onto every expense (a
  schema and security-surface change out of scope).
- **Denormalised monthly-spend rollup Cloud Function** — rejected for v1.0: a much larger
  change and a new server writer; retained as a FUTURE optimisation only if read cost
  proves material.
- **Summing `amountPaise` (the bill total)** — rejected: it over-reports, including the
  counterparty's share; spend is the user's own share.
- **Hand-rolled `CustomPainter` donut** — rejected: more rendering and bespoke
  accessibility code to avoid a pure-Dart dependency that adds no CocoaPod.
- **A new single-collection `date` index** — rejected as unnecessary: the existing
  `deleted ASC + date DESC` composite covers the query when it orders by `date`
  descending.
- **Reactive multi-stream merge** (watching each friendship's expense stream) — deferred:
  the one-shot `Future` fan-out is simpler and testable and refreshes on friends-list
  change or invalidation; live updates are a possible enhancement.
- **Device-local or UTC month boundary** — rejected: the window must be IST (SRS section
  5.9) to match the app's date rendering.
- **Reading `currentUserIdProvider` directly in the provider** — rejected in favour of
  the counterparty-complement share extraction, which keeps the provider a pure derived
  consumer of `friendsListProvider` with `dependencies: [friendsListProvider]` only; the
  direct approach would additionally require listing `currentUserIdProvider` in
  `dependencies`.

---

  ## ADR-0018: Notification Deep-Link Tab-Switch — `homeTabIndex` on the Sealed Target, `selectTab` in the Handler (FR-AC-05)

  **Status:** Accepted

  ### Context

  FR-AC-05 (SRS section 4.7, line 240, P0) — "Tapping a notification shall deep-link the
  user to the relevant screen, even from a cold start." The resolver, the navigation, and
  the four dispatch sources shipped in #53. What was **deferred from #63** (which built the
  `shellNavigationControllerProvider` seam and wired the Profile rows, recording the deferral
  in the FR-PR-04 story Architect Notes §5 as "controller seam only") is the **tab-switch**:
  today a notification tap pushes the detail screen onto the **root** navigator over whatever
  primary tab happened to be active, and never drives the bottom-nav selection — so the user
  lands in, and on pop returns to, a stale, unrelated tab.

  The surfaces in play:

  - `lib/core/routing/notification_deep_links.dart` — the pure resolver
    `NotificationDeepLinks.resolve(payload, currentUid)` → a sealed `DeepLinkTarget`
    (`DeepLinkExpenseDetail`, `DeepLinkFriendDetail`, `DeepLinkUnavailable`,
    `DeepLinkGroupsComingSoon`), plus `navigate(context, target)` which only `Navigator.push`-es
    the detail screen or shows a snackbar. It has **no `ref`/container** today.
  - `lib/features/notifications/application/deep_link_handler.dart` — `DeepLinkHandler` (holds
    the app `ProviderContainer`) resolves, emits the PII-free `fcm_notification_tapped` event,
    then calls `navigate`.
  - `lib/features/notifications/presentation/notifications_lifecycle_host.dart` — wires the four
    dispatch sources (foreground banner, background `onMessageOpenedApp`, cold-start
    `getInitialMessage`, and the post-sign-in replay of `pendingDeepLinkProvider`).
  - `lib/features/shell/application/shell_navigation_controller.dart` — the #63
    `shellNavigationControllerProvider` (`NotifierProvider.autoDispose<…, int>`,
    `selectTab(int)` ignores out-of-range, emits no telemetry).
  - `lib/features/activity/presentation/activity_feed_screen.dart` — the Activity-feed row-tap,
    which consumes the SAME resolver + `navigate` from **within** the Activity tab (an in-tab
    navigation that must NOT switch tabs).

  This ADR ratifies where the tab-switch lives, the target→tab mapping, the switch-then-push
  ordering and cold-start timing guarantee, the Activity-row-tap exclusion, and the telemetry
  decision. It binds the Designer and the Flutter Dev. It authorises no schema, rules, index,
  Cloud Function, or plugin change.

  ### Decision

  **1. Mapping lives on the target; the side effect lives in the handler.** Add an
  `int? get homeTabIndex` getter to the sealed `DeepLinkTarget` and override it per case
  (options (a)+(c) of the kickoff escalation). `DeepLinkHandler.handleDeepLink` reads the app
  container's `shellNavigationControllerProvider.notifier` and calls `selectTab(homeTabIndex)`
  when non-null, **before** calling `NotificationDeepLinks.navigate`. `navigate` therefore stays
  **Riverpod-free** — no `WidgetRef`, container, or selector parameter is threaded into it. This
  keeps the routing contract a pure function of the target while the Riverpod side effect stays
  in the one place (the handler) that already owns a container, and the Activity-feed row-tap —
  which calls `navigate` directly, never the handler — is excluded by construction.

  **2. Target → primary-tab mapping (PM + Designer ratified).**

  | Target | `homeTabIndex` | Tab | Snackbar |
  |---|---|---|---|
  | `DeepLinkExpenseDetail` | `1` | Friends | — (pushes Expense Detail) |
  | `DeepLinkFriendDetail` | `1` | Friends | — (pushes Friend Detail) |
  | `DeepLinkUnavailable` | `3` | Activity | "This item is no longer available." |
  | `DeepLinkGroupsComingSoon` | `null` | (no switch) | "Groups are coming soon." |

  Expense and friend detail are both friends-cluster screens that push **over** the Friends tab,
  so pop lands on Friends. `DeepLinkUnavailable` (e.g. `expense_deleted`) maps to Activity
  because the item lived in the activity feed; the existing SCR-25 snackbar is preserved and no
  detail is pushed. `DeepLinkGroupsComingSoon` does not switch (forward-compat; Groups is a
  Sprint 3 epic). The indices mirror the canonical `OBTBottomNav.tabs` order (Home 0 / Friends 1
  / Groups 2 / Activity 3 / Profile 4); the handler derives the telemetry token from
  `OBTBottomNav.tabs[index].telemetryLabel`, so there is no second source of tab tokens.

  **3. Switch-then-push ordering and the cold-start timing guarantee.** `selectTab` is a
  synchronous state set; it runs **before** the awaited `navigate` push, so the underlying
  IndexedStack is already on the correct tab when the detail screen is presented full-screen
  above it — no visible flash of the wrong tab. The tab switch must occur only when
  `AuthenticatedShell` is mounted: for `background`/`foreground` the shell is mounted by
  definition; for `coldStart` and the pending replay this is guaranteed by the existing
  post-`AuthenticatedWithProfile` `addPostFrameCallback` in `NotificationsLifecycleHost`. A
  deep-link arriving while a non-shell route is on top (e.g. mid-onboarding, unauthenticated)
  still caches to `pendingDeepLinkProvider` and replays on sign-in — that behaviour is
  preserved unchanged.

  **4. Keep the root-navigator push (no per-tab Navigator).** The detail screen continues to be
  presented full-screen above the shell via the root navigator; this PR only also selects the
  underlying tab. A full per-tab nested-`Navigator` / `go_router` migration is Sprint 3 and out
  of scope.

  **5. Telemetry — extend, do not re-declare.** `fcm_notification_tapped` is extended with one
  **non-identifying** `target_tab` enum parameter ∈ {`friends`, `activity`, `none`} alongside
  the existing `notification_type` and `source`. It is **not** a new event. The `uid`, any
  friendship composite, and raw entity IDs must NEVER be a parameter (SRS line 308 / ADR-0013);
  `target_tab` is a fixed lowercase tab token and carries no identity.

  **6. Activity-feed row-tap exclusion is load-bearing.** `ActivityFeedScreen._onRowTap` keeps
  calling `NotificationDeepLinks.navigate` directly and must never call `selectTab`. A
  boundary-contract grep over `activity_feed_screen.dart` guards against a future refactor
  coupling them.

  ### Consequences

  - **Changed files:** `lib/core/routing/notification_deep_links.dart` (the `homeTabIndex`
    getter on the sealed type + four overrides; `navigate` unchanged) and
    `lib/features/notifications/application/deep_link_handler.dart` (the `selectTab` call before
    `navigate` + the `target_tab` telemetry parameter, importing
    `shell_navigation_controller.dart` and `obt_bottom_nav.dart`). No new production file.
  - **Architectural firsts:** the first **notification** consumer of
    `shellNavigationControllerProvider` (closing the #63 §5 deferral in full), and the first
    cross-feature reach from `notifications` into the `shell` controller. With this, every
    FR-AC requirement (FR-AC-01..05) is fully shipped.
  - **Riverpod scoping.** `shellNavigationControllerProvider` is root-scoped (no `dependencies`
    list) and resolves to the single root-container instance the shell `ref.watch`es; the
    handler reads it from the same app container, so `selectTab` mutates the instance the shell
    observes. The provider is `autoDispose` but the mounted shell is its keep-alive watcher
    during every dispatch path, so the set is observed (not disposed mid-frame).
  - **Required tests** (Flutter Dev / QA): target→`homeTabIndex` unit mapping; handler dispatch
    selecting the right tab per target across the foreground/background/cold-start sources; the
    cold-start replay ordering (tab selected on the post-auth frame, before the push); the
    `target_tab` telemetry value + a PII-leak assertion (no `uid`/composite in any parameter);
    and the Activity-row-tap boundary-grep guard. Per-feature coverage ≥ 70%.
  - **No backend or plugin change.** No Cloud Function, `firestore.rules`,
    `firestore.indexes.json`, or schema change; no new Flutter plugin → no `ios/Podfile.lock`
    change. Invariants 1 (integer paise) and 2 (`simplifiedBalances` server-only) are N/A — no
    money, no balance; Invariant 4 reinforced (single project, emulator-tested).
  - **Relationship to prior ADRs.** ADR-0013 (PII-safe telemetry): `fcm_notification_tapped`
    stays type + source + the non-identifying `target_tab`. The #63 / FR-PR-04 Architect Notes
    §2 introduced `shellNavigationControllerProvider` and §5 deferred this exact consumer; this
    ADR closes that deferral. ADR-0004 (Riverpod): the side effect stays out of the pure router
    and inside the container-holding handler.

  ### Alternatives Considered

  - **Thread a `WidgetRef` / `tabIndex` selector into `NotificationDeepLinks.navigate`**
    (escalation option (b)) — rejected: it couples the pure router to Riverpod and would drag the
    Activity-feed row-tap (which calls `navigate`) into the tab-switch surface, the exact
    coupling AC-6 forbids.
  - **A `Map<Type, int>` mapping table in the handler** — rejected in favour of the `homeTabIndex`
    getter, which keeps the mapping co-located with each sealed case and exhaustively checked by
    the switch/override discipline.
  - **Switch the tab inside `NotificationsLifecycleHost` (per dispatch source)** — rejected: the
    handler is the single choke point all four sources already funnel through, so the switch
    belongs there once, not replicated across the four call sites.
  - **A new `notification_tab_switched` telemetry event** — rejected: the tap is already observed
    by `fcm_notification_tapped`; a `target_tab` parameter on it is sufficient and avoids event
    proliferation.
  - **Navigate within a per-tab nested Navigator (`go_router` ShellRoute)** — deferred to Sprint 3
    (ADR-noted in the PR #56 shell story §2.1); the minimal switch-then-root-push is the
    lowest-risk change for v1.0.
  - **Foreground banner tap does NOT switch tabs** — rejected: one handler, one contract; a banner
    tap that routed differently from a background tap would be a surprising inconsistency. The
    Designer ratified the consistent behaviour.

  ---

  ## ADR-0019: OS Settings Deep-Link — `app_settings` Behind a Core `AppSettingsService` Seam (AC-11)

  **Status:** Accepted

  ### Context

  AC-11 (FR-AC-04, SRS section 4.7) requires that when an OS permission is denied, the app
  offers an "Open Settings" CTA that deep-links to the app's OS settings page. Two surfaces
  shipped short of that because no Flutter plugin capable of opening an OS settings screen was
  in the lockfile:

  - **SCR-27 Notification Preferences** (`lib/features/profile/presentation/notification_preferences_screen.dart`,
    `_OsPermissionBanner`). PR #55 shipped the AC-11 banner **without** the button: the
    FR-PR-03 story **§2.4** ratified `FirebaseMessaging.instance.openAppNotificationSettings()`
    from the existing `firebase_messaging`, but that method does not exist on the Dart API
    (re-verified at this kickoff in the installed `firebase_messaging-16.3.0`), so the §2.4
    fallback ladder shipped the banner copy alone and §2.4 **REJECTED** pulling
    `app_settings`/`permission_handler` as a 5-SP scoping decision.
  - **SCR-10 Add Friend contact-permission** (`lib/features/friends/data/contact_service.dart`,
    `FlutterContactService.openSettings()`). It called `FlutterContacts.openExternalPick()` — a
    contact-picker fallback, not the OS settings page — with a line-77 TODO naming `app_settings`.

  This ADR ratifies the dependency choice and the seam. It authorises no schema, rules, index,
  or Cloud Function change.

  ### Decision

  **1. Add exactly one plugin: `app_settings: ^7.0.0`.** It is single-purpose, so it carries the
  smallest dependency-graph and `ios/Podfile.lock` delta. `AppSettings.openAppSettings(type:)`
  covers both needs: `AppSettingsType.notification` (Android `ACTION_APP_NOTIFICATION_SETTINGS`;
  iOS the app settings page) and the default `AppSettingsType.settings` (Android
  `ACTION_APPLICATION_DETAILS_SETTINGS`; iOS `UIApplication.openSettingsURLString`). Kickoff
  verification: `7.0.0` resolves; its iOS podspec targets platform **11.0**, below the project's
  iOS **15.0** Podfile target (no connectivity_plus-style version break); both enum values exist.
  This **reverses** the FR-PR-03 §2.4 "REJECTED `app_settings`/`permission_handler`" note, which
  was an interim scoping decision; the convenience deep-link is now in scope as its own chore.

  **2. One shared seam behind a provider.** `lib/core/services/app_settings_service.dart`
  (`AppSettingsService` abstract + `DefaultAppSettingsService` + `appSettingsServiceProvider`),
  a thin binding shim with zero business logic — exactly the `UrlLauncherService` /
  `ImagePickerService` pattern under `lib/core/services/`. Two methods,
  `openNotificationSettings()` and `openAppSettings()`. Both call sites — the SCR-27 banner and
  the SCR-10 `FlutterContactService` — bind to this seam, never to the plugin directly, so the
  platform channel (unavailable in `flutter test`) is faked via a Riverpod override. First shared
  consumer of a single permission-settings seam across two features (`notifications`/`profile`
  and `friends`).

  **3. Telemetry — one PII-free event.** `permission_settings_opened` with a single
  non-identifying `surface` enum ∈ {`notifications`, `contacts`}, declared in
  `telemetry-plan.md §1.8` and logged at the **presentation** layer (the banner button and the
  Add Friend `_openContactSettings` callback), never inside the data-layer shim. No `uid`,
  friendship composite, or raw entity ID (SRS line 308 / ADR-0013).

  **4. No Android `<queries>` entry.** The plugin uses system settings intents
  (`ACTION_APP_NOTIFICATION_SETTINGS` / `ACTION_APPLICATION_DETAILS_SETTINGS`), which target the
  Settings app via well-known system actions — not arbitrary-package visibility (unlike the
  FR-PR-05 `mailto` `<queries>`). iOS `Podfile.lock` **does** change and is committed in the same
  PR (the CI "Build iOS (no signing)" job runs vanilla `pod install`, which fails on a stale lock).

  ### Consequences

  - **New files:** `lib/core/services/app_settings_service.dart`,
    `lib/core/telemetry/permission_settings_telemetry.dart`.
  - **Changed files:** `pubspec.yaml` (+`app_settings`), `pubspec.lock`, `ios/Podfile.lock`
    (+`app_settings` pod, 6 insertions, no collateral version bumps),
    `notification_preferences_screen.dart` (`_OsPermissionBanner` → `ConsumerWidget` + button;
    stale §2.4 doc comment corrected), `contact_service.dart` (`openSettings()` delegates to
    the seam; TODO removed; constructor takes `AppSettingsService`),
    `add_friend_screen.dart` (`_openContactSettings` logs telemetry + calls the controller).
  - **Invariants.** 1 (integer paise) and 2 (`simplifiedBalances` server-only) are N/A — no
    money, no balance. **Invariant 3 (system share sheet) is N/A and not conflated** — opening
    OS settings is not sharing and is never routed through `Share.share`. Invariant 4 reinforced
    (single project, emulator/faked-seam tested).
  - **Relationship to prior ADRs.** ADR-0013 (PII-safe telemetry): the new event carries only a
    `surface` enum. The `UrlLauncherService` (FR-PR-05) and `ImagePickerService` (FR-EX-05)
    shims are the precedent this seam mirrors.

  ### Alternatives Considered

  - **`permission_handler` instead of `app_settings`** — rejected: its `openAppSettings()` would
    also subsume the permission-request lifecycle, a larger refactor than this chore needs; the
    contact/notification request flows already work. Exactly one plugin is added, never both.
  - **`FirebaseMessaging.instance.openAppNotificationSettings()`** (FR-PR-03 §2.4 RATIFIED) —
    rejected: the method does not exist on the installed `firebase_messaging` Dart API; this ADR
    supersedes that note.
  - **Notifications-only, leave the friends `openExternalPick` as a fast-follow** — rejected: the
    dependency is paid once and the friends TODO is the same gap; unifying now closes both.
  - **Log telemetry inside `AppSettingsService`** — rejected: the shim stays business-logic-free;
    telemetry is logged at the presentation layer, matching the repo convention.
  - **No telemetry** — rejected by the PM: one PII-free `surface`-only event gives useful
    observability of how often users reach the permanently-denied path.

  ---
