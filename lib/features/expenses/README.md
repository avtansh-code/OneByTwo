# Expenses

Feature-folder that owns expense capture, splits, and (later) editing/deletion
for friendship and group contexts.

## Implemented scope (FR-EX-01)

Two-step **Add Expense** bottom sheet on the Friend Detail screen, friendship
context only:

- **Step 1 — Amount, description, category, date.** Indian-numbering amount
  input (`OBTAmountInput`), 8 categories (food, travel, groceries, rent,
  utilities, entertainment, shopping, other), date defaulting to today.
- **Step 2 — Split method and payer.** `equal` and `exact` enabled;
  `unequal`/`percentage`/`shares` rendered as disabled chips with "Coming
  soon" tooltips (Telemetry-plan locks honoured).
- **Save** writes a new doc under `friendships/{fid}/expenses/{eid}` via the
  `ExpenseRepository`. The Cloud Function `onExpenseWriteFriendship`
  (FR-SE-03/04) is the sole writer of `simplifiedBalances` — this feature
  never touches that field.

Telemetry (Camp B names — see `expense_telemetry.dart`):

- `expense_step1_opened` / `expense_step1_completed` / `expense_step1_abandoned`
- `expense_category_selected`
- `expense_step2_opened` / `expense_step2_completed` / `expense_step2_abandoned`
- `expense_split_method_changed` / `expense_payer_changed`
- `expense_split_validation_failed`
- `expense_save_succeeded` / `expense_save_failed`

All `friendship_id` and `expense_id` values are SHA-256-truncated via
`hashFriendshipId()` / `hashId()` from `core/telemetry/event_id_hash.dart`.

## Layout

```
application/
  add_expense_controller.dart   # StateNotifier + telemetry emission
  expense_telemetry.dart        # event-name + param-key constants
data/
  expense_repository.dart       # ExpenseStore (abstract), FirestoreExpenseStore,
                                # ExpenseRepository concrete wrapper
domain/
  add_expense_state.dart        # sealed Editing/Saving/Success/AddExpenseError
  expense_category.dart         # 8-value enum + label/icon map
  expense_create_error.dart     # typed error + ExpenseCreateErrorType
  expense_doc.dart              # Firestore-shape with toCreateMap()
  expense_draft.dart            # UI draft model
  split_calculator.dart         # pure integer splitter
  split_method.dart             # enum (equal + exact enabled in FR-EX-01)
presentation/
  add_expense_bottom_sheet.dart # root sheet + ref.listen side-effects
  steps/
    step_1_amount_details.dart
    step_2_split_and_payer.dart
  widgets/
    expense_category_grid.dart
    split_row.dart
    split_validation_message.dart
```

## Deferred extension points

- **Step 3 (receipt upload)** — FR-EX-05. `ExpenseDoc.receiptUrl` is wired
  but always `null` in FR-EX-01. Candidate for the next PR per
  `docs/sprint-zero/next-three-prs.md`.
- **Notes field** — Step 1 has no notes input yet (`has_notes` always
  `false` in `expense_step1_completed` / `expense_save_succeeded`).
- **Unequal / percentage / shares splits** — chips visible but disabled
  with "Coming soon" tooltips. Lift the three locks in `split_method.dart`
  when each method ships.
- **Edit / delete expense** — FR-EX-06. The FR-EX-01 bottom-sheet scaffold,
  `split_calculator`, and `ExpenseRepository` write path are reusable for
  edit. Soft-delete is already accepted by the FR-SE-03/04 trigger and
  the FR-SE-05/06 rules. Candidate for the next PR.
- **Activity feed** — FR-EX-07. Chronological list of expenses and
  settlements across all friendships and groups. Reads the same
  `friendships/{fid}/expenses/{eid}` documents this feature writes; no
  new write surface required.
- **Group context** — FR-EX-02. Only friendship context is supported in
  FR-EX-01; `context_type` telemetry param is always `'friendship'`. Pairs
  with the deferred `onExpenseWriteGroup` trigger (FR-SE-03/04 architect
  notes §2).
- **Multi-context entry point** — the Add Expense FAB in FR-EX-01 lives on
  the placeholder Friend Detail screen only. The Home dashboard
  (FR-HD-01) and Group Detail (FR-GR-04) FABs will invoke the same
  bottom-sheet sequence with the relevant `context_type` once those
  surfaces ship.
- **`recurringRule`** — extension-point lock per `ARCH-EXT-06` (not in
  the write shape).

## Hand-off seams

- **FR-FR-03 friends list (upstream read side):** the post-expense net
  balance re-renders automatically. This feature triggers no manual
  refresh; `friends_list_screen.dart` streams `simplifiedBalances`
  directly via `core/balances/net_balance.dart` and formats with
  `core/formatters/inr_formatter.dart#formatInrFromPaise`.
- **FR-FR-03 Friend Detail placeholder (upstream UI entry):** the Add
  Expense FAB is wired on `FriendDetailPlaceholderScreen`. FR-FR-04
  (Friend Detail full screen) will replace the placeholder; the FAB
  call site is preserved.
- **FR-SE-03/04 `onExpenseWriteFriendship` (downstream write side):**
  every write from `ExpenseRepository` to
  `friendships/{fid}/expenses/{eid}` invokes the trigger. The trigger
  is the sole writer of `simplifiedBalances` and `lastActivityAt`;
  this feature writes neither.

## Invariants honoured

- **Money is integer paise** (`amountPaise`, `sharePaise`). No `double`, no
  `.toDouble()`, no inline `/100`. Display via
  `core/formatters/inr_formatter.dart#formatInrFromPaise`.
- **`simplifiedBalances` is read-only** from this feature.
- **PII-hashed telemetry** — every `friendship_id` / `expense_id` parameter
  uses the `_hash` suffix and a SHA-256 truncation.
