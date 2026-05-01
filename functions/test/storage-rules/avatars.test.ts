import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import {readFileSync} from "fs";
import {resolve} from "path";
import {ref, uploadBytes, getDownloadURL} from "firebase/storage";

const PROJECT_ID = "demo-onebytwo";
const RULES_PATH = resolve(__dirname, "../../../storage.rules");

/** A minimal 1x1 PNG image for upload tests. */
const TINY_PNG = Buffer.from(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
  "base64"
);

let testEnv: RulesTestEnvironment;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    storage: {
      rules: readFileSync(RULES_PATH, "utf8"),
      host: "127.0.0.1",
      port: 9199,
    },
  });
});

afterEach(async () => {
  await testEnv.clearStorage();
});

afterAll(async () => {
  await testEnv.cleanup();
});

describe("avatars/{userId} — write rules", () => {
  const uid = "user-avatar-123";

  it("allows authenticated user to upload their own avatar", async () => {
    const ctx = testEnv.authenticatedContext(uid);
    const avatarRef = ref(ctx.storage(), `avatars/${uid}`);
    await assertSucceeds(
      uploadBytes(avatarRef, TINY_PNG, {contentType: "image/png"})
    );
  });

  it("rejects upload to another user's avatar path", async () => {
    const ctx = testEnv.authenticatedContext(uid);
    const avatarRef = ref(ctx.storage(), "avatars/other-user");
    await assertFails(
      uploadBytes(avatarRef, TINY_PNG, {contentType: "image/png"})
    );
  });

  it("rejects unauthenticated upload", async () => {
    const ctx = testEnv.unauthenticatedContext();
    const avatarRef = ref(ctx.storage(), `avatars/${uid}`);
    await assertFails(
      uploadBytes(avatarRef, TINY_PNG, {contentType: "image/png"})
    );
  });
});

describe("avatars/{userId} — read rules", () => {
  const ownerUid = "user-avatar-owner";
  const otherUid = "user-avatar-other";

  beforeEach(async () => {
    // Seed an avatar via admin (bypass rules).
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      const avatarRef = ref(adminCtx.storage(), `avatars/${ownerUid}`);
      await uploadBytes(avatarRef, TINY_PNG, {contentType: "image/png"});
    });
  });

  it("allows authenticated user to read their own avatar", async () => {
    const ctx = testEnv.authenticatedContext(ownerUid);
    const avatarRef = ref(ctx.storage(), `avatars/${ownerUid}`);
    await assertSucceeds(getDownloadURL(avatarRef));
  });

  it("allows another authenticated user to read someone else's avatar", async () => {
    const ctx = testEnv.authenticatedContext(otherUid);
    const avatarRef = ref(ctx.storage(), `avatars/${ownerUid}`);
    await assertSucceeds(getDownloadURL(avatarRef));
  });

  it("rejects unauthenticated avatar read", async () => {
    const ctx = testEnv.unauthenticatedContext();
    const avatarRef = ref(ctx.storage(), `avatars/${ownerUid}`);
    await assertFails(getDownloadURL(avatarRef));
  });
});
