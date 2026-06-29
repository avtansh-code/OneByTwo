/**
 * Function-boundary tests for the onFriendshipCreate trigger.
 *
 * These tests exercise `createTriggerHandler(deps)` directly with a mocked
 * activity-writer + logger — no emulator required. The handler is a thin
 * producer that fans out one `friend_added` item to both members via the
 * shared `writeExpenseActivity`; this suite asserts the trigger-specific
 * concerns: both members targeted, payload shape (authorUid + friendshipId),
 * author resolution, missing-member containment, stale-event drop, and
 * PII-free logging.
 *
 * Mirrors the on-settlement-write FR-AC-01 activity-writer integration tests.
 *
 * @module test/triggers/on-friendship-create/function.test.ts
 */

import type {FirestoreEvent, QueryDocumentSnapshot} from
  "firebase-functions/v2/firestore";
import {createTriggerHandler} from
  "../../../src/triggers/on-friendship-create/function";
import {writeExpenseActivity} from
  "../../../src/triggers/on-expense-write/activity-writer";

jest.mock("../../../src/triggers/on-expense-write/activity-writer");

const mockedWriteExpenseActivity = writeExpenseActivity as jest.MockedFunction<
  typeof writeExpenseActivity
>;

beforeEach(() => {
  mockedWriteExpenseActivity.mockReset();
  mockedWriteExpenseActivity.mockResolvedValue({
    membersSucceeded: 2,
    membersFailed: 0,
  });
});

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
    error: (message: string, data?: Record<string, unknown>) => {
      calls.push({level: "error", message, data});
    },
    calls,
  };
}

/** The writer is mocked, so the db is never touched — a stub suffices. */
function createStubDb(): FirebaseFirestore.Firestore {
  return {} as unknown as FirebaseFirestore.Firestore;
}

/** Default valid friendship doc data ({uidA}_{uidB}, createdBy inviter). */
function validFriendshipData(
  overrides: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    memberIds: ["userA", "userB"],
    createdBy: "userA",
    ...overrides,
  };
}

/**
 * Builds a minimal `onDocumentCreated` FirestoreEvent. `event.data` is a
 * QueryDocumentSnapshot (the created document) — not a Change. When
 * `docData` is null the snapshot is treated as absent (undefined data).
 */
function makeEvent(opts: {
  friendshipId?: string;
  eventTime?: string;
  docData?: Record<string, unknown> | null;
}): FirestoreEvent<QueryDocumentSnapshot | undefined, {friendshipId: string}> {
  const friendshipId = opts.friendshipId ?? "userA_userB";
  const eventTime = opts.eventTime ?? new Date().toISOString();

  const snap =
    opts.docData === null ?
      undefined :
      ({
        exists: true,
        data: () => opts.docData ?? validFriendshipData(),
        ref: {path: `friendships/${friendshipId}`},
      } as unknown as QueryDocumentSnapshot);

  return {
    id: "event-id",
    type: "google.cloud.firestore.document.v1.created",
    specversion: "1.0",
    source: "//firestore.googleapis.com/projects/demo-onebytwo",
    time: eventTime,
    document: `friendships/${friendshipId}`,
    params: {friendshipId},
    data: snap,
    location: "asia-south1",
    project: "demo-onebytwo",
    database: "(default)",
    namespace: "(default)",
  } as unknown as FirestoreEvent<
    QueryDocumentSnapshot | undefined,
    {friendshipId: string}
  >;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("onFriendshipCreate handler — friend_added emission", () => {
  it("writes friend_added to BOTH members with the friendshipId entity", async () => {
    const logger = createMockLogger();
    const handler = createTriggerHandler({db: createStubDb(), logger});

    await handler(makeEvent({docData: validFriendshipData()}));

    expect(mockedWriteExpenseActivity).toHaveBeenCalledTimes(1);
    const [, req] = mockedWriteExpenseActivity.mock.calls[0];
    expect(req.eventType).toBe("friend_added");
    expect(req.memberIds).toEqual(["userA", "userB"]);
    expect(req.friendshipId).toBe("userA_userB");
    expect(req.expenseId).toBe("userA_userB");
  });

  it("payload has authorUid (createdBy) + friendshipId", async () => {
    const logger = createMockLogger();
    const handler = createTriggerHandler({db: createStubDb(), logger});

    await handler(makeEvent({docData: validFriendshipData()}));

    const [, req] = mockedWriteExpenseActivity.mock.calls[0];
    expect(req.payload).toEqual({
      authorUid: "userA",
      friendshipId: "userA_userB",
    });
  });

  it("falls back to memberIds[0] as author when createdBy is absent", async () => {
    const logger = createMockLogger();
    const handler = createTriggerHandler({db: createStubDb(), logger});

    await handler(
      makeEvent({docData: {memberIds: ["userB", "userC"]}}),
    );

    const [, req] = mockedWriteExpenseActivity.mock.calls[0];
    expect(req.payload).toEqual({
      authorUid: "userB",
      friendshipId: "userA_userB",
    });
  });

  it("contains missing memberIds — no write, no throw, logs skip", async () => {
    const logger = createMockLogger();
    const handler = createTriggerHandler({db: createStubDb(), logger});

    await expect(
      handler(makeEvent({docData: {createdBy: "userA"}})),
    ).resolves.toBeUndefined();

    expect(mockedWriteExpenseActivity).not.toHaveBeenCalled();
    const skip = logger.calls.find(
      (c) => c.data?.event === "friend_added_emission_skipped_missing_members",
    );
    expect(skip).toBeDefined();
    expect(skip!.level).toBe("error");
  });

  it("contains missing document data — no write, no throw", async () => {
    const logger = createMockLogger();
    const handler = createTriggerHandler({db: createStubDb(), logger});

    await expect(
      handler(makeEvent({docData: null})),
    ).resolves.toBeUndefined();

    expect(mockedWriteExpenseActivity).not.toHaveBeenCalled();
  });

  it("drops stale events (>7 days old) without writing", async () => {
    const eightDaysAgo = new Date(
      Date.now() - 8 * 24 * 60 * 60 * 1000,
    ).toISOString();
    const logger = createMockLogger();
    const handler = createTriggerHandler({db: createStubDb(), logger});

    await handler(makeEvent({eventTime: eightDaysAgo}));

    expect(mockedWriteExpenseActivity).not.toHaveBeenCalled();
    const dropped = logger.calls.find(
      (c) => c.data?.event === "friendship_create_trigger_stale_event_dropped",
    );
    expect(dropped).toBeDefined();
  });

  it("contains writer failures — does not throw if writeExpenseActivity throws", async () => {
    mockedWriteExpenseActivity.mockRejectedValueOnce(
      new Error("simulated programmer error in payload validator"),
    );
    const logger = createMockLogger();
    const handler = createTriggerHandler({db: createStubDb(), logger});

    await expect(
      handler(makeEvent({docData: validFriendshipData()})),
    ).resolves.toBeUndefined();

    const err = logger.calls.find(
      (c) => c.data?.event === "friend_added_emission_internal_error",
    );
    expect(err).toBeDefined();
    expect(err!.level).toBe("error");
  });

  it("logs friendship_create_trigger_fired first, with a hashed ID (no raw UIDs)", async () => {
    const logger = createMockLogger();
    const handler = createTriggerHandler({db: createStubDb(), logger});

    await handler(makeEvent({docData: validFriendshipData()}));

    expect(logger.calls[0].data?.event).toBe("friendship_create_trigger_fired");
    const serialised = JSON.stringify(logger.calls.map((c) => c.data));
    expect(serialised).not.toContain("userA_userB");
    expect(serialised).not.toContain("userA");
    expect(logger.calls[0].data?.friendshipIdHash).toHaveLength(16);
  });
});
