/**
 * Runtime payload validator for activity-feed items.
 *
 * The activity-writer calls this BEFORE the Firestore write to catch
 * programmer errors at runtime that the TypeScript compiler cannot
 * (e.g. a hand-constructed payload missing `payerId`, or a runtime
 * value that fell through a `JSON.parse` round-trip and lost its
 * type narrowing).
 *
 * Architect ratification: FR-EX-07 architect notes §2.9 item 8
 * (placement co-located with the writer; not under a top-level
 * `schema-validators` module because no such module exists today).
 *
 * @module triggers/on-expense-write/activity-validator
 */

import type {
  ActivityItemType,
  ActivityPayload,
  ExpenseAddedPayload,
  ExpenseDeletedPayload,
  ExpenseEditedPayload,
  SettlementPayload,
} from "./payload-builder";

/**
 * Validates an activity-payload pair against the per-event-type
 * required-field contract. Throws a descriptive Error on the first
 * violation. Returns silently on success.
 *
 * Designed to fail loudly (throw, not return false) — a malformed
 * payload is a programmer error, not a runtime user-input concern.
 * The activity-writer's caller chain treats the throw as an internal
 * INTERNAL error and the trigger's retry logic will surface it.
 */
export function validateActivityPayload(
  eventType: ActivityItemType,
  payload: ActivityPayload,
): void {
  if (payload === null || typeof payload !== "object") {
    throw new Error(
      "validateActivityPayload: payload must be a non-null object.",
    );
  }

  switch (eventType) {
    case "expense_added":
      validateExpenseAddedPayload(payload as ExpenseAddedPayload);
      return;
    case "expense_edited":
      validateExpenseEditedPayload(payload as ExpenseEditedPayload);
      return;
    case "expense_deleted":
      validateExpenseDeletedPayload(payload as ExpenseDeletedPayload);
      return;
    case "settlement":
      validateSettlementPayload(payload as SettlementPayload);
      return;
    default: {
      const _exhaustive: never = eventType;
      throw new Error(
        `validateActivityPayload: unknown eventType '${String(_exhaustive)}'.`,
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Per-event-type validators
// ---------------------------------------------------------------------------

const EXPENSE_BASE_FIELDS = [
  "expenseId",
  "friendshipId",
  "description",
  "amountPaise",
  "category",
  "payerId",
  "splits",
  "splitMethod",
  "hasReceipt",
  "authorUid",
] as const;

function validateExpenseAddedPayload(payload: ExpenseAddedPayload): void {
  assertHasFields("expense_added", payload, EXPENSE_BASE_FIELDS);
  assertExpenseSharedShape("expense_added", payload);
}

function validateExpenseEditedPayload(payload: ExpenseEditedPayload): void {
  assertHasFields("expense_edited", payload, [
    ...EXPENSE_BASE_FIELDS,
    "changedFields",
  ]);
  assertExpenseSharedShape("expense_edited", payload);
  if (!Array.isArray(payload.changedFields)) {
    throw new Error(
      "validateActivityPayload: expense_edited.changedFields must be an array.",
    );
  }
  for (const field of payload.changedFields) {
    if (typeof field !== "string") {
      throw new Error(
        "validateActivityPayload: expense_edited.changedFields entries " +
          "must be strings.",
      );
    }
  }
}

function validateExpenseDeletedPayload(payload: ExpenseDeletedPayload): void {
  assertHasFields("expense_deleted", payload, [
    "expenseId",
    "friendshipId",
    "description",
    "amountPaise",
    "category",
    "authorUid",
    "deletedAt",
  ] as const);

  if (typeof payload.description !== "string") {
    throw new Error(
      "validateActivityPayload: expense_deleted.description must be a string.",
    );
  }
  if (typeof payload.amountPaise !== "number" ||
    !Number.isInteger(payload.amountPaise) ||
    payload.amountPaise <= 0) {
    throw new Error(
      "validateActivityPayload: expense_deleted.amountPaise must be a " +
        "positive integer.",
    );
  }
  if (typeof payload.category !== "string") {
    throw new Error(
      "validateActivityPayload: expense_deleted.category must be a string.",
    );
  }
  if (typeof payload.authorUid !== "string" || payload.authorUid.length === 0) {
    throw new Error(
      "validateActivityPayload: expense_deleted.authorUid must be a " +
        "non-empty string.",
    );
  }
  if (payload.deletedAt === undefined || payload.deletedAt === null) {
    throw new Error(
      "validateActivityPayload: expense_deleted.deletedAt is required.",
    );
  }
}

/**
 * Validates a `settlement` payload (FR-AC-01 architect §2.4). Required
 * fields: settlementId, fromUserId, toUserId, amountPaise, contextType,
 * contextId, authorUid. The `note` field is optional.
 */
function validateSettlementPayload(payload: SettlementPayload): void {
  assertHasFields("settlement", payload, [
    "settlementId",
    "fromUserId",
    "toUserId",
    "amountPaise",
    "contextType",
    "contextId",
    "authorUid",
  ] as const);

  if (typeof payload.settlementId !== "string" ||
    payload.settlementId.length === 0) {
    throw new Error(
      "validateActivityPayload: settlement.settlementId must be a " +
        "non-empty string.",
    );
  }
  if (typeof payload.fromUserId !== "string" ||
    payload.fromUserId.length === 0) {
    throw new Error(
      "validateActivityPayload: settlement.fromUserId must be a " +
        "non-empty string.",
    );
  }
  if (typeof payload.toUserId !== "string" || payload.toUserId.length === 0) {
    throw new Error(
      "validateActivityPayload: settlement.toUserId must be a " +
        "non-empty string.",
    );
  }
  if (typeof payload.amountPaise !== "number" ||
    !Number.isInteger(payload.amountPaise) ||
    payload.amountPaise <= 0) {
    throw new Error(
      "validateActivityPayload: settlement.amountPaise must be a positive " +
        "integer.",
    );
  }
  if (payload.contextType !== "friendship" && payload.contextType !== "group") {
    throw new Error(
      "validateActivityPayload: settlement.contextType must be 'friendship' " +
        "or 'group'.",
    );
  }
  if (typeof payload.contextId !== "string" || payload.contextId.length === 0) {
    throw new Error(
      "validateActivityPayload: settlement.contextId must be a " +
        "non-empty string.",
    );
  }
  if (typeof payload.authorUid !== "string" || payload.authorUid.length === 0) {
    throw new Error(
      "validateActivityPayload: settlement.authorUid must be a " +
        "non-empty string.",
    );
  }
  if (payload.note !== undefined && typeof payload.note !== "string") {
    throw new Error(
      "validateActivityPayload: settlement.note, when present, must be " +
        "a string.",
    );
  }
}

// ---------------------------------------------------------------------------
// Shared assertions
// ---------------------------------------------------------------------------

function assertHasFields(
  eventType: string,
  payload: object,
  fields: readonly string[],
): void {
  const payloadRecord = payload as Record<string, unknown>;
  for (const field of fields) {
    // Treat an explicit `undefined` as missing — Firestore would
    // silently drop the field on the write, producing an incomplete
    // activity item. Belt-and-braces over the rules-enforced source
    // contract.
    if (!(field in payloadRecord) || payloadRecord[field] === undefined) {
      throw new Error(
        `validateActivityPayload: ${eventType} payload missing required ` +
          `field '${field}'.`,
      );
    }
  }
}

function assertExpenseSharedShape(
  eventType: string,
  payload: ExpenseAddedPayload,
): void {
  if (typeof payload.description !== "string") {
    throw new Error(
      `validateActivityPayload: ${eventType}.description must be a string.`,
    );
  }
  if (
    typeof payload.amountPaise !== "number" ||
    !Number.isInteger(payload.amountPaise) ||
    payload.amountPaise <= 0
  ) {
    throw new Error(
      `validateActivityPayload: ${eventType}.amountPaise must be a ` +
        "positive integer.",
    );
  }
  if (typeof payload.category !== "string") {
    throw new Error(
      `validateActivityPayload: ${eventType}.category must be a string.`,
    );
  }
  if (typeof payload.payerId !== "string" || payload.payerId.length === 0) {
    throw new Error(
      `validateActivityPayload: ${eventType}.payerId must be a ` +
        "non-empty string.",
    );
  }
  if (typeof payload.authorUid !== "string" || payload.authorUid.length === 0) {
    throw new Error(
      `validateActivityPayload: ${eventType}.authorUid must be a ` +
        "non-empty string.",
    );
  }
  if (typeof payload.splitMethod !== "string") {
    throw new Error(
      `validateActivityPayload: ${eventType}.splitMethod must be a string.`,
    );
  }
  if (!Array.isArray(payload.splits) || payload.splits.length === 0) {
    throw new Error(
      `validateActivityPayload: ${eventType}.splits must be a non-empty array.`,
    );
  }
  for (const split of payload.splits) {
    if (
      typeof split !== "object" || split === null ||
      typeof split.userId !== "string" ||
      typeof split.sharePaise !== "number" ||
      !Number.isInteger(split.sharePaise) ||
      split.sharePaise < 0
    ) {
      throw new Error(
        `validateActivityPayload: ${eventType}.splits entries must be ` +
          "{ userId: string, sharePaise: non-negative integer }.",
      );
    }
  }
  if (typeof payload.hasReceipt !== "boolean") {
    throw new Error(
      `validateActivityPayload: ${eventType}.hasReceipt must be a boolean.`,
    );
  }
}
