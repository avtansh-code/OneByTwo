/**
 * Function-boundary tests for the onExpenseWriteFriendship trigger.
 *
 * These tests exercise `createTriggerHandler(deps)` directly with mocked
 * Firestore + logger — no emulator required. The trigger handler is the thin
 * orchestration layer wrapping the shared `recomputeAndWrite` core; this
 * suite asserts the trigger-specific concerns: change-type discrimination,
 * stale-event guard, `lastActivityAt` monotonicity, error-policy mapping,
 * structured telemetry, and PII-free logging.
 *
 * Coverage target per the per-module gate: >= 70% of
 * functions/src/triggers/on-expense-write/.
 *
 * @module test/triggers/on-expense-write/function.test.ts
 */

import {Timestamp} from "firebase-admin/firestore";
import type {Change, DocumentSnapshot, FirestoreEvent} from
  "firebase-functions/v2/firestore";
import {createTriggerHandler} from
  "../../../src/triggers/on-expense-write/function";
import {writeExpenseActivity} from
  "../../../src/triggers/on-expense-write/activity-writer";

jest.mock("../../../src/triggers/on-expense-write/activity-writer");

const mockedWriteExpenseActivity = writeExpenseActivity as jest.MockedFunction<
  typeof writeExpenseActivity
>;

beforeEach(() => {
  mockedWriteExpenseActivity.mockReset();
  mockedWriteExpenseActivity.mockResolvedValue({
    membersSucceeded: 2,
    membersFailed: 0,
  });
});

// ---------------------------------------------------------------------------
// Mock helpers — copy the simplified-debts/function.test.ts pattern
// ---------------------------------------------------------------------------

interface LoggerCall {
  level: "info" | "warn" | "error";
  message: string;
  data?: Record<string, unknown>;
}

function createMockLogger() {
  const calls: LoggerCall[] = [];
  return {
    info: (message: string, data?: Record<string, unknown>) => {
      calls.push({level: "info", message, data});
    },
    warn: (message: string, data?: Record<string, unknown>) => {
      calls.push({level: "warn", message, data});
    },
    error: (message: string, data?: Record<string, unknown>) => {
      calls.push({level: "error", message, data});
    },
    calls,
  };
}

/**
 * Builds a mock Firestore where the friendship doc and its expenses
 * subcollection can be configured per-test. Records every `tx.update(...)`
 * call for assertion.
 *
 * FR-SE-05/06: also handles the top-level `settlements` collection query
 * introduced by the `recomputeAndWrite` settlement-read extension. When
 * `settlements` is omitted, the settlements query returns an empty list.
 */
function createMockDb(opts: {
  contextExists: boolean;
  contextData?: Record<string, unknown>;
  expenses?: Array<{id: string; data: Record<string, unknown>}>;
  settlements?: Array<{id: string; data: Record<string, unknown>}>;
}): FirebaseFirestore.Firestore {
  const expenseDocs = (opts.expenses ?? []).map((e) => ({
    id: e.id,
    exists: true,
    data: () => e.data,
    ref: {path: `friendships/fid/expenses/${e.id}`},
  }));

  const settlementDocs = (opts.settlements ?? []).map((s) => ({
    id: s.id,
    exists: true,
    data: () => s.data,
    ref: {path: `settlements/${s.id}`},
  }));

  const contextSnap = {
    exists: opts.contextExists,
    data: () => opts.contextData ?? {},
    ref: {path: "friendships/fid"},
  };

  const updateFn = jest.fn();

  const settlementsQuery = {_queryKind: "settlements"};
  const expensesQuery = {_queryKind: "expenses"};

  const mockDb = {
    collection: jest.fn((name: string) => {
      if (name === "settlements") {
        return {
          where: jest.fn().mockReturnValue({
            where: jest.fn().mockReturnValue(settlementsQuery),
          }),
        };
      }
      // friendships/{fid} doc-ref:
      //   .collection('expenses').where(...) — used by the trigger's
      //     read-side query (inside recomputeAndWrite).
      //   .get() — used by emitExpenseActivity to resolve memberIds
      //     for the activity fan-out (FR-EX-07).
      return {
        doc: jest.fn().mockReturnValue({
          collection: jest.fn().mockReturnValue({
            where: jest.fn().mockReturnValue(expensesQuery),
          }),
          get: jest.fn().mockResolvedValue({
            exists: opts.contextExists,
            data: () => opts.contextData ?? {},
          }),
          _isDocRef: true,
        }),
      };
    }),
    runTransaction: jest.fn(async (fn: (tx: unknown) => Promise<unknown>) => {
      const tx = {
        get: jest.fn((ref: unknown) => {
          const r = ref as Record<string, unknown>;
          if (r._queryKind === "expenses") {
            return Promise.resolve({docs: expenseDocs});
          }
          if (r._queryKind === "settlements") {
            return Promise.resolve({docs: settlementDocs});
          }
          return Promise.resolve(contextSnap);
        }),
        update: updateFn,
      };
      return fn(tx);
    }),
    _updateFn: updateFn,
  };

  return mockDb as unknown as FirebaseFirestore.Firestore;
}

/**
 * Builds a minimal FirestoreEvent for a friendship expense write. The
 * runtime `Change<DocumentSnapshot>` shape uses `.exists` on each side;
 * passing `undefined` for change.before models "create"; passing
 * `undefined` for change.after models "delete".
 */
function makeEvent(opts: {
  changeType: "create" | "update" | "delete";
  friendshipId?: string;
  expenseId?: string;
  eventTime?: string;
  beforeData?: Record<string, unknown>;
  afterData?: Record<string, unknown>;
}): FirestoreEvent<
  Change<DocumentSnapshot> | undefined,
  {friendshipId: string; expenseId: string}
> {
  const friendshipId = opts.friendshipId ?? "fid";
  const expenseId = opts.expenseId ?? "eid";
  const eventTime = opts.eventTime ?? new Date().toISOString();

  const beforeExists =
    opts.changeType === "update" || opts.changeType === "delete";
  const afterExists =
    opts.changeType === "create" || opts.changeType === "update";

  const beforeSnap = {
    exists: beforeExists,
    data: () => opts.beforeData ?? {},
    ref: {path: `friendships/${friendshipId}/expenses/${expenseId}`},
  } as unknown as DocumentSnapshot;

  const afterSnap = {
    exists: afterExists,
    data: () => opts.afterData ?? {},
    ref: {path: `friendships/${friendshipId}/expenses/${expenseId}`},
  } as unknown as DocumentSnapshot;

  const change = {before: beforeSnap, after: afterSnap} as unknown as Change<
    DocumentSnapshot
  >;

  return {
    id: "event-id",
    type: "google.cloud.firestore.document.v1.written",
    specversion: "1.0",
    source: "//firestore.googleapis.com/projects/demo-onebytwo",
    time: eventTime,
    document: `friendships/${friendshipId}/expenses/${expenseId}`,
    params: {friendshipId, expenseId},
    data: change,
    location: "asia-south1",
    project: "demo-onebytwo",
    database: "(default)",
    namespace: "(default)",
  } as unknown as FirestoreEvent<
    Change<DocumentSnapshot> | undefined,
    {friendshipId: string; expenseId: string}
  >;
}

/** Convenience: a valid two-person expense seed. */
function validExpenseData(overrides: Record<string, unknown> = {}) {
  return {
    payerId: "userA",
    amountPaise: 10000,
    splits: [
      {userId: "userA", sharePaise: 5000},
      {userId: "userB", sharePaise: 5000},
    ],
    deleted: false,
    description: "Test",
    ...overrides,
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("onExpenseWriteFriendship handler — boundary", () => {
  // -------------------------------------------------------------------------
  // 1. CREATE event recomputes balances and writes lastActivityAt
  // -------------------------------------------------------------------------
  it("recomputes simplifiedBalances on create and writes lastActivityAt atomically", async () => {
    const eventTime = new Date(Date.now() - 30 * 1000).toISOString();
    const expectedTimestamp = Timestamp.fromDate(new Date(eventTime));
    const db = createMockDb({
      contextExists: true,
      contextData: {
        memberIds: ["userA", "userB"],
        lastActivityAt: Timestamp.fromDate(
          new Date(Date.now() - 24 * 60 * 60 * 1000),
        ),
      },
      expenses: [{id: "eid", data: validExpenseData()}],
    });
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await handler(
      makeEvent({
        changeType: "create",
        eventTime,
        afterData: validExpenseData(),
      }),
    );

    const updateFn = (db as unknown as {_updateFn: jest.Mock})._updateFn;
    expect(updateFn).toHaveBeenCalledTimes(1);
    const [, payload] = updateFn.mock.calls[0];
    expect(payload).toEqual({
      simplifiedBalances: {userB: {userA: 5000}},
      lastActivityAt: expectedTimestamp,
    });
  });

  // -------------------------------------------------------------------------
  // 2. UPDATE event recomputes from current expense set
  // -------------------------------------------------------------------------
  it("recomputes on update with the post-edit expense set", async () => {
    const db = createMockDb({
      contextExists: true,
      contextData: {memberIds: ["userA", "userB"]},
      expenses: [
        {
          id: "eid",
          data: validExpenseData({
            amountPaise: 20000,
            splits: [
              {userId: "userA", sharePaise: 10000},
              {userId: "userB", sharePaise: 10000},
            ],
          }),
        },
      ],
    });
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await handler(
      makeEvent({
        changeType: "update",
        beforeData: validExpenseData(),
        afterData: validExpenseData({amountPaise: 20000}),
      }),
    );

    const updateFn = (db as unknown as {_updateFn: jest.Mock})._updateFn;
    expect(updateFn).toHaveBeenCalledTimes(1);
    expect(updateFn.mock.calls[0][1].simplifiedBalances).toEqual({
      userB: {userA: 10000},
    });
  });

  // -------------------------------------------------------------------------
  // 3. SOFT-DELETE: expense is removed from the active set (the query filter)
  // -------------------------------------------------------------------------
  it("recomputes on soft-delete (deleted=true in current set is filtered by the query)", async () => {
    // The trigger's transaction query is `where('deleted', '!=', true)`.
    // Our mock query returns whatever the test provides; here we simulate
    // the post-soft-delete state by passing an empty expenses array (the
    // single expense was soft-deleted and excluded by the query).
    const db = createMockDb({
      contextExists: true,
      contextData: {memberIds: ["userA", "userB"]},
      expenses: [],
    });
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await handler(
      makeEvent({
        changeType: "update",
        beforeData: validExpenseData(),
        afterData: validExpenseData({deleted: true}),
      }),
    );

    const updateFn = (db as unknown as {_updateFn: jest.Mock})._updateFn;
    expect(updateFn).toHaveBeenCalledTimes(1);
    expect(updateFn.mock.calls[0][1].simplifiedBalances).toEqual({});
  });

  // -------------------------------------------------------------------------
  // 4. HARD-DELETE: change.after is undefined; trigger still recomputes
  // -------------------------------------------------------------------------
  it("recomputes on hard-delete (change.after undefined) with current expense set", async () => {
    const db = createMockDb({
      contextExists: true,
      contextData: {memberIds: ["userA", "userB"]},
      expenses: [],
    });
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await handler(
      makeEvent({
        changeType: "delete",
        beforeData: validExpenseData(),
      }),
    );

    const updateFn = (db as unknown as {_updateFn: jest.Mock})._updateFn;
    expect(updateFn).toHaveBeenCalledTimes(1);
    expect(updateFn.mock.calls[0][1].simplifiedBalances).toEqual({});
  });

  // -------------------------------------------------------------------------
  // 5. Idempotency: second invocation with the same event produces identical
  //    simplifiedBalances. lastActivityAt may match or be later (monotonic).
  // -------------------------------------------------------------------------
  it("is idempotent: identical second invocation yields identical balances", async () => {
    const eventTime = new Date(Date.now() - 30 * 1000).toISOString();
    const db = createMockDb({
      contextExists: true,
      contextData: {memberIds: ["userA", "userB"]},
      expenses: [{id: "eid", data: validExpenseData()}],
    });
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await handler(
      makeEvent({changeType: "create", eventTime, afterData: validExpenseData()}),
    );
    await handler(
      makeEvent({changeType: "create", eventTime, afterData: validExpenseData()}),
    );

    const updateFn = (db as unknown as {_updateFn: jest.Mock})._updateFn;
    expect(updateFn).toHaveBeenCalledTimes(2);
    expect(updateFn.mock.calls[0][1].simplifiedBalances).toEqual(
      updateFn.mock.calls[1][1].simplifiedBalances,
    );
  });

  // -------------------------------------------------------------------------
  // 6. Stale-event guard: events older than 7 days do not write
  // -------------------------------------------------------------------------
  it("drops stale events (>7 days old) without writing", async () => {
    const eightDaysAgo = new Date(
      Date.now() - 8 * 24 * 60 * 60 * 1000,
    ).toISOString();
    const db = createMockDb({
      contextExists: true,
      contextData: {memberIds: ["userA", "userB"]},
      expenses: [{id: "eid", data: validExpenseData()}],
    });
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await handler(
      makeEvent({
        changeType: "create",
        eventTime: eightDaysAgo,
        afterData: validExpenseData(),
      }),
    );

    const updateFn = (db as unknown as {_updateFn: jest.Mock})._updateFn;
    expect(updateFn).not.toHaveBeenCalled();

    const droppedLog = logger.calls.find(
      (c) => c.data?.event === "expense_trigger_stale_event_dropped",
    );
    expect(droppedLog).toBeDefined();
    expect(droppedLog!.data!.contextType).toBe("friendship");
    expect(typeof droppedLog!.data!.contextIdHash).toBe("string");
    expect(droppedLog!.data!.contextIdHash).toMatch(/^[0-9a-f]{16}$/);
    expect(typeof droppedLog!.data!.expenseIdHash).toBe("string");
    expect(typeof droppedLog!.data!.ageMs).toBe("number");
  });

  // -------------------------------------------------------------------------
  // 7. CONTEXT_NOT_FOUND: friendship doc deleted → log and return, no throw
  // -------------------------------------------------------------------------
  it("logs CONTEXT_NOT_FOUND and returns successfully (no throw, no retry)", async () => {
    const db = createMockDb({contextExists: false});
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await expect(
      handler(
        makeEvent({changeType: "create", afterData: validExpenseData()}),
      ),
    ).resolves.toBeUndefined();

    const failedLog = logger.calls.find(
      (c) => c.data?.event === "simplified_debts_compute_failed",
    );
    expect(failedLog).toBeDefined();
    expect(failedLog!.data!.errorCode).toBe("CONTEXT_NOT_FOUND");
    expect(failedLog!.level).toBe("error");

    const updateFn = (db as unknown as {_updateFn: jest.Mock})._updateFn;
    expect(updateFn).not.toHaveBeenCalled();
  });

  // -------------------------------------------------------------------------
  // 8. BALANCE_INVARIANT_VIOLATED: trigger logs AND throws so CF retries
  // -------------------------------------------------------------------------
  it("logs BALANCE_INVARIANT_VIOLATED and throws so Cloud Functions retries", async () => {
    // Construct an expense where sharePaise sum != amountPaise:
    // payer A paid 10000, but splits sum to 7000. Net balances:
    // A: +10000 - 4000 = +6000, B: -3000. Residual: +3000 (non-zero) →
    // the simplifyDebts algorithm throws "Balance invariant violation".
    const db = createMockDb({
      contextExists: true,
      contextData: {memberIds: ["userA", "userB"]},
      expenses: [
        {
          id: "eid",
          data: {
            payerId: "userA",
            amountPaise: 10000,
            deleted: false,
            splits: [
              {userId: "userA", sharePaise: 4000},
              {userId: "userB", sharePaise: 3000},
            ],
          },
        },
      ],
    });
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await expect(
      handler(
        makeEvent({changeType: "create", afterData: validExpenseData()}),
      ),
    ).rejects.toThrow();

    const failedLog = logger.calls.find(
      (c) => c.data?.event === "simplified_debts_compute_failed",
    );
    expect(failedLog).toBeDefined();
    expect(failedLog!.data!.errorCode).toBe("BALANCE_INVARIANT_VIOLATED");
    expect(failedLog!.level).toBe("error");
  });

  // -------------------------------------------------------------------------
  // 9. PII guard: structured logger NEVER receives payerId, splits[].userId,
  //    amountPaise, sharePaise, or description values. The contextId
  //    (friendshipId) is also PII (it's a composite of two UIDs) — the
  //    trigger MUST hash it before logging.
  // -------------------------------------------------------------------------
  it("never logs PII (raw UIDs in friendshipId, payer/split userIds, amounts, description)", async () => {
    const uidAlice = "pii-uid-alice";
    const uidBob = "pii-uid-bob";
    const realisticFriendshipId = `${uidAlice}_${uidBob}`; // schema's composite-UID pattern
    const realisticExpenseId = "pii-expense-secret-id";

    const db = createMockDb({
      contextExists: true,
      contextData: {memberIds: [uidAlice, uidBob]},
      expenses: [
        {
          id: "eid",
          data: {
            payerId: uidAlice,
            amountPaise: 987654,
            splits: [
              {userId: uidAlice, sharePaise: 493827},
              {userId: uidBob, sharePaise: 493827},
            ],
            deleted: false,
            description: "PII-secret-dinner",
          },
        },
      ],
    });
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await handler(
      makeEvent({
        changeType: "create",
        friendshipId: realisticFriendshipId,
        expenseId: realisticExpenseId,
        afterData: {
          payerId: uidAlice,
          amountPaise: 987654,
          splits: [
            {userId: uidAlice, sharePaise: 493827},
            {userId: uidBob, sharePaise: 493827},
          ],
          deleted: false,
          description: "PII-secret-dinner",
        },
      }),
    );

    for (const call of logger.calls) {
      const serialised = JSON.stringify(call.data);
      // Raw UIDs (from friendshipId, payerId, splits[].userId)
      expect(serialised).not.toContain(uidAlice);
      expect(serialised).not.toContain(uidBob);
      // The raw composite friendshipId
      expect(serialised).not.toContain(realisticFriendshipId);
      // Raw expenseId (also opaque-looking but treated PII-safe via hashing)
      expect(serialised).not.toContain(realisticExpenseId);
      // Monetary values
      expect(serialised).not.toContain("987654");
      expect(serialised).not.toContain("493827");
      // Description text
      expect(serialised).not.toContain("PII-secret-dinner");
    }

    // Affirmative check: the hashed contextIdHash IS present in every log
    // line (so production ops still get correlation IDs).
    for (const call of logger.calls) {
      const data = call.data ?? {};
      if ("contextIdHash" in data) {
        expect((data as Record<string, unknown>).contextIdHash).toMatch(
          /^[0-9a-f]{16}$/,
        );
      }
    }
  });

  // -------------------------------------------------------------------------
  // 10. expense_trigger_fired is the FIRST log call (top of handler)
  // -------------------------------------------------------------------------
  it("emits expense_trigger_fired as the first log call with hashed IDs", async () => {
    const db = createMockDb({
      contextExists: true,
      contextData: {memberIds: ["userA", "userB"]},
      expenses: [{id: "eid", data: validExpenseData()}],
    });
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await handler(
      makeEvent({changeType: "create", afterData: validExpenseData()}),
    );

    expect(logger.calls.length).toBeGreaterThan(0);
    expect(logger.calls[0].data?.event).toBe("expense_trigger_fired");
    expect(logger.calls[0].data?.contextType).toBe("friendship");
    expect(logger.calls[0].data?.contextIdHash).toMatch(/^[0-9a-f]{16}$/);
    expect(logger.calls[0].data?.expenseIdHash).toMatch(/^[0-9a-f]{16}$/);
    expect(logger.calls[0].data?.changeType).toBe("create");
    expect(typeof logger.calls[0].data?.eventTime).toBe("string");
    // Raw IDs MUST NOT appear in the fired log.
    expect(logger.calls[0].data).not.toHaveProperty("contextId");
    expect(logger.calls[0].data).not.toHaveProperty("expenseId");
  });

  // -------------------------------------------------------------------------
  // 11. lastActivityAt monotonicity: older event does NOT regress existing
  // -------------------------------------------------------------------------
  it("does not regress lastActivityAt when an older event arrives", async () => {
    // Both timestamps must be within the 7-day stale-event window. We use
    // recent relative times to avoid hitting the stale-event guard.
    const olderEventTime = new Date(Date.now() - 60 * 60 * 1000).toISOString();
    const existingNewerTimestamp = Timestamp.fromDate(
      new Date(Date.now() - 5 * 60 * 1000),
    );
    const db = createMockDb({
      contextExists: true,
      contextData: {
        memberIds: ["userA", "userB"],
        lastActivityAt: existingNewerTimestamp,
      },
      expenses: [{id: "eid", data: validExpenseData()}],
    });
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await handler(
      makeEvent({
        changeType: "create",
        eventTime: olderEventTime,
        afterData: validExpenseData(),
      }),
    );

    const updateFn = (db as unknown as {_updateFn: jest.Mock})._updateFn;
    expect(updateFn).toHaveBeenCalledTimes(1);
    // lastActivityAt should remain the existing (newer) value
    expect(updateFn.mock.calls[0][1].lastActivityAt).toEqual(
      existingNewerTimestamp,
    );
    // simplifiedBalances is still written
    expect(updateFn.mock.calls[0][1].simplifiedBalances).toEqual({
      userB: {userA: 5000},
    });
  });

  // -------------------------------------------------------------------------
  // 12. lastActivityAt is updated when the event is newer than existing
  // -------------------------------------------------------------------------
  it("updates lastActivityAt when the event is newer than the existing value", async () => {
    const newerEventTime = new Date(Date.now() - 60 * 1000).toISOString();
    const newerTimestamp = Timestamp.fromDate(new Date(newerEventTime));
    const existingOlderTimestamp = Timestamp.fromDate(
      new Date(Date.now() - 60 * 60 * 1000),
    );
    const db = createMockDb({
      contextExists: true,
      contextData: {
        memberIds: ["userA", "userB"],
        lastActivityAt: existingOlderTimestamp,
      },
      expenses: [{id: "eid", data: validExpenseData()}],
    });
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await handler(
      makeEvent({
        changeType: "create",
        eventTime: newerEventTime,
        afterData: validExpenseData(),
      }),
    );

    const updateFn = (db as unknown as {_updateFn: jest.Mock})._updateFn;
    expect(updateFn).toHaveBeenCalledTimes(1);
    expect(updateFn.mock.calls[0][1].lastActivityAt).toEqual(newerTimestamp);
  });

  // -------------------------------------------------------------------------
  // 13. lastActivityAt is set when the existing value is absent
  // -------------------------------------------------------------------------
  it("writes lastActivityAt when the existing value is missing", async () => {
    const eventTime = new Date(Date.now() - 60 * 1000).toISOString();
    const expectedTimestamp = Timestamp.fromDate(new Date(eventTime));
    const db = createMockDb({
      contextExists: true,
      contextData: {memberIds: ["userA", "userB"]},
      // note: no lastActivityAt
      expenses: [{id: "eid", data: validExpenseData()}],
    });
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await handler(
      makeEvent({
        changeType: "create",
        eventTime,
        afterData: validExpenseData(),
      }),
    );

    const updateFn = (db as unknown as {_updateFn: jest.Mock})._updateFn;
    expect(updateFn).toHaveBeenCalledTimes(1);
    expect(updateFn.mock.calls[0][1].lastActivityAt).toEqual(expectedTimestamp);
  });
});

// ---------------------------------------------------------------------------
// FR-EX-07: trigger ↔ activity-writer contract
// ---------------------------------------------------------------------------

describe("onExpenseWriteFriendship handler — FR-EX-07 activity-writer integration", () => {
  // -------------------------------------------------------------------------
  // FR-EX-07 AC-1: create event invokes writeExpenseActivity with
  // expense_added payload for BOTH friendship members.
  // -------------------------------------------------------------------------
  it("calls writeExpenseActivity with expense_added on create — both members targeted", async () => {
    const db = createMockDb({
      contextExists: true,
      contextData: {memberIds: ["userA", "userB"]},
      expenses: [{id: "eid", data: validExpenseData()}],
    });
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await handler(
      makeEvent({changeType: "create", afterData: validExpenseData()}),
    );

    expect(mockedWriteExpenseActivity).toHaveBeenCalledTimes(1);
    const [, callRequest] = mockedWriteExpenseActivity.mock.calls[0];
    expect(callRequest.eventType).toBe("expense_added");
    expect(callRequest.memberIds).toEqual(["userA", "userB"]);
    expect(callRequest.friendshipId).toBe("fid");
    expect(callRequest.expenseId).toBe("eid");
  });

  // -------------------------------------------------------------------------
  // FR-EX-07 AC-2: update event (no deleted flip) invokes writeExpenseActivity
  // with expense_edited payload.
  // -------------------------------------------------------------------------
  it("calls writeExpenseActivity with expense_edited on regular edit", async () => {
    const db = createMockDb({
      contextExists: true,
      contextData: {memberIds: ["userA", "userB"]},
      expenses: [
        {
          id: "eid",
          data: validExpenseData({
            amountPaise: 20000,
            splits: [
              {userId: "userA", sharePaise: 10000},
              {userId: "userB", sharePaise: 10000},
            ],
          }),
        },
      ],
    });
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await handler(
      makeEvent({
        changeType: "update",
        beforeData: validExpenseData(),
        afterData: validExpenseData({
          amountPaise: 20000,
          splits: [
            {userId: "userA", sharePaise: 10000},
            {userId: "userB", sharePaise: 10000},
          ],
        }),
      }),
    );

    expect(mockedWriteExpenseActivity).toHaveBeenCalledTimes(1);
    const [, callRequest] = mockedWriteExpenseActivity.mock.calls[0];
    expect(callRequest.eventType).toBe("expense_edited");
  });

  // -------------------------------------------------------------------------
  // FR-EX-07 AC-3: soft-delete (update with deleted: false -> true) invokes
  // writeExpenseActivity with expense_deleted payload, NOT expense_edited.
  // -------------------------------------------------------------------------
  it("calls writeExpenseActivity with expense_deleted on soft-delete (not expense_edited)", async () => {
    const db = createMockDb({
      contextExists: true,
      contextData: {memberIds: ["userA", "userB"]},
      expenses: [],
    });
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await handler(
      makeEvent({
        changeType: "update",
        beforeData: validExpenseData({deleted: false}),
        afterData: validExpenseData({deleted: true}),
      }),
    );

    expect(mockedWriteExpenseActivity).toHaveBeenCalledTimes(1);
    const [, callRequest] = mockedWriteExpenseActivity.mock.calls[0];
    expect(callRequest.eventType).toBe("expense_deleted");
    expect(callRequest.memberIds).toEqual(["userA", "userB"]);
  });

  // -------------------------------------------------------------------------
  // FR-EX-07 AC-3 (hard-delete variant): change.after.exists === false invokes
  // writeExpenseActivity with expense_deleted.
  // -------------------------------------------------------------------------
  it("calls writeExpenseActivity with expense_deleted on hard-delete", async () => {
    const db = createMockDb({
      contextExists: true,
      contextData: {memberIds: ["userA", "userB"]},
      expenses: [],
    });
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await handler(
      makeEvent({changeType: "delete", beforeData: validExpenseData()}),
    );

    expect(mockedWriteExpenseActivity).toHaveBeenCalledTimes(1);
    const [, callRequest] = mockedWriteExpenseActivity.mock.calls[0];
    expect(callRequest.eventType).toBe("expense_deleted");
  });

  // -------------------------------------------------------------------------
  // FR-EX-07 AC-5: stale-event drop branch does NOT invoke writeExpenseActivity.
  // -------------------------------------------------------------------------
  it("does NOT call writeExpenseActivity on the stale-event-drop branch", async () => {
    const eightDaysAgo = new Date(
      Date.now() - 8 * 24 * 60 * 60 * 1000,
    ).toISOString();
    const db = createMockDb({
      contextExists: true,
      contextData: {memberIds: ["userA", "userB"]},
      expenses: [{id: "eid", data: validExpenseData()}],
    });
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await handler(
      makeEvent({
        changeType: "create",
        eventTime: eightDaysAgo,
        afterData: validExpenseData(),
      }),
    );

    expect(mockedWriteExpenseActivity).not.toHaveBeenCalled();
  });

  // -------------------------------------------------------------------------
  // FR-EX-07 AC-5: CONTEXT_NOT_FOUND branch does NOT invoke writeExpenseActivity.
  // -------------------------------------------------------------------------
  it("does NOT call writeExpenseActivity on the CONTEXT_NOT_FOUND branch", async () => {
    const db = createMockDb({contextExists: false});
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await handler(
      makeEvent({changeType: "create", afterData: validExpenseData()}),
    );

    expect(mockedWriteExpenseActivity).not.toHaveBeenCalled();
  });

  // -------------------------------------------------------------------------
  // FR-EX-07 AC-5: BALANCE_INVARIANT_VIOLATED branch (handler throws) does
  // NOT invoke writeExpenseActivity.
  // -------------------------------------------------------------------------
  it("does NOT call writeExpenseActivity on the BALANCE_INVARIANT_VIOLATED branch", async () => {
    const db = createMockDb({
      contextExists: true,
      contextData: {memberIds: ["userA", "userB"]},
      expenses: [
        {
          id: "eid",
          data: {
            payerId: "userA",
            amountPaise: 10000,
            deleted: false,
            splits: [
              {userId: "userA", sharePaise: 4000},
              {userId: "userB", sharePaise: 3000},
            ],
          },
        },
      ],
    });
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await expect(
      handler(
        makeEvent({changeType: "create", afterData: validExpenseData()}),
      ),
    ).rejects.toThrow();

    expect(mockedWriteExpenseActivity).not.toHaveBeenCalled();
  });

  // -------------------------------------------------------------------------
  // Activity-emission failure is CONTAINED — trigger's success branch is
  // preserved. The writer mock is configured to throw; the trigger must
  // STILL log simplified_debts_compute_completed (not _failed) and must
  // NOT throw.
  // -------------------------------------------------------------------------
  it("contains activity-emission failures — trigger does not throw if writeExpenseActivity throws", async () => {
    mockedWriteExpenseActivity.mockRejectedValueOnce(
      new Error("simulated programmer error in payload validator"),
    );

    const db = createMockDb({
      contextExists: true,
      contextData: {memberIds: ["userA", "userB"]},
      expenses: [{id: "eid", data: validExpenseData()}],
    });
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await expect(
      handler(
        makeEvent({changeType: "create", afterData: validExpenseData()}),
      ),
    ).resolves.toBeUndefined();

    // The recompute success branch still logs as completed.
    const completedLog = logger.calls.find(
      (c) => c.data?.event === "simplified_debts_compute_completed",
    );
    expect(completedLog).toBeDefined();

    // The activity-emission internal error is logged but does NOT bubble.
    const internalErrorLog = logger.calls.find(
      (c) => c.data?.event === "activity_emission_internal_error",
    );
    expect(internalErrorLog).toBeDefined();
    expect(internalErrorLog!.level).toBe("error");
  });
});
