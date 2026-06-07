/**
 * Firestore Security Rules tests for the `activity/{userId}/items/{itemId}`
 * collection (FR-EX-07).
 *
 * Covers ACs AC-6 through AC-12 of the FR-EX-07 story:
 *
 *   - AC-6  — Authenticated owner can read their own activity items.
 *   - AC-7  — Non-owner cannot read another user's activity items.
 *   - AC-8  — Unauthenticated read rejected.
 *   - AC-9  — Client cannot create an activity item (server-only write).
 *   - AC-10 — Client cannot update an activity item.
 *   - AC-11 — Client cannot delete an activity item.
 *   - AC-12 — Reading the parent `activity/{userId}` document is rejected.
 *
 * Defence-in-depth: the parent activity document has an explicit
 * `allow read, write: if false` rather than relying solely on the top-of-file
 * default-deny match. The subcollection's read predicate is
 * `request.auth.uid == userId`; writes are uniformly denied to clients
 * (only the Cloud Functions service account, which bypasses rules, may write).
 *
 * @module test/firestore-rules/activity.test.ts
 */

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import {readFileSync} from "fs";
import {resolve} from "path";
import {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  serverTimestamp,
  setLogLevel,
} from "firebase/firestore";

const PROJECT_ID = "demo-onebytwo";
const RULES_PATH = resolve(__dirname, "../../../firestore.rules");

/**
 * Valid activity-item document shape per
 * docs/design/07-technical/firestore-schema.md lines 194-211 and the
 * FR-EX-07 architect notes §2.6 (`expense_added` shape).
 */
function validActivityItemDoc(
  overrides: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    type: "expense_added",
    payload: {
      expenseId: "expense-abc",
      friendshipId: "uidA_uidB",
      description: "Test expense",
      amountPaise: 10000,
      category: "food",
      payerId: "uidA",
      splits: [
        {userId: "uidA", sharePaise: 5000},
        {userId: "uidB", sharePaise: 5000},
      ],
      splitMethod: "equal",
      hasReceipt: false,
      authorUid: "uidA",
    },
    createdAt: serverTimestamp(),
    ...overrides,
  };
}

let testEnv: RulesTestEnvironment;

beforeAll(async () => {
  setLogLevel("error");
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(RULES_PATH, "utf8"),
      host: "127.0.0.1",
      port: 8181,
    },
  });
});

afterEach(async () => {
  await testEnv.clearFirestore();
});

afterAll(async () => {
  await testEnv.cleanup();
});

// ---------------------------------------------------------------------------
// AC-6 — Authenticated owner can read their own activity items
// ---------------------------------------------------------------------------

describe("activity/{userId}/items — read rules (AC-6, AC-7, AC-8)", () => {
  const uidA = "uid-alice";
  const uidB = "uid-bob";
  const itemId = "seeded-item-id";

  beforeEach(async () => {
    // Admin-seed an activity item under uidA (bypasses rules so the
    // read-tests have something to read).
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      const itemDoc = doc(
        adminCtx.firestore(),
        `activity/${uidA}/items/${itemId}`,
      );
      await setDoc(itemDoc, validActivityItemDoc());
    });
  });

  it("AC-6: allows an authenticated owner to read their own activity items", async () => {
    const ctx = testEnv.authenticatedContext(uidA);
    const itemDoc = doc(ctx.firestore(), `activity/${uidA}/items/${itemId}`);
    await assertSucceeds(getDoc(itemDoc));
  });

  it("AC-7: rejects a different authenticated user reading another's activity items", async () => {
    const ctx = testEnv.authenticatedContext(uidB);
    const itemDoc = doc(ctx.firestore(), `activity/${uidA}/items/${itemId}`);
    await assertFails(getDoc(itemDoc));
  });

  it("AC-8: rejects an unauthenticated client reading any activity items", async () => {
    const ctx = testEnv.unauthenticatedContext();
    const itemDoc = doc(ctx.firestore(), `activity/${uidA}/items/${itemId}`);
    await assertFails(getDoc(itemDoc));
  });

  // Defence-in-depth: cross-uid mismatch on the read predicate.
  it("AC-7 (variant): rejects a different authenticated user reading even with no item present", async () => {
    const ctx = testEnv.authenticatedContext(uidB);
    const missingItemDoc = doc(
      ctx.firestore(),
      `activity/${uidA}/items/non-existent-id`,
    );
    await assertFails(getDoc(missingItemDoc));
  });
});

// ---------------------------------------------------------------------------
// AC-9 / AC-10 / AC-11 — Client cannot write (create / update / delete)
// ---------------------------------------------------------------------------

describe("activity/{userId}/items — write rules (AC-9, AC-10, AC-11)", () => {
  const uidA = "uid-alice";
  const seededItemId = "seeded-item-id";

  beforeEach(async () => {
    // Admin-seed an item so the update/delete tests have a target.
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      const itemDoc = doc(
        adminCtx.firestore(),
        `activity/${uidA}/items/${seededItemId}`,
      );
      await setDoc(itemDoc, validActivityItemDoc());
    });
  });

  it("AC-9: rejects the owner attempting to CREATE an activity item under their own path", async () => {
    const ctx = testEnv.authenticatedContext(uidA);
    const newItemDoc = doc(
      ctx.firestore(),
      `activity/${uidA}/items/client-attempted-id`,
    );
    await assertFails(setDoc(newItemDoc, validActivityItemDoc()));
  });

  it("AC-9 (variant): rejects a different authenticated user creating an item under another user's path", async () => {
    const ctx = testEnv.authenticatedContext("uid-bob");
    const newItemDoc = doc(
      ctx.firestore(),
      `activity/${uidA}/items/client-attempted-id`,
    );
    await assertFails(setDoc(newItemDoc, validActivityItemDoc()));
  });

  it("AC-9 (variant): rejects an unauthenticated client creating an activity item", async () => {
    const ctx = testEnv.unauthenticatedContext();
    const newItemDoc = doc(
      ctx.firestore(),
      `activity/${uidA}/items/client-attempted-id`,
    );
    await assertFails(setDoc(newItemDoc, validActivityItemDoc()));
  });

  it("AC-10: rejects the owner attempting to UPDATE an existing activity item", async () => {
    const ctx = testEnv.authenticatedContext(uidA);
    const itemDoc = doc(
      ctx.firestore(),
      `activity/${uidA}/items/${seededItemId}`,
    );
    await assertFails(updateDoc(itemDoc, {type: "expense_edited"}));
  });

  it("AC-11: rejects the owner attempting to DELETE an existing activity item", async () => {
    const ctx = testEnv.authenticatedContext(uidA);
    const itemDoc = doc(
      ctx.firestore(),
      `activity/${uidA}/items/${seededItemId}`,
    );
    await assertFails(deleteDoc(itemDoc));
  });
});

// ---------------------------------------------------------------------------
// AC-12 — Parent activity/{userId} document read rejected
// ---------------------------------------------------------------------------

describe("activity/{userId} parent document — defence-in-depth (AC-12)", () => {
  const uidA = "uid-alice";

  it("AC-12: rejects the owner attempting to read the parent activity/{userId} document", async () => {
    const ctx = testEnv.authenticatedContext(uidA);
    const parentDoc = doc(ctx.firestore(), `activity/${uidA}`);
    // The parent doc never holds semantic content; only the subcollection
    // is the read surface. Explicit `allow read, write: if false` on the
    // parent is defence-in-depth over the top-of-file default-deny.
    await assertFails(getDoc(parentDoc));
  });

  it("AC-12 (variant): rejects creating the parent activity/{userId} document", async () => {
    const ctx = testEnv.authenticatedContext(uidA);
    const parentDoc = doc(ctx.firestore(), `activity/${uidA}`);
    await assertFails(setDoc(parentDoc, {marker: "anything"}));
  });

  it("AC-12 (variant): rejects an unauthenticated client reading the parent document", async () => {
    const ctx = testEnv.unauthenticatedContext();
    const parentDoc = doc(ctx.firestore(), `activity/${uidA}`);
    await assertFails(getDoc(parentDoc));
  });
});
