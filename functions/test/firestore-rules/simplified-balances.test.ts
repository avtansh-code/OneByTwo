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
  serverTimestamp,
  setLogLevel,
} from "firebase/firestore";

const PROJECT_ID = "demo-onebytwo";
const RULES_PATH = resolve(__dirname, "../../../firestore.rules");

/** Valid friendship document shape for seeding and creation tests. */
function validFriendshipDoc(overrides: Record<string, unknown> = {}) {
  return {
    memberIds: ["user-a", "user-b"],
    lastActivityAt: serverTimestamp(),
    ...overrides,
  };
}

/** Valid group document shape for seeding and creation tests. */
function validGroupDoc(overrides: Record<string, unknown> = {}) {
  return {
    name: "Test Group",
    type: "trip",
    memberIds: ["user-a", "user-b"],
    adminId: "user-a",
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
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
// Friendships — simplifiedBalances is client-read-only (Invariant 2)
// ---------------------------------------------------------------------------

describe("friendships/{friendshipId} — simplifiedBalances read access", () => {
  const friendshipId = "friendship-sb-read";

  it("allows an authenticated member to read a friendship doc including simplifiedBalances", async () => {
    // Seed via admin with simplifiedBalances already present (as Cloud Function would write).
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      const adminDoc = doc(adminCtx.firestore(), `friendships/${friendshipId}`);
      await setDoc(adminDoc, {
        memberIds: ["user-a", "user-b"],
        lastActivityAt: serverTimestamp(),
        simplifiedBalances: {"user-b": {"user-a": 20000}},
      });
    });

    const ctx = testEnv.authenticatedContext("user-a");
    const friendDoc = doc(ctx.firestore(), `friendships/${friendshipId}`);
    await assertSucceeds(getDoc(friendDoc));
  });

  it("rejects unauthenticated read of a friendship", async () => {
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      const adminDoc = doc(adminCtx.firestore(), `friendships/${friendshipId}`);
      await setDoc(adminDoc, {
        memberIds: ["user-a", "user-b"],
        lastActivityAt: serverTimestamp(),
        simplifiedBalances: {},
      });
    });

    const ctx = testEnv.unauthenticatedContext();
    const friendDoc = doc(ctx.firestore(), `friendships/${friendshipId}`);
    await assertFails(getDoc(friendDoc));
  });

  it("rejects read by a non-member", async () => {
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      const adminDoc = doc(adminCtx.firestore(), `friendships/${friendshipId}`);
      await setDoc(adminDoc, {
        memberIds: ["user-a", "user-b"],
        lastActivityAt: serverTimestamp(),
        simplifiedBalances: {},
      });
    });

    const ctx = testEnv.authenticatedContext("user-c");
    const friendDoc = doc(ctx.firestore(), `friendships/${friendshipId}`);
    await assertFails(getDoc(friendDoc));
  });
});

describe("friendships/{friendshipId} — simplifiedBalances create rules", () => {
  const friendshipId = "friendship-sb-create";

  it("allows a member to create a friendship WITHOUT simplifiedBalances", async () => {
    const ctx = testEnv.authenticatedContext("user-a");
    const friendDoc = doc(ctx.firestore(), `friendships/${friendshipId}`);
    await assertSucceeds(setDoc(friendDoc, validFriendshipDoc()));
  });

  it("rejects creation of a friendship WITH simplifiedBalances", async () => {
    const ctx = testEnv.authenticatedContext("user-a");
    const friendDoc = doc(ctx.firestore(), `friendships/${friendshipId}`);
    await assertFails(
      setDoc(friendDoc, validFriendshipDoc({simplifiedBalances: {}}))
    );
  });
});

describe("friendships/{friendshipId} — simplifiedBalances update rules", () => {
  const friendshipId = "friendship-sb-update";

  it("rejects a member updating simplifiedBalances", async () => {
    // Seed doc with empty simplifiedBalances (as if Cloud Function initialised it).
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      const adminDoc = doc(adminCtx.firestore(), `friendships/${friendshipId}`);
      await setDoc(adminDoc, {
        memberIds: ["user-a", "user-b"],
        lastActivityAt: serverTimestamp(),
        simplifiedBalances: {},
      });
    });

    const ctx = testEnv.authenticatedContext("user-a");
    const friendDoc = doc(ctx.firestore(), `friendships/${friendshipId}`);
    await assertFails(
      updateDoc(friendDoc, {
        simplifiedBalances: {"user-b": {"user-a": 5000}},
      })
    );
  });

  it("allows a member to update other fields without touching simplifiedBalances", async () => {
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      const adminDoc = doc(adminCtx.firestore(), `friendships/${friendshipId}`);
      await setDoc(adminDoc, {
        memberIds: ["user-a", "user-b"],
        lastActivityAt: serverTimestamp(),
        simplifiedBalances: {},
      });
    });

    const ctx = testEnv.authenticatedContext("user-a");
    const friendDoc = doc(ctx.firestore(), `friendships/${friendshipId}`);
    // Update only lastActivityAt; simplifiedBalances and memberIds unchanged.
    await assertSucceeds(
      updateDoc(friendDoc, {
        lastActivityAt: serverTimestamp(),
      })
    );
  });
});

// ---------------------------------------------------------------------------
// Groups — simplifiedBalances is client-read-only (Invariant 2)
// ---------------------------------------------------------------------------

describe("groups/{groupId} — simplifiedBalances read access", () => {
  const groupId = "group-sb-read";

  it("allows an authenticated member to read a group doc including simplifiedBalances", async () => {
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      const adminDoc = doc(adminCtx.firestore(), `groups/${groupId}`);
      await setDoc(adminDoc, {
        name: "Test Group",
        type: "trip",
        memberIds: ["user-a", "user-b"],
        adminId: "user-a",
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
        simplifiedBalances: {"user-b": {"user-a": 10000}},
      });
    });

    const ctx = testEnv.authenticatedContext("user-a");
    const groupDoc = doc(ctx.firestore(), `groups/${groupId}`);
    await assertSucceeds(getDoc(groupDoc));
  });

  it("rejects unauthenticated read of a group", async () => {
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      const adminDoc = doc(adminCtx.firestore(), `groups/${groupId}`);
      await setDoc(adminDoc, {
        name: "Test Group",
        type: "trip",
        memberIds: ["user-a", "user-b"],
        adminId: "user-a",
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
        simplifiedBalances: {},
      });
    });

    const ctx = testEnv.unauthenticatedContext();
    const groupDoc = doc(ctx.firestore(), `groups/${groupId}`);
    await assertFails(getDoc(groupDoc));
  });
});

describe("groups/{groupId} — simplifiedBalances create rules", () => {
  const groupId = "group-sb-create";

  it("rejects creation of a group WITH simplifiedBalances", async () => {
    const ctx = testEnv.authenticatedContext("user-a");
    const groupDoc = doc(ctx.firestore(), `groups/${groupId}`);
    await assertFails(
      setDoc(groupDoc, validGroupDoc({simplifiedBalances: {}}))
    );
  });
});

describe("groups/{groupId} — simplifiedBalances update rules", () => {
  const groupId = "group-sb-update";

  it("rejects a member updating simplifiedBalances on a group", async () => {
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      const adminDoc = doc(adminCtx.firestore(), `groups/${groupId}`);
      await setDoc(adminDoc, {
        name: "Test Group",
        type: "trip",
        memberIds: ["user-a", "user-b"],
        adminId: "user-a",
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
        simplifiedBalances: {},
      });
    });

    const ctx = testEnv.authenticatedContext("user-a");
    const groupDoc = doc(ctx.firestore(), `groups/${groupId}`);
    await assertFails(
      updateDoc(groupDoc, {
        simplifiedBalances: {"user-b": {"user-a": 10000}},
      })
    );
  });

  it("rejects a non-member writing simplifiedBalances to another group (cross-write)", async () => {
    // Seed two groups: user-a is in group-1, user-c is in group-2.
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      const group1Doc = doc(adminCtx.firestore(), "groups/group-cross-1");
      await setDoc(group1Doc, {
        name: "Group One",
        type: "home",
        memberIds: ["user-a", "user-b"],
        adminId: "user-a",
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
        simplifiedBalances: {},
      });

      const group2Doc = doc(adminCtx.firestore(), "groups/group-cross-2");
      await setDoc(group2Doc, {
        name: "Group Two",
        type: "other",
        memberIds: ["user-c", "user-d"],
        adminId: "user-c",
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
        simplifiedBalances: {},
      });
    });

    // user-a (member of group-1) tries to write simplifiedBalances on group-2.
    const ctx = testEnv.authenticatedContext("user-a");
    const group2Doc = doc(ctx.firestore(), "groups/group-cross-2");
    await assertFails(
      updateDoc(group2Doc, {
        simplifiedBalances: {"user-c": {"user-d": 999}},
      })
    );
  });
});

describe("groups/{groupId} — admin SDK bypass (Cloud Functions path)", () => {
  const groupId = "group-admin-bypass";

  it("allows writing simplifiedBalances via admin context (security rules disabled)", async () => {
    // Seed the document first.
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      const adminDoc = doc(adminCtx.firestore(), `groups/${groupId}`);
      await setDoc(adminDoc, {
        name: "Admin Bypass Group",
        type: "couple",
        memberIds: ["user-a", "user-b"],
        adminId: "user-a",
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
        simplifiedBalances: {},
      });
    });

    // Write simplifiedBalances via admin — this is how Cloud Functions operate.
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      const adminDoc = doc(adminCtx.firestore(), `groups/${groupId}`);
      await assertSucceeds(
        updateDoc(adminDoc, {
          simplifiedBalances: {"user-b": {"user-a": 50000}},
        })
      );
    });
  });
});
