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
  setDoc,
  updateDoc,
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
// Helpers
// ---------------------------------------------------------------------------

const uid = "user-update-test";

/** Seed the user document via admin bypass before each test in a describe. */
async function seedUserDoc(overrides: Record<string, unknown> = {}) {
  await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
    const adminDoc = doc(adminCtx.firestore(), `users/${uid}`);
    await setDoc(adminDoc, validUserDoc(overrides));
  });
}

// ---------------------------------------------------------------------------
// Valid updates
// ---------------------------------------------------------------------------

describe("users/{userId} — valid updates", () => {
  beforeEach(async () => {
    await seedUserDoc();
  });

  it("allows owner to update displayName", async () => {
    const ctx = testEnv.authenticatedContext(uid, {
      phone_number: "+919876543210",
    });
    const userDoc = doc(ctx.firestore(), `users/${uid}`);
    await assertSucceeds(
      updateDoc(userDoc, {
        displayName: "New Name",
        updatedAt: serverTimestamp(),
      })
    );
  });

  it("allows owner to update photoUrl", async () => {
    const ctx = testEnv.authenticatedContext(uid, {
      phone_number: "+919876543210",
    });
    const userDoc = doc(ctx.firestore(), `users/${uid}`);
    await assertSucceeds(
      updateDoc(userDoc, {
        photoUrl: "https://example.com/new.jpg",
        updatedAt: serverTimestamp(),
      })
    );
  });

  it("allows owner to update both displayName and photoUrl", async () => {
    const ctx = testEnv.authenticatedContext(uid, {
      phone_number: "+919876543210",
    });
    const userDoc = doc(ctx.firestore(), `users/${uid}`);
    await assertSucceeds(
      updateDoc(userDoc, {
        displayName: "Another Name",
        photoUrl: "https://example.com/avatar.png",
        updatedAt: serverTimestamp(),
      })
    );
  });

  it("allows owner to set photoUrl to null (remove photo)", async () => {
    // Seed with a non-null photoUrl so we can remove it.
    await testEnv.clearFirestore();
    await seedUserDoc({photoUrl: "https://example.com/old.jpg"});

    const ctx = testEnv.authenticatedContext(uid, {
      phone_number: "+919876543210",
    });
    const userDoc = doc(ctx.firestore(), `users/${uid}`);
    await assertSucceeds(
      updateDoc(userDoc, {
        photoUrl: null,
        updatedAt: serverTimestamp(),
      })
    );
  });
});

// ---------------------------------------------------------------------------
// Immutable fields
// ---------------------------------------------------------------------------

describe("users/{userId} — immutable fields", () => {
  beforeEach(async () => {
    await seedUserDoc();
  });

  it("rejects update that changes phoneNumber", async () => {
    const ctx = testEnv.authenticatedContext(uid, {
      phone_number: "+919876543210",
    });
    const userDoc = doc(ctx.firestore(), `users/${uid}`);
    await assertFails(
      updateDoc(userDoc, {
        phoneNumber: "+919999999999",
        updatedAt: serverTimestamp(),
      })
    );
  });

  it("rejects update that changes createdAt", async () => {
    const ctx = testEnv.authenticatedContext(uid, {
      phone_number: "+919876543210",
    });
    const userDoc = doc(ctx.firestore(), `users/${uid}`);
    await assertFails(
      updateDoc(userDoc, {
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
    );
  });
});

// ---------------------------------------------------------------------------
// Validation constraints
// ---------------------------------------------------------------------------

describe("users/{userId} — validation constraints", () => {
  beforeEach(async () => {
    await seedUserDoc();
  });

  it("rejects empty displayName", async () => {
    const ctx = testEnv.authenticatedContext(uid, {
      phone_number: "+919876543210",
    });
    const userDoc = doc(ctx.firestore(), `users/${uid}`);
    await assertFails(
      updateDoc(userDoc, {
        displayName: "",
        updatedAt: serverTimestamp(),
      })
    );
  });

  it("rejects displayName longer than 50 characters", async () => {
    const ctx = testEnv.authenticatedContext(uid, {
      phone_number: "+919876543210",
    });
    const userDoc = doc(ctx.firestore(), `users/${uid}`);
    await assertFails(
      updateDoc(userDoc, {
        displayName: "A".repeat(51),
        updatedAt: serverTimestamp(),
      })
    );
  });
});

// ---------------------------------------------------------------------------
// Access control
// ---------------------------------------------------------------------------

describe("users/{userId} — access control", () => {
  beforeEach(async () => {
    await seedUserDoc();
  });

  it("rejects update by a different authenticated user", async () => {
    const ctx = testEnv.authenticatedContext("user-b", {
      phone_number: "+911234567890",
    });
    const userDoc = doc(ctx.firestore(), `users/${uid}`);
    await assertFails(
      updateDoc(userDoc, {
        displayName: "Hacked Name",
        updatedAt: serverTimestamp(),
      })
    );
  });

  it("rejects update by unauthenticated client", async () => {
    const ctx = testEnv.unauthenticatedContext();
    const userDoc = doc(ctx.firestore(), `users/${uid}`);
    await assertFails(
      updateDoc(userDoc, {
        displayName: "Anonymous",
        updatedAt: serverTimestamp(),
      })
    );
  });
});
