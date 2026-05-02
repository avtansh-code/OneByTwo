# Cloud Functions Error Codes

| Field            | Value              |
|------------------|--------------------|
| Document Version | 1.0                |
| Status           | Draft              |
| Author           | Solution Architect |
| SRS Baseline     | v1.1               |

---

## 1. Error Envelope

All Cloud Functions return errors in a typed envelope. Generic `Error` is never
thrown to callers. All caught exceptions are mapped to a typed error at the
function boundary.

```typescript
interface CloudFunctionError {
  ok: false;
  error: {
    code: string;       // machine-readable error code from the catalogue below
    message: string;    // human-readable description (no PII)
    details?: unknown;  // optional structured details for debugging
  };
}
```

When using Firebase HTTPS Callable functions, errors are thrown as `HttpsError`
with:

- `code`: mapped to the appropriate Firebase error code (e.g.,
  `invalid-argument`, `not-found`, `internal`).
- `message`: the human-readable message.
- `details`: the typed error code from this catalogue.

---

## 2. Error Code Catalogue

### recomputeSimplifiedBalances

| Code | Firebase Code | HTTP Equiv | Description | Retryable |
|------|---------------|------------|-------------|-----------|
| `INVALID_INPUT` | `invalid-argument` | 400 | Missing or malformed input: `contextType` is not `'friendship'` or `'group'`, or `contextId` is missing/empty. | No |
| `CONTEXT_NOT_FOUND` | `not-found` | 404 | The specified friendship or group document does not exist in Firestore. | No |
| `PERMISSION_DENIED` | `permission-denied` | 403 | The caller does not have permission to invoke this function. | No |
| `BALANCE_INVARIANT_VIOLATED` | `internal` | 500 | The sum of all net balances is non-zero after computation. This indicates data corruption in the expenses/settlements log. Logged as a critical error. | Yes (after data investigation) |
| `INTERNAL` | `internal` | 500 | An unexpected error occurred during computation. All caught exceptions that do not match a specific code are mapped here. | Yes |

### Shared Codes (all functions)

| Code | Firebase Code | HTTP Equiv | Description | Retryable |
|------|---------------|------------|-------------|-----------|
| `UNAUTHENTICATED` | `unauthenticated` | 401 | No valid authentication context. | No |

---

## 3. Logging Convention

When a typed error is returned or thrown:

- The function logs the event using `firebase-functions/logger` with structured
  fields.
- Required fields: `event` (e.g., `simplified_debts_compute_failed`),
  `errorCode`, `contextType`, `contextId`.
- **Never** log `userId` values, raw monetary amounts, or any PII
  (SRS section 5.4).
- Error logs use `logger.error()`; warnings use `logger.warn()`.

---

## 4. Client Error Handling

Clients consuming HTTPS Callable functions should:

1. Catch `FirebaseFunctionsException` (or equivalent SDK type).
2. Read the `details` field for the typed error code from this catalogue.
3. Display a user-friendly message based on the code.
4. For `INTERNAL` errors, show a generic retry message and report to Crashlytics.

---

## 5. Invariant Compliance

- **Invariant 1 (paise):** Error messages must not expose raw monetary values.
  Use contextual descriptions only (e.g., "balance check failed for context X").
- **Invariant 2 (simplifiedBalances server-only):** The error model does not
  apply to client writes to `simplifiedBalances` — those are blocked at the
  Firestore Security Rules layer, not the function layer.
