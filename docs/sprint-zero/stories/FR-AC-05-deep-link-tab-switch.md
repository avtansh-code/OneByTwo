# FR-AC-05 — Deep-link tab-switch on notification tap (part 2)

> Implementation-ready user story for the **deep-link tab-switch**: a notification
> tap must **select the relevant primary tab** before pushing the detail screen,
> so the user lands in (and on pop returns to) a coherent tab context instead of a
> stale, unrelated tab. The original FR-AC-05 (resolver + navigation + the four
> dispatch sources + cold-start) shipped in #53; the tab-switch was **deferred
> from #63** (which built the `shellNavigationControllerProvider` seam) as
> "controller seam only". 100% client-side navigation refinement over existing
> providers: no new data layer, no schema/rules/index/function change, no new
> Flutter plugin (no `ios/Podfile.lock` change).

---

## SRS Requirement ID(s)

- **FR-AC-05** (SRS section 4.7, line 240, **P0**) — "Tapping a notification shall
  deep-link the user to the relevant screen, even from a cold start." This story
  completes the requirement by landing the user in the **relevant tab context**
  (the bottom-nav primary tab), not merely the detail route pushed over whatever
  tab happened to be active.

## Relevant SRS Sections

- **Section 4.7** — Activity Feed & Notifications. FR-AC-05 (P0). Closing the
  tab-switch is the last deferred piece of an FR-AC P0; every FR-AC requirement
  (FR-AC-01..05) is then fully shipped.
- **Section 5.4 / line 308** — PII rule: phone number, name, photo URL (and, by
  ADR-0013, UID-composite identifiers) shall never be logged in Crashlytics or
  Analytics. The `fcm_notification_tapped` event stays PII-free.
- **Section 13.1** — Flutter feature-first folder layout.

## Relevant Design References

- `docs/design/06-screen-specs/23-28-settle-activity-profile.md` §SCR-25
  (Activity Feed — "Reachable from … push notification deep-link (FR-AC-05)";
  Deep-Link Behaviour table; the "This item is no longer available" snackbar;
  Edge Case 1 "Notification deep-link from cold start").
- `docs/design/02-design-system/components.md` §2 `OBTBottomNav` (the fixed tab
  order: Home 0 / Friends 1 / Groups 2 / Activity 3 / Profile 4).

## Priority

**P0.** FR-AC-05 is a P0 functional requirement; the tab-switch is the last open
piece of it. It is the **first carry-forward candidate** on the
`next-three-prs.md` list, now unblocked by the `shellNavigationControllerProvider`
seam shipped in #63 and explicitly deferred there ("controller seam only", FR-PR-04
story Architect Notes §5).

## Story

**As** a One By Two user who taps a push notification,
**I want** the app to open on the primary tab that the notification relates to (not
whatever tab I last left open),
**so that** the screen I land on — and the screen I return to when I close the
detail — makes sense for what I tapped.

## Preconditions

- The user is authenticated and has completed profile setup; the
  `AuthenticatedShell` is mounted (its active tab index is owned by
  `shellNavigationControllerProvider`, the #63 seam).
- The FCM deep-link surface exists: `NotificationDeepLinks.resolve` →
  `DeepLinkTarget`; `DeepLinkHandler.handleDeepLink` (holds the app
  `ProviderContainer`) resolves, emits `fcm_notification_tapped`, then calls
  `NotificationDeepLinks.navigate`; `NotificationsLifecycleHost` wires the four
  dispatch sources (foreground banner, background `onMessageOpenedApp`, cold-start
  `getInitialMessage`, and the post-sign-in replay of `pendingDeepLinkProvider`).
- The Activity feed (`ActivityFeedScreen._onRowTap`) consumes the SAME resolver +
  `navigate` from **within** the Activity tab — an in-tab navigation that must NOT
  switch tabs.

## Acceptance Criteria

### AC-1 — Background settlement tap selects Friends + pushes Friend Detail (happy path)

**Given** the app is backgrounded and a `settlement_received` notification arrives
for a friendship the signed-in user is a member of
**When** the user taps it (`onMessageOpenedApp` → `DeepLinkSource.background`)
**Then** the shell switches to the **Friends tab (index 1)** via
`shellNavigationControllerProvider.notifier.selectTab(1)` **before** the
root-navigator push, and `FriendDetailScreen` is pushed on top — so closing the
detail returns the user to Friends.

### AC-2 — Background expense tap selects Friends + pushes Expense Detail

**Given** a backgrounded `expense_added` (or `expense_edited`) notification with a
valid friendship `contextId` and an `itemId`
**When** the user taps it
**Then** the shell switches to the **Friends tab (index 1)** and `ExpenseDetailScreen`
is pushed over it (both expense and friend detail are friends-cluster screens, so
both map to the Friends tab).

### AC-3 — Cold-start expense tap: cached pre-auth, then selects Friends + pushes in order

**Given** the app is launched cold from a tapped `expense_added` notification while
the user is **not yet authenticated**
**When** the payload is captured (`getInitialMessage`) it is cached to
`pendingDeepLinkProvider`; **and when** auth then reaches
`AuthenticatedWithProfile`
**Then** on the post-`AuthenticatedWithProfile` `addPostFrameCallback` replay the
shell selects the **Friends tab (index 1)** AND pushes `ExpenseDetailScreen`, in
that order — the tab switch occurs only after `AuthenticatedShell` is mounted, so
there is **no wrong-tab flash** and **no push onto a dead context**.

### AC-4 — Deleted-item tap selects Activity + shows snackbar, no push (DeepLinkUnavailable)

**Given** an `expense_deleted` notification (resolves to `DeepLinkUnavailable`)
**When** the user taps it from any dispatch source
**Then** the shell switches to the **Activity tab (index 3)** (the item lived in
the activity feed) and the existing **"This item is no longer available."**
snackbar is shown; **no** detail screen is pushed.

### AC-5 — Group-invite tap does NOT switch tabs, shows snackbar (DeepLinkGroupsComingSoon)

**Given** a `group_invite` notification (resolves to `DeepLinkGroupsComingSoon`,
forward-compat — no producer in v1.0)
**When** the user taps it
**Then** **no** tab switch occurs and the existing **"Groups are coming soon."**
snackbar is shown. (Groups remain a Sprint 3 epic; no real `group_invite`
deep-link is wired.)

### AC-6 — Activity-feed row-tap does NOT change the primary tab (negative case)

**Given** the user is on the Activity tab (index 3) and taps an activity row whose
event resolves to an expense/friend detail
**When** `ActivityFeedScreen._onRowTap` resolves the target and calls
`NotificationDeepLinks.navigate` directly (it does **not** use `DeepLinkHandler`)
**Then** the detail screen is pushed but the **primary tab is unchanged** (the
bottom-nav stays on Activity) — the row-tap is an in-tab navigation and must never
call `selectTab`. A boundary-contract grep guards `activity_feed_screen.dart`
against any `selectTab` / `shellNavigationController` reference.

### AC-7 — Foreground in-app-banner tap switches tabs for consistency

**Given** a foreground in-app notification banner is showing
**When** the user taps it (`DeepLinkSource.foreground`)
**Then** the same `DeepLinkHandler` path runs, so the relevant tab is selected
before the push — the banner tap behaves identically to a background/cold-start
tap (one handler, one contract).

### AC-8 — Telemetry is PII-free with a non-identifying `target_tab` (negative-for-PII)

**Given** any notification tap dispatched through `DeepLinkHandler`
**Then** exactly the existing `fcm_notification_tapped` event is emitted (NOT a new
event), carrying `notification_type`, `source`, and a new **non-identifying**
`target_tab` enum ∈ {`friends`, `activity`, `none`} derived from the target's home
tab. **No** `uid`, friendship composite, or raw entity ID is ever a parameter
(SRS line 308 / ADR-0013).

### AC-9 — No regression across the four dispatch sources or the cold-start cache/replay

**Given** the tab-switch is added
**Then** all four dispatch sources (foreground banner, background
`onMessageOpenedApp`, cold-start `getInitialMessage`, pending replay) still
navigate exactly as before; a deep-link arriving while unauthenticated still caches
to `pendingDeepLinkProvider` and replays on sign-in; and the
`DeepLinkUnavailable` / `DeepLinkGroupsComingSoon` snackbar paths are preserved.

### AC-10 — Invariants and scope

`NotificationDeepLinks.navigate` stays Riverpod-free (the `selectTab` side effect
lives in `DeepLinkHandler`). Invariants 1 (integer paise) and 2
(`simplifiedBalances` server-only) are **N/A** — this PR moves no money and reads
no balance. No second Firebase project (Invariant 4). No Cloud Function, Firestore
rule/index, or schema change; no new Flutter plugin → **no `ios/Podfile.lock`
change**. No `go_router` / per-tab nested Navigator (Sprint 3).

## Definition of Done

- [ ] Code merged to main via approved PR.
- [ ] `int? homeTabIndex` getter added to the sealed `DeepLinkTarget`
      (`lib/core/routing/notification_deep_links.dart`): `DeepLinkExpenseDetail` /
      `DeepLinkFriendDetail` → `1`, `DeepLinkUnavailable` → `3`,
      `DeepLinkGroupsComingSoon` → `null`; `navigate` unchanged (Riverpod-free).
- [ ] `DeepLinkHandler.handleDeepLink` selects the tab
      (`shellNavigationControllerProvider.notifier.selectTab(homeTabIndex)`) before
      `navigate`, and adds the `target_tab` parameter to `fcm_notification_tapped`.
- [ ] Unit tests (target→`homeTabIndex` mapping); widget tests (each dispatch
      source selects the right tab + pushes; cold-start replay ordering;
      Activity-row-tap does not switch); telemetry `target_tab` + PII-leak
      assertion. Per-feature coverage ≥ 70%.
- [ ] Telemetry / analytics in place: `fcm_notification_tapped` extended with the
      non-identifying `target_tab` enum (no new event, no PII).
- [ ] Documentation updated: `lib/features/notifications/README.md`, the FR-AC-03
      story telemetry contract row, ADR-0018, and the SCR-25 designer note.
- [ ] QA reviewed and verified against the four dispatch sources + the cold-start
      replay ordering + the target→tab mapping + the Activity-row-tap exclusion +
      the snackbar fallbacks + telemetry PII + coverage.

## Invariant Compliance

- [x] Money values are integer paise (invariant 1) — **N/A**: no monetary surface.
- [x] No client writes to `simplifiedBalances` (invariant 2) — **N/A**: no balance
      read or write.
- [x] Uses system share sheet only (invariant 3) — **N/A**: no sharing.
- [x] Single Firebase project (invariant 4) — reinforced: no new project/config;
      all pre-merge testing via the Emulator Suite (`demo-onebytwo`).

## Implementation Notes

- **Where the tab-switch lives (architect's call — see ADR-0018 / Architect Notes
  §2):** a `homeTabIndex` getter on the sealed `DeepLinkTarget` keeps the mapping
  with the target; the `selectTab` side effect lives in `DeepLinkHandler` (which
  already holds the container), keeping `NotificationDeepLinks.navigate` free of
  Riverpod. The Activity-feed row-tap uses `navigate` directly (never the handler),
  so it is naturally excluded from the tab-switch.
- **First notification consumer of `shellNavigationControllerProvider`** and the
  first cross-feature reach from `notifications` into `shell`.
- Affected folders: `lib/core/routing/`, `lib/features/notifications/`.

---

## Architect Notes

> Confirmed at kickoff: FR-AC-05 (the deep-link tab-switch) is the next-slot pick
> — the **first carry-forward candidate**, now unblocked by the
> `shellNavigationControllerProvider` seam (#63), closing the **last deferred piece
> of a P0**. The decision is recorded as **ADR-0018**
> (`.github/shared/decision-log.md`). Zero schema / security-rule / index / Cloud
> Function change; no new Flutter plugin (no `ios/Podfile.lock` change). Invariants
> 1 and 2 are N/A (no money, no `simplifiedBalances`).

### §1 — `homeTabIndex` on the sealed `DeepLinkTarget` (mapping with the target)

Add `int? get homeTabIndex` to the sealed base and override per case in
`lib/core/routing/notification_deep_links.dart` (indices mirror
`OBTBottomNav.tabs`: Home 0 / Friends 1 / Groups 2 / Activity 3 / Profile 4):

```dart
sealed class DeepLinkTarget {
  const DeepLinkTarget();

  /// Primary tab to select before navigating, or null for no switch.
  int? get homeTabIndex;
}
// DeepLinkExpenseDetail / DeepLinkFriendDetail → 1 (Friends)
// DeepLinkUnavailable                          → 3 (Activity)
// DeepLinkGroupsComingSoon                     → null (no switch)
```

`NotificationDeepLinks.navigate` is **unchanged** — it stays Riverpod-free (no
`WidgetRef`, container, or selector parameter). The exhaustive `switch` discipline
on the sealed type guarantees a new target type cannot be added without choosing a
tab mapping.

### §2 — `selectTab` + `target_tab` in `DeepLinkHandler` (the side effect)

In `DeepLinkHandler.handleDeepLink`, after resolving the target and before
`navigate`:

```dart
final target = resolveTarget(payload, currentUid: currentUid);
final tabIndex = target.homeTabIndex;
final targetTab = tabIndex == null
    ? 'none'
    : OBTBottomNav.tabs[tabIndex].telemetryLabel; // 'friends' | 'activity'
unawaited(_ref.read(analyticsServiceProvider).logEvent(
  name: 'fcm_notification_tapped',
  parameters: {
    'notification_type': payload.type.wireName,
    'source': source.wireName,
    'target_tab': targetTab, // non-identifying enum (ADR-0013)
  },
));
if (tabIndex != null) {
  _ref.read(shellNavigationControllerProvider.notifier).selectTab(tabIndex);
}
if (!context.mounted) return;
await NotificationDeepLinks.navigate(context, target);
```

The handler imports `shell_navigation_controller.dart` and `obt_bottom_nav.dart`
(the first cross-feature reach from `notifications` into `shell`). `selectTab` is
called synchronously before the awaited push, so the IndexedStack is already on the
target tab when the detail is presented — no wrong-tab flash.

### §3 — Cold-start ordering

No new ordering machinery is needed: the cold-start and pending-replay paths already
dispatch from the post-`AuthenticatedWithProfile` `addPostFrameCallback` in
`NotificationsLifecycleHost._onAuthStateChanged`, which fires only once
`AuthenticatedShell` is mounted. A deep-link captured pre-auth still caches to
`pendingDeepLinkProvider` and replays on sign-in (unchanged). Because the shell
`ref.watch`es the `autoDispose` controller, it is alive during every dispatch, so
the handler's `selectTab` mutates the instance the shell observes.

### §4 — Activity-feed row-tap exclusion (load-bearing)

`ActivityFeedScreen._onRowTap` keeps calling `NotificationDeepLinks.navigate`
directly — it does **not** route through `DeepLinkHandler`, so it never selects a
tab (it is an in-tab navigation). A boundary-contract grep over
`lib/features/activity/presentation/activity_feed_screen.dart` asserts the file
contains no `selectTab` / `shellNavigationController` reference, so a future refactor
cannot accidentally couple them.

### §5 — Telemetry (PII-free)

`fcm_notification_tapped` is extended with the non-identifying `target_tab` enum
only — not a new event, no `uid`, friendship composite, or raw entity ID. The
FR-AC-03 story telemetry contract row and `lib/features/notifications/README.md` are
updated to document the new parameter.

### §6 — No backend change

No new Cloud Function, Firestore collection, security rule, or index. No money path
(Invariant 1 N/A) and no `simplifiedBalances` read/write (Invariant 2 N/A). Single
production project, emulator-tested in CI (Invariant 4). No new Flutter plugin → no
`ios/Podfile.lock` change.

### §7 — Designer ratification

The Designer ratifies the target→tab mapping and the back-stack UX (pop from a
notification-opened detail returns to the chosen tab), confirms there is no
wrong-tab flash (synchronous `selectTab` before the push), and confirms the
foreground in-app-banner tap switches tabs for consistency with the
background/cold-start tap. The SCR-25 Deep-Link Behaviour / Edge Cases note is
updated accordingly.

## Branch / PR Metadata

| Field | Value |
|---|---|
| **Branch** | `feat/fr-ac-05-deep-link-tab-switch` |
| **Base** | `main` at `1f26548` (PR #67 merged: FR-HD-03 spend breakdown chart) |
| **Target PR** | next available GitHub number (≥ #69) — reconcile slot label at open |
| **PR title (≤72 chars)** | `feat(notifications): FR-AC-05 deep-link tab switch on notification tap` |
| **Commit-title scope** | `notifications` (single-token per CI title-lint `[a-z0-9_-]+`) |
| **Story SP** | 3 |
