/**
 * Function-boundary tests for the FR-SE-09 sendReminderNotification
 * callable.
 *
 * Mirrors `functions/test/lookup-user-by-phone-number/function.test.ts`
 * (DI-mocked Firestore + logger; no emulator). Exercises every AC
 * in the FR-SE-09 contract:
 *
 *   - AC-1   happy path → success + rate-limit doc + FCM dispatch +
 *            activity emission.
 *   - AC-3   unauth → UNAUTHENTICATED.
 *   - AC-4   malformed input → INVALID_INPUT (multiple shapes).
 *   - AC-5   non-member → NOT_A_MEMBER.
 *   - AC-6   recipient doesn't owe → RECIPIENT_DOESNT_OWE.
 *   - AC-7   rate-limit within 24h window → RATE_LIMITED + nextAllowedAtIso.
 *   - AC-8   rate-limit post-window → pass + rewrite.
 *   - AC-9   prefs disabled → RECIPIENT_PREFS_DISABLED.
 *   - AC-10  no tokens → RECIPIENT_NO_TOKENS.
 *   - AC-11  full-failure dispatch → FCM_DISPATCH_FAILED + no rate-
 *            limit write.
 *   - AC-12  group-context → GROUP_CONTEXT_NOT_SUPPORTED.
 *   - AC-19  structured-log PII guard.
 *   - AC-21  no simplifiedBalances writes.
 *   - AC-22  no notificationPrefs writes.
 *
 * @module test/send-reminder-notification/function.test.ts
 */

import {HttpsError} from "firebase-functions/v2/https";
import {
  createSendReminderHandler,
  SendReminderFunctionDeps,
} from "../../src/send-reminder-notification/function";

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

interface FriendshipDocSnapshot {
  exists: boolean;
  data: Record<string, unknown> | null;
}

interface UserDocSnapshot {
  exists: boolean;
  data: Record<string, unknown> | null;
}

interface RateLimitDocSnapshot {
  exists: boolean;
  data: Record<string, unknown> | null;
}

interface MockDbState {
  friendship: FriendshipDocSnapshot;
  sender: UserDocSnapshot;
  recipient: UserDocSnapshot;
  rateLimit: RateLimitDocSnapshot;
  /** When true, the rate-limit doc write throws to simulate transient. */
  rateLimitWriteThrows?: boolean;
}

/**
 * Captures every Firestore write for assertions. Each entry records
 * the doc-path string and the payload passed to set / update.
 */
interface CapturedWrites {
  rateLimitSets: Array<Record<string, unknown>>;
  activityAdds: Array<{recipient: string; payload: Record<string, unknown>}>;
}

/**
 * Builds a mock Firestore that returns scripted snapshots for
 *   - `friendships/{contextId}` reads,
 *   - `users/{senderUid}` and `users/{recipientUid}` reads,
 *   - `_rateLimits/{senderUid}/sends/{recipientUid}` reads + writes,
 *   - `activity/{recipientUid}/items` add.
 *
 * The callable's exact read order and doc-paths are asserted by the
 * tests by exercising the public callable handler and observing the
 * resulting writes + log events; the mock supports both `.doc()` and
 * `.collection().doc()` access patterns used by the handler.
 */
function createMockDb(state: MockDbState): {
  db: FirebaseFirestore.Firestore;
  writes: CapturedWrites;
} {
  const writes: CapturedWrites = {
    rateLimitSets: [],
    activityAdds: [],
  };

  const collectionFn = jest.fn((collectionId: string) => {
    if (collectionId === "friendships") {
      return {
        doc: jest.fn(() => ({
          get: jest.fn().mockResolvedValue({
            exists: state.friendship.exists,
            data: () => state.friendship.data ?? undefined,
          }),
        })),
      };
    }
    if (collectionId === "users") {
      return {
        doc: jest.fn((userId: string) => {
          const snap = userId === "uid-sender" ? state.sender :
            state.recipient;
          return {
            get: jest.fn().mockResolvedValue({
              exists: snap.exists,
              data: () => snap.data ?? undefined,
            }),
          };
        }),
      };
    }
    if (collectionId === "activity") {
      return {
        doc: jest.fn((recipientUid: string) => ({
          collection: jest.fn(() => ({
            add: jest.fn((payload: Record<string, unknown>) => {
              writes.activityAdds.push({recipient: recipientUid, payload});
              return Promise.resolve({id: `act-${writes.activityAdds.length}`});
            }),
          })),
        })),
      };
    }
    throw new Error(`Mock db: unexpected collection '${collectionId}'`);
  });

  const docFn = jest.fn((docPath: string) => {
    if (
      docPath.startsWith("_rateLimits/") &&
      docPath.includes("/sends/")
    ) {
      return {
        get: jest.fn().mockResolvedValue({
          exists: state.rateLimit.exists,
          data: () => state.rateLimit.data ?? undefined,
        }),
        set: jest.fn((payload: Record<string, unknown>) => {
          if (state.rateLimitWriteThrows) {
            return Promise.reject(new Error("rate-limit write failed"));
          }
          writes.rateLimitSets.push(payload);
          return Promise.resolve();
        }),
      };
    }
    throw new Error(`Mock db: unexpected doc path '${docPath}'`);
  });

  return {
    db: {
      collection: collectionFn,
      doc: docFn,
    } as unknown as FirebaseFirestore.Firestore,
    writes,
  };
}

function createDeps(state: Partial<MockDbState> = {}): {
  deps: SendReminderFunctionDeps;
  logger: ReturnType<typeof createMockLogger>;
  writes: CapturedWrites;
  fcmDispatch: jest.Mock;
} {
  const defaults: MockDbState = {
    friendship: {
      exists: true,
      data: {
        memberIds: ["uid-sender", "uid-recipient"],
        simplifiedBalances: {
          "uid-recipient": {"uid-sender": 50000},
        },
      },
    },
    sender: {
      exists: true,
      data: {
        displayName: "Avtansh",
      },
    },
    recipient: {
      exists: true,
      data: {
        displayName: "Priya",
        fcmTokens: ["tokRec1", "tokRec2"],
        notificationPrefs: {
          newExpense: true,
          settlement: true,
          reminder: true,
        },
      },
    },
    rateLimit: {exists: false, data: null},
  };
  const merged: MockDbState = {...defaults, ...state};
  const {db, writes} = createMockDb(merged);
  const logger = createMockLogger();
  const fcmDispatch = jest.fn().mockResolvedValue({
    succeeded: 2,
    failed: 0,
    pruned: [],
    suppressedByPrefs: 0,
    skippedEmptyTokens: 0,
    skippedMissingUser: 0,
  });
  const deps: SendReminderFunctionDeps = {
    db,
    logger,
    sendReminderFcm: fcmDispatch,
    now: () => new Date("2026-06-08T12:00:00Z"),
  };
  return {deps, logger, writes, fcmDispatch};
}

function authContext(uid: string) {
  return {auth: {uid}};
}

function noAuthContext() {
  return {};
}

const validInput = {
  toUserId: "uid-recipient",
  contextType: "friendship" as const,
  contextId: "uid-sender_uid-recipient",
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("sendReminderNotification handler — FR-SE-09", () => {
  // -----------------------------------------------------------------------
  // AC-1 / AC-2 — happy path
  // -----------------------------------------------------------------------
  it("AC-1: happy path returns nextAllowedAtIso and writes rate-limit doc",
    async () => {
      const {deps, writes} = createDeps();
      const handler = createSendReminderHandler(deps);

      const result = await handler(validInput, authContext("uid-sender"));

      // now (mocked) is 2026-06-08T12:00:00Z; +24h is 2026-06-09T12:00:00Z
      expect(result).toEqual({
        success: true,
        nextAllowedAtIso: "2026-06-09T12:00:00.000Z",
      });
      expect(writes.rateLimitSets).toHaveLength(1);
      const written = writes.rateLimitSets[0];
      expect(written.recipientUid).toBe("uid-recipient");
      expect(written.senderUid).toBe("uid-sender");
      expect(typeof written.lastSentAt).toBe("object");
      expect(typeof written.windowStart).toBe("number");
      expect(written.count).toBeDefined();
    });

  it("AC-1: happy path calls sendReminderFcm with correct params", async () => {
    const {deps, fcmDispatch} = createDeps();
    const handler = createSendReminderHandler(deps);

    await handler(validInput, authContext("uid-sender"));

    expect(fcmDispatch).toHaveBeenCalledTimes(1);
    const params = fcmDispatch.mock.calls[0][1];
    expect(params.fromUserId).toBe("uid-sender");
    expect(params.toUserId).toBe("uid-recipient");
    expect(params.senderName).toBe("Avtansh");
    expect(params.amountPaise).toBe(50000);
    expect(params.contextType).toBe("friendship");
    expect(params.contextId).toBe("uid-sender_uid-recipient");
  });

  it("AC-2: happy path emits activity item to recipient ONLY", async () => {
    const {deps, writes} = createDeps();
    const handler = createSendReminderHandler(deps);

    await handler(validInput, authContext("uid-sender"));

    expect(writes.activityAdds).toHaveLength(1);
    const entry = writes.activityAdds[0];
    expect(entry.recipient).toBe("uid-recipient");
    expect(entry.payload.type).toBe("reminder");
    const payload = entry.payload.payload as Record<string, unknown>;
    expect(payload.senderUid).toBe("uid-sender");
    expect(payload.recipientUid).toBe("uid-recipient");
    expect(payload.amountPaise).toBe(50000);
    expect(payload.contextType).toBe("friendship");
    expect(payload.contextId).toBe("uid-sender_uid-recipient");
  });

  // -----------------------------------------------------------------------
  // AC-3 — unauth
  // -----------------------------------------------------------------------
  it("AC-3: throws UNAUTHENTICATED when request.auth is missing", async () => {
    const {deps, writes, fcmDispatch} = createDeps();
    const handler = createSendReminderHandler(deps);

    try {
      await handler(validInput, noAuthContext());
      fail("Expected HttpsError to be thrown");
    } catch (err) {
      expect(err).toBeInstanceOf(HttpsError);
      const e = err as HttpsError;
      expect(e.code).toBe("unauthenticated");
      expect((e.details as {errorCode: string}).errorCode).toBe(
        "UNAUTHENTICATED",
      );
    }
    expect(fcmDispatch).not.toHaveBeenCalled();
    expect(writes.rateLimitSets).toHaveLength(0);
    expect(writes.activityAdds).toHaveLength(0);
  });

  // -----------------------------------------------------------------------
  // AC-4 — malformed input
  // -----------------------------------------------------------------------
  it("AC-4: throws INVALID_INPUT when toUserId is missing", async () => {
    const {deps} = createDeps();
    const handler = createSendReminderHandler(deps);

    try {
      await handler(
        {contextType: "friendship", contextId: "uid-sender_uid-recipient"},
        authContext("uid-sender"),
      );
      fail("Expected HttpsError to be thrown");
    } catch (err) {
      expect(err).toBeInstanceOf(HttpsError);
      const e = err as HttpsError;
      expect(e.code).toBe("invalid-argument");
      expect((e.details as {errorCode: string}).errorCode).toBe(
        "INVALID_INPUT",
      );
    }
  });

  it("AC-4: throws INVALID_INPUT when toUserId is empty string", async () => {
    const {deps} = createDeps();
    const handler = createSendReminderHandler(deps);
    await expect(
      handler({...validInput, toUserId: ""}, authContext("uid-sender")),
    ).rejects.toMatchObject({
      code: "invalid-argument",
      details: {errorCode: "INVALID_INPUT"},
    });
  });

  it("AC-4: throws INVALID_INPUT when contextId is empty string", async () => {
    const {deps} = createDeps();
    const handler = createSendReminderHandler(deps);
    await expect(
      handler({...validInput, contextId: ""}, authContext("uid-sender")),
    ).rejects.toMatchObject({
      code: "invalid-argument",
      details: {errorCode: "INVALID_INPUT"},
    });
  });

  it("AC-4: throws INVALID_INPUT when contextType is invalid", async () => {
    const {deps} = createDeps();
    const handler = createSendReminderHandler(deps);
    await expect(
      handler(
        {...validInput, contextType: "wedding" as unknown as "friendship"},
        authContext("uid-sender"),
      ),
    ).rejects.toMatchObject({
      code: "invalid-argument",
      details: {errorCode: "INVALID_INPUT"},
    });
  });

  it("AC-4: throws INVALID_INPUT when message exceeds 500 chars", async () => {
    const {deps} = createDeps();
    const handler = createSendReminderHandler(deps);
    const tooLong = "x".repeat(501);
    await expect(
      handler(
        {...validInput, message: tooLong},
        authContext("uid-sender"),
      ),
    ).rejects.toMatchObject({
      code: "invalid-argument",
      details: {errorCode: "INVALID_INPUT"},
    });
  });

  // -----------------------------------------------------------------------
  // AC-5 — non-member
  // -----------------------------------------------------------------------
  it("AC-5: throws NOT_A_MEMBER when caller is not in friendship.memberIds",
    async () => {
      const {deps, writes, fcmDispatch} = createDeps({
        friendship: {
          exists: true,
          data: {
            memberIds: ["uid-other", "uid-recipient"],
            simplifiedBalances: {
              "uid-recipient": {"uid-other": 50000},
            },
          },
        },
      });
      const handler = createSendReminderHandler(deps);

      await expect(
        handler(validInput, authContext("uid-sender")),
      ).rejects.toMatchObject({
        code: "permission-denied",
        details: {errorCode: "NOT_A_MEMBER"},
      });
      expect(fcmDispatch).not.toHaveBeenCalled();
      expect(writes.rateLimitSets).toHaveLength(0);
      expect(writes.activityAdds).toHaveLength(0);
    });

  it("AC-5: throws NOT_A_MEMBER when friendship doc does not exist",
    async () => {
      const {deps} = createDeps({
        friendship: {exists: false, data: null},
      });
      const handler = createSendReminderHandler(deps);

      await expect(
        handler(validInput, authContext("uid-sender")),
      ).rejects.toMatchObject({
        code: "permission-denied",
        details: {errorCode: "NOT_A_MEMBER"},
      });
    });

  // -----------------------------------------------------------------------
  // AC-6 — recipient doesn't owe
  // -----------------------------------------------------------------------
  it("AC-6: throws RECIPIENT_DOESNT_OWE when simplifiedBalances has no entry",
    async () => {
      const {deps, writes, fcmDispatch} = createDeps({
        friendship: {
          exists: true,
          data: {
            memberIds: ["uid-sender", "uid-recipient"],
            simplifiedBalances: {},
          },
        },
      });
      const handler = createSendReminderHandler(deps);

      await expect(
        handler(validInput, authContext("uid-sender")),
      ).rejects.toMatchObject({
        code: "failed-precondition",
        details: {errorCode: "RECIPIENT_DOESNT_OWE"},
      });
      expect(fcmDispatch).not.toHaveBeenCalled();
      expect(writes.rateLimitSets).toHaveLength(0);
      expect(writes.activityAdds).toHaveLength(0);
    });

  it("AC-6: throws RECIPIENT_DOESNT_OWE when sender is the debtor",
    async () => {
      const {deps} = createDeps({
        friendship: {
          exists: true,
          data: {
            memberIds: ["uid-sender", "uid-recipient"],
            simplifiedBalances: {
              "uid-sender": {"uid-recipient": 50000},
            },
          },
        },
      });
      const handler = createSendReminderHandler(deps);

      await expect(
        handler(validInput, authContext("uid-sender")),
      ).rejects.toMatchObject({
        code: "failed-precondition",
        details: {errorCode: "RECIPIENT_DOESNT_OWE"},
      });
    });

  it("AC-6: throws RECIPIENT_DOESNT_OWE when owed amount is zero",
    async () => {
      const {deps} = createDeps({
        friendship: {
          exists: true,
          data: {
            memberIds: ["uid-sender", "uid-recipient"],
            simplifiedBalances: {
              "uid-recipient": {"uid-sender": 0},
            },
          },
        },
      });
      const handler = createSendReminderHandler(deps);

      await expect(
        handler(validInput, authContext("uid-sender")),
      ).rejects.toMatchObject({
        code: "failed-precondition",
        details: {errorCode: "RECIPIENT_DOESNT_OWE"},
      });
    });

  // -----------------------------------------------------------------------
  // AC-7 / AC-8 — rate limit
  // -----------------------------------------------------------------------
  it("AC-7: throws RATE_LIMITED when prior send within 24h window",
    async () => {
      // Mock now() = 2026-06-08T12:00:00Z; prior send 12h ago.
      const twelveHoursAgoMs = new Date("2026-06-08T00:00:00Z").getTime();
      const {deps, writes, fcmDispatch} = createDeps({
        rateLimit: {
          exists: true,
          data: {
            lastSentAt: {toMillis: () => twelveHoursAgoMs},
            count: 1,
            windowStart: twelveHoursAgoMs,
            recipientUid: "uid-recipient",
            senderUid: "uid-sender",
          },
        },
      });
      const handler = createSendReminderHandler(deps);

      try {
        await handler(validInput, authContext("uid-sender"));
        fail("Expected RATE_LIMITED");
      } catch (err) {
        expect(err).toBeInstanceOf(HttpsError);
        const e = err as HttpsError;
        expect(e.code).toBe("resource-exhausted");
        const details = e.details as {
          errorCode: string;
          nextAllowedAtIso: string;
        };
        expect(details.errorCode).toBe("RATE_LIMITED");
        // lastSentAt + 24h = 2026-06-09T00:00:00.000Z
        expect(details.nextAllowedAtIso).toBe("2026-06-09T00:00:00.000Z");
      }
      expect(fcmDispatch).not.toHaveBeenCalled();
      expect(writes.rateLimitSets).toHaveLength(0);
    });

  it("AC-8: passes when prior send was > 24h ago and writes new rate-limit",
    async () => {
      // Mock now() = 2026-06-08T12:00:00Z; prior send 25h ago.
      const twentyFiveHoursAgoMs =
        new Date("2026-06-07T11:00:00Z").getTime();
      const {deps, writes} = createDeps({
        rateLimit: {
          exists: true,
          data: {
            lastSentAt: {toMillis: () => twentyFiveHoursAgoMs},
            count: 1,
            windowStart: twentyFiveHoursAgoMs,
            recipientUid: "uid-recipient",
            senderUid: "uid-sender",
          },
        },
      });
      const handler = createSendReminderHandler(deps);

      const result = await handler(validInput, authContext("uid-sender"));
      expect(result.success).toBe(true);
      expect(writes.rateLimitSets).toHaveLength(1);
    });

  // -----------------------------------------------------------------------
  // AC-9 — prefs disabled
  // -----------------------------------------------------------------------
  it("AC-9: throws RECIPIENT_PREFS_DISABLED when recipient prefs.reminder=false",
    async () => {
      const {deps, writes, fcmDispatch} = createDeps({
        recipient: {
          exists: true,
          data: {
            displayName: "Priya",
            fcmTokens: ["tokRec"],
            notificationPrefs: {
              newExpense: true,
              settlement: true,
              reminder: false,
            },
          },
        },
      });
      const handler = createSendReminderHandler(deps);

      await expect(
        handler(validInput, authContext("uid-sender")),
      ).rejects.toMatchObject({
        code: "failed-precondition",
        details: {errorCode: "RECIPIENT_PREFS_DISABLED"},
      });
      expect(fcmDispatch).not.toHaveBeenCalled();
      expect(writes.rateLimitSets).toHaveLength(0);
      expect(writes.activityAdds).toHaveLength(0);
    });

  // -----------------------------------------------------------------------
  // AC-10 — no tokens
  // -----------------------------------------------------------------------
  it("AC-10: throws RECIPIENT_NO_TOKENS when recipient has empty fcmTokens",
    async () => {
      const {deps, writes, fcmDispatch} = createDeps({
        recipient: {
          exists: true,
          data: {
            displayName: "Priya",
            fcmTokens: [],
            notificationPrefs: {reminder: true},
          },
        },
      });
      const handler = createSendReminderHandler(deps);

      await expect(
        handler(validInput, authContext("uid-sender")),
      ).rejects.toMatchObject({
        code: "failed-precondition",
        details: {errorCode: "RECIPIENT_NO_TOKENS"},
      });
      expect(fcmDispatch).not.toHaveBeenCalled();
      expect(writes.rateLimitSets).toHaveLength(0);
      expect(writes.activityAdds).toHaveLength(0);
    });

  it("AC-10: throws RECIPIENT_NO_TOKENS when fcmTokens field is missing",
    async () => {
      const {deps} = createDeps({
        recipient: {
          exists: true,
          data: {displayName: "Priya", notificationPrefs: {reminder: true}},
        },
      });
      const handler = createSendReminderHandler(deps);

      await expect(
        handler(validInput, authContext("uid-sender")),
      ).rejects.toMatchObject({
        code: "failed-precondition",
        details: {errorCode: "RECIPIENT_NO_TOKENS"},
      });
    });

  // -----------------------------------------------------------------------
  // AC-11 — full-failure dispatch
  // -----------------------------------------------------------------------
  it("AC-11: throws FCM_DISPATCH_FAILED when dispatch reports zero succeeded",
    async () => {
      const {deps, writes, fcmDispatch} = createDeps();
      fcmDispatch.mockResolvedValueOnce({
        succeeded: 0,
        failed: 2,
        pruned: ["tokRec1", "tokRec2"],
        suppressedByPrefs: 0,
        skippedEmptyTokens: 0,
        skippedMissingUser: 0,
      });
      const handler = createSendReminderHandler(deps);

      await expect(
        handler(validInput, authContext("uid-sender")),
      ).rejects.toMatchObject({
        code: "unavailable",
        details: {errorCode: "FCM_DISPATCH_FAILED"},
      });
      // Rate-limit NOT recorded on full-failure dispatch.
      expect(writes.rateLimitSets).toHaveLength(0);
      // Activity NOT emitted either — no "send" happened.
      expect(writes.activityAdds).toHaveLength(0);
    });

  // -----------------------------------------------------------------------
  // AC-12 — group-context forward-compat
  // -----------------------------------------------------------------------
  it("AC-12: throws GROUP_CONTEXT_NOT_SUPPORTED for contextType='group'",
    async () => {
      const {deps, writes, fcmDispatch} = createDeps();
      const handler = createSendReminderHandler(deps);

      await expect(
        handler(
          {...validInput, contextType: "group", contextId: "grp-1"},
          authContext("uid-sender"),
        ),
      ).rejects.toMatchObject({
        code: "unimplemented",
        details: {errorCode: "GROUP_CONTEXT_NOT_SUPPORTED"},
      });
      expect(fcmDispatch).not.toHaveBeenCalled();
      expect(writes.rateLimitSets).toHaveLength(0);
    });

  // -----------------------------------------------------------------------
  // AC-19 — PII guard in structured logs
  // -----------------------------------------------------------------------
  it("AC-19: log events hash all uid params and never include raw uids",
    async () => {
      const {deps, logger} = createDeps();
      const handler = createSendReminderHandler(deps);

      await handler(validInput, authContext("uid-sender"));

      const raw = JSON.stringify(logger.calls);
      expect(raw).not.toContain("uid-sender");
      expect(raw).not.toContain("uid-recipient");

      // Verify the attempted + succeeded logs were emitted with hashed ids.
      const attempted = logger.calls.find(
        (c) => c.data?.event === "reminder_send_attempted",
      );
      expect(attempted).toBeDefined();
      expect(attempted!.data!.senderUidHash).toMatch(/^[0-9a-f]{16}$/);
      expect(attempted!.data!.recipientUidHash).toMatch(/^[0-9a-f]{16}$/);

      const succeeded = logger.calls.find(
        (c) => c.data?.event === "reminder_send_succeeded",
      );
      expect(succeeded).toBeDefined();
      expect(succeeded!.data!.contextIdHash).toMatch(/^[0-9a-f]{16}$/);
    });

  it("AC-19: rate-limited log event hashes recipient and contextId", async () => {
    const twelveHoursAgoMs = new Date("2026-06-08T00:00:00Z").getTime();
    const {deps, logger} = createDeps({
      rateLimit: {
        exists: true,
        data: {
          lastSentAt: {toMillis: () => twelveHoursAgoMs},
          count: 1,
          windowStart: twelveHoursAgoMs,
        },
      },
    });
    const handler = createSendReminderHandler(deps);

    try {
      await handler(validInput, authContext("uid-sender"));
    } catch {
      // expected
    }
    const log = logger.calls.find(
      (c) => c.data?.event === "reminder_send_rate_limited",
    );
    expect(log).toBeDefined();
    expect(log!.data!.senderUidHash).toMatch(/^[0-9a-f]{16}$/);
    expect(log!.data!.recipientUidHash).toMatch(/^[0-9a-f]{16}$/);
    expect(log!.data!.nextAllowedAtIso).toBe("2026-06-09T00:00:00.000Z");
  });

  it("AC-19: optional message body never appears in logs (only presence)",
    async () => {
      const {deps, logger} = createDeps();
      const handler = createSendReminderHandler(deps);

      await handler(
        {...validInput, message: "Pay me back already!!"},
        authContext("uid-sender"),
      );

      const raw = JSON.stringify(logger.calls);
      expect(raw).not.toContain("Pay me back");
      const succeeded = logger.calls.find(
        (c) => c.data?.event === "reminder_send_succeeded",
      );
      expect(succeeded).toBeDefined();
      expect(succeeded!.data!.messageLength).toBe(21);
    });
});
