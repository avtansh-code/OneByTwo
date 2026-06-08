/**
 * Unit tests for the trigger-facing expense-notification dispatcher
 * (FR-AC-03).
 *
 * Exercises `sendExpenseNotification(deps, params)`:
 *
 *   - Reads each non-author recipient's `users/{uid}` doc.
 *   - For each recipient: runs prefs-filter → renderer → fcm-send.
 *   - For each recipient suppressed by prefs: logs
 *     `fcm_send_suppressed_by_prefs` and skips.
 *   - Tolerates a missing user doc (logs `fcm_send_skipped_missing_user`).
 *   - Tolerates an empty `fcmTokens` array (logs
 *     `fcm_send_skipped_empty_tokens`).
 *
 * `fcm-send.ts` is mocked at the module boundary; the prefs-filter and
 * renderer are real (small pure functions — no need to mock).
 *
 * @module test/notifications/send-expense-notification.test.ts
 */

import {sendExpenseNotification} from
  "../../src/notifications/send-expense-notification";
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

/**
 * Builds a mock Firestore that returns a per-recipient `users/{uid}` doc
 * based on the supplied map. Keys are user IDs; values are the doc data
 * (or `null` for an absent user doc).
 */
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
  authorUid: "uid-author",
  contextType: "friendship" as const,
  contextId: "uid-author_uid-other",
  expenseId: "exp1",
  senderName: "Rahul",
  description: "Dinner",
  amountPaise: 120000,
  eventTimestamp: new Date("2026-06-08T10:00:00Z"),
  changeType: "create" as const,
};

describe("sendExpenseNotification — FR-AC-03 dispatcher", () => {
  // -------------------------------------------------------------------------
  // Happy path: one recipient with non-empty fcmTokens & newExpense=true
  // -------------------------------------------------------------------------
  it("calls fcm-send for each non-author recipient with newExpense=true and non-empty tokens", async () => {
    const db = createMockDb({
      "uid-bob": {
        fcmTokens: ["tokBob1", "tokBob2"],
        notificationPrefs: {
          newExpense: true,
          settlement: true,
          reminder: true,
        },
      },
    });
    const logger = createMockLogger();

    await sendExpenseNotification(
      {db, logger, messaging: createMockMessaging()},
      {
        ...baseParams,
        memberIds: ["uid-author", "uid-bob"],
      },
    );

    expect(mockedSendFcmToTokens).toHaveBeenCalledTimes(1);
    const callArgs = mockedSendFcmToTokens.mock.calls[0][1];
    expect(callArgs.userId).toBe("uid-bob");
    expect(callArgs.tokens).toEqual(["tokBob1", "tokBob2"]);
    expect(callArgs.notificationType).toBe("expense_added");
    expect(callArgs.payload.type).toBe("expense_added");
    expect(callArgs.payload.senderName).toBe("Rahul");
  });

  it("dispatches to multiple recipients in parallel (skipping the author)", async () => {
    const db = createMockDb({
      "uid-bob": {
        fcmTokens: ["tokBob"],
        notificationPrefs: {
          newExpense: true,
          settlement: true,
          reminder: true,
        },
      },
      "uid-carol": {
        fcmTokens: ["tokCarol"],
        notificationPrefs: {
          newExpense: true,
          settlement: true,
          reminder: true,
        },
      },
    });
    const logger = createMockLogger();

    await sendExpenseNotification(
      {db, logger, messaging: createMockMessaging()},
      {
        ...baseParams,
        memberIds: ["uid-author", "uid-bob", "uid-carol"],
      },
    );

    expect(mockedSendFcmToTokens).toHaveBeenCalledTimes(2);
    const recipientIds = mockedSendFcmToTokens.mock.calls
      .map((c) => c[1].userId)
      .sort();
    expect(recipientIds).toEqual(["uid-bob", "uid-carol"]);
  });

  // -------------------------------------------------------------------------
  // Prefs short-circuit (AC-7)
  // -------------------------------------------------------------------------
  it("suppresses send for recipients with newExpense=false (logs fcm_send_suppressed_by_prefs)", async () => {
    const db = createMockDb({
      "uid-bob": {
        fcmTokens: ["tokBob"],
        notificationPrefs: {
          newExpense: false,
          settlement: true,
          reminder: true,
        },
      },
    });
    const logger = createMockLogger();

    await sendExpenseNotification(
      {db, logger, messaging: createMockMessaging()},
      {
        ...baseParams,
        memberIds: ["uid-author", "uid-bob"],
      },
    );

    expect(mockedSendFcmToTokens).not.toHaveBeenCalled();
    const suppressedLog = logger.calls.find(
      (c) => c.data?.event === "fcm_send_suppressed_by_prefs",
    );
    expect(suppressedLog).toBeDefined();
    expect(suppressedLog!.data!.userIdHash).toMatch(/^[0-9a-f]{16}$/);
    expect(suppressedLog!.data!.notificationType).toBe("expense_added");
  });

  it("sends to enabled recipients while suppressing disabled ones in the same fan-out", async () => {
    const db = createMockDb({
      "uid-bob": {
        fcmTokens: ["tokBob"],
        notificationPrefs: {
          newExpense: false,
          settlement: true,
          reminder: true,
        },
      },
      "uid-carol": {
        fcmTokens: ["tokCarol"],
        notificationPrefs: {
          newExpense: true,
          settlement: true,
          reminder: true,
        },
      },
    });
    const logger = createMockLogger();

    await sendExpenseNotification(
      {db, logger, messaging: createMockMessaging()},
      {
        ...baseParams,
        memberIds: ["uid-author", "uid-bob", "uid-carol"],
      },
    );

    expect(mockedSendFcmToTokens).toHaveBeenCalledTimes(1);
    expect(mockedSendFcmToTokens.mock.calls[0][1].userId).toBe("uid-carol");
  });

  // -------------------------------------------------------------------------
  // Skip branches
  // -------------------------------------------------------------------------
  it("logs fcm_send_skipped_empty_tokens and skips when recipient has no tokens", async () => {
    const db = createMockDb({
      "uid-bob": {
        fcmTokens: [],
        notificationPrefs: {
          newExpense: true,
          settlement: true,
          reminder: true,
        },
      },
    });
    const logger = createMockLogger();

    await sendExpenseNotification(
      {db, logger, messaging: createMockMessaging()},
      {
        ...baseParams,
        memberIds: ["uid-author", "uid-bob"],
      },
    );

    expect(mockedSendFcmToTokens).not.toHaveBeenCalled();
    const skipLog = logger.calls.find(
      (c) => c.data?.event === "fcm_send_skipped_empty_tokens",
    );
    expect(skipLog).toBeDefined();
  });

  it("logs fcm_send_skipped_missing_user when recipient doc does not exist", async () => {
    const db = createMockDb({
      // intentionally omit uid-bob — getDoc returns exists=false
    });
    const logger = createMockLogger();

    await sendExpenseNotification(
      {db, logger, messaging: createMockMessaging()},
      {
        ...baseParams,
        memberIds: ["uid-author", "uid-bob"],
      },
    );

    expect(mockedSendFcmToTokens).not.toHaveBeenCalled();
    const skipLog = logger.calls.find(
      (c) => c.data?.event === "fcm_send_skipped_missing_user",
    );
    expect(skipLog).toBeDefined();
  });

  // -------------------------------------------------------------------------
  // Author exclusion
  // -------------------------------------------------------------------------
  it("never sends to the author themselves", async () => {
    const db = createMockDb({
      "uid-author": {
        fcmTokens: ["tokAuthor"],
        notificationPrefs: {
          newExpense: true,
          settlement: true,
          reminder: true,
        },
      },
    });
    const logger = createMockLogger();

    await sendExpenseNotification(
      {db, logger, messaging: createMockMessaging()},
      {
        ...baseParams,
        memberIds: ["uid-author"],
      },
    );

    expect(mockedSendFcmToTokens).not.toHaveBeenCalled();
  });

  // -------------------------------------------------------------------------
  // changeType discrimination
  // -------------------------------------------------------------------------
  it("uses expense_edited type for changeType=update", async () => {
    const db = createMockDb({
      "uid-bob": {
        fcmTokens: ["tokBob"],
        notificationPrefs: {
          newExpense: true,
          settlement: true,
          reminder: true,
        },
      },
    });
    const logger = createMockLogger();

    await sendExpenseNotification(
      {db, logger, messaging: createMockMessaging()},
      {
        ...baseParams,
        changeType: "update",
        memberIds: ["uid-author", "uid-bob"],
      },
    );

    expect(mockedSendFcmToTokens).toHaveBeenCalledTimes(1);
    expect(mockedSendFcmToTokens.mock.calls[0][1].notificationType).toBe(
      "expense_edited",
    );
  });

  it("uses expense_deleted type for changeType=delete", async () => {
    const db = createMockDb({
      "uid-bob": {
        fcmTokens: ["tokBob"],
        notificationPrefs: {
          newExpense: true,
          settlement: true,
          reminder: true,
        },
      },
    });
    const logger = createMockLogger();

    await sendExpenseNotification(
      {db, logger, messaging: createMockMessaging()},
      {
        ...baseParams,
        changeType: "delete",
        memberIds: ["uid-author", "uid-bob"],
      },
    );

    expect(mockedSendFcmToTokens).toHaveBeenCalledTimes(1);
    expect(mockedSendFcmToTokens.mock.calls[0][1].notificationType).toBe(
      "expense_deleted",
    );
  });
});
