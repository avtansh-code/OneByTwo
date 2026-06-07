/**
 * Storage Security Rules tests for the new
 * `receipts/{contextType}/{contextId}/{expenseId}` path tree.
 *
 * Validates the access-control posture introduced by FR-EX-05 — the
 * first client uploader to Firebase Storage from the expense feature.
 * Closes R7 (Storage rules file-size test) + R8 (Storage rules MIME
 * test) from the Sprint-1 Bucket-B burndown
 * (docs/audits/sprint-1/07-bucket-b-burndown.md lines 136, 187, 232).
 *
 * Two predicates land in `storage.rules`:
 *
 *   match /receipts/friendships/{friendshipId}/{expenseId} { ... }
 *   match /receipts/groups/{groupId}/{expenseId}           { ... }  // defensive
 *
 * Both predicates use the same `firestore.get()` cross-collection read
 * pattern to validate the caller's membership of the parent context
 * document. The friendship-context UI is the only client surface in
 * PR #48; the group-context predicate is defensive (closes R7 + R8
 * in one shot per architect notes §2.1) and the group-context UI
 * ships with the Sprint 3 groups epic.
 *
 * Prerequisites: Firestore emulator on port 8181 (for the
 * cross-collection predicate's parent-doc read) AND Storage emulator
 * on port 9199.
 * Run with: `npm run test:rules` under
 * `firebase emulators:exec --only firestore,storage`.
 */

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import {readFileSync} from "fs";
import {resolve} from "path";
import {doc, setDoc, setLogLevel} from "firebase/firestore";
import {ref, uploadBytes, getDownloadURL} from "firebase/storage";

const PROJECT_ID = "demo-onebytwo";
const STORAGE_RULES_PATH = resolve(__dirname, "../../../storage.rules");
const FIRESTORE_RULES_PATH = resolve(__dirname, "../../../firestore.rules");

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const memberA = "user-aaa";
const memberB = "user-bbb";
const outsider = "user-outsider";

function friendshipId(uidA: string, uidB: string): string {
  return [uidA, uidB].sort().join("_");
}

const FID = friendshipId(memberA, memberB);
const GID = "group-test-123";
const EID = "expense-abc-123";

/** A minimal 1x1 PNG image for upload tests (~70 bytes). */
const TINY_PNG = Buffer.from(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
  "base64",
);

/** A minimal JPEG header buffer for content-type tests. */
const TINY_JPEG = Buffer.from([
  0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01,
  0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xff, 0xdb, 0x00, 0x43,
  0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
  0x09, 0x08, 0x0a, 0x0c, 0x14, 0x0d, 0x0c, 0x0b, 0x0b, 0x0c, 0x19, 0x12,
  0x13, 0x0f, 0x14, 0x1d, 0x1a, 0x1f, 0x1e, 0x1d, 0x1a, 0x1c, 0x1c, 0x20,
  0x24, 0x2e, 0x27, 0x20, 0x22, 0x2c, 0x23, 0x1c, 0x1c, 0x28, 0x37, 0x29,
  0x2c, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1f, 0x27, 0x39, 0x3d, 0x38, 0x32,
  0x3c, 0x2e, 0x33, 0x34, 0x32, 0xff, 0xd9,
]);

/** Seeds the parent friendship doc via admin (bypasses rules). */
async function seedFriendship(testEnv: RulesTestEnvironment): Promise<void> {
  await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
    await setDoc(doc(adminCtx.firestore(), `friendships/${FID}`), {
      memberIds: [memberA, memberB],
      createdBy: memberA,
      lastActivityAt: new Date(),
      simplifiedBalances: {},
    });
  });
}

/** Seeds the parent group doc via admin (bypasses rules). */
async function seedGroup(testEnv: RulesTestEnvironment): Promise<void> {
  await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
    await setDoc(doc(adminCtx.firestore(), `groups/${GID}`), {
      memberIds: [memberA, memberB],
      createdBy: memberA,
      name: "Test Group",
      lastActivityAt: new Date(),
      simplifiedBalances: {},
    });
  });
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
      rules: readFileSync(FIRESTORE_RULES_PATH, "utf8"),
      host: "127.0.0.1",
      port: 8181,
    },
    storage: {
      rules: readFileSync(STORAGE_RULES_PATH, "utf8"),
      host: "127.0.0.1",
      port: 9199,
    },
  });
});

afterEach(async () => {
  await testEnv.clearStorage();
  await testEnv.clearFirestore();
});

afterAll(async () => {
  await testEnv.cleanup();
});

// ---------------------------------------------------------------------------
// receipts/friendships/{fid}/{eid} — WRITE rules
// ---------------------------------------------------------------------------

describe("receipts/friendships/{fid}/{eid} — write rules", () => {
  beforeEach(async () => {
    await seedFriendship(testEnv);
  });

  it(
    "AC-13: allows authenticated friendship member to upload a JPEG " +
      "<= 10 MB",
    async () => {
      const ctx = testEnv.authenticatedContext(memberA);
      const path = `receipts/friendships/${FID}/${EID}`;
      await assertSucceeds(
        uploadBytes(ref(ctx.storage(), path), TINY_JPEG, {
          contentType: "image/jpeg",
        }),
      );
    },
  );

  it(
    "AC-13 (second member): allows the OTHER friendship member to upload",
    async () => {
      const ctx = testEnv.authenticatedContext(memberB);
      const path = `receipts/friendships/${FID}/${EID}`;
      await assertSucceeds(
        uploadBytes(ref(ctx.storage(), path), TINY_PNG, {
          contentType: "image/png",
        }),
      );
    },
  );

  it("AC-14: rejects non-member upload to a friendship receipt path", async () => {
    const ctx = testEnv.authenticatedContext(outsider);
    const path = `receipts/friendships/${FID}/${EID}`;
    await assertFails(
      uploadBytes(ref(ctx.storage(), path), TINY_JPEG, {
        contentType: "image/jpeg",
      }),
    );
  });

  it("AC-15: rejects unauthenticated upload to a friendship receipt path", async () => {
    const ctx = testEnv.unauthenticatedContext();
    const path = `receipts/friendships/${FID}/${EID}`;
    await assertFails(
      uploadBytes(ref(ctx.storage(), path), TINY_JPEG, {
        contentType: "image/jpeg",
      }),
    );
  });

  it(
    "AC-16: rejects oversize upload (> 10 MB) from an authenticated " +
      "friendship member",
    async () => {
      const ctx = testEnv.authenticatedContext(memberA);
      const path = `receipts/friendships/${FID}/${EID}`;
      const oversize = Buffer.alloc(11 * 1024 * 1024, 0xff);
      await assertFails(
        uploadBytes(ref(ctx.storage(), path), oversize, {
          contentType: "image/jpeg",
        }),
      );
    },
  );

  it(
    "AC-17: rejects unsupported MIME (text/plain) from an authenticated " +
      "friendship member",
    async () => {
      const ctx = testEnv.authenticatedContext(memberA);
      const path = `receipts/friendships/${FID}/${EID}`;
      await assertFails(
        uploadBytes(ref(ctx.storage(), path), Buffer.from("hello"), {
          contentType: "text/plain",
        }),
      );
    },
  );

  it(
    "AC-17 (additional): rejects image/gif from an authenticated " +
      "friendship member (only JPEG and PNG accepted)",
    async () => {
      const ctx = testEnv.authenticatedContext(memberA);
      const path = `receipts/friendships/${FID}/${EID}`;
      await assertFails(
        uploadBytes(ref(ctx.storage(), path), TINY_PNG, {
          contentType: "image/gif",
        }),
      );
    },
  );
});

// ---------------------------------------------------------------------------
// receipts/friendships/{fid}/{eid} — READ rules
// ---------------------------------------------------------------------------

describe("receipts/friendships/{fid}/{eid} — read rules", () => {
  const path = `receipts/friendships/${FID}/${EID}`;

  beforeEach(async () => {
    await seedFriendship(testEnv);
    // Seed a receipt object via admin (bypass rules).
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      await uploadBytes(ref(adminCtx.storage(), path), TINY_JPEG, {
        contentType: "image/jpeg",
      });
    });
  });

  it("AC-18: allows authenticated friendship member to read", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertSucceeds(getDownloadURL(ref(ctx.storage(), path)));
  });

  it("AC-18 (second member): allows the OTHER friendship member to read", async () => {
    const ctx = testEnv.authenticatedContext(memberB);
    await assertSucceeds(getDownloadURL(ref(ctx.storage(), path)));
  });

  it("AC-18: rejects non-member read", async () => {
    const ctx = testEnv.authenticatedContext(outsider);
    await assertFails(getDownloadURL(ref(ctx.storage(), path)));
  });

  it("AC-18: rejects unauthenticated read", async () => {
    const ctx = testEnv.unauthenticatedContext();
    await assertFails(getDownloadURL(ref(ctx.storage(), path)));
  });
});

// ---------------------------------------------------------------------------
// receipts/groups/{gid}/{eid} — WRITE rules (defensive — UI ships
// friendship-only in PR #48; group-context UI is the Sprint 3 epic)
// ---------------------------------------------------------------------------

describe("receipts/groups/{gid}/{eid} — write rules (defensive)", () => {
  beforeEach(async () => {
    await seedGroup(testEnv);
  });

  it("allows authenticated group member to upload a JPEG", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    const path = `receipts/groups/${GID}/${EID}`;
    await assertSucceeds(
      uploadBytes(ref(ctx.storage(), path), TINY_JPEG, {
        contentType: "image/jpeg",
      }),
    );
  });

  it("rejects non-member upload to a group receipt path", async () => {
    const ctx = testEnv.authenticatedContext(outsider);
    const path = `receipts/groups/${GID}/${EID}`;
    await assertFails(
      uploadBytes(ref(ctx.storage(), path), TINY_JPEG, {
        contentType: "image/jpeg",
      }),
    );
  });

  it("rejects unauthenticated upload to a group receipt path", async () => {
    const ctx = testEnv.unauthenticatedContext();
    const path = `receipts/groups/${GID}/${EID}`;
    await assertFails(
      uploadBytes(ref(ctx.storage(), path), TINY_JPEG, {
        contentType: "image/jpeg",
      }),
    );
  });

  it("rejects oversize upload (> 10 MB) from an authenticated group member", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    const path = `receipts/groups/${GID}/${EID}`;
    const oversize = Buffer.alloc(11 * 1024 * 1024, 0xff);
    await assertFails(
      uploadBytes(ref(ctx.storage(), path), oversize, {
        contentType: "image/jpeg",
      }),
    );
  });

  it(
    "rejects unsupported MIME (text/plain) from an authenticated " +
      "group member",
    async () => {
      const ctx = testEnv.authenticatedContext(memberA);
      const path = `receipts/groups/${GID}/${EID}`;
      await assertFails(
        uploadBytes(ref(ctx.storage(), path), Buffer.from("hello"), {
          contentType: "text/plain",
        }),
      );
    },
  );
});

// ---------------------------------------------------------------------------
// receipts/groups/{gid}/{eid} — READ rules (defensive)
// ---------------------------------------------------------------------------

describe("receipts/groups/{gid}/{eid} — read rules (defensive)", () => {
  const path = `receipts/groups/${GID}/${EID}`;

  beforeEach(async () => {
    await seedGroup(testEnv);
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      await uploadBytes(ref(adminCtx.storage(), path), TINY_JPEG, {
        contentType: "image/jpeg",
      });
    });
  });

  it("allows authenticated group member to read", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertSucceeds(getDownloadURL(ref(ctx.storage(), path)));
  });

  it("rejects non-member read", async () => {
    const ctx = testEnv.authenticatedContext(outsider);
    await assertFails(getDownloadURL(ref(ctx.storage(), path)));
  });

  it("rejects unauthenticated read", async () => {
    const ctx = testEnv.unauthenticatedContext();
    await assertFails(getDownloadURL(ref(ctx.storage(), path)));
  });
});

// ---------------------------------------------------------------------------
// Cross-collection predicate verification (§2.9 item 1 — non-trivial
// first for this codebase's Storage rules)
// ---------------------------------------------------------------------------

describe("storage.rules firestore.get() cross-collection predicate", () => {
  it(
    "rejects upload when the parent friendship document does NOT exist " +
      "(get() resolves to null → memberIds 'in' check evaluates false)",
    async () => {
      // Deliberately do NOT seed the friendship doc.
      const ctx = testEnv.authenticatedContext(memberA);
      const path = `receipts/friendships/${FID}/${EID}`;
      await assertFails(
        uploadBytes(ref(ctx.storage(), path), TINY_JPEG, {
          contentType: "image/jpeg",
        }),
      );
    },
  );

  it(
    "rejects upload when the parent group document does NOT exist " +
      "(get() resolves to null → memberIds 'in' check evaluates false)",
    async () => {
      const ctx = testEnv.authenticatedContext(memberA);
      const path = `receipts/groups/${GID}/${EID}`;
      await assertFails(
        uploadBytes(ref(ctx.storage(), path), TINY_JPEG, {
          contentType: "image/jpeg",
        }),
      );
    },
  );
});

// ---------------------------------------------------------------------------
// Default deny — unrelated paths still rejected
// ---------------------------------------------------------------------------

describe("storage default-deny — unrelated paths", () => {
  it("rejects upload to an arbitrary path outside avatars/ and receipts/", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      uploadBytes(ref(ctx.storage(), "random/path/file.jpg"), TINY_JPEG, {
        contentType: "image/jpeg",
      }),
    );
  });

  it("rejects upload to receipts/ root (no contextType segment)", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      uploadBytes(
        ref(ctx.storage(), `receipts/${EID}`),
        TINY_JPEG,
        {contentType: "image/jpeg"},
      ),
    );
  });
});
