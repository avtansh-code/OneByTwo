/**
 * Firestore Security Rules tests for the new
 * `friendships/{friendshipId}/expenses/{expenseId}` subcollection.
 *
 * Validates the access-control posture introduced by PR #36
 * (FR-SE-03/04) — specifically AC-8 of the
 * FR-SE-03-04-expense-trigger-friendship story.
 *
 * The split-sum check (sum of `splits[i].sharePaise` equals
 * `amountPaise`) is the load-bearing Invariant-1 enforcement at the
 * write boundary. This file exercises it exhaustively.
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

/**
 * A valid expense document shape per the schema in
 * docs/design/07-technical/firestore-schema.md and the new rules.
 * Splits sum exactly to amountPaise. createdBy is the caller (override
 * via opts when authenticating as a different user).
 */
function validExpenseDoc(overrides: Record<string, unknown> = {}) {
  return {
    amountPaise: 10000,
    description: "Test expense",
    category: "general",
    date: serverTimestamp(),
    payerId: memberA,
    splits: [
      {userId: memberA, sharePaise: 5000},
      {userId: memberB, sharePaise: 5000},
    ],
    splitMethod: "equal",
    receiptUrl: null,
    createdBy: memberA,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    deleted: false,
    source: "manual",
    currency: "INR",
    recurringRule: null,
    ...overrides,
  };
}

/** Seeds the parent friendship doc via admin (bypasses rules). */
async function seedFriendship(testEnv: RulesTestEnvironment) {
  await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
    await setDoc(doc(adminCtx.firestore(), `friendships/${FID}`), {
      memberIds: [memberA, memberB],
      createdBy: memberA,
      lastActivityAt: new Date(),
      simplifiedBalances: {},
    });
  });
}

/** Seeds a valid expense doc via admin (bypasses rules). */
async function seedExpense(
  testEnv: RulesTestEnvironment,
  expenseId: string,
  overrides: Record<string, unknown> = {},
) {
  await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
    await setDoc(
      doc(
        adminCtx.firestore(),
        `friendships/${FID}/expenses/${expenseId}`,
      ),
      {
        amountPaise: 10000,
        description: "Seeded",
        category: "general",
        date: new Date(),
        payerId: memberA,
        splits: [
          {userId: memberA, sharePaise: 5000},
          {userId: memberB, sharePaise: 5000},
        ],
        splitMethod: "equal",
        receiptUrl: null,
        createdBy: memberA,
        createdAt: new Date(),
        updatedAt: new Date(),
        deleted: false,
        source: "manual",
        currency: "INR",
        recurringRule: null,
        ...overrides,
      },
    );
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
// READ tests
// ---------------------------------------------------------------------------

describe("friendships/{fid}/expenses/{eid} — read rules", () => {
  beforeEach(async () => {
    await seedFriendship(testEnv);
    await seedExpense(testEnv, "exp1");
  });

  it("allows a member to read an expense", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertSucceeds(
      getDoc(doc(ctx.firestore(), `friendships/${FID}/expenses/exp1`)),
    );
  });

  it("allows the second member to read", async () => {
    const ctx = testEnv.authenticatedContext(memberB);
    await assertSucceeds(
      getDoc(doc(ctx.firestore(), `friendships/${FID}/expenses/exp1`)),
    );
  });

  it("rejects read by a non-member", async () => {
    const ctx = testEnv.authenticatedContext(outsider);
    await assertFails(
      getDoc(doc(ctx.firestore(), `friendships/${FID}/expenses/exp1`)),
    );
  });

  it("rejects unauthenticated read", async () => {
    const ctx = testEnv.unauthenticatedContext();
    await assertFails(
      getDoc(doc(ctx.firestore(), `friendships/${FID}/expenses/exp1`)),
    );
  });
});

// ---------------------------------------------------------------------------
// CREATE tests
// ---------------------------------------------------------------------------

describe("friendships/{fid}/expenses/{eid} — create rules", () => {
  beforeEach(async () => {
    await seedFriendship(testEnv);
  });

  it("allows a member to create a valid expense", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertSucceeds(
      setDoc(
        doc(ctx.firestore(), `friendships/${FID}/expenses/exp1`),
        validExpenseDoc(),
      ),
    );
  });

  it("allows the second member to create a valid expense", async () => {
    const ctx = testEnv.authenticatedContext(memberB);
    await assertSucceeds(
      setDoc(
        doc(ctx.firestore(), `friendships/${FID}/expenses/exp2`),
        validExpenseDoc({payerId: memberB, createdBy: memberB}),
      ),
    );
  });

  // ── Invariant 1 — sum check (the load-bearing FR-EX-04 enforcement) ──

  it("rejects creation when splits sum > amountPaise", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      setDoc(
        doc(ctx.firestore(), `friendships/${FID}/expenses/exp1`),
        validExpenseDoc({
          amountPaise: 10000,
          splits: [
            {userId: memberA, sharePaise: 6000},
            {userId: memberB, sharePaise: 5000},
          ],
        }),
      ),
    );
  });

  it("rejects creation when splits sum < amountPaise", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      setDoc(
        doc(ctx.firestore(), `friendships/${FID}/expenses/exp1`),
        validExpenseDoc({
          amountPaise: 10000,
          splits: [
            {userId: memberA, sharePaise: 4000},
            {userId: memberB, sharePaise: 5000},
          ],
        }),
      ),
    );
  });

  it("rejects creation when splits sum mismatches by 1 paise", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      setDoc(
        doc(ctx.firestore(), `friendships/${FID}/expenses/exp1`),
        validExpenseDoc({
          amountPaise: 10000,
          splits: [
            {userId: memberA, sharePaise: 5001},
            {userId: memberB, sharePaise: 5000},
          ],
        }),
      ),
    );
  });

  it("allows a one-split expense (paid by self, owed to self)", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertSucceeds(
      setDoc(
        doc(ctx.firestore(), `friendships/${FID}/expenses/exp1`),
        validExpenseDoc({
          amountPaise: 5000,
          splits: [{userId: memberA, sharePaise: 5000}],
        }),
      ),
    );
  });

  // ── Member checks ──

  it("rejects creation when payerId is not a friendship member", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      setDoc(
        doc(ctx.firestore(), `friendships/${FID}/expenses/exp1`),
        validExpenseDoc({payerId: outsider}),
      ),
    );
  });

  it("rejects creation when a split userId is not a friendship member", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      setDoc(
        doc(ctx.firestore(), `friendships/${FID}/expenses/exp1`),
        validExpenseDoc({
          splits: [
            {userId: memberA, sharePaise: 5000},
            {userId: outsider, sharePaise: 5000},
          ],
        }),
      ),
    );
  });

  it("rejects creation by a non-member of the friendship", async () => {
    const ctx = testEnv.authenticatedContext(outsider);
    await assertFails(
      setDoc(
        doc(ctx.firestore(), `friendships/${FID}/expenses/exp1`),
        validExpenseDoc({createdBy: outsider, payerId: memberA}),
      ),
    );
  });

  it("rejects unauthenticated creation", async () => {
    const ctx = testEnv.unauthenticatedContext();
    await assertFails(
      setDoc(
        doc(ctx.firestore(), `friendships/${FID}/expenses/exp1`),
        validExpenseDoc(),
      ),
    );
  });

  // ── Extension-point locks (v1.0 invariants) ──

  it("rejects creation with currency != 'INR'", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      setDoc(
        doc(ctx.firestore(), `friendships/${FID}/expenses/exp1`),
        validExpenseDoc({currency: "USD"}),
      ),
    );
  });

  it("rejects creation with source != 'manual'", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      setDoc(
        doc(ctx.firestore(), `friendships/${FID}/expenses/exp1`),
        validExpenseDoc({source: "ocr"}),
      ),
    );
  });

  it("rejects creation with a non-null recurringRule", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      setDoc(
        doc(ctx.firestore(), `friendships/${FID}/expenses/exp1`),
        validExpenseDoc({recurringRule: {freq: "weekly"}}),
      ),
    );
  });

  // ── Field-shape checks ──

  it("rejects creation when splits is missing", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    const data = validExpenseDoc();
    delete (data as Record<string, unknown>).splits;
    await assertFails(
      setDoc(
        doc(ctx.firestore(), `friendships/${FID}/expenses/exp1`),
        data,
      ),
    );
  });

  it("rejects creation when amountPaise is zero", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      setDoc(
        doc(ctx.firestore(), `friendships/${FID}/expenses/exp1`),
        validExpenseDoc({
          amountPaise: 0,
          splits: [{userId: memberA, sharePaise: 0}],
        }),
      ),
    );
  });

  it("rejects creation when amountPaise is negative", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      setDoc(
        doc(ctx.firestore(), `friendships/${FID}/expenses/exp1`),
        validExpenseDoc({
          amountPaise: -100,
          splits: [{userId: memberA, sharePaise: -100}],
        }),
      ),
    );
  });

  it("rejects creation with deleted: true on create", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      setDoc(
        doc(ctx.firestore(), `friendships/${FID}/expenses/exp1`),
        validExpenseDoc({deleted: true}),
      ),
    );
  });

  it("rejects creation with createdBy != caller", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      setDoc(
        doc(ctx.firestore(), `friendships/${FID}/expenses/exp1`),
        validExpenseDoc({createdBy: memberB}),
      ),
    );
  });

  it("rejects creation with an unknown splitMethod", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      setDoc(
        doc(ctx.firestore(), `friendships/${FID}/expenses/exp1`),
        validExpenseDoc({splitMethod: "weighted-by-mood"}),
      ),
    );
  });

  it("rejects creation when splits.size() exceeds the friendship cap (2)", async () => {
    // A friendship has exactly 2 members. Every split.userId must be in
    // memberIds, so splits beyond 2 either repeat memberIds (redundant)
    // or fail the member check. The rule cap is N=2 — confirmed by
    // attempting a 3-element splits array that would otherwise sum
    // correctly. (The groups subcollection in Sprint 3 will have a
    // higher cap matching the group-member maximum.)
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      setDoc(
        doc(ctx.firestore(), `friendships/${FID}/expenses/exp1`),
        validExpenseDoc({
          amountPaise: 9000,
          splits: [
            {userId: memberA, sharePaise: 3000},
            {userId: memberB, sharePaise: 3000},
            {userId: memberA, sharePaise: 3000},
          ],
        }),
      ),
    );
  });

  it("rejects creation with an unknown extra field", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      setDoc(
        doc(ctx.firestore(), `friendships/${FID}/expenses/exp1`),
        validExpenseDoc({rogueField: "unauthorised"}),
      ),
    );
  });
});

// ---------------------------------------------------------------------------
// UPDATE tests
// ---------------------------------------------------------------------------

describe("friendships/{fid}/expenses/{eid} — update rules", () => {
  beforeEach(async () => {
    await seedFriendship(testEnv);
    await seedExpense(testEnv, "exp1");
  });

  it("allows a member to update amount + splits consistently", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertSucceeds(
      updateDoc(
        doc(ctx.firestore(), `friendships/${FID}/expenses/exp1`),
        {
          amountPaise: 20000,
          splits: [
            {userId: memberA, sharePaise: 10000},
            {userId: memberB, sharePaise: 10000},
          ],
          updatedAt: serverTimestamp(),
        },
      ),
    );
  });

  it("rejects edit of amountPaise without matching splits", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      updateDoc(
        doc(ctx.firestore(), `friendships/${FID}/expenses/exp1`),
        {
          amountPaise: 20000,
          // splits still sum to 10000
          updatedAt: serverTimestamp(),
        },
      ),
    );
  });

  it("rejects update by a non-member", async () => {
    const ctx = testEnv.authenticatedContext(outsider);
    await assertFails(
      updateDoc(
        doc(ctx.firestore(), `friendships/${FID}/expenses/exp1`),
        {description: "Hijack", updatedAt: serverTimestamp()},
      ),
    );
  });

  it("rejects update that mutates createdBy", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      updateDoc(
        doc(ctx.firestore(), `friendships/${FID}/expenses/exp1`),
        {createdBy: memberB, updatedAt: serverTimestamp()},
      ),
    );
  });

  it("rejects update that mutates createdAt", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      updateDoc(
        doc(ctx.firestore(), `friendships/${FID}/expenses/exp1`),
        {createdAt: new Date("2024-01-01T00:00:00Z"), updatedAt: serverTimestamp()},
      ),
    );
  });

  it("allows a member to soft-delete (deleted: true)", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertSucceeds(
      updateDoc(
        doc(ctx.firestore(), `friendships/${FID}/expenses/exp1`),
        {deleted: true, updatedAt: serverTimestamp()},
      ),
    );
  });

  it("rejects update that flips currency away from 'INR'", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      updateDoc(
        doc(ctx.firestore(), `friendships/${FID}/expenses/exp1`),
        {currency: "USD", updatedAt: serverTimestamp()},
      ),
    );
  });

  it("rejects update that flips source away from 'manual'", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      updateDoc(
        doc(ctx.firestore(), `friendships/${FID}/expenses/exp1`),
        {source: "ocr", updatedAt: serverTimestamp()},
      ),
    );
  });

  it("rejects update that sets a non-null recurringRule", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      updateDoc(
        doc(ctx.firestore(), `friendships/${FID}/expenses/exp1`),
        {recurringRule: {freq: "weekly"}, updatedAt: serverTimestamp()},
      ),
    );
  });
});

// ---------------------------------------------------------------------------
// FR-EX-06 UPDATE additions (PR #46)
//
// These tests document the rules-layer behaviour for the edit + soft-delete
// shapes that the FR-EX-06 client typed-mapping helper produces.
//
// Tests 1 and 2 intentionally document the KNOWN ROLES GAP recorded in the
// FR-EX-06 story §2.9 item 5: the current isValidExpenseUpdate() at
// firestore.rules:275-284 enforces isCallerFriendshipMember() and the
// createdBy / createdAt immutability checks, but does NOT enforce
// request.auth.uid == resource.data.createdBy. Any friendship member can
// therefore update or soft-delete an expense per the rules — creator-only
// gating today lives only in the client UI (story AC-13). A future rules-
// hardening PR will tighten this; when it does, flip Tests 1 and 2 from
// assertSucceeds to assertFails.
//
// Tests 3 and 4 lock the FR-EX-06 client wire-shape contract:
//   - Test 3 confirms that partial updates which omit updatedAt are rejected
//     by the data.updatedAt == request.time check at firestore.rules:283.
//   - Test 4 confirms that the canonical FR-EX-06 partial map
//     (amountPaise + matching splits + updatedAt) is accepted.
// ---------------------------------------------------------------------------

describe("friendships/{fid}/expenses/{eid} — update rules (FR-EX-06 additions)", () => {
  beforeEach(async () => {
    await seedFriendship(testEnv);
    await seedExpense(testEnv, "exp1");
  });

  it(
    "rules currently allow update by a non-creator member (FR-EX-06 gap; see story §2.9 item 5)",
    async () => {
      // memberB (non-creator but still a friendship member) attempts to
      // update the description. The rule does not gate on creator equality,
      // so this passes today. Flip to assertFails when the rules-hardening
      // PR adds request.auth.uid == prev.createdBy to isValidExpenseUpdate().
      const ctxB = testEnv.authenticatedContext(memberB);
      await assertSucceeds(
        updateDoc(
          doc(ctxB.firestore(), `friendships/${FID}/expenses/exp1`),
          {
            description: "Edited by non-creator member",
            updatedAt: serverTimestamp(),
          },
        ),
      );
    },
  );

  it(
    "rules currently allow soft-delete by a non-creator member (FR-EX-06 gap; see story §2.9 item 5)",
    async () => {
      // Same gap as above, exercised via the soft-delete shape.
      const ctxB = testEnv.authenticatedContext(memberB);
      await assertSucceeds(
        updateDoc(
          doc(ctxB.firestore(), `friendships/${FID}/expenses/exp1`),
          {
            deleted: true,
            updatedAt: serverTimestamp(),
          },
        ),
      );
    },
  );

  it(
    "rejects update that omits updatedAt (FR-EX-06 partial-map safety)",
    async () => {
      // No updatedAt in the partial map. The merged doc preserves the prior
      // updatedAt timestamp from the seed, which will not equal request.time
      // — the rule at firestore.rules:283 rejects.
      const ctxA = testEnv.authenticatedContext(memberA);
      await assertFails(
        updateDoc(
          doc(ctxA.firestore(), `friendships/${FID}/expenses/exp1`),
          {
            description: "Edited without bumping updatedAt",
          },
        ),
      );
    },
  );

  it(
    "accepts FR-EX-06 partial-update map (amountPaise + splits + updatedAt)",
    async () => {
      // The FR-EX-06 client typed-mapping helper produces exactly this
      // shape: only the changed keys + the serverTimestamp updatedAt
      // refresh. Firestore merges with the existing doc; the merged
      // result satisfies isValidExpenseShared because the splits still
      // sum to the new amountPaise.
      const ctxA = testEnv.authenticatedContext(memberA);
      await assertSucceeds(
        updateDoc(
          doc(ctxA.firestore(), `friendships/${FID}/expenses/exp1`),
          {
            amountPaise: 20000,
            splits: [
              {userId: memberA, sharePaise: 10000},
              {userId: memberB, sharePaise: 10000},
            ],
            updatedAt: serverTimestamp(),
          },
        ),
      );
    },
  );
});

// ---------------------------------------------------------------------------
// DELETE tests
// ---------------------------------------------------------------------------

describe("friendships/{fid}/expenses/{eid} — delete rules", () => {
  beforeEach(async () => {
    await seedFriendship(testEnv);
    await seedExpense(testEnv, "exp1");
  });

  it("rejects hard delete by a member (soft-delete only)", async () => {
    const ctx = testEnv.authenticatedContext(memberA);
    await assertFails(
      deleteDoc(doc(ctx.firestore(), `friendships/${FID}/expenses/exp1`)),
    );
  });

  it("rejects hard delete by a non-member", async () => {
    const ctx = testEnv.authenticatedContext(outsider);
    await assertFails(
      deleteDoc(doc(ctx.firestore(), `friendships/${FID}/expenses/exp1`)),
    );
  });

  it("rejects unauthenticated delete", async () => {
    const ctx = testEnv.unauthenticatedContext();
    await assertFails(
      deleteDoc(doc(ctx.firestore(), `friendships/${FID}/expenses/exp1`)),
    );
  });

  it("allows admin-SDK bypass for hard delete (withSecurityRulesDisabled)", async () => {
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      await deleteDoc(
        doc(adminCtx.firestore(), `friendships/${FID}/expenses/exp1`),
      );
    });
    // No assertion needed — withSecurityRulesDisabled would throw if rejected.
  });
});
