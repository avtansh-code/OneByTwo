# Expenses

Feature-folder that owns expense capture, splits, and (later) editing/deletion
for friendship and group contexts.

## Implemented scope (PR #38 — FR-EX-01)

Two-step **Add Expense** bottom sheet on the Friend Detail screen, friendship
context only:

- **Step 1 — Amount, description, category, date.** Indian-numbering amount
  input (`OBTAmountInput`), 8 categories (food, travel, groceries, rent,
  utilities, entertainment, shopping, other), date defaulting to today.
- **Step 2 — Split method and payer.** `equal` and `exact` enabled;
  `unequal`/`percentage`/`shares` rendered as disabled chips with "Coming
  soon" tooltips (Telemetry-plan locks honoured).
- **Save** writes a new doc under `friendships/{fid}/expenses/{eid}` via the
  `ExpenseRepository`. The Cloud Function `onExpenseWriteFriendship` (PR #36)
  is the sole writer of `simplifiedBalances` — this feature never touches
  that field.

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
  split_method.dart             # enum (equal + exact enabled in PR #38)
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

- **Step 3 (receipt upload)** — FR-EX-05 (`ExpenseDoc.receiptUrl` is wired but
  always `null` in PR #38).
- **Notes field** — Step 1 has no notes input yet (`has_notes` always `false`
  in `expense_step1_completed` / `expense_save_succeeded`).
- **Unequal / percentage / shares splits** — chips visible but disabled with
  "Coming soon" tooltips.
- **Group context** — only friendship context is supported in PR #38;
  `context_type` telemetry param is `'friendship'`.
- **`recurringRule`** — extension-point lock per `ARCH-EXT-06` (not in the
  write shape).

## Invariants honoured

- **Money is integer paise** (`amountPaise`, `sharePaise`). No `double`, no
  `.toDouble()`, no inline `/100`. Display via
  `core/formatters/inr_formatter.dart#formatInrFromPaise`.
- **`simplifiedBalances` is read-only** from this feature.
- **PII-hashed telemetry** — every `friendship_id` / `expense_id` parameter
  uses the `_hash` suffix and a SHA-256 truncation.
