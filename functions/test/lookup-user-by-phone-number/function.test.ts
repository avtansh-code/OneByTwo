/**
 * Function-boundary tests for the lookupUserByPhoneNumber callable.
 *
 * Uses dependency injection (mock Firestore, mock logger, mock algorithm) —
 * no emulator needed. The source module does not exist yet (test-first
 * discipline) — these tests will fail to compile until the implementation
 * is created.
 */

import {HttpsError} from "firebase-functions/v2/https";
import {
  createLookupHandler,
  LookupFunctionDeps,
} from "../../src/lookup-user-by-phone-number/function";

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
    warn: (message: string, data?: Record<string, unknown>) => {
      calls.push({level: "warn", message, data});
    },
    calls,
  };
}

/**
 * Creates a mock Firestore with rate-limit document behaviour.
 *
 * @param rateLimitData - The data to return for the rate-limit document read,
 *   or null if the document should not exist.
 */
function createMockDb(rateLimitData: {count: number; windowStart: number} | null) {
  const setFn = jest.fn().mockResolvedValue(undefined);
  const updateFn = jest.fn().mockResolvedValue(undefined);

  const rateLimitSnap = {
    exists: rateLimitData !== null,
    data: () => rateLimitData,
  };

  const mockDb = {
    collection: jest.fn().mockReturnValue({
      where: jest.fn().mockReturnValue({
        limit: jest.fn().mockReturnValue({
          get: jest.fn().mockResolvedValue({
            empty: true,
            docs: [],
          }),
        }),
      }),
    }),
    doc: jest.fn().mockReturnValue({
      get: jest.fn().mockResolvedValue(rateLimitSnap),
      set: setFn,
      update: updateFn,
    }),
    _setFn: setFn,
    _updateFn: updateFn,
  };

  return mockDb as unknown as FirebaseFirestore.Firestore;
}

/** Builds LookupFunctionDeps from mock db and logger. */
function createDeps(rateLimitData: {count: number; windowStart: number} | null = null) {
  const logger = createMockLogger();
  const db = createMockDb(rateLimitData);
  const deps: LookupFunctionDeps = {db, logger};
  return {deps, logger, db};
}

/** Auth context helper. */
function authContext(uid: string) {
  return {auth: {uid}};
}

/** No auth context. */
function noAuthContext() {
  return {};
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("lookupUserByPhoneNumber handler", () => {
  // -----------------------------------------------------------------------
  // 1. Valid E.164 input passes through to algorithm
  // -----------------------------------------------------------------------
  it("accepts a valid +91 E.164 phone number and returns a result", async () => {
    const {deps} = createDeps(null);
    const handler = createLookupHandler(deps);

    const result = await handler(
      {phoneNumber: "+919876543210"},
      authContext("caller-uid"),
    );

    // The mock db returns no user docs, so result should be unmatched
    expect(result).toEqual({matched: false});
  });

  // -----------------------------------------------------------------------
  // 2. Malformed phone number — raw 10-digit
  // -----------------------------------------------------------------------
  it("throws INVALID_INPUT for raw 10-digit number without +91 prefix", async () => {
    const {deps} = createDeps(null);
    const handler = createLookupHandler(deps);

    try {
      await handler({phoneNumber: "9876543210"}, authContext("caller-uid"));
      fail("Expected HttpsError to be thrown");
    } catch (err) {
      expect(err).toBeInstanceOf(HttpsError);
      const httpsErr = err as HttpsError;
      expect(httpsErr.code).toBe("invalid-argument");
      expect((httpsErr.details as {errorCode: string}).errorCode).toBe("INVALID_INPUT");
    }
  });

  // -----------------------------------------------------------------------
  // 3. Non-Indian number
  // -----------------------------------------------------------------------
  it("throws INVALID_INPUT for a non-Indian phone number", async () => {
    const {deps} = createDeps(null);
    const handler = createLookupHandler(deps);

    try {
      await handler({phoneNumber: "+447911123456"}, authContext("caller-uid"));
      fail("Expected HttpsError to be thrown");
    } catch (err) {
      expect(err).toBeInstanceOf(HttpsError);
      const httpsErr = err as HttpsError;
      expect(httpsErr.code).toBe("invalid-argument");
      expect((httpsErr.details as {errorCode: string}).errorCode).toBe("INVALID_INPUT");
    }
  });

  // -----------------------------------------------------------------------
  // 4. Empty string
  // -----------------------------------------------------------------------
  it("throws INVALID_INPUT for an empty string phone number", async () => {
    const {deps} = createDeps(null);
    const handler = createLookupHandler(deps);

    try {
      await handler({phoneNumber: ""}, authContext("caller-uid"));
      fail("Expected HttpsError to be thrown");
    } catch (err) {
      expect(err).toBeInstanceOf(HttpsError);
      const httpsErr = err as HttpsError;
      expect(httpsErr.code).toBe("invalid-argument");
      expect((httpsErr.details as {errorCode: string}).errorCode).toBe("INVALID_INPUT");
    }
  });

  // -----------------------------------------------------------------------
  // 5. Missing phoneNumber field
  // -----------------------------------------------------------------------
  it("throws INVALID_INPUT when phoneNumber field is missing", async () => {
    const {deps} = createDeps(null);
    const handler = createLookupHandler(deps);

    try {
      await handler({}, authContext("caller-uid"));
      fail("Expected HttpsError to be thrown");
    } catch (err) {
      expect(err).toBeInstanceOf(HttpsError);
      const httpsErr = err as HttpsError;
      expect(httpsErr.code).toBe("invalid-argument");
      expect((httpsErr.details as {errorCode: string}).errorCode).toBe("INVALID_INPUT");
    }
  });

  // -----------------------------------------------------------------------
  // 6. Rate-limit not exceeded — algorithm called
  // -----------------------------------------------------------------------
  it("calls algorithm when rate-limit counter is below 100", async () => {
    const now = Date.now();
    const {deps} = createDeps({count: 50, windowStart: now - 1000});
    const handler = createLookupHandler(deps);

    const result = await handler(
      {phoneNumber: "+919876543210"},
      authContext("caller-uid"),
    );

    // Should proceed to algorithm (mock returns no match)
    expect(result).toEqual({matched: false});
  });

  it("calls algorithm when rate-limit window has expired", async () => {
    const oneHourAgoMs = Date.now() - 3600001; // just over 1 hour ago
    const {deps} = createDeps({count: 100, windowStart: oneHourAgoMs});
    const handler = createLookupHandler(deps);

    const result = await handler(
      {phoneNumber: "+919876543210"},
      authContext("caller-uid"),
    );

    // Window expired, so rate limit resets — algorithm should be called
    expect(result).toEqual({matched: false});
  });

  // -----------------------------------------------------------------------
  // 7. Rate-limit exceeded
  // -----------------------------------------------------------------------
  it("throws RATE_LIMITED when counter >= 100 within the current window", async () => {
    const now = Date.now();
    const {deps} = createDeps({count: 100, windowStart: now - 1000});
    const handler = createLookupHandler(deps);

    try {
      await handler({phoneNumber: "+919876543210"}, authContext("caller-uid"));
      fail("Expected HttpsError to be thrown");
    } catch (err) {
      expect(err).toBeInstanceOf(HttpsError);
      const httpsErr = err as HttpsError;
      expect(httpsErr.code).toBe("resource-exhausted");
      expect((httpsErr.details as {errorCode: string}).errorCode).toBe("RATE_LIMITED");
    }
  });

  it("throws RATE_LIMITED when counter exceeds 100 within the current window", async () => {
    const now = Date.now();
    const {deps} = createDeps({count: 150, windowStart: now - 500});
    const handler = createLookupHandler(deps);

    try {
      await handler({phoneNumber: "+919876543210"}, authContext("caller-uid"));
      fail("Expected HttpsError to be thrown");
    } catch (err) {
      expect(err).toBeInstanceOf(HttpsError);
      const httpsErr = err as HttpsError;
      expect(httpsErr.code).toBe("resource-exhausted");
      expect((httpsErr.details as {errorCode: string}).errorCode).toBe("RATE_LIMITED");
    }
  });

  // -----------------------------------------------------------------------
  // 8. Algorithm throws unexpected error
  // -----------------------------------------------------------------------
  it("throws INTERNAL when the algorithm throws an unexpected error", async () => {
    // Create deps where the db.collection().where().limit().get() rejects
    const logger = createMockLogger();
    const db = {
      collection: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          limit: jest.fn().mockReturnValue({
            get: jest.fn().mockRejectedValue(new Error("Firestore unavailable")),
          }),
        }),
      }),
      doc: jest.fn().mockReturnValue({
        get: jest.fn().mockResolvedValue({
          exists: false,
          data: () => null,
        }),
        set: jest.fn().mockResolvedValue(undefined),
        update: jest.fn().mockResolvedValue(undefined),
      }),
    } as unknown as FirebaseFirestore.Firestore;

    const deps: LookupFunctionDeps = {db, logger};
    const handler = createLookupHandler(deps);

    try {
      await handler({phoneNumber: "+919876543210"}, authContext("caller-uid"));
      fail("Expected HttpsError to be thrown");
    } catch (err) {
      expect(err).toBeInstanceOf(HttpsError);
      const httpsErr = err as HttpsError;
      expect(httpsErr.code).toBe("internal");
      expect((httpsErr.details as {errorCode: string}).errorCode).toBe("INTERNAL");
    }
  });

  // -----------------------------------------------------------------------
  // 9. Unauthenticated request
  // -----------------------------------------------------------------------
  it("throws unauthenticated when no auth context is provided", async () => {
    const {deps} = createDeps(null);
    const handler = createLookupHandler(deps);

    try {
      await handler({phoneNumber: "+919876543210"}, noAuthContext() as any);
      fail("Expected HttpsError to be thrown");
    } catch (err) {
      expect(err).toBeInstanceOf(HttpsError);
      const httpsErr = err as HttpsError;
      expect(httpsErr.code).toBe("unauthenticated");
    }
  });

  // -----------------------------------------------------------------------
  // 10. Successful invocation logging — hashed phone, no raw values
  // -----------------------------------------------------------------------
  it("logs started and completed events with hashed phoneNumber on success", async () => {
    const {deps, logger} = createDeps(null);
    const handler = createLookupHandler(deps);

    await handler({phoneNumber: "+919876543210"}, authContext("caller-uid"));

    const startedLog = logger.calls.find(
      (c) => c.data?.event === "lookup_user_by_phone_number_started",
    );
    expect(startedLog).toBeDefined();
    expect(startedLog!.level).toBe("info");
    // Must contain a hashed phone number, not the raw value
    expect(startedLog!.data!.phoneNumberHash).toBeDefined();
    expect(typeof startedLog!.data!.phoneNumberHash).toBe("string");
    // SHA-256 hex digest is 64 characters
    expect((startedLog!.data!.phoneNumberHash as string).length).toBe(64);

    const completedLog = logger.calls.find(
      (c) => c.data?.event === "lookup_user_by_phone_number_completed",
    );
    expect(completedLog).toBeDefined();
    expect(completedLog!.level).toBe("info");

    // Verify raw phone number and userId NEVER appear in any log
    for (const call of logger.calls) {
      const serialised = JSON.stringify(call.data);
      expect(serialised).not.toContain("+919876543210");
      expect(serialised).not.toContain("caller-uid");
    }
  });

  // -----------------------------------------------------------------------
  // 11. Failed invocation logging
  // -----------------------------------------------------------------------
  it("logs failed event with error code on validation failure", async () => {
    const {deps, logger} = createDeps(null);
    const handler = createLookupHandler(deps);

    try {
      await handler({phoneNumber: "invalid"}, authContext("caller-uid"));
    } catch {
      // expected
    }

    const failedLog = logger.calls.find(
      (c) => c.data?.event === "lookup_user_by_phone_number_failed",
    );
    expect(failedLog).toBeDefined();
    expect(failedLog!.level).toBe("error");
    expect(failedLog!.data!.errorCode).toBe("INVALID_INPUT");
  });

  it("logs failed event with RATE_LIMITED error code", async () => {
    const now = Date.now();
    const {deps, logger} = createDeps({count: 100, windowStart: now - 1000});
    const handler = createLookupHandler(deps);

    try {
      await handler({phoneNumber: "+919876543210"}, authContext("caller-uid"));
    } catch {
      // expected
    }

    const failedLog = logger.calls.find(
      (c) => c.data?.event === "lookup_user_by_phone_number_failed",
    );
    expect(failedLog).toBeDefined();
    expect(failedLog!.level).toBe("error");
    expect(failedLog!.data!.errorCode).toBe("RATE_LIMITED");
  });

  it("logs failed event with INTERNAL error code on unexpected errors", async () => {
    const logger = createMockLogger();
    const db = {
      collection: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          limit: jest.fn().mockReturnValue({
            get: jest.fn().mockRejectedValue(new Error("boom")),
          }),
        }),
      }),
      doc: jest.fn().mockReturnValue({
        get: jest.fn().mockResolvedValue({
          exists: false,
          data: () => null,
        }),
        set: jest.fn().mockResolvedValue(undefined),
        update: jest.fn().mockResolvedValue(undefined),
      }),
    } as unknown as FirebaseFirestore.Firestore;

    const deps: LookupFunctionDeps = {db, logger};
    const handler = createLookupHandler(deps);

    try {
      await handler({phoneNumber: "+919876543210"}, authContext("caller-uid"));
    } catch {
      // expected
    }

    const failedLog = logger.calls.find(
      (c) => c.data?.event === "lookup_user_by_phone_number_failed",
    );
    expect(failedLog).toBeDefined();
    expect(failedLog!.level).toBe("error");
    expect(failedLog!.data!.errorCode).toBe("INTERNAL");
  });
});
