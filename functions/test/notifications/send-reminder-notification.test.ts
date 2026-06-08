/**
 * Unit tests for the FCM-dispatch helper used by the FR-SE-09 send-
 * reminder callable.
 *
 * Mirrors `send-settlement-notification.test.ts` (single-recipient
 * shape). The helper composes user-doc read → prefs-filter →
 * empty-tokens short-circuit → `renderPayload('reminder', ...)` →
 * `sendFcmToTokens`. Like the other two helpers, it does NOT throw —
 * the callable consumes the typed `NotificationDispatchResult` tally
 * and maps to its own `HttpsError` codes.
 *
 * @module test/notifications/send-reminder-notification.test.ts
 */

import {sendReminderNotification} from
  "../../src/notifications/send-reminder-notification";
import {sendFcmToTokens} from "../../src/notifications/fcm-send";

jest.mock("../../src/notifications/fcm-send", () => {
  const actual = jest.requireActual("../../src/notifications/fcm-send");
  return {
    ...actual,
    sendFcmToTokens: jest.fn().mockResolvedValue({
      succeeded: 1,
      failed: 0,
      pruned: [],
    }),
  };
});

const mockedSendFcmToTokens = sendFcmToTokens as jest.MockedFunction<
  typeof sendFcmToTokens
>;

beforeEach(() => {
  mockedSendFcmToTokens.mockClear();
  mockedSendFcmToTokens.mockResolvedValue({
    succeeded: 1,
    failed: 0,
    pruned: [],
  });
});

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

function createMockDb(
  users: Record<string, Record<string, unknown> | null>,
): FirebaseFirestore.Firestore {
  const docFn = jest.fn((userId: string) => ({
    get: jest.fn().mockResolvedValue({
      exists: users[userId] !== undefined && users[userId] !== null,
      data: () => users[userId] ?? undefined,
      id: userId,
    }),
  }));
  return {
    collection: jest.fn().mockReturnValue({doc: docFn}),
  } as unknown as FirebaseFirestore.Firestore;
}

function createMockMessaging() {
  return {} as unknown as import("firebase-admin/messaging").Messaging;
}

const baseParams = {
  fromUserId: "uid-sender",
  toUserId: "uid-recipient",
  contextType: "friendship" as const,
  contextId: "uid-sender_uid-recipient",
  senderName: "Avtansh",
  amountPaise: 50000,
  eventTimestamp: new Date("2026-06-08T10:00:00Z"),
};

describe("sendReminderNotification — FR-SE-09 FCM helper", () => {
  it("dispatches reminder to recipient when prefs allow and tokens non-empty",
    async () => {
      const db = createMockDb({
        "uid-recipient": {
          fcmTokens: ["tokRec1", "tokRec2"],
          notificationPrefs: {
            newExpense: true,
            settlement: true,
            reminder: true,
          },
        },
      });
      const logger = createMockLogger();

      const result = await sendReminderNotification(
        {db, logger, messaging: createMockMessaging()},
        baseParams,
      );

      expect(mockedSendFcmToTokens).toHaveBeenCalledTimes(1);
      const callArgs = mockedSendFcmToTokens.mock.calls[0][1];
      expect(callArgs.userId).toBe("uid-recipient");
      expect(callArgs.tokens).toEqual(["tokRec1", "tokRec2"]);
      expect(callArgs.notificationType).toBe("reminder");
      expect(callArgs.payload.title).toBe("Reminder from Avtansh");
      expect(callArgs.payload.body).toBe(
        "Avtansh is nudging you about \u20B9500.",
      );
      expect(result.succeeded).toBe(1);
    });

  it("does NOT read or send to the sender (fromUserId — the actor)", async () => {
    const db = createMockDb({
      "uid-sender": {
        fcmTokens: ["tokSender"],
        notificationPrefs: {
          newExpense: true,
          settlement: true,
          reminder: true,
        },
      },
      "uid-recipient": {
        fcmTokens: ["tokRec"],
        notificationPrefs: {
          newExpense: true,
          settlement: true,
          reminder: true,
        },
      },
    });
    const logger = createMockLogger();

    await sendReminderNotification(
      {db, logger, messaging: createMockMessaging()},
      baseParams,
    );

    expect(mockedSendFcmToTokens).toHaveBeenCalledTimes(1);
    expect(mockedSendFcmToTokens.mock.calls[0][1].userId).toBe("uid-recipient");
  });

  it("suppresses send when reminder=false (logs fcm_send_suppressed_by_prefs)",
    async () => {
      const db = createMockDb({
        "uid-recipient": {
          fcmTokens: ["tokRec"],
          notificationPrefs: {
            newExpense: true,
            settlement: true,
            reminder: false,
          },
        },
      });
      const logger = createMockLogger();

      const result = await sendReminderNotification(
        {db, logger, messaging: createMockMessaging()},
        baseParams,
      );

      expect(mockedSendFcmToTokens).not.toHaveBeenCalled();
      expect(result.suppressedByPrefs).toBe(1);
      const suppressedLog = logger.calls.find(
        (c) => c.data?.event === "fcm_send_suppressed_by_prefs",
      );
      expect(suppressedLog).toBeDefined();
      expect(suppressedLog!.data!.notificationType).toBe("reminder");
    });

  it("logs fcm_send_skipped_empty_tokens when recipient has no tokens",
    async () => {
      const db = createMockDb({
        "uid-recipient": {
          fcmTokens: [],
          notificationPrefs: {
            newExpense: true,
            settlement: true,
            reminder: true,
          },
        },
      });
      const logger = createMockLogger();

      const result = await sendReminderNotification(
        {db, logger, messaging: createMockMessaging()},
        baseParams,
      );

      expect(mockedSendFcmToTokens).not.toHaveBeenCalled();
      expect(result.skippedEmptyTokens).toBe(1);
      const skipLog = logger.calls.find(
        (c) => c.data?.event === "fcm_send_skipped_empty_tokens",
      );
      expect(skipLog).toBeDefined();
    });

  it("logs fcm_send_skipped_missing_user when recipient doc does not exist",
    async () => {
      const db = createMockDb({});
      const logger = createMockLogger();

      const result = await sendReminderNotification(
        {db, logger, messaging: createMockMessaging()},
        baseParams,
      );

      expect(mockedSendFcmToTokens).not.toHaveBeenCalled();
      expect(result.skippedMissingUser).toBe(1);
      const skipLog = logger.calls.find(
        (c) => c.data?.event === "fcm_send_skipped_missing_user",
      );
      expect(skipLog).toBeDefined();
    });

  it("defaults to reminder=true when notificationPrefs map is absent",
    async () => {
      const db = createMockDb({
        "uid-recipient": {
          fcmTokens: ["tokRec"],
        },
      });
      const logger = createMockLogger();

      await sendReminderNotification(
        {db, logger, messaging: createMockMessaging()},
        baseParams,
      );

      expect(mockedSendFcmToTokens).toHaveBeenCalledTimes(1);
    });

  it("propagates the dispatch result counts unchanged", async () => {
    mockedSendFcmToTokens.mockResolvedValueOnce({
      succeeded: 2,
      failed: 1,
      pruned: ["tokDead"],
    });
    const db = createMockDb({
      "uid-recipient": {
        fcmTokens: ["tokA", "tokB", "tokDead"],
        notificationPrefs: {
          newExpense: true,
          settlement: true,
          reminder: true,
        },
      },
    });
    const logger = createMockLogger();

    const result = await sendReminderNotification(
      {db, logger, messaging: createMockMessaging()},
      baseParams,
    );

    expect(result.succeeded).toBe(2);
    expect(result.failed).toBe(1);
    expect(result.pruned).toEqual(["tokDead"]);
  });

  it("hashes the recipient userId in suppressed-by-prefs log (PII guard)",
    async () => {
      const db = createMockDb({
        "uid-recipient": {
          fcmTokens: ["tokRec"],
          notificationPrefs: {reminder: false},
        },
      });
      const logger = createMockLogger();

      await sendReminderNotification(
        {db, logger, messaging: createMockMessaging()},
        baseParams,
      );

      const suppressed = logger.calls.find(
        (c) => c.data?.event === "fcm_send_suppressed_by_prefs",
      );
      expect(suppressed).toBeDefined();
      // Hashed userId is 16-hex-char SHA-256 prefix; raw uid must not appear.
      const raw = JSON.stringify(suppressed!.data);
      expect(raw).not.toContain("uid-recipient");
      expect(suppressed!.data!.userIdHash).toMatch(/^[0-9a-f]{16}$/);
    });
});
