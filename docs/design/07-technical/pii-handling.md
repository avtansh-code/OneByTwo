# PII Handling

| Field            | Value              |
|------------------|--------------------|
| Document Version | 1.0                |
| Status           | Active             |
| Author           | Solution Architect |
| SRS Baseline     | v1.1               |
| ADR Reference    | ADR-0013           |

---

## 1. Scope

This document defines how Personally Identifiable Information (PII) —
particularly device contacts (names and phone numbers) — is handled in
One By Two. It is the canonical PII-handling reference for every current and
future pull request that touches PII.

---

## 2. Principles

### 2.1 PII stays on-device

PII remains on the device unless explicitly required for a server-side
operation. Querying Firestore by `phoneNumber` to look up a single user is
acceptable; batch-uploading contact lists is not.

### 2.2 PII is excluded from telemetry and persistent stores

PII is never included in any of the following:

- Analytics event parameters.
- Crashlytics breadcrumbs.
- Client-side logs (including `debugPrint`, `log`, and `print` statements).
- Server-side logs (Cloud Function `console.log` or `functions.logger`).
- Persistent caches (SharedPreferences, Hive, or any on-disk store).

### 2.3 Contact data is scoped to the picker route

Contact data is held in a controller scoped to the picker route. When the
picker is dismissed, the controller is disposed and the data falls out of
memory. No reference to the full contact list is retained beyond the picker
lifecycle.

### 2.4 Telemetry events use safe parameters

Telemetry event names are acceptable (e.g. `contact_selected`,
`friend_request_sent`). Parameters containing names or phone numbers are not
acceptable. Use counts or hashed identifiers instead.

Examples of compliant telemetry:

```dart
// Good: event name only, no PII in parameters
analytics.logEvent(name: 'contact_selected');

// Good: count parameter, no PII
analytics.logEvent(name: 'contacts_loaded', parameters: {'count': 42});

// Bad: phone number in parameters — NEVER do this
analytics.logEvent(name: 'contact_selected', parameters: {'phone': '+919876543210'});
```

### 2.5 Hand-off contract from the contact picker

The contact picker exposes only the single selected contact to downstream
code:

```
selectedContact: { displayName: String, phoneNumbers: List<String> }
```

Phone numbers are E.164 normalised (e.g. `+91XXXXXXXXXX`). The full contact
list never crosses the picker boundary.

---

## 3. Enforcement

PII-leak tests (see `test/features/friends/pii_leak_test.dart`) mock the
analytics, Crashlytics, and logging providers and assert that no PII appears
in any captured events, breadcrumbs, or log output.

These tests must pass in the PR pipeline before any PII-touching code is
merged.

---

## 4. Invariant Status

The PII handling posture described in this document is real and enforced by
tests. However, it has not been promoted to a fifth formal invariant in
`.github/shared/invariants.md`. Consistent with the reasoning applied in
ADR-0012 (where the `affectedKeys()` pattern was not promoted because
promotion would be premature), the PII handling pattern should prove stable
across at least two to three PII-touching features before elevation to an
invariant is considered. See ADR-0013 for the full rationale.

---

## 5. Revision History

| Version | Date       | Change                                |
|---------|------------|---------------------------------------|
| 1.0     | 2025-06-26 | Initial version (PR #31, ADR-0013).   |
