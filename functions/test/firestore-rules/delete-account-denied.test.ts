/**
 * FR-AU-09 — server-only account-deletion boundary (Security Rules).
 *
 * Account deletion runs exclusively in the `deleteUserAccount` Cloud
 * Function via the Admin SDK, which bypasses Security Rules. Clients have
 * NO delete path (ADR-0016). This suite confirms — in FR-AU-09's name —
 * that a client cannot delete the documents the cascade removes, so the
 * server-only boundary the feature depends on stays intact. It complements
 * (does not replace) the per-collection delete-rule suites in
 * `users.test.ts`, `friendships.test.ts`, and `settlements.test.ts`.
 *
 * Maps to FR-AU-09 AC-8 (client-side deletes stay rejected by Security
 * Rules).
 */

import {
  assertFails,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import {readFileSync} from "fs";
import {resolve} from "path";
import {doc, setDoc, deleteDoc, setLogLevel} from "firebase/firestore";

const PROJECT_ID = "demo-onebytwo";
const RULES_PATH = resolve(__dirname, "../../../firestore.rules");

const UID_A = "fr-au-09-user-a";
const UID_B = "fr-au-09-user-b";
const FRIENDSHIP_ID = `${UID_A}_${UID_B}`;

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

describe("FR-AU-09 — client deletes stay denied (server-only cascade)", () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      const db = adminCtx.firestore();
      await setDoc(doc(db, `users/${UID_A}`), {
        phoneNumber: "+919876500001",
        displayName: "Avtansh",
        photoUrl: null,
        fcmTokens: [],
        notificationPrefs: {newExpense: true, settlement: true, reminder: true},
        locale: "en-IN",
        createdAt: new Date(),
        updatedAt: new Date(),
      });
      await setDoc(doc(db, `friendships/${FRIENDSHIP_ID}`), {
        memberIds: [UID_A, UID_B],
        createdBy: UID_A,
        lastActivityAt: new Date(),
      });
    });
  });

  it("rejects a client deleting their own users/{uid} document", async () => {
    const ctx = testEnv.authenticatedContext(UID_A);
    await assertFails(deleteDoc(doc(ctx.firestore(), `users/${UID_A}`)));
  });

  it("rejects a member deleting a friendship they belong to", async () => {
    const ctx = testEnv.authenticatedContext(UID_A);
    await assertFails(
      deleteDoc(doc(ctx.firestore(), `friendships/${FRIENDSHIP_ID}`)),
    );
  });

  it("rejects the surviving member deleting the friendship (history preserved)", async () => {
    const ctx = testEnv.authenticatedContext(UID_B);
    await assertFails(
      deleteDoc(doc(ctx.firestore(), `friendships/${FRIENDSHIP_ID}`)),
    );
  });
});
