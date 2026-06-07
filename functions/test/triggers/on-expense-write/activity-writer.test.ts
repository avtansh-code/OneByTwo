/**
 * Unit tests for `writeExpenseActivity` — the activity-feed writer
 * called by the trigger handler after every successful recompute
 * (FR-EX-07).
 *
 * Covers ACs:
 *   - AC-1: create writes expense_added to BOTH members
 *   - AC-2: edit writes expense_edited to BOTH members
 *   - AC-3: soft-delete writes expense_deleted to BOTH members
 *   - AC-4: authorUid captured in the payload
 *   - AC-13: idempotency posture documented (the writer itself has no
 *            dedup; the trigger drops stale events before calling)
 *   - AC-14: PII guard on every structured-log event
 *   - AC-18 (smoke): validator throws before any Firestore write on
 *            an invalid payload
 *
 * No emulator needed — uses a mock Firestore that captures every
 * `.add(...)` call for assertion.
 *
 * @module test/triggers/on-expense-write/activity-writer.test.ts
 */

import {Timestamp} from "firebase-admin/firestore";
import {
  writeExpenseActivity,
  EVENT_ACTIVITY_ITEM_WRITTEN,
  EVENT_ACTIVITY_ITEM_WRITE_FAILED,
  EVENT_ACTIVITY_EMISSION_COMPLETED,
  type ActivityWriterDependencies,
} from "../../../src/triggers/on-expense-write/activity-writer";
import type {
  ActivityPayload,
  ExpenseAddedPayload,
  ExpenseDeletedPayload,
  ExpenseEditedPayload,
} from "../../../src/triggers/on-expense-write/payload-builder";

// ---------------------------------------------------------------------------
// Mock helpers
// ---------------------------------------------------------------------------

interface LoggerCall {
  level: "info" | "error";
  message: string;
  data?: Record<string, unknown>;
}

function createMockLogger() {
  const calls: LoggerCall[] = [];
  return {
    info: (message: string, data?: Record<string, unknown>) => {
      calls.push({level: "info", message, data});
    },
    error: (message: string, data?: Record<string, unknown>) => {
      calls.push({level: "error", message, data});
    },
    calls,
  };
}

interface MockDocAddCall {
  path: string;
  data: Record<string, unknown>;
}

/**
 * Builds a mock Firestore that captures every
 * `db.collection('activity').doc(uid).collection('items').add(data)`
 * call. Configure per-member failures via `failingMemberIds`.
 */
function createMockDb(
  failingMemberIds: ReadonlySet<string> = new Set<string>(),
): {
  db: FirebaseFirestore.Firestore;
  addCalls: MockDocAddCall[];
} {
  const addCalls: MockDocAddCall[] = [];

  const mockDb = {
    collection: jest.fn((collectionName: string) => {
      if (collectionName !== "activity") {
        throw new Error(
          `Unexpected collection accessed: ${collectionName}. ` +
            "The activity-writer should ONLY touch the activity collection.",
        );
      }
      return {
        doc: jest.fn((recipientUid: string) => ({
          collection: jest.fn((subcollectionName: string) => {
            if (subcollectionName !== "items") {
              throw new Error(
                `Unexpected subcollection accessed: ${subcollectionName}.`,
              );
            }
            return {
              add: jest.fn(async (data: Record<string, unknown>) => {
                addCalls.push({
                  path: `activity/${recipientUid}/items/{auto-id}`,
                  data,
                });
                if (failingMemberIds.has(recipientUid)) {
                  const err = new Error(
                    `Simulated failure for member ${recipientUid}`,
                  );
                  (err as {code?: string}).code = "permission-denied";
                  throw err;
                }
                return {id: `auto-id-${recipientUid}`};
              }),
            };
          }),
        })),
      };
    }),
  };

  return {db: mockDb as unknown as FirebaseFirestore.Firestore, addCalls};
}

function makeDeps(
  failingMemberIds: ReadonlySet<string> = new Set<string>(),
): {
  deps: ActivityWriterDependencies;
  addCalls: MockDocAddCall[];
  loggerCalls: LoggerCall[];
} {
  const {db, addCalls} = createMockDb(failingMemberIds);
  const logger = createMockLogger();
  return {
    deps: {db, logger},
    addCalls,
    loggerCalls: logger.calls,
  };
}

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

function validExpenseEditedPayload(): ExpenseEditedPayload {
  return {...validExpenseAddedPayload(), changedFields: ["amountPaise"]};
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

// ---------------------------------------------------------------------------
// AC-1 — create writes to BOTH members
// ---------------------------------------------------------------------------

describe("writeExpenseActivity — AC-1 (create writes to BOTH members)", () => {
  it("writes one activity item per friendship member", async () => {
    const {deps, addCalls} = makeDeps();

    const result = await writeExpenseActivity(deps, {
      friendshipId: "uidA_uidB",
      expenseId: "exp-1",
      eventType: "expense_added",
      payload: validExpenseAddedPayload(),
      memberIds: ["uidA", "uidB"],
    });

    expect(result.membersSucceeded).toBe(2);
    expect(result.membersFailed).toBe(0);
    expect(addCalls).toHaveLength(2);

    const paths = addCalls.map((c) => c.path).sort();
    expect(paths).toEqual([
      "activity/uidA/items/{auto-id}",
      "activity/uidB/items/{auto-id}",
    ]);

    // Each Firestore document has the type, payload, and createdAt.
    for (const call of addCalls) {
      expect(call.data.type).toBe("expense_added");
      expect(call.data.payload).toEqual(validExpenseAddedPayload());
      expect(call.data.createdAt).toBeDefined();
    }
  });
});

// ---------------------------------------------------------------------------
// AC-2 — edit writes to BOTH members
// ---------------------------------------------------------------------------

describe("writeExpenseActivity — AC-2 (edit writes to BOTH members)", () => {
  it("writes an expense_edited item per member with changedFields", async () => {
    const {deps, addCalls} = makeDeps();

    await writeExpenseActivity(deps, {
      friendshipId: "uidA_uidB",
      expenseId: "exp-1",
      eventType: "expense_edited",
      payload: validExpenseEditedPayload(),
      memberIds: ["uidA", "uidB"],
    });

    expect(addCalls).toHaveLength(2);
    for (const call of addCalls) {
      expect(call.data.type).toBe("expense_edited");
      const payload = call.data.payload as ExpenseEditedPayload;
      expect(payload.changedFields).toEqual(["amountPaise"]);
    }
  });
});

// ---------------------------------------------------------------------------
// AC-3 — soft-delete writes to BOTH members
// ---------------------------------------------------------------------------

describe("writeExpenseActivity — AC-3 (soft-delete writes to BOTH members)", () => {
  it("writes an expense_deleted item per member with deletedAt", async () => {
    const {deps, addCalls} = makeDeps();
    const deletedAt = Timestamp.fromDate(new Date("2026-06-07T12:00:00Z"));

    await writeExpenseActivity(deps, {
      friendshipId: "uidA_uidB",
      expenseId: "exp-1",
      eventType: "expense_deleted",
      payload: validExpenseDeletedPayload({deletedAt}),
      memberIds: ["uidA", "uidB"],
    });

    expect(addCalls).toHaveLength(2);
    for (const call of addCalls) {
      expect(call.data.type).toBe("expense_deleted");
      const payload = call.data.payload as ExpenseDeletedPayload;
      expect(payload.deletedAt).toEqual(deletedAt);
      expect(payload.description).toBe("Dinner");
    }
  });
});

// ---------------------------------------------------------------------------
// AC-4 — authorUid captured in the payload
// ---------------------------------------------------------------------------

describe("writeExpenseActivity — AC-4 (authorUid captured)", () => {
  it("passes authorUid through to the written payload", async () => {
    const {deps, addCalls} = makeDeps();

    await writeExpenseActivity(deps, {
      friendshipId: "uidA_uidB",
      expenseId: "exp-1",
      eventType: "expense_added",
      payload: validExpenseAddedPayload({authorUid: "uid-author-specific"}),
      memberIds: ["uidA", "uidB"],
    });

    for (const call of addCalls) {
      const payload = call.data.payload as ExpenseAddedPayload;
      expect(payload.authorUid).toBe("uid-author-specific");
    }
  });
});

// ---------------------------------------------------------------------------
// Containment — per-member failure does not block the other member's write
// ---------------------------------------------------------------------------

describe("writeExpenseActivity — error containment (architect §2.9 item 2)", () => {
  it("a single member's write failure does NOT block the other member", async () => {
    const {deps, addCalls, loggerCalls} = makeDeps(new Set(["uidA"]));

    const result = await writeExpenseActivity(deps, {
      friendshipId: "uidA_uidB",
      expenseId: "exp-1",
      eventType: "expense_added",
      payload: validExpenseAddedPayload(),
      memberIds: ["uidA", "uidB"],
    });

    // Both .add() attempts were issued; the rejected one is still
    // captured in addCalls because the call WAS made (it just threw).
    expect(addCalls).toHaveLength(2);
    expect(result.membersSucceeded).toBe(1);
    expect(result.membersFailed).toBe(1);

    const failedLog = loggerCalls.find(
      (c) => c.data?.event === EVENT_ACTIVITY_ITEM_WRITE_FAILED,
    );
    expect(failedLog).toBeDefined();
    expect(failedLog!.level).toBe("error");
    expect(failedLog!.data!.errorCode).toBe("permission-denied");

    const summaryLog = loggerCalls.find(
      (c) => c.data?.event === EVENT_ACTIVITY_EMISSION_COMPLETED,
    );
    expect(summaryLog).toBeDefined();
    expect(summaryLog!.data!.membersSucceeded).toBe(1);
    expect(summaryLog!.data!.membersFailed).toBe(1);
  });

  it("the writer NEVER rethrows even when every member's write fails", async () => {
    const {deps, addCalls, loggerCalls} = makeDeps(
      new Set(["uidA", "uidB"]),
    );

    await expect(
      writeExpenseActivity(deps, {
        friendshipId: "uidA_uidB",
        expenseId: "exp-1",
        eventType: "expense_added",
        payload: validExpenseAddedPayload(),
        memberIds: ["uidA", "uidB"],
      }),
    ).resolves.toEqual({membersSucceeded: 0, membersFailed: 2});

    expect(addCalls).toHaveLength(2);

    const failedLogs = loggerCalls.filter(
      (c) => c.data?.event === EVENT_ACTIVITY_ITEM_WRITE_FAILED,
    );
    expect(failedLogs).toHaveLength(2);
  });
});

// ---------------------------------------------------------------------------
// Structured-log content — affirmative shape per event
// ---------------------------------------------------------------------------

describe("writeExpenseActivity — structured-log content (FR-EX-07 §2.4)", () => {
  it("emits activity_item_written per successful per-member write", async () => {
    const {deps, loggerCalls} = makeDeps();

    await writeExpenseActivity(deps, {
      friendshipId: "uidA_uidB",
      expenseId: "exp-1",
      eventType: "expense_added",
      payload: validExpenseAddedPayload(),
      memberIds: ["uidA", "uidB"],
    });

    const writtenLogs = loggerCalls.filter(
      (c) => c.data?.event === EVENT_ACTIVITY_ITEM_WRITTEN,
    );
    expect(writtenLogs).toHaveLength(2);
    for (const log of writtenLogs) {
      const data = log.data!;
      expect(data.contextType).toBe("friendship");
      expect(data.eventType).toBe("expense_added");
      expect(data.contextIdHash).toMatch(/^[0-9a-f]{16}$/);
      expect(data.expenseIdHash).toMatch(/^[0-9a-f]{16}$/);
      expect(data.authorUidHash).toMatch(/^[0-9a-f]{16}$/);
      expect(data.recipientUidHash).toMatch(/^[0-9a-f]{16}$/);
      expect(typeof data.payloadSizeBytes).toBe("number");
      expect(data.payloadSizeBytes as number).toBeGreaterThan(0);
    }
  });

  it("emits activity_emission_completed exactly once per invocation", async () => {
    const {deps, loggerCalls} = makeDeps();

    await writeExpenseActivity(deps, {
      friendshipId: "uidA_uidB",
      expenseId: "exp-1",
      eventType: "expense_added",
      payload: validExpenseAddedPayload(),
      memberIds: ["uidA", "uidB"],
    });

    const summaryLogs = loggerCalls.filter(
      (c) => c.data?.event === EVENT_ACTIVITY_EMISSION_COMPLETED,
    );
    expect(summaryLogs).toHaveLength(1);
    const data = summaryLogs[0].data!;
    expect(data.contextType).toBe("friendship");
    expect(data.eventType).toBe("expense_added");
    expect(data.membersSucceeded).toBe(2);
    expect(data.membersFailed).toBe(0);
  });
});

// ---------------------------------------------------------------------------
// AC-14 — PII guard (NO raw UID, friendshipId, expenseId, or description
// in any structured-log line)
// ---------------------------------------------------------------------------

describe("writeExpenseActivity — AC-14 (PII guard on every structured-log event)", () => {
  it("never logs raw UIDs, raw friendshipId, raw expenseId, or description", async () => {
    const uidAlice = "pii-uid-alice-secret";
    const uidBob = "pii-uid-bob-secret";
    const realisticFriendshipId = `${uidAlice}_${uidBob}`;
    const realisticExpenseId = "pii-expense-id-secret";

    const {deps, loggerCalls} = makeDeps(new Set([uidBob]));
    // ^ also include a failure path so activity_item_write_failed is emitted

    await writeExpenseActivity(deps, {
      friendshipId: realisticFriendshipId,
      expenseId: realisticExpenseId,
      eventType: "expense_added",
      payload: validExpenseAddedPayload({
        expenseId: realisticExpenseId,
        friendshipId: realisticFriendshipId,
        payerId: uidAlice,
        authorUid: uidAlice,
        description: "PII-secret-dinner",
        splits: [
          {userId: uidAlice, sharePaise: 5000},
          {userId: uidBob, sharePaise: 5000},
        ],
      }),
      memberIds: [uidAlice, uidBob],
    });

    expect(loggerCalls.length).toBeGreaterThan(0);
    for (const call of loggerCalls) {
      const serialised = JSON.stringify(call.data);
      expect(serialised).not.toContain(uidAlice);
      expect(serialised).not.toContain(uidBob);
      expect(serialised).not.toContain(realisticFriendshipId);
      expect(serialised).not.toContain(realisticExpenseId);
      expect(serialised).not.toContain("PII-secret-dinner");
    }

    // Affirmative: every hash IS present and is the expected format.
    const writtenOrFailedLogs = loggerCalls.filter(
      (c) =>
        c.data?.event === EVENT_ACTIVITY_ITEM_WRITTEN ||
        c.data?.event === EVENT_ACTIVITY_ITEM_WRITE_FAILED,
    );
    expect(writtenOrFailedLogs.length).toBeGreaterThan(0);
    for (const log of writtenOrFailedLogs) {
      const data = log.data!;
      expect(data.contextIdHash).toMatch(/^[0-9a-f]{16}$/);
      expect(data.expenseIdHash).toMatch(/^[0-9a-f]{16}$/);
      expect(data.authorUidHash).toMatch(/^[0-9a-f]{16}$/);
      expect(data.recipientUidHash).toMatch(/^[0-9a-f]{16}$/);
    }
  });
});

// ---------------------------------------------------------------------------
// AC-13 — idempotency posture (the writer itself has NO dedup; the
// trigger drops stale events before calling — exercised in function.test.ts)
// ---------------------------------------------------------------------------

describe("writeExpenseActivity — AC-13 (idempotency posture)", () => {
  it("two identical invocations produce two pairs of activity items (writer has no dedup)", async () => {
    const {deps, addCalls} = makeDeps();
    const request = {
      friendshipId: "uidA_uidB",
      expenseId: "exp-1",
      eventType: "expense_added" as const,
      payload: validExpenseAddedPayload(),
      memberIds: ["uidA", "uidB"],
    };

    await writeExpenseActivity(deps, request);
    await writeExpenseActivity(deps, request);

    // Two pairs == 4 total writes. The writer is NOT responsible for
    // dedup; the trigger's stale-event drop is the inherited gate per
    // FR-EX-07 architect §2.5.
    expect(addCalls).toHaveLength(4);
  });
});

// ---------------------------------------------------------------------------
// AC-18 (smoke) — validator throws before any Firestore write on invalid payload
// ---------------------------------------------------------------------------

describe("writeExpenseActivity — AC-18 (validator throws before Firestore I/O)", () => {
  it("throws and writes nothing when payload is missing a required field", async () => {
    const {deps, addCalls} = makeDeps();
    const invalid = validExpenseAddedPayload();
    delete (invalid as Partial<ExpenseAddedPayload>).payerId;

    await expect(
      writeExpenseActivity(deps, {
        friendshipId: "uidA_uidB",
        expenseId: "exp-1",
        eventType: "expense_added",
        payload: invalid as unknown as ActivityPayload,
        memberIds: ["uidA", "uidB"],
      }),
    ).rejects.toThrow(/missing required field/);

    expect(addCalls).toHaveLength(0);
  });
});
