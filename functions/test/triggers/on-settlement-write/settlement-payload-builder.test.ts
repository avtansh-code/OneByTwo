/**
 * Unit tests for `buildSettlementActivityPayload` — the pure mapping
 * function that converts a settlement-trigger `(changeType, before,
 * after)` tuple into the typed `BuiltActivityPayload` for emission
 * into `activity/{userId}/items/{auto-id}` documents.
 *
 * Covers ACs (FR-AC-01):
 *   - AC-10 (positive): create-branch returns `{eventType:
 *     'settlement', payload: {settlementId, fromUserId, toUserId,
 *     amountPaise, contextType, contextId, note?, authorUid}}`.
 *   - AC-11 (negative): soft-delete-branch returns null (no
 *     emission). The architect's §2.2 decision.
 *
 * No emulator needed — pure-function unit tests.
 *
 * @module test/triggers/on-settlement-write/settlement-payload-builder.test.ts
 */

import {buildSettlementActivityPayload} from
  "../../../src/triggers/on-settlement-write/settlement-payload-builder";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function validSettlementData(overrides: Record<string, unknown> = {}) {
  return {
    fromUserId: "uidA",
    toUserId: "uidB",
    amountPaise: 5000,
    contextType: "friendship" as const,
    contextId: "uidA_uidB",
    note: null as string | null,
    deleted: false,
    ...overrides,
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("buildSettlementActivityPayload — create branch (AC-10)", () => {
  it("maps a create event to a settlement payload with all required fields", () => {
    const result = buildSettlementActivityPayload(
      "create",
      {
        settlementId: "set-1",
        after: validSettlementData(),
      },
    );

    expect(result).not.toBeNull();
    expect(result!.eventType).toBe("settlement");
    expect(result!.payload).toEqual({
      settlementId: "set-1",
      fromUserId: "uidA",
      toUserId: "uidB",
      amountPaise: 5000,
      contextType: "friendship",
      contextId: "uidA_uidB",
      authorUid: "uidA",
    });
  });

  it("includes the optional note when present (non-null string)", () => {
    const result = buildSettlementActivityPayload(
      "create",
      {
        settlementId: "set-2",
        after: validSettlementData({note: "Lunch repayment"}),
      },
    );

    expect(result).not.toBeNull();
    expect(result!.payload).toMatchObject({
      note: "Lunch repayment",
    });
  });

  it("omits the note key when it is null on the source doc", () => {
    const result = buildSettlementActivityPayload(
      "create",
      {
        settlementId: "set-3",
        after: validSettlementData({note: null}),
      },
    );

    expect(result).not.toBeNull();
    expect(result!.payload).not.toHaveProperty("note");
  });

  it("authorUid mirrors fromUserId (architect §2.4)", () => {
    const result = buildSettlementActivityPayload(
      "create",
      {
        settlementId: "set-4",
        after: validSettlementData({fromUserId: "uid-custom-author"}),
      },
    );

    expect(result!.payload).toMatchObject({
      authorUid: "uid-custom-author",
    });
  });

  it("preserves the integer amountPaise (Invariant 1)", () => {
    const result = buildSettlementActivityPayload(
      "create",
      {
        settlementId: "set-5",
        after: validSettlementData({amountPaise: 987654}),
      },
    );

    expect(typeof result!.payload.amountPaise).toBe("number");
    expect(Number.isInteger(result!.payload.amountPaise)).toBe(true);
    expect(result!.payload.amountPaise).toBe(987654);
  });

  it("throws on a create event with no `after` snapshot", () => {
    expect(() =>
      buildSettlementActivityPayload("create", {
        settlementId: "set-bad",
      }),
    ).toThrow(/create.+after/);
  });
});

describe("buildSettlementActivityPayload — update branch (soft-delete) (AC-11)", () => {
  it("returns null on a soft-delete update (deleted: false -> true)", () => {
    const result = buildSettlementActivityPayload(
      "update",
      {
        settlementId: "set-soft-del",
        before: validSettlementData({deleted: false}),
        after: validSettlementData({deleted: true}),
      },
    );

    // Soft-delete is the v1.0 "no emission" case per architect §2.2.
    expect(result).toBeNull();
  });

  it("returns null on any update event (settlements have no edit branch)", () => {
    // Rules at firestore.rules:461-469 only permit deleted: false -> true
    // on update. Any other update path would be a rules violation
    // (admin-only). The settlement-trigger handler short-circuits ALL
    // update events for activity emission per architect §2.2.
    const result = buildSettlementActivityPayload(
      "update",
      {
        settlementId: "set-update",
        before: validSettlementData(),
        after: validSettlementData({amountPaise: 9999}),
      },
    );

    expect(result).toBeNull();
  });
});

describe("buildSettlementActivityPayload — delete branch (hard-delete)", () => {
  it("returns null on a hard-delete event (admin-only path; no emission)", () => {
    const result = buildSettlementActivityPayload(
      "delete",
      {
        settlementId: "set-hard-del",
        before: validSettlementData(),
      },
    );

    expect(result).toBeNull();
  });
});
