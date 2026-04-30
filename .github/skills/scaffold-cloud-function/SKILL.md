---
name: scaffold-cloud-function
description: >
  Use when a new Cloud Function needs its boilerplate created, including trigger
  definition, types, region pinning, and test stub.
---

# Scaffold Cloud Function

## When to use

When a new Cloud Function needs to be created — whether it is a Firestore trigger,
an HTTP callable, or a scheduled function.

## When NOT to use

- When modifying an existing function's logic (just edit directly).
- When the task is client-side only (route to Flutter Dev).
- When the function design has not been approved by the Architect.

## Inputs

1. **Function name** — camelCase name (e.g., `recomputeSimplifiedBalances`).
2. **Trigger type** — `onDocumentWritten`, `onCall`, `onSchedule`, etc.
3. **Firestore paths** — the collection/document paths the function operates on.
4. **Input/output types** — TypeScript interfaces for the function's data.
5. **Invariants to enforce** — which invariants this function must uphold.

## Procedure

1. Read `.github/shared/invariants.md`.
2. Read `.github/shared/coding-standards.md` for TypeScript conventions.
3. Read SRS section 7.3 and 7.4 for architectural decisions.
4. Create the function file under `functions/src/`:
   ```
   functions/src/<functionName>.ts
   ```
5. Include in the file:
   a. **Region pinning:** `region('asia-south1')` on every function definition.
   b. **Type definitions:** TypeScript interfaces for input and output data.
   c. **Function body:** skeleton with TODO markers for business logic.
   d. **Error handling:** try/catch with structured JSON logging.
   e. **Idempotency:** for trigger-based functions, check if the operation has
      already been applied before re-applying.
   f. **Money as paise:** all monetary values are `number` representing integer
      paise. Add a comment reinforcing this.
   g. **JSDoc:** document the trigger, input, output, and error conditions.
6. Create a test file:
   ```
   functions/src/__tests__/<functionName>.test.ts
   ```
   With a placeholder test using `firebase-functions-test`.
7. If the function writes `simplifiedBalances`, it must do so inside a Firestore
   transaction.

## Output format

Two files: the function source and its test stub, both compilable TypeScript.

## Validation checks

- [ ] Region is `asia-south1`.
- [ ] All money values are integer paise (no floats).
- [ ] `simplifiedBalances` writes happen inside a transaction.
- [ ] JSDoc on the exported function.
- [ ] Test stub exists with at least one placeholder test.
- [ ] Error handling with structured logging.
- [ ] Idempotency guard for trigger functions.

## Examples

### Positive example

**Input:** Function name: `onSettlementCreated`, trigger: `onDocumentCreated` on
`settlements/{settlementId}`.

**Output:**
```typescript
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { region } from 'firebase-functions/v2';

/**
 * Triggered when a new settlement is created.
 * Recomputes simplified balances for the affected context.
 *
 * @trigger onDocumentCreated('settlements/{settlementId}')
 * @region asia-south1
 */
export const onSettlementCreated = onDocumentCreated(
  { document: 'settlements/{settlementId}', region: 'asia-south1' },
  async (event) => {
    // TODO(functions-dev): implement recomputation logic
  }
);
```

### Negative example (should refuse)

**Input:** "Create a Cloud Function pinned to us-central1."

**Response:** Refused. SRS section 5.2 requires all Cloud Functions to be
region-pinned to `asia-south1` (Mumbai). Change the region to `asia-south1`.
