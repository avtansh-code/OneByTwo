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
 */
function createMockDb(opts: {
  contextExists: boolean;
  contextData?: Record<string, unknown>;
  expenses?: Array<{id: string; data: Record<string, unknown>}>;
}): FirebaseFirestore.Firestore {
  const expenseDocs = (opts.expenses ?? []).map((e) => ({
    id: e.id,
    exists: true,
    data: () => e.data,
    ref: {path: `mock/expenses/${e.id}`},
  }));

  const contextSnap = {
    exists: opts.contextExists,
    data: () => opts.contextData ?? {},
    ref: {path: "mock/context/doc"},
  };

  const updateFn = jest.fn();

  // Build mock query/collection/doc chain
  const mockDb = {
    collection: jest.fn().mockReturnValue({
      doc: jest.fn().mockReturnValue({
        collection: jest.fn().mockReturnValue({
          where: jest.fn().mockReturnValue({
            // This object is passed to tx.get() for expenses
            _isQuery: true,
          }),
        }),
        // This ref is passed to tx.get() for context document
        _isDocRef: true,
      }),
    }),
    runTransaction: jest.fn(async (fn: (tx: unknown) => Promise<unknown>) => {
      const tx = {
        get: jest.fn((ref: unknown) => {
          // If ref is the query, return expenses
          if ((ref as Record<string, boolean>)._isQuery) {
            return Promise.resolve({docs: expenseDocs});
          }
          // Otherwise return context document
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
