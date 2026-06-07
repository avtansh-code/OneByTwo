/**
 * Unit tests for `buildExpenseActivityPayload` — the pure mapping
 * function that maps the trigger's `(changeType, before, after)` tuple
 * to the typed `ActivityPayload`.
 *
 * Pure function; no Firebase admin needed. Exercises every change-type
 * branch + per-event-type payload shape per FR-EX-07 AC-1, AC-2, AC-3,
 * and architect notes §2.6.
 *
 * @module test/triggers/on-expense-write/payload-builder.test.ts
 */

import {Timestamp} from "firebase-admin/firestore";
import {
  buildExpenseActivityPayload,
  type ExpenseDocData,
} from "../../../src/triggers/on-expense-write/payload-builder";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function validExpenseData(
  overrides: Partial<ExpenseDocData> = {},
): ExpenseDocData {
  return {
    payerId: "uidA",
    amountPaise: 10000,
    splits: [
      {userId: "uidA", sharePaise: 5000},
      {userId: "uidB", sharePaise: 5000},
    ],
    description: "Test expense",
    category: "food",
    splitMethod: "equal",
    receiptUrl: null,
    createdBy: "uidA",
    deleted: false,
    ...overrides,
  };
}

const FRIENDSHIP_ID = "uidA_uidB";
const EXPENSE_ID = "exp-123";

// ---------------------------------------------------------------------------
// CREATE branch
// ---------------------------------------------------------------------------

describe("buildExpenseActivityPayload — create", () => {
  it("emits expense_added with all base fields populated", () => {
    const after = validExpenseData();
    const built = buildExpenseActivityPayload(
      "create",
      {friendshipId: FRIENDSHIP_ID, expenseId: EXPENSE_ID, after},
    );

    expect(built.eventType).toBe("expense_added");
    expect(built.payload).toEqual({
      expenseId: EXPENSE_ID,
      friendshipId: FRIENDSHIP_ID,
      description: "Test expense",
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
    });
  });

  it("derives hasReceipt: true when receiptUrl is a non-empty string", () => {
    const after = validExpenseData({
      receiptUrl: "https://firebasestorage.googleapis.com/v0/b/.../receipt.jpg",
    });
    const built = buildExpenseActivityPayload(
      "create",
      {friendshipId: FRIENDSHIP_ID, expenseId: EXPENSE_ID, after},
    );

    expect(built.eventType).toBe("expense_added");
    expect((built.payload as {hasReceipt: boolean}).hasReceipt).toBe(true);
  });

  it("derives hasReceipt: false when receiptUrl is the empty string", () => {
    const after = validExpenseData({receiptUrl: ""});
    const built = buildExpenseActivityPayload(
      "create",
      {friendshipId: FRIENDSHIP_ID, expenseId: EXPENSE_ID, after},
    );

    expect((built.payload as {hasReceipt: boolean}).hasReceipt).toBe(false);
  });

  it("captures authorUid from createdBy field", () => {
    const after = validExpenseData({createdBy: "creator-uid", payerId: "uidA"});
    const built = buildExpenseActivityPayload(
      "create",
      {friendshipId: FRIENDSHIP_ID, expenseId: EXPENSE_ID, after},
    );

    expect((built.payload as {authorUid: string}).authorUid).toBe("creator-uid");
    expect((built.payload as {payerId: string}).payerId).toBe("uidA");
  });

  it("throws when after snapshot is missing", () => {
    expect(() =>
      buildExpenseActivityPayload(
        "create",
        {friendshipId: FRIENDSHIP_ID, expenseId: EXPENSE_ID},
      ),
    ).toThrow(/'create' requires 'after'/);
  });
});

// ---------------------------------------------------------------------------
// UPDATE branch
// ---------------------------------------------------------------------------

describe("buildExpenseActivityPayload — update", () => {
  it("emits expense_edited with changedFields = ['amountPaise'] when only amount changed", () => {
    const before = validExpenseData();
    const after = validExpenseData({
      amountPaise: 20000,
      splits: [
        {userId: "uidA", sharePaise: 10000},
        {userId: "uidB", sharePaise: 10000},
      ],
    });
    const built = buildExpenseActivityPayload(
      "update",
      {friendshipId: FRIENDSHIP_ID, expenseId: EXPENSE_ID, before, after},
    );

    expect(built.eventType).toBe("expense_edited");
    expect(
      (built.payload as {changedFields: string[]}).changedFields.sort(),
    ).toEqual(["amountPaise", "splits"]);
    expect((built.payload as {amountPaise: number}).amountPaise).toBe(20000);
  });

  it("emits expense_edited with changedFields = ['receiptUrl'] for receipt-only attach (FR-EX-07 AC-2)", () => {
    const before = validExpenseData({receiptUrl: null});
    const after = validExpenseData({
      receiptUrl: "https://firebasestorage.googleapis.com/v0/b/.../receipt.jpg",
    });
    const built = buildExpenseActivityPayload(
      "update",
      {friendshipId: FRIENDSHIP_ID, expenseId: EXPENSE_ID, before, after},
    );

    expect(built.eventType).toBe("expense_edited");
    expect((built.payload as {changedFields: string[]}).changedFields).toEqual([
      "receiptUrl",
    ]);
    expect((built.payload as {hasReceipt: boolean}).hasReceipt).toBe(true);
  });

  it("emits expense_edited with changedFields = ['receiptUrl'] for receipt-only remove", () => {
    const before = validExpenseData({
      receiptUrl: "https://firebasestorage.googleapis.com/v0/b/.../receipt.jpg",
    });
    const after = validExpenseData({receiptUrl: null});
    const built = buildExpenseActivityPayload(
      "update",
      {friendshipId: FRIENDSHIP_ID, expenseId: EXPENSE_ID, before, after},
    );

    expect((built.payload as {changedFields: string[]}).changedFields).toEqual([
      "receiptUrl",
    ]);
    expect((built.payload as {hasReceipt: boolean}).hasReceipt).toBe(false);
  });

  it("emits expense_edited with empty changedFields when no monitored field changed", () => {
    // Both snapshots identical (in DIFF_FIELDS terms) — the update was on
    // an excluded field like updatedAt. The activity-writer still emits
    // expense_edited because changeType is 'update'; the empty
    // changedFields array signals the client to render a no-op.
    const before = validExpenseData();
    const after = validExpenseData();
    const built = buildExpenseActivityPayload(
      "update",
      {friendshipId: FRIENDSHIP_ID, expenseId: EXPENSE_ID, before, after},
    );

    expect(built.eventType).toBe("expense_edited");
    expect((built.payload as {changedFields: string[]}).changedFields).toEqual(
      [],
    );
  });

  it("emits expense_edited with multiple changedFields when many fields changed", () => {
    const before = validExpenseData();
    const after = validExpenseData({
      description: "New description",
      category: "transport",
      payerId: "uidB",
      splitMethod: "exact",
    });
    const built = buildExpenseActivityPayload(
      "update",
      {friendshipId: FRIENDSHIP_ID, expenseId: EXPENSE_ID, before, after},
    );

    expect(
      (built.payload as {changedFields: string[]}).changedFields.sort(),
    ).toEqual(["category", "description", "payerId", "splitMethod"]);
  });

  it("throws when before snapshot is missing", () => {
    const after = validExpenseData();
    expect(() =>
      buildExpenseActivityPayload(
        "update",
        {friendshipId: FRIENDSHIP_ID, expenseId: EXPENSE_ID, after},
      ),
    ).toThrow(/'update' requires both 'before' and 'after'/);
  });

  it("throws when after snapshot is missing", () => {
    const before = validExpenseData();
    expect(() =>
      buildExpenseActivityPayload(
        "update",
        {friendshipId: FRIENDSHIP_ID, expenseId: EXPENSE_ID, before},
      ),
    ).toThrow(/'update' requires both 'before' and 'after'/);
  });
});

// ---------------------------------------------------------------------------
// DELETE branch (both soft- and hard-delete)
// ---------------------------------------------------------------------------

describe("buildExpenseActivityPayload — delete", () => {
  it("emits expense_deleted with pre-delete snapshot fields", () => {
    const before = validExpenseData({
      description: "Pre-delete description",
      amountPaise: 50000,
      category: "shopping",
      createdBy: "creator-uid",
    });
    const deletedAt = Timestamp.fromDate(new Date("2026-06-07T12:00:00Z"));
    const built = buildExpenseActivityPayload(
      "delete",
      {friendshipId: FRIENDSHIP_ID, expenseId: EXPENSE_ID, before},
      deletedAt,
    );

    expect(built.eventType).toBe("expense_deleted");
    expect(built.payload).toEqual({
      expenseId: EXPENSE_ID,
      friendshipId: FRIENDSHIP_ID,
      description: "Pre-delete description",
      amountPaise: 50000,
      category: "shopping",
      authorUid: "creator-uid",
      deletedAt,
    });
  });

  it("captures authorUid from the pre-delete snapshot's createdBy", () => {
    const before = validExpenseData({createdBy: "original-author"});
    const deletedAt = Timestamp.now();
    const built = buildExpenseActivityPayload(
      "delete",
      {friendshipId: FRIENDSHIP_ID, expenseId: EXPENSE_ID, before},
      deletedAt,
    );

    expect((built.payload as {authorUid: string}).authorUid).toBe(
      "original-author",
    );
  });

  it("throws when before snapshot is missing", () => {
    const deletedAt = Timestamp.now();
    expect(() =>
      buildExpenseActivityPayload(
        "delete",
        {friendshipId: FRIENDSHIP_ID, expenseId: EXPENSE_ID},
        deletedAt,
      ),
    ).toThrow(/'delete' requires 'before'/);
  });

  it("throws when deletedAt is missing", () => {
    const before = validExpenseData();
    expect(() =>
      buildExpenseActivityPayload(
        "delete",
        {friendshipId: FRIENDSHIP_ID, expenseId: EXPENSE_ID, before},
      ),
    ).toThrow(/'delete' requires 'deletedAt'/);
  });
});

// ---------------------------------------------------------------------------
// Invariant 1 boundary check (paise integers — no float arithmetic)
// ---------------------------------------------------------------------------

describe("buildExpenseActivityPayload — Invariant 1 (paise integers)", () => {
  it("preserves amountPaise as an integer (no /100 conversion to rupees)", () => {
    const after = validExpenseData({amountPaise: 12345});
    const built = buildExpenseActivityPayload(
      "create",
      {friendshipId: FRIENDSHIP_ID, expenseId: EXPENSE_ID, after},
    );

    const amount = (built.payload as {amountPaise: number}).amountPaise;
    expect(amount).toBe(12345);
    expect(Number.isInteger(amount)).toBe(true);
  });

  it("preserves every split.sharePaise as an integer", () => {
    const after = validExpenseData({
      amountPaise: 9999,
      splits: [
        {userId: "uidA", sharePaise: 4999},
        {userId: "uidB", sharePaise: 5000},
      ],
    });
    const built = buildExpenseActivityPayload(
      "create",
      {friendshipId: FRIENDSHIP_ID, expenseId: EXPENSE_ID, after},
    );

    const splits = (built.payload as {splits: Array<{sharePaise: number}>})
      .splits;
    for (const split of splits) {
      expect(Number.isInteger(split.sharePaise)).toBe(true);
    }
  });
});
