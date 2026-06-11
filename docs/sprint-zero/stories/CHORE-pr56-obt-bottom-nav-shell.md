# CHORE — `OBTBottomNav` + `AuthenticatedShell`

> Implementation-ready chore story for the **bottom-nav UX foundation**
> that closes the long-deferred PR #52 §2.1 deferral. Ships the
> design-system primitive `OBTBottomNav` (per `components.md §2`), the
> `AuthenticatedShell` IndexedStack host that mounts the five primary
> tab-content widgets (Home dashboard placeholder, Friends list, Groups
> list placeholder, Activity feed, Profile screen), the
> `bottom_nav_tab_selected` telemetry event, and the `lib/main.dart`
> wire-change that swaps the temporary `HomePlaceholderScreen` for the
> shell. The temporary `HomePlaceholderScreen` (with its in-AppBar
> Activity / Profile shortcut buttons) is deleted in the same PR.

---

## SRS Requirement ID(s)

**None.** This PR is a **UX-foundation chore** — no SRS-functional-
requirement closes. The closure target is the design-system spec
`docs/design/02-design-system/components.md §2 OBTBottomNav` plus the
information-architecture spec `docs/design/01-information-architecture/navigation-flow.md §1`
(subgraph `MainTabs` lines 80-88 enumerates the five primary
destinations) and §4.4 "Bottom navigation shell" (lines 305-311).

The shell unblocks the v1.0 navigation contract for every primary
surface listed in SRS section 6.3 ("Home / Friends / Groups / Activity
/ Profile are the five primary screens") even though no individual SRS
FR is closed by this PR.

## Relevant SRS Sections

- **Section 6.3** — Core screen list. Five primary screens are
  enumerated; this PR ships the canonical entry point that lets users
  switch between them.
- **Section 5.10** — Observability. One new client analytics event
  (`bottom_nav_tab_selected`) is added under "Cross-Cutting Events"
  (`docs/design/07-technical/telemetry-plan.md §1.8`). PII guard per
  ADR-0013 — no UID-derived parameters.
- **Section 13.1** — Flutter feature-first folder layout. NEW
  `lib/features/shell/` feature folder lands; mirrors the existing
  per-feature `application/` + `presentation/` split.
- **Section 4.8** — FR-HD-01..04 home dashboard. NOT closed by this
  PR; the `HomeDashboardPlaceholder` ships under the Home tab and is
  replaced by the real `HomeDashboardScreen` in a focused FR-HD-01..04
  follow-up. The persistent FR-HD-04 FAB is OUT OF SCOPE for this PR.

## Priority

**P0 enabler / P1 chore.** Although no SRS-FR closes, the bottom-nav
shell is the **last UX foundation blocking the Sprint 3 Groups epic**:
every primary surface needed by the Groups epic (Home / Friends /
Groups / Activity / Profile) now has a real screen waiting to be wired
into the canonical tab cluster, and PR #55 shipped the last feature
(Notification Preferences sub-route) that owned its own in-AppBar
navigation entry.

## Story Points

**3.** Decomposes as:

- **1 SP** — `OBTBottomNav` design-system primitive (5 tabs,
  outlined/filled icon swap on selection, accessibility semantics, 48
  dp tap-target floor) + widget tests for render contract + tap
  callback + tab-definition constants.
- **1 SP** — `AuthenticatedShell` host (IndexedStack over 5 tab
  content widgets for tab-state preservation; in-shell `setState`
  navigation; PopScope snap-to-tab-0 on Android back; per-tap
  telemetry) + 2 placeholder screens (Home dashboard placeholder,
  Groups list placeholder) + shell telemetry constants + widget tests.
- **1 SP** — `lib/main.dart` wire change swapping
  `HomePlaceholderScreen` for `AuthenticatedShell` + deletion of the
  temporary `HomePlaceholderScreen` file + boundary-contract grep over
  the new `lib/features/shell/**` + `lib/core/widgets/nav/obt_bottom_nav.dart`
  files + telemetry-plan.md append + docs roll-ups.

Escalate to 5 SP only if the architect bundles the FR-HD-04 FAB
(persistent floating action button on every primary tab) wired to a
context-picker bottom sheet — RECOMMENDED defer; the Group path of the
context picker depends on the Sprint 3 Groups epic.

Patterns reused without re-derivation:

- `lib/core/widgets/inputs/obt_amount_input.dart` — design-system
  primitive folder + naming convention (`OBT*` prefix; sub-folder by
  category).
- `lib/features/reminders/application/reminder_telemetry.dart` and
  `lib/features/profile/application/notification_preferences_telemetry.dart`
  — telemetry constants file structure (event-name constants + param
  key constants; `abstract final class` or top-level `const String`
  declarations).
- `test/features/profile/notification_preferences_boundary_contract_test.dart`
  — boundary-contract grep template (Inv-1 + Inv-2 + PII-leak groups;
  per-file scan against a hard-coded constant list of NEW files).
- `lib/features/profile/presentation/profile_screen.dart` — tab-root
  widget pattern (`AppBar(automaticallyImplyLeading: false)` so no
  back arrow shows when the screen is mounted at the root of the
  shell's IndexedStack).

## Branch / PR Metadata

| Field | Value |
|---|---|
| **Branch** | `user/avtanshgupta/0611/obt-bottom-nav-shell` |
| **Base** | `main` at `ac5b05a` (PR #55 merged: FR-PR-03 + FR-AC-04 notification prefs UI) |
| **Target PR** | #56 |
| **PR title (51 chars)** | `feat(shell): OBTBottomNav + authenticated tab shell` |
| **Commit-title scope** | `shell` (the load-bearing surface — single-token per CI title-lint `[a-z0-9_-]+`) |
| **Story SP** | 3 |
| **Velocity after merge** | 87 SP across 20 PRs |

## Dependencies

This story builds on:

- **PR #10 (FR-AU-06)** — `HomePlaceholderScreen` exists at
  `lib/features/auth/presentation/home_placeholder_screen.dart` and is
  the file being replaced.
- **PR #29 (FR-PR-01 / SCR-26)** — `ProfileScreen` exists and is the
  tab 4 content widget. Owns its own `AppBar(title: const Text('Profile'),
  automaticallyImplyLeading: false)` — the canonical tab-root
  precedent.
- **PR #35 (FR-FR-03 / SCR-09)** — `FriendsListScreen` exists and is
  the tab 1 content widget. Owns its own AppBar.
- **PR #52 (FR-AC-01 / SCR-25)** — `ActivityFeedScreen` exists and is
  the tab 3 content widget. Owns its own AppBar. The PR #52 §2.1
  deferral named the bottom-nav shell as a follow-up; this PR is that
  follow-up.
- **PR #55 (FR-PR-03 + FR-AC-04)** — Notification Preferences
  sub-route under Profile lands; this was the LAST feature that owned
  an in-AppBar navigation entry. Every primary surface needed by the
  shell now exists.

## GitHub Issue This Story Closes

**None.** The OBTBottomNav shell deferral was tracked in
`next-three-prs.md` (PR #56 candidate list) and in PR #52's architect
§2.1, not as a separate GitHub issue. The story file IS the source of
truth.

## User Story

As a **signed-in user with a fully-shaped profile**,
I want **a persistent bottom navigation bar that lets me switch
instantly between the five primary surfaces (Home, Friends, Groups,
Activity, Profile)**,
so that **I can navigate the app without stacking redundant
`Navigator.push` routes, my scroll position and form state on each tab
are preserved across switches, and the Android back-button on a
non-Home tab returns me to Home rather than jarringly closing the
app**.

## Preconditions

1. User is authenticated AND has a fully-shaped Firestore user doc
   (the `AuthenticatedWithProfile` auth state). The shell is only
   mounted from this branch in `lib/main.dart`.
2. The five tab content widgets all exist and own their own AppBars
   (the shell does NOT inject an outer AppBar):
   - Tab 0 (Home): `HomeDashboardPlaceholder` (NEW — ships in this
     PR; extracted from `home_placeholder_screen.dart` body).
   - Tab 1 (Friends): `lib/features/friends/presentation/friends_list_screen.dart`
     (UNCHANGED).
   - Tab 2 (Groups): `GroupsListPlaceholder` (NEW — ships in this PR;
     `lib/features/groups/` is greenfield).
   - Tab 3 (Activity): `lib/features/activity/presentation/activity_feed_screen.dart`
     (UNCHANGED).
   - Tab 4 (Profile): `lib/features/profile/presentation/profile_screen.dart`
     (UNCHANGED).
3. `lib/core/widgets/` exists as the design-system primitive root
   (with sub-folders `inputs/`, `dialogs/`, `lists/`). The new
   `OBTBottomNav` ships under a NEW `nav/` sub-folder per the
   established sub-folder-by-category convention.
4. `flutter_riverpod` 2.x is wired in `lib/main.dart` (the shell is a
   `ConsumerStatefulWidget` so the per-tab telemetry call can read
   `analyticsServiceProvider`).

## Acceptance Criteria

> The 18 ACs below mirror the brief at `docs/copilot_prompts/sprint_2/19.md`
> Phase 1 lines 131-164. Every AC is testable; the test plan in the
> Architect Notes maps each AC to a specific test file.

### Shell render contract — positive ACs

- **AC-1 — Shell renders Home tab on initial mount.** Given an
  `AuthenticatedWithProfile` user lands on the shell, when the shell
  mounts, then `currentIndex` is 0, the Home tab is visually selected
  (filled `Icons.home` icon + `colorScheme.primary` label colour), the
  body renders `HomeDashboardPlaceholder` (Icon + "Home" headline +
  "The real dashboard is coming soon." copy), AND the `OBTBottomNav`
  is visible at the bottom of the `Scaffold`.
- **AC-2 — Tap Friends tab switches to FriendsListScreen.** Given the
  shell is rendered with `currentIndex: 0`, when the user taps the
  Friends tab (index 1), then `currentIndex` becomes 1, the Friends
  tab is visually selected, the body renders `FriendsListScreen`, AND
  a `bottom_nav_tab_selected` telemetry event fires with
  `{tab_index: 1, tab_label: "friends"}`.
- **AC-3 — Tap Groups tab renders the Groups placeholder.** Given the
  shell is on any tab, when the user taps Groups (index 2), then the
  body renders `GroupsListPlaceholder` (Icon + "Groups" headline +
  "Coming in Sprint 3" sub-copy), AND telemetry fires with
  `{tab_index: 2, tab_label: "groups"}`.
- **AC-4 — Tap Activity tab renders ActivityFeedScreen.** Given the
  shell is on any tab, when the user taps Activity (index 3), then
  the body renders `ActivityFeedScreen`, AND telemetry fires with
  `{tab_index: 3, tab_label: "activity"}`.
- **AC-5 — Tap Profile tab renders ProfileScreen.** Given the shell
  is on any tab, when the user taps Profile (index 4), then the body
  renders `ProfileScreen`, AND telemetry fires with
  `{tab_index: 4, tab_label: "profile"}`.
- **AC-6 — Tab state preservation via IndexedStack.** Given the user
  is on tab 1 (Friends), then switches to tab 4 (Profile), then back
  to tab 1, when the Friends tab re-renders, then the underlying
  widget's `State` instance is PRESERVED (the IndexedStack mounts
  every child once on construction; `setState` toggles `_currentIndex`
  but does NOT dispose the inactive children's state). The widget
  test asserts this with a stateful test harness widget that
  increments a counter on every `build`; switching tabs and back
  preserves the counter.

### `OBTBottomNav` design-system contract

- **AC-7 — `OBTBottomNav` renders 5 tabs with the spec-ratified
  labels and icons.** Given the widget is mounted with
  `currentIndex: 0`, when scanned, then 5 `BottomNavigationBarItem`
  entries are present with labels in order (Home, Friends, Groups,
  Activity, Profile), each tab has BOTH outlined (`activeIcon`'s
  outline pair) and filled icon variants, the active tab (index 0)
  shows the FILLED icon, the inactive tabs (1-4) show the OUTLINED
  icon, AND the active tab label uses
  `Theme.of(context).colorScheme.primary`.
- **AC-8 — Tapping a tab invokes `onTabSelected` with the correct
  index.** Given the widget is mounted with `currentIndex: 0` and an
  `onTabSelected` callback that records its arguments, when the user
  taps the Activity tab, then the callback fires exactly once with
  `3`. The same contract holds for taps on the active tab (Material's
  `BottomNavigationBar` re-fires the callback with the current
  index).
- **AC-9 — Minimum tap target is 48x48 dp per accessibility spec.**
  Given the widget is mounted in a `MaterialApp` at the
  test-environment default text scale, when each tab's tap region is
  measured, then each tap-target's rendered size is >= 48 dp in both
  axes (Material's `BottomNavigationBar` default sizing satisfies
  this; the widget test asserts via `tester.getSize`).
- **AC-10 — Active tab announces "Selected" via Semantics.** Given
  the widget is mounted with `currentIndex: 2`, when scanned via
  `tester.getSemantics(find.text('Groups'))`, then the semantics node
  carries `isSelected: true` (Material's default; the platform
  accessibility framework converts this to the spoken "Selected"
  suffix).

### Shell navigation + auth + back-button contract

- **AC-11 — Android back-button on non-zero tab snaps to tab 0.**
  Given the shell is on tab 3 (Activity), when the user invokes the
  Android back-button (`tester.binding.handlePopRoute()` in the
  widget test), then `currentIndex` becomes 0 (the Home tab is
  rendered) AND the underlying `Route` does NOT pop (the `PopScope`
  intercepts because `canPop: false` when `_currentIndex != 0`).
  Telemetry is NOT fired for the back-driven switch — this is a
  different user intent than a tab tap (architect §2.6 ratification).
- **AC-12 — Android back-button on tab 0 pops the shell (default
  behaviour).** Given the shell is on tab 0 (Home), when the user
  invokes the Android back-button, then the `PopScope`'s
  `canPop: true` lets the system handle the back gesture (the
  framework treats this as "pop the root route" — i.e. close the
  app).
- **AC-13 — Shell-internal `Navigator.push` stacks ON TOP of the
  bottom nav.** Given the user is on tab 4 (Profile) and taps the
  "Notification Preferences" row (SCR-26 -> SCR-27), when the SCR-27
  screen pushes via `MaterialPageRoute`, then the `OBTBottomNav` is
  HIDDEN (SCR-27's Scaffold paints over the entire screen — the
  existing `EditProfileScreen` precedent). When the user pops SCR-27,
  then the shell re-renders with `currentIndex: 4` and the bottom nav
  is visible again.

### `HomePlaceholderScreen` deletion

- **AC-14 — `HomePlaceholderScreen` is deleted from the codebase.**
  Given the PR diff, when scanned, then
  `lib/features/auth/presentation/home_placeholder_screen.dart` no
  longer exists, NO Dart file imports it, AND no orphaned test exists
  under `test/features/auth/home_placeholder_screen_test.dart` (Phase
  0 verified no such test existed pre-PR — the AC's second clause is
  vacuously true).

### Cross-cutting and negative guards

- **AC-15 — Telemetry PII guard.** Given the
  `bottom_nav_tab_selected` event fires, when its payload is scanned,
  then it contains EXACTLY `tab_index` (int) and `tab_label`
  (string), and does NOT contain `userId`, `uid`, `friendship_id`, or
  `friendship_id_hash` parameters. The PII-leak grep test at
  `test/features/shell/shell_boundary_contract_test.dart` asserts
  the absence of these string literals in the shell source files.
- **AC-16 — Invariant 1 boundary contract.** Given the PR diff, when
  scanned for `.toDouble()`, `parseFloat`, `/100`, `.toFixed`, or
  `double` declarations on the new files, then ZERO violations exist
  anywhere in `lib/features/shell/**` or
  `lib/core/widgets/nav/obt_bottom_nav.dart`. The new client-side
  grep at `test/features/shell/shell_boundary_contract_test.dart` is
  the affirmative gate.
- **AC-17 — Invariant 2 negative guard.** Given the PR diff, when
  scanned, then ZERO references to `simplifiedBalances` exist
  anywhere in the new files.
- **AC-18 — Shell does NOT inject an outer AppBar.** Given any tab is
  rendered inside the shell, when the widget tree is inspected, then
  the shell's `Scaffold` has `appBar: null` — each tab content widget
  owns its own AppBar. The negative widget test asserts this is
  true for all 5 tabs.

## Telemetry Contract

One NEW client event ships with this PR. It is NOT pre-declared in
`docs/design/07-technical/telemetry-plan.md` and so this PR appends a
new row under `§1.8 Cross-Cutting Events` (the bottom nav is genuinely
cross-cutting — visible on all 5 primary surfaces — so §1.8 is the
correct section per its own definition: "events not tied to a single
screen").

| Event Name | Parameters | Parameter Types | Trigger |
|---|---|---|---|
| `bottom_nav_tab_selected` | `tab_index`, `tab_label` | `int` (0..4), `string` (`home` / `friends` / `groups` / `activity` / `profile`) | User taps a tab in `OBTBottomNav`. Fires on EVERY tap (including taps on the active tab; Material's `BottomNavigationBar` re-fires the callback for active-tab taps). Does NOT fire on programmatic switches (Android back-button snap-to-zero is a programmatic switch — architect §2.6). |

PII guard per ADR-0013: the `tab_index` and `tab_label` parameters
are SAFE non-identifying tokens — no UID-derived parameters; no
hashing required.

## Invariant Compliance

| Invariant | Status | Notes |
|---|---|---|
| 1 (paise integers) | N/A | No monetary values flow through the shell, bottom-nav widget, or placeholder screens. Boundary-contract grep at `test/features/shell/shell_boundary_contract_test.dart` is defence-in-depth. |
| 2 (`simplifiedBalances` server-only) | N/A | No `simplifiedBalances` access on any new code path. Defence-in-depth grep covers. |
| 3 (system share sheet) | N/A | No share-sheet code paths. |
| 4 (single Firebase project) | N/A | No new Firebase SDK usage. The shell mounts existing Riverpod-backed widgets that consume the existing Firebase initialisation from `lib/main.dart`. |

## Files Touched (exhaustive)

NEW (8 files):

- `docs/sprint-zero/stories/CHORE-pr56-obt-bottom-nav-shell.md` (this
  file)
- `lib/features/shell/application/shell_telemetry.dart` (event +
  param key constants)
- `lib/features/shell/presentation/authenticated_shell.dart`
  (`ConsumerStatefulWidget` with IndexedStack + PopScope + telemetry)
- `lib/features/shell/presentation/home_dashboard_placeholder.dart`
  (Tab 0 content — extracted from `home_placeholder_screen.dart` body)
- `lib/features/shell/presentation/groups_list_placeholder.dart`
  (Tab 2 content — Coming in Sprint 3)
- `lib/core/widgets/nav/obt_bottom_nav.dart` (design-system primitive)
- `test/features/shell/authenticated_shell_test.dart` (widget tests)
- `test/features/shell/shell_boundary_contract_test.dart` (Inv-1 +
  Inv-2 + PII-leak grep)
- `test/core/widgets/nav/obt_bottom_nav_test.dart` (design-system
  widget tests)
- `test/features/shell/shell_telemetry_test.dart` (constants contract)

MODIFY (4 files):

- `lib/main.dart` — replace `HomePlaceholderScreen` import + line-133
  switch arm with `AuthenticatedShell`
- `docs/design/07-technical/telemetry-plan.md` — append
  `bottom_nav_tab_selected` row under §1.8 Cross-Cutting Events
- `docs/sprint-zero/sprint-2-plan.md` — PR #56 status (merged), 87 SP
  across 20 PRs
- `docs/sprint-zero/next-three-prs.md` — roll PR #56 to merged; refresh
  PR #57 / #58 / #59 candidates
- `docs/audits/sprint-1/07-bucket-b-burndown.md` — PR #56 entry; closes
  PR #52 §2.1 OBTBottomNav deferral

DELETE (1 file):

- `lib/features/auth/presentation/home_placeholder_screen.dart`
  (superseded — body content extracted to
  `HomeDashboardPlaceholder`; AppBar shortcut buttons are obsoleted
  by the bottom nav)

## Out-of-Scope (deferred follow-ups)

- **FR-HD-01..04 home dashboard implementation** (separate P0 story;
  ~5-8 SP; requires a `home_balance_summary` aggregator + donut/bar
  chart widget).
- **FR-HD-04 persistent FAB** (separate P0 story; ~2 SP if Group path
  stubbed with "Coming soon", else blocked on Sprint 3 Groups epic).
- **`go_router` migration** (Sprint 3 standalone chore ~3-5 SP per
  `navigation-flow.md §4.4`).
- **Groups feature implementation** (Sprint 3 epic).
- **`shellNavigationControllerProvider`** (programmatic tab-switching
  for FR-AC-05 cold-start deep-link expansion; defer to follow-up).
- **`profile_placeholder_screen.dart` cleanup** (separate chore;
  not bundled per the precedent of touching only files this PR
  directly modifies).
- **Material 3 `NavigationBar` migration** (replacing
  `BottomNavigationBar`; separate design call).
- **Indicator-pill behind active icon** (the design spec's pill is a
  `NavigationBar` feature, not `BottomNavigationBar`; ship without
  for v1.0 per architect §2.10 reconciliation 4).
