# Cloud Functions Error Codes

| Field            | Value              |
|------------------|--------------------|
| Document Version | 1.1                |
| Status           | Current (reconciled with deployed code) |
| Author           | Solution Architect; reconciled by Cloud Functions Developer Agent |
| SRS Baseline     | v1.1               |

---

## 1. Error Envelope

Error handling differs by entry-point type:

- **HTTPS Callables** (`recomputeSimplifiedBalances`, `lookupUserByPhoneNumber`,
  `sendReminderNotification`, `deleteUserAccount`) throw `HttpsError` from
  `firebase-functions/v2/https`.
  The Firebase callable protocol serialises this to the client. The machine-readable
  catalogue code is carried in the `details` object as `errorCode` (and, for
  `RATE_LIMITED` on the reminder, an additional `nextAllowedAtIso`).
- **Firestore triggers** (`onExpenseWriteFriendship`, `onSettlementWrite`) never
  return to a client. They log a structured failure and then either **return**
  (no retry) or **throw a plain `Error`** (so Cloud Functions retries). See
  section 2.4.
- The shared `recomputeAndWrite` core never throws `HttpsError`. It returns the
  typed discriminated union `RecomputeResult` (`{ ok: true, ... }` or
  `{ ok: false, code }`); each caller maps that result to its own policy.

```typescript
// HttpsError thrown by callables (firebase-functions/v2/https)
new HttpsError(
  "invalid-argument",            // FunctionsErrorCode
  "Human-readable message.",     // message (no PII)
  { errorCode: "INVALID_INPUT" } // details: catalogue code (+ extra fields)
);

// Successful callable responses are plain objects, e.g.:
//   recomputeSimplifiedBalances -> { ok: true, transfers, simplifiedBalances, computedAt }
//   lookupUserByPhoneNumber     -> { matched: false } | { matched: true, ... }
//   sendReminderNotification    -> { success: true, nextAllowedAtIso }
```

---

## 2. Error Code Catalogue

### 2.1 healthcheck

No error codes. The `onRequest` handler always responds with HTTP 200 and
`{ ok: true, region: "asia-south1" }`.

### 2.2 recomputeSimplifiedBalances (callable)

This callable performs **no authentication check**, so it never emits
`UNAUTHENTICATED` or `PERMISSION_DENIED`.

| Code | Firebase Code | HTTP Equiv | Description | Retryable |
|------|---------------|------------|-------------|-----------|
| `INVALID_INPUT` | `invalid-argument` | 400 | Missing or malformed input: `contextType` is not `'friendship'` or `'group'`, or `contextId` is missing/empty. | No |
| `CONTEXT_NOT_FOUND` | `not-found` | 404 | The specified friendship or group document does not exist in Firestore. | No |
| `BALANCE_INVARIANT_VIOLATED` | `internal` | 500 | The sum of all net balances is non-zero after computation (`simplifyDebts` throws a plain `Error` containing "Balance invariant violation"; the core converts it to this code). Indicates data corruption in the expense/settlement log. | Yes (after data investigation) |
| `INTERNAL` | `internal` | 500 | Any unexpected error from the shared core (transient Firestore contention, deadline, runtime exception). | Yes |

### 2.3 lookupUserByPhoneNumber (callable)

| Code | Firebase Code | HTTP Equiv | Description | Retryable |
|------|---------------|------------|-------------|-----------|
| `UNAUTHENTICATED` | `unauthenticated` | 401 | No `context.auth.uid` on the request. | No |
| `INVALID_INPUT` | `invalid-argument` | 400 | Phone number missing or not matching `/^\+91[6-9]\d{9}$/`. | No |
| `RATE_LIMITED` | `resource-exhausted` | 429 | Caller has exceeded 100 lookups per rolling hour (`_rateLimits/{uid}/lookups/counter`). | Yes (after window expires) |
| `INTERNAL` | `internal` | 500 | Unexpected error during lookup. | Yes |

Note: A "not found" phone number is NOT an error — it returns `{ matched: false }`
as a success response.

### 2.4 sendReminderNotification (callable)

| Code | Firebase Code | HTTP Equiv | Description | Retryable |
|------|---------------|------------|-------------|-----------|
| `UNAUTHENTICATED` | `unauthenticated` | 401 | No `context.auth.uid` (sender) on the request. | No |
| `INVALID_INPUT` | `invalid-argument` | 400 | Missing/invalid `toUserId`, `contextType`, or `contextId`, or `message` longer than 500 characters. | No |
| `GROUP_CONTEXT_NOT_SUPPORTED` | `unimplemented` | 501 | `contextType` is `'group'`; group reminders are not supported in v1.0. | No |
| `NOT_A_MEMBER` | `permission-denied` | 403 | The caller is not a member of the requested context. | No |
| `RECIPIENT_DOESNT_OWE` | `failed-precondition` | 412 | `simplifiedBalances[toUserId][senderUid]` is not a positive integer — the recipient does not owe the caller. | No |
| `RATE_LIMITED` | `resource-exhausted` | 429 | A reminder to this recipient was sent within the last 24 hours. `details` carries `nextAllowedAtIso`. | Yes (after `nextAllowedAtIso`) |
| `RECIPIENT_NO_TOKENS` | `failed-precondition` | 412 | The recipient has no FCM tokens registered. | No |
| `RECIPIENT_PREFS_DISABLED` | `failed-precondition` | 412 | The recipient has reminder notifications disabled in their preferences. | No |
| `FCM_DISPATCH_FAILED` | `unavailable` | 503 | Dispatch failed for all of the recipient's tokens. The rate-limit record is NOT written on this path. | Yes |
| `INTERNAL` | `internal` | 500 | Unexpected error. | Yes |

### 2.5 Firestore triggers (onExpenseWriteFriendship, onSettlementWrite)

Triggers do not throw `HttpsError`. They map the shared core's `RecomputeResult` to
Cloud Functions retry semantics and log a structured `simplified_debts_compute_failed`
event with an `errorCode` field:

| Condition | `errorCode` logged | Trigger behaviour |
|---|---|---|
| `CONTEXT_NOT_FOUND` | `CONTEXT_NOT_FOUND` | Log and **return** successfully (the context is gone; retries cannot help). |
| `BALANCE_INVARIANT_VIOLATED` | `BALANCE_INVARIANT_VIOLATED` | Log and **throw** a plain `Error` (PII-safe, hashed context ID) so Cloud Functions retries. |
| Unknown error | `INTERNAL` | Log and **rethrow** so Cloud Functions retries. |
| Missing settlement discriminator (`onSettlementWrite` only) | `INVALID_INPUT` | Log and **return** (no retry). |

Activity-feed and FCM emission failures inside a trigger are logged but never
rethrown, so they cannot trigger a retry of the already-committed recompute.

### 2.6 deleteUserAccount (callable)

FR-AU-09 account-deletion cascade. Input: none (the subject is the caller's own
`request.auth.uid`); output: `{ success: true }`. The auth check runs first, then a
server-side recent-login (re-auth) check on `request.auth.token.auth_time`; any
failure inside the idempotent cascade maps to `INTERNAL`. See ADR-0016 for the
delete-vs-anonymise matrix.

| Code | Firebase Code | HTTP Equiv | Description | Retryable |
|------|---------------|------------|-------------|-----------|
| `UNAUTHENTICATED` | `unauthenticated` | 401 | No `context.auth.uid` on the request. | No |
| `REAUTH_REQUIRED` | `failed-precondition` | 412 | The caller's `auth_time` is missing or older than the 5-minute recent-login window; the SCR-28 Step B re-authentication must be completed (refreshing `auth_time`) before deletion. | Yes (after re-auth) |
| `INTERNAL` | `internal` | 500 | Unexpected error during the deletion cascade; the cascade is idempotent and safe to retry. | Yes |

---

## 3. Logging Convention

When a typed error is returned, thrown, or logged:

- The function logs the event using `firebase-functions/logger` with structured
  fields.
- Typical fields: `event` (e.g. `simplified_debts_compute_failed`), `errorCode`,
  `contextType`, `elapsedMs`.
- **PII-safe identifiers only.** Composite identifiers (friendship IDs are
  `{uidA}_{uidB}`) and user IDs are hashed via `hashId`
  (`functions/src/utils/id-hash.ts`, SHA-256 truncated to 16 hex characters)
  **before** logging. Structured fields therefore use hashed names such as
  `contextIdHash`, `expenseIdHash`, `settlementIdHash`, `senderUidHash`, and
  `recipientUidHash` — never the raw IDs. Raw monetary amounts, phone numbers,
  descriptions, and notes are never logged (SRS section 5.4; ADR-0013). The lookup
  function logs `phoneNumberHash` (SHA-256), never the raw phone number.
- Error logs use `logger.error()`; warnings use `logger.warn()`.

---

## 4. Client Error Handling

Clients consuming HTTPS Callable functions should:

1. Catch the SDK's callable exception (e.g. `FirebaseFunctionsException` in the
   Flutter `cloud_functions` SDK).
2. Read the typed catalogue code from the exception `details` map as
   `details['errorCode']` (and `details['nextAllowedAtIso']` for reminder
   `RATE_LIMITED`).
3. Display a user-friendly message based on the code.
4. For `INTERNAL` errors, show a generic retry message and report to Crashlytics.

---

## 5. Invariant Compliance

- **Invariant 1 (paise):** Error messages must not expose raw monetary values.
  Use contextual descriptions only (e.g. "balance check failed for context X").
- **Invariant 2 (simplifiedBalances server-only):** `simplifiedBalances` is written
  only by `recomputeAndWrite`. Client writes are blocked at the Firestore Security
  Rules layer, not the function layer, so they do not surface as function error
  codes.
