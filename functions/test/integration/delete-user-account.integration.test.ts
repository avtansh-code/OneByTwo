/**
 * Integration tests for the FR-AU-09 deleteUserAccount Cloud Function.
 *
 * Runs against the Firebase Emulator Suite (Firestore 8181, Auth 9099,
 * Storage 9199). Seeds real documents / an Auth user / an avatar object,
 * invokes the handler via dependency injection, and asserts the ADR-0016
 * cascade end-to-end:
 *
 *   (a) personal records are gone and users/{uid} is tombstoned;
 *   (b) the surviving member's friendship and simplifiedBalances are
 *       preserved byte-for-byte (Invariant 2);
 *   (c) the surviving member's expense + settlement history survives;
 *   (d) the cascade is idempotent (a re-run after completion succeeds);
 *   (e) an unauthenticated call is rejected with UNAUTHENTICATED.
 *
 * Trigger independence: the Invariant-2 case seeds `simplifiedBalances`
 * DIRECTLY on the friendship document and writes NO expense / settlement,
 * so the deployed `onExpenseWriteFriendship` / `onSettlementWrite` recompute
 * triggers never fire and cannot mutate the seeded value (CI runs
 * `test:integration` with `functions` loaded). The history case writes real
 * expense / settlement docs (which may fire a recompute) but asserts only
 * their survival, never a recomputed balance value.
 *
 * Run with: npm run test:integration
 * Prerequisites: auth, firestore, and storage emulators running.
 */

// Must be set BEFORE importing firebase-admin so the SDK connects to the
// emulators. Honour values already injected by `firebase emulators:exec`.
process.env.FIRESTORE_EMULATOR_HOST =
  process.env.FIRESTORE_EMULATOR_HOST ?? "127.0.0.1:8181";
process.env.FIREBASE_AUTH_EMULATOR_HOST =
  process.env.FIREBASE_AUTH_EMULATOR_HOST ?? "127.0.0.1:9099";
process.env.FIREBASE_STORAGE_EMULATOR_HOST =
  process.env.FIREBASE_STORAGE_EMULATOR_HOST ?? "127.0.0.1:9199";

import {initializeApp, deleteApp, getApp} from "firebase-admin/app";
import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {getAuth} from "firebase-admin/auth";
import {getStorage} from "firebase-admin/storage";
import {HttpsError} from "firebase-functions/v2/https";
import {
  createDeleteUserAccountHandler,
  DeleteUserAccountResponse,
} from "../../src/delete-user-account/function";

// ---------------------------------------------------------------------------
// Constants / shared state
// ---------------------------------------------------------------------------

const PROJECT_ID = "demo-onebytwo";
const APP_NAME = "integration-test-delete-user-account";
const BUCKET = `${PROJECT_ID}.appspot.com`;

const UID_A = "int-del-user-a";
const UID_B = "int-del-user-b";
const FRIENDSHIP_ID = `${UID_A}_${UID_B}`;
const SETTLEMENT_ID = "int-del-settle-1";
const EXPENSE_ID = "exp-1";
/** A shared receipt object — must SURVIVE A's deletion (belongs to B too). */
const RECEIPT_PATH = `receipts/friendships/${FRIENDSHIP_ID}/${EXPENSE_ID}`;

/** A owes B 5_000 paise. Integer paise (Invariant 1). */
const SEEDED_SIMPLIFIED_BALANCES = {
  [UID_A]: {[UID_B]: 5000},
};

let db: FirebaseFirestore.Firestore;
let auth: ReturnType<typeof getAuth>;
let bucket: ReturnType<ReturnType<typeof getStorage>["bucket"]>;
let handler: (
  data: unknown,
  context: {auth?: {uid: string; token?: {auth_time?: number}}},
) => Promise<DeleteUserAccountResponse>;

const noopLogger = {
  info: () => undefined,
  warn: () => undefined,
  error: () => undefined,
};

/** Caller context with a freshly-authenticated `auth_time` (now, in seconds). */
function authCtx(uid: string): {
  auth: {uid: string; token: {auth_time: number}};
} {
  return {auth: {uid, token: {auth_time: Math.floor(Date.now() / 1000)}}};
}

// ---------------------------------------------------------------------------
// Setup / teardown
// ---------------------------------------------------------------------------

beforeAll(() => {
  const app = initializeApp(
    {projectId: PROJECT_ID, storageBucket: BUCKET},
    APP_NAME,
  );
  db = getFirestore(app);
  auth = getAuth(app);
  bucket = getStorage(app).bucket();
  handler = createDeleteUserAccountHandler({
    db,
    authAdmin: auth,
    bucket,
    logger: noopLogger,
  });
});

afterEach(async () => {
  await cleanup();
});

afterAll(async () => {
  await deleteApp(getApp(APP_NAME));
});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function avatarPath(uid: string): string {
  return `avatars/${uid}`;
}

function makeUser(displayName: string, phoneNumber: string) {
  return {
    phoneNumber,
    displayName,
    photoUrl: null,
    fcmTokens: ["token"],
    notificationPrefs: {newExpense: true, settlement: true, reminder: true},
    locale: "en-IN",
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  };
}

/** Seeds the departing user's personal records, avatar, and Auth record. */
async function seedPersonal(): Promise<void> {
  await auth.createUser({uid: UID_A});
  await db.collection("users").doc(UID_A).set(
    makeUser("Avtansh", "+919876500001"),
  );
  await db
    .collection("activity")
    .doc(UID_A)
    .collection("items")
    .doc("item-1")
    .set({type: "expense_added", createdAt: Timestamp.now()});
  await db
    .collection("_rateLimits")
    .doc(UID_A)
    .collection("lookups")
    .doc("counter")
    .set({count: 3, windowStart: Date.now()});
  await bucket
    .file(avatarPath(UID_A))
    .save(Buffer.from([0xff, 0xd8, 0xff]), {contentType: "image/jpeg"});
}

/** Seeds the surviving member B and a friendship with direct balances. */
async function seedSurvivingFriendship(): Promise<void> {
  await auth.createUser({uid: UID_B});
  await db.collection("users").doc(UID_B).set(
    makeUser("Priya", "+919876500002"),
  );
  await db.collection("friendships").doc(FRIENDSHIP_ID).set({
    memberIds: [UID_A, UID_B],
    createdBy: UID_A,
    simplifiedBalances: SEEDED_SIMPLIFIED_BALANCES,
    lastActivityAt: Timestamp.now(),
  });
}

async function cleanup(): Promise<void> {
  await db.recursiveDelete(db.collection("activity").doc(UID_A));
  await db.recursiveDelete(db.collection("_rateLimits").doc(UID_A));
  await db.recursiveDelete(db.collection("friendships").doc(FRIENDSHIP_ID));
  for (const path of [
    `users/${UID_A}`,
    `users/${UID_B}`,
    `settlements/${SETTLEMENT_ID}`,
  ]) {
    await db.doc(path).delete().catch(() => undefined);
  }
  for (const uid of [UID_A, UID_B]) {
    await auth.deleteUser(uid).catch(() => undefined);
    await bucket
      .file(avatarPath(uid))
      .delete({ignoreNotFound: true})
      .catch(() => undefined);
  }
  await bucket
    .file(RECEIPT_PATH)
    .delete({ignoreNotFound: true})
    .catch(() => undefined);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("deleteUserAccount — integration", () => {
  it("removes personal records and tombstones users/{uid}", async () => {
    await seedPersonal();

    const result = await handler(undefined, authCtx(UID_A));
    expect(result).toEqual({success: true});

    // users/A is replaced with the PII-free 'Deleted User' shell.
    const userSnap = await db.collection("users").doc(UID_A).get();
    expect(userSnap.exists).toBe(true);
    const shell = userSnap.data() ?? {};
    expect(shell.displayName).toBe("Deleted User");
    expect(shell.deletedAt).toBeDefined();
    expect(shell).not.toHaveProperty("phoneNumber");
    expect(shell).not.toHaveProperty("photoUrl");
    expect(shell).not.toHaveProperty("fcmTokens");
    expect(shell).not.toHaveProperty("notificationPrefs");
    expect(shell).not.toHaveProperty("locale");

    // activity + rate-limit subtrees are gone.
    const activityItems = await db
      .collection("activity")
      .doc(UID_A)
      .collection("items")
      .get();
    expect(activityItems.empty).toBe(true);
    const rateLimitCounter = await db
      .collection("_rateLimits")
      .doc(UID_A)
      .collection("lookups")
      .doc("counter")
      .get();
    expect(rateLimitCounter.exists).toBe(false);

    // avatar object is gone.
    const [avatarExists] = await bucket.file(avatarPath(UID_A)).exists();
    expect(avatarExists).toBe(false);

    // Auth record is gone.
    await expect(auth.getUser(UID_A)).rejects.toMatchObject({
      code: "auth/user-not-found",
    });
  });

  it(
    "preserves the surviving member's friendship and simplifiedBalances " +
      "byte-for-byte (Invariant 2)",
    async () => {
      await seedPersonal();
      await seedSurvivingFriendship();

      await handler(undefined, authCtx(UID_A));

      const friendshipSnap = await db
        .collection("friendships")
        .doc(FRIENDSHIP_ID)
        .get();
      expect(friendshipSnap.exists).toBe(true);
      expect(friendshipSnap.data()?.simplifiedBalances).toEqual(
        SEEDED_SIMPLIFIED_BALANCES,
      );
      expect(friendshipSnap.data()?.memberIds).toEqual([UID_A, UID_B]);

      // Surviving member's own doc is untouched (still has their PII).
      const userBSnap = await db.collection("users").doc(UID_B).get();
      expect(userBSnap.exists).toBe(true);
      expect(userBSnap.data()?.displayName).toBe("Priya");
      expect(userBSnap.data()?.phoneNumber).toBe("+919876500002");
      // The deleted user A resolves to the tombstone name for B's client.
      const userASnap = await db.collection("users").doc(UID_A).get();
      expect(userASnap.data()?.displayName).toBe("Deleted User");
    },
  );

  it("preserves the surviving member's expense, settlement and receipt history",
    async () => {
      await seedPersonal();
      await seedSurvivingFriendship();
      // A real expense + settlement (these may fire the recompute trigger in
      // CI; we assert only their survival, never a recomputed balance value).
      await db
        .collection("friendships")
        .doc(FRIENDSHIP_ID)
        .collection("expenses")
        .doc(EXPENSE_ID)
        .set({
          payerId: UID_A,
          amountPaise: 10000,
          splits: [
            {userId: UID_A, sharePaise: 5000},
            {userId: UID_B, sharePaise: 5000},
          ],
          deleted: false,
          createdAt: Timestamp.now(),
        });
      await db.collection("settlements").doc(SETTLEMENT_ID).set({
        contextType: "friendship",
        contextId: FRIENDSHIP_ID,
        fromUserId: UID_A,
        toUserId: UID_B,
        amountPaise: 5000,
        deleted: false,
        createdAt: Timestamp.now(),
      });
      // A shared receipt object on the surviving friendship (AC-7) — personal
      // to neither member; must survive A's deletion (only avatars/{uid} is a
      // personal Storage path the cascade removes).
      await bucket
        .file(RECEIPT_PATH)
        .save(Buffer.from([0xff, 0xd8, 0xff]), {contentType: "image/jpeg"});

      await handler(undefined, authCtx(UID_A));

      // The friendship and its history survive (deleteUserAccount never
      // touches friendships / expenses / settlements / receipts).
      expect(
        (await db.collection("friendships").doc(FRIENDSHIP_ID).get()).exists,
      ).toBe(true);
      const expenseSnap = await db
        .collection("friendships")
        .doc(FRIENDSHIP_ID)
        .collection("expenses")
        .doc(EXPENSE_ID)
        .get();
      expect(expenseSnap.exists).toBe(true);
      expect(expenseSnap.data()?.amountPaise).toBe(10000);
      const settlementSnap = await db
        .collection("settlements")
        .doc(SETTLEMENT_ID)
        .get();
      expect(settlementSnap.exists).toBe(true);
      expect(settlementSnap.data()?.amountPaise).toBe(5000);
      // The shared receipt object is preserved.
      const [receiptExists] = await bucket.file(RECEIPT_PATH).exists();
      expect(receiptExists).toBe(true);
    },
  );

  it(
    "is idempotent: a re-run after completion resolves cleanly and keeps " +
      "shared data intact",
    async () => {
      await seedPersonal();
      await seedSurvivingFriendship();

      await handler(undefined, authCtx(UID_A));
      // Second invocation (simulates the SCR-28 edge-case 3/4 retry).
      const second = await handler(undefined, authCtx(UID_A));
      expect(second).toEqual({success: true});

      const friendshipSnap = await db
        .collection("friendships")
        .doc(FRIENDSHIP_ID)
        .get();
      expect(friendshipSnap.exists).toBe(true);
      expect(friendshipSnap.data()?.simplifiedBalances).toEqual(
        SEEDED_SIMPLIFIED_BALANCES,
      );
      const userBSnap = await db.collection("users").doc(UID_B).get();
      expect(userBSnap.data()?.displayName).toBe("Priya");
      // users/A is still a tombstone (not duplicated or restored).
      const userASnap = await db.collection("users").doc(UID_A).get();
      expect(userASnap.data()?.displayName).toBe("Deleted User");
    },
  );

  it("rejects an unauthenticated call with UNAUTHENTICATED", async () => {
    await expect(handler({}, {})).rejects.toBeInstanceOf(HttpsError);
    await expect(handler({}, {})).rejects.toMatchObject({
      code: "unauthenticated",
      details: {errorCode: "UNAUTHENTICATED"},
    });
  });
});
