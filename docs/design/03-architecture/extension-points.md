# Architecture — Extension Points

> **Document owner:** Solution Architect
> **Version:** 1.0
> **Status:** Draft — pending Flutter Dev and Functions Dev review
> **Audience:** Solution Architect, Flutter Developer, Cloud Functions Developer, Product Manager

---

## Purpose

This document catalogues the architectural seams in the v1.0 data model and backend where post-v1.0 features (SRS section 12.3) are intended to dock. Each seam is a field, discriminator, or strategy pattern that exists in the v1.0 architecture with a single, default value but is designed to accept additional values in v1.1 without schema migration, backfill scripts, or breaking changes.

This document is the architecture counterpart to:

- `docs/design/01-information-architecture/extension-points.md` — navigation, flows, and screen structure.
- `docs/design/02-design-system/extension-points.md` — visual tokens, component variants, and interaction patterns.

Where those documents address the client-side user experience, this document addresses Firestore schema fields, Cloud Function modules, and backend contracts.

All features referenced below are explicitly out of scope for v1.0 (SRS section 12.3). No implementation work for these features shall occur in v1.0 sprints. This catalogue exists solely to ensure the v1.0 architecture is structured so that these additions are additive — new field values, new optional fields, new strategy implementations — never destructive.

**Mandatory v1.0 rule:** For every extension point below, the v1.0 codebase MUST write the field or discriminator with its stated default value on every document at creation time, rather than omitting it. This ensures that v1.1 queries and composite indexes against these fields work immediately without backfill migrations across existing documents.

**Exception (as implemented):** `recurringRule` (ARCH-EXT-03) is the one field the client does **not** write — it is omitted, and the security rules accept it absent **or** `null`. No v1.0 composite index references it, so the backfill risk does not apply. See ARCH-EXT-03.

---

## Extension Points

### ARCH-EXT-01: Settlement Method Discriminator

| Field | Detail |
|---|---|
| **ID** | ARCH-EXT-01 |
| **Name** | Settlement method discriminator |
| **Location** | `settlements/{settlementId}`, field `method` |
| **Corresponding IA extension** | IA-EXT-01 (Settle-up UPI slot) |
| **Corresponding DS extension** | DS-EXT-03 (UpiAppLogoRow component) |
| **v1.0 value** | Always `'manual'`. The field is written on every settlement document at creation time. The v1.0 Settle Up flow (SRS section 6.3, item 9) supports only manual settlement recording: amount, date, and optional note (FR-SE-05). No payment integration exists. |
| **v1.1 change** | Adds `'upi'` as a second permitted value. When `method` is `'upi'`, two additional fields are present: `upiTransactionId` (string, the UPI reference returned by the payment app callback) and `upiApp` (string, e.g. `'gpay'`, `'phonepe'`, `'paytm'` — the app used for the transaction). These fields are absent or `null` when `method` is `'manual'`. Security rules will be extended to validate that `upiTransactionId` is non-empty when `method` is `'upi'`. (SRS section 12.3, bullet 1.) |
| **Migration impact** | None. Existing `'manual'` documents are unaffected. The new `'upi'` value applies only to newly created documents. Queries filtering on `method == 'manual'` continue to return all historical settlements. Composite indexes on `(contextId, method, date)` work immediately because the field is present on all existing documents. |

**v1.0 implementation mandate:** Every settlement document created in v1.0 MUST include `method: 'manual'` as an explicit field value. Omitting the field would cause v1.1 index queries on `method` to miss legacy documents.

---

### ARCH-EXT-02: Currency Field on Expenses and Settlements

| Field | Detail |
|---|---|
| **ID** | ARCH-EXT-02 |
| **Name** | Currency field on expenses and settlements |
| **Location** | `groups/{groupId}/expenses/{expenseId}`, `friendships/{id}/expenses/{id}`, and `settlements/{settlementId}`, field `currency` |
| **Corresponding IA extension** | None (no IA-level change; formatting only) |
| **Corresponding DS extension** | DS-EXT-04 (Multi-currency token slot) |
| **v1.0 value** | Always `'INR'`. The field is written on every expense and settlement document at creation time. v1.0 is INR-only (SRS sections 1.3, 3.4, 5.9). All monetary values are stored as integer paise (SRS section 7.3, Invariant 1). |
| **v1.1 change** | Supports additional ISO 4217 currency codes (e.g., `'USD'`, `'EUR'`, `'GBP'`). The `amountPaise` field is reinterpreted as the smallest unit of the specified currency (e.g., cents for USD). The `currency` field determines the symbol, grouping pattern, and decimal precision used at the UI layer. The simplified-debts algorithm (SRS section 7.4) operates per-currency; multi-currency groups require separate balance maps keyed by currency code. |
| **Migration impact** | None. Existing documents already carry `currency: 'INR'` and require no update. Queries scoped to `currency == 'INR'` continue to return all historical data. |

**v1.0 implementation mandate:** Every expense and settlement document created in v1.0 MUST include `currency: 'INR'` as an explicit field value.

---

### ARCH-EXT-03: Recurring Rule Sub-Document on Expenses

| Field | Detail |
|---|---|
| **ID** | ARCH-EXT-03 |
| **Name** | Recurring rule sub-document on expenses |
| **Location** | `groups/{groupId}/expenses/{expenseId}` and `friendships/{id}/expenses/{id}`, optional field `recurringRule` |
| **Corresponding IA extension** | IA-EXT-02 (Recurring expense toggle) |
| **Corresponding DS extension** | DS-EXT-02 (RecurrenceChip component) |
| **v1.0 value** | **Absent.** Unlike the other extension fields, the client (`ExpenseDoc`) does **not** write `recurringRule` — it is omitted. The security rules tolerate this by accepting the field absent **or** `null` (`!('recurringRule' in data) || data.recurringRule == null`). The v1.0 expense creation flow captures single-occurrence expenses only (SRS section 6.3, item 8; FR-EX-01). |
| **v1.1 change** | When non-null, contains a sub-document: `{ frequency: 'daily' \| 'weekly' \| 'fortnightly' \| 'monthly' \| 'yearly', interval: number, endDate: timestamp \| null, nextOccurrence: timestamp }`. A scheduled Cloud Function reads expenses where `recurringRule.nextOccurrence <= now`, creates a new expense document copying the template fields, and advances `nextOccurrence` by the specified interval. (SRS section 12.3, bullet 3.) |
| **Migration impact** | None. The field is optional. Existing documents with `recurringRule: null` are single-occurrence expenses and require no update. Queries for recurring expenses (`recurringRule != null`) correctly exclude all v1.0 data. The scheduled Cloud Function only processes documents where `recurringRule.nextOccurrence` is a valid timestamp. |

**v1.0 implementation mandate (revised to match implementation):** The client **omits**
`recurringRule`; the security rules accept it absent or `null`. Because the field is
optional and no v1.0 composite index references it, the absence on legacy documents is
handled at query time (treat a missing rule as non-recurring) rather than by a
strict create-time default. A v1.1 recurring-expense rollout writes the field going
forward. This is the single documented exception to design principle 1.

---

### ARCH-EXT-04: Locale Field on User Documents

| Field | Detail |
|---|---|
| **ID** | ARCH-EXT-04 |
| **Name** | Locale field on user documents |
| **Location** | `users/{userId}`, field `locale` |
| **Corresponding IA extension** | IA-EXT-03 (Language selector row) |
| **Corresponding DS extension** | DS-EXT-01 (Hindi font fallback stack), DS-EXT-05 (RTL layout support) |
| **v1.0 value** | Always `'en-IN'`. The field is written on every user document at creation time. v1.0 ships with English as the sole locale (SRS section 5.9). |
| **v1.1 change** | Supports additional BCP 47 locale codes: `'hi-IN'` (Hindi), `'mr-IN'` (Marathi), `'ta-IN'` (Tamil), and potentially others. The locale field drives: (a) the `.arb` localisation file loaded by the Flutter client; (b) the language used in push notification bodies composed by Cloud Functions; (c) date and number formatting preferences. (SRS section 12.3, bullet 2.) |
| **Migration impact** | None. Existing user documents already carry `locale: 'en-IN'`. The default value serves as the correct backfill for all v1.0 users. Cloud Functions that compose notification text read `locale` from the recipient's user document; all existing documents return `'en-IN'`, preserving current behaviour. |

**v1.0 implementation mandate:** Every user document created in v1.0 MUST include `locale: 'en-IN'` as an explicit field value. Cloud Functions that generate user-facing text (e.g., notification bodies) SHOULD read the `locale` field and use it to select a string template, even if only the `'en-IN'` template exists in v1.0. This avoids a code-path refactor when new locales are added.

---

### ARCH-EXT-05: Notification Channel Expansion

| Field | Detail |
|---|---|
| **ID** | ARCH-EXT-05 |
| **Name** | Notification channel expansion |
| **Location** | Cloud Functions notification module (`functions/src/notifications/`) |
| **Corresponding IA extension** | None (backend-only change) |
| **Corresponding DS extension** | None |
| **v1.0 value** | FCM push notifications only. The module is **function-based**, not a class strategy: it exposes a `NotificationsApi` (`sendExpenseNotification`, `sendSettlementNotification`, `sendReminderNotification`) over an FCM transport (`fcm-send.ts`), with shared `payload-renderer.ts` and `prefs-filter.ts`. There is **no** `NotificationChannel`/`FcmChannel` class today. Notifications are produced by the expense trigger (`onExpenseWriteFriendship`), the settlement trigger (`onSettlementWrite`), and the reminder callable (`sendReminderNotification`). There is **no** group-membership trigger in v1.0. |
| **v1.1 change** | Additional channel implementations may be registered: `SmsChannel` (for users without the app installed, e.g., pre-registered friends added by phone number), `EmailChannel`, or `InAppInboxChannel` (persisted notifications readable within the app). The channel selector reads user preferences from the `notificationPrefs` sub-document on the user document (SRS section 7.2) and dispatches to the appropriate channel(s). |
| **Migration impact** | None. The strategy pattern is a code-level concern; no schema changes are required for existing Firestore documents. The `notificationPrefs` sub-document (SRS section 7.2) already exists on user documents and can be extended with new boolean fields (e.g., `smsEnabled`, `emailEnabled`) without affecting existing preferences. New channel implementations are registered in the Cloud Function module; no client-side changes are needed beyond updating preference controls in the Profile screen. |

**v1.0 implementation note (as built):** The notification module isolates FCM behind a
single transport (`fcm-send.ts`) and shared payload/preference helpers
(`payload-renderer.ts`, `prefs-filter.ts`), so trigger sites do not inline raw FCM API
calls. It is a function-based `NotificationsApi` (per-event send functions) rather than a
class-based strategy/dispatcher; introducing a `NotificationChannel` abstraction and a
dispatcher is the v1.1 step (principle 5), not a v1.0 deliverable.

---

### ARCH-EXT-06: Settlement Verification Status

| Field | Detail |
|---|---|
| **ID** | ARCH-EXT-06 |
| **Name** | Settlement verification status |
| **Location** | `settlements/{settlementId}`, field `verificationStatus` |
| **Corresponding IA extension** | IA-EXT-01 (Settle-up UPI slot) |
| **Corresponding DS extension** | DS-EXT-03 (UpiAppLogoRow component) |
| **v1.0 value** | Always `'unverified'`. The field is written on every settlement document at creation time. In v1.0, all settlements are manually recorded (ARCH-EXT-01: `method: 'manual'`); there is no payment confirmation mechanism, so the system cannot verify that a payment actually occurred. |
| **v1.1 change** | Adds `'verified'` as a second permitted value. When a settlement is created via UPI deep-link (ARCH-EXT-01: `method: 'upi'`), the initial status is `'pending'`. A Cloud Function webhook or callback handler receives the UPI payment confirmation and updates the status to `'verified'`. If the payment fails or times out, the status may transition to `'failed'` and the settlement is not counted in balance computations. Security rules ensure that only the Cloud Functions service account can transition `verificationStatus` — clients may read the field but never write to it, following the same pattern as `simplifiedBalances` (SRS section 7.5). |
| **Migration impact** | None. Existing `'unverified'` documents are semantically correct: manual settlements have no external verification. Queries filtering on `verificationStatus == 'unverified'` return all historical data. The `recomputeSimplifiedBalances` Cloud Function (SRS section 7.3) continues to include all settlements in its computation; v1.1 extends it to exclude settlements where `verificationStatus == 'failed'`. |

**v1.0 implementation mandate:** Every settlement document created in v1.0 MUST include `verificationStatus: 'unverified'` as an explicit field value. Firestore Security Rules MUST mark `verificationStatus` as client-read-only (writable only by the Cloud Functions service account), mirroring the enforcement pattern used for `simplifiedBalances` (SRS section 7.5, Invariant 2).

---

### ARCH-EXT-07: Expense Source Discriminator

| Field | Detail |
|---|---|
| **ID** | ARCH-EXT-07 |
| **Name** | Expense source discriminator |
| **Location** | `groups/{groupId}/expenses/{expenseId}` and `friendships/{id}/expenses/{id}`, field `source` |
| **Corresponding IA extension** | IA-EXT-06 (Receipt OCR auto-fill) |
| **Corresponding DS extension** | DS-EXT-06 (AI Suggestion Card) |
| **v1.0 value** | Always `'manual'`. The field is written on every expense document at creation time. All v1.0 expenses are entered by hand: amount, description, category, date, split method, and optional receipt attachment (SRS section 6.3, item 8; FR-EX-01 through FR-EX-09). |
| **v1.1 change** | Adds `'ocr'` as a second permitted value, indicating the expense was created (or pre-populated) from AI-assisted receipt scanning (SRS section 12.3, bullet 5). When `source` is `'ocr'`, additional metadata fields may be present: `ocrConfidence` (number, 0–100, overall extraction confidence), `ocrExtractedFields` (map recording which fields were auto-filled vs. manually corrected — useful for model retraining). Future values could include `'import'` for CSV/bank-statement imports. |
| **Migration impact** | None. Existing `'manual'` documents are unaffected. Queries filtering on `source == 'manual'` return all historical data. Analytics queries on `source == 'ocr'` correctly return an empty set for the pre-v1.1 period. |

**v1.0 implementation mandate:** Every expense document created in v1.0 MUST include `source: 'manual'` as an explicit field value. Omitting the field would cause v1.1 index queries on `source` to miss legacy documents.

---

## Cross-References

| Extension Point | SRS Sections | IA Extension | DS Extension |
|---|---|---|---|
| ARCH-EXT-01 | 4.6, 6.3 (item 9), 7.2, 12.3 (bullet 1) | IA-EXT-01 | DS-EXT-03 |
| ARCH-EXT-02 | 1.3, 3.4, 5.9, 7.2, 7.3 | None | DS-EXT-04 |
| ARCH-EXT-03 | 6.3 (item 8), 7.2, 12.3 (bullet 3) | IA-EXT-02 | DS-EXT-02 |
| ARCH-EXT-04 | 5.9, 7.2, 12.3 (bullet 2) | IA-EXT-03 | DS-EXT-01, DS-EXT-05 |
| ARCH-EXT-05 | 7.2, 7.3, 12.3 (bullets 1, 2, 6) | None | None |
| ARCH-EXT-06 | 4.6, 7.2, 7.5, 12.3 (bullet 1) | IA-EXT-01 | DS-EXT-03 |
| ARCH-EXT-07 | 4.5, 6.3 (item 8), 7.2, 12.3 (bullet 5) | IA-EXT-06 | DS-EXT-06 |

---

## Schema Field Summary

The following table summarises every field that v1.0 must write with a default value to support these extension points. This serves as a checklist for the Flutter Developer (client-side document creation) and the Cloud Functions Developer (server-side document creation).

| Collection | Field | Type | v1.0 Default | Written By |
|---|---|---|---|---|
| `settlements` | `method` | string | `'manual'` | Client (on settlement creation) |
| `settlements` | `currency` | string | `'INR'` | Client (on settlement creation) |
| `settlements` | `verificationStatus` | string | `'unverified'` | Client (on settlement creation); thereafter Cloud Functions only |
| `expenses` (group and friendship sub-collections) | `currency` | string | `'INR'` | Client (on expense creation) |
| `expenses` (friendship sub-collection; group is data-layer-only) | `recurringRule` | map or null | **absent** (client omits; rules accept absent or `null`) | Not written by the client |
| `expenses` (group and friendship sub-collections) | `source` | string | `'manual'` | Client (on expense creation) |
| `users` | `locale` | string | `'en-IN'` | Client (on user registration) |

---

## Design Principles for Extension Points

1. **Write defaults, never omit.** Every extension-point field listed in this document must be explicitly written with its v1.0 default value at document creation time. Firestore does not index absent fields in composite indexes; omitting a field today creates a backfill obligation tomorrow. This is the single most important principle in this document. **Documented exception:** `recurringRule` (ARCH-EXT-03) is omitted by the client and the rules accept it absent or `null`; no v1.0 composite index references it, so the backfill risk does not apply.

2. **Discriminator, not boolean.** Extension points that distinguish behaviour modes (settlement method, expense source) use string discriminators, not booleans. A boolean `isUpi` field would need to be replaced with a three-valued field if a third payment method is added. A string discriminator accommodates unbounded future values.

3. **Optional sub-documents over nullable scalars.** For complex future data (recurring rules, OCR metadata), the extension point is an optional sub-document (`map | null`) rather than multiple nullable scalar fields scattered across the document. This groups related data, simplifies security rules (one field-level rule instead of many), and makes the absence/presence check a single operation.

4. **Client-read-only for derived state.** Fields whose values are determined by external systems (UPI payment confirmation, OCR confidence) follow the same security pattern as `simplifiedBalances` (SRS section 7.5, Invariant 2): clients may read the field but only Cloud Functions may write to it. This is enforced by Firestore Security Rules.

5. **Isolate the transport for backend extensibility.** Where the extension point is a code-level concern rather than a schema concern (ARCH-EXT-05: notification channels), the v1.0 implementation isolates the FCM transport (`fcm-send.ts`) behind a function-based `NotificationsApi` so trigger sites do not inline FCM calls. The full strategy/dispatcher with pluggable channels is the v1.1 evolution, not a v1.0 deliverable.

---

## Revision History

| Date | Author | Change |
|---|---|---|
| 2025-01-XX | Solution Architect | Initial draft — seven extension points identified from SRS section 12.3 and data model (SRS section 7.2) |
