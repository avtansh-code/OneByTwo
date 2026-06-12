# Expenses

Feature-folder that owns expense capture, splitting, receipts, and
edit/delete for the **friendship** context: Add Expense (FR-EX-01),
receipt attachment (FR-EX-05), and the Expense Detail screen with
edit/delete (FR-EX-06). Group context (FR-EX-02) is deferred.

## Implemented scope

### FR-EX-01 / FR-EX-05 — Add Expense (three-step bottom sheet)

`AddExpenseBottomSheet` (SCR-19/20/21) on the Friend Detail screen,
friendship context only:

- **Step 1 — Amount, description, category, date.** Indian-numbering
  amount input (`OBTAmountInput`, emits paise), 8 categories (food,
  travel, rent, utilities, groceries, entertainment, shopping, other),
  date defaulting to today.
- **Step 2 — Split method and payer.** `equal` and `exact` enabled
  (`isSplitMethodEnabled` in `split_method.dart`); `unequal` /
  `percentage` / `shares` render as disabled "Coming soon" chips.
  `exact` splits gate Save on `sum(shares) == amountPaise` (FR-EX-04).
- **Step 3 — Receipt and confirm (FR-EX-05).** Optional receipt image
  (camera / gallery), validated client-side (10 MB cap; JPEG/PNG only),
  uploaded via `ReceiptStorageService` to
  `receipts/friendships/{fid}/{eid}`, plus a read-only summary card.
- **Save** writes a new doc under `friendships/{fid}/expenses/{eid}` via
  `ExpenseRepository.createExpense` (`ExpenseDoc.toCreateMap()`,
  `deleted: false`). The Cloud Function `onExpenseWriteFriendship`
  (FR-SE-03/04) is the sole writer of `simplifiedBalances` — this
  feature never touches that field.

### FR-EX-06 — Expense Detail, edit and delete

- `application/expense_detail_provider.dart` — `expenseDetailProvider`,
  a `FutureProvider.autoDispose.family<ExpenseDoc?, ExpenseDetailArgs>`
  one-shot read of `friendships/{fid}/expenses/{eid}`.
- `presentation/expense_detail_screen.dart` — `ExpenseDetailScreen`
  (SCR-22), a read-only detail view reached from the friend-detail
  timeline. The **Edit** AppBar action re-opens `AddExpenseBottomSheet`
  in edit mode (`ExpenseDoc.toUpdateMap(changedFields)`); the **Delete**
  action shows a destructive `OBTConfirmationDialog` and performs a
  soft delete. Both actions are rendered only when the current user
  created the expense (defence-in-depth over the rules).
- `presentation/widgets/changed_field_indicator.dart` —
  `ChangedFieldIndicator`, the edit-mode "changed" affordance.
- `presentation/widgets/receipt_fullscreen_viewer.dart` —
  `ReceiptFullscreenViewer`, the tap-to-zoom receipt viewer.

### Telemetry (`expense_telemetry.dart`)

- **FR-EX-01 funnel:** `expense_step1_opened` / `_completed` /
  `_abandoned`, `expense_category_selected`, `expense_step2_opened` /
  `_completed` / `_abandoned`, `expense_split_method_changed`,
  `expense_payer_changed`, `expense_split_validation_failed`,
  `expense_save_succeeded` / `expense_save_failed`.
- **FR-EX-05 receipts:** `expense_step3_opened`,
  `expense_receipt_attached` (`source`, `file_size_bytes`),
  `expense_receipt_removed`, `expense_step3_abandoned`.
- **FR-EX-06 edit:** `expense_edit_opened`, `expense_edit_field_changed`,
  `expense_edit_saved`, `expense_edit_failed`, `expense_edit_abandoned`.
- **FR-EX-06 delete:** `expense_delete_initiated`,
  `expense_delete_confirmed`, `expense_delete_cancelled`,
  `expense_delete_failed`.

All `friendship_id` and `expense_id` values are SHA-256-truncated via
`hashFriendshipId()` / `hashId()` from `core/telemetry/event_id_hash.dart`.

## Layout

```
application/
  add_expense_controller.dart   # StateNotifier + telemetry (add + edit + delete + receipt)
  expense_detail_provider.dart  # FutureProvider.autoDispose.family<ExpenseDoc?, …>
  expense_telemetry.dart        # event-name + param-key constants
data/
  expense_repository.dart       # ExpenseStore (abstract), Firestore impl, repo wrapper
  receipt_storage_service.dart  # FR-EX-05 receipt upload/delete (Firebase Storage)
domain/
  add_expense_state.dart        # sealed Editing/Saving/Uploading/Success/AddExpenseError
  expense_category.dart         # 8-value enum + label/icon map
  expense_create_error.dart     # typed error + ExpenseCreateErrorType
  expense_delete_error.dart     # typed error + ExpenseDeleteErrorType
  expense_doc.dart              # Firestore shape: toCreateMap / toUpdateMap / fromMap
  expense_draft.dart            # UI draft model
  expense_update_error.dart     # typed error + ExpenseUpdateErrorType
  receipt_upload_error.dart     # typed error + ReceiptUploadErrorType
  split_calculator.dart         # pure integer splitter
  split_method.dart             # enum + isSplitMethodEnabled (equal + exact)
presentation/
  add_expense_bottom_sheet.dart # root sheet host (add + edit modes)
  expense_detail_screen.dart    # SCR-22 read-only detail + edit/delete actions
  steps/
    step_1_amount_details.dart
    step_2_split_and_payer.dart
    step_3_receipt_and_confirm.dart
  widgets/
    changed_field_indicator.dart
    expense_category_grid.dart
    receipt_fullscreen_viewer.dart
    split_row.dart
    split_validation_message.dart
```

## Deferred extension points

- **Group context (FR-EX-02).** Only friendship context is supported;
  the `context_type` telemetry param is always `'friendship'`.
  `ReceiptStorageService` exposes only the friendship upload/delete
  methods today; a group-context method does not exist yet (it is noted
  as future work in that file). Pairs with the deferred
  `onExpenseWriteGroup` trigger.
- **Unequal / percentage / shares splits.** Chips visible but disabled
  with "Coming soon" tooltips. Lift the gate in `split_method.dart`
  (`isSplitMethodEnabled`) when each method ships.
- **Notes field.** Step 1 has no dedicated notes input yet (`has_notes`
  reflects the description field).
- **Multi-context entry point.** The Add Expense FAB is reachable from
  the Friend Detail screen and the shell's Add-Expense context picker
  (friend selection only); the Home dashboard (FR-HD) and Group Detail
  (FR-GR-04) entry points ship with those surfaces.
- **`recurringRule`** — extension-point lock per `ARCH-EXT-06` (not in
  the write shape).

## Hand-off seams

- **FR-FR-03 friends list / FR-FR-04 Friend Detail (upstream UI):** the
  Add Expense FAB call site lives on `FriendDetailScreen` (friends
  feature) and in the shell's context picker; the post-write net balance
  re-renders automatically because the friends surfaces stream
  `simplifiedBalances` via `core/balances/net_balance.dart` and format
  with `core/formatters/inr_formatter.dart#formatInrFromPaise`.
- **FR-AC-01 activity feed (downstream read):** the activity feature
  reads the same `friendships/{fid}/expenses/{eid}` documents this
  feature writes; no new write surface is required.
- **FR-SE-03/04 `onExpenseWriteFriendship` (downstream write side):**
  every create / edit / soft-delete from `ExpenseRepository` invokes the
  trigger, which is the sole writer of `simplifiedBalances` and
  `lastActivityAt`.

## Invariants honoured

- **Invariant 1 (integer paise):** `amountPaise` / `sharePaise` are
  always `int`; `OBTAmountInput` emits paise and `formatInrFromPaise` is
  the sole display conversion. No `double`, no `.toDouble()`, no inline
  `/ 100`. The boundary-contract grep test enforces this across the
  feature.
- **Invariant 2 (`simplifiedBalances` server-maintained):**
  `simplifiedBalances` is read-only from this feature; the
  `onExpenseWriteFriendship` trigger is the sole writer.
- **Invariant 3 (system share sheet only):** N/A — no share surface.
- **Invariant 4 (single Firebase project):** all Firestore and Storage
  reads/writes go through the single production project; pre-merge
  verification runs against the Firebase Emulator Suite.
- **PII-hashed telemetry:** every `friendship_id` / `expense_id`
  parameter uses the `_hash` suffix and SHA-256 truncation.
