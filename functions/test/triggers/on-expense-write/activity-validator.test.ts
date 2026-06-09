/**
 * Unit tests for `validateActivityPayload` — the runtime guard called
 * by the activity-writer before every Firestore write.
 *
 * Covers FR-EX-07 AC-18.
 *
 * @module test/triggers/on-expense-write/activity-validator.test.ts
 */

import {Timestamp} from "firebase-admin/firestore";
import {validateActivityPayload} from
  "../../../src/triggers/on-expense-write/activity-validator";
import type {
  ActivityPayload,
  ExpenseAddedPayload,
  ExpenseDeletedPayload,
  ExpenseEditedPayload,
  ReminderPayload,
  SettlementPayload,
} from "../../../src/triggers/on-expense-write/payload-builder";

function validExpenseAddedPayload(
  overrides: Partial<ExpenseAddedPayload> = {},
): ExpenseAddedPayload {
  return {
    expenseId: "exp-1",
    friendshipId: "uidA_uidB",
    description: "Dinner",
    amountPaise: 10000,
    category: "food",
    payerId: "uidA",
    splits: [
      {userId: "uidA", sharePaise: 5000},
      {userId: "uidB", sharePaise: 5000},
    ],
    splitMethod: "equal",
    hasReceipt: false,
    authorUid: "uidA",
    ...overrides,
  };
}

function validExpenseEditedPayload(
  overrides: Partial<ExpenseEditedPayload> = {},
): ExpenseEditedPayload {
  return {
    ...validExpenseAddedPayload(),
    changedFields: ["amountPaise"],
    ...overrides,
  };
}

function validExpenseDeletedPayload(
  overrides: Partial<ExpenseDeletedPayload> = {},
): ExpenseDeletedPayload {
  return {
    expenseId: "exp-1",
    friendshipId: "uidA_uidB",
    description: "Dinner",
    amountPaise: 10000,
    category: "food",
    authorUid: "uidA",
    deletedAt: Timestamp.now(),
    ...overrides,
  };
}

describe("validateActivityPayload — expense_added", () => {
  it("accepts a complete valid payload", () => {
    expect(() =>
      validateActivityPayload("expense_added", validExpenseAddedPayload()),
    ).not.toThrow();
  });

  it("rejects payload missing payerId", () => {
    const bad = validExpenseAddedPayload();
    delete (bad as Partial<ExpenseAddedPayload>).payerId;
    expect(() =>
      validateActivityPayload("expense_added", bad as ExpenseAddedPayload),
    ).toThrow(/missing required field 'payerId'/);
  });

  it("rejects payload with non-integer amountPaise", () => {
    expect(() =>
      validateActivityPayload(
        "expense_added",
        validExpenseAddedPayload({amountPaise: 100.5}),
      ),
    ).toThrow(/amountPaise must be a positive integer/);
  });

  it("rejects payload with zero amountPaise (must be positive)", () => {
    expect(() =>
      validateActivityPayload(
        "expense_added",
        validExpenseAddedPayload({amountPaise: 0}),
      ),
    ).toThrow(/amountPaise must be a positive integer/);
  });

  it("rejects payload with negative sharePaise", () => {
    expect(() =>
      validateActivityPayload(
        "expense_added",
        validExpenseAddedPayload({
          splits: [
            {userId: "uidA", sharePaise: -100},
            {userId: "uidB", sharePaise: 10100},
          ],
        }),
      ),
    ).toThrow(/splits entries must be/);
  });

  it("rejects payload with empty splits array", () => {
    expect(() =>
      validateActivityPayload(
        "expense_added",
        validExpenseAddedPayload({splits: []}),
      ),
    ).toThrow(/splits must be a non-empty array/);
  });

  it("rejects payload with non-boolean hasReceipt", () => {
    const bad = validExpenseAddedPayload();
    (bad as {hasReceipt: unknown}).hasReceipt = "false";
    expect(() => validateActivityPayload("expense_added", bad)).toThrow(
      /hasReceipt must be a boolean/,
    );
  });

  it("rejects payload with non-string category (Rec #4)", () => {
    const bad = validExpenseAddedPayload();
    (bad as {category: unknown}).category = 42;
    expect(() => validateActivityPayload("expense_added", bad)).toThrow(
      /category must be a string/,
    );
  });

  it("rejects payload with non-string splitMethod (Rec #4)", () => {
    const bad = validExpenseAddedPayload();
    (bad as {splitMethod: unknown}).splitMethod = null;
    expect(() => validateActivityPayload("expense_added", bad)).toThrow(
      /splitMethod must be a string/,
    );
  });

  it("rejects payload with explicit undefined required field (Rec #3)", () => {
    const bad = validExpenseAddedPayload() as unknown as Record<string, unknown>;
    bad.payerId = undefined;
    expect(() =>
      validateActivityPayload(
        "expense_added",
        bad as unknown as ExpenseAddedPayload,
      ),
    ).toThrow(/missing required field 'payerId'/);
  });
});

describe("validateActivityPayload — expense_edited", () => {
  it("accepts a complete valid payload with changedFields", () => {
    expect(() =>
      validateActivityPayload(
        "expense_edited",
        validExpenseEditedPayload(),
      ),
    ).not.toThrow();
  });

  it("accepts an empty changedFields array (no-op edit)", () => {
    expect(() =>
      validateActivityPayload(
        "expense_edited",
        validExpenseEditedPayload({changedFields: []}),
      ),
    ).not.toThrow();
  });

  it("rejects payload missing changedFields", () => {
    const bad = validExpenseEditedPayload();
    delete (bad as Partial<ExpenseEditedPayload>).changedFields;
    expect(() =>
      validateActivityPayload(
        "expense_edited",
        bad as ExpenseEditedPayload,
      ),
    ).toThrow(/missing required field 'changedFields'/);
  });

  it("rejects payload with non-string changedFields entries", () => {
    expect(() =>
      validateActivityPayload(
        "expense_edited",
        validExpenseEditedPayload({
          changedFields: [123 as unknown as string],
        }),
      ),
    ).toThrow(/changedFields entries must be strings/);
  });
});

describe("validateActivityPayload — expense_deleted", () => {
  it("accepts a complete valid payload", () => {
    expect(() =>
      validateActivityPayload(
        "expense_deleted",
        validExpenseDeletedPayload(),
      ),
    ).not.toThrow();
  });

  it("rejects payload missing deletedAt", () => {
    const bad = validExpenseDeletedPayload();
    delete (bad as Partial<ExpenseDeletedPayload>).deletedAt;
    expect(() =>
      validateActivityPayload(
        "expense_deleted",
        bad as ExpenseDeletedPayload,
      ),
    ).toThrow(/missing required field 'deletedAt'/);
  });

  it("rejects payload with empty authorUid string", () => {
    expect(() =>
      validateActivityPayload(
        "expense_deleted",
        validExpenseDeletedPayload({authorUid: ""}),
      ),
    ).toThrow(/authorUid must be a non-empty string/);
  });

  it("rejects payload with non-integer amountPaise", () => {
    expect(() =>
      validateActivityPayload(
        "expense_deleted",
        validExpenseDeletedPayload({amountPaise: 99.99}),
      ),
    ).toThrow(/amountPaise must be a positive integer/);
  });

  it("rejects payload with non-string category (Rec #4)", () => {
    const bad = validExpenseDeletedPayload();
    (bad as {category: unknown}).category = 42;
    expect(() =>
      validateActivityPayload("expense_deleted", bad),
    ).toThrow(/expense_deleted.category must be a string/);
  });

  it("rejects payload with explicit undefined deletedAt (Rec #3)", () => {
    const bad = validExpenseDeletedPayload() as unknown as Record<string, unknown>;
    bad.deletedAt = undefined;
    expect(() =>
      validateActivityPayload(
        "expense_deleted",
        bad as unknown as ExpenseDeletedPayload,
      ),
    ).toThrow(/missing required field 'deletedAt'/);
  });
});

describe("validateActivityPayload — guard rails", () => {
  it("rejects null payload", () => {
    expect(() =>
      validateActivityPayload(
        "expense_added",
        null as unknown as ActivityPayload,
      ),
    ).toThrow(/payload must be a non-null object/);
  });

  it("rejects unknown eventType (compile-time-impossible but runtime defence)", () => {
    expect(() =>
      validateActivityPayload(
        "unknown_event_type" as unknown as Parameters<
          typeof validateActivityPayload
        >[0],
        validExpenseAddedPayload(),
      ),
    ).toThrow(/unknown eventType/);
  });
});

// ---------------------------------------------------------------------------
// FR-AC-01 AC-13 — settlement payload validation
// ---------------------------------------------------------------------------

function validSettlementPayload(
  overrides: Partial<SettlementPayload> = {},
): SettlementPayload {
  return {
    settlementId: "set-1",
    fromUserId: "uidA",
    toUserId: "uidB",
    amountPaise: 5000,
    contextType: "friendship",
    contextId: "uidA_uidB",
    authorUid: "uidA",
    ...overrides,
  };
}

describe("validateActivityPayload — settlement (FR-AC-01)", () => {
  it("accepts a complete valid settlement payload", () => {
    expect(() =>
      validateActivityPayload("settlement", validSettlementPayload()),
    ).not.toThrow();
  });

  it("accepts a settlement payload with an optional note", () => {
    expect(() =>
      validateActivityPayload(
        "settlement",
        validSettlementPayload({note: "Lunch repayment"}),
      ),
    ).not.toThrow();
  });

  it("rejects payload missing settlementId", () => {
    const bad = validSettlementPayload();
    delete (bad as Partial<SettlementPayload>).settlementId;
    expect(() =>
      validateActivityPayload("settlement", bad as SettlementPayload),
    ).toThrow(/missing required field 'settlementId'/);
  });

  it("rejects payload missing fromUserId", () => {
    const bad = validSettlementPayload();
    delete (bad as Partial<SettlementPayload>).fromUserId;
    expect(() =>
      validateActivityPayload("settlement", bad as SettlementPayload),
    ).toThrow(/missing required field 'fromUserId'/);
  });

  it("rejects payload missing toUserId", () => {
    const bad = validSettlementPayload();
    delete (bad as Partial<SettlementPayload>).toUserId;
    expect(() =>
      validateActivityPayload("settlement", bad as SettlementPayload),
    ).toThrow(/missing required field 'toUserId'/);
  });

  it("rejects payload missing amountPaise", () => {
    const bad = validSettlementPayload();
    delete (bad as Partial<SettlementPayload>).amountPaise;
    expect(() =>
      validateActivityPayload("settlement", bad as SettlementPayload),
    ).toThrow(/missing required field 'amountPaise'/);
  });

  it("rejects payload missing contextType", () => {
    const bad = validSettlementPayload();
    delete (bad as Partial<SettlementPayload>).contextType;
    expect(() =>
      validateActivityPayload("settlement", bad as SettlementPayload),
    ).toThrow(/missing required field 'contextType'/);
  });

  it("rejects payload missing contextId", () => {
    const bad = validSettlementPayload();
    delete (bad as Partial<SettlementPayload>).contextId;
    expect(() =>
      validateActivityPayload("settlement", bad as SettlementPayload),
    ).toThrow(/missing required field 'contextId'/);
  });

  it("rejects payload missing authorUid", () => {
    const bad = validSettlementPayload();
    delete (bad as Partial<SettlementPayload>).authorUid;
    expect(() =>
      validateActivityPayload("settlement", bad as SettlementPayload),
    ).toThrow(/missing required field 'authorUid'/);
  });

  it("rejects non-integer amountPaise (Invariant 1 negative guard)", () => {
    expect(() =>
      validateActivityPayload(
        "settlement",
        validSettlementPayload({amountPaise: 12.34 as unknown as number}),
      ),
    ).toThrow(/amountPaise must be a positive integer/);
  });

  it("rejects zero amountPaise", () => {
    expect(() =>
      validateActivityPayload(
        "settlement",
        validSettlementPayload({amountPaise: 0}),
      ),
    ).toThrow(/amountPaise must be a positive integer/);
  });

  it("rejects negative amountPaise", () => {
    expect(() =>
      validateActivityPayload(
        "settlement",
        validSettlementPayload({amountPaise: -1000}),
      ),
    ).toThrow(/amountPaise must be a positive integer/);
  });

  it("rejects empty fromUserId", () => {
    expect(() =>
      validateActivityPayload(
        "settlement",
        validSettlementPayload({fromUserId: ""}),
      ),
    ).toThrow(/fromUserId must be a non-empty string/);
  });

  it("rejects invalid contextType (defence-in-depth — rules enforce too)", () => {
    expect(() =>
      validateActivityPayload(
        "settlement",
        validSettlementPayload({
          contextType: "invalid" as unknown as "friendship" | "group",
        }),
      ),
    ).toThrow(/contextType must be 'friendship' or 'group'/);
  });
});


// ===========================================================================
// FR-SE-09: reminder event-type validator extension
// ===========================================================================

function validReminderPayload(
  overrides: Partial<ReminderPayload> = {},
): ReminderPayload {
  return {
    senderUid: "uid-sender",
    recipientUid: "uid-recipient",
    contextType: "friendship",
    contextId: "uid-sender_uid-recipient",
    amountPaise: 50000,
    ...overrides,
  };
}

describe("validateActivityPayload — reminder (FR-SE-09)", () => {
  it("accepts a minimal valid payload (no message)", () => {
    expect(() =>
      validateActivityPayload("reminder", validReminderPayload()),
    ).not.toThrow();
  });

  it("accepts a valid payload with optional message", () => {
    expect(() =>
      validateActivityPayload(
        "reminder",
        validReminderPayload({message: "Please settle up when you can."}),
      ),
    ).not.toThrow();
  });

  it("accepts a payload with message at maximum length (500 chars)", () => {
    expect(() =>
      validateActivityPayload(
        "reminder",
        validReminderPayload({message: "x".repeat(500)}),
      ),
    ).not.toThrow();
  });

  it("rejects payload with message longer than 500 chars", () => {
    expect(() =>
      validateActivityPayload(
        "reminder",
        validReminderPayload({message: "x".repeat(501)}),
      ),
    ).toThrow(/message.*500/);
  });

  it("rejects payload missing senderUid", () => {
    const bad = validReminderPayload();
    delete (bad as Partial<ReminderPayload>).senderUid;
    expect(() =>
      validateActivityPayload("reminder", bad as ReminderPayload),
    ).toThrow(/missing required field 'senderUid'/);
  });

  it("rejects payload missing recipientUid", () => {
    const bad = validReminderPayload();
    delete (bad as Partial<ReminderPayload>).recipientUid;
    expect(() =>
      validateActivityPayload("reminder", bad as ReminderPayload),
    ).toThrow(/missing required field 'recipientUid'/);
  });

  it("rejects payload with empty senderUid string", () => {
    expect(() =>
      validateActivityPayload(
        "reminder",
        validReminderPayload({senderUid: ""}),
      ),
    ).toThrow(/senderUid must be a non-empty string/);
  });

  it("rejects payload with empty recipientUid string", () => {
    expect(() =>
      validateActivityPayload(
        "reminder",
        validReminderPayload({recipientUid: ""}),
      ),
    ).toThrow(/recipientUid must be a non-empty string/);
  });

  it("rejects payload with non-integer amountPaise", () => {
    expect(() =>
      validateActivityPayload(
        "reminder",
        validReminderPayload({amountPaise: 100.5}),
      ),
    ).toThrow(/amountPaise must be a positive integer/);
  });

  it("rejects payload with zero amountPaise", () => {
    expect(() =>
      validateActivityPayload(
        "reminder",
        validReminderPayload({amountPaise: 0}),
      ),
    ).toThrow(/amountPaise must be a positive integer/);
  });

  it("rejects payload with negative amountPaise", () => {
    expect(() =>
      validateActivityPayload(
        "reminder",
        validReminderPayload({amountPaise: -100}),
      ),
    ).toThrow(/amountPaise must be a positive integer/);
  });

  it("rejects invalid contextType (defence-in-depth)", () => {
    expect(() =>
      validateActivityPayload(
        "reminder",
        validReminderPayload({
          contextType: "wedding" as unknown as "friendship" | "group",
        }),
      ),
    ).toThrow(/contextType must be 'friendship' or 'group'/);
  });

  it("rejects empty contextId", () => {
    expect(() =>
      validateActivityPayload(
        "reminder",
        validReminderPayload({contextId: ""}),
      ),
    ).toThrow(/contextId must be a non-empty string/);
  });

  it("rejects payload where message is non-string (when present)", () => {
    const bad = validReminderPayload();
    (bad as {message: unknown}).message = 42;
    expect(() => validateActivityPayload("reminder", bad)).toThrow(
      /message.*string/,
    );
  });
});
