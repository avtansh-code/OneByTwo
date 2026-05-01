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
  serverTimestamp,
  setLogLevel,
} from "firebase/firestore";

const PROJECT_ID = "demo-onebytwo";
const RULES_PATH = resolve(__dirname, "../../../firestore.rules");

/** Valid user document shape per docs/design/07-technical/firestore-schema.md. */
function validUserDoc(overrides: Record<string, unknown> = {}) {
  return {
    phoneNumber: "+919876543210",
    displayName: "Avtansh",
    photoUrl: null,
    fcmTokens: [],
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    notificationPrefs: {newExpense: true, settlement: true, reminder: true},
    locale: "en-IN",
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
      port: 8080,
    },
  });
});

afterEach(async () => {
  await testEnv.clearFirestore();
});

afterAll(async () => {
  await testEnv.cleanup();
});

describe("users/{userId} — create rules", () => {
  const uid = "user-abc-123";

  it("allows an authenticated user to create their own user doc", async () => {
    const ctx = testEnv.authenticatedContext(uid, {
      phone_number: "+919876543210",
    });
    const userDoc = doc(ctx.firestore(), `users/${uid}`);
    await assertSucceeds(setDoc(userDoc, validUserDoc()));
  });

  it("rejects creation when userId does not match auth uid", async () => {
    const ctx = testEnv.authenticatedContext("different-uid", {
      phone_number: "+919876543210",
    });
    const userDoc = doc(ctx.firestore(), `users/${uid}`);
    await assertFails(setDoc(userDoc, validUserDoc()));
  });

  it("rejects creation when user doc already exists (no overwrite)", async () => {
    // Seed the document via admin (bypass rules).
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      const adminDoc = doc(adminCtx.firestore(), `users/${uid}`);
      await setDoc(adminDoc, validUserDoc());
    });

    // Attempt a second create as the authenticated user.
    const ctx = testEnv.authenticatedContext(uid, {
      phone_number: "+919876543210",
    });
    const userDoc = doc(ctx.firestore(), `users/${uid}`);
    await assertFails(setDoc(userDoc, validUserDoc()));
  });

  it("rejects creation by an unauthenticated user", async () => {
    const ctx = testEnv.unauthenticatedContext();
    const userDoc = doc(ctx.firestore(), `users/${uid}`);
    await assertFails(setDoc(userDoc, validUserDoc()));
  });

  it("rejects creation with a missing required field (displayName)", async () => {
    const ctx = testEnv.authenticatedContext(uid, {
      phone_number: "+919876543210",
    });
    const userDoc = doc(ctx.firestore(), `users/${uid}`);
    const invalidDoc = validUserDoc();
    delete (invalidDoc as Record<string, unknown>).displayName;
    await assertFails(setDoc(userDoc, invalidDoc));
  });

  it("rejects creation with wrong phoneNumber (not matching auth token)", async () => {
    const ctx = testEnv.authenticatedContext(uid, {
      phone_number: "+919876543210",
    });
    const userDoc = doc(ctx.firestore(), `users/${uid}`);
    await assertFails(
      setDoc(userDoc, validUserDoc({phoneNumber: "+919999999999"}))
    );
  });

  it("rejects creation with extra unexpected fields", async () => {
    const ctx = testEnv.authenticatedContext(uid, {
      phone_number: "+919876543210",
    });
    const userDoc = doc(ctx.firestore(), `users/${uid}`);
    await assertFails(
      setDoc(userDoc, validUserDoc({isAdmin: true}))
    );
  });

  it("rejects creation with invalid locale", async () => {
    const ctx = testEnv.authenticatedContext(uid, {
      phone_number: "+919876543210",
    });
    const userDoc = doc(ctx.firestore(), `users/${uid}`);
    await assertFails(
      setDoc(userDoc, validUserDoc({locale: "fr-FR"}))
    );
  });

  it("rejects creation with invalid notificationPrefs shape", async () => {
    const ctx = testEnv.authenticatedContext(uid, {
      phone_number: "+919876543210",
    });
    const userDoc = doc(ctx.firestore(), `users/${uid}`);
    await assertFails(
      setDoc(userDoc, validUserDoc({notificationPrefs: {spamAll: true}}))
    );
  });
});

describe("users/{userId} — read rules", () => {
  const uid = "user-read-test";

  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      const adminDoc = doc(adminCtx.firestore(), `users/${uid}`);
      await setDoc(adminDoc, validUserDoc());
    });
  });

  it("allows an authenticated user to read their own user doc", async () => {
    const ctx = testEnv.authenticatedContext(uid);
    const userDoc = doc(ctx.firestore(), `users/${uid}`);
    await assertSucceeds(getDoc(userDoc));
  });

  it("rejects reading another user's doc", async () => {
    const ctx = testEnv.authenticatedContext("other-user");
    const userDoc = doc(ctx.firestore(), `users/${uid}`);
    await assertFails(getDoc(userDoc));
  });

  it("rejects unauthenticated read", async () => {
    const ctx = testEnv.unauthenticatedContext();
    const userDoc = doc(ctx.firestore(), `users/${uid}`);
    await assertFails(getDoc(userDoc));
  });
});

describe("users/{userId} — update rules", () => {
  const uid = "user-update-test";

  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      const adminDoc = doc(adminCtx.firestore(), `users/${uid}`);
      await setDoc(adminDoc, validUserDoc());
    });
  });

  it("rejects update that changes phoneNumber (immutable field)", async () => {
    const ctx = testEnv.authenticatedContext(uid, {
      phone_number: "+919876543210",
    });
    const userDoc = doc(ctx.firestore(), `users/${uid}`);
    await assertFails(
      setDoc(userDoc, validUserDoc({phoneNumber: "+919999999999"}), {merge: true})
    );
  });

  it("rejects update that changes createdAt (immutable field)", async () => {
    const ctx = testEnv.authenticatedContext(uid, {
      phone_number: "+919876543210",
    });
    const userDoc = doc(ctx.firestore(), `users/${uid}`);
    await assertFails(
      setDoc(userDoc, validUserDoc(), {merge: true})
    );
  });
});

describe("users/{userId} — delete rules", () => {
  const uid = "user-delete-test";

  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      const adminDoc = doc(adminCtx.firestore(), `users/${uid}`);
      await setDoc(adminDoc, validUserDoc());
    });
  });

  it("rejects deletion even by the document owner", async () => {
    const ctx = testEnv.authenticatedContext(uid);
    const {deleteDoc} = await import("firebase/firestore");
    const userDoc = doc(ctx.firestore(), `users/${uid}`);
    await assertFails(deleteDoc(userDoc));
  });
});
