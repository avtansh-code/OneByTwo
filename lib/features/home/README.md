# Home

Feature-folder that owns the Home dashboard (SCR-06), tab 0 of the
authenticated shell. Replaces the temporary `HomeDashboardPlaceholder`
shipped by PR #56.

Implements **FR-HD-01** (overall net simplified balance as the primary
visual element) and **FR-HD-02** (top 5 friends/groups by absolute
simplified balance with a quick "Settle Up" action per row). **FR-HD-03**
(P1 monthly category breakdown) ships as a "coming soon" placeholder card
only — the real chart is a separate P1 PR.

## Implemented scope

100% client-side and **read-only** over `simplifiedBalances`
(Invariant 2). No new data layer: the dashboard composes the existing
friendship balance axis (`friendsListProvider`).

### Application — derived providers

`application/home_balances_providers.dart`:

- `overallNetBalanceProvider` (`Provider<AsyncValue<int>>`) — FR-HD-01.
  The signed integer-paise **sum** of every friendship's
  `netBalancePaise`, folded over `friendsListProvider`. Positive ⇒ owed
  to the user; negative ⇒ the user owes; zero ⇒ all settled up.
- `topBalancesProvider` (`Provider<AsyncValue<List<FriendListItem>>>`) —
  FR-HD-02. Zero balances excluded, sorted by **descending absolute
  balance**, stable tie-break on the upstream `lastActivityAt`-desc
  order, capped at `topBalancesCap = 5`. Returns an unmodifiable list.

Both declare `dependencies: [friendsListProvider]` to propagate that
provider's per-arm `currentUserIdProvider` scoping (bound in
`lib/main.dart`). Both are pure read-side reducers — they never write
`simplifiedBalances`.

### Application — telemetry

`application/home_telemetry.dart` — the six SCR-06 events (`home_viewed`,
`home_settle_up_tapped`, `home_tile_tapped`, `home_empty_cta_tapped`,
`home_error_retry_tapped`, `home_error_support_tapped`) plus their
parameter-key and enum-token constants. The only identifier parameter,
`context_id_hash`, is the `hashFriendshipId()` of the friendshipId
(ADR-0013); every other parameter is non-identifying.

### Presentation

- `presentation/home_dashboard_screen.dart` — `HomeDashboardScreen`
  (`ConsumerStatefulWidget`). Renders the four SCR-06 states:
  - **loading** — skeleton; `home_viewed` not yet emitted.
  - **empty** — "No expenses yet" + an "Add Expense" CTA opening the
    Add Expense context picker.
  - **populated** — net-balance header card + "Top Balances" list (each
    row with Settle Up + tile-tap) + the FR-HD-03 "This Month"
    placeholder card.
  - **error** (`HD-FIRESTORE-READ`) — Retry + a "Contact Support" link
    reusing the FR-PR-05 `ContactSupportController` (the first reuse
    outside Profile).

  `home_viewed` is single-fire on the first terminal (data/error) frame,
  matching `friends_list_viewed` / `settlement_history_viewed`.

- `presentation/widgets/net_balance_header_card.dart` —
  `NetBalanceHeaderCard`. The FR-HD-01 header. Direction is conveyed by
  text and by the semantic `ColorScheme` role (tertiary/error/surface),
  never colour alone (SRS section 5.6).
- `presentation/widgets/top_balance_tile.dart` — `TopBalanceTile`. A
  Top Balances row: avatar + name + the **reused** friends-feature
  `BalancePill` + a "Settle Up" text button (48×48 dp tap target).
- `presentation/widgets/spending_breakdown_placeholder_card.dart` —
  `SpendingBreakdownPlaceholderCard`. The non-interactive FR-HD-03
  placeholder (no chart).

## Layout

```
application/
  home_balances_providers.dart   # overallNetBalanceProvider + topBalancesProvider
  home_telemetry.dart            # 6 SCR-06 events + param/token constants
presentation/
  home_dashboard_screen.dart     # SCR-06 four-state screen (tab 0)
  widgets/
    net_balance_header_card.dart        # FR-HD-01 header
    top_balance_tile.dart               # FR-HD-02 row (reuses BalancePill)
    spending_breakdown_placeholder_card.dart  # FR-HD-03 placeholder
```

`domain/` is intentionally empty for now: the dashboard reuses the
friends feature's `FriendListItem` rather than introducing a parallel
view-model.

## Invariants honoured

- **Invariant 1 (integer paise):** balances flow as `int`; every rupee
  string is produced by `formatInrFromPaise()` in the child widgets. No
  `double`, no inline `/ 100`. Enforced by
  `test/features/home/home_boundary_contract_test.dart`.
- **Invariant 2 (`simplifiedBalances` server-maintained):** the
  dashboard only reads the field (via `friendsListProvider`); the
  boundary-contract grep asserts it is never written here.
- **Invariant 3 (system share sheet only):** the error-state Contact
  Support link uses the FR-PR-05 `mailto:` flow, not the share sheet.
- **Invariant 4 (single Firebase project):** all reads come from the
  single production project via the emulator in CI.

## Stubs and deferrals

- **Group axis** — `topBalancesProvider` is friendship-only; telemetry
  carries `context_type: 'friend'`. The Sprint 3 Groups epic slots a
  second source into the Top Balances section without changing the
  provider contract.
- **FR-HD-03 chart** — placeholder only; the donut/bar chart + the
  category-aggregation read path are a separate P1 PR (no charting
  plugin added here).
- **FR-OF-01 offline banner** — deferred (needs a connectivity signal /
  plugin → `ios/Podfile.lock` churn). The error state covers the
  empty-cache-offline first-launch case.

## Hand-off boundaries

- **In (mount):** `AuthenticatedShell` mounts `HomeDashboardScreen` as
  tab 0, inside the per-arm `ProviderScope` (from `lib/main.dart`) that
  binds `currentUserIdProvider`.
- **Out (settle up):** opens the settlements feature's
  `SettleUpBottomSheet` with `source: 'home_dashboard'`.
- **Out (friend detail):** navigates to the friends feature's
  `FriendDetailScreen`.
- **Out (add expense):** the empty-state CTA opens the shell's
  `AddExpenseContextPickerSheet`.
