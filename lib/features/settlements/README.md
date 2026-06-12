# Settlements

Feature-folder that owns the "settle up" surfaces: settlement creation
(FR-SE-05, PR #43), settlement history (FR-FR-04 in-timeline read path,
PR #42, plus the dedicated `/settle/history` screen for the friendship
axis, FR-SE-08 / SCR-24), and payment reminders (FR-SE-09).

## Implemented scope

### Read path (PR #42)

PR #42 ships the read-only scaffolding required by the FR-FR-04 Friend
Detail screen:

- `domain/settlement_doc.dart` — immutable value type for a
  `settlements/{settlementId}` document. The `fromFirestore` factory
  applies strict type and shape validation:
  - Missing required field → returns `null` and fires `onParseFailure`.
  - Wrong type (e.g., `amountPaise` as `String` / `double`) → same.
  - Non-positive `amountPaise` (Invariant 1) → same.
  - Soft-deleted docs (`deleted == true`) still parse — the repository
    layer filters them out at the next layer.
- `data/settlement_repository.dart` — abstract `SettlementStore`,
  `FirestoreSettlementStore` (production), `SettlementRepository`
  wrapper, `settlementRepositoryProvider`. Mirrors the
  `FriendshipStore` (PR #35) and `ExpenseStore` (PR #38) patterns so
  tests inject a `FakeSettlementStore` (no `fake_cloud_firestore`
  dependency in `pubspec.yaml`).
- `SettlementRepository.watchByContext({contextType, contextId})` is
  the canonical read entry point. Soft-deleted entries are excluded
  from the projected list.

### Write path (PR #43, FR-SE-05 / FR-SE-06 / FR-SE-07)

PR #43 closes the symmetric write-side of the simplified-debts
round-trip:

- `domain/settle_up_draft.dart` — immutable in-memory form state
  (`suggestedAmountPaise`, `amountPaise`, `date`, `note`). All
  monetary fields are integer paise (Invariant 1). `validate()`
  returns field-keyed errors (`amount` / `note`); `canonicalNote`
  folds empty / whitespace-only input to `null` per the §2.3 canonical
  write form. `isPartial = amount < suggested` drives the
  `is_partial` telemetry parameter.
- `domain/settlement_create_error.dart` — `SettlementCreateError`
  exception + `SettlementCreateErrorType` discriminated union
  (`permissionDenied`, `network`, `balanceChanged`, `invalidAmount`,
  `unknown`). Each value maps to a user-facing message via
  `userFacingMessage` and to the `settle_up_error { error_code }`
  parameter via `telemetryErrorCode`.
- `data/settlement_repository.dart` — extended with
  `SettlementStore.createSettlement({data})` on the abstract store and
  `SettlementRepository.createSettlement({doc})` on the wrapper.
  The repository translates `FirebaseException` codes into the typed
  `SettlementCreateError`:
  - `permission-denied` → `permissionDenied`
  - `unavailable` → `network`
  - other → `unknown`
- `domain/settlement_doc.dart` — extended with `toCreateMap()`
  producing the exact Firestore-shaped map satisfying every predicate
  in `firestore.rules` lines 379–489 (PR #37 rules):
  - 12 whitelisted keys (`fromUserId`, `toUserId`, `amountPaise`,
    `contextType`, `contextId`, `date`, `note`, `method`,
    `verificationStatus`, `currency`, `createdAt`, `deleted`)
  - `createdAt = FieldValue.serverTimestamp()` (satisfies
    `createdAt == request.time`)
  - `method = 'manual'`, `currency = 'INR'`,
    `verificationStatus = 'unverified'` (ARCH-EXT-01 / 02 / 06)
  - `deleted = false` (soft-delete is a separate update path)
- `application/settle_up_telemetry.dart` — event-name + parameter-key
  constants for the five settle-up events: `settle_up_tapped`,
  `settle_up_screen_viewed`, `settlement_recorded`,
  `settle_up_error`, `settle_up_validation_failed`. Includes
  `amountRangeFor()` (4-bucket spec shared with `ExpenseTelemetry`).
- `application/settle_up_state.dart` — sealed `SettleUpState`
  hierarchy: `SettleUpEditing`, `SettleUpSaving`, `SettleUpSuccess`,
  `SettleUpError`.
- `application/settle_up_controller.dart` —
  `StateNotifier<SettleUpState>`, family-keyed by
  `SettleUpArgs { friendshipId, currentUserUid, otherUserUid,
  otherDisplayName, suggestedAmountPaise }`. Setters
  `setAmount(int) / setDate(DateTime) / setNote(String?)` re-run
  `draft.validate()` and emit a new `SettleUpEditing`. `save()`
  transitions Editing → Saving → (Success | SettleUpError) and emits
  the appropriate telemetry. Validation-failure path fires
  `settle_up_validation_failed` and is a no-op.
- `presentation/settle_up_bottom_sheet.dart` — root host. Drag handle
  + sheet title + `SettleUpHeader` + `OBTAmountInput` (PR #38 extract)
  + date picker + optional note field + Record Settlement button.
  `ref.listen<SettleUpState>` drives the success snackbar +
  auto-dismiss / error snackbar. `settle_up_screen_viewed` fires
  exactly once via `addPostFrameCallback`.
- `presentation/widgets/settle_up_header.dart` — payer avatar →
  arrow → payee avatar row with centred suggested-amount echo.

The host wires the bottom sheet via
`lib/features/friends/presentation/widgets/obt_settle_up_card.dart`
(extracted under `friends/` because the card is a navigational
affordance hosted by the friends context; the settlement write logic
lives here). When `header.balanceState == BalanceState.owes`,
`FriendDetailScreen` renders the card between the header and the
timeline; tapping the card fires `settle_up_tapped { source:
'friend_detail' }` and opens the bottom sheet.

Per Architect Notes §2.5, the **receiving direction** (friend owes
current user) ships **without** the card in PR #43; FR-SE-09 Send
Reminder ships that branch.

### Settlement history screen (FR-SE-08 / SCR-24)

PR #58 closes the FR-SE-08 P0 commitment for the dedicated full-history
surface (friendship axis; the group axis is wired by the Sprint 3 Group
Detail screen). The screen reuses the PR #42 read path verbatim — zero
changes to `settlement_repository.dart`, `firestore.rules`, or
`firestore.indexes.json`.

- `application/settlement_history_telemetry.dart` — event-name +
  parameter-key constants for the two pre-declared events
  (`settlement_history_viewed { context_type, item_count }`,
  `settlement_history_error { error_code, context_type }`). NEITHER
  event carries `context_id` (PII guard, ADR-0013).
- `application/settlement_history_provider.dart` —
  `settlementHistoryProvider`, a `StreamProvider.family` keyed by
  `SettlementHistoryArgs { contextType, contextId }`. Reuses
  `SettlementRepository.watchByContext` and applies a 50-item cap
  (`settlementHistoryItemCap`) over the projected list.
- `presentation/settlement_history_screen.dart` — the SCR-24
  `ConsumerStatefulWidget`. Four states (loading / populated / empty /
  error) via inline private widgets (no OBT* primitive extraction per
  Architect Notes §2.3). Per-row layout: inline `dd MMM yyyy` date,
  payer avatar → arrow → payee avatar, `formatInrFromPaise()` amount,
  optional muted note. `settlement_history_viewed` fires exactly once
  on the first resolved frame; `settlement_history_error` fires once on
  the first error frame. Generic over `(contextType, contextId)` so the
  Sprint 3 Group Detail surface can push it with `contextType: 'group'`.

The entry point is the **"View Settlement History"** text link on
`FriendDetailScreen`, shown unconditionally in the populated state and
hidden in the empty state. The tap pushes the screen via
`MaterialPageRoute` with `contextType: 'friendship'`. No entry-point
telemetry — the destination's `settlement_history_viewed` captures the
funnel arrival (Architect Notes §2.6).

## Layout

```
application/
  settle_up_controller.dart       # StateNotifier + SettleUpArgs family
  settle_up_state.dart            # sealed SettleUpState hierarchy
  settle_up_telemetry.dart        # event / param constants + amountRangeFor
data/
  settlement_repository.dart      # store + Firestore impl + repo (R+W)
domain/
  settle_up_draft.dart            # immutable form state + validation
  settlement_create_error.dart    # typed exception + enum
  settlement_doc.dart             # strict-parsing value type + toCreateMap
presentation/
  settle_up_bottom_sheet.dart     # root sheet host
  widgets/
    settle_up_header.dart         # payer → arrow → payee + amount echo
```

## Invariants honoured

- **Invariant 1 (integer paise):** every `amountPaise` field — on
  the draft, on the repository call, on the Firestore payload — is
  `int`. `OBTAmountInput.onChanged` emits paise; `formatInrFromPaise()`
  is the sole conversion at the UI boundary. The boundary-contract
  grep test at
  `test/features/settlements/settle_up_boundary_contract_test.dart`
  enforces zero `.toDouble()`, zero `/ 100`, zero `double` decls
  across all settlements source files.
- **Invariant 2 (`simplifiedBalances` server-maintained):** neither
  the controller, the repository, the bottom sheet, the header, nor
  the card touches `simplifiedBalances`. The controller READS the
  field indirectly via the host's `netBalancePaise()` derivation for
  the pre-fill. The `onSettlementWrite` trigger (PR #37) is the sole
  writer; `recomputeSimplifiedBalances` folds the new settlement into
  the canonical view in a single transaction.
- **Invariant 2 parallel (ARCH-EXT-06 — `verificationStatus`
  server-maintained):** the field is exposed read-only on
  `SettlementDoc`; the write payload always carries `'unverified'`.
- **Invariant 3 (system share sheet only):** N/A.
- **Invariant 4 (single Firebase project):** every read + write goes
  through the single production project; pre-merge verification runs
  against the Firebase Emulator Suite.

## Hand-off boundaries

- **Out (read):** `SettlementRepository.watchByContext` powers the
  Friend Detail timeline (`lib/features/friends/`).
- **Out (write):** `SettlementRepository.createSettlement` produces
  the top-level `settlements/{auto-id}` doc; `onSettlementWrite`
  (PR #37) consumes it. The friendship-doc snapshot stream emits the
  updated `simplifiedBalances` within NFR-PE-04's 2.5 s P95 budget.
- **In (rules):** Firestore Security Rules on the `settlements/`
  collection were ratified in PR #37 and require
  `fromUserId == request.auth.uid` on create;
  `verificationStatus` is service-account-write-only after the
  initial `'unverified'` value.
- **In (telemetry):** the five PII-hashed events
  (`hashFriendshipId()` / `hashId()` per ADR-0013) — the PII-leak
  test at
  `test/features/settlements/settle_up_pii_leak_test.dart` enforces.

## Out of scope for PR #43

- Home Dashboard `OBTSettleUpCard` host (FR-HD-02 — Home Dashboard
  does not exist yet).
- Group context Settle Up (FR-GR-04 — Sprint 3 groups epic).
- Edit / delete settlement (separate later PR; soft-delete via
  `deleted: false → true` is server-ready per PR #37 rules).
- Send Reminder (FR-SE-09 P1 — separate later PR).
- Settlement Confirmation animation sub-screen (UX-polish later PR).
- Two-sided card orientation when the friend owes the current user
  (§2.5 default-omit; ships with FR-SE-09).

> The dedicated full-history screen (FR-SE-08 P0) was deferred from
> PR #43 and is now shipped by PR #58 — see "Settlement history screen
> (FR-SE-08 / SCR-24)" above.

## Firestore composite index

The settlements composite index in `firestore.indexes.json` was
extended in PR #42 from `(contextType ASC, contextId ASC)` to
`(contextType ASC, contextId ASC, date DESC)` so the canonical query
`where contextType + where contextId + orderBy date desc` runs without
`FAILED_PRECONDITION`. PR #43 does NOT add or modify any index; the
existing composite covers both the read (from PR #42) and the write
path (the trigger's read of `settlements` for recomputation).

