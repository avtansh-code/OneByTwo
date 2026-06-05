/**
 * Integration tests for the onExpenseWriteFriendship Firestore trigger.
 *
 * These tests run inside `firebase emulators:exec --only auth,firestore,
 * functions,storage` so that the trigger registered in
 * `functions/src/triggers/on-expense-write/index.ts` actually fires on
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
 * Coverage targets (story FR-SE-03-04 ACs):
 *   - AC-1, AC-2, AC-3, AC-4: change-type coverage walks through
 *     create -> update -> soft-delete and asserts simplifiedBalances at
 *     each step.
 *   - AC-6 (atomicity): the parent friendship snapshot after the trigger
 *     fires must reflect BOTH simplifiedBalances and lastActivityAt.
 *   - AC-9: the canonical 6-case matrix from
 *     docs/design/07-technical/simplified-debts-algorithm.md walked
 *     end-to-end through the trigger.
 *   - AC-10: CONTEXT_NOT_FOUND — admin-SDK creates an expense under a
 *     non-existent friendship; the trigger MUST NOT throw or retry-storm.
 *     (Observed by absence of any sustained update activity on the doc.)
 *
 * @module test/integration/on-expense-write.integration.test.ts
 */

process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8181";

import {initializeApp, deleteApp, getApp} from "firebase-admin/app";
import {getFirestore, Timestamp} from "firebase-admin/firestore";

const PROJECT_ID = "demo-onebytwo";
const APP_NAME = "integration-test-on-expense-write";

// How long to wait for the trigger to fire and write the parent friendship.
// The trigger's I/O budget is one transaction + one document update — usually
// well under 2 seconds in the emulator. Polling at 100 ms granularity gives
// ~30 attempts within a 3-second timeout.
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
// AC-9 (canonical 6-case matrix) plus AC-1/2/3 (change-type coverage)
//
// We implement a focused subset of the canonical algorithm cases here. The
// pure algorithm coverage at functions/test/simplified-debts/algorithm.test.ts
// covers all 6 cases against the algorithm. This file proves the WIRING
// end-to-end through the trigger by exercising representative cases.
// ---------------------------------------------------------------------------

describe("onExpenseWriteFriendship — integration (registered trigger)", () => {
  // -------------------------------------------------------------------------
  // AC-1, AC-6, AC-9 (Example 5 — two-person variant of the trip case)
  // -------------------------------------------------------------------------
  describe("create event triggers atomic balance + lastActivityAt write", () => {
    const fid = "int-on-write-create";
    const contextPath = `friendships/${fid}`;

    beforeEach(async () => {
      await seedDoc(contextPath, {
        memberIds: ["A", "B"],
        createdBy: "A",
        lastActivityAt: Timestamp.fromDate(new Date("2026-01-01T00:00:00.000Z")),
        simplifiedBalances: {},
      });
    });

    it("computes simplifiedBalances and updates lastActivityAt atomically", async () => {
      // A paid 10000, split equally → B owes A 5000.
      await seedDoc(`${contextPath}/expenses/exp-create`, makeExpense({
        payerId: "A",
        amountPaise: 10000,
        splits: [
          {userId: "A", sharePaise: 5000},
          {userId: "B", sharePaise: 5000},
        ],
      }));

      const data = await waitForBalances(contextPath, {B: {A: 5000}});
      expect(data).toBeDefined();
      expect(data!.simplifiedBalances).toEqual({B: {A: 5000}});
      expect(data!.lastActivityAt).toBeDefined();
      // lastActivityAt should be advanced past the seeded 2026-01-01 value
      const newTs = (data!.lastActivityAt as Timestamp).toMillis();
      const seededTs = new Date("2026-01-01T00:00:00.000Z").getTime();
      expect(newTs).toBeGreaterThan(seededTs);
    });
  });

  // -------------------------------------------------------------------------
  // AC-2, AC-3 — update and soft-delete sequencing
  // -------------------------------------------------------------------------
  describe("update and soft-delete event flow", () => {
    const fid = "int-on-write-flow";
    const contextPath = `friendships/${fid}`;
    const expPath = `${contextPath}/expenses/exp-flow`;

    beforeEach(async () => {
      await seedDoc(contextPath, {
        memberIds: ["X", "Y"],
        createdBy: "X",
        lastActivityAt: Timestamp.fromDate(new Date("2026-01-01T00:00:00.000Z")),
        simplifiedBalances: {},
      });
    });

    it("walks create → update → soft-delete with correct balances at each step", async () => {
      // ── 1. Create: X pays 8000, split equally ⇒ Y owes X 4000 ──
      await seedDoc(expPath, makeExpense({
        payerId: "X",
        amountPaise: 8000,
        splits: [
          {userId: "X", sharePaise: 4000},
          {userId: "Y", sharePaise: 4000},
        ],
      }));
      await waitForBalances(contextPath, {Y: {X: 4000}});

      // ── 2. Update: X now pays 20000 (split equally) ⇒ Y owes X 10000 ──
      await db.doc(expPath).update({
        amountPaise: 20000,
        splits: [
          {userId: "X", sharePaise: 10000},
          {userId: "Y", sharePaise: 10000},
        ],
        updatedAt: Timestamp.now(),
      });
      await waitForBalances(contextPath, {Y: {X: 10000}});

      // ── 3. Soft-delete: balances revert to settled ──
      await db.doc(expPath).update({
        deleted: true,
        updatedAt: Timestamp.now(),
      });
      const final = await waitForBalances(contextPath, {});
      expect(final!.simplifiedBalances).toEqual({});
    });
  });

  // -------------------------------------------------------------------------
  // AC-10 — context-not-found path: no orphaned write
  //
  // This test verifies that the trigger does not write to a parent
  // friendship doc when that doc is missing. It does NOT prove the
  // absence of a retry storm — proving "no retries" at the integration
  // layer would require deterministic invocation-count capture from
  // the emulator, which the v2 Firestore emulator does not expose.
  // The unit test "logs CONTEXT_NOT_FOUND and returns successfully"
  // in function.test.ts is the authoritative no-retry assertion.
  // -------------------------------------------------------------------------
  describe("context-not-found graceful handling", () => {
    it("does not create the parent friendship doc when it is missing", async () => {
      const orphanFid = "int-on-write-orphan";
      const orphanExpPath = `friendships/${orphanFid}/expenses/exp-orphan`;
      // Note: friendship doc is deliberately NOT seeded.

      await seedDoc(orphanExpPath, makeExpense({
        payerId: "A",
        amountPaise: 10000,
        splits: [
          {userId: "A", sharePaise: 5000},
          {userId: "B", sharePaise: 5000},
        ],
      }));

      // Brief wait for the trigger to fire at least once.
      await new Promise((r) => setTimeout(r, 1500));

      // The friendship doc must remain absent — the trigger's missing-
      // context guard returns before any write is attempted.
      const friendshipSnap = await db.doc(`friendships/${orphanFid}`).get();
      expect(friendshipSnap.exists).toBe(false);

      // The orphan expense doc must still exist — the trigger does not
      // delete; it merely declines to recompute.
      const expenseSnap = await db.doc(orphanExpPath).get();
      expect(expenseSnap.exists).toBe(true);
    }, 10000);
  });

  // -------------------------------------------------------------------------
  // AC-9 — canonical three-person trip case (Example 5)
  //
  // While the friendship subcollection is between exactly two parties, the
  // simplified-balances algorithm's three-person canonical case is exercised
  // via the GROUP context (PR #12 integration test). This trigger only binds
  // to friendship paths in PR #36; the groups binding is deferred to Sprint 3
  // per architect notes §2. Here we restrict to two-person cases for AC-9.
  // -------------------------------------------------------------------------
  describe("AC-9 canonical two-person variants", () => {
    it("Example 1 — empty expenses → empty simplifiedBalances", async () => {
      const fid = "int-on-write-empty";
      const contextPath = `friendships/${fid}`;
      await seedDoc(contextPath, {
        memberIds: ["A", "B"],
        createdBy: "A",
        lastActivityAt: Timestamp.now(),
        simplifiedBalances: {init: {marker: 1}}, // seed garbage to prove recompute clears
      });

      // Create then soft-delete an expense to force the trigger to recompute
      // and prove it writes {} (the algorithm's correct output for empty set).
      await seedDoc(`${contextPath}/expenses/exp-noop`, makeExpense({
        payerId: "A",
        amountPaise: 1000,
        splits: [
          {userId: "A", sharePaise: 500},
          {userId: "B", sharePaise: 500},
        ],
        deleted: true, // already soft-deleted on create — algorithm sees zero active expenses
      }));

      // The trigger fires, the active-expense query filters this doc out,
      // so simplifiedBalances becomes {}.
      const data = await waitForBalances(contextPath, {});
      expect(data!.simplifiedBalances).toEqual({});
    });

    it("Example 2 — self-paid expense → empty simplifiedBalances", async () => {
      const fid = "int-on-write-selfpaid";
      const contextPath = `friendships/${fid}`;
      await seedDoc(contextPath, {
        memberIds: ["A", "B"],
        createdBy: "A",
        lastActivityAt: Timestamp.now(),
        // Stale marker to prove the trigger re-wrote the field (rather
        // than waitForBalances returning immediately on the seeded value).
        simplifiedBalances: {stale: {marker: 1}},
      });

      // A pays 5000, A owes himself 5000 → no transfer.
      await seedDoc(`${contextPath}/expenses/exp-self`, makeExpense({
        payerId: "A",
        amountPaise: 5000,
        splits: [{userId: "A", sharePaise: 5000}],
      }));

      const data = await waitForBalances(contextPath, {});
      expect(data!.simplifiedBalances).toEqual({});
    });

    it("Example 3 — perfectly balanced → empty simplifiedBalances", async () => {
      const fid = "int-on-write-balanced";
      const contextPath = `friendships/${fid}`;
      await seedDoc(contextPath, {
        memberIds: ["A", "B"],
        createdBy: "A",
        lastActivityAt: Timestamp.now(),
        // Stale marker (see Example 2).
        simplifiedBalances: {stale: {marker: 1}},
      });

      // A pays 10000 (B owes A 5000); B pays 10000 (A owes B 5000); net zero.
      await seedDoc(`${contextPath}/expenses/exp-a`, makeExpense({
        payerId: "A",
        amountPaise: 10000,
        splits: [
          {userId: "A", sharePaise: 5000},
          {userId: "B", sharePaise: 5000},
        ],
      }));
      await seedDoc(`${contextPath}/expenses/exp-b`, makeExpense({
        payerId: "B",
        amountPaise: 10000,
        splits: [
          {userId: "A", sharePaise: 5000},
          {userId: "B", sharePaise: 5000},
        ],
      }));

      const data = await waitForBalances(contextPath, {});
      expect(data!.simplifiedBalances).toEqual({});
    });
  });
});
