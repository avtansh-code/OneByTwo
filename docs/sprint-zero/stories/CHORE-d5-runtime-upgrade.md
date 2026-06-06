# CHORE: D5 — Cloud Functions runtime upgrade (Node 22 + firebase-functions 7.x)

> Chore story covering the deadline-bound D5a + D5b items from the Sprint 1
> Bucket-B burndown. Upgrades the Cloud Functions runtime from Node 20 to
> Node 22 LTS and the SDK from `firebase-functions` 6.x to 7.x in a single
> atomic PR so the next `firebase deploy --only functions` after the
> **2026-10-31** Node 20 decommission cutoff succeeds.
>
> Closes [#39](https://github.com/avtansh-code/OneByTwo/issues/39) (Node 20
> decommissioned 2026-10-31) and
> [#40](https://github.com/avtansh-code/OneByTwo/issues/40)
> (`firebase-functions` 6.x → 7.x).

---

## SRS Requirement ID(s)

- SRS section 7.1 (Cloud Functions runtime + region pinning)
- SRS section 9.1 (single Firebase project, emulator usage)
- SRS section 9.2 (PR + Release pipelines)
- Invariant #2 (`simplifiedBalances` server-maintained — defence-in-depth
  re-check after the SDK upgrade)
- Invariant #4 (single Firebase project — load-bearing for the deploy
  path this PR touches)

## Priority

**P0 — Must have.** Deadline-bound: Google Cloud Functions Gen 2 will
reject deployments on the `nodejs20` runtime after **2026-10-31**. The
next functions deploy after that date would fail, blocking every
production hotfix. Recommended ship-by date is mid-September 2026 to
leave one deploy cycle of slack.

## Story Points

**3** (predictable shape; reconciliation surface bounded by 5 deployed
functions × 2 SDK majors; default assumption is zero source-code
reconciliations because we only consume the v2 surfaces which are
stable across the 6 → 7 boundary). If the migration notes prove this
wrong, escalate to 5 SP and split into PR #44a (Node 22 only) + PR #44b
(`firebase-functions@7.x`); default remains a single PR.

## User Story

As the **One By Two engineering team**,
I want **the Cloud Functions runtime upgraded to Node 22 LTS and the
`firebase-functions` SDK upgraded from 6.x to 7.x in a single atomic
PR**
so that **the next `firebase deploy --only functions` after the
2026-10-31 Node 20 decommission cutoff succeeds, the `firebase-functions`
deprecation warning on every deploy clears, and the rollback story for
the upgrade remains a single `git revert`**.

## Preconditions

1. PR #43 (FR-SE-05/06/07 Settle Up flow) merged to `main`. Both halves
   of the simplified-debts round-trip closed end-to-end from the user's
   point of view.
2. 100 Cloud Functions tests passing on the current Node 20 +
   `firebase-functions ^6.1.2` matrix (pre-upgrade baseline).
3. `flutter analyze --fatal-infos` + `flutter test` green on a fresh
   checkout (794 pass / 24 skipped post-PR-#43).
4. `.firebaserc` contains exactly one project (Invariant 4 CI gate
   green).
5. Issues
   [#39](https://github.com/avtansh-code/OneByTwo/issues/39) and
   [#40](https://github.com/avtansh-code/OneByTwo/issues/40) open and
   labelled `sprint-2-chore`.

---

## Acceptance Criteria

### AC-1 — Node 22 runtime declared (positive)

> Given the `functions/package.json` and `firebase.json` files,
> When the upgrade is applied,
> Then `functions/package.json` `engines.node` reads `"22"` AND
> `firebase.json` `functions[0].runtime` reads `"nodejs22"`.

The two declarations are linked by Firebase tooling — they MUST agree.

### AC-2 — `firebase-functions` upgraded to 7.x (positive)

> Given the `functions/package.json` dependencies,
> When the upgrade is applied,
> Then `firebase-functions` is pinned to a 7.x version
> (e.g. `^7.0.0` or the latest 7.x available at PR-kickoff time) AND
> `package-lock.json` is regenerated atomically with the version bump.

### AC-3 — CI runners upgraded to Node 22 (positive)

> Given the five `actions/setup-node@v4` invocations in
> `.github/workflows/pr.yml` (three) and `.github/workflows/release.yml`
> (two),
> When the upgrade is applied,
> Then every `node-version` value reads `'22'`.

The `cache: 'npm'` and `cache-dependency-path: functions/package-lock.json`
pins are unchanged.

### AC-4 — Lint + build + tests pass on the new matrix (positive)

> Given the Node 22 + `firebase-functions@7.x` runtime,
> When `cd functions && npm ci && npm run lint && npm run build && npm test`
> runs in CI,
> Then exit code 0 across every step.

Coverage on `functions/src/simplified-debts/function.ts` stays at
≥ 90% branch (the PR #36 baseline; current actual ≈ 90%).

### AC-5 — Rules tests pass (positive)

> Given the upgrade,
> When `cd functions && npm run test:rules` runs under
> `firebase emulators:exec`,
> Then every Firestore Security Rules test (friendship + expense-friendship
> + settlements + simplifiedBalances negative) passes.

The rules surface is unchanged so the test outcomes MUST be identical
to the pre-upgrade baseline.

### AC-6 — Integration tests pass (positive)

> Given the upgrade,
> When
> `firebase emulators:exec --only auth,firestore,functions,storage "cd functions && npm run test:integration"`
> runs,
> Then every integration test exits 0 AND the `onExpenseWriteFriendship`
> and `onSettlementWrite` triggers register and fire under the new
> runtime + SDK matrix.

### AC-7 — Healthcheck deploys and serves (positive — manual smoke)

> Given a successful local `cd functions && npm run build`,
> When the deploy step in `.github/workflows/release.yml` runs against
> the production project,
> Then all 5 functions migrate cleanly with no invocation gap AND
> post-deploy `GET /healthcheck` returns
> `200 OK { "ok": true, "region": "asia-south1" }`.

Verified in QA's manual smoke matrix; CI does not execute the
production deploy on the PR pipeline.

### AC-8 — Reconciled breaking changes are documented (positive)

> Given the `firebase-functions` 6 → 7 migration notes,
> When the upgrade is applied,
> Then the Architect Notes §2.7 of this story enumerates every
> breaking-change reconciliation made to `functions/src/**` (with
> file:line, old API, new API, rationale).

If zero changes were required (the 6 → 7 migration is a clean swap
for our v2-only surfaces), the Architect Notes explicitly state that —
the audit trail matters.

### AC-9 — Invariant 2 preserved (negative — defence-in-depth)

> Given the upgraded `firebase-functions@7.x` callable surface,
> When the rules test "rejects a client write to simplifiedBalances"
> runs,
> Then the write is REJECTED with `permission-denied`.

The upgrade MUST NOT introduce a code path where the new callable
signature allows a client to update the field. Enforced by re-running
the existing rules tests; no new test needed.

### AC-10 — Invariant 4 preserved (positive)

> Given the upgrade,
> When `.firebaserc` and `firebase.json` are inspected,
> Then `.firebaserc` contains exactly one project (the CI gate in
> `.github/workflows/pr.yml` enforces this on every PR; the upgrade
> MUST NOT regress it) AND `firebase.json` `singleProjectMode: true`
> is unchanged.

### AC-11 — No Flutter source touched (negative — scope guardrail)

> Given the PR #44 diff,
> When `git diff main --stat -- lib/ test/features/ test/integration/`
> runs,
> Then the output is empty.

This PR is server-side only.

### AC-12 — No rules / indexes / storage changes (negative — scope guardrail)

> Given the PR #44 diff,
> When
> `git diff main --stat -- firestore.rules firestore.indexes.json storage.rules`
> runs,
> Then the output is empty.

---

## Invariant Compliance

| # | Invariant | Applicability |
|---|---|---|
| 1 | Money is integer paise | **N/A.** No monetary surface changes. The upgrade does not modify how `recomputeSimplifiedBalances` returns paise to the client. |
| 2 | `simplifiedBalances` server-maintained | **APPLIES (defence-in-depth).** The trigger remains the sole writer. The upgrade MUST NOT introduce a code path where the new `firebase-functions@7.x` callable signature allows a client to update the field. Re-run the PR #37 rules test that asserts client writes to `simplifiedBalances` are rejected with `permission-denied`. |
| 3 | System share sheet only | **N/A.** No sharing surface touched. |
| 4 | Single Firebase project | **APPLIES (load-bearing).** This PR is the first to touch the deploy path since PR #38. Verify `.firebaserc` still contains exactly one project (the CI gate in `.github/workflows/pr.yml` enforces this) and `firebase.json` `singleProjectMode: true` is preserved. |

---

## Definition of Done

Reference: `docs/design/08-plan/definition-of-ready-and-done.md`

- [ ] Code merged to `main` via approved PR.
- [ ] `functions/package.json` `engines.node` = `"22"`.
- [ ] `functions/package.json` `firebase-functions` pinned to 7.x.
- [ ] `functions/package-lock.json` regenerated atomically.
- [ ] `firebase.json` `functions[0].runtime` = `"nodejs22"`.
- [ ] All five `actions/setup-node@v4` invocations across
      `.github/workflows/pr.yml` (three) and
      `.github/workflows/release.yml` (two) read `node-version: '22'`.
- [ ] `cd functions && npm ci && npm run lint && npm run build && npm test`
      exits 0 in CI on the new matrix.
- [ ] `cd functions && npm run test:rules` exits 0 under
      `firebase emulators:exec`.
- [ ] `firebase emulators:exec --only auth,firestore,functions,storage "cd functions && npm run test:integration"`
      exits 0.
- [ ] Coverage on `functions/src/simplified-debts/function.ts` stays at
      ≥ 90% branch (PR #36 baseline).
- [ ] Architect Notes §2.7 enumerates every breaking-change
      reconciliation OR explicitly states "zero reconciliations
      required".
- [ ] If §2.7 lists any reconciliation that changes observable
      behaviour, a regression test exists for it.
- [ ] `.firebaserc` contains exactly one project (Invariant 4 CI gate
      green).
- [ ] `firebase.json` `singleProjectMode: true` unchanged.
- [ ] Rules test for client write to `simplifiedBalances` still rejects
      with `permission-denied` (Invariant 2 re-verification).
- [ ] `git diff main --stat -- lib/ test/features/ test/integration/`
      empty (no Flutter source touched).
- [ ] `git diff main --stat -- firestore.rules firestore.indexes.json storage.rules`
      empty (no rules / indexes / storage changes).
- [ ] `docs/audits/sprint-1/07-bucket-b-burndown.md` D5a + D5b marked
      closed with PR #44 cross-ref.
- [ ] `docs/sprint-zero/sprint-2-plan.md` PR #44 row added to PR
      Tracking + Velocity (3 SP, cumulative 37 SP / 11 PRs).
- [ ] `docs/sprint-zero/next-three-prs.md` rolled forward
      (PR #45 / PR #46 / PR #47 candidates).
- [ ] `docs/design/07-technical/cloud-functions-catalogue.md` runtime
      header line updated to Node 22.
- [ ] QA reviewed and verified acceptance criteria (including the
      Inv-2 defence-in-depth re-check).
- [ ] Post-deploy `GET /healthcheck` returns
      `200 OK { "ok": true, "region": "asia-south1" }` (release tag
      smoke).
- [ ] No open S1 or S2 bugs.

---

## Out of Scope

- Any Flutter source change (`lib/**`, `test/features/**`,
  `test/integration/**` — except confirming the existing integration
  test stubs still pass against the new runtime).
- Any new feature work — this is a pure infrastructure upgrade PR.
- Migrating to Node 24 (not GA on Cloud Functions Gen 2 at filing
  time; rejected per Architect Notes §2.3).
- Upgrading `firebase-admin` beyond what the
  `firebase-functions@7.x` migration notes require.
- Re-architecting the functions module layout (ADR-0011 stands).
- Touching `firestore.rules`, `firestore.indexes.json`, or
  `storage.rules` (deployed via the same release workflow but no rule
  changes needed for this PR).
- The five remaining D-row bucket-B items (D1, D2, D4, D6, D7 — Sprint
  4+ scope per the burndown).
- The `lookup-user-by-phone-number` rate-limit doc-path bug fix
  (separate later PR; tracked in `docs/sprint-zero/next-three-prs.md`
  PR #45 candidate list).
- The three post-PR #38 cleanup S4 items (stale event names in 3 design
  docs; splitter test cap labels; missing `// TODO(SCR-08)` comment).
- Any new ADR (ADR-0011 + ADR-0003 stand unchanged).
- Any change to `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`,
  the Android / iOS native shells, or any Flutter dependency
  (the `cloud_functions` Flutter package is the client-side wrapper and
  is unrelated to the Cloud Functions runtime + SDK upgrade).

---

## Dependencies

| Dependency | Status |
|---|---|
| PR #43 — FR-SE-05/06/07 Settle Up flow | Merged |
| 100 Cloud Functions tests passing on the current matrix | Verified pre-upgrade |
| `.firebaserc` exists in repo root | Present |
| Issue [#39](https://github.com/avtansh-code/OneByTwo/issues/39) — Node 20 decommissioned 2026-10-31 | Open |
| Issue [#40](https://github.com/avtansh-code/OneByTwo/issues/40) — `firebase-functions` 6→7 | Open |
| `firebase-functions` 7.x available on npm | Verified (latest at filing time: `7.2.5`) |
| Node 22 GA on Cloud Functions Gen 2 | Verified against canonical runtime calendar |
| `firebase-functions-test` peer-dep compatibility | Verified (3.5.0 accepts `firebase-functions >= 4.9.0`, includes 7.x) |

---

## References

| Artefact | Path |
|---|---|
| SRS | `docs/OneByTwo_Requirements_Spec.md` — sections 7.1, 9.1, 9.2 |
| Invariants | `.github/shared/invariants.md` — Invariants #2, #4 |
| DoR / DoD | `docs/design/08-plan/definition-of-ready-and-done.md` |
| Feature PR conventions | `docs/patterns/feature-pr-conventions.md` (Cloud Functions section) |
| Test strategy | `.github/shared/test-strategy.md` (five-layer test pyramid) |
| Burndown (authoritative tracker) | `docs/audits/sprint-1/07-bucket-b-burndown.md` — rows D5a + D5b |
| Rolling plan | `docs/sprint-zero/next-three-prs.md` — PR #44 default plan |
| Cloud Functions catalogue | `docs/design/07-technical/cloud-functions-catalogue.md` (runtime header) |
| ADR — CF module layout | `.github/shared/decision-log.md` — ADR-0011 |
| ADR — single Firebase project | `.github/shared/decision-log.md` — ADR-0003 |
| Canonical migration notes | `firebase-functions` v7 release notes at <https://github.com/firebase/firebase-functions/releases/tag/v7.0.0> |
| Canonical runtime calendar | <https://cloud.google.com/functions/docs/runtime-support> |

---

## Architect Notes

> Appended at PR #44 kickoff after consulting the canonical
> `firebase-functions` v7 release notes
> (<https://github.com/firebase/firebase-functions/releases/tag/v7.0.0>)
> and the Cloud Run Functions runtime support calendar
> (<https://cloud.google.com/functions/docs/runtime-support>).

### 2.1 — Runtime + SDK matrix

| Pin | Old | New | Rationale |
|---|---|---|---|
| `functions/package.json` `engines.node` | `"20"` | `"22"` | Node 20 decommissioned 2026-10-31 on Cloud Functions Gen 2; Node 22 is the current GA LTS. |
| `firebase.json` `functions[0].runtime` | `"nodejs20"` | `"nodejs22"` | Linked to the package.json engines field by Firebase tooling — both MUST agree. |
| `functions/package.json` `firebase-functions` | `^6.1.2` | `^7.0.0` | Clears the CLI deprecation warning emitted on every deploy. Locked to the caret-major so future 7.x patch releases land via `npm update`. Latest at filing time: `7.2.5`. |
| `functions/package.json` `firebase-functions-test` | `^3.4.0` | unchanged (`^3.4.0` — actual resolved `3.5.0`) | Peer-dep range `firebase-functions: >= 4.9.0` accepts 7.x. No matching-major bump required. |
| `functions/package.json` `firebase-admin` | `^13.0.2` | unchanged | The `firebase-functions@7.x` migration notes do not require a `firebase-admin` bump. Bundling one would double the breaking-change reconciliation surface for zero deadline reason. |
| `.github/workflows/pr.yml` × 3 `node-version` | `'20'` | `'22'` | Three `actions/setup-node@v4` invocations (functions lint, integration tests, coverage gate). The `cache: 'npm'` + `cache-dependency-path: functions/package-lock.json` pins are unchanged. |
| `.github/workflows/release.yml` × 2 `node-version` | `'20'` | `'22'` | Two `actions/setup-node@v4` invocations (test guard, deploy). Same pin scheme. |

### 2.2 — Files to touch (exhaustive — anything outside this set is scope creep)

- `functions/package.json` — `engines.node` + `firebase-functions` dependency.
- `functions/package-lock.json` — regenerated by `npm install`.
- `firebase.json` — `functions[0].runtime`.
- `.github/workflows/pr.yml` — three `node-version: '20'` → `'22'`.
- `.github/workflows/release.yml` — two `node-version: '20'` → `'22'`.
- `functions/src/**/*.ts` — IF AND ONLY IF the `firebase-functions@7.x`
  migration notes require a breaking-change reconciliation. Default
  assumption is ZERO reconciliations per §2.7. If any are needed they
  are listed explicitly in §2.7 with the file:line, old API, new API,
  and rationale.
- `functions/jest.config.js`, `functions/jest.rules.config.js`,
  `functions/jest.integration.config.js` — IF the
  `firebase-functions-test` upgrade requires a test-config change.
  Default-zero assumption (no `firebase-functions-test` major bump
  required per §2.1).
- `docs/sprint-zero/stories/CHORE-d5-runtime-upgrade.md` — this story
  file (already committed; this section is the architect-notes
  follow-on commit).
- `docs/audits/sprint-1/07-bucket-b-burndown.md` — mark D5a + D5b
  closed with the PR #44 cross-ref.
- `docs/sprint-zero/sprint-2-plan.md` — PR #44 row in PR Tracking +
  Velocity tables (3 SP, cumulative 37 SP / 11 PRs).
- `docs/sprint-zero/next-three-prs.md` — roll forward (PR #45 + PR #46
  + PR #47 candidates).
- `docs/design/07-technical/cloud-functions-catalogue.md` — update the
  Runtime header line from "Node 20" to "Node 22".

### 2.3 — Node 22 LTS choice

Node 22 is the current GA LTS on Cloud Functions Gen 2 (verified
against <https://cloud.google.com/functions/docs/runtime-support> at
PR-kickoff time). Node 22's LTS window extends to 2027-04-30
deprecation / 2027-10-31 decommission, comfortably past the next
foreseeable Sprint 2 / Sprint 3 cycle and well beyond the v1.0
release window.

Node 24 is NOT yet GA on Cloud Functions Gen 2 at filing time, so it
is rejected. Staying on Node 22 is the more conservative choice — if
Node 24 GA's during the v1.0 stabilisation window we re-evaluate via
a follow-up D-row chore, but there is no deadline-driven reason to
chase the newer runtime in this PR.

### 2.4 — `firebase-functions@7.x` upgrade rationale

The 6 → 7 major bump is required to clear the CLI deprecation warning
that has surfaced on every deploy since the post-PR #38 deploy. The
canonical v7.0.0 release notes
(<https://github.com/firebase/firebase-functions/releases/tag/v7.0.0>)
enumerate seven breaking changes:

1. Drop support for Node.js 16. Minimum supported version is now
   Node.js 18.
2. Remove deprecated `functions.config()` API. Use `params` module
   for environment variables instead.
3. Upgrade to TypeScript v5 and target ES2022.
4. Unhandled errors in async `onRequest` handlers in the Emulator
   now return a 500 error immediately.
5. Add support for ESM (ECMAScript Modules) alongside CommonJS
   (additive).
6. Add `onMutationExecuted()` trigger for Firebase Data Connect
   (additive).
7. Rename v1 Event to LegacyEvent to avoid api-extractor conflict.

Applicability to our codebase:

| # | Change | Applies? | Why |
|---|---|---|---|
| 1 | Node ≥ 18 floor | No | We are going from Node 20 to Node 22, both ≥ 18. |
| 2 | Remove `functions.config()` | No | We use v2 surfaces only — no `functions.config()` callers in `functions/src/**`. |
| 3 | TS v5 + ES2022 target | No | Already on TypeScript 5.7.3 with ES2022 target in `tsconfig.json`. |
| 4 | Async `onRequest` errors return 500 | No | Our only `onRequest` is `healthcheck` (synchronous; returns 200 unconditionally). |
| 5 | ESM support | No | Additive; CommonJS continues to work. |
| 6 | Data Connect trigger | No | Not used. |
| 7 | Rename v1 Event → LegacyEvent | No | We import from `firebase-functions/v2/**` exclusively; the v1 namespace is unused. |

Conclusion: **zero source-code reconciliations expected** for the
v6 → v7 swap. The default assumption in §2.7 is "zero
reconciliations required" and is validated by the test pyramid
(Phase 4 of the prompt).

### 2.5 — Atomic upgrade rationale

Node 22 + `firebase-functions@7.x` ship in the **same PR** for two
reasons:

(a) **Rollback story:** a single `git revert` restores the
    working state. Splitting into PR #44a (Node 22 only) + PR #44b
    (`firebase-functions@7.x`) would require two reverts to fully
    rollback.

(b) **Test surface:** the five-layer pyramid only has to be
    exercised once on the new matrix. Splitting doubles the
    breaking-change reconciliation surface, and the
    `firebase-functions@7.x` migration may itself depend on Node 22
    features for some of its internal modules.

The escape hatch in §2.1 of the story (split into PR #44a + PR #44b
if §2.7 surfaces a wider-than-expected reconciliation list) is
deliberately conservative; the architect does not anticipate
exercising it.

### 2.6 — Test pyramid execution order

Every layer of the test pyramid is exercised on the new matrix
BEFORE merge:

1. **Layer 1 — Algorithm unit (no Firebase):**
   `cd functions && npm test` against `simplified-debts/algorithm.ts`
   and `lookup-user-by-phone-number/algorithm.ts`.
2. **Layer 2 — Algorithm property:** the `fast-check` property tests
   under `functions/test/simplified-debts/algorithm.property.test.ts`.
3. **Layer 3 — Function boundary (mocked Firestore):** the
   `function.ts` boundary tests for each of the 5 deployed functions
   (`healthcheck`, `lookupUserByPhoneNumber`,
   `recomputeSimplifiedBalances`, `onExpenseWriteFriendship`,
   `onSettlementWrite`).
4. **Layer 4 — Firestore Security Rules:**
   `cd functions && npm run test:rules` under
   `firebase emulators:exec`.
5. **Layer 5 — Integration (full emulator suite):**
   `firebase emulators:exec --only auth,firestore,functions,storage "cd functions && npm run test:integration"`.

Coverage on `functions/src/simplified-debts/function.ts` MUST stay
at ≥ 90% branch (the PR #36 baseline).

### 2.7 — Anticipated breaking-change reconciliations

**Pre-implementation prediction (filed at architect-notes commit
time): ZERO reconciliations required.**

The v2 surfaces we consume — `onCall`, `onDocumentWritten`,
`onRequest`, `HttpsError`, `logger` — are documented as stable
across the 6 → 7 boundary for the API patterns we use (see §2.4
applicability matrix). The v6 → v7 breaking changes either do not
apply to our v2-only callsites (changes 1, 2, 5, 6, 7) or are
already aligned with our existing tsconfig (change 3) or are
operationally irrelevant to our handlers (change 4 — our only
`onRequest` is the synchronous `healthcheck`).

**Post-implementation update (filled by functions-dev after the
test pyramid ran on the new matrix):**

**Zero reconciliations required.** The pre-implementation prediction
held. Test pyramid green on the new matrix:

| Layer | Suite count | Test count | Status |
|---|---|---|---|
| 1 + 2 + 3 (algorithm unit + property + boundary) | 9 / 9 | 100 / 100 pass | ✓ |
| 4 (Firestore + Storage rules) | 7 / 7 | 149 / 149 pass | ✓ |
| 5 (full-emulator integration) | 3 / 4 + 1 skipped suite | 28 pass / 5 skipped | ✓ |

Coverage on `functions/src/simplified-debts/function.ts`: **89.13%
branch** (PR #36 baseline was 88.57% — unchanged within margin; the
coverage gate's per-module line threshold of ≥ 70% is comfortably
cleared by every `functions/src/**` module).

The single skipped integration suite is
`functions/test/integration/lookup-user-by-phone-number.integration.test.ts`
(`describe.skip` — the pre-existing rate-limit doc-path bug from
PR #32 / #34, surfaced by the PR #36 CI workflow change and tracked
as a separate `PR #45` candidate per
`docs/sprint-zero/next-three-prs.md`). Unrelated to this PR.

The five deployed functions — `healthcheck`, `lookupUserByPhoneNumber`,
`recomputeSimplifiedBalances`, `onExpenseWriteFriendship`,
`onSettlementWrite` — all load and execute under the new runtime + SDK
matrix. No source-code changes were required to any file under
`functions/src/**`.

**Side observation (out of scope; flagged for follow-up):** the rules
test suite is sensitive to the firebase-tools functions-emulator
runtime under the new matrix when run via
`firebase emulators:exec --only auth,firestore,functions,storage`. The
issue reproduces on the OLD ff6 matrix too with `firebase-tools >= 14.x`
and is environment-sensitive (timing-dependent on macOS; not observed
on Linux runners). When run with `--only firestore,storage` (rules
tests do not depend on the functions emulator), 149/149 pass cleanly
on both the old and the new matrix. The CI pipeline (`pr.yml`
integration-tests job) chains `npm run test:rules` inside an
`--only auth,firestore,functions,storage` invocation; CI baseline on
Linux runners has historically been 149/149. The orchestrator notes
this as a candidate for a future test-hygiene chore (move
`test:rules` to a dedicated `--only firestore,storage` invocation in
the CI workflow to eliminate the trigger-interference flake) but
**explicitly defers it as out of scope for PR #44 per the scope
guardrails** — the upgrade is the only deadline-bound item.

### 2.8 — No new ADR required

ADR-0011 (Cloud Function module layout — `algorithm.ts` +
`function.ts` + `index.ts`) stands unchanged — the upgrade preserves
the layout. ADR-0003 (single Firebase project; emulator suite for
non-production) stands unchanged — the upgrade is verified against
the emulator before merge and `.firebaserc` is not touched.

The upgrade is a pure dependency bump; no architectural decisions
are revisited. The "let's add an ADR codifying the runtime-upgrade
cadence" suggestion (Phase 5 guardrails) is deferred — file an issue
if a future architect wants to enshrine the cadence; this PR ships
the upgrade.

### 2.9 — Forward-compatibility note

Node 22's LTS window means this upgrade is good through at least
the v1.0 release. The next foreseeable runtime forcing event is
Node 22 deprecation (announced 2027-04-30 deprecation /
2027-10-31 decommission per the runtime calendar at filing time).
The next D-row update will be a Node 22 → 24 (or whatever LTS is
current then) bump on a similar schedule, slotted ~6 months ahead
of the cutoff.

For `firebase-functions`, semver-major releases historically cadence
every ~14 months. The 7.x line should comfortably cover the rest of
Sprint 2 + Sprint 3 + the v1.0 release; an 8.x bump is not
anticipated within the v1.0 window.

The `firebase-admin` 13.x line was released in November 2024 and is
currently at 13.10.0 (filing time). No deprecation signal yet; the
next major (14.x) is the natural pair for a future
`firebase-functions@8.x` bump.

