# Decision Log

Architecture Decision Records (ADRs) for the OneByTwo project.

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

OneByTwo targets casual and power users in India who want a clear, single answer to
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
operational complexity, cost, and configuration drift risk. OneByTwo is a v1.0
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

**Status:** Proposed — architect to confirm

### Context

Flutter offers several state management solutions. The SRS specifies "Riverpod 2.x
(or BLoC if architect prefers)" (section 5.7). A decision must be recorded.

### Decision (Proposed)

Use Riverpod 2.x as the sole state management solution.

### Rationale

- Riverpod is compile-safe and does not depend on `BuildContext` for provider access,
  making it easier to test and refactor.
- Riverpod 2.x supports code generation (`riverpod_generator`) for reduced
  boilerplate.
- The team is starting fresh with no legacy BLoC code to maintain.

### Consequences

- All state lives in Riverpod providers, organised by feature folder.
- Developers must follow the Riverpod documentation and conventions for
  `AsyncNotifier`, `StreamProvider`, and `FutureProvider`.
- If the architect prefers BLoC, this ADR must be updated before any feature code is
  written.

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
