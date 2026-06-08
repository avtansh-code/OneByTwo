/**
 * Activity Payload Builder for friendship-expense triggers.
 *
 * Pure function that maps the trigger's
 * `(changeType, before, after)` tuple to a typed `ActivityPayload`
 * suitable for embedding inside an `activity/{userId}/items/{auto-id}`
 * document. Extracted from the activity-writer so the mapping logic
 * can be exercised by unit tests without spinning up Firestore.
 *
 * Architect ratification: FR-EX-07 architect notes §2.6 — per-event-
 * type payload schema with discriminated-union shape.
 *
 * @module triggers/on-expense-write/payload-builder
 */

import type {Timestamp} from "firebase-admin/firestore";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/**
 * Activity-item type discriminator. Values match the canonical
 * enumeration in docs/design/07-technical/firestore-schema.md line 202.
 * The remaining schema-doc variant (`'group_change'`) is FUTURE work
 * (Sprint 3 groups epic).
 *
 * `'settlement'` is emitted by the settlement-trigger
 * (functions/src/triggers/on-settlement-write/) per FR-AC-01.
 */
export type ActivityItemType =
  | "expense_added"
  | "expense_edited"
  | "expense_deleted"
  | "settlement"
  | "reminder";

/** Trigger change discriminator (mirrors `function.ts` `ChangeType`). */
export type ChangeType = "create" | "update" | "delete";

/** Shape of a single split element on an expense document. */
export interface ExpenseSplit {
  userId: string;
  sharePaise: number;
}

/** Shape of the source expense document (subset relevant to the activity payload). */
export interface ExpenseDocData {
  payerId: string;
  amountPaise: number;
  splits: ExpenseSplit[];
  description: string;
  category: string;
  splitMethod: string;
  receiptUrl: string | null;
  createdBy: string;
  deleted: boolean;
}

/** `expense_added` payload. */
export interface ExpenseAddedPayload {
  expenseId: string;
  friendshipId: string;
  description: string;
  amountPaise: number;
  category: string;
  payerId: string;
  splits: ExpenseSplit[];
  splitMethod: string;
  hasReceipt: boolean;
  authorUid: string;
}

/** `expense_edited` payload — extends `expense_added` with `changedFields`. */
export interface ExpenseEditedPayload extends ExpenseAddedPayload {
  changedFields: string[];
}

/** `expense_deleted` payload — pre-delete snapshot fields only. */
export interface ExpenseDeletedPayload {
  expenseId: string;
  friendshipId: string;
  description: string;
  amountPaise: number;
  category: string;
  authorUid: string;
  deletedAt: Timestamp;
}

/**
 * `settlement` payload — emitted by the settlement-trigger
 * (FR-AC-01 architect notes §2.4). Captures the directional fields
 * needed by the SCR-25 row ("You settled up with X" vs "X settled
 * up with you") plus the deep-link target identifier (`contextId`
 * is the friendship document ID; `settlementId` is the auto-ID
 * Firestore assigns to the settlement document).
 */
export interface SettlementPayload {
  settlementId: string;
  fromUserId: string;
  toUserId: string;
  amountPaise: number;
  contextType: "friendship" | "group";
  contextId: string;
  note?: string;
  authorUid: string;
}

/**
 * `reminder` payload — emitted by the FR-SE-09 sendReminderNotification
 * callable (architect §2.4). The `message` field is the optional
 * free-text composed by the sender (max 500 chars); v1.0 always
 * omits it on the client side and the callable defaults to a
 * hardcoded copy.
 */
export interface ReminderPayload {
  senderUid: string;
  recipientUid: string;
  contextType: "friendship" | "group";
  contextId: string;
  amountPaise: number;
  message?: string;
}

/** Discriminated union of every payload shape this builder emits. */
export type ActivityPayload =
  | ExpenseAddedPayload
  | ExpenseEditedPayload
  | ExpenseDeletedPayload
  | SettlementPayload
  | ReminderPayload;

/** Result tuple of `buildExpenseActivityPayload`. */
export interface BuiltActivityPayload {
  eventType: ActivityItemType;
  payload: ActivityPayload;
}

// ---------------------------------------------------------------------------
// Fields-of-interest for the `changedFields` diff
// ---------------------------------------------------------------------------

/**
 * Whitelisted set of fields the diff algorithm checks for `expense_edited`.
 *
 * Restricted to the user-visible fields the activity feed should reflect.
 * Server-managed metadata (`updatedAt`, `createdAt`, `createdBy`) is
 * excluded — those change on every write and would pollute the
 * `changedFields` array. `deleted` is excluded because soft-delete uses
 * the `expense_deleted` discriminator, not `expense_edited`. Extension-
 * point fields (`currency`, `source`, `recurringRule`) are excluded
 * because they are invariant-locked per the rules.
 */
const DIFF_FIELDS: readonly (keyof ExpenseDocData)[] = [
  "amountPaise",
  "description",
  "category",
  "payerId",
  "splits",
  "splitMethod",
  "receiptUrl",
];

/**
 * Returns the subset of `DIFF_FIELDS` whose value differs between
 * `before` and `after`. Deep equality for `splits` via JSON
 * canonicalisation — the trigger's source documents always shape splits
 * identically (sorted object key order is irrelevant because the same
 * client serialises both halves of every update).
 */
function diffChangedFields(
  before: ExpenseDocData,
  after: ExpenseDocData,
): string[] {
  const changed: string[] = [];
  for (const field of DIFF_FIELDS) {
    const beforeValue = before[field];
    const afterValue = after[field];
    if (field === "splits") {
      if (JSON.stringify(beforeValue) !== JSON.stringify(afterValue)) {
        changed.push(field);
      }
    } else if (beforeValue !== afterValue) {
      changed.push(field);
    }
  }
  return changed;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Maps a trigger event to the activity-payload pair `{ eventType, payload }`
 * for emission into `activity/{userId}/items/{auto-id}` documents.
 *
 * Soft-delete semantics (FR-EX-06): an update whose `before.deleted === false`
 * and `after.deleted === true` is treated as a `delete` (emits
 * `expense_deleted`), NOT an `update` (which would emit `expense_edited`).
 * The caller signals this by passing `changeType: 'delete'` for soft-delete
 * paths; the trigger's `function.ts` does this discrimination upstream.
 *
 * @param changeType - The trigger's change discriminator.
 * @param request - The expense IDs, friendship ID, and source data
 *   snapshots. `before` is required for `'update'` and `'delete'`;
 *   `after` is required for `'create'` and `'update'`.
 * @param deletedAt - For `'delete'`, the timestamp at which the
 *   activity-write is happening (Firestore server timestamp).
 * @returns The typed `{ eventType, payload }` tuple ready for
 *   `validateActivityPayload` and Firestore write.
 *
 * @throws Error if the (changeType, before, after) combination is
 *   inconsistent (e.g. `'create'` with no `after`; `'delete'` with no
 *   `before`).
 */
export function buildExpenseActivityPayload(
  changeType: ChangeType,
  request: {
    friendshipId: string;
    expenseId: string;
    before?: ExpenseDocData;
    after?: ExpenseDocData;
  },
  deletedAt?: Timestamp,
): BuiltActivityPayload {
  const {friendshipId, expenseId, before, after} = request;

  if (changeType === "create") {
    if (!after) {
      throw new Error(
        "buildExpenseActivityPayload: 'create' requires 'after' snapshot.",
      );
    }
    return {
      eventType: "expense_added",
      payload: buildExpenseAddedPayload(expenseId, friendshipId, after),
    };
  }

  if (changeType === "update") {
    if (!before || !after) {
      throw new Error(
        "buildExpenseActivityPayload: 'update' requires both 'before' " +
          "and 'after' snapshots.",
      );
    }
    return {
      eventType: "expense_edited",
      payload: {
        ...buildExpenseAddedPayload(expenseId, friendshipId, after),
        changedFields: diffChangedFields(before, after),
      },
    };
  }

  // changeType === 'delete' (soft- or hard-delete)
  if (!before) {
    throw new Error(
      "buildExpenseActivityPayload: 'delete' requires 'before' snapshot.",
    );
  }
  if (!deletedAt) {
    throw new Error(
      "buildExpenseActivityPayload: 'delete' requires 'deletedAt' timestamp.",
    );
  }
  return {
    eventType: "expense_deleted",
    payload: {
      expenseId,
      friendshipId,
      description: before.description,
      amountPaise: before.amountPaise,
      category: before.category,
      authorUid: before.createdBy,
      deletedAt,
    },
  };
}

/**
 * Builds the `expense_added` payload shape. Shared between the create
 * branch (direct emission) and the update branch (combined with
 * `changedFields` to form the `expense_edited` payload).
 *
 * `hasReceipt: boolean` is derived from a non-null/non-empty
 * `receiptUrl` per the schema (PR #48 ratified `receiptUrl` is either
 * `null` or a Firebase Storage download URL string).
 */
function buildExpenseAddedPayload(
  expenseId: string,
  friendshipId: string,
  data: ExpenseDocData,
): ExpenseAddedPayload {
  return {
    expenseId,
    friendshipId,
    description: data.description,
    amountPaise: data.amountPaise,
    category: data.category,
    payerId: data.payerId,
    splits: data.splits,
    splitMethod: data.splitMethod,
    hasReceipt: data.receiptUrl !== null && data.receiptUrl !== "",
    authorUid: data.createdBy,
  };
}
