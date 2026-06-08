/**
 * Unit tests for the trigger-facing settlement-notification dispatcher
 * (FR-AC-03).
 *
 * Mirrors `send-expense-notification.test.ts` but with a single
 * recipient (`toUserId` — the payee). The payer (`fromUserId`) is the
 * actor and is NOT notified of their own action per
 * `docs/design/07-technical/notifications.md` §2.2.
 *
 * @module test/notifications/send-settlement-notification.test.ts
 */

import {sendSettlementNotification} from
  "../../src/notifications/send-settlement-notification";
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
  fromUserId: "uid-payer",
  toUserId: "uid-payee",
  contextType: "friendship" as const,
  contextId: "uid-payer_uid-payee",
  settlementId: "settle1",
  senderName: "Priya",
  amountPaise: 35000,
  eventTimestamp: new Date("2026-06-08T10:00:00Z"),
};

describe("sendSettlementNotification — FR-AC-03 dispatcher", () => {
  it("sends to the payee (toUserId) ONLY when settlement=true and tokens non-empty", async () => {
    const db = createMockDb({
      "uid-payee": {
        fcmTokens: ["tokPayee1", "tokPayee2"],
        notificationPrefs: {
          newExpense: true,
          settlement: true,
          reminder: true,
        },
      },
    });
    const logger = createMockLogger();

    await sendSettlementNotification(
      {db, logger, messaging: createMockMessaging()},
      baseParams,
    );

    expect(mockedSendFcmToTokens).toHaveBeenCalledTimes(1);
    const callArgs = mockedSendFcmToTokens.mock.calls[0][1];
    expect(callArgs.userId).toBe("uid-payee");
    expect(callArgs.tokens).toEqual(["tokPayee1", "tokPayee2"]);
    expect(callArgs.notificationType).toBe("settlement_received");
    expect(callArgs.payload.title).toBe("Priya settled up");
    expect(callArgs.payload.body).toBe("You received ₹350.");
  });

  it("does NOT read or send to the payer (fromUserId — the actor)", async () => {
    const db = createMockDb({
      "uid-payer": {
        fcmTokens: ["tokPayer"],
        notificationPrefs: {
          newExpense: true,
          settlement: true,
          reminder: true,
        },
      },
      "uid-payee": {
        fcmTokens: ["tokPayee"],
        notificationPrefs: {
          newExpense: true,
          settlement: true,
          reminder: true,
        },
      },
    });
    const logger = createMockLogger();

    await sendSettlementNotification(
      {db, logger, messaging: createMockMessaging()},
      baseParams,
    );

    expect(mockedSendFcmToTokens).toHaveBeenCalledTimes(1);
    expect(mockedSendFcmToTokens.mock.calls[0][1].userId).toBe("uid-payee");
  });

  it("suppresses send when settlement=false (logs fcm_send_suppressed_by_prefs)", async () => {
    const db = createMockDb({
      "uid-payee": {
        fcmTokens: ["tokPayee"],
        notificationPrefs: {
          newExpense: true,
          settlement: false,
          reminder: true,
        },
      },
    });
    const logger = createMockLogger();

    await sendSettlementNotification(
      {db, logger, messaging: createMockMessaging()},
      baseParams,
    );

    expect(mockedSendFcmToTokens).not.toHaveBeenCalled();
    const suppressedLog = logger.calls.find(
      (c) => c.data?.event === "fcm_send_suppressed_by_prefs",
    );
    expect(suppressedLog).toBeDefined();
    expect(suppressedLog!.data!.notificationType).toBe("settlement_received");
  });

  it("logs fcm_send_skipped_empty_tokens when payee has no tokens", async () => {
    const db = createMockDb({
      "uid-payee": {
        fcmTokens: [],
        notificationPrefs: {
          newExpense: true,
          settlement: true,
          reminder: true,
        },
      },
    });
    const logger = createMockLogger();

    await sendSettlementNotification(
      {db, logger, messaging: createMockMessaging()},
      baseParams,
    );

    expect(mockedSendFcmToTokens).not.toHaveBeenCalled();
    const skipLog = logger.calls.find(
      (c) => c.data?.event === "fcm_send_skipped_empty_tokens",
    );
    expect(skipLog).toBeDefined();
  });

  it("logs fcm_send_skipped_missing_user when payee doc does not exist", async () => {
    const db = createMockDb({
      // intentionally omit uid-payee
    });
    const logger = createMockLogger();

    await sendSettlementNotification(
      {db, logger, messaging: createMockMessaging()},
      baseParams,
    );

    expect(mockedSendFcmToTokens).not.toHaveBeenCalled();
    const skipLog = logger.calls.find(
      (c) => c.data?.event === "fcm_send_skipped_missing_user",
    );
    expect(skipLog).toBeDefined();
  });

  it("defaults to settlement=true when notificationPrefs map is absent", async () => {
    const db = createMockDb({
      "uid-payee": {
        fcmTokens: ["tokPayee"],
        // no notificationPrefs map — should default to allow
      },
    });
    const logger = createMockLogger();

    await sendSettlementNotification(
      {db, logger, messaging: createMockMessaging()},
      baseParams,
    );

    expect(mockedSendFcmToTokens).toHaveBeenCalledTimes(1);
  });
});
