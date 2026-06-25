# Next Three PRs

> Rolling roadmap. Updated at the end of every PR.
> **Renumber (2026-06-25):** a Design Conversion sprint — migrating the built app and the shared component library onto the "Direction A — Haldi" visual system (`design_handoff_one_by_two/`, ratified by ADR-0024) — was inserted as the new **Sprint 3**; every later sprint shifts +1, so the Groups-and-Settlements epic is now **Sprint 4**. The live GitHub milestones were renumbered to match by DevOps via `gh`. See `docs/audits/design-conversion/`.
> Last updated: the **Issue #47 friendship-expense creator-only rules hardening** (#72, `33f870d`) merged — `isValidExpenseUpdate()` now gates friendship-context expense edit / soft-delete on `request.auth.uid == prev.createdBy`. With it, **every P0 functional requirement except the deferred Groups epic (FR-GR-01..07, now Sprint 4) is shipped, every P1 is shipped**, and the single-focus issue-backed carry-forward candidate (#47) is consumed. The **Bucket-B close-with-evidence bundle** has since merged as #73 (`f9a4c54`) — it verified the Sprint-1 boundary-audit findings that Sprint 2 PRs already resolved, posted per-issue evidence comments, **fully closed #21**, **re-scoped #20 / #23** (kept open), and reconciled the burndown + roadmap; **velocity-excluded** (docs/hygiene, like #59). The **`chore(auth)` client-housekeeping bundle** (#74, `ce6d594`) has since merged — the first of the three consolidated Sprint-2 close-out PRs (renamed `authStateNotifierProvider` → `authStateProvider` (M1), relocated the three shared providers to `lib/core/providers/` (M4), emitted the four secondary auth-funnel telemetry events and corrected the `is_new_user` typing note (T3/T4/T5), and aligned the splash / phone-entry / OTP screen specs (S1/S3/S4/S5)); it **closed #15 / #16 / #17 / #18** and carried **5 SP**, advancing the velocity Total to **137 SP / 33 PRs**. The **`docs` close-out bundle** (#75, `dbc209d`) has since **Merged** — the second of the three: it added the #19 (CV2) coverage fields, completed the #24 (CN3 / CN4) Jest-config table and Cloud-Functions PR checklist, and created the #28 (SR3) Friends HTML mockup; it **closed #19 / #24 / #28** and was **velocity-excluded** (0 SP, pure docs/design). The next PR — the **third and final** of the three — is the **`test` close-out bundle** (#76): the SC1–SC4 coverage tests, RT2 CI step-duration logging, and the INV2 share-sheet verification; it **closes #20** and **re-scopes #23** (RT2 + INV2 closed with evidence; the PY3 Flutter emulator-harness remainder kept open), and **carries 5 SP** (counted on merge: 137 / 33 → 142 / 34). It lands as the next available number (≥ #76 now that the highest PR is #75 and the highest issue is #68), reconciled at PR open. **CLOSED:** #76 merged (`3f3cd16`, **142 / 34**) and #77 merged (`b9b1e63`, path-filter pipeline + milestone-tracking convention + deepened review skill; velocity-excluded), so **Sprint 2 is fully closed.** The **Sprint 2 → Sprint 3 boundary audit** then ran: cleanup **PR #91** (`chore: Sprint 2 boundary cleanup and audit findings`) fixes the 33 Bucket-A findings and files 44 Bucket-B issues (#78–#90); audit + cleanup, velocity-excluded. **RENUMBER: a Design Conversion sprint was inserted as the new Sprint 3 (Haldi visual-system migration; ADR-0024); the Groups epic shifts to Sprint 4. IN FLIGHT — Sprint 3 (Design Conversion) PR #1: DC-01 design-token foundation** (issue #113, branch `feat/design-token-foundation`) — `lib/app/theme.dart` → Haldi marigold `ColorScheme` with **ink** `onPrimary` + the `OBTColors` extension + the `AppTheme` radius / soft-warm-shadow / motion tokens + Bricolage Grotesque / Hanken Grotesk + the `OBTText.amount` / `.amountHero` helpers, per `docs/sprint-zero/sprint-3-plan.md`; it changes no application behaviour, data model, security rules, the simplified-debts algorithm, or Cloud Functions, and reskins **no** screen or `OBT*` widget (those are DC-02 onward). DC-01..DC-13 are filed under the Sprint 3 milestone (#113–#125). **NEXT UP after DC-01: DC-02 (#114)** — reskin the six `OBT*` shared widgets to the Haldi tokens. **The Groups epic is now Sprint 4:** FR-GR-01 (Create group, issue #92) is the first Sprint-4 PR and is unblocked (DoR-compliant story `docs/sprint-zero/stories/FR-GR-01-create-group.md`; the `groups/{groupId}` schema, create rule, screen spec SCR-14, wireframe, mockup, and `group_created` telemetry all exist; see `docs/sprint-zero/sprint-4-kickoff-readiness.md`). **FR-GR-02 (#93)** and **FR-GR-03 (#94)** follow, building on the invite-token model (ADR-0023) added in #91.

---

## GitHub issue / PR numbering note (post-PR #55)

The numbering jumped because issues and PRs share the same sequential
namespace on GitHub. The post-PR #48 sequence so far:

| Number | Type | What |
|---|---|---|
| #46 | PR | FR-EX-06 edit / delete expense, friendship context (merged 2026-06-07) |
| #47 | Issue | Firestore rules-hardening for non-creator update/delete — **MERGED (closed by #72, `33f870d`)**; tightened friendship-expense edit / soft-delete to the creator |
| #48 | PR | FR-EX-05 receipt attachment, friendship context (merged 2026-06-07) |
| #49 | Issue | Orphan-cleanup Cloud Function for unreferenced receipts (90-day reaper) — OPEN (FUTURE-work chore, 2 SP) |
| #50 | Issue | Trigger no-op-recompute optimisation when update touches only `receiptUrl` + `updatedAt` — OPEN (FUTURE-work chore, 1 SP). **EXPLICITLY CANNOT BE CLOSED** by any FR-EX-07-consuming PR — the optimisation would skip activity emission on receipt-only updates, breaking the FR-EX-07 contract (AC-2). |
| #51 | PR | FR-EX-07 activity feed write-side, friendship expenses (merged 2026-06-07) |
| #52 | PR | FR-AC-01 activity feed read-side + settlement-trigger activity emission (merged 2026-06-08) |
| #53 | PR | FR-AC-03 FCM push notifications + FR-AC-05 cold-start deep-link (merged 2026-06-08) |
| #54 | PR | FR-SE-09 Send Reminder + per-friend 24-hour rate limit (merged 2026-06-09) |
| #55 | PR | FR-PR-03 + FR-AC-04 Notification Preferences UI (SCR-27) + production `cloud_functions` adapter wiring for `reminderRepositoryProvider` + `matchingRepositoryProvider` (merged 2026-06-11) |
| #56 | PR | OBTBottomNav design-system primitive (`components.md §2`) + `AuthenticatedShell` IndexedStack host (5 primary tabs) + 2 placeholder screens + `bottom_nav_tab_selected` telemetry + PopScope snap-to-tab-0 + `lib/main.dart` wire-change + deletion of temporary `HomePlaceholderScreen` (merged 2026-06-11) |
| #57 | PR | FR-HD-04 persistent FAB + Add Expense context picker — `OBTFloatingActionButton` design-system primitive + `AuthenticatedShell` FAB slot + context picker bottom sheet (Friend / Group target with Group path stubbed for Sprint 3) + bundled `currentUserIdProvider` production wiring in `AuthenticatedWithProfile` arm of `lib/main.dart` (closes FR #56 deferral that left `friendsListProvider` + `activityFeedProvider` throwing in production) (merged 2026-06-11) |
| #58 | PR | FR-SE-08 dedicated settlement-history screen (SCR-24) — `SettlementHistoryScreen` at `/settle/history` + `settlementHistoryProvider` (`StreamProvider.family`, 50-item cap) + `settlement_history_telemetry.dart` (2 pre-declared events) + "View Settlement History" link on `FriendDetailScreen` (friendship axis; group axis stubbed) (merged 2026-06-12) |
| **#59** | **PR** | Documentation reconciliation — docs/skills/agents synced to current code + two code fixes (Firestore emulator debug-log port `8080`->`8181` in `lib/main.dart`; missing `test:canonical` script in `functions/package.json`) + fvm pin + lefthook repair (merged 2026-06-12, `093fce7`) |
| **#60** | **PR** | FR-PR-05 Contact Support `mailto:` flow + FR-SH-04 fallback dialog (merged 2026-06-12, `8f72514`). |
| **#61** | **PR** | CI PR-pipeline speed-up — parallelise `build-ios`/`build-android` with `flutter-checks` (no `needs:` edge), cache CocoaPods, guard `flutterfire_cli` activation, de-duplicate coverage-gate via artifacts, pin `firebase-tools` (merged 2026-06-12, `d474507`). |
| **#62** | **PR** | FR-HD-01/02 Home dashboard (SCR-06) — merged 2026-06-13, `57c272e`. |
| **#63** | **PR** | **FR-PR-04 "My Friends" / "My Groups" from Profile (SCR-26, P0) — the last open P0 functional requirement, omitted from this candidate list (corrected); merged 2026-06-13, `209afea`.** |
| **#64** | **PR** | **FR-PR-02 update phone number via OTP re-verification (SRS 4.2 line 175, P1) — merged 2026-06-16, `2e68713`.** |
| **#65** | **PR** | **FR-AU-09 permanently delete your account (SCR-28 Part B, SRS 4.1 line 168, P1) — merged 2026-06-17, `d542793`; the second top-ranked P1 (FR-PR-02 #64 was the first); first reuse of the FR-PR-02 re-authentication surface; the deferred 30-day reaper / grace-period work is FUTURE issue #66.** |
| #66 | Issue | FUTURE: 30-day scheduled-cleanup reaper + grace-period / confirmation SMS / audit log for account deletion (SCR-28 Open Questions 1-3) — deferred from FR-AU-09 (#65); CANNOT be closed by #65. |
| **#67** | **PR** | **FR-HD-03 current-month spend summary with a category breakdown chart (SCR-06, SRS 4.8 line 248, P1) — merged 2026-06-17, `1f26548`; the top-ranked remaining P1 and the last open Home-dashboard requirement (FR-HD-01/02 in #62, FR-HD-04 in #57); first cross-friendship expense read path (fan-out) + first charting approach (`fl_chart`, pure-Dart, no `ios/Podfile.lock` change); two review refinements landed in-PR (server-side month upper bound in `fetchExpensesInMonth`, reusing the existing `expenses (deleted ASC + date DESC)` index; largest-remainder legend percentages summing to 100). ADR-0017.** |
| #68 | Issue | FUTURE: denormalised per-user monthly-spend rollup Cloud Function to remove the FR-HD-03 N+1 fan-out reads — filed/deferred from FR-HD-03 (#67); CANNOT be closed by #67. Do NOT build it in FR-AC-05. |
| **#69** | **PR** | **FR-AC-05 deep-link tab-switch on notification tap (SRS 4.7 line 240, P0) — merged 2026-06-17, `8dd67f9`; the first carry-forward candidate, unblocked by the `shellNavigationControllerProvider` seam (#63) and closing that PR's "controller seam only" deferral; first notification consumer of the shell tab controller. Closed the last deferred piece of a P0, so every P0 except the Sprint-3 Groups epic and every P1 is shipped. Two review refinements landed in-PR (an explicit AC-7 foreground-banner tab-selection test; a comment pinning the synchronous `selectTab`-before-`context.mounted` ordering). ADR-0018.** |
| **#70** | **PR** | **AC-11 "Open Settings" deep-link CTA chore (FR-AC-04 / AC-11 + parallel FR-FR-01 contact-permission gap) — merged 2026-06-20, `dda2f97`; the highest-ranked unshipped carry-forward candidate (surfaced by PR #55 QA). `app_settings: ^7.0.0` behind a shared `lib/core/services/AppSettingsService` seam; both surfaces wired (SCR-27 notification banner + SCR-10 contact-permission view); PII-free `permission_settings_opened` telemetry; `ios/Podfile.lock` committed. ADR-0019.** |
| #71 | PR | `shared_preferences` cross-launch persistence chore — merged 2026-06-20, `a0de106`; the highest-ranked unshipped carry-forward candidate now that #70 merged (the natural pair with the #70 `app_settings` chore, deliberately NOT bundled). Adopts `shared_preferences: ^2.5.5` behind a thin `lib/core/services/KeyValueStore` seam (loaded once in `main()`, injected via `ProviderScope`) and persists FR-AC-04 `wasPermanentlyDenied` (closes the controller TODO) + the FR-SE-09 reminder cooldown (`NotifierProvider.family` with a past-`nextAllowedAt` expiry guard). No telemetry. `ios/Podfile.lock` committed. No tracked issue (candidate-list bullet + two code TODOs — no `Closes #NN`); landed as the next available number ≥ #71, reconciled at PR open. ADR-0020. |
| #72 | PR | Firestore rules — restrict friendship-expense edit / soft-delete to the **expense creator** — **merged 2026-06-20, `33f870d`** (closed `#47`); the highest-ranked unshipped single-focus, issue-backed carry-forward candidate. Added `request.auth.uid == prev.createdBy` to `isValidExpenseUpdate()` (defence-in-depth re-check of the FR-EX-06 client UI gate), inverted the two `assertSucceeds` "flip to assertFails" placeholder tests and added the creator-success counterparts (full rules suite green, 10 suites / 200 tests). Settlement either-party soft-delete left deliberately asymmetric. Pure `firestore.rules` + rules-tests; no client / function / trigger / schema / index change. |
| #73 | PR | **Bucket-B close-with-evidence bundle** — **merged 2026-06-22, `f9a4c54`** (`Closes #21`); documentation + issue-tracker hygiene (the diffuse runner-up to #47). Verifies the Sprint-1 boundary-audit findings Sprint 2 PRs already resolved (CV3 → #36; R1–R3 → #32; R5a → #51; R7–R8 → #48; PY3 Functions/emulator layer → the `test:integration` suite enabled in CI by #36, extended by #37 / #45 / #65), posts per-issue evidence comments, **fully closes #21** (the groups halves R4 / R5b / R6 re-scoped to the Sprint 3 Groups epic) and **re-scopes #20** (SC1–SC4 kept open) and **#23** (Flutter-harness PY3 + RT2 + INV2 kept open), and reconciles `07-bucket-b-burndown.md` + the plan + this roadmap. Acts on #20 / #21 / #23 (no new tracked issue); `Closes #21` only. No app code / rules / new tests / schema / index / function change; no new ADR. Velocity-excluded. |
| #74 | PR | **`chore(auth)` client-housekeeping bundle** — **merged 2026-06-22, `ce6d594`** (`Closes #15 / #16 / #17 / #18`); first of the three consolidated Sprint-2 close-out PRs. Renamed `authStateNotifierProvider` → `authStateProvider` (M1), relocated `firebaseFirestoreProvider` / `firebaseStorageProvider` / `phoneAuthRepositoryProvider` to `lib/core/providers/` (M4; `currentUserIdProvider` deferred as a separate follow-up), emitted the four secondary auth-funnel events (`phone_entry_viewed` / `phone_validation_failed` / `otp_send_requested` / `otp_verification_started`, the last superseding `signup_otp_submitted`) and corrected the `is_new_user` typing note to `int (0/1)` (T3/T4/T5), and aligned the splash (1500 ms) / phone-entry (snackbar OTP-send error + live `XXXXX XXXXX`) / OTP (resend copy) screen specs (S1/S3/S4/S5). Carried 5 SP (velocity Total → 137 / 33). No rules / trigger / schema / index / function change; no new ADR. |
| #75 | PR | **`docs` close-out bundle** — **merged 2026-06-22, `dbc209d`**; second of the three consolidated Sprint-2 close-out PRs (closes #19 / #24 / #28). Adds the #19 (CV2) before/after coverage fields to `feature-pr-conventions.md` §6 + `.github/PULL_REQUEST_TEMPLATE.md`; completes the #24 CN3 Jest-config-separation table (`jest.config.js` / `jest.rules.config.js` / `jest.integration.config.js` — roots, npm scripts, workers, emulator ports) in §3 and adds the CN4 Cloud-Functions PR checklist (region `asia-south1`, error-code mapping, transaction usage, idempotency) to §6 + the template; creates the #28 (SR3) Friends HTML mockup `docs/design/05-mockups/09-friends.html` (the 9th mockup; SCR-09..12) and updates the mockups `README.md` index. Reconciles `07-bucket-b-burndown.md` (CV2 / CN3 / CN4 / SR3 → closed; Total 10 / 27 → 14 / 23). `Closes #19 / #24 / #28`; **velocity-excluded** (0 SP, pure docs/design). No `lib/` / `functions/` / rules / trigger / schema / index change; no new ADR. |
| #76 | PR | **`test` close-out bundle** — IN FLIGHT; third and final of the three consolidated Sprint-2 close-out PRs. **Fully closes #20**: SC1 phone-entry concurrent-submit guard test + a separate `fix(auth)` adding the `isLoading` guard the test surfaced; SC2 OTP auto-retrieval-timeout tests at the genuine `requestOtp` consumers (the `FirebasePhoneAuthRepository` wiring + the phone-entry controller's `otp_auto_read_failed` path); SC3 `MAX_SAFE_INTEGER` overflow-boundary + SC4 100+/1000-member algorithm scalability tests under `functions/test/simplified-debts/`. Closes the **#23** RT2 (per-step duration logging on the emulator-dependent `pr.yml` steps) and INV2 (first automated Invariant-3 guard: a `ShareServiceBase.share()` boundary unit test + a `share_boundary_contract_test.dart` grep over `lib/`) halves with evidence, and **re-scopes #23** — the PY3 Flutter emulator integration-harness remainder stays open (a real `integration_test/` harness needs an Android emulator in CI). `Closes #20` + `Refs #23`. No `lib/**` change beyond the single `fix(auth)` guard; no `functions/src/**` / rules / trigger / schema / index change; no new ADR. Carries **5 SP** (counted on merge: 137 / 33 → 142 / 34). |

The "Next three PRs" below refer to the next three FEATURE/CHORE
**pull requests**. Their issue-number counterparts (when filed) will
consume intermediate numbers; the orchestrator should not assume the
roadmap slot label equals the GitHub number. **Now that the Bucket-B
close-out bundle has merged as PR #73, the `chore(auth)`
client-housekeeping bundle lands as the next available number ≥ #74**
(highest PR is #73, highest issue is #68) — and unlike the recent chores
it DOES carry tracked issues, opening with `Closes #15 / #16 / #17 /
#18`. Reconcile the slot label at PR open.

---

## PR #75 — Merged (`docs` close-out bundle)

**Status:** Merged 2026-06-22 (`dbc209d`, `Closes #19 / #24 / #28`). The second of the
three consolidated Sprint-2 close-out PRs, confirmed as the next-slot pick at the
post-#74 kickoff. Pure docs/design; **velocity-excluded** (like #59 / #61 / #73), so the
Total is unchanged at **137 SP / 33 PRs**.

- **Coverage tracking (CV2).** Added the before/after coverage fields to
  `feature-pr-conventions.md` §6 and `.github/PULL_REQUEST_TEMPLATE.md`.
- **Cloud Functions conventions (CN3 / CN4).** Completed the Jest-config-separation
  table (`jest.config.js` / `jest.rules.config.js` / `jest.integration.config.js`) in §3
  and added the Cloud-Functions PR checklist (region `asia-south1`, error-code mapping,
  transaction usage, idempotency) to §6 and the PR template.
- **Friends mockup (SR3).** Created `docs/design/05-mockups/09-friends.html` (the 9th
  mockup; SCR-09..12) and updated the mockups `README.md` index.

**Stubs / defers.** No `lib/` / `functions/` / rules / trigger / schema / index change; no
new ADR. A follow-up review commit (`6f0123a`) swept the stale `test:canonical` "not
defined" note out of `test-strategy.md` and `test-design.md`.

**Next candidates** (architect's call at the post-#75 kickoff): the **third and final**
consolidated Sprint-2 close-out PR — the **`test` bundle** (now IN FLIGHT as #76; closes
#20, re-scopes #23) — plus the `go_router` migration (Sprint 3), FR-SR-01/02 Search
(SCR-07), and the Sprint 3 Groups epic (FR-GR-01..07).

---

## PR #74 — Merged (`chore(auth)` client-housekeeping bundle)

**Status:** Merged 2026-06-22 (`ce6d594`, `Closes #15 / #16 / #17 / #18`). The first of
the three consolidated Sprint-2 close-out PRs, confirmed as the next-slot pick at the
post-#73 kickoff. Feature-adjacent client housekeeping that **carries 5 SP**, so the
velocity Total advances **132 SP / 32 PRs → 137 SP / 33 PRs**.

- **Providers.** Renamed `authStateNotifierProvider` → `authStateProvider` (M1) and
  relocated `firebaseFirestoreProvider` / `firebaseStorageProvider` /
  `phoneAuthRepositoryProvider` to `lib/core/providers/` (M4; `currentUserIdProvider`
  deferred as a separate follow-up to keep #17 to its literal three-provider scope).
- **Telemetry.** Emitted the four secondary auth-funnel events (`phone_entry_viewed` /
  `phone_validation_failed` / `otp_send_requested` / `otp_verification_started`, the
  last superseding the non-standard `signup_otp_submitted`) and corrected the
  `is_new_user` typing note to `int (0/1)` (T3 / T4 / T5).
- **Screen specs.** Aligned the splash (1500 ms; S1), phone-entry (snackbar OTP-send
  error + live `XXXXX XXXXX` formatting; S3 / S4) and OTP (resend-exhausted copy; S5)
  specs.

**Stubs / defers.** No rules / trigger / schema / index / Cloud Function change; no new
ADR (documented architecture alignment). `currentUserIdProvider` relocation deferred to
a separate follow-up.

**Next candidates** (architect's call at the post-#74 kickoff): the remaining two
consolidated Sprint-2 close-out PRs — the **`docs` bundle** (now IN FLIGHT as #75;
closes #19 / #24 / #28) and a **`test` bundle** (#20 / #23) — plus the `go_router`
migration (Sprint 3), FR-SR-01/02 Search (SCR-07), and the Sprint 3 Groups epic
(FR-GR-01..07).

---

## PR #73 — Merged (Bucket-B close-with-evidence bundle)

**Status:** Merged 2026-06-22 (`f9a4c54`, `Closes #21`). The first dedicated Bucket-B
tracker-hygiene PR — the diffuse runner-up to #47 — confirmed as the next-slot pick at
kickoff. Documentation + issue-tracker hygiene only; **velocity-excluded** (like #59 /
#61), so the Total is unchanged at **132 SP / 32 PRs**.

- **Evidence verified.** Confirmed the Sprint-1 boundary-audit findings that Sprint 2 PRs
  already resolved (CV3 → #36; R1–R3 → #32; R5a → #51; R7–R8 → #48; PY3 Functions/emulator
  layer → the `test:integration` suite) and posted per-issue evidence comments.
- **#21 fully closed; #20 / #23 re-scoped.** All non-groups rules findings resolved (the
  R4 / R5b / R6 groups halves re-scoped to the Sprint 3 Groups epic). #20 (SC1–SC4) and #23
  (Flutter-harness PY3 + RT2 + INV2) kept open under narrowed scope. Reconciled
  `07-bucket-b-burndown.md` + the plan + this roadmap.

**Stubs / defers.** No app code / rules / new tests / schema / index / Cloud Function
change; no new ADR.

**Next candidates** (architect's call at the post-#73 kickoff): the **three consolidated
Sprint-2 close-out PRs** — the `chore(auth)` client-housekeeping bundle (now IN FLIGHT as
#74; closes #15 / #16 / #17 / #18), a `docs` bundle (#19 / #24 / #28), and a `test` bundle
(#20 / #23) — plus the `go_router` migration (Sprint 3), FR-SR-01/02 Search (SCR-07), and
the Sprint 3 Groups epic (FR-GR-01..07).

---

## PR #72 — Merged (Firestore rules: friendship-expense creator-only edit / soft-delete)

**Status:** Merged 2026-06-20 (`33f870d`, `Closes #47`). The Issue #47 friendship-expense
creator-only rules hardening confirmed as the next-slot pick at kickoff — the
**highest-ranked unshipped single-focus, issue-backed carry-forward candidate** now that
#71 merged, and the one remaining candidate with a tracked GitHub issue (so the PR opened
**with** a `Closes #47` line). It landed as the next available number ≥ #72 (highest PR
#71, highest issue #68), reconciled at PR open.

This is the **first rules PR that TIGHTENS an existing `allow`** (every prior rules change
added a new collection block or relaxed a constraint), and the first issue-backed PR in
several slots.

- **Creator-only gate (no new ADR).** `isValidExpenseUpdate()` in `firestore.rules` now
  requires `request.auth.uid == prev.createdBy`, so a non-creator friendship member can no
  longer edit or soft-delete a friendship-context expense directly — a defence-in-depth
  re-check of the FR-EX-06 client UI gate (the bottom-sheet entry points already gate on
  `expense.createdBy == currentUser.uid`). A tightening within ADR-0010's field-level
  pattern under ADR-0008, in service of Invariant 2; no new ADR.
- **Tests inverted + completed.** The two self-documenting `assertSucceeds` "flip to
  assertFails" non-creator placeholder tests in
  `functions/test/firestore-rules/expenses-friendship.test.ts` were inverted, and the two
  creator-success counterparts added. Full rules suite green: **10 suites / 200 tests**.
- **Settlement asymmetry preserved.** The bilateral settlement either-party soft-delete
  (the settlements `allow update`) was left deliberately asymmetric and untouched —
  settlements are bilateral; expenses have a single creator.

**Stubs / defers.** Pure `firestore.rules` + rules-tests; no client / Cloud Function /
trigger / schema / `firestore.indexes.json` change. Invariants 1 / 3 / 4 N/A; Invariant 2
reinforced.

**Next candidates** (architect's call at the post-#72 kickoff): the carry-forward list
below — the **Bucket-B close-with-evidence bundle** (now IN FLIGHT as the next PR; the
diffuse runner-up to #47, closing/documenting the audit findings Sprint 2 already
resolved), the `go_router` migration (Sprint 3), FR-SR-01/02 Search (SCR-07), and the
Sprint 3 Groups epic (FR-GR-01..07).

---

## PR #71 — Merged (`shared_preferences` cross-launch persistence chore)

**Status:** Merged 2026-06-20 (`a0de106`). The `shared_preferences` cross-launch-persistence chore confirmed as
the next-slot pick at kickoff — the **highest-ranked unshipped carry-forward candidate**
and the **natural pair** with the merged #70 `app_settings` chore (deliberately NOT
bundled into it). It closes two documented in-memory deviations in one shot: the
`notification_permission_controller.dart` TODO (FR-AC-04 "next launch") and the
`reminder_cooldown_provider.dart` deferral (FR-SE-09 §2.6). There is **no** tracked
GitHub issue — recorded only as this candidate-list bullet plus two in-code notes — so
the PR opens **without** a `Closes #NN`; it lands as the next available number ≥ #71
(highest PR #70, highest issue #68), reconciled at PR open.

Both deferrals shipped best-effort-but-session-only because `shared_preferences` was not
in the lockfile. This is the **first on-device cross-launch client state** in the app
(every prior piece of client state is in-memory or Firestore-backed).

- **One plugin behind a shared seam (ADR-0020).** Adds `shared_preferences: ^2.5.5`
  (iOS pod `shared_preferences_foundation` platform 13.0 < the project's iOS 15 target —
  no version break) behind a thin `lib/core/services/key_value_store.dart` (`KeyValueStore`
  + `SharedPreferencesKeyValueStore` + `InMemoryKeyValueStore` default +
  `keyValueStoreProvider`), mirroring `AppSettingsService` / `UrlLauncherService`. The
  surface is synchronous and typed (`getBool` / `setBool` / `getString` / `setString` /
  `remove`) over an already-loaded `SharedPreferences`, so the sync `Notifier.build()`
  hydrates with no async/sync mismatch.
- **Load once in `main()`, inject via `ProviderScope`.** `await
  SharedPreferences.getInstance()` after the existing awaits, before `runApp`; override
  `keyValueStoreProvider`. The default `InMemoryKeyValueStore` keeps the platform channel
  out of `flutter test`; tests inject a fake (one shared instance across two containers
  simulates a relaunch) — never `setMockInitialValues`.
- **Persist `wasPermanentlyDenied`.** Hydrated in `build()`, awaited `setBool` on the
  deny/error transition; the line-89-90 TODO removed and the controller / README dartdocs
  corrected from "this session" to "next launch".
- **Persist the FR-SE-09 cooldown.** `reminderCooldownProvider` promoted to a
  `NotifierProvider.family` so read-hydrate / write-persist / **expiry** live in one class;
  a past `nextAllowedAt` hydrates as `null` with lazy key removal (never a phantom
  countdown). The server stays the authoritative 24-hour gate; cooldown writes are
  fire-and-forget.
- **Key registry + no telemetry.** Keys in `lib/core/persistence/preference_keys.dart`;
  NO new Analytics event (persistence is not a user action).
- **iOS `Podfile.lock` committed.** Regenerated via `pod install --repo-update`
  (+`shared_preferences_foundation` pod, no collateral Firebase version bumps). No Android
  `<queries>` entry.

**Stubs / defers.** No Cloud Function; no `firestore.rules` / index / schema change.
Invariants 1 and 2 are N/A (no money, no `simplifiedBalances`); Invariant 3 is N/A and
not conflated (on-device storage is not sharing). Does NOT widen scope to other ephemeral
state (theme, last-tab, draft expenses, onboarding flags) — each is its own future chore.

**Next candidates** (architect's call at the post-#71 kickoff): the carry-forward list
below — the `go_router` migration (Sprint 3), the Bucket-B chore close-out bundle, Issue
#47 rules-hardening, FR-SR-01/02 Search (SCR-07), and the Sprint 3 Groups epic
(FR-GR-01..07).

---

## PR #70 — Merged (AC-11 "Open Settings" deep-link CTA chore)

**Status:** Merged 2026-06-20 (`dda2f97`). The AC-11 "Open Settings" deep-link CTA chore confirmed as the
next-slot pick at kickoff — the **highest-ranked unshipped carry-forward
candidate** (it leads the post-#69 "Next candidates"), surfaced by PR #55 QA. It
closes the **PR #55 §2.4 AC-11 graceful-degradation deferral** in full (the SCR-27
notification banner gains the actionable button the fallback ladder promised) and
the **parallel SCR-10 contact-permission gap** (the `FlutterContacts.openExternalPick()`
placeholder is replaced by a real OS-settings deep-link). There is **no** tracked
GitHub issue — the follow-up was recorded only as this candidate-list bullet — so
the PR opens **without** a `Closes #NN`; it lands as the next available number
≥ #70 (highest PR #69, highest issue #68), reconciled at PR open.

Two surfaces fell short because, until now, no Flutter plugin capable of opening an
OS settings screen was in the lockfile: SCR-27 (`_OsPermissionBanner`) shipped
text-only (PR #55 §2.4 — `firebase_messaging` exposes no `openAppNotificationSettings()`
on the Dart API, re-verified in `firebase_messaging-16.3.0`), and SCR-10
(`ContactService.openSettings()`) opened the contact picker, not the app's settings
page (a line-77 TODO named `app_settings`).

- **One plugin behind a shared seam (ADR-0019).** Adds `app_settings: ^7.0.0` (the
  single-purpose choice — smallest dependency-graph + `ios/Podfile.lock` delta; iOS
  podspec platform 11.0 < the project's iOS 15 target, so no version break — **not**
  `permission_handler`; never both) behind a thin
  `lib/core/services/app_settings_service.dart` (`AppSettingsService` +
  `appSettingsServiceProvider`), mirroring `UrlLauncherService` / `ImagePickerService`.
  It exposes `openNotificationSettings()` (`AppSettingsType.notification`) and
  `openAppSettings()` (`AppSettingsType.settings`), so both call sites bind to a
  fakeable seam, never to the plugin directly.
- **Both surfaces wired (unify).** SCR-27: `_OsPermissionBanner` becomes a
  `ConsumerWidget` and gains an "Open Settings" `TextButton` → `openNotificationSettings()`;
  the banner copy is unchanged. SCR-10: `FlutterContactService.openSettings()` →
  `openAppSettings()` (the line-77 TODO removed); the non-permanent "Grant Permission"
  re-request and "Type a number instead" fallback are unchanged. First shared consumer
  of one permission-settings seam across `notifications`/`profile` and `friends`.
- **Telemetry (PII-free, newly DECLARED).** One `permission_settings_opened` event
  (`surface` enum `notifications`/`contacts`) added to `telemetry-plan.md §1.8` and
  logged at the presentation layer. No `uid`, friendship composite, or raw entity ID
  (SRS line 308 / ADR-0013).
- **iOS `Podfile.lock` committed.** Regenerated via `pod install --repo-update`
  (+`app_settings` pod, no collateral version bumps) — the CI "Build iOS (no signing)"
  job runs vanilla `pod install` and fails on a stale lock. No Android `<queries>`
  entry (system settings intents, not arbitrary-package visibility).

**Stubs / defers.** No Cloud Function; no `firestore.rules` / index / schema change.
Invariants 1 and 2 are N/A (no money, no `simplifiedBalances`); Invariant 3 is N/A
and **not** conflated — opening OS settings is not sharing and is never routed
through `Share.share`. **Does NOT bundle `shared_preferences`** (the
`wasPermanentlyDenied` / FR-SE-09 cooldown cross-launch persistence is a SEPARATE
tracked chore).

**Next candidates** (architect's call at the post-#70 kickoff): the carry-forward
list below — the `shared_preferences` adoption (cross-launch persistence), the
`go_router` migration (Sprint 3), the Bucket-B chore close-out bundle, Issue #47
rules-hardening, FR-SR-01/02 Search (SCR-07), and the Sprint 3 Groups epic
(FR-GR-01..07).

---

## PR #69 — Merged (FR-AC-05 deep-link tab-switch on notification tap)

**Status:** Merged 2026-06-17 (`8dd67f9`). FR-AC-05 (the deep-link tab-switch) confirmed as the next-slot
pick at kickoff — the **first carry-forward candidate** on the list below, now
**unblocked by the `shellNavigationControllerProvider` seam** shipped in #63 and
explicitly deferred there as "controller seam only". It closes the **last
deferred piece of a P0** (SRS section 4.7, line 240): every FR-AC requirement is
then fully shipped.

Today a notification tap pushes the detail screen onto the **root** navigator
over whatever primary tab happened to be active, and never drives the bottom-nav
selection — so the user lands in (and on pop returns to) a stale, unrelated tab.
This PR makes a notification deep-link **select the correct primary tab** before
the push, so the user lands in the relevant tab context with a coherent
back-stack.

- **Drive the shell tab from the deep-link dispatch (ADR-0018).** A new
  `int? homeTabIndex` getter on the sealed `DeepLinkTarget` carries the mapping
  with the target; `DeepLinkHandler.handleDeepLink` reads
  `shellNavigationControllerProvider.notifier` and `selectTab(...)` BEFORE the
  root-navigator push, leaving `NotificationDeepLinks.navigate` Riverpod-free.
- **Target → primary-tab mapping.** `DeepLinkExpenseDetail` /
  `DeepLinkFriendDetail` → the **Friends tab (index 1)** (both push a
  friends-cluster detail, so pop lands on Friends); `DeepLinkUnavailable`
  (e.g. `expense_deleted`) → the **Activity tab (index 3)** + the existing
  "This item is no longer available" snackbar (the item lived in the activity
  feed); `DeepLinkGroupsComingSoon` → no tab switch + the existing "Groups are
  coming soon" snackbar (forward-compat).
- **Cold-start ordering.** The tab switch rides the existing post-
  `AuthenticatedWithProfile` `addPostFrameCallback` replay so it never runs
  before `AuthenticatedShell` is mounted; `selectTab` is synchronous and runs
  before the awaited push, so there is no wrong-tab flash. A deep-link arriving
  pre-auth still caches to `pendingDeepLinkProvider` and replays on sign-in.
- **Activity-feed row-tap excluded.** The in-tab row-tap shares the resolver but
  uses `NotificationDeepLinks.navigate` directly (never the handler), so it does
  NOT switch tabs — guarded by a boundary-contract grep so a future refactor
  cannot accidentally couple them.
- **Telemetry (PII-free).** `fcm_notification_tapped` is extended with a
  non-identifying `target_tab` enum (`friends` / `activity` / `none`) — not a
  new event; no `uid`, friendship composite, or raw entity ID is ever a
  parameter (SRS line 308 / ADR-0013).

**Stubs / defers.** No new Cloud Function; no `firestore.rules` / index / schema
change; no new Flutter plugin (no `ios/Podfile.lock` change). Invariants 1 and 2
are N/A (no money, no `simplifiedBalances`). The `go_router` / per-tab nested
Navigator migration stays Sprint 3; the Groups epic and a real `group_invite`
deep-link stay deferred (the `group_invite` payload remains the
`DeepLinkGroupsComingSoon` snackbar).

**Next candidates** (architect's call at the post-#69 kickoff): the carry-forward
list below — the `app_settings`/`permission_handler` "Open Settings" CTA chore,
the `go_router` migration (Sprint 3), the Bucket-B chore close-out bundle, Issue
#47 rules-hardening, FR-SR-01/02 Search (SCR-07), and the Sprint 3 Groups epic
(FR-GR-01..07).

---

## PR #67 — Merged (FR-HD-03 monthly spend category breakdown chart)

**Status:** Merged 2026-06-17 (`1f26548`). Two review refinements landed in-PR
(a server-side month upper bound in `fetchExpensesInMonth`, reusing the existing
`expenses (deleted ASC + date DESC)` composite index; largest-remainder legend
percentages that always sum to 100); the deferred N+1-read denormalised rollup is
filed as FUTURE issue #68. FR-HD-03 confirmed as the next-slot pick at kickoff —
the
**top-ranked remaining P1** (SRS section 4.8, line 248) on the carry-forward
candidate list and the **last open Home-dashboard requirement** now that
FR-HD-01/02 shipped (#62), FR-HD-04 shipped (#57), and **every P0 functional
requirement is shipped**. It was explicitly deferred from #62 as "a separate
P1 PR (the real donut/bar chart + the category-aggregation read path)".

Replaces the `SpendingBreakdownPlaceholderCard` ("Spending breakdown coming
soon", `lib/features/home/presentation/widgets/spending_breakdown_placeholder_card.dart`)
under the "This Month" header (`home_dashboard_screen.dart`) with a real card:
the current calendar-month (IST, SRS section 5.9) **total spend** + a
per-category breakdown chart.

- **First cross-friendship expense read path (ADR-0017).** Every prior expense
  read was scoped to a single friendship (`watchExpensesByFriendship`).
  FR-HD-03 fans out over `friendsListProvider` (the FR-HD-01/02 source) to read
  each friendship's current-month non-deleted `expenses` and folds the
  signed-in user's OWN `sharePaise` from each expense's `splits` per
  `ExpenseCategory` — **NOT** the full `amountPaise` (which includes the other
  member's share and would over-report spend). `collectionGroup('expenses')`
  was rejected: expenses carry no member field, so the query cannot be scoped
  to the caller's friendships under the membership-gated rules without a schema
  change. Group axis stubbed (Sprint 3), exactly as `topBalancesProvider`.
- **Integer paise end-to-end (Invariant 1).** Every category subtotal and the
  month total is an integer `*Paise` sum; the only rupee conversion is
  `formatInrFromPaise(int)` at the widget layer; chart segment ratios derive
  from integer paise. No `double`, no inline `/100`.
- **First charting approach + 8-category colour-token map.** The donut chart
  (charting library ratified in ADR-0017) renders per-category segments using a
  new dark-mode-safe, WCAG-AA category→colour map (designer-owned); each
  segment announces "category, ₹amount, percentage" (never colour-only). Legend
  + month total below.
- **Empty / zero state.** No expenses this month → a friendly "No spending yet
  this month" card, NOT the chart. Loading reuses the dashboard skeleton; error
  reuses the FR-PR-05 `ContactSupportController` / `HD-FIRESTORE-READ` path
  (like FR-HD-01/02).
- **Telemetry (PII-free, newly DECLARED).** A new
  `home_spending_breakdown_viewed` event is added to `telemetry-plan.md §1.3`
  and wired — the first newly-declared telemetry event of the sprint's recent
  PRs (FR-PR-04/05 and FR-AU-09 all wired pre-declared events). No `uid`,
  `friendshipId`, or raw rupee/paise value is ever a parameter (SRS line 308).

**Stubs / defers.** No new Cloud Function; `firestore.rules` unchanged;
Invariant 2 N/A (reads `expenses`, never `simplifiedBalances`). A new
`firestore.indexes.json` index is added only if the architect finds the
existing `expenses (deleted ASC + date DESC)` composite index does not cover
the per-friendship current-month query (which orders by `date` DESC to reuse
it). The donut tap-to-drill-down per-category expense list, a denormalised
monthly-spend rollup Cloud Function (FUTURE optimisation), and any spending
share/export action (Invariant 3) are out of scope.

**Next candidates** (architect's call at the post-#67 kickoff): the
carry-forward list below — the FR-AC-05 deep-link tab-switch migration, the
`app_settings`/`permission_handler` "Open Settings" CTA chore, the Bucket-B
chore close-out bundle, Issue #47 rules-hardening, and the Sprint 3 Groups epic.

---

## PR #65 — Merged (FR-AU-09 permanently delete your account)

**Status:** Merged 2026-06-17 (`d542793`). FR-AU-09 confirmed as the next-slot pick at kickoff —
the **next top-ranked remaining P1** (SRS section 4.1, line 168) now that
FR-PR-02 has merged (#64) and **every P0 functional requirement is
shipped**. It is the **LAST open authentication-cluster requirement**
(FR-AU-01..08 are all shipped) and the **first reuse of the FR-PR-02
re-authentication surface** (`PhoneAccountRepository.reauthenticate`)
outside the change-phone flow.

Replaces the `'Coming soon'` Delete Account dead-end on the Profile screen
(SCR-26, `profile_screen.dart` lines 387-401) with the SCR-28 Part B
multi-step full-screen flow at `/profile/delete-account` (Step A warning →
Step B re-authentication → Step C type-`DELETE` confirmation → Step D
processing → Step E success → Phone Entry, stack cleared):

- **New callable Cloud Function `deleteUserAccount`** (region
  `asia-south1`, exported from `index.ts` with the `REGION` const; auth
  check first → `UNAUTHENTICATED`; `HttpsError` with `details.errorCode`).
  The **first cascade-delete fan-out function** and the **first
  `admin.auth().deleteUser(...)`** — it runs the cascade via the Admin SDK
  (clients have NO delete path). Idempotent (already-absent state treated
  as success); step order Firestore (`recursiveDelete`) → Storage → Auth
  LAST.
- **Cascade matrix (ADR-0016).** DELETE personal records (`activity/{uid}`,
  `_rateLimits/{uid}`, Storage `avatars/{uid}`, the Firebase Auth record
  LAST); TOMBSTONE `users/{uid}` into a PII-free
  `{ displayName: 'Deleted User', deletedAt }` shell; PRESERVE shared data
  untouched (friendships where the user is a member, their expenses,
  settlements, receipts). The surviving member's `simplifiedBalances` is
  **NEVER** recomputed, zeroed or stripped (Invariant 2) — the **first
  server-side write adjacent to `simplifiedBalances` that deliberately
  preserves it**.
- **"Deleted User" via tombstone (no client change).** The three name
  fallback sites already use `displayName ?? 'Unknown'`, so a present
  `displayName: 'Deleted User'` renders "Deleted User" while a genuine
  missing-doc read stays "Unknown".
- **Re-auth reuses FR-PR-02.** SCR-28 Step B drives the existing
  `PhoneAccountRepository` (`requestOtp` + `reauthenticate` +
  `currentPhoneNumber`); never `signInWithCredential`. +91 only.
- **Type-`DELETE` gate** (case-sensitive, trimmed) before any Function
  call; processing Step D blocks back navigation with a 30s timeout →
  Profile + Contact Support snackbar (reuses the FR-PR-05
  `ContactSupportController`); success Step E → Phone Entry, stack cleared.
- **Telemetry (PII-free).** The 7 `delete_account_*` events are already
  pre-declared in `telemetry-plan.md §1.7`; only `delete_account_failed`
  carries `error_code`; the uid / phone number is NEVER a parameter (SRS
  line 308). Server logs hash the uid via `hashId`.

**Stubs / defers.** `firestore.rules` unchanged (client delete already
denied on users/friendships/settlements; a rules test confirms it stays
rejected). Groups axis stubbed (no live groups in v1.0; friendship axis
implemented fully, group axis forward-compat TODO + ADR note). The 30-day
**scheduled-cleanup reaper**, deletion-confirmation SMS, and admin audit
log (SCR-28 Account Deletion Open Questions 1-3) are deferred to a FUTURE
follow-up issue. No new Flutter plugin (`cloud_functions` already a
dependency) — **no `ios/Podfile.lock` change**.

**Next candidates** (architect's call at the post-#65 kickoff): **FR-HD-03 the
real spend-breakdown chart was selected and is now in flight as #67 above** (the
top-ranked remaining P1 and the last open Home-dashboard requirement). The
remaining carry-forward — the FR-AC-05 deep-link tab-switch migration, the
`app_settings`/`permission_handler` "Open Settings" CTA chore, the Bucket-B
chore close-out bundle, Issue #47 rules-hardening, and the Sprint 3 Groups epic.

---

## PR #64 — Merged (FR-PR-02 update phone number via OTP re-verification)

**Status:** Merged 2026-06-16 (`2e68713`). FR-PR-02 confirmed as the next-slot pick at kickoff —
the **top-ranked remaining P1** (SRS section 4.2, line 175) now that
**every P0 functional requirement is shipped** (FR-PR-04 closed the last
one in #63). It sits above FR-AU-09 account-deletion and the chore bundle
on the carry-forward list, removes the "Phone number cannot be changed
from here." dead-end on the Edit Profile screen (FR-PR-01), and is the
**first reuse of the auth phone-entry + OTP-entry flow outside sign-in**.

Replaces the read-only phone dead-end (SCR-26 Open Question #1, resolved
here) with a "Change Phone Number" flow:

- **`updatePhoneNumber` repo method — the mutate-current-user path.** New
  `PhoneAuthRepository.updatePhoneNumber({verificationId, code})` building
  `PhoneAuthProvider.credential(...)` and calling
  `currentUser.updatePhoneNumber(credential)` (NOT `signInWithCredential`,
  which would switch accounts). `credential-already-in-use` maps to the
  existing `AuthError.credentialInUse`.
- **`requires-recent-login` is the common path** (FR-AU-07 session
  persistence keeps the last sign-in older than Firebase's ~5-minute
  window). Two-OTP state machine: re-verify the CURRENT number
  (`reauthenticateWithCredential`) then verify the NEW number. New
  `AuthError.requiresRecentLogin` variant + British copy; mapped in
  `_mapException`.
- **`firestore.rules` `phoneNumber`-immutability relaxation
  (architect-owned).** `isValidUserUpdate()` line 80 relaxed from
  `data.phoneNumber == prev.phoneNumber` to
  `(data.phoneNumber == prev.phoneNumber || data.phoneNumber ==
  request.auth.token.phone_number)` — the first conditionally-writable
  identity field. Every other immutability/shape check is preserved.
  Token-refresh ordering: `currentUser.getIdToken(true)` after
  `updatePhoneNumber` and BEFORE the `users/{uid}.phoneNumber` write, or
  the relaxed rule rejects against a stale `phone_number` claim. Functions
  Dev extends `users-update.test.ts` (allow change-to-token-phone; reject
  change-to-arbitrary-phone; other immutables still rejected).
- **Telemetry (PII-free).** `phone_change_*` funnel events with an
  `error_code` enum; the number is NEVER a parameter (SRS line 308).
  Pre-declared in `telemetry-plan.md §1.7`.

**Stubs / defers.** International / multi-number support permanently out
of scope (+91 only, SRS line 133 / section 12.3). No friendship/contact
migration on change (existing friendships are UID-keyed, unaffected). No
new Cloud Function / collection / index / Flutter plugin — `firebase_auth`
already a dependency, so **no `ios/Podfile.lock` change**. The only backend
change is the `firestore.rules` relaxation + its tests.

**Next candidates** (architect's call at the post-#64 kickoff): **FR-AU-09
account-deletion was selected and is now in flight as #65 above** (the next
top-ranked P1, needing the cascade-delete Cloud Function). The remaining
carry-forward list — the FR-AC-05 deep-link tab-switch migration, the
`app_settings`/`permission_handler` "Open Settings" CTA chore, the
FR-HD-03 real chart, Issue #47 rules-hardening, and the Sprint 3 Groups
epic.

---

## PR #63 — Merged (FR-PR-04 My Friends / My Groups from Profile)

**Status:** Merged 2026-06-13 (`209afea`). FR-PR-04 was the next-slot pick
at kickoff — the **last open P0 functional requirement** (SRS section 4.2,
line 177); **every P0 functional requirement is now shipped**. It was
**missing from this candidate list** (the FR-HD-01/02 kickoff called
FR-HD "the last open P0 product surface"; FR-PR-04 was an omission), and
P0 outranked every remaining P1 (FR-PR-02, FR-AU-09, FR-HD-03) and every
chore.

Replaces the two hardcoded `'0'` + "Coming soon" snackbar Stats stubs on
the Profile screen (SCR-26) — shipped with FR-PR-01 — with live counts +
cross-tab navigation:

- **Live "My Friends" count.** `friendCountProvider`
  (`lib/features/profile/application/`, `Provider<AsyncValue<int>>`) — a
  pure `.length` projection over `friendsListProvider` with
  `dependencies: [friendsListProvider]` (the PR #62 scoping rule). Four
  async sub-states on the row: em dash on loading / error (never a
  crash), the integer on data, `0` on empty.
- **`shellNavigationControllerProvider` — the architectural first.** A
  `NotifierProvider.autoDispose<ShellNavigationController, int>` exposing
  `selectTab(int)`, replacing the in-shell `setState(_currentIndex)` and
  closing the PR #56 shell-story §2.2 deferral ("no `Notifier<int>` until
  a second consumer needs it" — FR-PR-04's Profile rows are that
  consumer). `AuthenticatedShell` reads it for `IndexedStack.index` /
  bottom-nav / PopScope and writes it from `_onTabSelected`, preserving
  the `bottom_nav_tab_selected` user-tap telemetry, the PopScope
  snap-to-tab-0 (no telemetry), and the FAB rules.
- **Profile rows rewired.** "My Friends" → `selectTab(1)` (Friends tab);
  "My Groups" → stub `0` + `selectTab(2)` (Groups tab) — no duplicate
  `FriendsListScreen` push (preserves IndexedStack tab-state). Two
  PII-free events `profile_friends_tapped` / `profile_groups_tapped`
  (`profile_stats_telemetry.dart`, pre-declared in `telemetry-plan.md`
  §1.7). SCR-26 a11y labels preserved with the live count.

**Stubs / defers.** Group axis stubbed (Sprint 3 Groups epic — "My
Groups" count is a literal `0`). **FR-AC-05 cold-start deep-link
tab-switch migration deferred** — this PR provides the controller seam
only; the FCM handler migration is a separate follow-up. No
`OBTProfileStatRow` extraction (deferred until a second use site). Zero
schema / rules / index / function change; no new Flutter plugin (no
`ios/Podfile.lock` change).

**Next candidates** (architect's call at the post-#63 kickoff): the
carry-forward list below — the FR-AC-05 deep-link tab-switch migration
(now unblocked by `shellNavigationControllerProvider`),
`app_settings`/`permission_handler` "Open Settings" CTA chore, FR-PR-02
phone-number-change, FR-AU-09 account-deletion, Issue #47
rules-hardening, the FR-HD-03 real chart, and the Sprint 3 Groups epic.

---

## PR #62 — Merged

**Status:** Merged 2026-06-13 (`57c272e`). FR-HD-01 + FR-HD-02 the real
Home dashboard (SCR-06) shipped — the last open P0 product surface on
this candidate list when it was picked.

Replaced `HomeDashboardPlaceholder` (shell tab 0, live since PR #56) with
the real `lib/features/home/` feature:

- **FR-HD-01** overall net-balance header card +
  **FR-HD-02** top-5 friendships by absolute balance with per-row
  "Settle Up" (`source: 'home_dashboard'`) and tile-tap → Friend Detail,
  via two pure derived providers (`overallNetBalanceProvider` sum,
  `topBalancesProvider` abs-sort / zero-exclude / cap-5 / stable
  tie-break) composed over `friendsListProvider` — no new data layer.
- Four inline states (loading / empty / populated / error). The error
  state (`HD-FIRESTORE-READ`) is the **first reuse of the FR-PR-05
  `ContactSupportController`** outside Profile.
- **FR-HD-03** (P1) "Spending breakdown coming soon" placeholder card —
  no chart, no charting plugin.
- `home_telemetry.dart` (6 SCR-06 events; `context_id_hash` via
  `hashFriendshipId`, PII-free) + a 1-line optional `source` param on
  `SettleUpBottomSheet` (default `friend_detail`).
- Shell tab-0 swap + `home_dashboard_placeholder.dart` deletion + shell
  README update.

**Stubs / defers.** Group axis stubbed (Sprint 3 Groups epic — no group
tiles). FR-OF-01 offline banner deferred (needs a connectivity plugin →
`ios/Podfile.lock` churn). Zero schema / rules / index / function change;
no new Flutter plugin.

---

## PR #57 — Merged

**Status:** Merged 2026-06-11. FR-HD-04 P0 + bundled `currentUserIdProvider` production-wiring closure shipped.

PR #57 shipped the FR-HD-04 persistent FAB + Add Expense context
picker in a single 3-SP bundle, plus the mandatory-bundled regression
closure for the `currentUserIdProvider` production-wiring gap that
PR #56 left behind in its `AuthenticatedWithProfile` arm. Natural
completion of PR #56 architect §2.1 reconciliation:

- **`OBTFloatingActionButton` design-system primitive** at
  `lib/core/widgets/nav/obt_floating_action_button.dart` per
  `components.md` (50 LOC). Material 3 FAB with the OneByTwo
  design tokens; reusable across every primary surface that
  needs a primary-action FAB.
- **`AuthenticatedShell` FAB slot.** The shell wires an
  `OBTFloatingActionButton` into `Scaffold.floatingActionButton`;
  `_onFabTapped` opens the Add Expense context picker bottom
  sheet. The FAB is hidden on the Activity tab per architect §2.3
  (Activity is a read-only surface).
- **`AddExpenseContextPickerSheet`** at
  `lib/features/shell/presentation/add_expense_context_picker_sheet.dart`
  (282 LOC). Friend path routes to the existing Add Expense
  bottom sheet (PR #38) with the selected friend pre-populated;
  Group path stubbed with a "Coming soon" snackbar pending the
  Sprint 3 Groups epic.
- **6 new `shell_telemetry.dart` constants** for the FAB-tap →
  picker-open → friend-select / group-select-stub funnel.
- **`friend_detail_screen.dart` FAB refactor** to consume the new
  `OBTFloatingActionButton` primitive with `heroTag: 'friendDetailFab'`
  (avoids Hero animation collision with the shell-owned FAB).
- **Bundled `currentUserIdProvider` production-wiring closure
  (mandatory bundle).** `lib/main.dart` now overrides
  `currentUserIdProvider` per-arm inside the `AuthenticatedWithProfile`
  `ProviderScope`. Without this fix, both `friendsListProvider` and
  `activityFeedProvider` threw `UnimplementedError` on first read in
  production. The 2-character Riverpod 2.x `dependencies: [currentUserIdProvider]`
  addition on each of those two providers (architect §2.9
  reconciliation discovery) is the natural completion of PR #56
  architect §2.1.

**In-spec deviations.** None. The architect's §2.2 reconciliation
documented spring-physics polish as a tracked follow-up (~1 SP);
not a deviation, just a polish item now on the PR #58 candidate
list.

**Velocity:** 3 SP (PR #57) → cumulative **90 SP across 21 PRs**.

**Test deltas:** +40 net new Flutter tests (1203 → 1243 passing + 30
skipped unchanged); Functions UNCHANGED (319 / 22); `dart analyze
--fatal-infos` + `dart format --set-exit-if-changed` clean; Inv-1 /
Inv-2 / Inv-4 / PII-leak greps clean on the new
`lib/features/shell/**` + `lib/core/widgets/nav/obt_floating_action_button.dart`
files. Gate-5 storage-rules pre-existing environmental emulator
failure (6 receipts tests in `functions/test/storage-rules/receipts.test.ts`;
**identical pass/fail set against `main` and HEAD**; environmental
`firestore.get()` cross-collection evaluation issue, NOT a regression
caused by PR #57) is tracked as a separate ~1-2 SP investigation
chore on the PR #58 candidate list below.

**Manual smoke matrix:** deferred to post-merge canary per the v1.0
single-Firebase-project convention. The PR body documents the smoke
matrix (sign-in → shell mount → FAB visible on Home / Friends /
Groups / Profile, hidden on Activity → tap FAB → context picker
bottom sheet appears → select Friend → Add Expense bottom sheet
opens with the selected friend pre-populated → select Group →
"Coming soon" snackbar).

---

## PR #56 — Merged

**Status:** Merged 2026-06-11. UX foundation chore.

PR #56 shipped the long-deferred OBTBottomNav shell in a single 3-SP
bundle:

- **`OBTBottomNav` design-system primitive** at
  `lib/core/widgets/nav/obt_bottom_nav.dart` per `components.md §2`.
  Five spec-ratified tabs (Home / Friends / Groups / Activity /
  Profile) with outlined-vs-filled icon swap on selection, the active
  tab using `Theme.colorScheme.primary`, a 48 dp tap-target floor,
  and Material's `BottomNavigationBarType.fixed`. The static
  `OBTBottomNav.tabs` list is the single source of truth for labels,
  icons, and telemetry tokens — the shell consumes it directly when
  firing the per-tap telemetry.
- **`AuthenticatedShell` IndexedStack host** at
  `lib/features/shell/presentation/authenticated_shell.dart`. The
  `ConsumerStatefulWidget` mounts the five tab content widgets in an
  `IndexedStack` so each tab's `State` instance + scroll position +
  active stream subscriptions survive a tab switch. The
  `@visibleForTesting tabContentOverride` parameter lets widget tests
  inject stub content to isolate the shell from per-feature provider
  graphs. The `PopScope(canPop: _currentIndex == 0)` wrapper snaps
  Android back-button presses from any non-zero tab to tab 0 (Home);
  back-driven switches do NOT fire telemetry (architect §2.6).
- **2 new placeholder screens** at
  `lib/features/shell/presentation/{home_dashboard_placeholder,groups_list_placeholder}.dart`
  per architect §2.5 (colocated with the shell rather than scattered
  across `lib/features/home/` + `lib/features/groups/`). Home
  placeholder ships until FR-HD-01..04 lands; Groups placeholder
  ships until the Sprint 3 Groups epic ships the real
  `GroupsListScreen`.
- **`bottom_nav_tab_selected` telemetry event** appended to
  `docs/design/07-technical/telemetry-plan.md §1.8 Cross-Cutting
  Events`. Payload: `tab_index` (int 0..4) + `tab_label` (canonical
  lowercase token). PII-clean per ADR-0013.
- **`lib/main.dart` line 133 wire change** swapping
  `HomePlaceholderScreen` for `AuthenticatedShell`, plus the matching
  push update in `phone_entry_screen.dart` after successful OTP
  verification.
- **DELETION** of `lib/features/auth/presentation/home_placeholder_screen.dart`
  per architect §2.4. Body content extracted to
  `HomeDashboardPlaceholder`; the temporary in-AppBar Activity /
  Profile shortcut buttons are obsoleted by the bottom nav.

**In-spec deviations.** None. The architect's §2.10 reconciliation 4
ratified shipping WITHOUT the `components.md §2` "indicator pill
behind icon" because Flutter's `BottomNavigationBar` does not render
it (the pill is a Material 3 `NavigationBar` feature; ship pillless
for v1.0 + revisit if/when a `NavigationBar` migration is approved).

**Velocity:** 3 SP (PR #56) → cumulative **87 SP across 20 PRs**.

**Test deltas:** +33 Flutter tests (5 telemetry constants + 14
`OBTBottomNav` widget tests + 10 `AuthenticatedShell` widget tests +
4 boundary-contract greps including the AC-14 deletion check); zero
new Functions tests (the PR ships no server-side code). All gates
green: 1203 Flutter tests pass; 191 rules tests unchanged; `dart
analyze --fatal-infos` + `dart format --set-exit-if-changed` clean;
Inv-1 / Inv-2 / Inv-4 / PII-leak greps clean on the new
`lib/features/shell/**` + `lib/core/widgets/nav/obt_bottom_nav.dart`
files.

**Manual smoke matrix:** deferred to post-merge canary per the v1.0
single-Firebase-project convention. The PR body documents the smoke
matrix (sign-in → shell mount → tap each tab → switch tabs and
verify scroll preservation → push SCR-27 over Profile and verify
bottom nav hides → Android back from non-zero tab snaps to Home).

---

## PR #55 — Merged

**Status:** Merged 2026-06-11. FR-PR-03 + FR-AC-04 shipped.

PR #55 closed two paired stories plus the deferred client-side
`cloud_functions` wiring chore in a single 5-SP bundle:

- **FR-PR-03 (Notification Preferences UI).** The Profile screen
  gained a `/profile/notifications` route (SCR-27) backed by the
  existing `users/{uid}.notificationPrefs` map. Three toggles
  (`newExpense`, `settlement`, `reminder`) each auto-save via a
  per-toggle 500 ms debounce; the new `NotificationPreferencesController`
  follows the `edit_profile_controller.dart` blueprint with a
  sealed `Ready` state carrying `savingKeys: Set<String>` for
  in-flight per-toggle spinners (rather than a separate hierarchy
  state — architect §2.1 ratification). The writer
  (`UserRepository.updateNotificationPrefs`) uses Firestore
  dot-path partial-map updates (`'notificationPrefs.reminder': false`)
  to avoid the read-modify-write race the full-map form would
  inherit (architect §2.2 ratification).
- **FR-AC-04 (server-side prefs gate, user-controllable).** The
  prefs-filter shipped in PR #53 is already the gate for every
  FCM fan-out path (expense triggers, settlement triggers,
  FR-SE-09 reminder callable); PR #55 makes that gate
  user-controllable from the client. No server-side change was
  needed — the gate inherits whatever flag the user flips. End-
  to-end coverage: 3 new `users-update.test.ts` rules tests
  validate the partial-map shape (positive partial-map; rejection
  on invalid value type; rejection on full-replace shape dropping
  the required `reminder` key). The separate fourth-key
  reconciliation remains tracked in architect §2.10 and is not
  conflated with AC-19's required-key contract.
- **Production `cloud_functions` adapter wiring (deferred chore
  closed in PR #55).** `cloud_functions` was added to
  `pubspec.yaml` and both `reminderRepositoryProvider` and
  `matchingRepositoryProvider` gained production overrides in
  `main.dart` — closing the throw-until-overridden gap that
  PR #54 left as the top candidate for PR #55. The FR-SE-09
  Send Reminder callable now reaches its production handler
  from the app shell.

**Architect §2.4 fallback realised (in-spec deviation).** At
kickoff the Flutter-dev verified that `firebase_messaging: ^16.2.0`
does NOT expose `openAppNotificationSettings()` on the Dart API
(neither Android nor iOS). Per architect §2.4 the graceful-
degradation path shipped: the OS-permission banner renders on both
platforms WITHOUT the "Open Settings" CTA button. A follow-up
`app_settings` / `permission_handler` chore PR remains tracked in
the PR #57 candidate list below to surface AC-11 on a later
iteration. The deviation was greenlit by QA because the banner
copy itself already conveys the required user action.

---

## PR #58 — Merged

**Status:** Merged 2026-06-12. FR-SE-08 dedicated settlement-history
screen (SCR-24) shipped for the friendship axis.

PR #58 closed the FR-SE-08 P0 commitment for the dedicated
`/settle/history` surface. The in-timeline settlement rows (PR #42 +
PR #43) satisfied the functional commitment; PR #58 delivered the
design-spec contract — a full reverse-chronological list reachable
from the "View Settlement History" link on Friend Detail:

- **`SettlementHistoryScreen`** (SCR-24) at
  `lib/features/settlements/presentation/settlement_history_screen.dart`.
  Generic over `(contextType, contextId)` — the architectural seam the
  Sprint 3 Group Detail screen inherits. Four states (loading /
  populated / empty / error) via inline private widgets (no OBT*
  primitive extraction).
- **`settlementHistoryProvider`** — a `StreamProvider.family` keyed by
  `SettlementHistoryArgs { contextType, contextId }`, reusing the
  PR #42 `watchByContext` read path with a 50-item cap. Zero changes
  to the repository, rules, or indexes.
- **`settlement_history_telemetry.dart`** — the two pre-declared
  events (`settlement_history_viewed`, `settlement_history_error`).
  NEITHER carries `context_id` (PII guard, ADR-0013).
- **"View Settlement History" link** on `FriendDetailScreen` (populated
  state only). No entry-point telemetry — the destination's
  `settlement_history_viewed` captures the funnel arrival.

Deferred (tracked follow-ups): Group-context push wiring (Sprint 3),
cursor-based pagination beyond 50, the OBT* primitive extractions
(`OBTSkeletonLoader` / `OBTEmptyState` / `OBTErrorState` /
`OBTUserAvatar` / `OBTRupeeText`), real-time fade-in, context-deleted
snackbar, per-month grouping, settlement-detail navigation, and the
share/export action.

**Velocity:** 3 SP (PR #58) → cumulative **93 SP across 22 PRs**.

---

## Carry-forward candidate list (post-#62)

**Status:** Rolling backlog. FR-HD-01/02 is in flight as #62 (see the
section near the top). The architect picks the post-#62 slot from the
list below per Sprint 2 velocity.

The candidate list carries forward everything not yet shipped.

Candidates (in rough priority order — architect's call at kickoff):

- **FR-PR-05 Contact Support `mailto:` flow** (P0) — **MERGED (#60,
  `8f72514`).** Bundled FR-SH-03 and the FR-SH-04 no-mail-client
  fallback dialog; 3 SP. First Firebase Remote Config consumer
  (`support_email_address`, in-app default `support@onebytwo.app`,
  ADR-0006). Wired BOTH Profile entry points — the action row and the
  error-state "Still stuck? Contact Support" link. The "Contact Support"
  links on OTHER error surfaces reuse the same `ContactSupportController`
  but remain separate follow-ups — **the FR-HD-01/02 dashboard error
  state (#62) is the first such reuse.**
- **`app_settings` / `permission_handler` dependency +
  AC-11 "Open Settings" CTA wiring (surfaced by PR #55 QA).**
  ~1-2 SP. Adds the dependency + wires the CTA on both platforms.
  Natural pair with `shared_preferences` adoption below.
  **IN FLIGHT as PR #70 (2026-06-17)** — `app_settings: ^7.0.0` (the
  single-purpose choice; not `permission_handler`; never both) behind a
  shared `lib/core/services/AppSettingsService` seam, wiring the SCR-27
  notification banner (FR-AC-04 / AC-11) and the SCR-10 contact-permission
  view (FR-FR-01); PII-free `permission_settings_opened` telemetry;
  `ios/Podfile.lock` committed. Closes the PR #55 §2.4 deferral and the
  `openExternalPick` placeholder. ADR-0019. The `shared_preferences`
  cross-launch-persistence pairing stays a SEPARATE chore (below).
- **FR-PR-02 phone-number-change flow** (P1; depends on the
  existing OTP re-verification flow; medium PR ~5 SP).
- **FR-AU-09 account-deletion flow** (P1; depends on a new
  Cloud Function for cascade-delete fan-out; medium PR ~5-8 SP) —
  **IN FLIGHT (this PR; PR #65; deferred reaper work as FUTURE issue #66).**
- **Bucket-B chore close-out** — the close-with-evidence verification
  **MERGED as #73 (`f9a4c54`, `Closes #21`)**; the remaining actionable
  chores (#15-#20, #23, #24, #28) are being closed out via **three
  consolidated PRs** (see `docs/sprint-zero/sprint-2-plan.md` §"Sprint 2
  close-out — consolidated chore PRs"). The first — the **`chore(auth)`
  client-housekeeping bundle** closing **#15 / #16 / #17 / #18** —
  **MERGED as #74 (`ce6d594`)**; the second — the **`docs` bundle**
  closing **#19 / #24 / #28** — **MERGED as #75 (`dbc209d`)**; the third
  and final — the **`test` bundle** (closes #20, re-scopes #23) — is
  **IN FLIGHT (this PR, #76)**.
- **Issue #47 rules-hardening for non-creator update/delete gate**
  (operational hardening; small standalone PR ~2 SP). Closes the
  defence-in-depth gap that the FR-EX-06 architect §2.9 item 5
  documented. **IN FLIGHT (opens with `Closes #47`)** — adds
  `request.auth.uid == prev.createdBy` to `isValidExpenseUpdate()` so only the
  expense creator may edit or soft-delete a friendship-context expense; inverts
  the two `assertSucceeds` "flip to assertFails" placeholder tests and adds the
  creator-success counterparts (full rules suite green). Settlement either-party
  soft-delete deliberately left asymmetric. Pure rules + rules-tests; no client /
  function / trigger / schema / index change.
- **`shared_preferences` adoption** for cross-launch persistence
  (PR #53 §2.6 `wasPermanentlyDenied` flag + FR-SE-09 §2.6 cooldown
  persistence). ~2-3 SP. Natural pair with the `app_settings` /
  `permission_handler` chore above. **MERGED (#71, `a0de106`, 2026-06-20)**
  — `shared_preferences: ^2.5.5` behind a thin `lib/core/services/KeyValueStore`
  seam (loaded once in `main()`, injected via `ProviderScope`); persists
  FR-AC-04 `wasPermanentlyDenied` (closes the controller TODO) + the
  FR-SE-09 cooldown (`NotifierProvider.family` with a past-`nextAllowedAt`
  expiry guard); no telemetry; `ios/Podfile.lock` committed. ADR-0020.
- **FR-HD-01..04 home dashboard implementation** (P0) — **IN FLIGHT
  (this PR; FR-HD-01 + FR-HD-02 only; roadmap "PR #62" slot, ≥ #62).**
  The `HomeDashboardPlaceholder` shipped by PR #56 is replaced by the
  real `lib/features/home/` dashboard; the FR-HD-04 persistent FAB
  (PR #57) is inherited for free. FR-HD-03 ships as a "coming soon"
  placeholder card only (no chart, no charting plugin — the real
  donut/bar chart + category-aggregation read path is a separate P1
  PR). The FR-OF-01 offline banner is deferred (needs a connectivity
  plugin → `ios/Podfile.lock` churn). 5 SP.
- **FR-SE-09 message-compose dialog follow-up** (the deferred UX
  PR per FR-SE-09 architect §2.5). 1-2 SP.
- **`shellNavigationControllerProvider` + FR-AC-05 deep-link
  tab-switching expansion** (follow-up to PR #56; ~2-3 SP). **IN FLIGHT as
  PR #69 (2026-06-17)** — the seam shipped in #63, and this PR wires the
  notification deep-link dispatch to `selectTab(...)` so a tap lands on the
  relevant primary tab (Friends for expense/friend detail, Activity for the
  unavailable snackbar) before the root-navigator push. The Activity-feed
  row-tap is excluded (in-tab navigation). Closes the #63 "controller seam
  only" deferral; every FR-AC requirement is then fully shipped.
- **FR-SR-01 / FR-SR-02 Search (SCR-07)** (P1; **reconciled into this
  list 2026-06-17 — previously OMITTED, corrected here**; net-new
  feature; **Sprint 3**; sizeable, ~8-13 SP, likely split across PRs).
  Search expenses by description, amount, category, or member (FR-SR-01,
  SRS line 255) + filter by date range, group, and category (FR-SR-02,
  SRS line 256). **Unbuilt** — there is no `lib/features/search/` folder,
  though the **six `search_*` events are already pre-declared** in
  `telemetry-plan.md §1.3` and SCR-07 (`search_opened`,
  `search_query_submitted`, `search_filter_applied`,
  `search_result_tapped`, `search_no_results`, `search_closed`).
  **Architectural escalation (ADR-worthy):** Firestore has **no native
  full-text search**, so "search by description" cannot be a server
  query — the approach must be ratified at kickoff: (a) client-side
  filtering over a cross-friendship expense read path (the FR-HD-03
  fan-out precedent; no new dependency, but only over loaded data and
  re-using/extending the FUTURE rollup #68 cost profile), (b) a
  third-party search index (Algolia / Typesense — a new dependency,
  cost, and a sync Cloud Function), or (c) Firestore prefix/exact
  matching only (description prefix + exact amount/category/member).
  **Open SCR-07 design questions that gate the build:** OQ-SR-01 (entry
  point — Home app-bar icon vs all-tab vs pull-down), OQ-SR-02
  (recent-searches persistence — pairs with the `shared_preferences`
  chore above), OQ-SR-03 (amount range vs exact match), OQ-SR-04
  (date-range filter presentation). Ranks **below the Groups P0 epic**;
  the search-backend decision plus the four OQs must be resolved before
  implementation — the architect confirms the slot at a Sprint 3 kickoff.
- **`OBTFloatingActionButton` spring-physics polish** (~1 SP —
  tracked follow-up per PR #57 architect §2.2 reconciliation. The
  primitive shipped without the spring-physics scale-in animation
  on first frame; cosmetic polish item, not a defect).
- **`currentUserIdProvider` rehoming** (~1 SP — tracked follow-up
  per PR #57 reviewer recommendation 2). The provider declaration
  still lives at `lib/features/friends/application/friends_list_provider.dart:15-21`
  for historical reasons (it was introduced alongside the friends
  list in PR #35) but the consumer set has since expanded to
  `friends`, `activity`, `shell` (the FAB context picker), and
  `main` (the per-arm `ProviderScope` override). The name no
  longer matches its location. Lift to `lib/features/auth/application/`
  or `lib/core/auth/` once a next unrelated consumer arrives so the
  rehoming has a forcing function beyond cosmetics. Architect §2.1
  explicitly deferred this from PR #57 to keep the bundle minimal.
- **`cloud-functions-catalogue.md §7` docs roll-up** (cosmetic
  chore; ~1 SP). The catalogue's `reminders/{senderUid}_{toUserId}`
  storage path and `RECIPIENT_NO_TOKENS → success: true` shape are
  SUPERSEDED by the FR-SE-09 architect ratifications.
- **Activity-writer rename cleanup** (cosmetic; small chore PR
  ~1-2 SP). Per FR-AC-01 architect §2.3 the rename of
  `writeExpenseActivity` → `writeContextActivity` was DEFERRED to
  minimise blast radius.
- **`OBTRupeeText` primitive** (UX foundation; small PR ~1 SP).
  Deferred from PR #52 per architect §2.6. Still waiting for a
  second use site.
- **`go_router` migration** (Sprint 3 standalone chore ~3-5 SP per
  `navigation-flow.md §4.4`). Refactors every existing
  `Navigator.push(MaterialPageRoute)` call site to a `go_router`
  route; the AuthenticatedShell refactors to a
  `StatefulShellRoute.indexedStack`.
- **Storage-rules `firestore.get()` cross-collection investigation
  chore** (~1-2 SP — discovered by PR #57 Phase 4 QA). The
  `npm run test:rules` Gate-5 currently shows 6 failures in
  `functions/test/storage-rules/receipts.test.ts` against the
  storage emulator's `firestore.get()` cross-collection predicate
  evaluation. Failures are pre-existing on `main` (IDENTICAL
  pass/fail set against `main` and HEAD); environmental / emulator
  issue, NOT a code defect in `storage.rules` or in PR #57's
  implementation. Tracked as a separate investigation rather than
  any blocker.
- **FCM emulator-side integration test infrastructure** (per
  PR #53 functions-dev §1 deviation). 2-3 SP.
- **Concurrent-edit detection for FR-EX-06** (operational
  hardening; small standalone PR). Explicitly deferred from PR #46.
- **Issue #49 — Orphan-cleanup Cloud Function for receipts**
  (FUTURE; filed during PR #48 per SRS schema doc line 312).
  Out of v1.0 unless required for compliance.
- **Issue #50 — Trigger no-op-recompute optimisation** (FUTURE;
  filed during PR #48). **EXPLICITLY CONSTRAINED** by FR-EX-07
  (PR #51 AC-2): the optimisation must NOT skip activity emission
  on receipt-only updates; a follow-up will update issue #50 with
  this constraint.
- **Rate-limit transaction race refactor** (operational hardening;
  small standalone PR). Deferred from PR #45 per chore-story
  Architect Notes §2.2. The FR-SE-09 rate-limit doc shape
  inherits the same read-modify-write race vector.
- **`emitExpenseActivity` memberIds re-read cleanup**
  (operational cleanup; small standalone PR ~1 SP). Per the
  PR #51 review recommendation #1.

---

## PR #59 / #60 / #61 — Merged

**Status:** All merged. #59 documentation reconciliation (`093fce7`);
#60 FR-PR-05 Contact Support `mailto:` flow (`8f72514`); #61 CI
PR-pipeline speed-up (`d474507`). The next feature PR is #62
(FR-HD-01/02 Home dashboard, in flight — see the section above).

---


## Sequencing rationale

After PR #43 both halves of the simplified-debts round-trip closed
end-to-end from the user's point of view. PR #44 then de-risked the
deploy path by retiring the Node 20 runtime + `firebase-functions`
6.x ahead of the 2026-10-31 cutoff. With 5 Cloud Functions live in
production (PR #36 trigger, PR #37 trigger + algorithm extension,
plus the original 3 from Sprint 1), the upgrade surface was
non-trivial; bundling Node-22 + `firebase-functions@7.x` into one
PR kept the rollback story atomic and the test surface bounded.

PR #45 then bundled two small hygiene streams into a single atomic
chore PR: (a) the `lookup-user-by-phone-number` rate-limit doc-path
fix at `functions/src/lookup-user-by-phone-number/function.ts:108`,
and (b) the three S4 items from the PR #38 QA sign-off Post-Merge
Cleanup Backlog. The 5 previously-skipped integration tests at
`functions/test/integration/lookup-user-by-phone-number.integration.test.ts`
are now active and exercise the rate-limit branch end-to-end in CI.

PR #46 then shipped FR-EX-06 (edit + soft-delete for friendship-
context expenses, mirroring SCR-22). The Expense Detail screen is
the natural viewing surface for the read-only row PR #42 rendered;
the bottom-sheet edit-mode reuses the PR #38 Add Expense layout
under an `isEditMode` controller path. The dedicated
`OBTConfirmationDialog` widget added in PR #46 is the reusable
confirmation primitive for every future destructive action.

PR #48 then closed the SCR-21 surface PR #38 had deferred —
receipt attachment for friendship-context expenses. Step 3 reuses
the Step 2 / bottom-sheet machinery; a new
`ReceiptStorageService` mirrors the existing repository pattern;
the `ImagePickerService` was extracted from `features/auth/data/`
to `lib/core/services/` so the expense feature can import it
without an auth → expenses dependency. The `storage.rules` predicate
for friendship-receipts ships with the matching defensive
group-receipts predicate (closes R7 + R8 in one shot).

PR #51 then closed the long-standing
`// TODO(FR-AC-01): write activity-feed item` hand-off seam at
`functions/src/triggers/on-expense-write/function.ts:160-169` —
the friendship-expense trigger now fans out an
`activity/{userId}/items/{auto-id}` document per friendship member
on every successful recompute (create / edit / soft-delete). The
new `firestore.rules` block at `match /activity/{userId}/items/{itemId}`
enforces member-read / server-only-write, the canonical posture
mirroring `simplifiedBalances`. The `activity-writer.ts` module
is reusable by the future settlement-trigger activity-emission
extension (paired with FR-AC-01 client read-side).

PR #52 picks up the highest-value backlog item per Sprint 2
velocity at the PR #52 kickoff. FR-AC-01 client (SCR-25) +
settlement-trigger activity emission is the natural next-feature
pairing — the read-side schema PR #51 wrote is the contract
FR-AC-01 reads, and the settlement-trigger half is needed for the
settlement leg of SCR-25 to render anything. The architect's call
at kickoff reflects the current priority signal.

PR #53 picks up FR-AC-03 + FR-AC-05 — the second natural P0 reader
of the FR-AC-01 in-app routing surface PR #52 shipped. FCM is the
cold-start signal (FR-AC-05) so the two stories pair naturally.

PR #56 picks up the OBTBottomNav shell — UX foundation chore
deferred since PR #52 §2.1. PR #55 shipped the LAST feature
(Notification Preferences sub-route under Profile) that owned its
own in-AppBar navigation entry, so every primary surface needed by
the bottom-nav tab cluster (Home / Friends / Groups / Activity /
Profile) now has a real screen waiting to be wired. The shell
ships with an `IndexedStack` interim (architect §2.1) — the
`go_router ShellRoute` ratified by `navigation-flow.md §4.4`
remains the long-term mechanism but is deferred to a Sprint 3
standalone chore that migrates every existing `Navigator.push`
call site. The shell is the canonical post-auth root from which
every Sprint 3 feature (Groups epic + FR-HD-01..04 home dashboard
+ FR-HD-04 persistent FAB) inherits.

PR #57 picks up FR-HD-04 (persistent FAB + Add Expense context
picker) as the natural pair with the OBTBottomNav shell PR #56 just
shipped. The shell exposes a `Scaffold.floatingActionButton` slot
ready for the design-system primitive; the FAB-tap → context-picker
funnel is the canonical Add Expense entry point now that every
primary surface inherits the shell. PR #57 also bundles the
`currentUserIdProvider` production-wiring closure that PR #56 left
behind in its `AuthenticatedWithProfile` arm: without the per-arm
`ProviderScope` override + the Riverpod 2.x
`dependencies: [currentUserIdProvider]` 2-character addition on
`friendsListProvider` + `activityFeedProvider`, both providers
threw `UnimplementedError` on first read in production. Natural
completion of PR #56 architect §2.1 reconciliation.

---

## Snapshot — Sprint 2 status at end of PR #58

| Metric | Value |
|---|---|
| PRs merged in Sprint 2 | 22 (#31, #32, #34, #35, #36, #37, #38, #41, #42, #43, #44, #45, #46, #48, #51, #52, #53, #54, #55, #56, #57, #58) |
| Story points delivered | 93 |
| Bucket-B items closed | 10 (R1, R2, R3, R5a, R7, R8, CV3, SR8, D5a, D5b). Remaining: 27 / 37. **PR #58 made zero Bucket-B progress** — the FR-SE-08 settlement-history screen was tracked as a P0 functional requirement (closes SRS row FR-SE-08), not as a Bucket-B item. |
| Critical Cross-PR Constraints | C-1 RESOLVED (chore #25 closed in PR #38) |
| Open `sprint-2-chore` issues | 14 (issues #47, #49, #50 remain open; PR #58 did not file any new issues) |
| Outstanding deadline-bound work | **None.** |
| Round-trip closures | **Simplified-debts WRITE round-trip closed in PR #43.** Expense lifecycle (create / edit / soft-delete) closed end-to-end on the friendship axis by PR #46. Receipt attachment surface closed by PR #48. Activity-feed WRITE-SIDE closed by PR #51; READ-SIDE closed by PR #52. FCM push-notification round-trip closed by PR #53. FR-SE-09 Send Reminder round-trip closed by PR #54. Notification preferences round-trip closed by PR #55 (server gate from PR #53 + client UI). Bottom-nav UX-foundation closed by PR #56. FR-HD-04 persistent FAB + Add Expense context picker closed by PR #57. **FR-SE-08 dedicated settlement-history surface (friendship axis) closed by PR #58** — the `/settle/history` screen is reachable from the Friend Detail "View Settlement History" link; the group axis is wired by the Sprint 3 Group Detail screen. |
