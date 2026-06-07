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
