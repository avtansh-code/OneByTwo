---
applyTo: "functions/src/**/*.ts"
---

# Cloud Functions Instructions

- Use Firebase Cloud Functions 2nd gen APIs (`onCall`, `onDocumentCreated`, `onSchedule`)
- Strict TypeScript — no `any` types, enable all strict compiler flags
- All amounts in paise (integer). Never use floating-point for money
- Validate all input in callable functions before processing
- Authenticate caller via `request.auth` in every callable function
- Use Firestore batch writes for operations affecting multiple documents (max 500 ops per batch)
- Implement rate limiting for sensitive operations using Firestore-backed counters
- Handle stale FCM tokens by removing them on send failure
- Log structured errors with context (groupId, userId, operation) — never log PII
- Use `firebase-functions/v2` `logger` for all logging (maps to Google Cloud Logging)
- Log function invocation duration (`durationMs`) for every callable and trigger function
- All functions deployed to asia-south1 region
