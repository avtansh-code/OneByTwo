---
applyTo: "functions/src/**/*.ts"
---

# Cloud Functions TypeScript Instructions

## General

- Use Cloud Functions 2nd gen TypeScript APIs.
- Deploy region: `asia-south1` (Mumbai) for all functions.
- Strict TypeScript: `noImplicitAny`, `strictNullChecks`, `noUnusedLocals`, `noUnusedParameters`.
- All amounts in paise (integer). NEVER floating-point for money.

## Callable Functions

- Always verify authentication: `if (!request.auth) throw new HttpsError('unauthenticated', '...');`
- Always validate inputs: check type, range, required fields before processing.
- Always verify membership: user must be a member of the group/friend pair.
- Use rate limiting for sensitive operations (e.g., invite creation, nudges).
- Return structured response objects (not raw data).

## Firestore Triggers

- Use `onDocumentCreated`, `onDocumentUpdated`, `onDocumentDeleted` from `firebase-functions/v2/firestore`.
- Always specify region: `{ region: 'asia-south1' }`.
- Use `admin.firestore().batch()` for atomic multi-document writes.
- Use `FieldValue.serverTimestamp()` for timestamp fields.
- For balance recalculation: read ALL expenses + settlements in the group/friend pair, recompute from scratch (not incremental).

## Notification Fan-Out Pattern

```typescript
// 1. Get group members (except action creator)
// 2. For each member: check notification preferences
// 3. Get FCM tokens from user doc
// 4. Build notification payload
// 5. Send via admin.messaging().sendEachForMulticast()
// 6. Handle stale tokens (remove on messaging/registration-token-not-registered)
// 7. Write to users/{uid}/notifications for in-app history
```

## Error Handling

- Use `HttpsError` for callable function errors with appropriate codes.
- Log errors with structured data (no PII).
- Wrap Firestore operations in try/catch.

## Testing

- Every function must have corresponding tests in `functions/test/`.
- Use Firebase Admin SDK with emulator for integration tests.
- Mock Firestore for unit tests.
