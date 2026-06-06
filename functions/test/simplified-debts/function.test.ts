/**
 * Function-boundary tests for recomputeSimplifiedBalances.
 *
 * Uses dependency injection (mock Firestore and logger) — no emulator needed.
 */

import {HttpsError} from "firebase-functions/v2/https";
import {createHandler, Dependencies} from "../../src/simplified-debts/function";

// ---------------------------------------------------------------------------
// Mock helpers
// ---------------------------------------------------------------------------

/** Creates a mock logger that records all calls. */
function createMockLogger() {
  const calls: Array<{level: string; message: string; data?: Record<string, unknown>}> = [];
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

/**
 * Creates a minimal mock Firestore that returns the provided context document
 * and expense documents inside a transaction.
 *
 * FR-SE-05/06 extension: also returns settlement documents from the top-level
 * `settlements` collection. The mock dispatches by the FIRST argument to
 * `db.collection()`:
 *   - `'friendships'` / `'groups'` → context doc + expenses subcollection
 *     (existing chain — `tx.get(docRef)` for context, `tx.get(query)` for
 *     expenses where the query carries `_queryKind: 'expenses'`).
 *   - `'settlements'` → top-level settlements query
 *     (`tx.get(query)` where the query carries `_queryKind: 'settlements'`).
 *
 * If `settlements` is omitted, the settlements query returns an empty list —
 * preserves backward compatibility with existing tests that never seeded
 * settlements.
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
    ref: {path: `mock/expenses/${e.id}`},
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
    ref: {path: "mock/context/doc"},
  };

  const updateFn = jest.fn();

  // Settlements chain: db.collection('settlements').where(...).where(...)
  const settlementsQuery = {_queryKind: "settlements"};
  const settlementsChain = {
    where: jest.fn().mockReturnValue({
      where: jest.fn().mockReturnValue(settlementsQuery),
    }),
  };

  // Friendships/groups chain: db.collection(X).doc(Y).collection('expenses').where('deleted','!=',true)
  const expensesQuery = {_queryKind: "expenses"};
  const contextChain = {
    doc: jest.fn().mockReturnValue({
      collection: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue(expensesQuery),
      }),
      _isDocRef: true,
    }),
  };

  const mockDb = {
    collection: jest.fn((name: string) => {
      if (name === "settlements") {
        return settlementsChain;
      }
      return contextChain;
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

/** Builds Dependencies from mock db and logger. */
function createDeps(
  dbOpts: Parameters<typeof createMockDb>[0],
): {deps: Dependencies; logger: ReturnType<typeof createMockLogger>; db: ReturnType<typeof createMockDb>} {
  const logger = createMockLogger();
  const db = createMockDb(dbOpts);
  return {deps: {db: db as unknown as FirebaseFirestore.Firestore, logger}, logger, db};
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("recomputeSimplifiedBalances handler", () => {
  // -----------------------------------------------------------------------
  // 1. Valid input returns expected output shape
  // -----------------------------------------------------------------------
  it("returns expected output shape for valid input with expenses", async () => {
    const {deps} = createDeps({
      contextExists: true,
      contextData: {members: ["userA", "userB"]},
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
    });

    const handler = createHandler(deps);
    const result = await handler({contextType: "friendship", contextId: "ctx1"});

    expect(result.ok).toBe(true);
    expect(Array.isArray(result.transfers)).toBe(true);
    expect(typeof result.simplifiedBalances).toBe("object");
    expect(typeof result.computedAt).toBe("string");
    // computedAt should be a valid ISO string
    expect(new Date(result.computedAt).toISOString()).toBe(result.computedAt);

    // With 10000 paid by A, split equally: A net +5000, B net -5000
    // => one transfer: B -> A for 5000
    expect(result.transfers).toEqual([
      {from: "userB", to: "userA", amountPaise: 5000},
    ]);
    expect(result.simplifiedBalances).toEqual({
      userB: {userA: 5000},
    });
  });

  // -----------------------------------------------------------------------
  // 2. Missing contextId returns INVALID_INPUT
  // -----------------------------------------------------------------------
  it("throws INVALID_INPUT when contextId is missing", async () => {
    const {deps} = createDeps({contextExists: true});
    const handler = createHandler(deps);

    try {
      await handler({contextType: "friendship"});
      fail("Expected HttpsError to be thrown");
    } catch (err) {
      expect(err).toBeInstanceOf(HttpsError);
      const httpsErr = err as HttpsError;
      expect(httpsErr.code).toBe("invalid-argument");
      expect((httpsErr.details as {errorCode: string}).errorCode).toBe(
        "INVALID_INPUT",
      );
    }
  });

  // -----------------------------------------------------------------------
  // 3. Empty contextId returns INVALID_INPUT
  // -----------------------------------------------------------------------
  it("throws INVALID_INPUT when contextId is empty string", async () => {
    const {deps} = createDeps({contextExists: true});
    const handler = createHandler(deps);

    try {
      await handler({contextType: "group", contextId: ""});
      fail("Expected HttpsError to be thrown");
    } catch (err) {
      expect(err).toBeInstanceOf(HttpsError);
      const httpsErr = err as HttpsError;
      expect(httpsErr.code).toBe("invalid-argument");
      expect((httpsErr.details as {errorCode: string}).errorCode).toBe(
        "INVALID_INPUT",
      );
    }
  });

  // -----------------------------------------------------------------------
  // 4. Unknown contextType returns INVALID_INPUT
  // -----------------------------------------------------------------------
  it("throws INVALID_INPUT when contextType is unknown", async () => {
    const {deps} = createDeps({contextExists: true});
    const handler = createHandler(deps);

    try {
      await handler({contextType: "team", contextId: "abc"});
      fail("Expected HttpsError to be thrown");
    } catch (err) {
      expect(err).toBeInstanceOf(HttpsError);
      const httpsErr = err as HttpsError;
      expect(httpsErr.code).toBe("invalid-argument");
      expect((httpsErr.details as {errorCode: string}).errorCode).toBe(
        "INVALID_INPUT",
      );
    }
  });

  // -----------------------------------------------------------------------
  // 5. Non-existent context returns CONTEXT_NOT_FOUND
  // -----------------------------------------------------------------------
  it("throws CONTEXT_NOT_FOUND when context document does not exist", async () => {
    const {deps} = createDeps({contextExists: false});
    const handler = createHandler(deps);

    try {
      await handler({contextType: "friendship", contextId: "nonexistent"});
      fail("Expected HttpsError to be thrown");
    } catch (err) {
      expect(err).toBeInstanceOf(HttpsError);
      const httpsErr = err as HttpsError;
      expect(httpsErr.code).toBe("not-found");
      expect((httpsErr.details as {errorCode: string}).errorCode).toBe(
        "CONTEXT_NOT_FOUND",
      );
    }
  });

  // -----------------------------------------------------------------------
  // 6. Successful invocation logs started and completed events
  // -----------------------------------------------------------------------
  it("logs started and completed events on success", async () => {
    const {deps, logger} = createDeps({
      contextExists: true,
      contextData: {},
      expenses: [
        {
          id: "exp1",
          data: {
            payerId: "userA",
            amountPaise: 6000,
            deleted: false,
            splits: [
              {userId: "userA", sharePaise: 3000},
              {userId: "userB", sharePaise: 3000},
            ],
          },
        },
      ],
    });

    const handler = createHandler(deps);
    await handler({contextType: "group", contextId: "grp1"});

    const startedLog = logger.calls.find(
      (c) => c.data?.event === "simplified_debts_compute_started",
    );
    expect(startedLog).toBeDefined();
    expect(startedLog!.level).toBe("info");
    expect(startedLog!.data!.contextType).toBe("group");
    expect(startedLog!.data!.contextId).toBe("grp1");

    const completedLog = logger.calls.find(
      (c) => c.data?.event === "simplified_debts_compute_completed",
    );
    expect(completedLog).toBeDefined();
    expect(completedLog!.level).toBe("info");
    expect(completedLog!.data!.contextType).toBe("group");
    expect(completedLog!.data!.contextId).toBe("grp1");
    expect(typeof completedLog!.data!.elapsedMs).toBe("number");
    expect(completedLog!.data!.transferCount).toBe(1);
  });

  // -----------------------------------------------------------------------
  // 7. Failed invocation logs failed event with error code, no PII
  // -----------------------------------------------------------------------
  it("logs failed event with errorCode but no userId values", async () => {
    const {deps, logger} = createDeps({contextExists: false});
    const handler = createHandler(deps);

    try {
      await handler({contextType: "friendship", contextId: "missing"});
      fail("Expected HttpsError");
    } catch {
      // expected
    }

    const failedLog = logger.calls.find(
      (c) => c.data?.event === "simplified_debts_compute_failed",
    );
    expect(failedLog).toBeDefined();
    expect(failedLog!.level).toBe("error");
    expect(failedLog!.data!.errorCode).toBe("CONTEXT_NOT_FOUND");

    // Verify no PII: no userId values in any logged data fields
    for (const call of logger.calls) {
      const serialised = JSON.stringify(call.data);
      // The only identifiers allowed are contextId and contextType
      // userId values like "userA", "userB" must never appear
      expect(serialised).not.toContain("userA");
      expect(serialised).not.toContain("userB");
    }
  });

  // -----------------------------------------------------------------------
  // Additional: empty expenses produce empty transfers
  // -----------------------------------------------------------------------
  it("returns empty transfers when there are no expenses", async () => {
    const {deps} = createDeps({
      contextExists: true,
      contextData: {},
      expenses: [],
    });

    const handler = createHandler(deps);
    const result = await handler({contextType: "friendship", contextId: "ctx2"});

    expect(result.ok).toBe(true);
    expect(result.transfers).toEqual([]);
    expect(result.simplifiedBalances).toEqual({});
  });

  // -----------------------------------------------------------------------
  // Additional: group contextType uses "groups" collection
  // -----------------------------------------------------------------------
  it("reads from 'groups' collection for group contextType", async () => {
    const {deps, db} = createDeps({
      contextExists: true,
      contextData: {},
      expenses: [],
    });

    const handler = createHandler(deps);
    await handler({contextType: "group", contextId: "grp99"});

    expect(
      (db as unknown as {collection: jest.Mock}).collection,
    ).toHaveBeenCalledWith("groups");
  });

  // -----------------------------------------------------------------------
  // Additional: friendship contextType uses "friendships" collection
  // -----------------------------------------------------------------------
  it("reads from 'friendships' collection for friendship contextType", async () => {
    const {deps, db} = createDeps({
      contextExists: true,
      contextData: {},
      expenses: [],
    });

    const handler = createHandler(deps);
    await handler({contextType: "friendship", contextId: "fr42"});

    expect(
      (db as unknown as {collection: jest.Mock}).collection,
    ).toHaveBeenCalledWith("friendships");
  });

  // -----------------------------------------------------------------------
  // Additional: writes simplifiedBalances to Firestore via transaction
  // -----------------------------------------------------------------------
  it("writes simplifiedBalances to the context document", async () => {
    const {deps, db} = createDeps({
      contextExists: true,
      contextData: {},
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
    });

    const handler = createHandler(deps);
    await handler({contextType: "friendship", contextId: "ctx1"});

    const updateFn = (db as unknown as {_updateFn: jest.Mock})._updateFn;
    expect(updateFn).toHaveBeenCalledTimes(1);
    expect(updateFn).toHaveBeenCalledWith(
      expect.anything(),
      {simplifiedBalances: {userB: {userA: 5000}}},
    );
  });
});

// ---------------------------------------------------------------------------
// recomputeAndWrite shared core — defence-in-depth around alsoSet
// ---------------------------------------------------------------------------

describe("recomputeAndWrite — alsoSet reserved-key guard", () => {
  it("throws when alsoSet contains a reserved key (simplifiedBalances)", async () => {
    const {recomputeAndWrite} = await import("../../src/simplified-debts/function");
    const {deps} = createDeps({contextExists: true, expenses: []});

    await expect(
      recomputeAndWrite(deps, {
        contextType: "friendship",
        contextId: "ctx1",
        alsoSet: {simplifiedBalances: {malicious: {override: 1}}},
      }),
    ).rejects.toThrow(/reserved key 'simplifiedBalances'/);
  });

  it("throws when alsoSet.lastActivityAt is not a Firestore Timestamp", async () => {
    const {recomputeAndWrite} = await import("../../src/simplified-debts/function");
    const {deps} = createDeps({contextExists: true, expenses: []});

    await expect(
      recomputeAndWrite(deps, {
        contextType: "friendship",
        contextId: "ctx1",
        alsoSet: {lastActivityAt: "2026-01-01T00:00:00.000Z"},
      }),
    ).rejects.toThrow(/lastActivityAt must be a Firestore Timestamp/);
  });
});

// ---------------------------------------------------------------------------
// FR-SE-05/06 — recomputeAndWrite settlement-read extension
//
// Validates that the shared core now reads settlements in the same
// transaction as expenses and folds them into the net-balance map. The
// public signature of recomputeAndWrite stays the same; settlements are an
// internal implementation detail of the algorithm's reading shape.
// ---------------------------------------------------------------------------

describe("recomputeAndWrite — settlement-read extension", () => {
  // -----------------------------------------------------------------------
  // 1. Settlement-only context: credit fromUserId / debit toUserId
  //
  // A pays B 5000 (no expenses). Net balances: A = +5000, B = -5000.
  // simplifiedBalances = {B: {A: 5000}} (debtor B owes creditor A 5000 —
  // because A is positive, A is the creditor in the simplified graph).
  // -----------------------------------------------------------------------
  it("returns expected balances for a settlement-only context (credit-from/debit-to)", async () => {
    const {deps} = createDeps({
      contextExists: true,
      contextData: {memberIds: ["userA", "userB"]},
      expenses: [],
      settlements: [
        {
          id: "set1",
          data: {
            fromUserId: "userA",
            toUserId: "userB",
            amountPaise: 5000,
            contextType: "friendship",
            contextId: "ctx1",
            deleted: false,
          },
        },
      ],
    });

    const handler = createHandler(deps);
    const result = await handler({contextType: "friendship", contextId: "ctx1"});

    expect(result.ok).toBe(true);
    expect(result.simplifiedBalances).toEqual({userB: {userA: 5000}});
  });

  // -----------------------------------------------------------------------
  // 2. Mixed expense + settlement: settlement reduces the existing debt
  //
  // A paid 10000 (split equally) → B owes A 5000.
  // B then pays A 3000 (a partial settlement).
  // Residual: B owes A 2000.
  // -----------------------------------------------------------------------
  it("folds settlements alongside expenses (partial-settlement reduces debt)", async () => {
    const {deps} = createDeps({
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
      settlements: [
        {
          id: "set1",
          data: {
            fromUserId: "userB",
            toUserId: "userA",
            amountPaise: 3000,
            contextType: "friendship",
            contextId: "ctx1",
            deleted: false,
          },
        },
      ],
    });

    const handler = createHandler(deps);
    const result = await handler({contextType: "friendship", contextId: "ctx1"});

    expect(result.ok).toBe(true);
    expect(result.simplifiedBalances).toEqual({userB: {userA: 2000}});
  });

  // -----------------------------------------------------------------------
  // 3. Settlement zeroes the debt exactly
  // -----------------------------------------------------------------------
  it("produces empty simplifiedBalances when a settlement fully zeroes the debt", async () => {
    const {deps} = createDeps({
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
      settlements: [
        {
          id: "set1",
          data: {
            fromUserId: "userB",
            toUserId: "userA",
            amountPaise: 5000,
            contextType: "friendship",
            contextId: "ctx1",
            deleted: false,
          },
        },
      ],
    });

    const handler = createHandler(deps);
    const result = await handler({contextType: "friendship", contextId: "ctx1"});

    expect(result.ok).toBe(true);
    expect(result.simplifiedBalances).toEqual({});
  });

  // -----------------------------------------------------------------------
  // 4. Settlement overshoot: debtor pays more than owed → net flips sign
  //
  // B owed A 5000; B pays A 8000 → A now owes B 3000.
  // simplifiedBalances = {A: {B: 3000}}.
  // -----------------------------------------------------------------------
  it("flips the net balance sign on overshoot (debtor overpays)", async () => {
    const {deps} = createDeps({
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
      settlements: [
        {
          id: "set1",
          data: {
            fromUserId: "userB",
            toUserId: "userA",
            amountPaise: 8000,
            contextType: "friendship",
            contextId: "ctx1",
            deleted: false,
          },
        },
      ],
    });

    const handler = createHandler(deps);
    const result = await handler({contextType: "friendship", contextId: "ctx1"});

    expect(result.ok).toBe(true);
    expect(result.simplifiedBalances).toEqual({userA: {userB: 3000}});
  });

  // -----------------------------------------------------------------------
  // 5. Soft-deleted settlements are excluded from the fold
  //
  // The implementation filters `deleted === true` settlements in code
  // (because the cross-field `==`,`==`,`!=` query would require an
  // unnecessary composite index; see Architect Notes §2).
  // -----------------------------------------------------------------------
  it("excludes settlements with deleted=true from the net-balance fold", async () => {
    const {deps} = createDeps({
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
      settlements: [
        {
          id: "set1",
          data: {
            fromUserId: "userB",
            toUserId: "userA",
            amountPaise: 5000,
            contextType: "friendship",
            contextId: "ctx1",
            deleted: true, // soft-deleted — must be filtered out
          },
        },
      ],
    });

    const handler = createHandler(deps);
    const result = await handler({contextType: "friendship", contextId: "ctx1"});

    expect(result.ok).toBe(true);
    // The soft-deleted settlement is ignored ⇒ residual debt remains.
    expect(result.simplifiedBalances).toEqual({userB: {userA: 5000}});
  });

  // -----------------------------------------------------------------------
  // 6. Multiple settlements accumulate correctly
  //
  // B owes A 10000 → B pays A 3000 + B pays A 4000 + A pays B 1000 →
  // residual: B owes A (10000 - 3000 - 4000 + 1000) = 4000.
  // -----------------------------------------------------------------------
  it("accumulates multiple settlements in the same fold", async () => {
    const {deps} = createDeps({
      contextExists: true,
      contextData: {memberIds: ["userA", "userB"]},
      expenses: [
        {
          id: "exp1",
          data: {
            payerId: "userA",
            amountPaise: 20000,
            deleted: false,
            splits: [
              {userId: "userA", sharePaise: 10000},
              {userId: "userB", sharePaise: 10000},
            ],
          },
        },
      ],
      settlements: [
        {
          id: "s1",
          data: {
            fromUserId: "userB",
            toUserId: "userA",
            amountPaise: 3000,
            contextType: "friendship",
            contextId: "ctx1",
            deleted: false,
          },
        },
        {
          id: "s2",
          data: {
            fromUserId: "userB",
            toUserId: "userA",
            amountPaise: 4000,
            contextType: "friendship",
            contextId: "ctx1",
            deleted: false,
          },
        },
        {
          id: "s3",
          data: {
            fromUserId: "userA",
            toUserId: "userB",
            amountPaise: 1000,
            contextType: "friendship",
            contextId: "ctx1",
            deleted: false,
          },
        },
      ],
    });

    const handler = createHandler(deps);
    const result = await handler({contextType: "friendship", contextId: "ctx1"});

    expect(result.ok).toBe(true);
    expect(result.simplifiedBalances).toEqual({userB: {userA: 4000}});
  });

  // -----------------------------------------------------------------------
  // 7. Settlements query is invoked against the top-level 'settlements'
  //    collection (not a subcollection)
  // -----------------------------------------------------------------------
  it("reads from the top-level 'settlements' collection", async () => {
    const {deps, db} = createDeps({
      contextExists: true,
      contextData: {memberIds: ["userA", "userB"]},
      expenses: [],
      settlements: [],
    });

    const handler = createHandler(deps);
    await handler({contextType: "friendship", contextId: "ctx1"});

    expect(
      (db as unknown as {collection: jest.Mock}).collection,
    ).toHaveBeenCalledWith("settlements");
  });
});
