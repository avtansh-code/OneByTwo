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
// Phone number change (FR-PR-02)
//
// phoneNumber is immutable EXCEPT a change to the caller's freshly
// re-verified auth phone. The relaxed `isValidUserUpdate()` clause is
// `data.phoneNumber == prev.phoneNumber ||
//  data.phoneNumber == request.auth.token.phone_number`. The client forces
// an ID-token refresh after `updatePhoneNumber` so the `phone_number` claim
// reflects the NEW number before this write (ADR-0015). These tests model
// the post-refresh token via the `phone_number` claim on the auth context.
// ---------------------------------------------------------------------------

describe("users/{userId} — phoneNumber change (FR-PR-02)", () => {
  beforeEach(async () => {
    await seedUserDoc();
  });

  it("allows changing phoneNumber to the caller's (refreshed) token phone", async () => {
    // Token claim is the NEW number, simulating the post-getIdToken(true)
    // state the client establishes before the Firestore write.
    const ctx = testEnv.authenticatedContext(uid, {
      phone_number: "+919123456780",
    });
    const userDoc = doc(ctx.firestore(), `users/${uid}`);
    await assertSucceeds(
      updateDoc(userDoc, {
        phoneNumber: "+919123456780",
        updatedAt: serverTimestamp(),
      })
    );
  });

  it("rejects changing phoneNumber to an arbitrary value (not the token phone)", async () => {
    // The token still carries the OLD number — the rule must reject a write
    // to any other number than request.auth.token.phone_number.
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

  it("rejects a phoneNumber change bundled with an immutable createdAt change", async () => {
    // Even when phoneNumber matches the token phone, every OTHER immutability
    // check still holds — createdAt cannot move.
    const ctx = testEnv.authenticatedContext(uid, {
      phone_number: "+919123456780",
    });
    const userDoc = doc(ctx.firestore(), `users/${uid}`);
    await assertFails(
      updateDoc(userDoc, {
        phoneNumber: "+919123456780",
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })
    );
  });

  it("rejects a phoneNumber change that also drops a required notificationPrefs key", async () => {
    // The relaxation is scoped to phoneNumber only — the full document shape
    // (here, notificationPrefs) is still validated on every update.
    const ctx = testEnv.authenticatedContext(uid, {
      phone_number: "+919123456780",
    });
    const userDoc = doc(ctx.firestore(), `users/${uid}`);
    await assertFails(
      updateDoc(userDoc, {
        phoneNumber: "+919123456780",
        notificationPrefs: {newExpense: true, settlement: true},
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

// ---------------------------------------------------------------------------
// notificationPrefs updates (FR-PR-03)
//
// Defence-in-depth coverage for the partial-map dot-path update path used by
// the SCR-27 notification preferences screen. The existing
// `isValidUserUpdate` + `isValidNotificationPrefs` rule functions (lines
// 72-99 of firestore.rules) already cover this path because Firestore
// evaluates rules against the POST-MERGE `request.resource.data` snapshot:
// the merge preserves untouched keys, so the rules re-validate the full
// `notificationPrefs` map shape on every write. These three tests pin that
// behaviour to the AC-17 / AC-18 / AC-19 contracts in the story.
// ---------------------------------------------------------------------------

describe("users/{userId} — notificationPrefs updates", () => {
  beforeEach(async () => {
    // Seeds the baseline user doc with the full
    // `{newExpense: true, settlement: true, reminder: true}` prefs map via
    // `validUserDoc()`.
    await seedUserDoc();
  });

  it("allows a partial-map dot-path flip of notificationPrefs.reminder to false",
    async () => {
      // AC-17: partial-map dot-path update succeeds. The post-merge
      // notificationPrefs map is {newExpense: true, settlement: true,
      // reminder: false} — still satisfies `isValidNotificationPrefs`
      // (hasAll + each key `is bool`).
      const ctx = testEnv.authenticatedContext(uid, {
        phone_number: "+919876543210",
      });
      const userDoc = doc(ctx.firestore(), `users/${uid}`);
      await assertSucceeds(
        updateDoc(userDoc, {
          "notificationPrefs.reminder": false,
          updatedAt: serverTimestamp(),
        })
      );
    });

  it("rejects a partial-map dot-path update with a non-bool value",
    async () => {
      // AC-18: partial-map dot-path update with a string value fails the
      // `prefs.reminder is bool` clause of `isValidNotificationPrefs`. The
      // post-merge notificationPrefs.reminder is the string "yes", not a
      // bool, so the rule rejects.
      const ctx = testEnv.authenticatedContext(uid, {
        phone_number: "+919876543210",
      });
      const userDoc = doc(ctx.firestore(), `users/${uid}`);
      await assertFails(
        updateDoc(userDoc, {
          "notificationPrefs.reminder": "yes",
          updatedAt: serverTimestamp(),
        })
      );
    });

  it("rejects a full-replace that drops a required notificationPrefs key",
    async () => {
      // AC-19: full-replace (no dot in the key) that omits `reminder` fails
      // the `hasAll(['newExpense', 'settlement', 'reminder'])` clause of
      // `isValidNotificationPrefs`. The post-merge notificationPrefs map
      // only has two keys, so the rule rejects.
      const ctx = testEnv.authenticatedContext(uid, {
        phone_number: "+919876543210",
      });
      const userDoc = doc(ctx.firestore(), `users/${uid}`);
      await assertFails(
        updateDoc(userDoc, {
          notificationPrefs: {newExpense: true, settlement: true},
          updatedAt: serverTimestamp(),
        })
      );
    });
});
