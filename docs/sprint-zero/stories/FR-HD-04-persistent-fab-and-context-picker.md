# FR-HD-04 — Persistent Add-Expense FAB + Context Picker

> Implementation-ready user story for the **first persistent
> Floating Action Button on the OneByTwo authenticated shell**, the
> design-system primitive `OBTFloatingActionButton`, the new
> `AddExpenseContextPickerSheet` (SCR-08), and the long-deferred
> production wiring of `currentUserIdProvider` from the auth gate.
> Ships the FAB in `Scaffold.floatingActionButton` of
> `AuthenticatedShell`, the context picker bottom sheet with Friends
> populated/empty/loading/error states + Groups "Coming in Sprint 3"
> stub row, the `FriendDetailScreen` FAB refactor to use the new
> primitive, the two pre-declared client telemetry events
> (`fab_tapped`, `expense_context_selected`), and the
> `ProviderScope` override in `lib/main.dart` that closes the
> `currentUserIdProvider` regression (currently throws
> `UnimplementedError` in production — Friends/Activity tabs crash
> on first tap until this PR ships).

---

## SRS Requirement ID(s)

- **FR-HD-04** (SRS section 4.8 — "A persistent floating action
  button shall allow adding a new expense from any primary tab";
  P0). This story closes the SRS row in full for v1.0.

## Relevant SRS Sections

- **Section 4.8** — Home Dashboard. FR-HD-04 row (P0).
- **Section 6.3** — Core screen list. SCR-08 is the Add Expense
  Entry Point (FAB action); the FAB is owned by the shell, and the
  context-selection step ships in this PR.
- **Section 5.10** — Observability. Two NEW client analytics events
  (`fab_tapped`, `expense_context_selected`), both PRE-DECLARED in
  `docs/design/07-technical/telemetry-plan.md §1.3` lines 88-89 —
  no telemetry-plan append required. PII guard per ADR-0013.
- **Section 13.1** — Flutter feature-first folder layout. NEW
  `OBTFloatingActionButton` primitive lands under `lib/core/widgets/`
  (canonical primitive home); the picker sheet lands under
  `lib/features/expenses/presentation/` (composite consumer).
- **Section 13.2** — Story format (this document).

## Relevant Design References

- `docs/design/02-design-system/components.md §3` — `OBTFloatingActionButton`
  spec: icon `Icons.add`, `backgroundColor: colorScheme.secondary`,
  `foregroundColor: Colors.white`, tooltip "Add new expense",
  semantic label "Add new expense", tap target 56×56 dp, always-
  active on primary tabs, `heroTag` default `'addExpenseFAB'` with
  constructor override.
- `docs/design/06-screen-specs/06-08-home-and-search.md` — SCR-08
  `FAB Action` section (§"Add Expense Entry Point (FAB Action)" at
  line 412+; FAB design contract at lines 443-447; per-tab telemetry
  at line 514).

## Priority

**P0.** FR-HD-04 is the single P0 row blocking the home-shell UX
contract. The bottom-nav shell (PR #56) ships the five-tab cluster
but has NO FAB slot wired; this PR is the FAB. Additionally, this
PR closes the **`currentUserIdProvider` production-wiring
regression** discovered during PR #56 verification — the provider
declared at `lib/features/friends/application/friends_list_provider.dart:15-21`
currently throws `UnimplementedError` because PR #56 did NOT add a
production override in `lib/main.dart`; the Friends tab (1) and
Activity tab (3) crash on first tap until this PR's `ProviderScope`
override lands.

## Story Points

**3.** Decomposes as:

- **1 SP** — `OBTFloatingActionButton` design-system primitive (per
  `docs/design/02-design-system/components.md §3`: icon `Icons.add`,
  `backgroundColor: colorScheme.secondary`, `foregroundColor:
  Colors.white`, tooltip "Add new expense", semantic label "Add new
  expense", tap target 56×56 dp, `heroTag` default `'addExpenseFAB'`
  with constructor override) + widget tests for render contract +
  hero-tag override + a11y semantics.
- **1 SP** — `AddExpenseContextPickerSheet` (Friends section with
  populated/empty/loading/error states; "Add your first friend"
  CTA; Retry button; Groups section single "Coming in Sprint 3"
  stub row; `expense_context_selected` telemetry on friend tap;
  informational snackbar + telemetry on Groups tap; full state-
  matrix widget tests).
- **1 SP** — `AuthenticatedShell` FAB integration (mount
  `OBTFloatingActionButton` in `Scaffold.floatingActionButton`; tap
  handler reads current tab index, fires `fab_tapped` with
  `source_tab` ∈ {home, friends, groups, activity, profile},
  opens the picker) + `currentUserIdProvider` production override
  in `lib/main.dart` driven from the `AuthenticatedWithProfile`
  auth state + `FriendDetailScreen` FAB refactor to consume
  `OBTFloatingActionButton` with `heroTag: 'friendDetailFab'`
  (preserves the existing `_openAddExpenseSheet` helper verbatim) +
  regression-guard widget test for the auth gate → shell wiring +
  boundary-contract grep extension over the 2 new files.

Pattern reuse precedents (no re-derivation needed):

- `lib/core/widgets/nav/obt_bottom_nav.dart` (PR #56) — design-
  system primitive blueprint: `core/widgets/` placement, leaf-
  component pattern, parameterised widget tests, accessibility
  semantics.
- `lib/features/shell/presentation/authenticated_shell.dart` (PR #56)
  — `Scaffold` host wired with `ConsumerStatefulWidget` +
  `_currentIndex` state + `OBTBottomNav.tabs` enumeration for
  telemetry labels.
- `lib/features/reminders/presentation/send_reminder_sheet.dart`
  (PR #54) — modal-bottom-sheet host blueprint with sealed-state
  rendering.
- `lib/features/friends/presentation/friends_list_screen.dart`
  (PR #36) — `friendsListProvider` consumption with populated/empty/
  loading/error `AsyncValue` pattern reused inside the picker's
  Friends section.
- `lib/features/friends/presentation/friend_detail_screen.dart`
  lines 188-200 — `_openAddExpenseSheet` helper, called UNCHANGED
  from the refactored FAB.

## Branch / PR Metadata

| Field | Value |
|---|---|
| **Branch** | `user/avtanshgupta/0611/fr-hd-04-persistent-fab` |
| **Base** | `main` at `e63ee5e` (PR #56 merged: `feat(shell): OBTBottomNav + authenticated tab shell`) |
| **Target PR** | #57 |
| **PR title (≤72 chars)** | `feat(shell): FR-HD-04 persistent FAB + add-expense context picker` |
| **Commit-title scope** | `shell` (single-token per CI title-lint `[a-z0-9_-]+`) |
| **Story SP** | 3 |

## Dependencies

This story builds on:

- **PR #56 (OBTBottomNav + AuthenticatedShell)** — `AuthenticatedShell`
  is the host into which `Scaffold.floatingActionButton:
  OBTFloatingActionButton(...)` is inserted. UNCHANGED at the
  IndexedStack / OBTBottomNav level; this PR adds ONE new field on
  the `Scaffold`.
- **PR #36 (FR-FR-03 friends-list)** — `friendsListProvider` is the
  data source consumed by the picker's Friends section. UNCHANGED;
  the picker is a fresh consumer.
- **PR #38 (FR-EX-01 expense creation)** — `AddExpenseBottomSheet`
  at `lib/features/expenses/presentation/add_expense_bottom_sheet.dart:29-58`
  is the destination of the friend-context path. UNCHANGED; the
  picker constructs it with the existing `({required friendshipId,
  required currentUserUid, required otherUserUid, initialExpense,
  initialExpenseId, super.key})` signature.
- **PR #10 / FR-AU-06 (profile setup)** — `AuthenticatedWithProfile`
  auth state carries the signed-in `uid` consumed by the
  `currentUserIdProvider` production override that lands in
  `lib/main.dart`.
- **PR #35 / FR-FR-04 (friend detail)** —
  `FriendDetailScreen.floatingActionButton` at lines 135-140 is the
  target for the `FloatingActionButton → OBTFloatingActionButton`
  refactor; `_openAddExpenseSheet` at lines 188-200 is preserved
  verbatim.

## GitHub Issue This Story Closes

**None.** FR-HD-04 is a P0 SRS row (section 4.8); no pre-existing
GitHub issue exists. The story is the source of truth.

## User Story

As an **authenticated user on any primary tab of the OneByTwo home
shell**,
I want **a persistent Add-Expense Floating Action Button that opens
a context picker letting me choose Friend or Group**,
so that **I can start adding an expense without first navigating
into a specific friend or group**.

## Preconditions

1. User is authenticated AND has completed profile setup
   (`AuthenticatedWithProfile(uid: String, user: UserModel)` state
   emitted by `authStateProvider` per FR-AU-06 / PR #10).
2. `AuthenticatedShell` (PR #56) is mounted at the root of the
   authenticated routing surface, with `OBTBottomNav` rendering the
   five primary tabs (Home, Friends, Groups, Activity, Profile).
3. `friendsListProvider` (PR #36) is functional and emits an
   `AsyncValue<List<FriendListItem>>` for the picker's Friends
   section.
4. `AddExpenseBottomSheet` (PR #38) constructor signature
   `({required friendshipId, required currentUserUid, required
   otherUserUid, initialExpense, initialExpenseId, super.key})`
   UNCHANGED.

---

## Acceptance Criteria

> 18 ACs grouped into 6 contractual buckets (FAB render +
> visibility contract; FAB → context picker flow; Context picker —
> Friends section; Context picker — Groups stub; `currentUserIdProvider`
> production-wiring regression closure; `FriendDetailScreen` FAB
> refactor; Cross-cutting and negative guards). Each AC is
> independently testable.

### FAB render + visibility contract

**AC-1 — Persistent FAB visible on every primary tab.** Given an
`AuthenticatedWithProfile` user lands on the shell, when the shell
mounts on any tab (0..4), then the `Scaffold.floatingActionButton`
is non-null AND of type `OBTFloatingActionButton` AND visible AND
tappable. Tested by parameterised widget test for i ∈ {0,1,2,3,4}.

**AC-2 — `OBTFloatingActionButton` design contract.** Icon `Icons.add`;
`backgroundColor: Theme.colorScheme.secondary`; `foregroundColor:
Colors.white`; semantic label "Add new expense"; tooltip "Add new
expense"; tap target ≥ 56 dp on both axes.

**AC-3 — Hero tag default + override.** Default `heroTag` ==
`'addExpenseFAB'`; constructed with `heroTag: 'friendDetailFab'`
then `heroTag` == `'friendDetailFab'`. `FriendDetailScreen`
refactor passes the explicit tag.

### FAB → context picker flow

**AC-4 — Tap FAB on Home tab.** Tap FAB on Home tab fires
`fab_tapped` with `source_tab: 'home'` AND opens the
`AddExpenseContextPickerSheet`.

**AC-5 — Tap FAB on each non-Home tab.** Tap FAB on each non-Home
tab fires `fab_tapped` with the corresponding `source_tab` ∈
{friends, groups, activity, profile}. 4 parameterised cases.

### Context picker — Friends section

**AC-6 — Populated state.** 3 friends → 3 `FriendListTile` rows in
provider order + "Groups" section with single "Coming in Sprint 3"
row.

**AC-7 — Tap friend row.** Tap friend row →
`expense_context_selected{context_type: 'friend'}` fires + picker
dismissed + `AddExpenseBottomSheet` mounts with `friendshipId ==
friend.friendshipId && currentUserUid == <current uid> &&
otherUserUid == friend.otherUserUid`.

**AC-8 — Empty state.** "You have no friends yet" + button "Add
your first friend" + Groups section still renders the "Coming in
Sprint 3" row.

**AC-9 — Tap "Add your first friend".** Tap "Add your first friend"
→ picker dismissed + `AddFriendScreen` is topmost route.

**AC-10 — Loading state.** `CircularProgressIndicator` in Friends
section + Groups section still renders the "Coming in Sprint 3"
row.

**AC-11 — Error state.** Error message + Retry button; tapping
Retry re-invalidates the provider.

### Context picker — Groups stub

**AC-12 — Tap Groups row.** Tap Groups row (any state — populated/
empty/loading/error) → `SnackBar` "Group expenses coming in Sprint
3." + `expense_context_selected{context_type: 'group'}` fires +
picker REMAINS mounted.

### `currentUserIdProvider` production-wiring regression closure

**AC-13 — Production override resolves to real UID.** Given auth
gate transitions to `AuthenticatedWithProfile(uid: 'uid-X')`, when
`AuthenticatedShell` is mounted, then `ref.read(currentUserIdProvider)`
returns `'uid-X'` (NOT throws `UnimplementedError`).

**AC-14 — Friends + Activity tabs no longer crash on tap.** Friends
tab (1) + Activity tab (3) no longer throw on tap. Regression-guard
widget test using `OneBytwoApp` + a `Stream.value(AuthenticatedWithProfile(uid:
'uid-X', user: ...))` auth-state override.

### `FriendDetailScreen` FAB refactor

**AC-15 — `FriendDetailScreen.floatingActionButton` contract.**
`FriendDetailScreen.floatingActionButton` is `OBTFloatingActionButton`
AND `heroTag == 'friendDetailFab'` AND `onPressed` opens the
existing `AddExpenseBottomSheet` via `_openAddExpenseSheet` (helper
at lines 188-200, UNCHANGED).

### Cross-cutting and negative guards

**AC-16 — Telemetry PII guard.** NEITHER `fab_tapped` NOR
`expense_context_selected` payload includes `userId` / `uid` /
`friendship_id` / `friendship_id_hash`. PII-leak grep extended with
the 2 new files.

**AC-17 — Invariant 1 boundary contract.** ZERO `.toDouble()`,
`parseFloat`, `/ 100`, `.toFixed`, or `double ` declarations in the
2 new files. Boundary-contract test extension is the affirmative
gate.

**AC-18 — Invariant 2 negative guard.** ZERO references to
`simplifiedBalances` in the 2 new files (picker READS
`friendsListProvider` which reads `simplifiedBalances`, but the
picker itself does not).

---

## Telemetry Contract (FR-HD-04 v1.0)

Two NEW client events. Both are **PRE-DECLARED** in
`docs/design/07-technical/telemetry-plan.md §1.3` lines 88-89 —
**no telemetry-plan edit is required in this PR**. This PR ships
the implementation that emits the already-declared events.

| Event | Trigger | Parameters | Types |
|---|---|---|---|
| `fab_tapped` | Every FAB tap, regardless of whether the user picks a context afterwards | `source_tab` | `string` ∈ {`home`, `friends`, `groups`, `activity`, `profile`} |
| `expense_context_selected` | **Friend path:** fires immediately BEFORE `AddExpenseBottomSheet` is opened. **Group path:** fires alongside the "Coming in Sprint 3" snackbar (picker stays mounted) | `context_type` | `string` ∈ {`friend`, `group`} |

**PII guard (ADR-0013):** Neither event carries a UID-derived
parameter. `source_tab` is a SAFE non-identifying enum (the five
primary-tab labels are not user-specific). `context_type` is a SAFE
non-identifying enum (the binary friend/group classifier is not
user-specific). **No hashing is required** because no hashable
identifiers are emitted. AC-16 asserts this defence-in-depth via
the PII-leak grep.

The constants live alongside the consuming code (canonical placement
per the architect's call in §2.3; PM recommendation: a single new
`lib/features/expenses/application/add_expense_telemetry.dart`
constants file scoped to the picker, mirroring
`lib/features/reminders/application/reminder_telemetry.dart`). The
shell + picker emit via the existing `analyticsServiceProvider`.

---

## Invariant Compliance

All four invariants are **N/A** to this surface; defence-in-depth
greps run on the 2 new files anyway to keep the negative guard
explicit per AC-17 / AC-18.

| Invariant | Applicability | How enforced |
|---|---|---|
| **1 — paise integers** | **N/A** | No monetary values flow through the FAB or the picker. The picker reads `friendsListProvider` which surfaces `FriendListItem` (already paise-int upstream); the picker hands `friendshipId` / UID strings only to `AddExpenseBottomSheet`. Defence-in-depth grep on the 2 new files asserts ZERO `.toDouble()` / `parseFloat` / `/100` / `.toFixed` / `double `-declaration matches (AC-17). |
| **2 — `simplifiedBalances` server-only** | **N/A** | The picker READS via `friendsListProvider` (which reads `simplifiedBalances` deeper in the pipeline) but the picker itself does NOT touch the field. Defence-in-depth grep on the 2 new files asserts ZERO `simplifiedBalances` references (AC-18). |
| **3 — system share sheet only** | **N/A** | No outbound sharing on this surface. |
| **4 — single Firebase project** | **N/A** | No new Firebase SDK usage. The `currentUserIdProvider` override consumes the existing `authStateProvider` (already pointing at the canonical Firebase app initialised at `lib/main.dart`); no new `Firebase.initializeApp` call. |

---

## Out of Scope

These are explicitly EXCLUDED to keep PR #57 surgical:

- **The full Add Expense flow (FR-EX-01 Step 1 / Step 2 / Step 3).**
  Already shipped in PR #38; the picker hands off to the existing
  `AddExpenseBottomSheet` UNCHANGED.
- **Real Group context path beyond the stub row.** The Groups
  section is a single "Coming in Sprint 3" row that fires the
  SnackBar + `expense_context_selected{context_type: 'group'}` and
  stays mounted. The real Groups flow ships with the Sprint 3
  Groups epic.
- **Contextual pre-fill from Friend / Group Detail screens (SCR-08
  §OQ-EX-02).** The site-map FAB is a global element; the
  `FriendDetailScreen` retains its OWN FAB (refactored to use the
  primitive but pre-filled with that friend's context). Cross-shell
  contextual pre-fill is a separate UX decision.
- **OBTRupeeText extraction.** Still deferred per PR #52 §2.6.
- **OBTBottomSheet extraction.** Still deferred per PR #38; the
  picker uses `showModalBottomSheet` inline per the existing
  pattern.
- **Home dashboard rendering (FR-HD-01 / FR-HD-02 / FR-HD-03).**
  `HomeDashboardPlaceholder` (PR #56) is the temporary Home tab;
  replaced by the real `HomeDashboardScreen` in a focused
  FR-HD-01..03 follow-up PR.
- **Search Overlay (SCR-07).** Separate P1 surface; depends on
  search-index design.
- **FCM cold-start deep-link to Add Expense.** Separate FR-AC-05
  surface; depends on Riverpod `Notifier<int>` for programmatic
  tab switching (deferred per PR #56 §2.2 until a second consumer
  needs it).
- **OAuth / SSO.** Not in v1.0 per SRS §12.3.

If an agent suggests bundling any of the above into PR #57, refuse
and cite this section.

---

## Architect-Call Sub-Questions (for Phase 2)

Enumerated for the architect agent to ratify in §2.1–§2.8 of the
forthcoming Architect Notes appendix:

- **§2.1 `OBTFloatingActionButton` file placement.** **PM
  recommendation:** `lib/core/widgets/fab/obt_floating_action_button.dart`
  — mirrors the per-component subfolder convention established by
  `lib/core/widgets/nav/obt_bottom_nav.dart` (PR #56). Single leaf
  component per file.
- **§2.2 `AddExpenseContextPickerSheet` file placement.** **PM
  recommendation:** `lib/features/expenses/presentation/add_expense_context_picker_sheet.dart`
  — composite consumer next to `add_expense_bottom_sheet.dart`.
  This is `expenses` territory, not `shell` (the shell only INVOKES
  the picker; the picker logic + state matrix belongs with the
  expense surface that owns the destination sheet).
- **§2.3 Telemetry constants placement.** **PM recommendation:** a
  new `lib/features/expenses/application/add_expense_telemetry.dart`
  file holding `fabTappedEvent`, `sourceTabParam`, the 5 source-tab
  string constants, `expenseContextSelectedEvent`, `contextTypeParam`,
  and the 2 context-type string constants. Mirror of
  `lib/features/reminders/application/reminder_telemetry.dart`.
- **§2.4 `currentUserIdProvider` production override mechanism.**
  **PM recommendation:** override in `lib/main.dart`'s root
  `ProviderScope` using a `Provider.overrideWith` that reads
  `authStateProvider` and exposes the `uid` field of
  `AuthenticatedWithProfile`. The override MUST throw with a clear
  message if the auth state is not `AuthenticatedWithProfile`
  (defence-in-depth: any consumer reading the provider outside the
  authenticated shell is a bug). Confirm whether the override
  belongs in `lib/main.dart` OR in a new `lib/features/shell/`
  helper.
- **§2.5 Picker dismiss-on-friend-tap timing.** **PM recommendation:**
  emit `expense_context_selected` FIRST, then `Navigator.pop` the
  picker, then `showModalBottomSheet(... AddExpenseBottomSheet)`.
  Avoids the race where the picker pops and the new sheet animates
  in simultaneously. Confirm with architect.
- **§2.6 Groups stub row visual.** **PM recommendation:** a single
  disabled-looking `ListTile` with leading group icon, title "Groups",
  trailing "Coming in Sprint 3" label, `onTap` fires the snackbar
  + telemetry (NOT navigate). The row is the ONE permanent item in
  the Groups section across all four Friends-section states.
- **§2.7 `FriendDetailScreen` FAB refactor surgical-diff scope.**
  **PM recommendation:** ONLY swap the `FloatingActionButton(...)`
  call at lines 135-140 with `OBTFloatingActionButton(heroTag:
  'friendDetailFab', onPressed: () => _openAddExpenseSheet(context))`.
  `_openAddExpenseSheet` (lines 188-200) UNCHANGED. The
  `friend_detail_screen_test.dart` widget test gets one new
  assertion for the primitive type + hero tag.
- **§2.8 Exhaustive files-to-touch list.** Per orchestrator §6, the
  architect MUST enumerate the full list verbatim in the Architect
  Notes appendix so QA can diff-check at review time. Anything
  outside the enumerated set is scope creep. **PM expectation
  (subject to architect override):**
  - NEW `lib/core/widgets/fab/obt_floating_action_button.dart`
  - NEW `lib/features/expenses/presentation/add_expense_context_picker_sheet.dart`
  - NEW `lib/features/expenses/application/add_expense_telemetry.dart`
  - MODIFY `lib/features/shell/presentation/authenticated_shell.dart`
    (add `floatingActionButton:` slot + tap handler)
  - MODIFY `lib/features/friends/presentation/friend_detail_screen.dart`
    (swap raw `FloatingActionButton` for `OBTFloatingActionButton`)
  - MODIFY `lib/main.dart` (add `currentUserIdProvider` override in
    the root `ProviderScope`)
  - NEW `test/core/widgets/fab/obt_floating_action_button_test.dart`
  - NEW `test/features/expenses/presentation/add_expense_context_picker_sheet_test.dart`
  - MODIFY `test/features/shell/presentation/authenticated_shell_test.dart`
    (parameterised AC-1 / AC-4 / AC-5 / AC-13 / AC-14 additions)
  - MODIFY `test/features/friends/presentation/friend_detail_screen_test.dart`
    (AC-15 addition)
  - MODIFY the existing PII-leak grep test + boundary-contract test
    files to include the 2 new files (AC-16 / AC-17 / AC-18)
  - **NOT touched:** `firestore.rules`, `firestore.indexes.json`,
    `storage.rules`, `functions/**`, `pubspec.yaml`,
    `docs/design/**`, `docs/OneByTwo_Requirements_Spec.md`,
    `docs/sprint-zero/sprint-2-plan.md`,
    `docs/sprint-zero/next-three-prs.md`,
    `docs/audits/sprint-1/07-bucket-b-burndown.md` (the latter
    three are Phase 5 roll-forward).

---

## Definition of Done

- All 18 ACs (AC-1 ... AC-18) satisfied with passing tests.
- Story (this file) present; Architect Notes appendix appended in
  Phase 2 — placeholder section below.
- Code merged (PR #57 squash-merged into `main` after green CI +
  QA sign-off).
- `dart format --set-exit-if-changed .` exits 0.
- `flutter analyze --fatal-infos` exits 0 ("No issues found").
- `flutter test` exits 0 with new tests for the FAB primitive +
  picker state matrix + shell FAB integration + `FriendDetailScreen`
  refactor + regression-guard.
- `cd functions && npm run lint && npm run build && npm test` exits 0
  (319 tests / 22 suites — **UNCHANGED**; zero Functions source
  changes in this PR).
- `cd functions && npm run test:rules` exits 0 (191 tests / 9
  suites — **UNCHANGED**; zero rules source changes in this PR).
- AC-16 PII-leak grep clean (no `userId` / `uid` / `friendship_id`
  / `friendship_id_hash` in `fab_tapped` or
  `expense_context_selected` event payloads, asserted against the 2
  new files).
- AC-17 Inv-1 negative-guard grep clean (zero `.toDouble()` /
  `parseFloat` / `/100` / `.toFixed` / `double `-declaration
  matches in the 2 new files).
- AC-18 Inv-2 negative-guard grep clean (zero `simplifiedBalances`
  references in the 2 new files).
- QA verified — cross-tab smoke matrix:
  - FAB visible + tappable on all 5 tabs (Home / Friends / Groups /
    Activity / Profile).
  - Picker Friends section: populated → tap friend → expense sheet
    opens with correct args.
  - Picker Friends section: empty → "Add your first friend" → routes
    to `AddFriendScreen`.
  - Picker Friends section: loading + error states render correctly;
    Retry re-invalidates.
  - Picker Groups stub row: snackbar fires, telemetry emitted,
    picker stays mounted across all four Friends-section states.
  - `FriendDetailScreen` FAB: refactor preserves the existing
    add-expense flow byte-for-byte at the destination.
  - Friends tab + Activity tab no longer crash on first tap
    (regression closure for `currentUserIdProvider`).
- Telemetry in place — both events PRE-DECLARED in
  `telemetry-plan.md §1.3` lines 88-89; this PR ships the emitters
  and asserts payload PII guard.
- Docs updated — Phase 5 roll-forward:
  - `docs/sprint-zero/sprint-2-plan.md` rolled forward with the
    PR #57 row (3 SP).
  - `docs/sprint-zero/next-three-prs.md` rolled forward (PR #57
    marked merged; PR #58 / #59 / #60 candidates per Phase 7).
  - `docs/audits/sprint-1/07-bucket-b-burndown.md` PR #57 entry
    appended.
- PR title scope is single-token (`shell`) and subject ≤ 72
  characters total. Suggested: `feat(shell): FR-HD-04 persistent
  FAB + add-expense context picker` (66 chars).
- PR body cites SCR-08 + `telemetry-plan.md §1.3` + the SRS row
  (FR-HD-04), confirms Invariants 1 / 2 / 3 / 4 (all N/A; defence-
  in-depth greps green per AC-17 / AC-18), enumerates the deferred
  items, and ends with `Next PR: PR #58 — TBD per architect's call
  at kickoff.`

---

## Follow-up Issues to File After Merge

The Phase 7 PM agent files (or notes in `next-three-prs.md`) the
following candidate issues once PR #57 is squash-merged:

1. **FR-HD-01 / FR-HD-02 / FR-HD-03 Home Dashboard real surface** —
   P0 + P0 + P1 trio; replaces `HomeDashboardPlaceholder` (PR #56)
   with the real screen rendering net balance + top-5 + monthly
   summary.
2. **Search Overlay (SCR-07)** — P1; depends on search-index
   design.
3. **OBTBottomSheet extraction** — cosmetic chore; needs a second
   non-AddExpense modal bottom-sheet consumer before extraction is
   justified.
4. **OBTRupeeText primitive extraction** — still deferred per
   PR #52 §2.6; needs a second non-friend-list consumer.
5. **Cross-shell contextual pre-fill from Friend/Group Detail FABs
   (SCR-08 §OQ-EX-02)** — UX decision pending; current spec keeps
   the Friend Detail FAB context-aware via the existing
   `_openAddExpenseSheet` helper.

These are tracked as candidates; the orchestrator decides which (if
any) are filed as GitHub issues at PR-#57 merge time.

---

## Architect Notes

*To be appended in Phase 2 by the architect agent.*
