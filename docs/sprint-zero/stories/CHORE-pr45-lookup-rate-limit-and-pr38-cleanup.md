# CHORE: PR #45 — lookup-user rate-limit doc-path fix + post-PR-#38 cleanup

> Bundled hygiene story covering two independent small-scope streams that
> ship together for atomic-rollback reasons and because each alone is too
> small to warrant a dedicated PR cycle.
>
> - **Stream A** (~2 SP) — fix the rate-limit document-path bug in
>   `functions/src/lookup-user-by-phone-number/function.ts:108` and
>   unskip the five integration tests that have been
>   `describe.skip`'d since PR #36 surfaced the bug.
> - **Stream B** (~1 SP) — close the three S4 items from the PR #38
>   QA sign-off "Post-Merge Cleanup Backlog" (stale `expense_added` /
>   `expense_add_failed` telemetry references in three design docs;
>   splitter test cap-label propagation; missing `// TODO(SCR-08)`
>   comment).
>
> This chore PR **closes no open GitHub issues** — both streams are
> tracked only in markdown:
>
> - Stream A is the "NEW finding (not Bucket B)" surfaced by PR #36
>   in `docs/audits/sprint-1/07-bucket-b-burndown.md` lines 211–216
>   and listed as a PR #45 candidate in
>   `docs/sprint-zero/next-three-prs.md` lines 41–45.
> - Stream B is the three S4 items in the "Post-Merge Cleanup Backlog"
>   section of `docs/sprint-zero/sprint-2-plan.md` lines 285–355.

---

## SRS Requirement ID(s)

- SRS section 7.1 (Cloud Functions runtime + region pinning — Stream A
  preserves region pinning to `asia-south1`)
- SRS section 5.7 (rate-limit policy: 100 lookups per user per hour —
  Stream A makes this gate actually enforce in production for the
  first time since FR-FR-01 shipped)
- SRS section 5.10 (analytics funnel events — Stream B Item B-1
  propagates the Camp B telemetry names to the last three design docs
  that PR #38's chore-#25 propagation scope missed)
- Invariant #4 (single Firebase project — defence-in-depth re-check
  because Stream A touches a deployed Cloud Function)

## Priority

**P2 — Should have.** Neither stream is deadline-bound. Stream A is a
silent-correctness bug (the rate-limit gate has never enforced in
production since FR-FR-01 shipped in PR #32 / #34) — but the abuse
surface is bounded because the contact-picker happy path stays well
below the 100/hour throttle. Stream B is pure documentation +
test-description drift with zero runtime impact.

Bundled to preserve Sprint 2 velocity without proliferating one-line
chore PRs.

## Story Points

**3** (Stream A ≈ 2 SP — one-line production fix + integration-test
unskip + catalogue doc update; Stream B ≈ 1 SP — six find-and-replace
operations across three docs + two test files + one comment
insertion).

If the architect discovers Stream A requires a behavioural refactor
(e.g. moving the rate-limit read-then-increment to `runTransaction()`
to close the known race), escalate to 5 SP. Default assumption is
"fix the path string, change nothing else" — the race is a separate
operational hardening concern explicitly deferred per Architect
Notes §2.2.

## User Story

As the **One By Two engineering team**,
I want **(a) the `lookupUserByPhoneNumber` rate-limit doc-path bug
fixed so the 100-per-hour throttle starts actually enforcing in
production and the five `describe.skip`'d integration tests run
end-to-end in CI, and (b) the three S4 documentation / test-label
items from the PR #38 QA sign-off closed**,
so that **the rate-limit policy declared in SRS §5.7 is no longer
silently broken, our CI integration suite reflects the real production
behaviour for the lookup-user gateway, and the design docs / splitter
test descriptions / `friends_list_screen.dart` reflect the current
state of the codebase per the architect's Camp B ratification (PR #38)
and the FR-EX-01 §2.10 deferred-FAB-chooser decision**.

## Preconditions

1. PR #44 (CHORE-D5 runtime upgrade — Node 22 + `firebase-functions@7.x`)
   merged to `main` (squash commit `b0fce99`, 2026-06-06). Production
   canary deploy verified via `GET /healthcheck` returning
   `200 OK { "ok": true, "region": "asia-south1" }`. All 5 functions
   running on `nodejs22` in `asia-south1` with no invocation gap.
2. 100 Cloud Functions tests passing on the merged Node 22 +
   `firebase-functions ^7.0.0` matrix (9 suites; pre-fix baseline).
3. `flutter analyze --fatal-infos` + `flutter test` green on a fresh
   checkout (794 pass / 24 skipped post-PR-#44).
4. `dart format --set-exit-if-changed .` exits 0 (160 files, 0
   changed).
5. `.firebaserc` contains exactly one project (Invariant 4 CI gate
   green in `.github/workflows/pr.yml` flutter-checks job).
6. The five `describe.skip`'d integration tests at
   `functions/test/integration/lookup-user-by-phone-number.integration.test.ts`
   are documented with a header comment block citing the bug; the
   seed path at line 243 (`_rateLimits/${userId}/lookups/counter`)
   already encodes the architect-canonical 4-segment subcollection
   layout.

---

## Acceptance Criteria

### Stream A — lookup-user rate-limit doc-path fix

#### AC-A1 — Production code uses an even-component doc path (positive)

> Given `functions/src/lookup-user-by-phone-number/function.ts`,
> When the fix is applied,
> Then the rate-limit doc reference reads
> `db.doc(`_rateLimits/${callerUid}/lookups/counter`)` (4 segments —
> a valid Firestore document path) AND no other call site in
> `functions/src/**` creates a malformed `_rateLimits/**` reference.

#### AC-A2 — Boundary tests pass with the new path (positive)

> Given `functions/test/lookup-user-by-phone-number/function.test.ts`,
> When `cd functions && npm test` runs,
> Then every boundary test passes AND any test that mocks the
> rate-limit document uses the same `_rateLimits/{uid}/lookups/counter`
> key as production. (The existing mock-Firestore returns the same
> doc shape regardless of the input path string — no key change is
> required; this AC is satisfied by the baseline tests still passing
> after the production change.)

#### AC-A3 — Integration suite unskipped and green (positive)

> Given `functions/test/integration/lookup-user-by-phone-number.integration.test.ts`,
> When the fix lands,
> Then (a) the SKIPPED header comment block citing the bug (lines
> 112–131 in the pre-fix file) is REMOVED, (b)
> `describe.skip("lookupUserByPhoneNumber — integration", ...)`
> becomes `describe("lookupUserByPhoneNumber — integration", ...)`,
> AND (c) all 5 integration tests pass under
> `firebase emulators:exec --only auth,firestore,functions,storage`.

#### AC-A4 — Rate-limit behaviour observable end-to-end (positive)

> Given a seeded counter at `_rateLimits/${uid}/lookups/counter` with
> `count: 100, windowStart: Date.now() - 1000`,
> When the function is invoked,
> Then it throws `HttpsError` with `code: 'resource-exhausted'` and
> `details.errorCode: 'RATE_LIMITED'`.
>
> Covered by the existing test
> `rate limiting > returns RATE_LIMITED when counter >= 100 within window`
> in the now-unskipped integration suite. Called out separately here
> because it is the load-bearing user-facing behaviour the fix
> restores.

#### AC-A5 — Rules surface unchanged but verified (negative)

> Given `firestore.rules`,
> When the rules tests run (`cd functions && npm run test:rules`),
> Then the `match /_rateLimits/{document=**}` deny rule continues to
> reject ALL client reads/writes at every depth (the recursive-wildcard
> match already covers the new 4-segment path).
>
> No new rules test is required; the existing rules-test suite
> exercises the recursive-wildcard deny. The path-depth fix in
> production code does NOT open a client write path.

#### AC-A6 — Catalogue documentation updated (positive)

> Given `docs/design/07-technical/cloud-functions-catalogue.md`
> lines 725–745,
> When the fix lands,
> Then the rate-limit counter row in the "Firestore paths written"
> table reads `_rateLimits/{userId}/lookups/counter` (the actual doc
> path) AND the prose paragraph below explicitly notes the
> subcollection layout (`counter` doc inside the `lookups`
> subcollection).

---

### Stream B — Post-PR #38 cleanup (three S4 items)

#### AC-B1 — Three design docs use Camp B telemetry names (positive + negative)

> Given the three documents from PR #38 cleanup item (1) —
> `docs/design/03-architecture/non-functional-design.md:399`,
> `docs/design/06-screen-specs/06-08-home-and-search.md:152, 517, 519`,
> `docs/design/06-screen-specs/19-22-expenses.md:360, 386`,
> When the rename is applied (`expense_added` →
> `expense_save_succeeded`; `expense_add_failed` →
> `expense_save_failed`),
> Then `grep -rn 'expense_added\|expense_add_failed'
> docs/design/03-architecture/ docs/design/06-screen-specs/` returns
> ZERO matches AND the same scope still references the new names
> (`expense_save_succeeded` / `expense_save_failed`) in the same
> positions.
>
> **CRITICAL (negative):** the notification-type schema discriminator
> `type: 'expense_added'` in
> `docs/design/07-technical/firestore-schema.md`,
> `docs/design/07-technical/notifications.md`,
> `docs/design/04-wireframes/notifications-and-deeplinks.md`,
> `docs/design/01-information-architecture/navigation-flow.md`,
> `docs/design/07-technical/cloud-functions-catalogue.md`,
> `docs/OneByTwo_Requirements_Spec.md`, and
> `docs/sprint-zero/stories/FR-FR-01-matching-and-friendship.md`
> MUST remain unchanged. The chore-#25 Camp B ratification was
> explicitly scoped to TELEMETRY only (FR-EX-01 Architect Notes §2.0);
> the notification-type discriminator is a Firestore SCHEMA field per
> SRS §7.2 and MUST NOT be renamed.
> `grep -rn "type.*['\"]expense_added['\"]" docs/` returns the same
> set of matches before and after the fix.

#### AC-B2 — Splitter test descriptions match the real cap (positive)

> Given the two test files from PR #38 cleanup item (2) —
> `test/features/expenses/split_calculator_test.dart` (lines 87, 91,
> 192, 216) and
> `test/features/expenses/split_calculator_property_test.dart` (lines
> 10, 37, 40, 63, 65, 88, 109, 134, 159),
> When the rename is applied (`99999999` → `999999999` for every
> "maximum permitted total" reference; coordinated update of the
> dependent share assertions on `split_calculator_test.dart` lines
> 95, 96, 216 to keep the test passing — see Architect Notes §2.7
> for the reconciliation rationale),
> Then `grep -n '99999999' test/features/expenses/split_calculator_test.dart
> test/features/expenses/split_calculator_property_test.dart` returns
> only matches that are substrings of `999999999` (the new 9-nines
> value); zero standalone 8-nines `99999999` remain.
>
> The test-description string at `split_calculator_test.dart:87`
> reads "the maximum permitted total (999999999 paise, odd)".
>
> The Flutter test suite (`flutter test`) continues to pass with
> identical pass/skip counts (794 pass / 24 skipped).

#### AC-B3 — `friends_list_screen.dart` carries the SCR-08 TODO (positive)

> Given `lib/features/friends/presentation/friends_list_screen.dart`,
> When the comment is added,
> Then the top of the file (immediately after the import block)
> contains a `// TODO(SCR-08)` comment block citing the deferred
> multi-context FAB chooser and naming `FriendDetailScreen` (not the
> pre-PR-#42 placeholder name `FriendDetailPlaceholderScreen`) as the
> only current Add Expense entry point.
>
> `flutter analyze --fatal-infos` passes (comments are inert; the
> static analyser sees no change but the file MUST stay clean).

---

### Cross-cutting (both streams)

#### AC-X1 — Five-layer test pyramid green (positive)

> Given the PR diff,
> When CI runs,
> Then every layer passes on the merged matrix (Node 22 /
> `firebase-functions@7.x`):
>
> - Layer 1 + 2 + 3 (algorithm unit / property / function boundary):
>   9 suites / 100 tests pass.
> - Layer 4 (rules): 7 suites / 149 tests pass.
> - Layer 5 (integration): 4 of 4 suites pass (the
>   previously-skipped `lookup-user-by-phone-number` suite is now
>   active and contributes 5 tests; the existing 3 suites pass at
>   their current counts).
>
> Coverage on `functions/src/lookup-user-by-phone-number/function.ts`
> improves modestly because the rate-limit branch is now exercised
> end-to-end in CI. Coverage on
> `functions/src/simplified-debts/function.ts` stays at ≥ 89% branch
> (PR #36 baseline).

#### AC-X2 — Invariant 4 preserved (positive)

> Given the PR diff,
> When `.firebaserc` is inspected,
> Then it contains exactly one project (`onebytwo-avtanshgupta`).
> `firebase.json` `singleProjectMode: true` remains unchanged. The
> CI gate in `.github/workflows/pr.yml` flutter-checks job continues
> to enforce.

#### AC-X3 — No feature work (negative)

> Given the PR #45 diff,
> When scanned for new feature flags, new screens, new routes, new
> Firestore collections, or new public Cloud Function APIs,
> Then the count is ZERO. This is a hygiene PR.

#### AC-X4 — No notification-type schema regression (negative)

> Given the PR #45 diff,
> When `grep -rn "type.*['\"]expense_added['\"]" docs/` is run before
> and after,
> Then the matched line count and content are IDENTICAL. The
> notification-type discriminator (`'expense_added'` /
> `'expense_edited'` / `'expense_deleted'` / `'settlement'` /
> `'group_change'`) is a Firestore schema field per SRS §7.2 and is
> untouched by this PR.

---

## Invariant Compliance

| # | Invariant | Applicability |
|---|---|---|
| 1 | Money is integer paise | **N/A.** No monetary surface changes. Stream B Item B-2 only updates test cap labels; the splitter itself is unchanged and the live `_kMaxPaise = 999999999` constant in `lib/core/widgets/inputs/obt_amount_input.dart:60` and `lib/features/expenses/application/add_expense_controller.dart:19` is also unchanged. |
| 2 | `simplifiedBalances` server-maintained | **N/A.** No `simplifiedBalances` write surface touched. The `_rateLimits/**` collection is an internal-only infrastructure namespace; rules already deny all client access at every depth. |
| 3 | System share sheet only | **N/A.** No sharing surface touched. |
| 4 | Single Firebase project | **APPLIES (defence-in-depth).** Stream A touches a Cloud Function that ships via the existing single-project deploy path. Verify `.firebaserc` still contains exactly one project and `firebase.json` `singleProjectMode: true` is preserved. CI gate enforces. |

---

## Definition of Done

Reference: `docs/design/08-plan/definition-of-ready-and-done.md`

- [ ] Code merged to `main` via approved PR.
- [ ] `functions/src/lookup-user-by-phone-number/function.ts:108`
      reads `db.doc(`_rateLimits/${callerUid}/lookups/counter`)`.
- [ ] `functions/test/integration/lookup-user-by-phone-number.integration.test.ts`
      header SKIPPED comment block removed.
- [ ] `functions/test/integration/lookup-user-by-phone-number.integration.test.ts`
      `describe.skip(...)` flipped to `describe(...)`.
- [ ] `cd functions && npm run lint && npm run build && npm test`
      exits 0 (still 9 suites / 100 tests).
- [ ] `cd functions && npm run test:rules` exits 0 under
      `firebase emulators:exec`.
- [ ] `firebase emulators:exec --only auth,firestore,functions,storage "cd functions && npm run test:integration"`
      exits 0 with the 5 newly-active `lookup-user-by-phone-number`
      integration tests passing.
- [ ] Coverage on `functions/src/lookup-user-by-phone-number/function.ts`
      measurably improves (rate-limit branch no longer dead code in
      CI).
- [ ] Coverage on `functions/src/simplified-debts/function.ts` stays
      at ≥ 89% branch (PR #36 baseline).
- [ ] `flutter analyze --fatal-infos` returns "No issues found".
- [ ] `dart format --set-exit-if-changed .` exits 0.
- [ ] `flutter test` returns identical 794 pass / 24 skipped.
- [ ] `grep -rn 'expense_added\|expense_add_failed' docs/design/03-architecture/ docs/design/06-screen-specs/`
      returns zero matches.
- [ ] `grep -rn "type.*['\"]expense_added['\"]" docs/` returns the
      same matches before and after (notification-type discriminator
      unchanged).
- [ ] `grep -n '99999999' test/features/expenses/split_calculator_test.dart
      test/features/expenses/split_calculator_property_test.dart`
      returns only matches that are substrings of `999999999`.
- [ ] `lib/features/friends/presentation/friends_list_screen.dart`
      carries the `// TODO(SCR-08)` comment block citing
      `FriendDetailScreen`.
- [ ] `.firebaserc` contains exactly one project (Invariant 4 CI
      gate green).
- [ ] `firebase.json` `singleProjectMode: true` unchanged.
- [ ] `docs/design/07-technical/cloud-functions-catalogue.md` rate-limit
      path documentation reflects the 4-segment doc path.
- [ ] `docs/audits/sprint-1/07-bucket-b-burndown.md` PR #45 section
      appended; the "NEW finding rate-limit" note marked closed with
      PR #45 cross-ref.
- [ ] `docs/sprint-zero/sprint-2-plan.md` PR #45 row added to PR
      Tracking + Velocity (3 SP, cumulative 40 SP / 12 PRs); three S4
      items in "Post-Merge Cleanup Backlog" marked closed.
- [ ] `docs/sprint-zero/next-three-prs.md` rolled forward (PR #45
      merged; PR #46 / PR #47 / PR #48 candidates).
- [ ] Architect Notes §2.7 enumerates every reconciliation OR
      explicitly states "zero reconciliations required beyond the
      coordinated splitter-share assertion update".
- [ ] QA reviewed and verified acceptance criteria, including the
      negative AC-X4 grep round-trip and the 101st-lookup
      `RATE_LIMITED` smoke.
- [ ] No open S1 or S2 bugs.

---

## Out of Scope

- Any feature work (FR-EX-05 / FR-EX-06 / FR-SE-09 / FR-SE-08 — these
  are P0/P1 features with their own stories and ACs; they belong in
  PR #46+).
- The rate-limit transaction race refactor (the current implementation
  has a known time-of-check-to-time-of-use race; explicitly deferred
  per Architect Notes §2.2 as a separate operational hardening
  concern).
- Any other Bucket-B item (D1 Riverpod 3.x, D2 share_plus, D4
  build_runner, D6 npm audit, D7 Jest 30 — all stay on issue
  [#22](https://github.com/avtansh-code/OneByTwo/issues/22) for Sprint
  4+).
- Any rules change (`firestore.rules`, `firestore.indexes.json`,
  `storage.rules` are unchanged — the recursive-wildcard `_rateLimits`
  deny rule already covers the new 4-segment path).
- Any new ADR (ADR-0011 + the existing `.github/shared/decision-log.md`
  rate-limit entry both stand; PR #45 implements the existing
  architect-canonical decision, not a new one).
- Refactoring the rate-limit logic itself (transaction semantics,
  window-reset behaviour, the 100/hour limit constant) beyond the
  path-string fix.
- Touching the `type: 'expense_added'` notification-type schema field
  anywhere (see AC-B1 and AC-X4).
- Bumping `firebase-admin`, `firebase-functions`, or any other
  Cloud Functions dependency pinned by PR #44.
- Any change to `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`,
  the Android / iOS native shells, or any Flutter dependency.
- Any change to `.github/workflows/*.yml` (the runtime + SDK matrix
  is fixed by PR #44 and is not revisited).

---

## Dependencies

| Dependency | Status |
|---|---|
| PR #44 — D5 runtime upgrade (Node 22 + `firebase-functions@7.x`) | Merged (squash `b0fce99`, 2026-06-06) |
| Production canary deploy verified (`GET /healthcheck` → `200 OK { ok: true, region: "asia-south1" }`) | Verified |
| 100 Cloud Functions tests passing on the merged matrix | Verified pre-fix |
| `flutter analyze --fatal-infos` + `flutter test` green (794 / 24 skipped) | Verified pre-fix |
| `dart format --set-exit-if-changed .` exits 0 | Verified pre-fix |
| `.firebaserc` exists in repo root | Present |
| Five `describe.skip`'d integration tests at `functions/test/integration/lookup-user-by-phone-number.integration.test.ts` lines 112–131 | Present (header comment block + `describe.skip`) |

---

## References

| Artefact | Path |
|---|---|
| SRS | `docs/OneByTwo_Requirements_Spec.md` — sections 5.7, 5.10, 7.1, 7.2 |
| Invariants | `.github/shared/invariants.md` — Invariant #4 |
| DoR / DoD | `docs/design/08-plan/definition-of-ready-and-done.md` |
| Feature PR conventions | `docs/patterns/feature-pr-conventions.md` (Cloud Functions section) |
| Test strategy | `.github/shared/test-strategy.md` (five-layer test pyramid) |
| Burndown (authoritative tracker) | `docs/audits/sprint-1/07-bucket-b-burndown.md` — PR #36 NEW finding (lines 211–216) |
| Rolling plan | `docs/sprint-zero/next-three-prs.md` — PR #45 default plan |
| Sprint 2 plan | `docs/sprint-zero/sprint-2-plan.md` — Post-Merge Cleanup Backlog (lines 285–355) |
| Camp B telemetry naming source-of-truth | `lib/features/expenses/application/expense_telemetry.dart`; `docs/design/07-technical/telemetry-plan.md` |
| FR-EX-01 §2.10 deferred FAB chooser | `docs/sprint-zero/stories/FR-EX-01-expense-creation.md` Architect Notes §2.10 |
| Rate-limit architectural canon | `.github/shared/decision-log.md` lines 695–765 (`_rateLimits/{userId}/lookups` logical container) |
| Integration test seed-path precedent | `functions/test/integration/lookup-user-by-phone-number.integration.test.ts:243` (`_rateLimits/${userId}/lookups/counter`) |
| Chore-story precedent | `docs/sprint-zero/stories/CHORE-d5-runtime-upgrade.md` |
| Cloud Functions catalogue | `docs/design/07-technical/cloud-functions-catalogue.md` lines 725–745 |
| ADR — CF module layout | `.github/shared/decision-log.md` — ADR-0011 |

---
