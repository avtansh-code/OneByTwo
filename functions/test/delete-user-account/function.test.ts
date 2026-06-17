/**
 * Function-boundary tests for the FR-AU-09 deleteUserAccount callable.
 *
 * DI-mocked Firestore / Auth / Storage / logger; no emulator. Exercises
 * the ADR-0016 contract:
 *
 *   - Auth check first      -> UNAUTHENTICATED when no caller uid.
 *   - Happy-path cascade     -> success; recursiveDelete of activity/{uid}
 *                               and _rateLimits/{uid}; users/{uid} tombstone;
 *                               avatar delete; Auth delete LAST.
 *   - Tombstone shape        -> only { displayName: 'Deleted User', deletedAt };
 *                               every PII field stripped.
 *   - Invariant 2 boundary   -> no friendship / settlement / expense /
 *                               simplifiedBalances write of any kind.
 *   - Idempotency            -> auth/user-not-found and a 404 avatar are
 *                               swallowed as success.
 *   - INTERNAL               -> a genuine step failure maps to INTERNAL.
 *   - Structured-log PII guard-> only uidHash is logged, never the raw uid.
 *
 * @module test/delete-user-account/function.test.ts
 */

import {HttpsError} from "firebase-functions/v2/https";
import {
  createDeleteUserAccountHandler,
  DeleteUserAccountFunctionDeps,
} from "../../src/delete-user-account/function";
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
  /** Doc paths whose recursiveDelete should throw a genuine error. */
  recursiveDeleteThrowsFor?: string[];
  /** When set, the users-doc tombstone set() throws this. */
  usersSetThrows?: unknown;
  /** When set, the avatar delete() throws this. */
  avatarThrows?: unknown;
  /** When set, the Auth deleteUser() throws this. */
  authThrows?: unknown;
}

interface Captured {
  order: string[];
  recursiveDeletePaths: string[];
  collectionsAccessed: string[];
  usersSets: Array<Record<string, unknown>>;
  avatarDeletes: Array<{path: string; options?: unknown}>;
  authDeletes: string[];
}

function createMocks(opts: MockOptions = {}): {
  deps: DeleteUserAccountFunctionDeps;
  captured: Captured;
  logger: ReturnType<typeof createMockLogger>;
} {
  const captured: Captured = {
    order: [],
    recursiveDeletePaths: [],
    collectionsAccessed: [],
    usersSets: [],
    avatarDeletes: [],
    authDeletes: [],
  };

  const db = {
    recursiveDelete: async (ref: {path: string}) => {
      captured.order.push(`recursiveDelete:${ref.path}`);
      captured.recursiveDeletePaths.push(ref.path);
      if (opts.recursiveDeleteThrowsFor?.includes(ref.path)) {
        throw new Error(`firestore unavailable for ${ref.path}`);
      }
    },
    collection: (name: string) => {
      captured.collectionsAccessed.push(name);
      return {
        doc: (id: string) => ({
          path: `${name}/${id}`,
          set: async (data: Record<string, unknown>) => {
            captured.order.push(`set:${name}/${id}`);
            if (name === "users") {
              captured.usersSets.push(data);
              if (opts.usersSetThrows !== undefined) throw opts.usersSetThrows;
            }
          },
        }),
      };
    },
  } as unknown as FirebaseFirestore.Firestore;

  const bucket = {
    file: (path: string) => ({
      delete: async (options?: {ignoreNotFound?: boolean}) => {
        captured.order.push(`avatarDelete:${path}`);
        captured.avatarDeletes.push({path, options});
        if (opts.avatarThrows !== undefined) throw opts.avatarThrows;
      },
    }),
  };

  const authAdmin = {
    deleteUser: async (uid: string) => {
      captured.order.push(`authDelete:${uid}`);
      captured.authDeletes.push(uid);
      if (opts.authThrows !== undefined) throw opts.authThrows;
    },
  };

  const logger = createMockLogger();

  return {
    deps: {db, bucket, authAdmin, logger, now: () => new Date(NOW_MS)},
    captured,
    logger,
  };
}

const UID = "user-to-delete-123";

/** Fixed clock for the deterministic auth_time recency check. */
const NOW_MS = Date.UTC(2026, 0, 1, 12, 0, 0);

/** A recently-authenticated `auth_time` (30s before NOW), in Unix seconds. */
const RECENT_AUTH_TIME_SEC = Math.floor(NOW_MS / 1000) - 30;

/** Builds a caller context with a (by default recent) `auth_time` claim. */
function authCtx(authTimeSec: number = RECENT_AUTH_TIME_SEC): {
  auth: {uid: string; token: {auth_time: number}};
} {
  return {auth: {uid: UID, token: {auth_time: authTimeSec}}};
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("deleteUserAccount — function boundary", () => {
  it("throws UNAUTHENTICATED when there is no caller uid", async () => {
    const {deps, captured} = createMocks();
    const handler = createDeleteUserAccountHandler(deps);

    await expect(handler({}, {})).rejects.toMatchObject({
      code: "unauthenticated",
      details: {errorCode: "UNAUTHENTICATED"},
    });
    // No work was performed before the auth check.
    expect(captured.order).toHaveLength(0);
    expect(captured.recursiveDeletePaths).toHaveLength(0);
    expect(captured.usersSets).toHaveLength(0);
    expect(captured.authDeletes).toHaveLength(0);
  });

  it("throws REAUTH_REQUIRED when auth_time is stale (re-auth gate)", async () => {
    const {deps, captured} = createMocks();
    const handler = createDeleteUserAccountHandler(deps);

    // auth_time 10 minutes before the fixed clock — older than the 5-min window.
    const staleAuthTimeSec = Math.floor(NOW_MS / 1000) - 10 * 60;
    await expect(handler(undefined, authCtx(staleAuthTimeSec))).rejects
      .toMatchObject({
        code: "failed-precondition",
        details: {errorCode: "REAUTH_REQUIRED"},
      });
    // The cascade never started — no destructive work before the gate passes.
    expect(captured.order).toHaveLength(0);
    expect(captured.authDeletes).toHaveLength(0);
  });

  it("throws REAUTH_REQUIRED when the auth_time claim is missing", async () => {
    const {deps, captured} = createMocks();
    const handler = createDeleteUserAccountHandler(deps);

    await expect(
      handler(undefined, {auth: {uid: UID, token: {}}}),
    ).rejects.toMatchObject({
      code: "failed-precondition",
      details: {errorCode: "REAUTH_REQUIRED"},
    });
    expect(captured.order).toHaveLength(0);
  });

  it("runs the full cascade and returns { success: true }", async () => {
    const {deps, captured} = createMocks();
    const handler = createDeleteUserAccountHandler(deps);

    const result = await handler(undefined, authCtx());

    expect(result).toEqual({success: true});
    expect(captured.recursiveDeletePaths).toEqual([
      `activity/${UID}`,
      `_rateLimits/${UID}`,
    ]);
    expect(captured.avatarDeletes).toEqual([
      {path: `avatars/${UID}`, options: {ignoreNotFound: true}},
    ]);
    expect(captured.authDeletes).toEqual([UID]);
  });

  it("deletes the Firebase Auth record LAST", async () => {
    const {deps, captured} = createMocks();
    const handler = createDeleteUserAccountHandler(deps);

    await handler(undefined, authCtx());

    expect(captured.order[captured.order.length - 1]).toBe(`authDelete:${UID}`);
    const authIndex = captured.order.indexOf(`authDelete:${UID}`);
    expect(captured.order.indexOf(`recursiveDelete:activity/${UID}`))
      .toBeLessThan(authIndex);
    expect(captured.order.indexOf(`recursiveDelete:_rateLimits/${UID}`))
      .toBeLessThan(authIndex);
    expect(captured.order.indexOf(`set:users/${UID}`)).toBeLessThan(authIndex);
    expect(captured.order.indexOf(`avatarDelete:avatars/${UID}`))
      .toBeLessThan(authIndex);
  });

  it("tombstones users/{uid} with a PII-free 'Deleted User' shell", async () => {
    const {deps, captured} = createMocks();
    const handler = createDeleteUserAccountHandler(deps);

    await handler(undefined, authCtx());

    expect(captured.usersSets).toHaveLength(1);
    const shell = captured.usersSets[0];
    expect(shell.displayName).toBe("Deleted User");
    expect(shell).toHaveProperty("deletedAt");
    // Exactly two keys — every PII field is stripped.
    expect(Object.keys(shell).sort()).toEqual(["deletedAt", "displayName"]);
    for (const piiField of [
      "phoneNumber",
      "photoUrl",
      "fcmTokens",
      "notificationPrefs",
      "locale",
    ]) {
      expect(shell).not.toHaveProperty(piiField);
    }
  });

  it("never writes to a friendship/settlement/simplifiedBalances (Invariant 2)", async () => {
    const {deps, captured} = createMocks();
    const handler = createDeleteUserAccountHandler(deps);

    await handler(undefined, authCtx());

    // Only the three personal collections are touched.
    expect(new Set(captured.collectionsAccessed)).toEqual(
      new Set(["activity", "_rateLimits", "users"]),
    );
    expect(captured.collectionsAccessed).not.toContain("friendships");
    expect(captured.collectionsAccessed).not.toContain("settlements");
    // The only write payload (the users tombstone) carries no balance field.
    expect(captured.usersSets[0]).not.toHaveProperty("simplifiedBalances");
  });

  it("is idempotent: a missing Auth record (auth/user-not-found) resolves as success", async () => {
    const {deps, captured} = createMocks({
      authThrows: {code: "auth/user-not-found"},
    });
    const handler = createDeleteUserAccountHandler(deps);

    const result = await handler(undefined, authCtx());

    expect(result).toEqual({success: true});
    expect(captured.authDeletes).toEqual([UID]);
  });

  it("is idempotent: a missing avatar (404) resolves as success", async () => {
    const {deps} = createMocks({avatarThrows: {code: 404}});
    const handler = createDeleteUserAccountHandler(deps);

    await expect(handler(undefined, authCtx())).resolves.toEqual({
      success: true,
    });
  });

  it("maps a genuine Firestore failure to INTERNAL", async () => {
    const {deps} = createMocks({
      recursiveDeleteThrowsFor: [`_rateLimits/${UID}`],
    });
    const handler = createDeleteUserAccountHandler(deps);

    await expect(handler(undefined, authCtx())).rejects.toMatchObject({
      code: "internal",
      details: {errorCode: "INTERNAL"},
    });
  });

  it("maps a genuine avatar delete failure to INTERNAL", async () => {
    const {deps} = createMocks({avatarThrows: {code: 500}});
    const handler = createDeleteUserAccountHandler(deps);

    await expect(handler(undefined, authCtx())).rejects.toMatchObject({
      code: "internal",
      details: {errorCode: "INTERNAL"},
    });
  });

  it("maps a genuine Auth delete failure (not user-not-found) to INTERNAL", async () => {
    const {deps} = createMocks({authThrows: {code: "auth/internal-error"}});
    const handler = createDeleteUserAccountHandler(deps);

    await expect(handler(undefined, authCtx())).rejects.toMatchObject({
      code: "internal",
      details: {errorCode: "INTERNAL"},
    });
  });

  it("propagates the typed HttpsError unchanged (does not re-wrap auth errors)", async () => {
    const {deps} = createMocks();
    const handler = createDeleteUserAccountHandler(deps);

    const error = await handler({}, {}).catch((e: unknown) => e);
    expect(error).toBeInstanceOf(HttpsError);
    expect((error as HttpsError).code).toBe("unauthenticated");
  });

  it("logs only the hashed uid — never the raw uid (PII guard)", async () => {
    const {deps, logger} = createMocks();
    const handler = createDeleteUserAccountHandler(deps);

    await handler(undefined, authCtx());

    const expectedHash = hashId(UID);
    expect(logger.calls.length).toBeGreaterThan(0);
    for (const call of logger.calls) {
      const serialised = JSON.stringify(call.data ?? {});
      expect(serialised).not.toContain(UID);
      if (call.data && "uidHash" in call.data) {
        expect(call.data.uidHash).toBe(expectedHash);
      }
    }
  });

  it("redacts the raw uid from the failure-path log message (PII guard)", async () => {
    // A non-404 Storage error whose message embeds the uid via the object
    // path — the realistic vector for a raw-uid leak on the failure path.
    const {deps, logger} = createMocks({
      avatarThrows: new Error(`storage 500 deleting avatars/${UID}`),
    });
    const handler = createDeleteUserAccountHandler(deps);

    await expect(handler(undefined, authCtx())).rejects.toMatchObject({
      code: "internal",
    });

    const failure = logger.calls.find(
      (c) => c.message === "delete_account_cascade_failed",
    );
    expect(failure).toBeDefined();
    // The errorMessage carries the SDK message but with the uid redacted.
    const serialised = JSON.stringify(failure?.data ?? {});
    expect(serialised).not.toContain(UID);
    expect(serialised).toContain(hashId(UID));
  });
});
