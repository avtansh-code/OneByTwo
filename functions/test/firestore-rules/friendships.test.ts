/**
 * Firestore security rules tests for the friendships collection.
 *
 * Uses @firebase/rules-unit-testing to validate that the rules in
 * firestore.rules enforce the expected access-control semantics for
 * friendship documents.
 *
 * Prerequisites: Firestore emulator running on port 8181.
 * Run with: npm run test:rules
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

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Valid friendship document shape per the Firestore schema.
 * memberIds must be sorted ascending and the deterministic document ID
 * is the two UIDs joined with '_'.
 */
function validFriendshipDoc(overrides: Record<string, unknown> = {}) {
  return {
    memberIds: ["user-aaa", "user-bbb"],
    createdBy: "user-aaa",
    lastActivityAt: serverTimestamp(),
    ...overrides,
  };
}

/**
 * Deterministic friendship ID for two users (sorted UIDs joined with '_').
 */
function friendshipId(uidA: string, uidB: string): string {
  return [uidA, uidB].sort().join("_");
}

// ---------------------------------------------------------------------------
// Setup / Teardown
// ---------------------------------------------------------------------------

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
// Create tests
// ---------------------------------------------------------------------------

describe("friendships/{friendshipId} — create rules", () => {
  const uidA = "user-aaa";
  const uidB = "user-bbb";
  const docId = friendshipId(uidA, uidB); // "user-aaa_user-bbb"

  it("allows an authenticated member to create a valid friendship", async () => {
    const ctx = testEnv.authenticatedContext(uidA);
    const friendshipDoc = doc(ctx.firestore(), `friendships/${docId}`);
    await assertSucceeds(setDoc(friendshipDoc, validFriendshipDoc()));
  });

  it("allows the second member to create the friendship", async () => {
    const ctx = testEnv.authenticatedContext(uidB);
    const friendshipDoc = doc(ctx.firestore(), `friendships/${docId}`);
    await assertSucceeds(
      setDoc(friendshipDoc, validFriendshipDoc({createdBy: uidB})),
    );
  });

  it("rejects creation by a user who is NOT a member of the friendship", async () => {
    const ctx = testEnv.authenticatedContext("outsider-uid");
    const friendshipDoc = doc(ctx.firestore(), `friendships/${docId}`);
    await assertFails(setDoc(friendshipDoc, validFriendshipDoc()));
  });

  it("rejects creation with simplifiedBalances present (Invariant 2)", async () => {
    const ctx = testEnv.authenticatedContext(uidA);
    const friendshipDoc = doc(ctx.firestore(), `friendships/${docId}`);
    await assertFails(
      setDoc(
        friendshipDoc,
        validFriendshipDoc({simplifiedBalances: {}}),
      ),
    );
  });

  it("rejects creation with simplifiedBalances containing data (Invariant 2)", async () => {
    const ctx = testEnv.authenticatedContext(uidA);
    const friendshipDoc = doc(ctx.firestore(), `friendships/${docId}`);
    await assertFails(
      setDoc(
        friendshipDoc,
        validFriendshipDoc({simplifiedBalances: {[uidB]: {[uidA]: 5000}}}),
      ),
    );
  });

  it("rejects creation with memberIds count != 2 (too few)", async () => {
    const ctx = testEnv.authenticatedContext(uidA);
    const friendshipDoc = doc(ctx.firestore(), `friendships/${docId}`);
    await assertFails(
      setDoc(friendshipDoc, validFriendshipDoc({memberIds: [uidA]})),
    );
  });

  it("rejects creation with memberIds count != 2 (too many)", async () => {
    const ctx = testEnv.authenticatedContext(uidA);
    const friendshipDoc = doc(ctx.firestore(), `friendships/${docId}`);
    await assertFails(
      setDoc(
        friendshipDoc,
        validFriendshipDoc({memberIds: [uidA, uidB, "user-ccc"]}),
      ),
    );
  });

  it("rejects creation with unsorted memberIds", async () => {
    const ctx = testEnv.authenticatedContext(uidB);
    const docIdReversed = friendshipId(uidA, uidB);
    const friendshipDoc = doc(ctx.firestore(), `friendships/${docIdReversed}`);
    await assertFails(
      setDoc(
        friendshipDoc,
        validFriendshipDoc({memberIds: [uidB, uidA]}), // reversed order
      ),
    );
  });

  it("rejects creation by an unauthenticated user", async () => {
    const ctx = testEnv.unauthenticatedContext();
    const friendshipDoc = doc(ctx.firestore(), `friendships/${docId}`);
    await assertFails(setDoc(friendshipDoc, validFriendshipDoc()));
  });
});

// ---------------------------------------------------------------------------
// Read tests
// ---------------------------------------------------------------------------

describe("friendships/{friendshipId} — read rules", () => {
  const uidA = "user-aaa";
  const uidB = "user-bbb";
  const docId = friendshipId(uidA, uidB);

  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      const adminDoc = doc(adminCtx.firestore(), `friendships/${docId}`);
      await setDoc(adminDoc, {
        memberIds: [uidA, uidB],
        createdBy: uidA,
        lastActivityAt: new Date(),
      });
    });
  });

  it("allows the first member to read the friendship", async () => {
    const ctx = testEnv.authenticatedContext(uidA);
    const friendshipDoc = doc(ctx.firestore(), `friendships/${docId}`);
    await assertSucceeds(getDoc(friendshipDoc));
  });

  it("allows the second member to read the friendship", async () => {
    const ctx = testEnv.authenticatedContext(uidB);
    const friendshipDoc = doc(ctx.firestore(), `friendships/${docId}`);
    await assertSucceeds(getDoc(friendshipDoc));
  });

  it("rejects read by a non-member", async () => {
    const ctx = testEnv.authenticatedContext("outsider-uid");
    const friendshipDoc = doc(ctx.firestore(), `friendships/${docId}`);
    await assertFails(getDoc(friendshipDoc));
  });

  it("rejects unauthenticated read", async () => {
    const ctx = testEnv.unauthenticatedContext();
    const friendshipDoc = doc(ctx.firestore(), `friendships/${docId}`);
    await assertFails(getDoc(friendshipDoc));
  });
});

// ---------------------------------------------------------------------------
// Update tests
// ---------------------------------------------------------------------------

describe("friendships/{friendshipId} — update rules", () => {
  const uidA = "user-aaa";
  const uidB = "user-bbb";
  const docId = friendshipId(uidA, uidB);

  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      const adminDoc = doc(adminCtx.firestore(), `friendships/${docId}`);
      await setDoc(adminDoc, {
        memberIds: [uidA, uidB],
        createdBy: uidA,
        lastActivityAt: new Date(),
      });
    });
  });

  it("allows a member to update lastActivityAt", async () => {
    const ctx = testEnv.authenticatedContext(uidA);
    const friendshipDoc = doc(ctx.firestore(), `friendships/${docId}`);
    await assertSucceeds(
      updateDoc(friendshipDoc, {lastActivityAt: serverTimestamp()}),
    );
  });

  it("rejects member updating simplifiedBalances (Invariant 2)", async () => {
    const ctx = testEnv.authenticatedContext(uidA);
    const friendshipDoc = doc(ctx.firestore(), `friendships/${docId}`);
    await assertFails(
      updateDoc(friendshipDoc, {simplifiedBalances: {[uidB]: {[uidA]: 5000}}}),
    );
  });

  it("rejects member updating simplifiedBalances to empty map (Invariant 2)", async () => {
    const ctx = testEnv.authenticatedContext(uidA);
    const friendshipDoc = doc(ctx.firestore(), `friendships/${docId}`);
    await assertFails(
      updateDoc(friendshipDoc, {simplifiedBalances: {}}),
    );
  });

  it("rejects member updating memberIds (immutable)", async () => {
    const ctx = testEnv.authenticatedContext(uidA);
    const friendshipDoc = doc(ctx.firestore(), `friendships/${docId}`);
    await assertFails(
      updateDoc(friendshipDoc, {memberIds: [uidA, "user-ccc"]}),
    );
  });

  it("rejects non-member updating the friendship", async () => {
    const ctx = testEnv.authenticatedContext("outsider-uid");
    const friendshipDoc = doc(ctx.firestore(), `friendships/${docId}`);
    await assertFails(
      updateDoc(friendshipDoc, {lastActivityAt: serverTimestamp()}),
    );
  });
});

// ---------------------------------------------------------------------------
// Delete tests
// ---------------------------------------------------------------------------

describe("friendships/{friendshipId} — delete rules", () => {
  const uidA = "user-aaa";
  const uidB = "user-bbb";
  const docId = friendshipId(uidA, uidB);

  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      const adminDoc = doc(adminCtx.firestore(), `friendships/${docId}`);
      await setDoc(adminDoc, {
        memberIds: [uidA, uidB],
        createdBy: uidA,
        lastActivityAt: new Date(),
      });
    });
  });

  it("denies deletion by the first member (default-deny for v1.0)", async () => {
    const ctx = testEnv.authenticatedContext(uidA);
    const friendshipDoc = doc(ctx.firestore(), `friendships/${docId}`);
    await assertFails(deleteDoc(friendshipDoc));
  });

  it("denies deletion by the second member (default-deny for v1.0)", async () => {
    const ctx = testEnv.authenticatedContext(uidB);
    const friendshipDoc = doc(ctx.firestore(), `friendships/${docId}`);
    await assertFails(deleteDoc(friendshipDoc));
  });

  it("denies deletion by a non-member", async () => {
    const ctx = testEnv.authenticatedContext("outsider-uid");
    const friendshipDoc = doc(ctx.firestore(), `friendships/${docId}`);
    await assertFails(deleteDoc(friendshipDoc));
  });

  it("denies unauthenticated deletion", async () => {
    const ctx = testEnv.unauthenticatedContext();
    const friendshipDoc = doc(ctx.firestore(), `friendships/${docId}`);
    await assertFails(deleteDoc(friendshipDoc));
  });
});

// ---------------------------------------------------------------------------
// Admin / service account bypass
// ---------------------------------------------------------------------------

describe("friendships/{friendshipId} — admin SDK bypass", () => {
  const uidA = "user-aaa";
  const uidB = "user-bbb";
  const docId = friendshipId(uidA, uidB);

  it("allows admin SDK to write simplifiedBalances (Invariant 2 — server-only)", async () => {
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      const adminDoc = doc(adminCtx.firestore(), `friendships/${docId}`);
      // Create the doc first
      await setDoc(adminDoc, {
        memberIds: [uidA, uidB],
        createdBy: uidA,
        lastActivityAt: new Date(),
        simplifiedBalances: {[uidB]: {[uidA]: 5000}},
      });

      // Verify it was written
      const snap = await getDoc(adminDoc);
      expect(snap.exists()).toBe(true);
      const data = snap.data();
      expect(data?.simplifiedBalances).toEqual({[uidB]: {[uidA]: 5000}});
    });
  });
});
