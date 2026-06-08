/**
 * Unit tests for the admin-SDK FCM send helper (FR-AC-03).
 *
 * Asserts:
 *   - One message sent per token via `Promise.allSettled` (parallel).
 *   - Aggregated result `{succeeded, failed, pruned}`.
 *   - On `messaging/registration-token-not-registered` (HTTP 410),
 *     `arrayRemove(token)` is invoked on `users/{uid}.fcmTokens`.
 *   - On non-410 errors, no prune; structured `fcm_send_failed` log.
 *   - Empty `tokens` array is a no-op (no admin-SDK call, no log).
 *   - Required structured-log events are emitted with the required
 *     parameters (architect §2.10 item 8 — token fingerprint, NOT raw
 *     token; `userIdHash` via `hashId()`).
 *
 * The admin-SDK Messaging surface is injected via the `messaging`
 * dependency so this test never touches real Firebase Cloud Messaging.
 *
 * @module test/notifications/fcm-send.test.ts
 */

import {sendFcmToTokens, fingerprintToken} from
  "../../src/notifications/fcm-send";
import type {NotificationPayload} from "../../src/notifications/types";

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
 * Mock Firestore that records `users/{uid}.update()` calls. We only care
 * about the `arrayRemove` invocation on the 410 cleanup branch.
 */
function createMockDbWithRecordedUpdates() {
  const updateFn = jest.fn().mockResolvedValue(undefined);
  const docFn = jest.fn().mockReturnValue({update: updateFn});
  const collectionFn = jest.fn().mockReturnValue({doc: docFn});
  return {
    db: {collection: collectionFn} as unknown as FirebaseFirestore.Firestore,
    updateFn,
    collectionFn,
    docFn,
  };
}

/**
 * Returns a per-token mock `messaging.send()` that resolves "ok-{token}"
 * for every token by default. Specific tokens can be configured to
 * reject with a 410 (`messaging/registration-token-not-registered`) or
 * a generic non-410 error.
 */
function createMockMessaging(opts: {
  not_registered_tokens?: ReadonlySet<string>;
  generic_error_tokens?: ReadonlySet<string>;
} = {}) {
  const not_registered_tokens = opts.not_registered_tokens ?? new Set();
  const generic_error_tokens = opts.generic_error_tokens ?? new Set();
  const sendFn = jest.fn(async (msg: {token: string}) => {
    if (not_registered_tokens.has(msg.token)) {
      const err = new Error("Registration token is not registered") as Error & {
        code?: string;
      };
      err.code = "messaging/registration-token-not-registered";
      throw err;
    }
    if (generic_error_tokens.has(msg.token)) {
      const err = new Error("Network error") as Error & {code?: string};
      err.code = "messaging/internal-error";
      throw err;
    }
    return `message-id-${msg.token}`;
  });
  return {
    messaging: {send: sendFn} as unknown as
      import("firebase-admin/messaging").Messaging,
    sendFn,
  };
}

function validPayload(): NotificationPayload {
  return {
    type: "expense_added",
    contextType: "friendship",
    contextId: "fid",
    itemId: "exp1",
    title: "Rahul added an expense",
    body: "Dinner -- ₹1,200.",
    senderName: "Rahul",
    amountPaise: "120000",
    createdAt: "2026-06-08T10:00:00.000Z",
  };
}

describe("fingerprintToken — token-fingerprinting helper", () => {
  it("returns an 8-character hex string", () => {
    const fp = fingerprintToken("eEXAMPLEtoken1234567890");
    expect(fp).toMatch(/^[0-9a-f]{8}$/);
    expect(fp).toHaveLength(8);
  });

  it("is deterministic for the same input", () => {
    expect(fingerprintToken("foo")).toBe(fingerprintToken("foo"));
  });

  it("never reveals any substring of the raw token", () => {
    const raw = "very-recognisable-token-substring-xyz";
    const fp = fingerprintToken(raw);
    expect(fp).not.toContain("very");
    expect(fp).not.toContain("recognisable");
    expect(fp).not.toContain("token");
    expect(fp).not.toContain("xyz");
  });
});

describe("sendFcmToTokens — FR-AC-03 / notifications.md §1.4", () => {
  // -------------------------------------------------------------------------
  // Happy path
  // -------------------------------------------------------------------------
  it("sends ONE message per token in parallel and returns aggregated result", async () => {
    const {db} = createMockDbWithRecordedUpdates();
    const {messaging, sendFn} = createMockMessaging();
    const logger = createMockLogger();

    const result = await sendFcmToTokens(
      {db, messaging, logger},
      {
        userId: "uid-alice",
        notificationType: "expense_added",
        tokens: ["tokA", "tokB", "tokC"],
        payload: validPayload(),
      },
    );

    expect(sendFn).toHaveBeenCalledTimes(3);
    expect(result).toEqual({succeeded: 3, failed: 0, pruned: []});
  });

  it("packages the payload as FCM data + high-priority android/apns config", async () => {
    const {db} = createMockDbWithRecordedUpdates();
    const {messaging, sendFn} = createMockMessaging();
    const logger = createMockLogger();

    await sendFcmToTokens(
      {db, messaging, logger},
      {
        userId: "uid-alice",
        notificationType: "expense_added",
        tokens: ["tokA"],
        payload: validPayload(),
      },
    );

    // Cast to Record<string, unknown> for shape assertions — the mock
    // typed only `{token: string}` on input but the real call site
    // assembles the BaseMessage envelope (data, android, apns).
    const sentMessage = sendFn.mock.calls[0][0] as unknown as Record<
      string,
      Record<string, unknown>
    > & {token: string};
    expect(sentMessage.token).toBe("tokA");
    // §2.1 envelope: every value is a string.
    expect(sentMessage.data.type).toBe("expense_added");
    expect(sentMessage.data.contextType).toBe("friendship");
    expect(sentMessage.data.amountPaise).toBe("120000");
    // High-priority delivery on both platforms (§2.1).
    expect(sentMessage.android.priority).toBe("high");
    expect(
      (sentMessage.apns.headers as Record<string, string>)["apns-priority"],
    ).toBe("10");
    expect(
      ((sentMessage.apns.payload as Record<string, Record<string, unknown>>)
        .aps as Record<string, unknown>)["content-available"],
    ).toBe(1);
    // Data-only message: no top-level `notification` block per §2.
    expect(sentMessage.notification).toBeUndefined();
  });

  // -------------------------------------------------------------------------
  // Empty tokens array — no-op
  // -------------------------------------------------------------------------
  it("is a no-op for an empty tokens array (no admin-SDK call, no log)", async () => {
    const {db} = createMockDbWithRecordedUpdates();
    const {messaging, sendFn} = createMockMessaging();
    const logger = createMockLogger();

    const result = await sendFcmToTokens(
      {db, messaging, logger},
      {
        userId: "uid-alice",
        notificationType: "expense_added",
        tokens: [],
        payload: validPayload(),
      },
    );

    expect(sendFn).not.toHaveBeenCalled();
    expect(logger.calls).toHaveLength(0);
    expect(result).toEqual({succeeded: 0, failed: 0, pruned: []});
  });

  // -------------------------------------------------------------------------
  // 410 prune branch (AC-6)
  // -------------------------------------------------------------------------
  it("prunes a 410-failed token from users/{uid}.fcmTokens via arrayRemove", async () => {
    const {db, updateFn, collectionFn, docFn} =
      createMockDbWithRecordedUpdates();
    const {messaging} = createMockMessaging({
      not_registered_tokens: new Set(["tokDEAD"]),
    });
    const logger = createMockLogger();

    const result = await sendFcmToTokens(
      {db, messaging, logger},
      {
        userId: "uid-alice",
        notificationType: "expense_added",
        tokens: ["tokOK1", "tokDEAD", "tokOK2"],
        payload: validPayload(),
      },
    );

    expect(result.succeeded).toBe(2);
    expect(result.failed).toBe(1);
    expect(result.pruned).toEqual(["tokDEAD"]);

    // The arrayRemove call resolves to `users/uid-alice` with a
    // `fcmTokens: arrayRemove(tokDEAD)` update.
    expect(collectionFn).toHaveBeenCalledWith("users");
    expect(docFn).toHaveBeenCalledWith("uid-alice");
    expect(updateFn).toHaveBeenCalledTimes(1);
    const updatePayload = updateFn.mock.calls[0][0];
    expect(updatePayload).toHaveProperty("fcmTokens");
  });

  it("does NOT prune the token on non-410 errors (logs fcm_send_failed)", async () => {
    const {db, updateFn} = createMockDbWithRecordedUpdates();
    const {messaging} = createMockMessaging({
      generic_error_tokens: new Set(["tokFAIL"]),
    });
    const logger = createMockLogger();

    const result = await sendFcmToTokens(
      {db, messaging, logger},
      {
        userId: "uid-alice",
        notificationType: "expense_added",
        tokens: ["tokFAIL"],
        payload: validPayload(),
      },
    );

    expect(result.succeeded).toBe(0);
    expect(result.failed).toBe(1);
    expect(result.pruned).toEqual([]);
    expect(updateFn).not.toHaveBeenCalled();

    const failedLog = logger.calls.find(
      (c) => c.data?.event === "fcm_send_failed",
    );
    expect(failedLog).toBeDefined();
    expect(failedLog!.level).toBe("error");
    expect(failedLog!.data!.errorCode).toBe("messaging/internal-error");
    expect(failedLog!.data!.notificationType).toBe("expense_added");
  });

  // -------------------------------------------------------------------------
  // Structured-log contract (AC-14)
  // -------------------------------------------------------------------------
  it("emits fcm_send_attempted once with userIdHash + notificationType + tokenCount", async () => {
    const {db} = createMockDbWithRecordedUpdates();
    const {messaging} = createMockMessaging();
    const logger = createMockLogger();

    await sendFcmToTokens(
      {db, messaging, logger},
      {
        userId: "uid-alice",
        notificationType: "expense_added",
        tokens: ["tokA", "tokB"],
        payload: validPayload(),
      },
    );

    const attemptedLogs = logger.calls.filter(
      (c) => c.data?.event === "fcm_send_attempted",
    );
    expect(attemptedLogs).toHaveLength(1);
    expect(attemptedLogs[0].data!.userIdHash).toMatch(/^[0-9a-f]{16}$/);
    expect(attemptedLogs[0].data!.notificationType).toBe("expense_added");
    expect(attemptedLogs[0].data!.tokenCount).toBe(2);
  });

  it("emits fcm_send_succeeded per successful send with userIdHash + tokenFingerprint", async () => {
    const {db} = createMockDbWithRecordedUpdates();
    const {messaging} = createMockMessaging();
    const logger = createMockLogger();

    await sendFcmToTokens(
      {db, messaging, logger},
      {
        userId: "uid-alice",
        notificationType: "expense_added",
        tokens: ["tokA", "tokB"],
        payload: validPayload(),
      },
    );

    const succeededLogs = logger.calls.filter(
      (c) => c.data?.event === "fcm_send_succeeded",
    );
    expect(succeededLogs).toHaveLength(2);
    for (const log of succeededLogs) {
      expect(log.data!.userIdHash).toMatch(/^[0-9a-f]{16}$/);
      expect(log.data!.tokenFingerprint).toMatch(/^[0-9a-f]{8}$/);
      expect(log.data!.notificationType).toBe("expense_added");
    }
  });

  it("emits fcm_token_pruned per 410 prune with userIdHash + tokenFingerprint", async () => {
    const {db} = createMockDbWithRecordedUpdates();
    const {messaging} = createMockMessaging({
      not_registered_tokens: new Set(["tokDEAD"]),
    });
    const logger = createMockLogger();

    await sendFcmToTokens(
      {db, messaging, logger},
      {
        userId: "uid-alice",
        notificationType: "expense_added",
        tokens: ["tokDEAD"],
        payload: validPayload(),
      },
    );

    const prunedLogs = logger.calls.filter(
      (c) => c.data?.event === "fcm_token_pruned",
    );
    expect(prunedLogs).toHaveLength(1);
    expect(prunedLogs[0].data!.userIdHash).toMatch(/^[0-9a-f]{16}$/);
    expect(prunedLogs[0].data!.tokenFingerprint).toMatch(/^[0-9a-f]{8}$/);
  });

  // -------------------------------------------------------------------------
  // PII guard (AC-14)
  // -------------------------------------------------------------------------
  it("never logs the raw FCM token (only the 8-char SHA-256 fingerprint)", async () => {
    const recognisableToken = "VERY_RECOGNISABLE_FCM_TOKEN_qwerty1234567890";
    const {db} = createMockDbWithRecordedUpdates();
    const {messaging} = createMockMessaging({
      not_registered_tokens: new Set([recognisableToken]),
    });
    const logger = createMockLogger();

    await sendFcmToTokens(
      {db, messaging, logger},
      {
        userId: "uid-alice",
        notificationType: "expense_added",
        tokens: [recognisableToken],
        payload: validPayload(),
      },
    );

    for (const call of logger.calls) {
      const serialised = JSON.stringify(call.data ?? {});
      expect(serialised).not.toContain(recognisableToken);
      expect(serialised).not.toContain("RECOGNISABLE");
      expect(serialised).not.toContain("qwerty1234567890");
    }
  });

  it("never logs the raw userId (only the 16-char SHA-256 hash via hashId)", async () => {
    const recognisableUserId = "pii-uid-recognisable-substring";
    const {db} = createMockDbWithRecordedUpdates();
    const {messaging} = createMockMessaging();
    const logger = createMockLogger();

    await sendFcmToTokens(
      {db, messaging, logger},
      {
        userId: recognisableUserId,
        notificationType: "expense_added",
        tokens: ["tokA"],
        payload: validPayload(),
      },
    );

    for (const call of logger.calls) {
      const serialised = JSON.stringify(call.data ?? {});
      expect(serialised).not.toContain(recognisableUserId);
      expect(serialised).not.toContain("recognisable");
    }
  });
});
