/**
 * Integration tests for the onSettlementWrite Firestore trigger.
 *
 * These tests run inside `firebase emulators:exec --only auth,firestore,
 * functions,storage` so that the trigger registered in
 * `functions/src/triggers/on-settlement-write/index.ts` actually fires on
 * Firestore writes. The Functions emulator must be running with the
 * compiled bundle from `functions/lib/`.
 *
 * Setup (CI): the PR workflow at .github/workflows/pr.yml runs
 *   firebase emulators:exec --only auth,firestore,functions,storage \
 *     "... && cd functions && npm run test:rules && npm run test:integration"
 *
 * Setup (local):
 *   1. cd functions && npm run build
 *   2. firebase emulators:start --only auth,firestore,functions,storage
 *   3. (separate shell) cd functions && npm run test:integration
 *
 * Coverage targets (story FR-SE-05/06 ACs):
 *   - AC-7, AC-8: algorithm reads settlements and filters soft-deleted.
 *   - AC-9: create event triggers atomic balance + lastActivityAt write.
 *   - AC-10: update + soft-delete walk.
 *   - AC-12: CONTEXT_NOT_FOUND graceful — write a settlement with
 *     contextId pointing at a non-existent friendship.
 *   - AC-15: canonical settlement matrix (full debt settlement, partial
 *     settlement, overshoot).
 *
 * @module test/integration/on-settlement-write.integration.test.ts
 */

process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8181";

import {initializeApp, deleteApp, getApp} from "firebase-admin/app";
import {getFirestore, Timestamp} from "firebase-admin/firestore";

const PROJECT_ID = "demo-onebytwo";
const APP_NAME = "integration-test-on-settlement-write";

const POLL_INTERVAL_MS = 100;
const POLL_TIMEOUT_MS = 5000;

// ---------------------------------------------------------------------------
// Shared state
// ---------------------------------------------------------------------------

let db: FirebaseFirestore.Firestore;
const createdDocPaths: string[] = [];

// ---------------------------------------------------------------------------
// Setup / Teardown
// ---------------------------------------------------------------------------

beforeAll(() => {
  const app = initializeApp({projectId: PROJECT_ID}, APP_NAME);
  db = getFirestore(app);
});

afterEach(async () => {
  const sorted = [...createdDocPaths].sort((a, b) => b.length - a.length);
  for (const docPath of sorted) {
    try {
      await db.doc(docPath).delete();
    } catch {
      // ignore — may already have been deleted
    }
  }
  createdDocPaths.length = 0;
});

afterAll(async () => {
  const app = getApp(APP_NAME);
  await deleteApp(app);
});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

async function seedDoc(
  path: string,
  data: Record<string, unknown>,
): Promise<void> {
  await db.doc(path).set(data);
  createdDocPaths.push(path);
}

function makeExpense(opts: {
  payerId: string;
  amountPaise: number;
  splits: Array<{userId: string; sharePaise: number}>;
  deleted?: boolean;
  description?: string;
}): Record<string, unknown> {
  return {
    payerId: opts.payerId,
    amountPaise: opts.amountPaise,
    splits: opts.splits,
    deleted: opts.deleted ?? false,
    description: opts.description ?? "Integration test expense",
    category: "general",
    date: Timestamp.now(),
    splitMethod: "equal",
    createdBy: opts.payerId,
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
    receiptUrl: null,
    source: "manual",
    currency: "INR",
    recurringRule: null,
  };
}

function makeSettlement(opts: {
  fromUserId: string;
  toUserId: string;
  amountPaise: number;
  contextType?: "friendship" | "group";
  contextId: string;
  deleted?: boolean;
  note?: string | null;
}): Record<string, unknown> {
  return {
    fromUserId: opts.fromUserId,
    toUserId: opts.toUserId,
    amountPaise: opts.amountPaise,
    contextType: opts.contextType ?? "friendship",
    contextId: opts.contextId,
    date: Timestamp.now(),
    note: opts.note ?? null,
    method: "manual",
    verificationStatus: "unverified",
    currency: "INR",
    createdAt: Timestamp.now(),
    deleted: opts.deleted ?? false,
  };
}

/**
 * Polls the parent friendship doc until `simplifiedBalances` matches the
 * expected value (or the timeout elapses). Returns the final snapshot data.
 */
async function waitForBalances(
  contextPath: string,
  expected: Record<string, unknown>,
): Promise<FirebaseFirestore.DocumentData | undefined> {
  const start = Date.now();
  let lastData: FirebaseFirestore.DocumentData | undefined;
  while (Date.now() - start < POLL_TIMEOUT_MS) {
    const snap = await db.doc(contextPath).get();
    lastData = snap.data();
    if (
      lastData &&
      JSON.stringify(lastData.simplifiedBalances) === JSON.stringify(expected)
    ) {
      return lastData;
    }
    await new Promise((r) => setTimeout(r, POLL_INTERVAL_MS));
  }
  return lastData;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("onSettlementWrite — integration (registered trigger)", () => {
  // -------------------------------------------------------------------------
  // AC-15 Case A — Full debt settlement zeroes the debt
  //
  // 1. A pays 10000 (split equally) → B owes A 5000.
  // 2. B pays A 5000 cash (the settlement) → debt cleared.
  // 3. simplifiedBalances becomes {}.
  // -------------------------------------------------------------------------
  describe("AC-15 case A — full debt settlement zeroes simplifiedBalances", () => {
    const fid = "int-on-settle-full";
    const contextPath = `friendships/${fid}`;

    beforeEach(async () => {
      await seedDoc(contextPath, {
        memberIds: ["A", "B"],
        createdBy: "A",
        lastActivityAt: Timestamp.fromDate(new Date("2026-01-01T00:00:00.000Z")),
        simplifiedBalances: {},
      });
      await seedDoc(`${contextPath}/expenses/exp1`, makeExpense({
        payerId: "A",
        amountPaise: 10000,
        splits: [
          {userId: "A", sharePaise: 5000},
          {userId: "B", sharePaise: 5000},
        ],
      }));
      // Wait for the expense trigger to settle balances at {B: {A: 5000}}.
      await waitForBalances(contextPath, {B: {A: 5000}});
    });

    it("settles the debt to empty when B pays A 5000", async () => {
      const settlementPath = `settlements/int-on-settle-full-s1`;
      await seedDoc(settlementPath, makeSettlement({
        fromUserId: "B",
        toUserId: "A",
        amountPaise: 5000,
        contextId: fid,
      }));

      const data = await waitForBalances(contextPath, {});
      expect(data).toBeDefined();
      expect(data!.simplifiedBalances).toEqual({});
      expect(data!.lastActivityAt).toBeDefined();
      // lastActivityAt should be advanced past the seeded value.
      const newTs = (data!.lastActivityAt as Timestamp).toMillis();
      const seededTs = new Date("2026-01-01T00:00:00.000Z").getTime();
      expect(newTs).toBeGreaterThan(seededTs);
    });
  });

  // -------------------------------------------------------------------------
  // AC-15 Case B — Partial settlement (FR-SE-06)
  //
  // B owes A 5000; B pays A 2000 → residual: B owes A 3000.
  // -------------------------------------------------------------------------
  describe("AC-15 case B — partial settlement leaves residual debt (FR-SE-06)", () => {
    const fid = "int-on-settle-partial";
    const contextPath = `friendships/${fid}`;

    beforeEach(async () => {
      await seedDoc(contextPath, {
        memberIds: ["X", "Y"],
        createdBy: "X",
        lastActivityAt: Timestamp.now(),
        simplifiedBalances: {},
      });
      await seedDoc(`${contextPath}/expenses/exp1`, makeExpense({
        payerId: "X",
        amountPaise: 10000,
        splits: [
          {userId: "X", sharePaise: 5000},
          {userId: "Y", sharePaise: 5000},
        ],
      }));
      await waitForBalances(contextPath, {Y: {X: 5000}});
    });

    it("residual is exactly the unpaid portion (FR-SE-06)", async () => {
      const settlementPath = `settlements/int-on-settle-partial-s1`;
      await seedDoc(settlementPath, makeSettlement({
        fromUserId: "Y",
        toUserId: "X",
        amountPaise: 2000,
        contextId: fid,
      }));

      const data = await waitForBalances(contextPath, {Y: {X: 3000}});
      expect(data!.simplifiedBalances).toEqual({Y: {X: 3000}});
    });
  });

  // -------------------------------------------------------------------------
  // AC-15 Case C — Overshoot (debtor pays more than owed)
  //
  // B owes A 5000; B pays A 8000 → A now owes B 3000 (net flip).
  // -------------------------------------------------------------------------
  describe("AC-15 case C — overshoot flips the net balance sign", () => {
    const fid = "int-on-settle-overshoot";
    const contextPath = `friendships/${fid}`;

    beforeEach(async () => {
      await seedDoc(contextPath, {
        memberIds: ["M", "N"],
        createdBy: "M",
        lastActivityAt: Timestamp.now(),
        simplifiedBalances: {},
      });
      await seedDoc(`${contextPath}/expenses/exp1`, makeExpense({
        payerId: "M",
        amountPaise: 10000,
        splits: [
          {userId: "M", sharePaise: 5000},
          {userId: "N", sharePaise: 5000},
        ],
      }));
      await waitForBalances(contextPath, {N: {M: 5000}});
    });

    it("net balance flips when the debtor overpays", async () => {
      const settlementPath = `settlements/int-on-settle-overshoot-s1`;
      await seedDoc(settlementPath, makeSettlement({
        fromUserId: "N",
        toUserId: "M",
        amountPaise: 8000,
        contextId: fid,
      }));

      const data = await waitForBalances(contextPath, {M: {N: 3000}});
      expect(data!.simplifiedBalances).toEqual({M: {N: 3000}});
    });
  });

  // -------------------------------------------------------------------------
  // AC-10 — update + soft-delete walk
  //
  // 1. Seed friendship + expense (B owes A 5000).
  // 2. Create settlement B→A 2000 → residual {B: {A: 3000}}.
  // 3. Soft-delete the settlement → residual returns to {B: {A: 5000}}.
  // -------------------------------------------------------------------------
  describe("AC-10 — update + soft-delete walk", () => {
    const fid = "int-on-settle-walk";
    const contextPath = `friendships/${fid}`;
    const settlementPath = `settlements/int-on-settle-walk-s1`;

    beforeEach(async () => {
      await seedDoc(contextPath, {
        memberIds: ["P", "Q"],
        createdBy: "P",
        lastActivityAt: Timestamp.now(),
        simplifiedBalances: {},
      });
      await seedDoc(`${contextPath}/expenses/exp1`, makeExpense({
        payerId: "P",
        amountPaise: 10000,
        splits: [
          {userId: "P", sharePaise: 5000},
          {userId: "Q", sharePaise: 5000},
        ],
      }));
      await waitForBalances(contextPath, {Q: {P: 5000}});
    });

    it("walks create → soft-delete with correct balances at each step", async () => {
      // ── 1. Create settlement Q→P 2000 ⇒ residual {Q:{P:3000}} ──
      await seedDoc(settlementPath, makeSettlement({
        fromUserId: "Q",
        toUserId: "P",
        amountPaise: 2000,
        contextId: fid,
      }));
      await waitForBalances(contextPath, {Q: {P: 3000}});

      // ── 2. Soft-delete settlement ⇒ residual reverts to {Q:{P:5000}} ──
      await db.doc(settlementPath).update({deleted: true});
      const final = await waitForBalances(contextPath, {Q: {P: 5000}});
      expect(final!.simplifiedBalances).toEqual({Q: {P: 5000}});
    });
  });

  // -------------------------------------------------------------------------
  // AC-12 — CONTEXT_NOT_FOUND graceful handling
  //
  // Settlement with contextId pointing at a non-existent friendship.
  // Friendship doc remains absent; settlement doc remains present;
  // no retry storm (asserted via the unit test, not here).
  // -------------------------------------------------------------------------
  describe("AC-12 context-not-found graceful handling", () => {
    it("does not create the parent friendship doc when contextId is orphan", async () => {
      const orphanFid = "int-on-settle-orphan";
      const settlementPath = `settlements/int-on-settle-orphan-s1`;
      // Note: friendship doc is deliberately NOT seeded.

      await seedDoc(settlementPath, makeSettlement({
        fromUserId: "A",
        toUserId: "B",
        amountPaise: 5000,
        contextId: orphanFid,
      }));

      // Brief wait for the trigger to fire at least once.
      await new Promise((r) => setTimeout(r, 1500));

      // The friendship doc must remain absent — the trigger's missing-
      // context guard returns before any write is attempted.
      const friendshipSnap = await db.doc(`friendships/${orphanFid}`).get();
      expect(friendshipSnap.exists).toBe(false);

      // The orphan settlement doc must still exist.
      const settlementSnap = await db.doc(settlementPath).get();
      expect(settlementSnap.exists).toBe(true);
    }, 10000);
  });

  // -------------------------------------------------------------------------
  // AC-17 (regression — explicit) — settlement that fires AFTER the expense
  // trigger has already settled balances. Proves the new
  // `recomputeAndWrite` settlement-read extension doesn't break the existing
  // expense-trigger codepath even when both triggers operate on the same
  // context document in rapid succession.
  // -------------------------------------------------------------------------
  describe("AC-17 regression — expense + settlement triggers cooperate", () => {
    const fid = "int-on-settle-coop";
    const contextPath = `friendships/${fid}`;

    it("expense trigger then settlement trigger produce correct final state", async () => {
      await seedDoc(contextPath, {
        memberIds: ["U", "V"],
        createdBy: "U",
        lastActivityAt: Timestamp.now(),
        simplifiedBalances: {},
      });

      // Expense first.
      await seedDoc(`${contextPath}/expenses/exp1`, makeExpense({
        payerId: "U",
        amountPaise: 8000,
        splits: [
          {userId: "U", sharePaise: 4000},
          {userId: "V", sharePaise: 4000},
        ],
      }));
      await waitForBalances(contextPath, {V: {U: 4000}});

      // Settlement next.
      await seedDoc(`settlements/int-on-settle-coop-s1`, makeSettlement({
        fromUserId: "V",
        toUserId: "U",
        amountPaise: 4000,
        contextId: fid,
      }));

      const final = await waitForBalances(contextPath, {});
      expect(final!.simplifiedBalances).toEqual({});
    });
  });
});
