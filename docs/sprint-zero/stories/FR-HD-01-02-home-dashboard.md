# FR-HD-01 + FR-HD-02 — Home Dashboard (SCR-06)

> Implementation-ready user story for the **real Home dashboard** that
> replaces the temporary `HomeDashboardPlaceholder` on tab 0 of the
> authenticated shell. Ships the FR-HD-01 overall net-balance header,
> the FR-HD-02 top-5 balances list with a per-row "Settle Up" action and
> tile-tap navigation to Friend Detail, and an FR-HD-03 (P1)
> "Spending breakdown coming soon" placeholder card. 100% client-side
> and read-only over `simplifiedBalances`: composes the existing
> `friendsListProvider` via two pure derived providers
> (`overallNetBalanceProvider`, `topBalancesProvider`). No new data
> layer, no schema/rules/index/function change, no new Flutter plugin.

---

## SRS Requirement ID(s)

- **FR-HD-01** (SRS section 4.2, line 246, **P0**) — the Home dashboard
  shall display the user's overall net simplified balance as the
  primary visual element.
- **FR-HD-02** (SRS section 4.2, line 247, **P0**) — the dashboard shall
  surface the top 5 friends/groups by absolute simplified balance with a
  quick "Settle Up" action per row.
- **FR-HD-03** (SRS section 4.2, line 248, **P1**) — current-month
  category breakdown. **Placeholder-only** here (no chart); the real
  donut/bar chart is a separate P1 PR (needs a charting dependency + a
  category-aggregation read path).

## Relevant SRS Sections

- **Section 4.2** — Home Dashboard. FR-HD-01/02 (P0), FR-HD-03 (P1).
- **Section 5.9 / FR-EX-09** — Indian numbering format for the balance
  amount (`formatInrFromPaise()`).
- **Section 5.10** — Observability. Six client analytics events
  (`home_viewed`, `home_settle_up_tapped`, `home_tile_tapped`,
  `home_empty_cta_tapped`, `home_error_retry_tapped`,
  `home_error_support_tapped`). PII guard per ADR-0013.
- **Section 6.4 / 6.5** — Error and empty-state taxonomy.
- **Section 7.3 / 7.5** — Integer paise; `simplifiedBalances`
  server-maintained, client-read-only.
- **Section 13.1** — Flutter feature-first folder layout. NEW
  `lib/features/home/` feature.

## Relevant Design References

- `docs/design/06-screen-specs/06-08-home-and-search.md` — SCR-06
  (authoritative layout, four states, telemetry, accessibility, edge
  cases).
- `docs/design/05-mockups/03-home-dashboard.html`.
- `docs/design/02-design-system/components.md` — `OBTBalancePill`,
  `OBTFriendListTile`, `OBTRupeeText`, `OBTEmptyState`, `OBTErrorState`.

## Priority

**P0.** FR-HD-01/02 is the last open P0 product surface on the
`docs/sprint-zero/next-three-prs.md` candidate list after FR-PR-05
(PR #60) closed. It replaces a placeholder that has been live on tab 0
since PR #56 and inherits the FR-HD-04 persistent FAB + context picker
(PR #57) for free.

## Story

**As** a One By Two user who has opened the app,
**I want** the Home tab to show my overall net balance and my biggest
outstanding balances at a glance,
**so that** I immediately know whether I owe or am owed money overall and
can settle the most significant balances in one tap.

## Preconditions

- The user is authenticated and has completed profile setup (the
  authenticated shell is mounted; `currentUserIdProvider` is bound to
  the signed-in UID by the per-arm `ProviderScope` in `lib/main.dart`).
- The friendship balance axis exists: `friendsListProvider` yields
  per-friendship `FriendListItem`s carrying `netBalancePaise` (signed
  integer paise, computed by `netBalancePaise()` over the
  server-maintained `simplifiedBalances`).
- Groups are **not** implemented (Sprint 3). The dashboard renders the
  friendship axis only.

## Acceptance Criteria

### AC-1 — Overall net balance, positive (FR-HD-01)

**Given** the user has friendships whose net balances sum to a positive
integer paise value
**When** the Home dashboard resolves
**Then** the header card shows "Overall, you are owed" and the absolute
amount formatted via `formatInrFromPaise()` in the Indian numbering
format, and `home_viewed` is emitted once with
`net_balance_state: "positive"`.

### AC-2 — Overall net balance, negative (FR-HD-01)

**Given** the friendships sum to a negative value
**When** the dashboard resolves
**Then** the header shows "Overall, you owe" and the absolute amount, and
`home_viewed` carries `net_balance_state: "negative"`.

### AC-3 — Overall net balance, settled (FR-HD-01)

**Given** the friendships sum to exactly zero (including the case where
non-zero individual balances cancel out)
**When** the dashboard resolves
**Then** the header shows "You're all settled up — high five!" with no
amount, and `home_viewed` carries `net_balance_state: "zero"`. If any
individual balance is non-zero, the Top Balances list still renders those
rows (SCR-06 Edge Case 1).

### AC-4 — Top 5 by absolute balance (FR-HD-02)

**Given** the user has more than five friendships with non-zero balances
**When** the dashboard resolves
**Then** the Top Balances section shows exactly five rows, sorted by
descending absolute balance, ties broken stably on the upstream
`lastActivityAt`-descending order; settled-up (zero-balance) friendships
are excluded.

### AC-5 — Settle Up per row (FR-HD-02)

**Given** a populated Top Balances row
**When** the user taps its "Settle Up" button
**Then** the existing Settle Up bottom sheet opens pre-filled with that
friend's context and `source: 'home_dashboard'`, and
`home_settle_up_tapped` is emitted with `context_type: "friend"`,
`context_id_hash` (the hashed friendshipId), and `amount_paise` (the
absolute balance).

### AC-6 — Tile navigation

**Given** a populated Top Balances row
**When** the user taps the tile body (not the Settle Up button)
**Then** the app navigates to Friend Detail for that friendship, and
`home_tile_tapped` is emitted with `context_type: "friend"` and
`context_id_hash`.

### AC-7 — Empty state

**Given** the user has no non-zero balances
**When** the dashboard resolves
**Then** the empty state renders the "No expenses yet" copy and an
"Add Expense" CTA; tapping the CTA emits `home_empty_cta_tapped` and
opens the Add Expense context picker.

### AC-8 — Loading state

**Given** the first Firestore snapshot has not yet resolved
**When** the dashboard is shown
**Then** a skeleton placeholder renders and `home_viewed` is **not** yet
emitted.

### AC-9 — Error state (negative case)

**Given** the balances read fails (the `friendsListProvider` stream
emits an error)
**When** the dashboard resolves
**Then** the error state renders "Something went wrong", the support
code "HD-FIRESTORE-READ", a "Retry" button, and a "Contact Support"
link; `home_viewed` is emitted once with `net_balance_state: "error"`.
Tapping "Retry" re-invokes the read and emits `home_error_retry_tapped`
with a 1-based `attempt_number`; tapping "Contact Support" emits
`home_error_support_tapped` with `error_code: "HD-FIRESTORE-READ"` and
runs the FR-PR-05 `mailto:` flow (fallback dialog when no mail client).

### AC-10 — FR-HD-03 placeholder

**Given** the populated state
**Then** a non-interactive "This Month" card shows "Spending breakdown
coming soon" — no chart, no charting dependency, no tap handler.

### AC-11 — Invariant 1 (integer paise)

All balances flow as `int`; every rupee string is produced by
`formatInrFromPaise()`. No `double`/`float`, no inline `/ 100`. Enforced
by `test/features/home/home_boundary_contract_test.dart`.

### AC-12 — Invariant 2 (`simplifiedBalances` read-only)

The dashboard only reads `simplifiedBalances` (via the friends-list
stream); it never writes the field. Enforced by the boundary-contract
grep.

### AC-13 — No PII in telemetry (ADR-0013)

Any friendship/context identifier emitted as a telemetry parameter is
hashed via `hashFriendshipId()`. No raw composite UID, display name,
photo URL, or phone number appears in any event. Enforced by
`test/features/home/home_dashboard_pii_leak_test.dart`.

## Definition of Done

- [ ] `lib/features/home/` scaffolded (domain/application/presentation)
      per SRS section 13.1.
- [ ] `overallNetBalanceProvider` + `topBalancesProvider` derived from
      `friendsListProvider` with unit tests for sum / abs-sort / stable
      tie-break / zero-exclusion / cap / empty / loading / error.
- [ ] `HomeDashboardScreen` with the four states + FR-HD-03 placeholder
      card + Settle Up + tile-tap wiring.
- [ ] `home_telemetry.dart` with the six SCR-06 events; hashed IDs;
      PII-leak test green.
- [ ] Shell tab 0 swapped to `HomeDashboardScreen`;
      `home_dashboard_placeholder.dart` deleted; shell README updated.
- [ ] Widget tests for each state + interactions; boundary-contract grep.
- [ ] Per-feature coverage ≥ 70%; `flutter analyze --fatal-infos` and
      `dart format` clean.
- [ ] Zero schema / rules / index / Cloud Function change; no new
      Flutter plugin (no `ios/Podfile.lock` change).

---

## Architect Notes

> Confirmed at kickoff: FR-HD-01 + FR-HD-02 is the next-slot pick. The
> design below was ratified before Flutter Dev implementation. Zero
> schema, security-rule, index, or Cloud Function changes; this is a
> pure read-side composition of existing providers.

### §1 — Derived providers (composition, no new data layer)

Two pure reducers in `lib/features/home/application/home_balances_providers.dart`:

- `overallNetBalanceProvider` (`Provider<AsyncValue<int>>`) — folds
  `friendsListProvider`'s items into the signed integer-paise sum
  (FR-HD-01). `whenData` preserves the upstream loading/error lifecycle.
- `topBalancesProvider` (`Provider<AsyncValue<List<FriendListItem>>>`) —
  excludes zero balances, sorts by descending `|netBalancePaise|`, and
  caps at `topBalancesCap = 5` (FR-HD-02). The sort is made stable by
  decorating with the original index as the tie-breaker, preserving the
  upstream `lastActivityAt`-descending order on equal magnitudes
  (SCR-06 Edge Case 2). Returns an unmodifiable list.

**Scoping (Riverpod 2.x).** `friendsListProvider` is itself scoped
(`dependencies: [currentUserIdProvider]`, overridden per-arm in
`lib/main.dart`). Any provider that watches it must declare
`dependencies: [friendsListProvider]` to propagate that scoping — both
derived providers do. This is the load-bearing detail; omitting it
throws the Riverpod "tried to read … but specified a 'dependencies'
list" assertion at first read.

### §2 — Screen state machine

`HomeDashboardScreen` watches `topBalancesProvider` for the
loading/empty/populated/error discriminator (it mirrors the upstream
`friendsListProvider` lifecycle), and reads `overallNetBalanceProvider`
for the header value inside the data branch:

- **loading** → skeleton; no `home_viewed`.
- **error** → error state; `home_viewed(error)`.
- **data, top list empty** → empty state; `home_viewed(zero)`. Empty vs
  populated is discriminated purely by "are there any non-zero
  balances?", so an overall-settled user with offsetting individual
  balances correctly shows the populated state (Edge Case 1).
- **data, top list non-empty** → populated state; `home_viewed(state)`.

`home_viewed` is **single-fire on the first terminal frame** (a
`_loggedView` bool gate), matching the repo discipline established by
`friends_list_viewed` and `settlement_history_viewed`. The `'loading'`
`net_balance_state` token is therefore reserved but not emitted by this
implementation — under the IndexedStack shell the screen is built once
and "became visible" cannot be cleanly detected without shell plumbing
that does not exist; single-fire on first terminal frame is the
correct, testable contract.

### §3 — Widget reuse (promote-vs-reuse decision)

**Reuse, do not promote.** The home feature already composes the friends
domain (`friendsListProvider`, `FriendListItem`), so it reuses
`lib/features/friends/presentation/widgets/balance_pill.dart` (`BalancePill`)
verbatim inside a home-specific `TopBalanceTile` (which adds the per-row
"Settle Up" action the friends list does not have). The net-balance
header is a small home-local `NetBalanceHeaderCard` (different copy and
layout from the friends-list pill and the Friend-Detail header — a third
distinct balance surface). We deliberately **do not** extract
`OBTBalancePill` / `OBTRupeeText` / `OBTEmptyState` / `OBTErrorState`
into `lib/core/widgets/` in this PR: the carry-forward list defers those
"until a second use site", and the minimum that avoids duplicating the
balance-pill logic is to reuse the existing widget. Large primitive
extractions remain their own follow-ups.

### §4 — Group axis stub (Sprint 3 seam)

FR-HD-02 reads "friends/groups". Groups are README-only (Sprint 3).
`topBalancesProvider` is friendship-only; telemetry carries
`context_type: 'friend'`. No group tiles render. The Sprint 3 Group
Detail work slots a second source into the Top Balances section without
changing the provider contract — the same stub discipline used by
FR-SE-08 (PR #58) and FR-HD-04 (PR #57).

### §5 — Offline banner (FR-OF-01) — DEFERRED

The SCR-06 Offline State is **deferred**. It needs a connectivity signal
(a new plugin → `ios/Podfile.lock` churn) and would widen scope past the
5-SP estimate. FR-OF-01/02/03 are a coherent offline-handling slice
better shipped together in their own PR. The error state already covers
the "empty cache + no connectivity" first-launch case (SCR-06 Edge
Case 3) via the generic `HD-FIRESTORE-READ` path.

### §6 — Settle-up reuse

The existing `SettleUpBottomSheet` is reused, not forked. A single
optional `source` parameter (default `'friend_detail'`) is added so the
sheet's `settle_up_screen_viewed.source` reflects the entry point; the
home dashboard passes `'home_dashboard'` (the token already
pre-anticipated in `settle_up_telemetry.dart`). No settlement logic is
duplicated.

### §7 — Telemetry payloads (PII-free)

Six events in `home_telemetry.dart`. The only identifier parameter,
`context_id_hash`, is the `hashFriendshipId()` of the friendshipId
(SHA-256 truncated to 16 hex, ADR-0013). `net_balance_state`,
`context_type`, `amount_paise`, `attempt_number`, and `error_code` are
non-identifying. A PII-leak test asserts no raw composite UID, name,
photo URL, or phone number reaches any event name, parameter value, or
parameter key.

### §8 — No backend change

No new Cloud Function, Firestore collection, security rule, or index.
The dashboard is read-only over `simplifiedBalances` (Invariant 2) and
reads from the single production project via the emulator in CI
(Invariant 4). No new Flutter plugin, so no `ios/Podfile.lock` change.

## Branch / PR Metadata

| Field | Value |
|---|---|
| **Branch** | `feat/home-dashboard` |
| **Base** | `main` at `d474507` (PR #61 merged: CI pipeline speed-up) |
| **Target PR** | next available GitHub number (≥ #62) |
| **PR title (≤72 chars)** | `feat(home): FR-HD-01/02 home dashboard balances` |
| **Commit-title scope** | `home` (single-token per CI title-lint `[a-z0-9_-]+`) |
| **Story SP** | 5 |
