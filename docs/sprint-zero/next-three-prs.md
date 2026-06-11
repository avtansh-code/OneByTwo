# Next Three PRs

> Rolling roadmap. Updated at the end of every PR.
> Last updated: PR #57 merged (FR-HD-04 persistent FAB + Add Expense context picker — closes FR-HD-04 P0 + bundled `currentUserIdProvider` production-wiring closure that PR #56 architect §2.1 left as the mandatory natural completion).

---

## GitHub issue / PR numbering note (post-PR #55)

The numbering jumped because issues and PRs share the same sequential
namespace on GitHub. The post-PR #48 sequence so far:

| Number | Type | What |
|---|---|---|
| #46 | PR | FR-EX-06 edit / delete expense, friendship context (merged 2026-06-07) |
| #47 | Issue | Firestore rules-hardening for non-creator update/delete (OPEN — Sprint 3 hardening) |
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
| **#58** | **PR** | **Next feature/chore PR — see below** |

The "Next three PRs" below refer to the next three FEATURE/CHORE
**pull requests** — i.e. PR #58, PR #59, PR #60. Their issue-number
counterparts (when filed) will consume intermediate numbers; the
orchestrator should not assume PR #58 = number 58 on GitHub.

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

## PR #58 — TBD

**Status:** Next up. Architect picks at PR #58 kickoff per Sprint 2 velocity.

PR #57 shipped the FR-HD-04 persistent FAB + Add Expense context
picker plus the bundled `currentUserIdProvider` production-wiring
closure. The shell now has its canonical primary-action FAB and the
two providers it depends on (`friendsListProvider`,
`activityFeedProvider`) are correctly wired in production. The FAB
is the natural seam that the FR-HD-01..04 home-dashboard work and
the Sprint 3 Groups epic will inherit.

Candidates (in rough priority order — architect's call at kickoff):

- **FR-SE-08 dedicated full-history settlement screen** at
  `/settlements/history` (P0 — PR #42's in-timeline rows satisfy
  v1.0 functionally but the dedicated screen is still a v1.0
  commitment). Natural pairing with the shell + FAB that PR #56 +
  PR #57 just shipped because the shared nav surface makes the
  "All settlements" deep-link target obvious. ~3-5 SP. **Highest-
  priority follow-up; top candidate for PR #58.**
- **FR-PR-05 Contact Support `mailto:` flow** (P0; depends on
  Remote Config wiring for the support email address; small
  standalone PR ~2 SP). Closes the last P0 line item on the
  Profile screen.
- **`app_settings` / `permission_handler` dependency +
  AC-11 "Open Settings" CTA wiring (surfaced by PR #55 QA).**
  ~1-2 SP. Adds the dependency + wires the CTA on both platforms.
  Natural pair with `shared_preferences` adoption below.
- **FR-PR-02 phone-number-change flow** (P1; depends on the
  existing OTP re-verification flow; medium PR ~5 SP).
- **FR-AU-09 account-deletion flow** (P1; depends on a new
  Cloud Function for cascade-delete fan-out; medium PR ~5-8 SP).
- **Bucket-B chore close-out** (single ~3 SP PR closing #20 CV3,
  #21 R1-R4, #23 PY3 partial with comments — see
  `docs/sprint-zero/sprint-2-plan.md` §"Issue closure candidates").
- **Issue #47 rules-hardening for non-creator update/delete gate**
  (operational hardening; small standalone PR ~2 SP). Closes the
  defence-in-depth gap that the FR-EX-06 architect §2.9 item 5
  documented.
- **`shared_preferences` adoption** for cross-launch persistence
  (PR #53 §2.6 `wasPermanentlyDenied` flag + FR-SE-09 §2.6 cooldown
  persistence). ~2-3 SP. Natural pair with the `app_settings` /
  `permission_handler` chore above.
- **FR-HD-01..04 home dashboard implementation** (P0; the
  `HomeDashboardPlaceholder` shipped by PR #56 is replaced by the
  real dashboard; FR-HD-04 persistent FAB shipped in PR #57 means
  the dashboard inherits the FAB-context-picker pair for free).
  ~5-8 SP.
- **FR-SE-09 message-compose dialog follow-up** (the deferred UX
  PR per FR-SE-09 architect §2.5). 1-2 SP.
- **`shellNavigationControllerProvider` + FR-AC-05 deep-link
  tab-switching expansion** (follow-up to PR #56; ~2 SP). The FCM
  cold-start handler currently lands on the activity feed via
  `MaterialPageRoute.push`; a future expansion can land on a
  SPECIFIC tab (0..4) using a Riverpod `Notifier<int>` controller
  read by the shell. Defer until a concrete second consumer (this
  expansion IS the second consumer).
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

## PR #59 — TBD

**Status:** Slot reserved. Architect picks at PR #58 kickoff.

Candidates: whatever doesn't land in PR #58 from the list above.

---

## PR #60 — TBD

**Status:** Slot reserved. Architect picks at PR #59 kickoff.

Candidates: whatever doesn't land in PR #58 / PR #59 from the list above.

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

## Snapshot — Sprint 2 status at end of PR #57

| Metric | Value |
|---|---|
| PRs merged in Sprint 2 | 21 (#31, #32, #34, #35, #36, #37, #38, #41, #42, #43, #44, #45, #46, #48, #51, #52, #53, #54, #55, #56, #57) |
| Story points delivered | 90 |
| Bucket-B items closed | 10 (R1, R2, R3, R5a, R7, R8, CV3, SR8, D5a, D5b). Remaining: 27 / 37. **PR #57 made zero Bucket-B progress** — the FR-HD-04 FAB + context picker work was tracked as a P0 functional requirement (closes SRS row FR-HD-04), not as a Bucket-B item; the bundled `currentUserIdProvider` production-wiring closure was tracked in `next-three-prs.md` as a PR #56 reconciliation discovery, not as a Bucket-B item. |
| Critical Cross-PR Constraints | C-1 RESOLVED (chore #25 closed in PR #38) |
| Open `sprint-2-chore` issues | 14 (issues #47, #49, #50 remain open; PR #57 did not file any new issues) |
| Outstanding deadline-bound work | **None.** |
| Round-trip closures | **Simplified-debts WRITE round-trip closed in PR #43.** Expense lifecycle (create / edit / soft-delete) closed end-to-end on the friendship axis by PR #46. Receipt attachment surface closed by PR #48. Activity-feed WRITE-SIDE closed by PR #51; READ-SIDE closed by PR #52. FCM push-notification round-trip closed by PR #53. FR-SE-09 Send Reminder round-trip closed by PR #54. Notification preferences round-trip closed by PR #55 (server gate from PR #53 + client UI). Bottom-nav UX-foundation closed by PR #56. **FR-HD-04 persistent FAB + Add Expense context picker closed by PR #57** — the shell exposes its canonical primary-action FAB and the Add Expense funnel is reachable from any tab; the bundled `currentUserIdProvider` production-wiring closure restores `friendsListProvider` + `activityFeedProvider` to functional state in production. |
