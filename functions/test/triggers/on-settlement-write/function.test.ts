/**
 * Function-boundary tests for the onSettlementWrite trigger.
 *
 * These tests exercise `createTriggerHandler(deps)` directly with mocked
 * Firestore + logger — no emulator required. The trigger handler is the
 * thin orchestration layer wrapping the shared `recomputeAndWrite` core
 * (extended in this story to read settlements alongside expenses); this
 * suite asserts the trigger-specific concerns: discriminator-from-doc-data
 * extraction (after-side on create/update; before-side on hard delete),
 * stale-event guard, `lastActivityAt` monotonicity, error-policy mapping,
 * structured telemetry, and PII-free logging.
 *
 * Coverage target per the per-module gate: >= 70% of
 * functions/src/triggers/on-settlement-write/.
 *
 * @module test/triggers/on-settlement-write/function.test.ts
 */

import {Timestamp} from "firebase-admin/firestore";
import type {Change, DocumentSnapshot, FirestoreEvent} from
  "firebase-functions/v2/firestore";
import {createTriggerHandler} from
  "../../../src/triggers/on-settlement-write/function";
import {writeExpenseActivity} from
  "../../../src/triggers/on-expense-write/activity-writer";
import type {NotificationsApi} from "../../../src/notifications";

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
// FR-AC-03 notifications API mock helper
// ---------------------------------------------------------------------------

/**
 * Builds a mocked `NotificationsApi` suitable for injection into the
 * trigger's `Dependencies.notificationsApi` slot. The default mock is a
 * no-op that resolves successfully; tests can override the per-method
 * implementation to assert call shape or simulate failures.
 */
function createMockNotificationsApi(): NotificationsApi & {
  sendExpenseNotification: jest.Mock;
  sendSettlementNotification: jest.Mock;
  sendReminderNotification: jest.Mock;
} {
  return {
    sendExpenseNotification: jest.fn().mockResolvedValue(undefined),
    sendSettlementNotification: jest.fn().mockResolvedValue(undefined),
    sendReminderNotification: jest.fn().mockResolvedValue(undefined),
  };
}

function createMockMessaging():
  import("firebase-admin/messaging").Messaging {
  return {} as unknown as import("firebase-admin/messaging").Messaging;
}

// ---------------------------------------------------------------------------
// Mock helpers — copy the function.test.ts pattern with the settlements
// extension (FR-SE-05/06). The mock dispatches by collection name:
//   - 'friendships' / 'groups' → context doc + expenses subcollection.
//   - 'settlements' → top-level settlements query.
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

function createMockDb(opts: {
  contextExists: boolean;
  contextData?: Record<string, unknown>;
  expenses?: Array<{id: string; data: Record<string, unknown>}>;
  settlements?: Array<{id: string; data: Record<string, unknown>}>;
  /**
   * Optional user-doc seed for the FR-AC-03 sender lookup. When set,
   * any read of `users/{any}` returns this data. Used by the
   * emitSettlementFcm helper to resolve `senderName` from
   * `users/{fromUserId}.displayName`.
   */
  authorDoc?: Record<string, unknown>;
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
      if (name === "users") {
        // FR-AC-03: emitSettlementFcm reads users/{fromUserId} for the
        // sender's displayName, and the inner notifications dispatcher
        // reads users/{toUserId} for fcmTokens + notificationPrefs.
        return {
          doc: jest.fn().mockReturnValue({
            get: jest.fn().mockResolvedValue({
              exists: opts.authorDoc !== undefined,
              data: () => opts.authorDoc ?? {},
            }),
          }),
        };
      }
      return {
        doc: jest.fn().mockReturnValue({
          collection: jest.fn().mockReturnValue({
            where: jest.fn().mockReturnValue(expensesQuery),
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
 * Settlement document data — a typed shape that the trigger reads from
 * `change.after.data()` (create/update) or `change.before.data()` (hard
 * delete) to extract `contextType` and `contextId`.
 */
function validSettlementData(overrides: Record<string, unknown> = {}) {
  return {
    fromUserId: "userA",
    toUserId: "userB",
    amountPaise: 5000,
    contextType: "friendship",
    contextId: "fid",
    date: Timestamp.now(),
    note: null,
    method: "manual",
    verificationStatus: "unverified",
    currency: "INR",
    createdAt: Timestamp.now(),
    deleted: false,
    ...overrides,
  };
}

/**
 * Builds a minimal FirestoreEvent for a top-level settlement write. Unlike
 * the expense trigger event (which carries `friendshipId` + `expenseId` in
 * event.params), the settlement trigger only carries `settlementId`. The
 * context discriminator (`contextType`, `contextId`) is read from the doc
 * data instead.
 */
function makeEvent(opts: {
  changeType: "create" | "update" | "delete";
  settlementId?: string;
  eventTime?: string;
  beforeData?: Record<string, unknown>;
  afterData?: Record<string, unknown>;
}): FirestoreEvent<
  Change<DocumentSnapshot> | undefined,
  {settlementId: string}
> {
  const settlementId = opts.settlementId ?? "sid";
  const eventTime = opts.eventTime ?? new Date().toISOString();

  const beforeExists =
    opts.changeType === "update" || opts.changeType === "delete";
  const afterExists =
    opts.changeType === "create" || opts.changeType === "update";

  const beforeSnap = {
    exists: beforeExists,
    data: () => opts.beforeData ?? {},
    ref: {path: `settlements/${settlementId}`},
  } as unknown as DocumentSnapshot;

  const afterSnap = {
    exists: afterExists,
    data: () => opts.afterData ?? {},
    ref: {path: `settlements/${settlementId}`},
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
    document: `settlements/${settlementId}`,
    params: {settlementId},
    data: change,
    location: "asia-south1",
    project: "demo-onebytwo",
    database: "(default)",
    namespace: "(default)",
  } as unknown as FirestoreEvent<
    Change<DocumentSnapshot> | undefined,
    {settlementId: string}
  >;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("onSettlementWrite handler — boundary", () => {
  // -------------------------------------------------------------------------
  // 1. CREATE event recomputes balances and writes lastActivityAt
  //
  // A settlement of {fromA: 5000, toB: 5000} on a context with one expense
  // (A paid 10000 split equally — B owes A 5000) → settlement zeroes the
  // debt → simplifiedBalances = {}.
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
      expenses: [
        {
          id: "exp1",
          data: {
            payerId: "userA",
            amountPaise: 10000,
            deleted: false,
            splits: [
              {userId: "userA", sharePaise: 5000},
              {userId: "userB", sharePaise: 5000},
            ],
          },
        },
      ],
      settlements: [
        {id: "sid", data: validSettlementData({fromUserId: "userB", toUserId: "userA", amountPaise: 5000})},
      ],
    });
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await handler(
      makeEvent({
        changeType: "create",
        eventTime,
        afterData: validSettlementData({
          fromUserId: "userB",
          toUserId: "userA",
          amountPaise: 5000,
        }),
      }),
    );

    const updateFn = (db as unknown as {_updateFn: jest.Mock})._updateFn;
    expect(updateFn).toHaveBeenCalledTimes(1);
    const [, payload] = updateFn.mock.calls[0];
    expect(payload).toEqual({
      simplifiedBalances: {},
      lastActivityAt: expectedTimestamp,
    });
  });

  // -------------------------------------------------------------------------
  // 2. UPDATE event reads contextType/contextId from the after-side
  //
  // No prior expenses. A settlement of {fromA: 7000, toB: 7000} means A
  // paid B 7000 in cash. With no prior debt, A now has positive net
  // (+7000) — A is the creditor; B owes A 7000 ⇒ {userB: {userA: 7000}}.
  // -------------------------------------------------------------------------
  it("extracts contextType/contextId from change.after on update", async () => {
    const db = createMockDb({
      contextExists: true,
      contextData: {memberIds: ["userA", "userB"]},
      expenses: [],
      settlements: [
        {id: "sid", data: validSettlementData({amountPaise: 7000})},
      ],
    });
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await handler(
      makeEvent({
        changeType: "update",
        beforeData: validSettlementData({amountPaise: 5000}),
        afterData: validSettlementData({amountPaise: 7000}),
      }),
    );

    const updateFn = (db as unknown as {_updateFn: jest.Mock})._updateFn;
    expect(updateFn).toHaveBeenCalledTimes(1);
    expect(updateFn.mock.calls[0][1].simplifiedBalances).toEqual({
      userB: {userA: 7000},
    });
    // db.collection('friendships').doc('fid') should have been resolved
    // from the doc data's {contextType: 'friendship', contextId: 'fid'}.
    expect(
      (db as unknown as {collection: jest.Mock}).collection,
    ).toHaveBeenCalledWith("friendships");
  });

  // -------------------------------------------------------------------------
  // 3. SOFT-DELETE: the soft-deleted settlement is filtered out of the
  //    in-code soft-delete filter, so balances reflect the state WITHOUT
  //    the settlement.
  // -------------------------------------------------------------------------
  it("recomputes on soft-delete (deleted=true settlement is filtered in-code)", async () => {
    const db = createMockDb({
      contextExists: true,
      contextData: {memberIds: ["userA", "userB"]},
      expenses: [
        {
          id: "exp1",
          data: {
            payerId: "userA",
            amountPaise: 10000,
            deleted: false,
            splits: [
              {userId: "userA", sharePaise: 5000},
              {userId: "userB", sharePaise: 5000},
            ],
          },
        },
      ],
      // Settlement marked deleted=true — algorithm should ignore it.
      settlements: [
        {
          id: "sid",
          data: validSettlementData({
            fromUserId: "userB",
            toUserId: "userA",
            amountPaise: 5000,
            deleted: true,
          }),
        },
      ],
    });
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await handler(
      makeEvent({
        changeType: "update",
        beforeData: validSettlementData({deleted: false}),
        afterData: validSettlementData({deleted: true}),
      }),
    );

    const updateFn = (db as unknown as {_updateFn: jest.Mock})._updateFn;
    expect(updateFn).toHaveBeenCalledTimes(1);
    // Settlement excluded → residual debt remains.
    expect(updateFn.mock.calls[0][1].simplifiedBalances).toEqual({
      userB: {userA: 5000},
    });
  });

  // -------------------------------------------------------------------------
  // 4. HARD-DELETE: change.after.exists === false; discriminator must come
  //    from change.before.data().
  // -------------------------------------------------------------------------
  it("extracts contextType/contextId from change.before on hard delete", async () => {
    const db = createMockDb({
      contextExists: true,
      contextData: {memberIds: ["userA", "userB"]},
      expenses: [],
      settlements: [],
    });
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await handler(
      makeEvent({
        changeType: "delete",
        beforeData: validSettlementData(),
      }),
    );

    const updateFn = (db as unknown as {_updateFn: jest.Mock})._updateFn;
    expect(updateFn).toHaveBeenCalledTimes(1);
    // No expenses, no settlements ⇒ empty balances.
    expect(updateFn.mock.calls[0][1].simplifiedBalances).toEqual({});
    expect(
      (db as unknown as {collection: jest.Mock}).collection,
    ).toHaveBeenCalledWith("friendships");
  });

  // -------------------------------------------------------------------------
  // 5. Idempotency: second invocation with the same event produces identical
  //    simplifiedBalances.
  // -------------------------------------------------------------------------
  it("is idempotent: identical second invocation yields identical balances", async () => {
    const eventTime = new Date(Date.now() - 30 * 1000).toISOString();
    const db = createMockDb({
      contextExists: true,
      contextData: {memberIds: ["userA", "userB"]},
      expenses: [],
      settlements: [
        {id: "sid", data: validSettlementData()},
      ],
    });
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await handler(makeEvent({changeType: "create", eventTime, afterData: validSettlementData()}));
    await handler(makeEvent({changeType: "create", eventTime, afterData: validSettlementData()}));

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
      expenses: [],
      settlements: [{id: "sid", data: validSettlementData()}],
    });
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await handler(
      makeEvent({
        changeType: "create",
        eventTime: eightDaysAgo,
        afterData: validSettlementData(),
      }),
    );

    const updateFn = (db as unknown as {_updateFn: jest.Mock})._updateFn;
    expect(updateFn).not.toHaveBeenCalled();

    const droppedLog = logger.calls.find(
      (c) => c.data?.event === "settlement_trigger_stale_event_dropped",
    );
    expect(droppedLog).toBeDefined();
    expect(droppedLog!.data!.contextType).toBe("friendship");
    expect(typeof droppedLog!.data!.contextIdHash).toBe("string");
    expect(droppedLog!.data!.contextIdHash).toMatch(/^[0-9a-f]{16}$/);
    expect(typeof droppedLog!.data!.settlementIdHash).toBe("string");
    expect(typeof droppedLog!.data!.ageMs).toBe("number");
  });

  // -------------------------------------------------------------------------
  // 7. CONTEXT_NOT_FOUND: friendship doc deleted → log and return, no throw
  // -------------------------------------------------------------------------
  it("logs CONTEXT_NOT_FOUND and returns successfully (no throw, no retry)", async () => {
    const db = createMockDb({
      contextExists: false,
      settlements: [],
    });
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await expect(
      handler(makeEvent({changeType: "create", afterData: validSettlementData()})),
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
  // 8. BALANCE_INVARIANT_VIOLATED: trigger logs AND throws so CF retries.
  //
  // Construct an expense where sharePaise sum != amountPaise.
  // -------------------------------------------------------------------------
  it("logs BALANCE_INVARIANT_VIOLATED and throws so Cloud Functions retries", async () => {
    const db = createMockDb({
      contextExists: true,
      contextData: {memberIds: ["userA", "userB"]},
      expenses: [
        {
          id: "exp1",
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
      settlements: [],
    });
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await expect(
      handler(makeEvent({changeType: "create", afterData: validSettlementData()})),
    ).rejects.toThrow();

    const failedLog = logger.calls.find(
      (c) => c.data?.event === "simplified_debts_compute_failed",
    );
    expect(failedLog).toBeDefined();
    expect(failedLog!.data!.errorCode).toBe("BALANCE_INVARIANT_VIOLATED");
    expect(failedLog!.level).toBe("error");
  });

  // -------------------------------------------------------------------------
  // 9. PII guard: structured logger NEVER receives fromUserId, toUserId,
  //    amountPaise, note, OR the raw composite friendship contextId. Only
  //    hashed identifiers are loggable.
  // -------------------------------------------------------------------------
  it("never logs PII (raw UIDs in contextId, fromUserId/toUserId, amounts, note)", async () => {
    const uidAlice = "pii-uid-alice";
    const uidBob = "pii-uid-bob";
    const realisticFriendshipId = `${uidAlice}_${uidBob}`;
    const realisticSettlementId = "pii-settlement-secret-id";

    const db = createMockDb({
      contextExists: true,
      contextData: {memberIds: [uidAlice, uidBob]},
      expenses: [],
      settlements: [
        {
          id: realisticSettlementId,
          data: {
            fromUserId: uidAlice,
            toUserId: uidBob,
            amountPaise: 987654,
            contextType: "friendship",
            contextId: realisticFriendshipId,
            note: "PII-secret-note",
            deleted: false,
          },
        },
      ],
    });
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await handler(
      makeEvent({
        changeType: "create",
        settlementId: realisticSettlementId,
        afterData: {
          fromUserId: uidAlice,
          toUserId: uidBob,
          amountPaise: 987654,
          contextType: "friendship",
          contextId: realisticFriendshipId,
          note: "PII-secret-note",
          deleted: false,
        },
      }),
    );

    for (const call of logger.calls) {
      const serialised = JSON.stringify(call.data);
      // Raw UIDs (from contextId, fromUserId, toUserId)
      expect(serialised).not.toContain(uidAlice);
      expect(serialised).not.toContain(uidBob);
      // The raw composite friendship contextId
      expect(serialised).not.toContain(realisticFriendshipId);
      // Raw settlementId
      expect(serialised).not.toContain(realisticSettlementId);
      // Monetary value
      expect(serialised).not.toContain("987654");
      // Note text
      expect(serialised).not.toContain("PII-secret-note");
    }

    // Affirmative check: hashed contextIdHash is present (production
    // ops still get correlation IDs).
    for (const call of logger.calls) {
      const data = call.data ?? {};
      if ("contextIdHash" in data) {
        expect((data as Record<string, unknown>).contextIdHash).toMatch(
          /^[0-9a-f]{16}$/,
        );
      }
      if ("settlementIdHash" in data) {
        expect((data as Record<string, unknown>).settlementIdHash).toMatch(
          /^[0-9a-f]{16}$/,
        );
      }
    }
  });

  // -------------------------------------------------------------------------
  // 10. settlement_trigger_fired is the FIRST log call (top of handler)
  // -------------------------------------------------------------------------
  it("emits settlement_trigger_fired as the first log call with hashed IDs", async () => {
    const db = createMockDb({
      contextExists: true,
      contextData: {memberIds: ["userA", "userB"]},
      expenses: [],
      settlements: [{id: "sid", data: validSettlementData()}],
    });
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await handler(makeEvent({changeType: "create", afterData: validSettlementData()}));

    expect(logger.calls.length).toBeGreaterThan(0);
    expect(logger.calls[0].data?.event).toBe("settlement_trigger_fired");
    expect(logger.calls[0].data?.contextType).toBe("friendship");
    expect(logger.calls[0].data?.contextIdHash).toMatch(/^[0-9a-f]{16}$/);
    expect(logger.calls[0].data?.settlementIdHash).toMatch(/^[0-9a-f]{16}$/);
    expect(logger.calls[0].data?.changeType).toBe("create");
    expect(typeof logger.calls[0].data?.eventTime).toBe("string");
    // Raw IDs MUST NOT appear in the fired log.
    expect(logger.calls[0].data).not.toHaveProperty("contextId");
    expect(logger.calls[0].data).not.toHaveProperty("settlementId");
  });

  // -------------------------------------------------------------------------
  // 11. lastActivityAt monotonicity: older event does NOT regress existing
  // -------------------------------------------------------------------------
  it("does not regress lastActivityAt when an older event arrives", async () => {
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
      expenses: [],
      settlements: [{id: "sid", data: validSettlementData()}],
    });
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await handler(
      makeEvent({
        changeType: "create",
        eventTime: olderEventTime,
        afterData: validSettlementData(),
      }),
    );

    const updateFn = (db as unknown as {_updateFn: jest.Mock})._updateFn;
    expect(updateFn).toHaveBeenCalledTimes(1);
    expect(updateFn.mock.calls[0][1].lastActivityAt).toEqual(
      existingNewerTimestamp,
    );
  });

  // -------------------------------------------------------------------------
  // 12. lastActivityAt updated when newer than existing
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
      expenses: [],
      settlements: [{id: "sid", data: validSettlementData()}],
    });
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await handler(
      makeEvent({
        changeType: "create",
        eventTime: newerEventTime,
        afterData: validSettlementData(),
      }),
    );

    const updateFn = (db as unknown as {_updateFn: jest.Mock})._updateFn;
    expect(updateFn).toHaveBeenCalledTimes(1);
    expect(updateFn.mock.calls[0][1].lastActivityAt).toEqual(newerTimestamp);
  });

  // -------------------------------------------------------------------------
  // 13. lastActivityAt set when existing is missing
  // -------------------------------------------------------------------------
  it("writes lastActivityAt when the existing value is missing", async () => {
    const eventTime = new Date(Date.now() - 60 * 1000).toISOString();
    const expectedTimestamp = Timestamp.fromDate(new Date(eventTime));
    const db = createMockDb({
      contextExists: true,
      contextData: {memberIds: ["userA", "userB"]},
      expenses: [],
      settlements: [{id: "sid", data: validSettlementData()}],
    });
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await handler(
      makeEvent({
        changeType: "create",
        eventTime,
        afterData: validSettlementData(),
      }),
    );

    const updateFn = (db as unknown as {_updateFn: jest.Mock})._updateFn;
    expect(updateFn).toHaveBeenCalledTimes(1);
    expect(updateFn.mock.calls[0][1].lastActivityAt).toEqual(expectedTimestamp);
  });

  // -------------------------------------------------------------------------
  // 14. Group context discriminator: trigger reads contextType='group' from
  //     doc data and resolves to the 'groups' collection.
  // -------------------------------------------------------------------------
  it("resolves to 'groups' collection when contextType is 'group'", async () => {
    const db = createMockDb({
      contextExists: true,
      contextData: {memberIds: ["userA", "userB", "userC"]},
      expenses: [],
      settlements: [
        {
          id: "sid",
          data: validSettlementData({
            contextType: "group",
            contextId: "gid",
          }),
        },
      ],
    });
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await handler(
      makeEvent({
        changeType: "create",
        afterData: validSettlementData({
          contextType: "group",
          contextId: "gid",
        }),
      }),
    );

    expect(
      (db as unknown as {collection: jest.Mock}).collection,
    ).toHaveBeenCalledWith("groups");
  });
});

// ---------------------------------------------------------------------------
// FR-AC-01: trigger ↔ activity-writer contract
// ---------------------------------------------------------------------------

describe("onSettlementWrite handler — FR-AC-01 activity-writer integration", () => {
  // -------------------------------------------------------------------------
  // FR-AC-01 AC-10: create event invokes writeExpenseActivity with
  // 'settlement' eventType targeting BOTH parties (fromUserId, toUserId).
  // -------------------------------------------------------------------------
  it("calls writeExpenseActivity with 'settlement' on create — both parties targeted", async () => {
    const db = createMockDb({
      contextExists: true,
      contextData: {memberIds: ["userA", "userB"]},
      expenses: [],
      settlements: [{id: "sid", data: validSettlementData()}],
    });
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await handler(
      makeEvent({changeType: "create", afterData: validSettlementData()}),
    );

    expect(mockedWriteExpenseActivity).toHaveBeenCalledTimes(1);
    const [, callRequest] = mockedWriteExpenseActivity.mock.calls[0];
    expect(callRequest.eventType).toBe("settlement");
    // Note: the activity-writer's WriteExpenseActivityRequest interface
    // pre-dates the settlement consumer; the field names friendshipId
    // and expenseId are misnomers when the source entity is a
    // settlement (the rename to writeContextActivity + contextId +
    // entityId is deferred per architect §2.3). The call site passes
    // contextId via friendshipId and settlementId via expenseId.
    expect(callRequest.friendshipId).toBe("fid");
    expect(callRequest.expenseId).toBe("sid");
    // memberIds resolves to [fromUserId, toUserId] per FR-AC-01 AC-10
    // — the settlement-trigger does NOT re-read the parent friendship
    // doc; both UIDs are already present on the settlement document
    // (rules at firestore.rules:445-455 require them).
    expect(callRequest.memberIds).toEqual(["userA", "userB"]);
    // Payload includes the FR-AC-01 §2.4 settlement schema.
    expect(callRequest.payload).toMatchObject({
      settlementId: "sid",
      fromUserId: "userA",
      toUserId: "userB",
      amountPaise: 5000,
      contextType: "friendship",
      contextId: "fid",
      authorUid: "userA",
    });
  });

  // -------------------------------------------------------------------------
  // FR-AC-01 AC-11: soft-delete (update with deleted: false -> true)
  // does NOT invoke writeExpenseActivity. v1.0 decision per architect §2.2.
  // -------------------------------------------------------------------------
  it("does NOT call writeExpenseActivity on soft-delete (AC-11)", async () => {
    const db = createMockDb({
      contextExists: true,
      contextData: {memberIds: ["userA", "userB"]},
      expenses: [],
      settlements: [
        {id: "sid", data: validSettlementData({deleted: true})},
      ],
    });
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await handler(
      makeEvent({
        changeType: "update",
        beforeData: validSettlementData({deleted: false}),
        afterData: validSettlementData({deleted: true}),
      }),
    );

    expect(mockedWriteExpenseActivity).not.toHaveBeenCalled();
  });

  // -------------------------------------------------------------------------
  // FR-AC-01 AC-12: stale-event drop branch does NOT invoke
  // writeExpenseActivity.
  // -------------------------------------------------------------------------
  it("does NOT call writeExpenseActivity on the stale-event-drop branch", async () => {
    const eightDaysAgo = new Date(
      Date.now() - 8 * 24 * 60 * 60 * 1000,
    ).toISOString();
    const db = createMockDb({
      contextExists: true,
      contextData: {memberIds: ["userA", "userB"]},
      expenses: [],
      settlements: [{id: "sid", data: validSettlementData()}],
    });
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await handler(
      makeEvent({
        changeType: "create",
        eventTime: eightDaysAgo,
        afterData: validSettlementData(),
      }),
    );

    expect(mockedWriteExpenseActivity).not.toHaveBeenCalled();
  });

  // -------------------------------------------------------------------------
  // FR-AC-01 AC-12: CONTEXT_NOT_FOUND branch does NOT invoke
  // writeExpenseActivity.
  // -------------------------------------------------------------------------
  it("does NOT call writeExpenseActivity on the CONTEXT_NOT_FOUND branch", async () => {
    const db = createMockDb({contextExists: false, settlements: []});
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await handler(
      makeEvent({changeType: "create", afterData: validSettlementData()}),
    );

    expect(mockedWriteExpenseActivity).not.toHaveBeenCalled();
  });

  // -------------------------------------------------------------------------
  // FR-AC-01 AC-12: BALANCE_INVARIANT_VIOLATED branch (trigger throws
  // for retry) does NOT invoke writeExpenseActivity.
  // -------------------------------------------------------------------------
  it("does NOT call writeExpenseActivity on the BALANCE_INVARIANT_VIOLATED branch", async () => {
    const db = createMockDb({
      contextExists: true,
      contextData: {memberIds: ["userA", "userB"]},
      expenses: [
        {
          id: "exp1",
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
      settlements: [],
    });
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await expect(
      handler(
        makeEvent({changeType: "create", afterData: validSettlementData()}),
      ),
    ).rejects.toThrow();

    expect(mockedWriteExpenseActivity).not.toHaveBeenCalled();
  });

  // -------------------------------------------------------------------------
  // FR-AC-01 AC-12 error containment: when writeExpenseActivity itself
  // throws (programmer error like a malformed payload caught by the
  // validator), the trigger must STILL log
  // simplified_debts_compute_completed and must NOT throw.
  // -------------------------------------------------------------------------
  it("contains activity-emission failures — trigger does not throw if writeExpenseActivity throws", async () => {
    mockedWriteExpenseActivity.mockRejectedValueOnce(
      new Error("simulated programmer error in payload validator"),
    );

    const db = createMockDb({
      contextExists: true,
      contextData: {memberIds: ["userA", "userB"]},
      expenses: [],
      settlements: [{id: "sid", data: validSettlementData()}],
    });
    const logger = createMockLogger();

    const handler = createTriggerHandler({db, logger});
    await expect(
      handler(
        makeEvent({changeType: "create", afterData: validSettlementData()}),
      ),
    ).resolves.toBeUndefined();

    const completedLog = logger.calls.find(
      (c) => c.data?.event === "simplified_debts_compute_completed",
    );
    expect(completedLog).toBeDefined();

    const internalErrorLog = logger.calls.find(
      (c) => c.data?.event === "activity_emission_internal_error",
    );
    expect(internalErrorLog).toBeDefined();
    expect(internalErrorLog!.level).toBe("error");
  });
});

// ---------------------------------------------------------------------------
// FR-AC-03: trigger ↔ FCM dispatcher contract
// ---------------------------------------------------------------------------

describe("onSettlementWrite handler — FR-AC-03 FCM emission", () => {
  // -------------------------------------------------------------------------
  // FR-AC-03 AC-5: create event invokes sendSettlementNotification with
  // recipient = toUserId.
  // -------------------------------------------------------------------------
  it("calls sendSettlementNotification on create with toUserId only + senderName resolved", async () => {
    const db = createMockDb({
      contextExists: true,
      contextData: {memberIds: ["userA", "userB"]},
      expenses: [],
      settlements: [{id: "sid", data: validSettlementData()}],
      authorDoc: {displayName: "Priya"},
    });
    const notificationsApi = createMockNotificationsApi();
    const logger = createMockLogger();

    const handler = createTriggerHandler({
      db,
      logger,
      notificationsApi,
      messaging: createMockMessaging(),
    });
    await handler(
      makeEvent({changeType: "create", afterData: validSettlementData()}),
    );

    expect(notificationsApi.sendSettlementNotification).toHaveBeenCalledTimes(
      1,
    );
    const [, callParams] =
      notificationsApi.sendSettlementNotification.mock.calls[0];
    expect(callParams.fromUserId).toBe("userA");
    expect(callParams.toUserId).toBe("userB");
    expect(callParams.contextType).toBe("friendship");
    expect(callParams.contextId).toBe("fid");
    expect(callParams.settlementId).toBe("sid");
    expect(callParams.amountPaise).toBe(5000);
    expect(callParams.senderName).toBe("Priya");
  });

  // -------------------------------------------------------------------------
  // FR-AC-03 AC-18: stale-event drop branch does NOT invoke
  // sendSettlementNotification.
  // -------------------------------------------------------------------------
  it("does NOT call sendSettlementNotification on the stale-event-drop branch", async () => {
    const eightDaysAgo = new Date(
      Date.now() - 8 * 24 * 60 * 60 * 1000,
    ).toISOString();
    const db = createMockDb({
      contextExists: true,
      contextData: {memberIds: ["userA", "userB"]},
      expenses: [],
      settlements: [{id: "sid", data: validSettlementData()}],
    });
    const notificationsApi = createMockNotificationsApi();
    const logger = createMockLogger();

    const handler = createTriggerHandler({
      db,
      logger,
      notificationsApi,
      messaging: createMockMessaging(),
    });
    await handler(
      makeEvent({
        changeType: "create",
        eventTime: eightDaysAgo,
        afterData: validSettlementData(),
      }),
    );

    expect(notificationsApi.sendSettlementNotification).not.toHaveBeenCalled();
  });

  // -------------------------------------------------------------------------
  // FR-AC-03 AC-18: CONTEXT_NOT_FOUND branch does NOT invoke
  // sendSettlementNotification.
  // -------------------------------------------------------------------------
  it("does NOT call sendSettlementNotification on the CONTEXT_NOT_FOUND branch", async () => {
    const db = createMockDb({contextExists: false, settlements: []});
    const notificationsApi = createMockNotificationsApi();
    const logger = createMockLogger();

    const handler = createTriggerHandler({
      db,
      logger,
      notificationsApi,
      messaging: createMockMessaging(),
    });
    await handler(
      makeEvent({changeType: "create", afterData: validSettlementData()}),
    );

    expect(notificationsApi.sendSettlementNotification).not.toHaveBeenCalled();
  });

  // -------------------------------------------------------------------------
  // FR-AC-03 AC-18: BALANCE_INVARIANT_VIOLATED branch (trigger throws
  // for retry) does NOT invoke sendSettlementNotification.
  // -------------------------------------------------------------------------
  it("does NOT call sendSettlementNotification on the BALANCE_INVARIANT_VIOLATED branch", async () => {
    const db = createMockDb({
      contextExists: true,
      contextData: {memberIds: ["userA", "userB"]},
      expenses: [
        {
          id: "exp1",
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
      settlements: [],
    });
    const notificationsApi = createMockNotificationsApi();
    const logger = createMockLogger();

    const handler = createTriggerHandler({
      db,
      logger,
      notificationsApi,
      messaging: createMockMessaging(),
    });
    await expect(
      handler(
        makeEvent({changeType: "create", afterData: validSettlementData()}),
      ),
    ).rejects.toThrow();

    expect(notificationsApi.sendSettlementNotification).not.toHaveBeenCalled();
  });

  // -------------------------------------------------------------------------
  // FR-AC-03 AC-17: FCM emission failure is CONTAINED — trigger's success
  // branch is preserved.
  // -------------------------------------------------------------------------
  it("contains FCM emission failures — trigger does not throw if sendSettlementNotification throws", async () => {
    const notificationsApi = createMockNotificationsApi();
    notificationsApi.sendSettlementNotification.mockRejectedValueOnce(
      new Error("simulated FCM internal error"),
    );

    const db = createMockDb({
      contextExists: true,
      contextData: {memberIds: ["userA", "userB"]},
      expenses: [],
      settlements: [{id: "sid", data: validSettlementData()}],
      authorDoc: {displayName: "Priya"},
    });
    const logger = createMockLogger();

    const handler = createTriggerHandler({
      db,
      logger,
      notificationsApi,
      messaging: createMockMessaging(),
    });
    await expect(
      handler(
        makeEvent({changeType: "create", afterData: validSettlementData()}),
      ),
    ).resolves.toBeUndefined();

    const completedLog = logger.calls.find(
      (c) => c.data?.event === "simplified_debts_compute_completed",
    );
    expect(completedLog).toBeDefined();

    const fcmErrorLog = logger.calls.find(
      (c) => c.data?.event === "fcm_emission_internal_error",
    );
    expect(fcmErrorLog).toBeDefined();
    expect(fcmErrorLog!.level).toBe("error");
    expect(fcmErrorLog!.data!.contextIdHash).toMatch(/^[0-9a-f]{16}$/);
  });

  // -------------------------------------------------------------------------
  // Architect §2.10 item 7: when notificationsApi is absent from deps
  // (existing tests, partial wiring), the emitter no-ops silently.
  // -------------------------------------------------------------------------
  it("no-ops silently when notificationsApi is undefined (backward-compat)", async () => {
    const db = createMockDb({
      contextExists: true,
      contextData: {memberIds: ["userA", "userB"]},
      expenses: [],
      settlements: [{id: "sid", data: validSettlementData()}],
    });
    const logger = createMockLogger();

    // No notificationsApi in deps — existing tests' contract preserved.
    const handler = createTriggerHandler({db, logger});
    await expect(
      handler(
        makeEvent({changeType: "create", afterData: validSettlementData()}),
      ),
    ).resolves.toBeUndefined();

    const completedLog = logger.calls.find(
      (c) => c.data?.event === "simplified_debts_compute_completed",
    );
    expect(completedLog).toBeDefined();
    const fcmErrorLog = logger.calls.find(
      (c) => c.data?.event === "fcm_emission_internal_error",
    );
    expect(fcmErrorLog).toBeUndefined();
  });
});
