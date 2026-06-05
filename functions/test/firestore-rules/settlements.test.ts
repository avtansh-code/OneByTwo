/**
 * Firestore Security Rules tests for the new `settlements/{settlementId}`
 * collection (FR-SE-05/06).
 *
 * Validates the access-control posture introduced by this story — AC-1
 * through AC-6 of the FR-SE-05-06-settlement-trigger story:
 *
 *   - AC-1: create allowed for fromUserId only.
 *   - AC-2: read allowed for both parties.
 *   - AC-3: verificationStatus is server-only (Invariant-2 parallel per
 *     ARCH-EXT-06).
 *   - AC-4: extension-point locks (method='manual', currency='INR',
 *     verificationStatus='unverified').
 *   - AC-5: historical-field immutability (only `deleted` may change).
 *   - AC-6: hard delete denied.
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
  setDoc,
  updateDoc,
  deleteDoc,
  getDoc,
  serverTimestamp,
  setLogLevel,
} from "firebase/firestore";

const PROJECT_ID = "demo-onebytwo";
const RULES_PATH = resolve(__dirname, "../../../firestore.rules");

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
const SETTLEMENT_ID = "settlement-1";

/**
 * A valid settlement document shape. fromUserId defaults to memberA
 * (the payer); toUserId is memberB (the recipient). Splits sum and
 * other invariants are not relevant for settlements — only the listed
 * field set and extension-point locks.
 */
function validSettlementDoc(overrides: Record<string, unknown> = {}) {
  return {
    fromUserId: memberA,
    toUserId: memberB,
    amountPaise: 5000,
    contextType: "friendship",
    contextId: FID,
    date: serverTimestamp(),
    note: null,
    method: "manual",                  // ARCH-EXT-01
    verificationStatus: "unverified",  // ARCH-EXT-06
    currency: "INR",                   // ARCH-EXT-02
    createdAt: serverTimestamp(),
    deleted: false,
    ...overrides,
  };
}

/** Seeds the parent friendship doc via admin (bypasses rules). */
async function seedFriendship(testEnv: RulesTestEnvironment) {
  const path = `friendships/${FID}`;
  await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
    await setDoc(doc(adminCtx.firestore(), path), {
      memberIds: [memberA, memberB],
      createdBy: memberA,
      lastActivityAt: new Date(),
      simplifiedBalances: {},
    });
  });
  trackPath(path);
}

/** Seeds a valid settlement doc via admin (bypasses rules). */
async function seedSettlement(
  testEnv: RulesTestEnvironment,
  settlementId: string = SETTLEMENT_ID,
  overrides: Record<string, unknown> = {},
) {
  const path = `settlements/${settlementId}`;
  await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
    await setDoc(
      doc(adminCtx.firestore(), path),
      {
        fromUserId: memberA,
        toUserId: memberB,
        amountPaise: 5000,
        contextType: "friendship",
        contextId: FID,
        date: new Date(),
        note: null,
        method: "manual",
        verificationStatus: "unverified",
        currency: "INR",
        createdAt: new Date(),
        deleted: false,
        ...overrides,
      },
    );
  });
  trackPath(path);
}

// ---------------------------------------------------------------------------
// Setup / Teardown
// ---------------------------------------------------------------------------

let testEnv: RulesTestEnvironment;

// Track docs created during each test so afterEach can delete them
// targeted (instead of `clearFirestore`, which acquires a global lock
// that can time out when an in-flight on-settlement-write trigger
// transaction is still draining). The on-settlement-write trigger
// reads BOTH the per-context friendship doc AND the top-level
// settlements collection inside a single transaction, so it has a
// wider race window with the global clearFirestore lock than the
// expense trigger does (the latter reads only the per-context
// expenses subcollection).
const createdDocPaths: string[] = [];

function trackPath(path: string) {
  if (!createdDocPaths.includes(path)) {
    createdDocPaths.push(path);
  }
}

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
  // Brief drain delay before deleting docs. The on-settlement-write
  // trigger reads BOTH the per-context friendship doc AND the top-level
  // settlements collection inside a single transaction. Targeted
  // deletes (instead of clearFirestore) avoid the global Firestore
  // lock; the brief delay lets pending trigger transactions complete
  // cleanly. This is test-only and does not affect production
  // semantics.
  await new Promise((r) => setTimeout(r, 100));
  await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
    // Known paths the test suite may create. Includes tracked seeds
    // PLUS the well-known settlement-ID suffixes used by CREATE tests
    // (which write via authenticated contexts, not the helpers).
    const knownPaths = [
      `friendships/${FID}`,
      `settlements/${SETTLEMENT_ID}`,
      `settlements/${SETTLEMENT_ID}-deleted`,
      `settlements/${SETTLEMENT_ID}-neg`,
      `settlements/${SETTLEMENT_ID}-2`,
      ...createdDocPaths,
    ];
    // De-duplicate then sort longest paths first (deepest first).
    const uniqueSorted = [...new Set(knownPaths)].sort(
      (a, b) => b.length - a.length,
    );
    for (const path of uniqueSorted) {
      try {
        await deleteDoc(doc(adminCtx.firestore(), path));
      } catch {
        // ignore — may already be gone
      }
    }
  });
  createdDocPaths.length = 0;
});

afterAll(async () => {
  await testEnv.cleanup();
});

// ---------------------------------------------------------------------------
// AC-2 — READ tests
// ---------------------------------------------------------------------------

describe("settlements/{sid} — read rules (AC-2)", () => {
  beforeEach(async () => {
    await seedFriendship(testEnv);
    await seedSettlement(testEnv);
  });

  it("allows the fromUserId to read", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertSucceeds(
      getDoc(doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`)),
    );
  });

  it("allows the toUserId to read", async () => {
    const ctx = testEnv.authenticatedContext(memberB);
    await assertSucceeds(
      getDoc(doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`)),
    );
  });

  it("rejects read by an outsider", async () => {
    const ctx = testEnv.authenticatedContext(outsider);
    await assertFails(
      getDoc(doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`)),
    );
  });

  it("rejects unauthenticated read", async () => {
    const ctx = testEnv.unauthenticatedContext();
    await assertFails(
      getDoc(doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`)),
    );
  });
});

// ---------------------------------------------------------------------------
// AC-1, AC-4 — CREATE tests
// ---------------------------------------------------------------------------

describe("settlements/{sid} — create rules (AC-1, AC-4)", () => {
  beforeEach(async () => {
    await seedFriendship(testEnv);
  });

  it("allows fromUserId == request.auth.uid to create a valid settlement", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertSucceeds(
      setDoc(
        doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`),
        validSettlementDoc(),
      ),
    );
  });

  it("allows memberB to create with fromUserId == memberB", async () => {
    const ctx = testEnv.authenticatedContext(memberB);
    await assertSucceeds(
      setDoc(
        doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`),
        validSettlementDoc({fromUserId: memberB, toUserId: memberA}),
      ),
    );
  });

  it("rejects creation when fromUserId != request.auth.uid (memberB authoring as memberA)", async () => {
    const ctx = testEnv.authenticatedContext(memberB);
    await assertFails(
      setDoc(
        doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`),
        validSettlementDoc({fromUserId: memberA}),
      ),
    );
  });

  it("rejects creation by an outsider (not a member of the context)", async () => {
    const ctx = testEnv.authenticatedContext(outsider);
    await assertFails(
      setDoc(
        doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`),
        validSettlementDoc({fromUserId: outsider, toUserId: memberA}),
      ),
    );
  });

  it("rejects creation by an unauthenticated caller", async () => {
    const ctx = testEnv.unauthenticatedContext();
    await assertFails(
      setDoc(
        doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`),
        validSettlementDoc(),
      ),
    );
  });

  it("rejects creation when fromUserId == toUserId", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      setDoc(
        doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`),
        validSettlementDoc({toUserId: memberA}),
      ),
    );
  });

  it("rejects creation when toUserId is not a member of the context", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      setDoc(
        doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`),
        validSettlementDoc({toUserId: outsider}),
      ),
    );
  });

  it("rejects creation when amountPaise <= 0 (Invariant 1)", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      setDoc(
        doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`),
        validSettlementDoc({amountPaise: 0}),
      ),
    );
    await assertFails(
      setDoc(
        doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}-neg`),
        validSettlementDoc({amountPaise: -100}),
      ),
    );
  });

  it("rejects creation when amountPaise is not an integer", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      setDoc(
        doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`),
        validSettlementDoc({amountPaise: 1.5}),
      ),
    );
  });

  // ── Extension-point locks (AC-4) ──────────────────────────────────────

  it("rejects creation when method != 'manual' (ARCH-EXT-01)", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      setDoc(
        doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`),
        validSettlementDoc({method: "upi"}),
      ),
    );
  });

  it("rejects creation when currency != 'INR' (ARCH-EXT-02)", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      setDoc(
        doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`),
        validSettlementDoc({currency: "USD"}),
      ),
    );
  });

  it("rejects creation when verificationStatus != 'unverified' (ARCH-EXT-06)", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      setDoc(
        doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`),
        validSettlementDoc({verificationStatus: "verified"}),
      ),
    );
    await assertFails(
      setDoc(
        doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}-2`),
        validSettlementDoc({verificationStatus: "pending"}),
      ),
    );
  });

  // ── Schema discipline ────────────────────────────────────────────────

  it("rejects creation when contextType is unknown", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      setDoc(
        doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`),
        validSettlementDoc({contextType: "team"}),
      ),
    );
  });

  it("rejects creation with deleted: true on create", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      setDoc(
        doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`),
        validSettlementDoc({deleted: true}),
      ),
    );
  });

  it("rejects creation with an unknown extra field", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      setDoc(
        doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`),
        validSettlementDoc({rogueField: "value"}),
      ),
    );
  });

  it("rejects creation when contextId is empty", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      setDoc(
        doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`),
        validSettlementDoc({contextId: ""}),
      ),
    );
  });

  it("rejects creation when createdAt != request.time", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      setDoc(
        doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`),
        validSettlementDoc({createdAt: new Date(2020, 0, 1)}),
      ),
    );
  });
});

// ---------------------------------------------------------------------------
// AC-3, AC-5 — UPDATE tests
// ---------------------------------------------------------------------------

describe("settlements/{sid} — update rules (AC-3, AC-5)", () => {
  beforeEach(async () => {
    await seedFriendship(testEnv);
    await seedSettlement(testEnv);
  });

  // ── Soft-delete (the ONLY supported update by any party) ────────────

  it("allows fromUserId to soft-delete (set deleted=true)", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertSucceeds(
      updateDoc(
        doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`),
        {deleted: true},
      ),
    );
  });

  it("allows toUserId to soft-delete (set deleted=true)", async () => {
    const ctx = testEnv.authenticatedContext(memberB);
    await assertSucceeds(
      updateDoc(
        doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`),
        {deleted: true},
      ),
    );
  });

  it("rejects soft-delete by an outsider", async () => {
    const ctx = testEnv.authenticatedContext(outsider);
    await assertFails(
      updateDoc(
        doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`),
        {deleted: true},
      ),
    );
  });

  it("rejects setting deleted back to false (un-delete is admin-only)", async () => {
    await seedSettlement(testEnv, `${SETTLEMENT_ID}-deleted`, {deleted: true});
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      updateDoc(
        doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}-deleted`),
        {deleted: false},
      ),
    );
  });

  // ── Immutability (AC-5) ─────────────────────────────────────────────

  it("rejects update that mutates fromUserId", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      updateDoc(
        doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`),
        {fromUserId: memberB},
      ),
    );
  });

  it("rejects update that mutates toUserId", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      updateDoc(
        doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`),
        {toUserId: outsider},
      ),
    );
  });

  it("rejects update that mutates amountPaise", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      updateDoc(
        doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`),
        {amountPaise: 9999},
      ),
    );
  });

  it("rejects update that mutates contextType", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      updateDoc(
        doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`),
        {contextType: "group"},
      ),
    );
  });

  it("rejects update that mutates contextId", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      updateDoc(
        doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`),
        {contextId: "another-fid"},
      ),
    );
  });

  it("rejects update that mutates createdAt", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      updateDoc(
        doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`),
        {createdAt: new Date(2020, 0, 1)},
      ),
    );
  });

  it("rejects update that mutates note", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      updateDoc(
        doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`),
        {note: "edited after the fact"},
      ),
    );
  });

  it("rejects update that mutates method", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      updateDoc(
        doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`),
        {method: "upi"},
      ),
    );
  });

  it("rejects update that mutates currency", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      updateDoc(
        doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`),
        {currency: "USD"},
      ),
    );
  });

  // ── verificationStatus is server-only (Invariant-2 parallel, AC-3) ──

  it("rejects update that mutates verificationStatus (Invariant-2 parallel)", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      updateDoc(
        doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`),
        {verificationStatus: "verified"},
      ),
    );
  });

  it("rejects update that mutates verificationStatus by the toUserId", async () => {
    const ctx = testEnv.authenticatedContext(memberB);
    await assertFails(
      updateDoc(
        doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`),
        {verificationStatus: "pending"},
      ),
    );
  });

  it("rejects multi-field update even if one field is the allowed deleted flag", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      updateDoc(
        doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`),
        {deleted: true, note: "extra"},
      ),
    );
  });

  it("rejects unauthenticated update", async () => {
    const ctx = testEnv.unauthenticatedContext();
    await assertFails(
      updateDoc(
        doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`),
        {deleted: true},
      ),
    );
  });
});

// ---------------------------------------------------------------------------
// AC-6 — DELETE tests (hard delete denied)
// ---------------------------------------------------------------------------

describe("settlements/{sid} — delete rules (AC-6)", () => {
  beforeEach(async () => {
    await seedFriendship(testEnv);
    await seedSettlement(testEnv);
  });

  it("rejects hard delete by fromUserId", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      deleteDoc(doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`)),
    );
  });

  it("rejects hard delete by toUserId", async () => {
    const ctx = testEnv.authenticatedContext(memberB);
    await assertFails(
      deleteDoc(doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`)),
    );
  });

  it("rejects hard delete by an outsider", async () => {
    const ctx = testEnv.authenticatedContext(outsider);
    await assertFails(
      deleteDoc(doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`)),
    );
  });

  it("rejects unauthenticated hard delete", async () => {
    const ctx = testEnv.unauthenticatedContext();
    await assertFails(
      deleteDoc(doc(ctx.firestore(), `settlements/${SETTLEMENT_ID}`)),
    );
  });

  it("allows admin SDK to hard delete (rules bypass)", async () => {
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      await deleteDoc(
        doc(adminCtx.firestore(), `settlements/${SETTLEMENT_ID}`),
      );
      const snap = await getDoc(
        doc(adminCtx.firestore(), `settlements/${SETTLEMENT_ID}`),
      );
      expect(snap.exists()).toBe(false);
    });
  });
});
