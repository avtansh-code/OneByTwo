# Home

Feature-folder that owns the Home dashboard (SCR-06), tab 0 of the
authenticated shell. Replaces the temporary `HomeDashboardPlaceholder`
shipped by PR #56.

Implements **FR-HD-01** (overall net simplified balance as the primary
visual element), **FR-HD-02** (top 5 friends/groups by absolute
simplified balance with a quick "Settle Up" action per row), and
**FR-HD-03** (the current-month spend summary with a per-category donut
breakdown).

## Implemented scope

100% client-side. The FR-HD-01/02 balances axis is **read-only** over
`simplifiedBalances` (Invariant 2); the FR-HD-03 breakdown axis is a read
over the `expenses` subcollections (Invariant 2 N/A — it never touches
`simplifiedBalances`). Both compose the existing `friendsListProvider`;
FR-HD-03 adds a one-shot per-friendship fan-out read through the expenses
feature's `ExpenseRepository`.

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

### Application — monthly spend (FR-HD-03)

`application/monthly_spend_breakdown_provider.dart`:

- `monthlySpendBreakdownProvider`
  (`FutureProvider<MonthlySpendBreakdown>`,
  `dependencies: [friendsListProvider]`) — awaits the resolved friends
  list, computes the current IST month window, fans out one
  `ExpenseRepository.fetchExpensesInMonth` read per friendship with
  `Future.wait`, and reduces the result through the pure
  `aggregateMonthlySpend`. It never reads `currentUserIdProvider`: the
  user's share is the counterparty complement of each friendship's
  `otherUserId`. `ref.invalidate` re-runs the fan-out (the card's Retry).
- `homeClockProvider` (`Provider<DateTime Function()>`) — an injectable
  `DateTime.now`, overridden in tests to pin the IST month window.

### Application — telemetry

`application/home_telemetry.dart` — the seven SCR-06 events
(`home_viewed`, `home_settle_up_tapped`, `home_tile_tapped`,
`home_empty_cta_tapped`, `home_error_retry_tapped`,
`home_error_support_tapped`, `home_spending_breakdown_viewed`) plus their
parameter-key and enum-token constants. The only identifier parameter,
`context_id_hash`, is the `hashFriendshipId()` of the friendshipId
(ADR-0013); `home_spending_breakdown_viewed` carries only `category_count`
(a `0`–`8` `int`); every other parameter is non-identifying.

### Presentation

- `presentation/home_dashboard_screen.dart` — `HomeDashboardScreen`
  (`ConsumerStatefulWidget`). Renders the four SCR-06 states:
  - **loading** — skeleton; `home_viewed` not yet emitted.
  - **empty** — "No expenses yet" + an "Add Expense" CTA opening the
    Add Expense context picker.
  - **populated** — net-balance header card + "Top Balances" list (each
    row with Settle Up + tile-tap) + the FR-HD-03 "This Month"
    spend-breakdown card.
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
- `presentation/widgets/spending_breakdown_card.dart` —
  `SpendingBreakdownCard` (`ConsumerStatefulWidget`). Watches
  `monthlySpendBreakdownProvider` and renders the four SCR-06
  sub-states: a chart-shaped **loading** skeleton, an **empty**
  "No spending yet this month" body (no chart), a **populated** donut +
  vertical legend, and an **error** body (Retry + a `HD-FIRESTORE-READ`
  Contact Support link reusing the FR-PR-05 controller). Owns the
  single-fire `home_spending_breakdown_viewed` gate — it fires once per
  mount on the first terminal data frame (populated or empty), never on
  loading or error. Accessibility: a donut-summary Semantics node plus
  one Semantics label per legend row, so no meaning is carried by colour
  alone (SRS section 5.6).
- `presentation/widgets/spending_donut_chart.dart` —
  `SpendingDonutChart`. An `fl_chart` `PieChart` wrapper (160 dp ring,
  centre = month total). The painted chart is decorative and wrapped in
  `ExcludeSemantics`; each section sweep is the integer-paise geometry
  ratio `categoryPaise / monthTotalPaise`, never a `double` money value.
- `presentation/widgets/spending_category_palette.dart` — the
  brightness-aware light/dark `ExpenseCategory → Color` maps (design
  tokens §1.3) plus the `spendingCategoryColor()` resolver. A plain
  `static const` map, not a `ThemeExtension`.

### Domain (FR-HD-03)

- `domain/monthly_spend_breakdown.dart` — the immutable value objects
  `CategorySpend { category, totalPaise }` and
  `MonthlySpendBreakdown { categories, monthTotalPaise }` (value
  equality; `categories` holds the non-zero totals sorted by descending
  paise).
- `domain/monthly_spend_aggregator.dart` — pure functions:
  `currentMonthWindowIst()` (the fixed `+05:30` IST month boundary
  returned as UTC instants, with December roll-over) and
  `aggregateMonthlySpend()` (sums each expense's user share — the
  non-`otherUserId` splits — per category inside the half-open window).
  No Flutter or Firebase imports, so it is exhaustively unit-tested.

## Layout

```
application/
  home_balances_providers.dart          # overallNetBalanceProvider + topBalancesProvider
  home_telemetry.dart                   # 7 SCR-06 events + param/token constants
  monthly_spend_breakdown_provider.dart # FR-HD-03 fan-out + homeClockProvider
domain/
  monthly_spend_breakdown.dart          # CategorySpend + MonthlySpendBreakdown
  monthly_spend_aggregator.dart         # pure IST window + per-category reducer
presentation/
  home_dashboard_screen.dart            # SCR-06 four-state screen (tab 0)
  widgets/
    net_balance_header_card.dart        # FR-HD-01 header
    top_balance_tile.dart               # FR-HD-02 row (reuses BalancePill)
    spending_breakdown_card.dart        # FR-HD-03 card (4 sub-states)
    spending_donut_chart.dart           # FR-HD-03 fl_chart donut
    spending_category_palette.dart      # FR-HD-03 category colours
```

The FR-HD-01/02 axis reuses the friends feature's `FriendListItem`
rather than introducing a parallel view-model; FR-HD-03 adds its own
`domain/` value objects (above) for the aggregated breakdown.

## Invariants honoured

- **Invariant 1 (integer paise):** balances and category totals flow as
  `int`; every rupee string is produced by `formatInrFromPaise()` in the
  child widgets. No `double`, no `.toDouble()`, no inline `/ 100` — the
  donut passes each section an `int / int` geometry ratio. Enforced by
  `test/features/home/home_boundary_contract_test.dart` over every home
  source file (including the six FR-HD-03 files).
- **Invariant 2 (`simplifiedBalances` server-maintained):** the
  FR-HD-01/02 axis only reads the field (via `friendsListProvider`) and
  the FR-HD-03 axis never references it at all (it reads `expenses`); the
  boundary-contract grep asserts it is never written here.
- **Invariant 3 (system share sheet only):** the error-state Contact
  Support link uses the FR-PR-05 `mailto:` flow, not the share sheet.
- **Invariant 4 (single Firebase project):** all reads come from the
  single production project via the emulator in CI.

## Stubs and deferrals

- **Group axis** — both `topBalancesProvider` and
  `monthlySpendBreakdownProvider` are friendship-only; the group axis is
  a forward-compat seam (the Sprint 3 Groups epic folds a second source
  into each without changing the provider contracts). FR-HD-03 telemetry
  is group-agnostic.
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
