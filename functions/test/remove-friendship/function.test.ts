/**
 * Function-boundary tests for the FR-FR-05 removeFriendship callable.
 *
 * DI-mocked Firestore / logger; no emulator. Exercises the handler contract:
 *
 *   - Auth check first       -> UNAUTHENTICATED when no caller uid (no read,
 *                               no delete).
 *   - Input validation       -> INVALID_INPUT for a missing / non-string /
 *                               non-`a_b` / slash-bearing friendshipId.
 *   - Missing doc            -> FRIENDSHIP_NOT_FOUND (no delete).
 *   - Non-member             -> NOT_A_MEMBER (no delete).
 *   - Balance gate           -> FRIENDSHIP_NOT_SETTLED on ANY non-zero
 *                               simplifiedBalances entry; the doc is NOT
 *                               deleted (load-bearing rule).
 *   - Settled (zero/empty/absent) -> recursiveDelete of friendships/{id} +
 *                               { success: true }.
 *   - INTERNAL               -> a genuine read/delete failure maps to INTERNAL.
 *   - Invariant 2 boundary   -> the handler NEVER writes simplifiedBalances
 *                               (no set / update of any kind).
 *   - Structured-log PII guard -> only hashed ids are logged, never the raw
 *                               uid or friendshipId.
 *
 * @module test/remove-friendship/function.test.ts
 */

import {HttpsError} from "firebase-functions/v2/https";
import {
  createRemoveFriendshipHandler,
  hasOutstandingBalance,
  RemoveFriendshipFunctionDeps,
} from "../../src/remove-friendship/function";
import {hashId} from "../../src/utils/id-hash";

// ---------------------------------------------------------------------------
// Mock helpers
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

interface MockOptions {
  /** Whether the friendship document exists. Defaults to true. */
  exists?: boolean;
  /** The friendship document data returned by snap.data(). */
  data?: Record<string, unknown>;
  /** When set, friendshipRef.get() throws this. */
  getThrows?: unknown;
  /** When set, db.recursiveDelete() throws this. */
  recursiveDeleteThrows?: unknown;
}

interface Captured {
  order: string[];
  getPaths: string[];
  recursiveDeletePaths: string[];
  /** Any set()/update() write captured — MUST stay empty (Invariant 2). */
  writes: Array<{op: string; path: string; data: unknown}>;
  collectionsAccessed: string[];
}

function createMocks(opts: MockOptions = {}): {
  deps: RemoveFriendshipFunctionDeps;
  captured: Captured;
  logger: ReturnType<typeof createMockLogger>;
} {
  const captured: Captured = {
    order: [],
    getPaths: [],
    recursiveDeletePaths: [],
    writes: [],
    collectionsAccessed: [],
  };

  const db = {
    collection: (name: string) => {
      captured.collectionsAccessed.push(name);
      return {
        doc: (id: string) => {
          const path = `${name}/${id}`;
          return {
            path,
            get: async () => {
              captured.order.push(`get:${path}`);
              captured.getPaths.push(path);
              if (opts.getThrows !== undefined) throw opts.getThrows;
              return {
                exists: opts.exists ?? true,
                data: () => opts.data,
              };
            },
            // Present so any accidental write attempt is captured rather
            // than throwing — the Invariant-2 test asserts `writes` is empty.
            set: async (data: unknown) => {
              captured.order.push(`set:${path}`);
              captured.writes.push({op: "set", path, data});
            },
            update: async (data: unknown) => {
              captured.order.push(`update:${path}`);
              captured.writes.push({op: "update", path, data});
            },
          };
        },
      };
    },
    recursiveDelete: async (ref: {path: string}) => {
      captured.order.push(`recursiveDelete:${ref.path}`);
      captured.recursiveDeletePaths.push(ref.path);
      if (opts.recursiveDeleteThrows !== undefined) {
        throw opts.recursiveDeleteThrows;
      }
    },
  } as unknown as FirebaseFirestore.Firestore;

  const logger = createMockLogger();
  return {deps: {db, logger}, captured, logger};
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const CALLER_UID = "uid-alice";
const FRIEND_UID = "uid-bob";
/** Deterministic sorted-and-joined friendship ID (uid-alice < uid-bob). */
const FRIENDSHIP_ID = `${CALLER_UID}_${FRIEND_UID}`;
const FRIENDSHIP_PATH = `friendships/${FRIENDSHIP_ID}`;
const NON_MEMBER_UID = "uid-carol";

/** Builds a settled friendship doc (optionally with a balances override). */
function settledDoc(
  overrides: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    memberIds: [CALLER_UID, FRIEND_UID],
    createdBy: CALLER_UID,
    ...overrides,
  };
}

/** Builds a caller context with the given uid (default: a member). */
function authCtx(uid: string = CALLER_UID): {auth: {uid: string}} {
  return {auth: {uid}};
}

// ---------------------------------------------------------------------------
// hasOutstandingBalance unit cases
// ---------------------------------------------------------------------------

describe("hasOutstandingBalance", () => {
  it("treats absent / empty / null as settled (false)", () => {
    expect(hasOutstandingBalance(undefined)).toBe(false);
    expect(hasOutstandingBalance(null)).toBe(false);
    expect(hasOutstandingBalance({})).toBe(false);
  });

  it("treats an all-zero leaf as settled (false)", () => {
    expect(hasOutstandingBalance({[FRIEND_UID]: {[CALLER_UID]: 0}})).toBe(
      false,
    );
  });

  it("detects a non-zero positive leaf (true)", () => {
    expect(hasOutstandingBalance({[FRIEND_UID]: {[CALLER_UID]: 50000}})).toBe(
      true,
    );
  });

  it("detects a non-zero leaf among zeros (true)", () => {
    expect(
      hasOutstandingBalance({
        [FRIEND_UID]: {[CALLER_UID]: 0},
        [CALLER_UID]: {[FRIEND_UID]: 1},
      }),
    ).toBe(true);
  });

  it("treats malformed shapes as settled (false), mirroring the client", () => {
    expect(hasOutstandingBalance("nope")).toBe(false);
    expect(hasOutstandingBalance(42)).toBe(false);
    expect(hasOutstandingBalance({[FRIEND_UID]: "not-a-map"})).toBe(false);
    expect(hasOutstandingBalance({[FRIEND_UID]: {[CALLER_UID]: "x"}})).toBe(
      false,
    );
  });
});

// ---------------------------------------------------------------------------
// Handler boundary tests
// ---------------------------------------------------------------------------

describe("removeFriendship — function boundary", () => {
  it("throws UNAUTHENTICATED when there is no caller uid", async () => {
    const {deps, captured} = createMocks();
    const handler = createRemoveFriendshipHandler(deps);

    await expect(
      handler({friendshipId: FRIENDSHIP_ID}, {}),
    ).rejects.toMatchObject({
      code: "unauthenticated",
      details: {errorCode: "UNAUTHENTICATED"},
    });
    // No work before the auth check.
    expect(captured.order).toHaveLength(0);
    expect(captured.recursiveDeletePaths).toHaveLength(0);
  });

  it.each([
    ["missing", {}],
    ["non-string", {friendshipId: 123}],
    ["empty string", {friendshipId: ""}],
    ["no underscore", {friendshipId: "abc"}],
    ["double underscore (uid contains _)", {friendshipId: "a_b_c"}],
    ["slash (path traversal)", {friendshipId: "a/expenses/b"}],
    ["slash with underscore", {friendshipId: "a_b/expenses/x"}],
  ])(
    "throws INVALID_INPUT for a malformed friendshipId: %s",
    async (_label, data) => {
      const {deps, captured} = createMocks();
      const handler = createRemoveFriendshipHandler(deps);

      await expect(handler(data, authCtx())).rejects.toMatchObject({
        code: "invalid-argument",
        details: {errorCode: "INVALID_INPUT"},
      });
      // Validation happens before any Firestore access.
      expect(captured.order).toHaveLength(0);
    },
  );

  it("throws FRIENDSHIP_NOT_FOUND when the document is absent", async () => {
    const {deps, captured} = createMocks({exists: false});
    const handler = createRemoveFriendshipHandler(deps);

    await expect(
      handler({friendshipId: FRIENDSHIP_ID}, authCtx()),
    ).rejects.toMatchObject({
      code: "not-found",
      details: {errorCode: "FRIENDSHIP_NOT_FOUND"},
    });
    // The doc was read but nothing was deleted.
    expect(captured.getPaths).toEqual([FRIENDSHIP_PATH]);
    expect(captured.recursiveDeletePaths).toHaveLength(0);
  });

  it("throws NOT_A_MEMBER when the caller is not in memberIds", async () => {
    const {deps, captured} = createMocks({
      exists: true,
      data: settledDoc(),
    });
    const handler = createRemoveFriendshipHandler(deps);

    await expect(
      handler({friendshipId: FRIENDSHIP_ID}, authCtx(NON_MEMBER_UID)),
    ).rejects.toMatchObject({
      code: "permission-denied",
      details: {errorCode: "NOT_A_MEMBER"},
    });
    // Authorization failed -> nothing deleted.
    expect(captured.recursiveDeletePaths).toHaveLength(0);
  });

  it("throws NOT_A_MEMBER when memberIds is absent/malformed", async () => {
    const {deps, captured} = createMocks({
      exists: true,
      data: {createdBy: CALLER_UID}, // no memberIds
    });
    const handler = createRemoveFriendshipHandler(deps);

    await expect(
      handler({friendshipId: FRIENDSHIP_ID}, authCtx()),
    ).rejects.toMatchObject({
      code: "permission-denied",
      details: {errorCode: "NOT_A_MEMBER"},
    });
    expect(captured.recursiveDeletePaths).toHaveLength(0);
  });

  it("throws FRIENDSHIP_NOT_SETTLED on a non-zero balance and does NOT delete", async () => {
    const {deps, captured} = createMocks({
      exists: true,
      data: settledDoc({
        // uid-bob owes uid-alice ₹500 = 50000 paise.
        simplifiedBalances: {[FRIEND_UID]: {[CALLER_UID]: 50000}},
      }),
    });
    const handler = createRemoveFriendshipHandler(deps);

    await expect(
      handler({friendshipId: FRIENDSHIP_ID}, authCtx()),
    ).rejects.toMatchObject({
      code: "failed-precondition",
      details: {errorCode: "FRIENDSHIP_NOT_SETTLED"},
    });

    // The load-bearing rule: the doc and its subtree are NOT deleted.
    expect(captured.recursiveDeletePaths).toHaveLength(0);
    // And no balance write happened (Invariant 2).
    expect(captured.writes).toHaveLength(0);

    const failure = captured.order.find((o) => o.startsWith("recursiveDelete"));
    expect(failure).toBeUndefined();

    // Surfaces the exact copy required by the story.
    const error = await handler({friendshipId: FRIENDSHIP_ID}, authCtx()).catch(
      (e: unknown) => e,
    );
    expect((error as HttpsError).message).toBe(
      "Settle up before removing this friend.",
    );
  });

  it.each([
    ["empty map", {}],
    ["absent field", undefined],
    ["all-zero leaf", {[FRIEND_UID]: {[CALLER_UID]: 0}}],
  ])(
    "recursiveDeletes and returns success when settled: %s",
    async (_label, balances) => {
      const data =
        balances === undefined ?
          settledDoc() :
          settledDoc({simplifiedBalances: balances});
      const {deps, captured} = createMocks({exists: true, data});
      const handler = createRemoveFriendshipHandler(deps);

      const result = await handler(
        {friendshipId: FRIENDSHIP_ID},
        authCtx(),
      );

      expect(result).toEqual({success: true});
      // recursiveDelete targets exactly the friendship doc (its expenses
      // subtree is removed by the same recursiveDelete call).
      expect(captured.recursiveDeletePaths).toEqual([FRIENDSHIP_PATH]);
      // No balance write of any kind (Invariant 2).
      expect(captured.writes).toHaveLength(0);
    },
  );

  it("reads the doc BEFORE deleting (get precedes recursiveDelete)", async () => {
    const {deps, captured} = createMocks({
      exists: true,
      data: settledDoc({simplifiedBalances: {}}),
    });
    const handler = createRemoveFriendshipHandler(deps);

    await handler({friendshipId: FRIENDSHIP_ID}, authCtx());

    expect(captured.order).toEqual([
      `get:${FRIENDSHIP_PATH}`,
      `recursiveDelete:${FRIENDSHIP_PATH}`,
    ]);
  });

  it("never writes simplifiedBalances — only reads + deletes (Invariant 2)", async () => {
    const {deps, captured} = createMocks({
      exists: true,
      data: settledDoc({simplifiedBalances: {}}),
    });
    const handler = createRemoveFriendshipHandler(deps);

    await handler({friendshipId: FRIENDSHIP_ID}, authCtx());

    expect(captured.writes).toHaveLength(0);
    // Only the friendships collection is ever touched.
    expect(new Set(captured.collectionsAccessed)).toEqual(
      new Set(["friendships"]),
    );
  });

  it("maps a genuine read failure to INTERNAL", async () => {
    const {deps, captured} = createMocks({
      getThrows: new Error("firestore unavailable"),
    });
    const handler = createRemoveFriendshipHandler(deps);

    await expect(
      handler({friendshipId: FRIENDSHIP_ID}, authCtx()),
    ).rejects.toMatchObject({
      code: "internal",
      details: {errorCode: "INTERNAL"},
    });
    expect(captured.recursiveDeletePaths).toHaveLength(0);
  });

  it("maps a genuine recursiveDelete failure to INTERNAL", async () => {
    const {deps} = createMocks({
      exists: true,
      data: settledDoc({simplifiedBalances: {}}),
      recursiveDeleteThrows: new Error("bulkwriter exploded"),
    });
    const handler = createRemoveFriendshipHandler(deps);

    await expect(
      handler({friendshipId: FRIENDSHIP_ID}, authCtx()),
    ).rejects.toMatchObject({
      code: "internal",
      details: {errorCode: "INTERNAL"},
    });
  });

  it("propagates the typed HttpsError unchanged (does not re-wrap)", async () => {
    const {deps} = createMocks({exists: false});
    const handler = createRemoveFriendshipHandler(deps);

    const error = await handler({friendshipId: FRIENDSHIP_ID}, authCtx()).catch(
      (e: unknown) => e,
    );
    expect(error).toBeInstanceOf(HttpsError);
    expect((error as HttpsError).code).toBe("not-found");
  });

  it("logs only hashed ids — never the raw uid or friendshipId (PII guard)", async () => {
    const {deps, logger} = createMocks({
      exists: true,
      data: settledDoc({simplifiedBalances: {}}),
    });
    const handler = createRemoveFriendshipHandler(deps);

    await handler({friendshipId: FRIENDSHIP_ID}, authCtx());

    expect(logger.calls.length).toBeGreaterThan(0);
    for (const call of logger.calls) {
      const serialised = JSON.stringify(call.data ?? {});
      expect(serialised).not.toContain(CALLER_UID);
      expect(serialised).not.toContain(FRIENDSHIP_ID);
      if (call.data && "friendshipIdHash" in call.data) {
        expect(call.data.friendshipIdHash).toBe(hashId(FRIENDSHIP_ID));
      }
      if (call.data && "callerUidHash" in call.data) {
        expect(call.data.callerUidHash).toBe(hashId(CALLER_UID));
      }
    }
  });

  it("redacts the friendshipId from the INTERNAL failure log message", async () => {
    // A read error whose message embeds the doc path — the realistic vector
    // for a raw-id leak on the failure path.
    const {deps, logger} = createMocks({
      getThrows: new Error(`firestore 500 reading ${FRIENDSHIP_PATH}`),
    });
    const handler = createRemoveFriendshipHandler(deps);

    await expect(
      handler({friendshipId: FRIENDSHIP_ID}, authCtx()),
    ).rejects.toMatchObject({code: "internal"});

    const failure = logger.calls.find(
      (c) => c.message === "remove_friendship_failed",
    );
    expect(failure).toBeDefined();
    const serialised = JSON.stringify(failure?.data ?? {});
    expect(serialised).not.toContain(FRIENDSHIP_ID);
    expect(serialised).toContain(hashId(FRIENDSHIP_ID));
  });
});
