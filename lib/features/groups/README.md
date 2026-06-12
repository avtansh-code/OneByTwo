# Groups

> **Status: not yet implemented in the client.** This feature folder is
> greenfield — it currently contains **no Dart code**, only this README.

The Groups epic (FR-GR-01 … FR-GR-07: group create, invite members,
group detail, group expenses/settlements, member removal, leave, delete)
is planned for the Sprint 3 Groups epic and has no Flutter UI or state
yet.

## What exists today

- **Server-side schema and rules only.** The Firestore `groups`
  collection schema is defined in
  `docs/design/07-technical/firestore-schema.md`, and its security rules
  ship in `firestore.rules`. These are owned by the Architect and the
  Functions Dev; they exist so the data layer is ready before the client
  is built.
- **A shell placeholder, hosted elsewhere.** The Groups bottom-nav tab
  renders `GroupsListPlaceholder` from
  `lib/features/shell/presentation/groups_list_placeholder.dart` (a
  "coming soon" stand-in), and the Add-Expense context picker shows a
  disabled "Coming in Sprint 3" Groups row
  (`lib/features/shell/presentation/add_expense_context_picker_sheet.dart`).
  Both live under the `shell` feature, not here.

## Planned scope (not built)

When the Groups epic lands, this folder will follow the standard
feature-first layout (`application/`, `data/`, `domain/`,
`presentation/` + `presentation/widgets/`) used by every other feature.
Some seams already anticipate a group context, while others are
friendship-only today and will need extending:

- `SettlementRepository` already takes a `contextType` argument
  (`watchByContext(contextType:, contextId:)` and the create path); only
  the `'friendship'` arm is exercised today.
- `SettlementHistoryScreen` is generic over `(contextType, contextId)`
  (its constructor requires both), so a future Group Detail screen can
  push it with `contextType: 'group'`.
- `ExpenseRepository` is currently keyed by `friendshipId` (not a generic
  `contextType`); the group surface will need an additional path.
- `ReceiptStorageService` exposes only `uploadFriendshipReceipt` /
  `deleteFriendshipReceipt` today. A group-context method does not exist
  yet; it is noted as future work in that file's documentation
  (path convention `receipts/{contextType}/{contextId}/{expenseId}`).

## Invariants (apply once built)

- **Invariant 1 (integer paise):** all group balances and expense
  amounts must be `int` paise, displayed via `formatInrFromPaise`.
- **Invariant 2 (`simplifiedBalances` read-only):** a group's
  `simplifiedBalances` map is written only by the
  `recomputeSimplifiedBalances` Cloud Function; the client reads it.

## Hand-off boundaries

- **In (read-only):** `groups/{groupId}` documents and their
  server-maintained `simplifiedBalances`.
- **Out:** schema, indexes and security rules belong to the Architect;
  the `recompute` / write triggers belong to the Functions Dev.
