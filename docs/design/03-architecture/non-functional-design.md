# Non-Functional Design

This document maps every non-functional requirement from SRS section 5 to the
architectural mechanisms that satisfy it. Each subsection corresponds to an NFR
category and includes a traceability table linking NFR IDs (or bullet
requirements) to concrete design decisions.

---

## 1. Performance (SRS section 5.1)

### 1.1 Architectural mechanisms

**Cold start within 3 seconds (NFR-PE-01).** The Flutter application performs
minimal work on the splash screen: it initialises Firebase Auth and checks for a
persisted credential. All other SDK initialisation (Analytics, Crashlytics, FCM,
App Check) is deferred to post-first-frame. Tree-shaking and `--split-debug-info`
ensure that the compiled binary contains no dead code. The Firestore persistent
cache is enabled by default so that the first read after launch can be served from
local storage.

**Warm start within 1 second (NFR-PE-02).** Firebase Auth persists the session
token on device. On warm start the app skips the OTP flow entirely and navigates
directly to the Home dashboard. Firestore's local cache serves the last-known
snapshot while the listener re-establishes its server connection.

**Dashboard render within 1.5 seconds (NFR-PE-03).** The Home screen attaches a
real-time listener to the user's `friendships` and `groups` documents, reading the
pre-computed `simplifiedBalances` field (invariant 2). Because the balance data is
denormalised and pre-aggregated by the Cloud Function, the client performs no
computation — it maps the snapshot directly to UI widgets. A skeleton-first
rendering pattern displays placeholder shapes within the first frame, replaced by
data once the snapshot arrives.

**Expense save within 2.5 seconds (NFR-PE-04).** The expense write and the
subsequent `recomputeSimplifiedBalances` Cloud Function execution both occur
within the `asia-south1` (Mumbai) region, eliminating cross-region latency. The
Firestore write returns to the client optimistically via the local cache, and the
Cloud Function trigger fires server-side without requiring a client round-trip for
the recomputation.

**Firestore read latency within 400 ms (NFR-PE-05).** All Firestore instances and
Cloud Functions are co-located in `asia-south1`. The Firestore SDK's local cache
serves reads immediately when the device is online, with the server snapshot
arriving asynchronously to confirm or update the local value.

**App size within 60 MB Android / 90 MB iOS (NFR-PE-06).** The application avoids
heavy native SDKs. Firebase packages are the primary native dependency. Image
assets are compressed, and deferred loading (`deferred as`) is used for
non-critical feature modules to reduce the initial download size. The release
build uses `--split-per-abi` on Android to produce architecture-specific APKs.

### 1.2 Traceability

| NFR ID | Requirement | Architectural mechanism |
|---|---|---|
| NFR-PE-01 | Cold start ≤ 3 s (P95) | Deferred SDK init, tree-shaking, persistent cache |
| NFR-PE-02 | Warm start ≤ 1 s (P95) | Persisted auth session, Firestore local cache |
| NFR-PE-03 | Dashboard render ≤ 1.5 s (P95) | Pre-computed `simplifiedBalances`, real-time listener, skeleton UI |
| NFR-PE-04 | Expense save ≤ 2.5 s (P95) | In-region Firestore write + Cloud Function trigger |
| NFR-PE-05 | Firestore read ≤ 400 ms (P95) | Co-located region, SDK cache-first reads |
| NFR-PE-06 | App size ≤ 60 MB / 90 MB | No heavy SDKs, `--split-per-abi`, deferred loading |

---

## 2. Scalability (SRS section 5.2)

### 2.1 Architectural mechanisms

**100K to 1M MAU without architectural change.** The data model uses top-level
collections (`users`, `friendships`, `groups`, `settlements`) that Firestore
distributes automatically across storage splits. No single collection acts as a
bottleneck because queries are always scoped to a user's own participation
(filtered by `memberIds`). Cloud Functions scale horizontally via Firebase's
managed infrastructure with no provisioned concurrency ceiling for v1.0.

**Avoidance of hot documents.** Each expense is its own document within a
subcollection, and each friendship/group is a separate document. The
`simplifiedBalances` field is updated only when an expense or settlement mutates
within that context — not on every app open. Write frequency to any single
document is bounded by the rate of financial mutations within that specific
group or friendship, which is well below Firestore's 1 write/sec sustained limit
for a single document.

**Cloud Functions in `asia-south1`.** All Cloud Functions, including
`recomputeSimplifiedBalances`, are deployed to the Mumbai region. This
co-location with the Firestore instance eliminates cross-region hops for
triggered functions and callable invocations.

**Simplified-debts computation within 500 ms (P95) for groups up to 50
members.** The algorithm (SRS section 7.4) is O(n log n) where n is the number
of group members: it partitions members into creditors and debtors, sorts both
lists, and greedily pairs them. For 50 members with potentially hundreds of
expenses, the scan of expenses is O(e) and the simplification is O(n log n),
both well within the 500 ms budget on Cloud Functions' compute allocation.

### 2.2 Traceability

| Requirement | Architectural mechanism |
|---|---|
| 100K–1M MAU linear scaling | Top-level collections, participant-scoped queries, horizontal Cloud Function scaling |
| No hot documents | Per-context subcollections, bounded write frequency per document |
| Region-pinned functions | All functions deployed to `asia-south1` |
| Simplified-debts ≤ 500 ms (P95, 50 members) | O(n log n) greedy algorithm, in-region execution |

---

## 3. Availability and Reliability (SRS section 5.3)

### 3.1 Architectural mechanisms

**99.9% uptime.** The application depends on Firebase's managed services, which
carry a 99.95% SLA for Firestore and Cloud Functions in single-region
configurations. The architecture does not introduce any self-managed
infrastructure that could lower this baseline.

**Crash-free rate of 99.5% or higher.** Firebase Crashlytics is integrated on
both platforms with mandatory dSYM and Dart symbol upload from the CI release
pipeline (SRS section 9.2). Non-fatal errors (e.g. network timeouts) are caught
and reported without crashing the application. Riverpod's `AsyncValue` pattern
ensures that provider errors surface as error states in the UI rather than
unhandled exceptions.

**Atomic financial mutations.** All state-modifying operations on financial data
use Firestore transactions or batched writes (SRS section 7.3). The
`recomputeSimplifiedBalances` Cloud Function reads all non-deleted expenses and
settlements within a Firestore transaction and writes the resulting
`simplifiedBalances` atomically. If any concurrent write conflicts with the
transaction, Firestore retries automatically. This guarantees that
`simplifiedBalances` is always consistent with the underlying expense and
settlement documents.

### 3.2 Traceability

| Requirement | Architectural mechanism |
|---|---|
| 99.9% uptime | Firebase managed SLA, no self-managed infra |
| Crash-free rate ≥ 99.5% | Crashlytics integration, symbol upload in CI, `AsyncValue` error handling |
| Atomic financial mutations | Firestore transactions for recomputation, batched writes for multi-doc updates |

---

## 4. Security (SRS section 5.4)

### 4.1 Architectural mechanisms

**TLS 1.2+ for all traffic.** Firebase SDKs enforce TLS 1.2 or higher on all
client–server communication by default. No additional configuration is required.

**Participant-scoped Firestore Security Rules.** Every document in the data model
includes a `memberIds` array (or equivalent participant field). Security Rules
restrict reads and writes to authenticated users whose `request.auth.uid` appears
in that array. There are no public collections (SRS section 7.5).

**Server-side auth verification.** Every Cloud Function validates the caller's
authentication state via the Firebase Admin SDK before performing any operation.
Callable functions reject unauthenticated invocations; Firestore-triggered
functions operate under the service account's authority.

**No PII in Crashlytics or Analytics.** The application never sets custom
Crashlytics keys or Analytics user properties containing phone numbers, display
names, or photo URLs. User identification in Crashlytics uses only the opaque
Firebase `uid`.

**Receipt images access-controlled.** Receipt images in Cloud Storage are stored
under paths scoped to the expense context (e.g.
`receipts/{contextType}/{contextId}/{expenseId}`). Storage Security Rules require
that the requesting user is a participant in the corresponding Firestore document.

**Secrets management.** API keys, signing certificates, and service account
credentials are stored exclusively in GitHub Actions secrets. They are never
committed to source control (SRS section 5.4).

**App Check enforcement.** App Check is enabled with Play Integrity (Android) and
DeviceCheck (iOS) attestation providers. Firestore, Cloud Storage, and Cloud
Functions enforce App Check tokens, rejecting requests from unattested clients.
The Firebase Emulator Suite bypasses App Check during local testing (SRS section
8).

**`simplifiedBalances` write restriction (invariant 2).** Firestore Security
Rules explicitly deny any client write operation that modifies the
`simplifiedBalances` field on `friendships` or `groups` documents. Only the Cloud
Functions service account, which bypasses Security Rules via the Admin SDK, may
write this field. This is a non-negotiable invariant (.github/shared/invariants.md,
invariant 2).

### 4.2 Traceability

| Requirement | Architectural mechanism |
|---|---|
| TLS 1.2+ | Firebase SDK default enforcement |
| Participant-scoped access | `memberIds`-based Security Rules on all collections |
| Server-side auth in functions | Firebase Admin SDK verification in every Cloud Function |
| No PII in telemetry | Opaque `uid` only; no custom keys with personal data |
| Receipt access control | Storage Rules scoped to expense context participants |
| Secrets in CI only | GitHub Actions secrets; never in source |
| App Check | Play Integrity + DeviceCheck; enforced on Firestore, Storage, Functions |
| `simplifiedBalances` client-read-only | Security Rules deny client writes; Admin SDK bypasses for Cloud Function |

---

## 5. Privacy and Compliance (SRS section 5.5)

### 5.1 Architectural mechanisms

**DPDP Act, 2023 compliance.** The application collects only the minimum personal
data required: phone number (for authentication), display name, and optional
profile photo. A consent notice is presented during onboarding before any data
is collected. The privacy policy and terms of service are linked from both the
onboarding screen and the profile screen (SRS section 5.5).

**Account deletion within 30 days.** Account deletion is implemented as a Cloud
Function (not client-side logic) to ensure completeness and prevent partial
deletion. The function performs the following atomically or in a controlled
sequence:

1. Anonymises personal data (display name, photo URL) on the `users` document.
2. Removes or anonymises the user's identity from shared contexts (group member
   lists, expense payer/split entries, friendship documents) so that other
   participants see "Deleted User" rather than PII.
3. Deletes the Firebase Auth record.
4. Deletes FCM tokens and any stored receipts uploaded by the user.

The 30-day window allows for a grace period; the function may be triggered
immediately or scheduled, as determined by the implementation.

**Data anonymisation in shared contexts.** When a user deletes their account,
their `userId` is retained in historical expense and settlement documents (to
preserve the mathematical integrity of simplified balances), but all PII fields
are replaced with anonymised values. The `simplifiedBalances` are recomputed
after anonymisation to ensure consistency.

### 5.2 Traceability

| Requirement | Architectural mechanism |
|---|---|
| DPDP Act compliance | Minimum data collection, consent at onboarding, linked privacy policy |
| Account deletion within 30 days | Server-side Cloud Function; anonymisation of PII in shared contexts |
| Data anonymisation | PII fields replaced; `userId` retained for balance integrity |

---

## 6. Usability and Accessibility (SRS section 5.6)

### 6.1 Architectural mechanisms

**Two-tap rule for primary actions.** The information architecture places all
primary actions (add expense, settle up, view group) within two taps of the Home
dashboard. The bottom navigation bar provides direct access to Friends, Groups,
and Activity. The floating action button on the Home screen opens the
add-expense flow directly.

**Minimum tap targets.** The design system enforces minimum interactive element
sizes of 44x44 pt on iOS and 48x48 dp on Android. This is codified in the shared
component library so that individual feature screens inherit compliant tap targets
by default.

**WCAG AA contrast.** The colour token system (defined in the design system
documentation) specifies foreground/background pairings that meet or exceed the
4.5:1 contrast ratio for body text and 3:1 for large text, in both light and dark
themes.

**Screen-reader compatibility.** Every interactive widget carries a semantic label
via Flutter's `Semantics` widget or the `semanticLabel` property. The
architecture mandates that custom widgets expose semantic properties, and this is
verified during QA accessibility walkthroughs (test-strategy.md, non-functional
testing).

**Dynamic font scaling and dark mode.** The Flutter application respects the
platform's `MediaQuery.textScaleFactor` and `platformBrightness` settings. Theme
data is defined using `ThemeData` with both light and dark variants. No text sizes
are hardcoded; all use the design system's typography scale.

**Internationalisation-ready architecture.** All user-facing strings are
externalised via `.arb` files and the `intl` package. The v1.0 release ships with
English only, but the architecture supports adding Hindi and other Indian
languages without structural refactoring (SRS section 5.6).

### 6.2 Traceability

| Requirement | Architectural mechanism |
|---|---|
| 2-tap rule | IA: bottom nav + FAB on Home |
| Tap targets ≥ 44 pt / 48 dp | Design system component library with enforced minimums |
| WCAG AA contrast (≥ 4.5:1) | Colour token system with verified pairings |
| VoiceOver / TalkBack support | `Semantics` widgets on all interactive elements |
| Dynamic font scaling | `MediaQuery.textScaleFactor`, typography scale tokens |
| Dark mode | Dual `ThemeData` (light/dark), `platformBrightness` |
| Future language support | `.arb` externalisation, `intl` package |

---

## 7. Maintainability (SRS section 5.7)

### 7.1 Architectural mechanisms

**Linting and style.** The Dart codebase uses `very_good_analysis` (or
`flutter_lints`) as its lint rule set, enforced in CI. TypeScript Cloud Functions
follow ESLint with strict type-checking. Both are configured as pre-commit hooks
via Lefthook.

**Feature-first modular structure.** The Flutter application is organised into
feature modules (`auth`, `friends`, `groups`, `expenses`, `settlements`,
`profile`, `common`) as specified in SRS section 13.1. Each module encapsulates
its own data layer, state management, and presentation, reducing coupling between
features.

**State management with Riverpod 2.x.** Riverpod provides compile-time safety,
testability via provider overrides, and clear dependency graphs. This decision is
recorded as an ADR (see `.github/shared/decision-log.md`).

**Test coverage enforcement.** CI enforces ≥ 70% coverage for non-UI code and
≥ 50% overall (test-strategy.md). The simplified-debts module requires 100%
branch coverage of the canonical test matrix.

**Documentation.** All public Dart APIs use DartDoc comments. All Cloud Functions
use JSDoc comments. The simplified-debts algorithm is isolated in a single module
(`functions/src/simplifiedDebts.ts`) with its own dedicated test suite.

### 7.2 Traceability

| Requirement | Architectural mechanism |
|---|---|
| Consistent linting | `very_good_analysis` / ESLint, enforced in CI and Lefthook |
| Feature-first folder structure | Modular architecture per SRS section 13.1 |
| Riverpod 2.x state management | ADR-recorded decision; compile-time safe, testable |
| ≥ 70% non-UI / ≥ 50% overall coverage | CI-enforced thresholds |
| DartDoc / JSDoc on public APIs | Documentation standards in coding-standards.md |
| Isolated simplified-debts module | Single-file pure function with canonical test matrix |

---

## 8. Portability (SRS section 5.8)

### 8.1 Architectural mechanisms

**Single Flutter codebase.** The application deploys to both iOS and Android from
a single Dart codebase. Platform-specific code is limited to cases where no
cross-platform Flutter plugin exists (e.g. contact picker bridges). Any
platform-specific logic is isolated behind abstract interfaces so that the
business logic layer remains platform-agnostic.

**No unnecessary native dependencies.** The architecture avoids native SDKs
beyond Firebase and essential platform integrations. This minimises
platform-specific build failures and reduces the maintenance burden of native
dependency upgrades.

### 8.2 Traceability

| Requirement | Architectural mechanism |
|---|---|
| Single codebase for iOS and Android | Flutter cross-platform framework |
| No platform-specific native code unless required | Abstract interfaces for platform bridges |

---

## 9. Localisation and Internationalisation (SRS section 5.9)

### 9.1 Architectural mechanisms

**Externalised strings.** All user-facing text is defined in `.arb` files and
accessed via generated `AppLocalizations` classes. No string literals appear in
widget code. This is validated by a pseudolocalisation pass during QA
(test-strategy.md).

**IST date/time display.** All timestamps stored in Firestore use UTC. The client
converts to `Asia/Kolkata` (IST) at the presentation layer, regardless of the
device's local timezone setting.

**Indian currency formatting.** Monetary values are stored as integer paise
(invariant 1, SRS section 7.3). The UI layer formats display values using the
Indian numbering system (e.g. 1,00,000) with two decimal places and the `₹`
symbol prefix. The formatting logic is centralised in a shared utility to ensure
consistency across all screens.

### 9.2 Traceability

| Requirement | Architectural mechanism |
|---|---|
| Strings via `intl` / `.arb` files | Generated `AppLocalizations`, no hardcoded strings |
| IST display regardless of locale | UTC storage, `Asia/Kolkata` conversion at UI layer |
| Indian numbering, ₹ prefix, 2 decimals | Centralised currency formatter, integer paise storage |

---

## 10. Observability (SRS section 5.10)

### 10.1 Architectural mechanisms

**Crashlytics on both platforms.** Firebase Crashlytics is integrated for both
iOS and Android. The CI release pipeline uploads dSYM files (iOS) and Dart debug
symbols automatically on every release build, ensuring that crash reports are
fully symbolicated. PII is excluded from crash reports (SRS section 5.4).

**Analytics event tracking.** Firebase Analytics tracks the following key funnel
events, as specified in SRS section 5.10:

- `signup_started`, `signup_completed`
- `expense_save_succeeded`, `settlement_recorded`
- `group_created`, `friend_added`
- `simplified_balance_computed`
- `support_email_opened`

Event parameters contain only non-PII identifiers (opaque `uid` values, context
IDs). Custom user properties do not include phone numbers, names, or photo URLs.

**Structured Cloud Function logging.** All Cloud Functions emit structured JSON
logs via the Firebase Functions logger. Log entries include the function name,
execution duration, context ID, and outcome (success or error code). Cloud
Monitoring alerts are configured for error-rate spikes exceeding a defined
threshold.

### 10.2 Traceability

| Requirement | Architectural mechanism |
|---|---|
| Crashlytics on iOS and Android | SDK integration, dSYM/symbol upload in CI release pipeline |
| Analytics for key funnels | Named events per SRS section 5.10, no PII in parameters |
| Structured Cloud Function logs | JSON logger, Cloud Monitoring alerts on error-rate spikes |

---

## Cross-Cutting Invariant Compliance

The following table maps the four non-negotiable invariants
(.github/shared/invariants.md) to the NFR categories they intersect:

| Invariant | Intersecting NFR categories | Enforcement mechanism |
|---|---|---|
| 1. Money is integer paise | Performance (no conversion overhead), Localisation (UI-layer formatting) | Type constraints in schema, lint rules, CI tests |
| 2. `simplifiedBalances` server-maintained | Performance (pre-computed reads), Security (client-read-only), Reliability (atomic recomputation) | Firestore Security Rules, Cloud Function transaction |
| 3. System share sheet only | Portability (no platform-specific share SDKs), Maintainability (no third-party messaging imports) | Code review, lint rules |
| 4. Single Firebase project | Scalability (single-region co-location), Observability (unified telemetry), Maintainability (no env drift) | CI validation, `.firebaserc` single-entry enforcement |
