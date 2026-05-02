/**
 * Integration tests for recomputeSimplifiedBalances Cloud Function.
 *
 * These tests run against the Firebase Emulator Suite (Firestore on 127.0.0.1:8181).
 * They seed real Firestore documents, invoke the handler via dependency injection,
 * and assert both the response and the persisted Firestore state.
 *
 * Run with: npm run test:integration
 * Prerequisites: Firestore emulator running on port 8181.
 */

// Must be set BEFORE importing firebase-admin so the SDK connects to the emulator.
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8181";

import {initializeApp, deleteApp, getApp} from "firebase-admin/app";
import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {createHandler} from "../../src/simplified-debts/function";

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const PROJECT_ID = "demo-onebytwo";
const APP_NAME = "integration-test-simplified-debts";

// ---------------------------------------------------------------------------
// Shared state
// ---------------------------------------------------------------------------

let db: FirebaseFirestore.Firestore;
let handler: (data: unknown) => Promise<any>;

// Track all doc paths created during tests so we can clean up.
const createdDocPaths: string[] = [];

// ---------------------------------------------------------------------------
// Setup / Teardown
// ---------------------------------------------------------------------------

beforeAll(() => {
  const app = initializeApp({projectId: PROJECT_ID}, APP_NAME);
  db = getFirestore(app);
  handler = createHandler({
    db,
    logger: {
      info: jest.fn(),
      error: jest.fn(),
    },
  });
});

afterEach(async () => {
  // Delete all documents created during this test in reverse order
  // (subcollection docs before parent docs).
  const sorted = [...createdDocPaths].sort((a, b) => b.length - a.length);
  for (const docPath of sorted) {
    try {
      await db.doc(docPath).delete();
    } catch {
      // Ignore — may already have been deleted.
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

/**
 * Seeds a document in Firestore and records its path for cleanup.
 */
async function seedDoc(
  path: string,
  data: Record<string, unknown>,
): Promise<void> {
  await db.doc(path).set(data);
  createdDocPaths.push(path);
}

/**
 * Creates a standard expense document shape.
 */
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
    description: opts.description ?? "Test expense",
    category: "general",
    date: Timestamp.now(),
    splitMethod: "equal",
    createdBy: opts.payerId,
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  };
}

// ---------------------------------------------------------------------------
// Test Suite
// ---------------------------------------------------------------------------

describe("recomputeSimplifiedBalances — integration", () => {
  // -------------------------------------------------------------------------
  // 1. Three-person canonical case (friendship context)
  // -------------------------------------------------------------------------
  describe("three-person canonical case (friendship)", () => {
    const contextPath = "friendships/int-test-friendship-3p";
    const expPath = `${contextPath}/expenses/exp1`;

    beforeEach(async () => {
      await seedDoc(contextPath, {
        memberIds: ["A", "B", "C"],
        simplifiedBalances: {},
        lastActivityAt: Timestamp.now(),
      });

      await seedDoc(
        expPath,
        makeExpense({
          payerId: "A",
          amountPaise: 60000,
          splits: [
            {userId: "A", sharePaise: 20000},
            {userId: "B", sharePaise: 20000},
            {userId: "C", sharePaise: 20000},
          ],
          description: "Dinner split three ways",
        }),
      );
    });

    it("should return 2 transfers settling B->A and C->A", async () => {
      const result = await handler({
        contextType: "friendship",
        contextId: "int-test-friendship-3p",
      });

      expect(result.ok).toBe(true);
      expect(result.transfers).toHaveLength(2);

      // Sort transfers by 'from' for deterministic assertion
      const sorted = [...result.transfers].sort((a: any, b: any) =>
        a.from.localeCompare(b.from),
      );
      expect(sorted).toEqual([
        {from: "B", to: "A", amountPaise: 20000},
        {from: "C", to: "A", amountPaise: 20000},
      ]);
    });

    it("should return simplifiedBalances map matching expected shape", async () => {
      const result = await handler({
        contextType: "friendship",
        contextId: "int-test-friendship-3p",
      });

      expect(result.simplifiedBalances).toEqual({
        B: {A: 20000},
        C: {A: 20000},
      });
    });

    it("should persist simplifiedBalances to the Firestore document", async () => {
      await handler({
        contextType: "friendship",
        contextId: "int-test-friendship-3p",
      });

      const snap = await db.doc(contextPath).get();
      expect(snap.exists).toBe(true);

      const data = snap.data()!;
      expect(data.simplifiedBalances).toEqual({
        B: {A: 20000},
        C: {A: 20000},
      });
    });

    it("should return a valid ISO 8601 computedAt timestamp", async () => {
      const before = new Date().toISOString();
      const result = await handler({
        contextType: "friendship",
        contextId: "int-test-friendship-3p",
      });
      const after = new Date().toISOString();

      expect(typeof result.computedAt).toBe("string");
      expect(result.computedAt >= before).toBe(true);
      expect(result.computedAt <= after).toBe(true);
    });
  });

  // -------------------------------------------------------------------------
  // 2. Five-person canonical case (group context)
  // -------------------------------------------------------------------------
  describe("five-person canonical case (group)", () => {
    const contextPath = "groups/int-test-group-5p";

    beforeEach(async () => {
      await seedDoc(contextPath, {
        name: "Flat 5",
        memberIds: ["A", "B", "C", "D", "E"],
        adminId: "A",
        simplifiedBalances: {},
        lastActivityAt: Timestamp.now(),
      });

      // Expense 1: Rent — A pays 5000000 paise (50,000 INR), split equally 5 ways
      await seedDoc(
        `${contextPath}/expenses/exp-rent`,
        makeExpense({
          payerId: "A",
          amountPaise: 5000000,
          splits: [
            {userId: "A", sharePaise: 1000000},
            {userId: "B", sharePaise: 1000000},
            {userId: "C", sharePaise: 1000000},
            {userId: "D", sharePaise: 1000000},
            {userId: "E", sharePaise: 1000000},
          ],
          description: "Rent",
        }),
      );

      // Expense 2: Groceries — B pays 300000 paise (3,000 INR), split equally 5 ways
      await seedDoc(
        `${contextPath}/expenses/exp-groceries`,
        makeExpense({
          payerId: "B",
          amountPaise: 300000,
          splits: [
            {userId: "A", sharePaise: 60000},
            {userId: "B", sharePaise: 60000},
            {userId: "C", sharePaise: 60000},
            {userId: "D", sharePaise: 60000},
            {userId: "E", sharePaise: 60000},
          ],
          description: "Groceries",
        }),
      );

      // Expense 3: Electricity — C pays 200000 paise (2,000 INR), split equally 5 ways
      await seedDoc(
        `${contextPath}/expenses/exp-electricity`,
        makeExpense({
          payerId: "C",
          amountPaise: 200000,
          splits: [
            {userId: "A", sharePaise: 40000},
            {userId: "B", sharePaise: 40000},
            {userId: "C", sharePaise: 40000},
            {userId: "D", sharePaise: 40000},
            {userId: "E", sharePaise: 40000},
          ],
          description: "Electricity",
        }),
      );
    });

    it("should produce exactly 4 transfers", async () => {
      const result = await handler({
        contextType: "group",
        contextId: "int-test-group-5p",
      });

      expect(result.ok).toBe(true);
      expect(result.transfers).toHaveLength(4);
    });

    it("should compute correct net balances and transfers", async () => {
      // Net balances:
      //   A: +5000000 - 1000000 - 60000 - 40000 = +3900000
      //   B: +300000 - 1000000 - 60000 - 40000  = -800000
      //   C: +200000 - 1000000 - 60000 - 40000  = -900000
      //   D: -1000000 - 60000 - 40000            = -1100000
      //   E: -1000000 - 60000 - 40000            = -1100000
      //
      // Greedy algorithm (sorted by absolute amount descending, ties by userId asc):
      //   Creditors: A(3900000)
      //   Debtors:   D(1100000), E(1100000), C(900000), B(800000)
      //
      //   D -> A: 1100000  (A remaining: 2800000)
      //   E -> A: 1100000  (A remaining: 1700000)
      //   C -> A:  900000  (A remaining:  800000)
      //   B -> A:  800000  (A remaining:       0)

      const result = await handler({
        contextType: "group",
        contextId: "int-test-group-5p",
      });

      expect(result.transfers).toEqual([
        {from: "D", to: "A", amountPaise: 1100000},
        {from: "E", to: "A", amountPaise: 1100000},
        {from: "C", to: "A", amountPaise: 900000},
        {from: "B", to: "A", amountPaise: 800000},
      ]);

      expect(result.simplifiedBalances).toEqual({
        D: {A: 1100000},
        E: {A: 1100000},
        C: {A: 900000},
        B: {A: 800000},
      });
    });

    it("should persist simplifiedBalances to the Firestore group document", async () => {
      await handler({
        contextType: "group",
        contextId: "int-test-group-5p",
      });

      const snap = await db.doc(contextPath).get();
      const data = snap.data()!;
      expect(data.simplifiedBalances).toEqual({
        D: {A: 1100000},
        E: {A: 1100000},
        C: {A: 900000},
        B: {A: 800000},
      });
    });
  });

  // -------------------------------------------------------------------------
  // 3. Empty expenses
  // -------------------------------------------------------------------------
  describe("empty expenses", () => {
    const contextPath = "friendships/int-test-empty-expenses";

    beforeEach(async () => {
      await seedDoc(contextPath, {
        memberIds: ["A", "B"],
        simplifiedBalances: {},
        lastActivityAt: Timestamp.now(),
      });
    });

    it("should return empty transfers and empty simplifiedBalances", async () => {
      const result = await handler({
        contextType: "friendship",
        contextId: "int-test-empty-expenses",
      });

      expect(result.ok).toBe(true);
      expect(result.transfers).toEqual([]);
      expect(result.simplifiedBalances).toEqual({});
    });

    it("should write empty simplifiedBalances to Firestore", async () => {
      await handler({
        contextType: "friendship",
        contextId: "int-test-empty-expenses",
      });

      const snap = await db.doc(contextPath).get();
      const data = snap.data()!;
      expect(data.simplifiedBalances).toEqual({});
    });
  });

  // -------------------------------------------------------------------------
  // 4. Idempotent invocation
  // -------------------------------------------------------------------------
  describe("idempotent invocation", () => {
    const contextPath = "friendships/int-test-idempotent";

    beforeEach(async () => {
      await seedDoc(contextPath, {
        memberIds: ["X", "Y"],
        simplifiedBalances: {},
        lastActivityAt: Timestamp.now(),
      });

      await seedDoc(
        `${contextPath}/expenses/exp1`,
        makeExpense({
          payerId: "X",
          amountPaise: 50000,
          splits: [
            {userId: "X", sharePaise: 25000},
            {userId: "Y", sharePaise: 25000},
          ],
          description: "Lunch",
        }),
      );
    });

    it("should produce identical results on consecutive invocations", async () => {
      const result1 = await handler({
        contextType: "friendship",
        contextId: "int-test-idempotent",
      });

      const result2 = await handler({
        contextType: "friendship",
        contextId: "int-test-idempotent",
      });

      expect(result1.ok).toBe(true);
      expect(result2.ok).toBe(true);
      expect(result1.transfers).toEqual(result2.transfers);
      expect(result1.simplifiedBalances).toEqual(result2.simplifiedBalances);
    });

    it("should leave Firestore in the same state after both calls", async () => {
      await handler({
        contextType: "friendship",
        contextId: "int-test-idempotent",
      });

      const snap1 = await db.doc(contextPath).get();
      const balances1 = snap1.data()!.simplifiedBalances;

      await handler({
        contextType: "friendship",
        contextId: "int-test-idempotent",
      });

      const snap2 = await db.doc(contextPath).get();
      const balances2 = snap2.data()!.simplifiedBalances;

      expect(balances1).toEqual(balances2);
      expect(balances2).toEqual({Y: {X: 25000}});
    });
  });

  // -------------------------------------------------------------------------
  // 5. Non-existent context
  // -------------------------------------------------------------------------
  describe("non-existent context", () => {
    it("should throw not-found with CONTEXT_NOT_FOUND for missing friendship", async () => {
      await expect(
        handler({
          contextType: "friendship",
          contextId: "does-not-exist-friendship",
        }),
      ).rejects.toMatchObject({
        code: "not-found",
        details: {errorCode: "CONTEXT_NOT_FOUND"},
      });
    });

    it("should throw not-found with CONTEXT_NOT_FOUND for missing group", async () => {
      await expect(
        handler({
          contextType: "group",
          contextId: "does-not-exist-group",
        }),
      ).rejects.toMatchObject({
        code: "not-found",
        details: {errorCode: "CONTEXT_NOT_FOUND"},
      });
    });
  });

  // -------------------------------------------------------------------------
  // 6. Deleted expenses are excluded
  // -------------------------------------------------------------------------
  describe("deleted expenses are excluded", () => {
    const contextPath = "friendships/int-test-deleted-expenses";

    beforeEach(async () => {
      await seedDoc(contextPath, {
        memberIds: ["P", "Q"],
        simplifiedBalances: {},
        lastActivityAt: Timestamp.now(),
      });

      // Active expense: P paid 40000, split equally
      await seedDoc(
        `${contextPath}/expenses/exp-active`,
        makeExpense({
          payerId: "P",
          amountPaise: 40000,
          splits: [
            {userId: "P", sharePaise: 20000},
            {userId: "Q", sharePaise: 20000},
          ],
          deleted: false,
          description: "Active expense",
        }),
      );

      // Deleted expense: Q paid 100000, split equally — should be ignored
      await seedDoc(
        `${contextPath}/expenses/exp-deleted`,
        makeExpense({
          payerId: "Q",
          amountPaise: 100000,
          splits: [
            {userId: "P", sharePaise: 50000},
            {userId: "Q", sharePaise: 50000},
          ],
          deleted: true,
          description: "Deleted expense",
        }),
      );
    });

    it("should only use the non-deleted expense for computation", async () => {
      const result = await handler({
        contextType: "friendship",
        contextId: "int-test-deleted-expenses",
      });

      expect(result.ok).toBe(true);

      // Only the active expense: P paid 40000, each owes 20000.
      // P net: +40000 - 20000 = +20000 (creditor)
      // Q net: -20000 (debtor)
      expect(result.transfers).toEqual([
        {from: "Q", to: "P", amountPaise: 20000},
      ]);

      expect(result.simplifiedBalances).toEqual({
        Q: {P: 20000},
      });
    });

    it("should persist correct balances excluding deleted expense", async () => {
      await handler({
        contextType: "friendship",
        contextId: "int-test-deleted-expenses",
      });

      const snap = await db.doc(contextPath).get();
      const data = snap.data()!;
      expect(data.simplifiedBalances).toEqual({
        Q: {P: 20000},
      });
    });
  });
});
