# Shell

Feature-folder for the authenticated-area shell: the five-tab bottom
navigation, the persistent Add-Expense FAB, and the Add-Expense context
picker (FR-HD-04). It is the frame that hosts the per-feature tab
content once a user reaches `AuthenticatedWithProfile`.

## Implemented scope

### Five-tab shell

- `presentation/authenticated_shell.dart` — `AuthenticatedShell`
  (`ConsumerStatefulWidget`). Hosts the five primary tabs in an
  `IndexedStack` (for tab-state preservation) with `OBTBottomNav` and
  the persistent `OBTFloatingActionButton`. Tab content, in order:
  `HomeDashboardScreen` (home feature), `FriendsListScreen` (friends
  feature), `GroupsListPlaceholder`, `ActivityFeedScreen` (activity
  feature), `ProfileScreen` (profile feature). The current tab index is
  plain in-shell `setState` (no Riverpod `Notifier<int>` until a second
  consumer needs it). Android back on a non-zero tab snaps to tab 0 via
  `PopScope` (no telemetry on the back-driven switch). A
  `@visibleForTesting` `tabContentOverride` lets shell tests isolate
  from the per-feature provider graphs. `go_router` migration is a
  deferred Sprint 3 chore.

### Add-Expense FAB and context picker (SCR-08)

- `presentation/add_expense_context_picker_sheet.dart` —
  `AddExpenseContextPickerSheet` (`ConsumerWidget`). The FAB opens this
  modal. The **Friends** section consumes `friendsListProvider` and
  renders the populated / empty / loading / error sub-states; selecting a
  friend dismisses the picker and opens `AddExpenseBottomSheet` (expenses
  feature) with the friend's `(friendshipId, currentUserUid,
  otherUserUid)` tuple. The **Groups** section is a single disabled
  "Coming in Sprint 3" stub row that keeps the picker open on tap.

### Placeholders

- `presentation/groups_list_placeholder.dart` — `GroupsListPlaceholder`
  for tab 2. `lib/features/groups/` is greenfield (Sprint 3 Groups
  epic). Colocated with the shell so a later PR can swap it for the real
  Group list screen in one change.

  Tab 0's `HomeDashboardScreen` (FR-HD-01/02) now lives under
  `lib/features/home/`; the temporary `HomeDashboardPlaceholder` was
  deleted when the real dashboard shipped.

### Telemetry

- `application/shell_telemetry.dart` — top-level event-name, parameter-
  key, and token constants (no provider). Three events:
  `bottom_nav_tab_selected` (`tab_index`, `tab_label`), `fab_tapped`
  (`source_tab`), and `expense_context_selected` (`context_type`). The
  tab-label tokens (`home` / `friends` / `groups` / `activity` /
  `profile`) double as the `source_tab` values; `context_type` is
  `friend` / `group`. None of these payloads carry UID-derived
  parameters.

## Layout

```
application/
  shell_telemetry.dart                  # event/param/token constants (no provider)
presentation/
  authenticated_shell.dart              # 5-tab IndexedStack + bottom nav + FAB
  add_expense_context_picker_sheet.dart # SCR-08 picker → AddExpenseBottomSheet
  groups_list_placeholder.dart          # tab 2 placeholder (Sprint 3 groups)
```

## Invariants honoured

- **Invariant 1 (integer paise):** the picker shows friend balances via
  `FriendListTile` → `BalancePill` → `formatInrFromPaise`; the shell
  itself performs no monetary arithmetic.
- **Invariant 2 (`simplifiedBalances` server-maintained):** the picker
  reads `friendsListProvider` (which projects the field deeper in the
  pipeline) but the shell never reads or writes the field name.
- **Invariant 3 (system share sheet only):** N/A.
- **Invariant 4 (single Firebase project):** all reads go through the
  single production project. The PII-guard grep at
  `test/features/shell/shell_boundary_contract_test.dart` enforces that
  no shell telemetry carries identifiers.

## Hand-off boundaries

- **In (mount):** `lib/main.dart` mounts `AuthenticatedShell` as the
  `home` for the `AuthenticatedWithProfile` state, inside a per-arm
  `ProviderScope` that binds `currentUserIdProvider` to the signed-in
  UID.
- **Out (tab content):** `HomeDashboardScreen`, `FriendsListScreen`,
  `ActivityFeedScreen` and `ProfileScreen` are owned by their respective
  feature folders; Groups is a placeholder pending the Sprint 3 Groups
  epic.
- **Out (add expense):** the context picker opens `AddExpenseBottomSheet`
  from the expenses feature; the picker owns only the context selection,
  not the expense write.
