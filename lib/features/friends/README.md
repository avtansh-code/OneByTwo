# Friends

Feature-folder that owns the social graph and per-friend ledger surfaces:
add-friend (FR-FR-01), friends list with simplified net balance
(FR-FR-03), and the per-friend transaction history screen (FR-FR-04).

## Implemented scope

### FR-FR-01 — Add Friend (3 sub-flows)

- Contact picker UI (PR #31).
- Match-and-invite via callable Cloud Function (PR #32).
- Manual phone-number entry (PR #34).

### FR-FR-03 — Friends List with Simplified Net Balance (PR #35)

`presentation/friends_list_screen.dart` renders the four SCR-09 states
(loading / populated / empty / error) backed by
`application/friends_list_provider.dart` (a
`StreamProvider<List<FriendListItem>>`). Each row shows the
server-maintained net balance from `simplifiedBalances` via
`core/balances/net_balance.dart` and formats paise to INR via
`core/formatters/inr_formatter.dart` (`formatInrFromPaise`).

### FR-FR-04 — Friend Detail (PR #42)

`presentation/friend_detail_screen.dart` replaces the original
`FriendDetailPlaceholderScreen` and renders SCR-11:

- `widgets/friend_detail_header.dart` — 80 dp avatar + display name +
  the shared `OBTBalancePill` (large form; the friends-feature
  `balance_pill.dart` was deleted in DC-06 and all call sites re-point
  to the shared component).
- `widgets/friend_detail_timeline.dart` — up to 5 intermixed
  expense + settlement rows ordered by `date` desc; a "View full
  history" affordance opens the Haldi 12 `friend_history_screen.dart`
  (the full month-grouped, signed-amount log).
- `widgets/friend_detail_states.dart` — loading skeleton, empty
  state, error state.

`application/friend_detail_provider.dart` is a combined
`StreamProvider.family<FriendDetailState, FriendDetailArgs>` that joins
three real-time reads (friendship doc via
`FriendshipRepository.watchFriendship`, expenses via
`ExpenseRepository.watchExpensesByFriendship`, settlements via
`SettlementRepository.watchByContext`) into the `FriendDetailState`
sealed union (`FriendDetailStateEmpty` / `FriendDetailStatePopulated`;
loading + error are surfaced via the standard `AsyncValue` wrapper).

The balance pill derives from `netBalancePaise()` — the same helper
the friends list uses — so the friends-list chip and the friend-detail
header always agree.

The FAB on the Friend Detail screen opens `AddExpenseBottomSheet` from
the expenses feature folder (the call site was preserved verbatim from
the FR-FR-03 placeholder so PR #38 needed no change at swap-time).

### FR-SE-05 / FR-SE-07 — Settle Up CTA on Friend Detail (PR #43)

PR #43 inserts an `OBTSettleUpCard` between the header and the
timeline on `FriendDetailScreen` when
`header.balanceState == BalanceState.owes` (the current user owes the
friend). The **receiving direction** (`netBalancePaise > 0`, the friend
owes the current user) now also renders an `OBTSettleUpCard` — its
receiving-direction variant with a **Send Reminder** CTA — via the
`_ReceivingDirectionCard` host, wired to the `reminders` feature folder
(FR-SE-09). See `lib/features/reminders/README.md`.

Tapping the card fires `settle_up_tapped { source: 'friend_detail',
friendship_id_hash }` and opens `SettleUpBottomSheet` from the
`settlements` feature folder. The bottom sheet's controller writes to
the top-level `settlements/{auto-id}` collection; the
`onSettlementWrite` trigger (PR #37) folds the new doc into
`simplifiedBalances` and the friendship-doc snapshot stream re-emits,
flipping the header pill toward `Settled up` within NFR-PE-04's
2.5 s P95 budget.

- `widgets/obt_settle_up_card.dart` — reusable card with payer
  avatar → arrow → payee avatar + suggested amount. The owes-direction
  variant shows a Settle Up CTA (settlements); the receiving-direction
  variant (`isReceivingDirection: true`, with `nextAllowedAt` +
  `onSendReminder`) shows a Send Reminder CTA (reminders).
  Lives under `friends/` because the host is
  `FriendDetailScreen`; future hosts (Home Dashboard FR-HD-02; Group
  Detail FR-GR-04) will lift the widget into a shared design-system
  folder per the `OBTAmountInput` extraction precedent from PR #38.

PR #43 also extends `_SettlementRow` in
`widgets/friend_detail_timeline.dart` with a payer-aware label
(review §R3 / AC-9):

- `fromUserId == currentUserUid` → `"You paid [Friend's first name] ₹X.XX"`
- `fromUserId == otherUserUid` → `"[Friend's first name] paid you ₹X.XX"`

Telemetry:

- `friends_list_viewed` (single-fire per screen instance) — PR #35
- `friend_row_tapped` with hashed `friendship_id_hash` — PR #35
  (parameter key renamed from `friendship_id` in PR #43 review §R4
  for consistency with PR #42's `friend_detail_viewed` parameter)
- `friends_empty_add_tapped` — PR #35
- `friend_detail_viewed` (single-fire per screen instance) with
  `friendship_id_hash` + `balance_state` (`owed` / `owes` /
  `settled`) — PR #42
- `settle_up_tapped { source: 'friend_detail', friendship_id_hash }`
  — PR #43

All `friendship_id` values flow through `hashFriendshipId()` from
`core/telemetry/event_id_hash.dart` before emission.

## Layout

```
application/
  contact_permission_provider.dart
  contact_picker_controller.dart
  friend_detail_provider.dart        # FR-FR-04 combined provider
  friend_history_provider.dart       # DC-06 read-only full history (Haldi 12)
  friends_list_provider.dart         # FR-FR-03 stream provider
  match_and_invite_controller.dart
  user_profile_provider.dart         # cached per-uid profile family
data/
  contact_service.dart
  friendship_repository.dart         # store / repo / fake; watchFriendship added in PR #42
  matching_callable_adapter.dart     # cloud_functions bridge for lookup callable
  matching_repository.dart
  share_service.dart
domain/
  contact_permission_state.dart
  friend_list_item.dart
  friendship_doc.dart                # strict-parsing simplifiedBalances
  phone_normaliser.dart
  selected_contact.dart
presentation/
  add_friend_screen.dart
  friend_detail_screen.dart          # PR #42 — replaces placeholder; PR #43 inserts OBTSettleUpCard
  friend_history_screen.dart         # DC-06 — net-new Haldi 12 (month-grouped, signed)
  friends_list_screen.dart
  match_and_invite_screen.dart
  widgets/
    contact_list_tile.dart
    empty_contacts_state.dart
    friend_detail_header.dart        # PR #42; DC-06 → shared OBTBalancePill
    friend_detail_states.dart        # PR #42
    friend_detail_timeline.dart      # PR #42; PR #43 §R3 payer-aware settlement labels
    friend_list_tile.dart            # DC-06 → shared OBTBalancePill
    manual_phone_entry_tab.dart
    obt_settle_up_card.dart          # PR #43 (FR-SE-07)
    permission_denied_view.dart
    phone_selector_bottom_sheet.dart
    transaction_visuals.dart         # DC-06 — category-hue tile + mapping
```

## Invariants honoured

- **Invariant 1 (integer paise):** every monetary value originates as
  `int`; the only paise → INR conversion is via `formatInrFromPaise()`.
  Boundary-contract grep tests in
  `test/features/friends/friends_list_boundary_contract_test.dart` and
  `test/features/friends/friend_detail_boundary_contract_test.dart`
  enforce this on all read-side files.
- **Invariant 2 (`simplifiedBalances` server-maintained):** every read
  goes through `netBalancePaise()`; no client write to the field. The
  same boundary tests enforce this.
- **Invariant 3 (system share sheet only):** the share path uses
  `ShareService` which delegates to the platform share sheet.
- **Invariant 4 (single Firebase project):** every Firestore /
  Functions read goes through the single production project. Pre-merge
  verification runs against the Firebase Emulator Suite.

## Hand-off boundaries

- **Out:** the FAB call site for adding an expense lives on
  `FriendDetailScreen`; the bottom sheet itself
  (`AddExpenseBottomSheet`) is owned by the `expenses` feature folder.
- **Out:** the Settle Up CTA opens `SettleUpBottomSheet` from the
  `settlements` feature folder; the receiving-direction Send Reminder
  CTA is driven by the `reminders` feature folder (FR-SE-09).
- **Out:** `simplifiedBalances` is written exclusively by the
  `recomputeSimplifiedBalances` Cloud Function in
  `functions/src/simplified-debts/`.
- **In (read-only):** `simplifiedBalances` map projected via
  `netBalancePaise()`.
