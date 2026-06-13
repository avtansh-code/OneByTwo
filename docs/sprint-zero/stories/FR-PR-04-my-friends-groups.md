# FR-PR-04 — "My Friends" / "My Groups" from Profile (SCR-26)

> Implementation-ready user story for the **live "My Friends" count + Friends-tab
> navigation** and the **"My Groups" stub count + Groups-tab navigation** on the
> Profile screen (SCR-26 Stats section), replacing the two hardcoded `'0'` +
> "Coming soon" snackbar stubs shipped with FR-PR-01. 100% client-side and
> read-only: the friend count composes the existing `friendsListProvider` via a
> new derived `friendCountProvider`; tab navigation is driven by a new
> `shellNavigationControllerProvider` (a Riverpod `Notifier<int>` that replaces
> the in-shell `setState(_currentIndex)`). No new data layer, no
> schema/rules/index/function change, no new Flutter plugin.

---

## SRS Requirement ID(s)

- **FR-PR-04** (SRS section 4.2, line 177, **P0**) — users shall be able to view a
  list of all friends and groups they are part of from their profile. The Profile
  Stats section surfaces a live **"My Friends" count** whose row navigates to the
  Friends tab (index 1), and a **"My Groups" count** whose row navigates to the
  Groups tab (index 2).

## Relevant SRS Sections

- **Section 4.2** — Profile Management. FR-PR-04 (P0).
- **Section 5.10** — Observability. Two new client analytics events
  (`profile_friends_tapped`, `profile_groups_tapped`). PII guard per the
  parameter-key convention (no UID-derived parameters).
- **Section 6.4 / 6.5** — Error and empty-state taxonomy (the count read-error
  projection renders an em dash, never a crash).
- **Section 7.3 / 7.5** — Integer paise; `simplifiedBalances` server-maintained,
  client-read-only. (No monetary surface here — counts only — but the friend
  count reads `friendsListProvider`, which projects `simplifiedBalances` deeper in
  the pipeline; this story is READ-ONLY.)
- **Section 13.1** — Flutter feature-first folder layout.

## Relevant Design References

- `docs/design/06-screen-specs/23-28-settle-activity-profile.md` §SCR-26
  (authoritative: Stats-section row contract, "Leads to" → Friends List tab
  index 1 / Groups List tab index 2, accessibility table, telemetry table).
- `docs/design/05-mockups/08-profile-with-support.html`.
- `docs/design/04-wireframes/profile-and-support.md`.

## Priority

**P0.** FR-PR-04 is the **last open P0 functional requirement** in Sprint 2 — it
outranks every remaining P1 (FR-PR-02 phone-change, FR-AU-09 account-deletion,
FR-HD-03 chart) and every chore. It was omitted from the `next-three-prs.md`
carry-forward candidate list (the FR-HD-01/02 kickoff called FR-HD "the last open
P0 product surface"); this story corrects that omission. It removes a live
"Coming soon" stub on an already-shipped surface (exactly as FR-HD-01/02 removed
the Home placeholder) and is the concrete second consumer that finally introduces
`shellNavigationControllerProvider`.

## Story

**As** a One By Two user on my Profile screen,
**I want** to see how many friends (and groups) I have and tap straight through to
the full list,
**so that** I can review and reach my friends and groups from one place without
hunting through the bottom-nav tabs.

## Preconditions

- The user is authenticated and has completed profile setup (the authenticated
  shell is mounted; `currentUserIdProvider` is bound to the signed-in UID by the
  per-arm `ProviderScope` in `lib/main.dart`).
- The friendship balance axis exists: `friendsListProvider`
  (`lib/features/friends/application/friends_list_provider.dart`) yields
  `List<FriendListItem>`; the "My Friends" count is `items.length`.
- Groups are **not** implemented (Sprint 3 epic). `lib/features/groups/` is
  README-only; the Groups tab is a `GroupsListPlaceholder`. The "My Groups" count
  is therefore stubbed at `0`.

## Acceptance Criteria

### AC-1 — Live friend count, populated (FR-PR-04)

**Given** the signed-in user has N friendships (N > 0)
**When** the Profile screen resolves
**Then** the "My Friends" row trailing shows the integer `N` (sourced from
`friendCountProvider`, i.e. `friendsListProvider` items' `.length`), with the
accessibility label `"My Friends, N, button"`.

### AC-2 — Friend count, empty (FR-PR-04)

**Given** the user has zero friendships
**When** the Profile screen resolves
**Then** the "My Friends" row shows `0` with the label `"My Friends, 0, button"`.

### AC-3 — Friend count, loading (FR-PR-04)

**Given** the first `friendsListProvider` Firestore snapshot has not yet resolved
**When** the Profile screen is shown
**Then** the "My Friends" row trailing shows a non-numeric loading affordance (em
dash `—`) instead of a count, and the row does not crash or block the rest of the
screen.

### AC-4 — Friend count, read error (FR-PR-04) — **negative case**

**Given** the `friendsListProvider` stream emits an error (a Firestore read
failure)
**When** the Profile screen resolves
**Then** the "My Friends" row trailing renders an em dash `—` (NOT a crash, NOT an
error dialog, NOT a `0` that would misrepresent the data), the rest of the Profile
screen renders normally, and the row remains tappable.

### AC-5 — "My Friends" row navigates to the Friends tab (FR-PR-04)

**Given** any "My Friends" row state
**When** the user taps the row
**Then** the authenticated shell switches to the **Friends tab (index 1)** via
`shellNavigationControllerProvider.selectTab(1)` — the IndexedStack index becomes
1 and the bottom-nav selected index becomes 1, preserving the Friends tab's
existing state (no `Navigator.push` of a duplicate `FriendsListScreen`) — and
`profile_friends_tapped` is emitted.

### AC-6 — "My Groups" row stub + navigation (FR-PR-04)

**Given** the Profile screen is populated
**Then** the "My Groups" row shows the stub count `0` with the label
`"My Groups, 0, button"`; **when** the user taps it, the shell switches to the
**Groups tab (index 2)** (`selectTab(2)`, the existing `GroupsListPlaceholder`)
and `profile_groups_tapped` is emitted. No real group data is read or rendered
(Sprint 3).

### AC-7 — `bottom_nav_tab_selected` is NOT fired by programmatic switches

**Given** the user taps "My Friends" (or "My Groups", or the Android back button)
**Then** the cross-tab switch occurs WITHOUT emitting `bottom_nav_tab_selected` —
that event remains reserved for user taps on the bottom-nav bar itself. The
Profile rows emit only `profile_friends_tapped` / `profile_groups_tapped`.

### AC-8 — Shell behaviour preserved through the refactor

**Given** the `AuthenticatedShell` now reads its active index from
`shellNavigationControllerProvider`
**Then** every prior shell behaviour is unchanged: tapping a bottom-nav tab fires
`bottom_nav_tab_selected` with `{tab_index, tab_label}` and switches tabs; the
Android back button on a non-zero tab snaps to tab 0 **without** telemetry; the
persistent Add-Expense FAB is present on every tab and its `fab_tapped`
`source_tab` reflects the active tab; the `@visibleForTesting tabContentOverride`
still injects stub tabs; the shell Scaffold has `appBar: null`.

### AC-9 — No PII in telemetry

`profile_friends_tapped` and `profile_groups_tapped` carry **no** UID-derived,
name, photo-URL, or phone-number parameter (they are emitted parameter-free, like
`profile_viewed` / `sign_out_completed`). A friend count is a non-identifying
integer.

### AC-10 — Invariants 2 and 4

The friend count is a READ-ONLY projection over `friendsListProvider` (which reads
the server-maintained `simplifiedBalances`); nothing in this story writes
`simplifiedBalances` (Invariant 2). No second Firebase project is introduced
(Invariant 4). No new Flutter plugin → no `ios/Podfile.lock` change.

## Definition of Done

- [ ] `friendCountProvider` (`lib/features/profile/application/`) derived from
      `friendsListProvider` with `dependencies: [friendsListProvider]`; unit tests
      for data / empty(0) / loading / error sub-states.
- [ ] `shellNavigationControllerProvider`
      (`lib/features/shell/application/shell_navigation_controller.dart`) — a
      `Notifier<int>` exposing `selectTab(int)`; `AuthenticatedShell` refactored
      to read/write it; shell tests for the controller-driven switch +
      programmatic-switch-without-telemetry.
- [ ] Profile "My Friends" / "My Groups" rows rewired: live count + sub-states,
      `selectTab(1)` / `selectTab(2)`, group stub `0`, two telemetry events;
      hardcoded `'0'` + "Coming soon" snackbar removed; SCR-26 a11y labels
      preserved with the live count.
- [ ] `profile_stats_telemetry.dart` with the two PII-free events;
      `docs/design/07-technical/telemetry-plan.md` §1.7 updated to pre-declare
      them.
- [ ] Widget tests: count rendering per sub-state, friends-row → tab 1,
      groups-row → tab 2, telemetry, no-PII. Existing shell + auth-gate suites
      stay green.
- [ ] Per-feature coverage ≥ 70%; `flutter analyze --fatal-infos` and
      `dart format` clean.
- [ ] Zero schema / rules / index / Cloud Function change; no new Flutter plugin
      (no `ios/Podfile.lock` change).

---

## Architect Notes

> Confirmed at kickoff: FR-PR-04 is the next-slot pick (**P0**, the last open P0
> functional requirement; corrects the `23.md` / candidate-list omission). Zero
> schema, security-rule, index, or Cloud Function changes; this is a pure
> read-side composition plus a contained shell-state refactor. No new ADR — the
> design closes the deferral recorded in the PR #56 shell story Architect Notes
> §2.2, so it is documented here as Architect Notes (the FR-HD-01/02 precedent).

### §1 — `friendCountProvider` (composition, no new data layer)

One pure reducer in
`lib/features/profile/application/friend_count_provider.dart`:

```dart
final friendCountProvider = Provider<AsyncValue<int>>((ref) {
  final friendsAsync = ref.watch(friendsListProvider);
  return friendsAsync.whenData((items) => items.length);
}, dependencies: [friendsListProvider]);
```

- **Scoping (Riverpod 2.x) — load-bearing.** `friendsListProvider` is itself
  scoped (`dependencies: [currentUserIdProvider]`, overridden per-arm in
  `lib/main.dart`). Any provider that watches it MUST declare
  `dependencies: [friendsListProvider]` to propagate that scoping — omitting it
  throws the Riverpod "tried to read … but specified a 'dependencies' list"
  assertion at first read. This is the exact rule established by the FR-HD-01/02
  `overallNetBalanceProvider` / `topBalancesProvider`
  (`lib/features/home/application/home_balances_providers.dart`).
- **Four async sub-states**, rendered on the row trailing (NOT a full-screen
  state — the Profile screen's own loading/error states are driven by
  `authStateNotifierProvider`, unchanged):
  - `AsyncLoading` → em dash `—`.
  - `AsyncData(n)` → the integer `n` (including `0` for the empty case).
  - `AsyncError` → em dash `—` (defensive: a count read failure must never crash
    the Profile screen or block sign-out; SRS §6.4).

### §2 — `shellNavigationControllerProvider` (the architectural first)

Today `AuthenticatedShell` owns the active tab as a plain in-shell
`int _currentIndex` mutated by `setState` (PR #56 shell story Architect Notes
§2.2 deferred a Riverpod `Notifier<int>` "until a second consumer needs it").
**FR-PR-04 is that second consumer.**

New `lib/features/shell/application/shell_navigation_controller.dart`:

```dart
final shellNavigationControllerProvider =
    NotifierProvider.autoDispose<ShellNavigationController, int>(
  ShellNavigationController.new,
);

class ShellNavigationController extends AutoDisposeNotifier<int> {
  @override
  int build() => 0; // Home tab on first mount.

  /// Programmatically select a primary tab. Out-of-range indices are
  /// ignored. Does NOT emit telemetry — `bottom_nav_tab_selected` is
  /// emitted only by the shell's user-tap handler (architect §2.6 of the
  /// PR #56 story).
  void selectTab(int index) {
    if (index < 0 || index >= OBTBottomNav.tabs.length) return;
    state = index;
  }
}
```

- **Root-scoping (no `dependencies` list).** The controller watches no scoped
  provider, so it lives at the root container and needs no `dependencies`
  declaration. Both the shell and Profile read the same instance: the shell is
  mounted inside the per-arm `ProviderScope` (which only overrides
  `currentUserIdProvider`), and Profile is a descendant of the shell — neither
  overrides `shellNavigationControllerProvider`, so both resolve to the single
  root instance. **Do not** add it to any per-arm `ProviderScope` override list.
- **`autoDispose` for session-reset.** The shell `ref.watch`es the controller, so
  it stays alive for the shell's lifetime. On sign-out the shell unmounts → the
  last watcher drops → the provider auto-disposes → a fresh sign-in rebuilds it at
  `0` (Home). This reproduces the current "every fresh shell mounts on tab 0"
  behaviour exactly, with no `dispose()`-time `ref` access (which Riverpod
  discourages). The deferred FR-AC-05 deep-link consumer can later set the tab
  before mount; that is out of scope here (see §5).
- **`AuthenticatedShell` refactor** (`presentation/authenticated_shell.dart`):
  - `build()` reads `final index = ref.watch(shellNavigationControllerProvider);`
    and uses it for `IndexedStack.index`, `OBTBottomNav.currentIndex`, and
    `PopScope.canPop (index == 0)`.
  - `_onTabSelected(int i)` (the bottom-nav callback) KEEPS its bounds guard and
    its `bottom_nav_tab_selected` telemetry emission, then calls
    `ref.read(shellNavigationControllerProvider.notifier).selectTab(i)` instead of
    `setState`.
  - `PopScope.onPopInvokedWithResult` calls
    `ref.read(shellNavigationControllerProvider.notifier).selectTab(0)` directly
    (bypassing `_onTabSelected`) → snap-to-tab-0 with **no** telemetry, preserving
    the existing contract.
  - `_onFabTapped` reads the active index from
    `ref.read(shellNavigationControllerProvider)` (not `_currentIndex`) for the
    `source_tab` token.
  - Remove the `int _currentIndex` field. The `late final _tabContent`
    memoisation and `tabContentOverride` are unchanged.

### §3 — Profile rewire (`presentation/profile_screen.dart`)

- The two `_ProfileRow` Stats usages (the hardcoded `'0'` + "Coming soon"
  snackbar `onTap`) are replaced:
  - **My Friends:** trailing renders the `friendCountProvider` sub-state (`—` /
    integer / `—`); `onTap` fires `profile_friends_tapped` (fire-and-forget, no
    `await`) then `ref.read(shellNavigationControllerProvider.notifier)
    .selectTab(1)`. Semantic label `"My Friends, $count, button"` when data, else
    `"My Friends, button"`.
  - **My Groups:** trailing renders the literal `0`; `onTap` fires
    `profile_groups_tapped` then `selectTab(2)`. Semantic label
    `"My Groups, 0, button"`.
- The `_ProfileRow` private widget (56 dp height, leading icon, trailing) is
  reused verbatim — **no** `OBTProfileStatRow` design-system extraction (the
  carry-forward list defers `OBT*` extractions "until a second use site").
- `_buildPopulatedState` already receives the `WidgetRef ref`; read
  `ref.watch(friendCountProvider)` there to drive the friends-row trailing.

### §4 — Group axis stub (Sprint 3 seam)

Groups are README-only. The "My Groups" count is the literal `0`; the row
navigates to tab 2 (the existing `GroupsListPlaceholder`) for SCR-26 "tab index 2"
spec fidelity. No `group_list_provider`, no real count — the same stub discipline
used by FR-HD-02 (#62), FR-SE-08 (#58), and FR-HD-04 (#57). The Sprint 3 Groups
epic swaps the literal `0` for a real `groupCountProvider` without changing the
row or navigation contract.

### §5 — Telemetry payloads (PII-free) and the deferred deep-link seam

- Two events in
  `lib/features/profile/application/profile_stats_telemetry.dart`
  (`abstract final class ProfileStatsTelemetry`): `profile_friends_tapped`,
  `profile_groups_tapped`. **Parameter-free** — a friend count is a
  non-identifying integer, so no payload, no hashing
  (`event_id_hash.dart` not needed). Pre-declared in `telemetry-plan.md` §1.7.
- **FR-AC-05 cold-start deep-link tab switching — DEFERRED.** The FCM cold-start
  handler (`lib/features/notifications/application/deep_link_handler.dart`)
  currently lands on the activity feed via `MaterialPageRoute.push`. Now that
  `shellNavigationControllerProvider` exists, that handler COULD later
  `selectTab(...)` instead. This is a **separate follow-up** — this story only
  provides the controller + the Profile consumer. Seam noted; scope not widened.

### §6 — No backend change

No new Cloud Function, Firestore collection, security rule, or index. Read-only
over `simplifiedBalances` (Invariant 2); reads from the single production project
via the emulator in CI (Invariant 4). No new Flutter plugin, so no
`ios/Podfile.lock` change is expected.

## Branch / PR Metadata

| Field | Value |
|---|---|
| **Branch** | `feat/profile-my-friends-groups` |
| **Base** | `main` at `57c272e` (PR #62 merged: FR-HD-01/02 home dashboard) |
| **Target PR** | next available GitHub number (≥ #63) — reconcile slot label at open |
| **PR title (≤72 chars)** | `feat(profile): FR-PR-04 my friends/groups count + tab nav` |
| **Commit-title scope** | `profile` (single-token per CI title-lint `[a-z0-9_-]+`) |
| **Story SP** | 3 |
