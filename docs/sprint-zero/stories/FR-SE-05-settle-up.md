# FR-SE-05 / FR-SE-06 / FR-SE-07: Settle Up flow (Friend Detail)

> Implementation-ready user story for the symmetric write-side closure of
> the simplified-debts round-trip. Tap a `Settle Up` CTA on the Friend
> Detail screen → record a settlement → trigger fires → simplified
> balances recompute → header pill and timeline re-render in real-time.

---

## SRS Requirement ID(s)

FR-SE-05 (SRS section 4.6 — Record a settlement; the Settle Up UI shall
pre-fill the recipient and amount from the simplified-debts suggestion),
FR-SE-06 (SRS section 4.6 — Real-time balance update after a settlement
is recorded), FR-SE-07 (SRS section 4.6 — Settle Up CTA on every screen
that displays a non-zero simplified balance).

FR-SE-08 (SRS section 4.6 — View settlement history per friend and per
group) is **already partially delivered** by PR #42 (the in-timeline
settlement rows on Friend Detail). The dedicated full-history screen at
`/settlements/history` is OUT OF SCOPE for this story; a separate later
PR will deliver it.

## Relevant SRS Sections

- Section 4.6 — Simplify & Settle (FR-SE-05, FR-SE-06, FR-SE-07).
- Section 5.6 — Settle Up flow.
- Section 5.9 — Localisation and internationalisation.
- Section 5.10 — Observability.
- Section 6.3 item 9 — Canonical Settle Up flow.
- Section 6.4 — Loading, empty, and error states.
- Section 7.3 — Key architectural decisions (Invariants 1 and 2 — write-side).
- Section 7.5 — Security rules (already shipped in PR #37 for settlements).
- Section 13.2 — Story format (this document).

## Priority

**P0 — Must have**

## Story Points

5

## User Story

As a **signed-in user**,
I want to **record a settlement against a non-zero simplified balance with
a friend in two taps**,
so that **my outstanding balance updates in real-time and the friend and I
both see an accurate ledger without me having to manually subtract the
amount from each prior expense**.

## Preconditions

1. User is authenticated and a member of the friendship `friendshipId`.
2. The friendship document exists at `friendships/{friendshipId}` with
   `memberIds == [currentUid, friendUid]` (sorted) and a non-zero
   `simplifiedBalances` projection between the two members.
3. The top-level `settlements/{settlementId}` collection accepts client
   writes that satisfy the rules shipped in PR #37 (`firestore.rules`
   lines 379–489). The trigger `onSettlementWrite` is live at
   `asia-south1` and folds settlements into `simplifiedBalances`
   atomically (PR #37 also shipped this).
4. `simplifiedBalances` on the friendship document is maintained
   exclusively by the `recomputeSimplifiedBalances` Cloud Function
   (Invariant 2). Clients may read it but must never write to it.
5. PR #42 has merged: `FriendDetailScreen`, `friendDetailProvider`,
   `SettlementRepository.watchByContext`, the in-timeline settlement
   rows, and the reserved card position between header and timeline all
   exist in production.
6. The app uses the single configured Firebase project; pre-merge
   verification runs against the Firebase Emulator Suite (Invariant 4).

---

## Acceptance Criteria

### AC-1 — Settle Up CTA on Friend Detail (FR-SE-07)

> Given I am viewing `FriendDetailScreen` for a friendship with a non-zero
> net balance
> When the populated state renders
> Then an `OBTSettleUpCard` is visible between the header and the timeline
> showing payer avatar → arrow → payee avatar, the suggested amount
> derived from `|netBalancePaise|` formatted via `formatInrFromPaise()`,
> and a `Settle Up` CTA
> And the card is rendered in the design-system surface colour with the
> arrow direction reflecting the sign of `netBalancePaise` (per
> Architect Notes §2.5)

### AC-2 — Settled state suppresses the CTA

> Given `netBalancePaise == 0` (Architect Notes §2.5 also defaults to
> omitting the card when `netBalancePaise > 0` — the friend owes me —
> because FR-SE-09 Send Reminder is out of scope; the receiving direction
> ships without a card in this PR)
> When the populated or empty state renders
> Then the `OBTSettleUpCard` is NOT rendered
> And the header pill reads `Settled up` (PR #42 behaviour preserved)

### AC-3 — Open the Settle Up flow

> Given the CTA is visible (current user owes the friend)
> When the user taps the CTA
> Then the Settle Up bottom sheet opens with the recipient identity
> pre-bound (the friend), the amount pre-filled to `|netBalancePaise|`,
> the date defaulting to today, and the note field empty
> And the analytics event `settle_up_tapped` fires exactly once with
> `source: 'friend_detail'` and `friendship_id_hash:
> hashFriendshipId(friendshipId)`
> And the analytics event `settle_up_screen_viewed` fires exactly once on
> first paint of the bottom-sheet body with
> `context_type: 'friendship'`, `source: 'friend_detail'`, and
> `friendship_id_hash`

### AC-4 — Edit the suggested amount (partial settlement)

> Given the Settle Up flow is open
> When the user edits the amount to a value `>0` AND `<= suggestedAmountPaise`
> Then the inline error is cleared, the Save CTA stays enabled, and the
> eventual write carries `amountPaise == the entered value` (integer
> paise, Invariant 1)
>
> Boundary cases:
>
> - amount == 0 ⇒ inline error `Amount must be greater than zero.` AND
>   Save disabled
> - amount > `suggestedAmountPaise` ⇒ inline error
>   `Amount cannot exceed the outstanding balance of ₹X.XX.` AND Save
>   disabled
>
> The amount editor is the reusable `OBTAmountInput` (PR #38 extract);
> the controller receives integer paise from its `onChanged`.

### AC-5 — Optional note

> When the user enters a note ≤ 200 characters
> Then the value is included in the write payload as `note: <string>`
>
> When the user leaves the note empty
> Then the write payload includes `note: null` (the rules accept both
> absent OR `null`; the architect ratifies `null` as the single canonical
> form at §2.3)
>
> When the note exceeds 200 characters
> Then the inline error reads `Note must be 200 characters or fewer.` AND
> Save is disabled

### AC-6 — Save success path (FR-SE-05 + FR-SE-06)

> Given the form is valid
> When the user taps `Record Settlement`
> Then the controller transitions Editing → Saving, the repository writes
> to `settlements/{auto-id}`, the security rules accept the document,
> the `onSettlementWrite` trigger fires, `simplifiedBalances` updates on
> the friendship doc, the friendship-doc snapshot listener on
> `FriendDetailScreen` emits, and within ≤ 2.5 s P95 (NFR-PE-04) the
> screen re-renders so that:
>
> - the header pill flips toward `Settled up` (full settlement) or shows
>   the reduced remaining balance (partial settlement)
> - the new settlement row appears at the top of the timeline labelled
>   `You paid [Friend's first name] ₹X.XX`
> - the bottom sheet auto-dismisses with the success snackbar
>   `Settlement recorded.`
>
> And the analytics event `settlement_recorded` fires exactly once on
> the Saving → Success transition with:
> `context_type: 'friendship'`,
> `amount_range: <bucketed band>`,
> `is_partial: <bool — true if amount < suggestedAmountPaise>`,
> `friendship_id_hash`,
> `settlement_id_hash: hashId(generatedId)`.

### AC-7 — Save failure path (permission-denied)

> Given the security rules reject the write (e.g. the rules-test seeds a
> doc with `fromUserId != request.auth.uid`)
> When `createSettlement` throws `SettlementCreateError(permissionDenied)`
> Then the controller transitions Saving → SettleUpError(permissionDenied)
> And the bottom sheet remains open
> And an error snackbar reads `Couldn't record the settlement. Please try again.`
> And the analytics event `settle_up_error` fires exactly once with
> `error_code: 'permission_denied'`, `context_type: 'friendship'`, and
> `friendship_id_hash`

### AC-8 — Save failure path (network unavailable)

> Given the device is offline OR Firestore returns `unavailable`
> When `createSettlement` throws `SettlementCreateError(network)`
> Then the controller transitions Saving → SettleUpError(network)
> And the bottom sheet remains open
> And an error snackbar reads `You're offline. The settlement will be recorded when you reconnect.`
> And the analytics event `settle_up_error` fires exactly once with
> `error_code: 'network'`, `context_type: 'friendship'`, and
> `friendship_id_hash`
>
> Note: Firestore's offline persistence queues the write — the snackbar
> is informational; on reconnect the write succeeds without user action.

### AC-9 — Settlement row payer context (review §R3)

> Given a settlement document is rendered in the Friend Detail timeline
> When `doc.fromUserId == currentUserUid`
> Then the row label reads `You paid [Friend's first name] ₹X.XX`
>
> When `doc.fromUserId == otherUserUid`
> Then the row label reads `[Friend's first name] paid you ₹X.XX`
>
> And the amount uses `formatInrFromPaise()` exclusively

### AC-10 — Friends list telemetry key rename (review §R4)

> Given the user taps a row on `FriendsListScreen`
> When `friend_row_tapped` is emitted
> Then the hashed friendship-id is carried under parameter key
> `friendship_id_hash` (renamed from `friendship_id`, matching PR #42's
> `friend_detail_viewed { friendship_id_hash: ... }`)
> And the PII-leak test in
> `test/features/friends/friends_list_pii_leak_test.dart` asserts the
> new key name
> And `docs/design/07-technical/telemetry-plan.md` `friend_row_tapped`
> row reflects the rename

### AC-11 (Negative) — Invariant 1 (paise, write-side) at the boundary

> Given the new Settle Up source files
> When the boundary-contract grep runs over
> `lib/features/settlements/**/*.dart` and
> `lib/features/friends/presentation/widgets/obt_settle_up_card.dart`
> Then the files contain no `.toDouble()`, no inline `/ 100` math, and
> no `double` declarations
> And every user-entered amount flows through `OBTAmountInput.paiseValue`
> as integer paise
> And every paise → INR display uses `formatInrFromPaise()` exclusively

### AC-12 (Negative) — Invariant 2 (`simplifiedBalances` server-maintained)

> Given the new Settle Up source files (controller, repository,
> bottom sheet, header, card)
> When grep checks for `simplifiedBalances\s*[=:]` assignment patterns
> Then the files contain ZERO matches (no assignment, no map-literal
> write)
> And the rules-test from PR #37 — a client attempting
> `update simplifiedBalances` — continues to fail
> And the controller's call to `netBalancePaise(simplifiedBalances: ...)`
> is recognised as a named-argument READ and explicitly allowed (matches
> the FR-FR-04 boundary-contract grep precedent)

---

## Telemetry Events

| Event name | Parameters | Trigger |
|---|---|---|
| `settle_up_tapped` | `source: 'friend_detail'`, `friendship_id_hash: String` | User taps the `OBTSettleUpCard` CTA on Friend Detail |
| `settle_up_screen_viewed` | `context_type: 'friendship'`, `source: 'friend_detail'`, `friendship_id_hash: String` | Bottom sheet first paints body (fires once per sheet open) |
| `settlement_recorded` | `context_type: 'friendship'`, `amount_range: 'under_500' \| '500_5000' \| '5000_25000' \| 'over_25000'`, `is_partial: bool`, `friendship_id_hash: String`, `settlement_id_hash: String` | Saving → Success transition (fires once per successful save) |
| `settle_up_error` | `error_code: 'permission_denied' \| 'network' \| 'invalid_amount' \| 'balance_changed' \| 'unknown'`, `context_type: 'friendship'`, `friendship_id_hash: String` | Saving → SettleUpError transition (fires once per failure) |
| `settle_up_validation_failed` | `field: 'amount' \| 'note'`, `reason: String` | User taps Save while the form is invalid (no Firestore write attempted) |

Deferred — gated on out-of-scope features:

| Event name | Deferred to |
|---|---|
| `settlement_reminder_sent` | FR-SE-09 Send Reminder |
| `settle_up_screen_viewed { source: 'home_dashboard' }` | FR-HD-02 Home Dashboard |
| `settle_up_screen_viewed { source: 'group_detail' }` | FR-GR-04 Group Detail |
| `settlement_history_viewed` | FR-SE-08 dedicated full-history screen |

---

## Invariant Applicability Assessment

| # | Invariant | Applicability |
|---|---|---|
| 1 | Money is integer paise | Applicable — **write-side**. Every `amountPaise` field that lands in Firestore is integer paise emitted by `OBTAmountInput.onChanged` (PR #38 extract). No `double` arithmetic on the path. Display via `formatInrFromPaise()`. |
| 2 | `simplifiedBalances` server-maintained | Applicable — load-bearing READ. The controller calls `netBalancePaise(simplifiedBalances, currentUid, otherUid)` to compute the pre-fill suggestion. No client write of `simplifiedBalances` anywhere on the path; the trigger is the sole writer. |
| 3 | System share sheet only | N/A. This flow does not initiate outbound sharing. |
| 4 | Single Firebase project | Applicable. Writes go to the single production Firebase project; pre-merge verification uses the Emulator Suite. |

---

## Definition of Done

Reference: `docs/design/08-plan/definition-of-ready-and-done.md`

- [ ] Code merged to `main` via approved PR.
- [ ] Unit + widget + controller tests written and passing.
- [ ] Integration test passing against Firebase Emulator Suite (records a
      settlement and asserts the friendship-doc snapshot re-emits with
      `simplifiedBalances` updated within NFR-PE-04's 2.5 s P95 budget).
- [ ] Per-module coverage ≥ 70% on `lib/features/settlements/**` and
      on `lib/features/friends/presentation/widgets/obt_settle_up_card.dart`.
- [ ] QA reviewed and verified acceptance criteria (including the
      negative cases AC-7 + AC-8).
- [ ] Telemetry events in place and firing correctly (PII-leak test green).
- [ ] Accessibility verified (semantic labels on every interactive
      widget per SCR-23 §Accessibility, screen-reader pass, focus order).
- [ ] Dark mode checked (WCAG AA contrast ratios on the card + sheet).
- [ ] Invariant compliance confirmed (all four).
- [ ] Documentation updated (this story file with Architect Notes, sprint
      plan, next-three-prs, `lib/features/settlements/README.md`,
      `lib/features/friends/README.md`, `docs/design/07-technical/telemetry-plan.md`).
- [ ] No open S1 or S2 bugs.

---

## Invariant Compliance

- [ ] Money values are integer paise (Invariant 1) — required for every
      `amountPaise` write and every paise → INR display.
- [ ] No client writes to `simplifiedBalances` (Invariant 2) — required;
      read-only via `netBalancePaise()` for the pre-fill.
- [ ] Uses system share sheet only (Invariant 3) — N/A.
- [ ] Single Firebase project (Invariant 4) — compliant, production only.

---

## Design Artefact References

| Artefact | Path |
|---|---|
| Screen spec | `docs/design/06-screen-specs/23-28-settle-activity-profile.md` (SCR-23 Settle Up; SCR-24 dedicated history screen is DEFERRED) |
| Wireframe | `docs/design/04-wireframes/settle-up-flow.md` (Friend Detail entry point — section 1b) |
| Firestore schema | `docs/design/07-technical/firestore-schema.md` (`settlements/{settlementId}`) |
| Firestore rules | `firestore.rules` lines 379–489 (PR #37 — already shipped) |
| Cloud Functions catalogue | `docs/design/07-technical/cloud-functions-catalogue.md` (`onSettlementWrite` + `recomputeSimplifiedBalances`) |
| State management | `docs/design/07-technical/state-management.md` (settlements feature, write-side) |
| Telemetry plan | `docs/design/07-technical/telemetry-plan.md` (settlement events; friend_row_tapped rename) |
| Extension-point register | `docs/design/03-architecture/extension-points-register.md` (ARCH-EXT-01 `method='manual'`, ARCH-EXT-02 `currency='INR'`, ARCH-EXT-06 `verificationStatus='unverified'`) |
| Decision log | `.github/shared/decision-log.md` (ADR-0001, ADR-0002, ADR-0006, ADR-0007, ADR-0013) |

---

## Responsible Agents

| Agent | Responsibility |
|---|---|
| Flutter Dev | Settle Up bottom sheet, controller, repository write extension, settlement-doc create-map, `OBTSettleUpCard` extraction, `FriendDetailScreen` card wiring, `_SettlementRow` payer-aware labels (review §R3), friends-list analytics key rename (review §R4), all test files, integration test |
| Architect | Architect Notes ratification (§2.1–§2.11), invariants compliance review, extraction decision for `OBTSettleUpCard`, two-sided card orientation decision, telemetry single-fire discipline |
| QA | Manual smoke matrix per Phase 5 step 6, real-time round-trip verification via emulator, error state coverage, accessibility audit, emulator-backed sign-off |
| DevOps | No deployment changes (PR #37 rules already live; PR #42's settlements composite already deployed; no `functions/src/**` changes; no `firestore.indexes.json` changes) |
| Designer | SCR-23 sign-off on card surface + sheet layout; dark-mode contrast; arrow direction for the two-sided orientation |
| PM | Story creation, rolling plan update, follow-up FR-SE-08 dedicated-history-screen story file |

---

## Technical Notes

- **Reuse `OBTAmountInput`.** The PR #38 extract is the single user-input
  surface for paise amounts in the application; the Settle Up sheet
  reuses it verbatim. No parallel implementation. The widget's
  `onChanged: ValueChanged<int>` emits integer paise; the controller
  receives that paise value directly and stores it in
  `SettleUpDraft.amountPaise`.
- **Reuse `netBalancePaise()`.** The controller computes the suggested
  amount via the shared helper from `lib/core/balances/net_balance.dart`
  (the same helper the friends list and friend detail header both use).
  This locks in the parity invariant: the chip on the list, the pill on
  the detail screen, and the suggested amount on the Settle Up sheet
  all agree because they derive from the same input via the same helper.
- **New write-side surface on `SettlementStore` /
  `SettlementRepository`.** Extend the PR #42 read-side scaffolding with
  `createSettlement(...)`. The repository wraps Firestore failures in
  a typed `SettlementCreateError` (mirrors PR #38's
  `ExpenseCreateError`); the controller catches the typed error and
  drives the snackbar via a discriminated union.
- **`SettlementDoc.toCreateMap()`.** A new method on the existing
  `SettlementDoc` class that produces the Firestore-shaped map
  satisfying every predicate in `firestore.rules` lines 379–489 —
  `hasAllRequiredKeys`, `hasOnlyKnownKeys`, `isValidShape`,
  `isValidExtensionPointLocks`, `isValidSettlementCreate`. The shape
  mirrors `ExpenseDoc.toCreateMap()` (PR #38) and is the boundary at
  which the strict-create discipline is enforced.
- **`OBTSettleUpCard` extraction.** A new reusable widget at
  `lib/features/friends/presentation/widgets/obt_settle_up_card.dart`.
  Lives under `friends/` (not `settlements/`) because it is a
  navigational affordance hosted by the friends context; the settlement
  write logic lives in `settlements/`. The design-system catalogue
  lists three call sites (Home Dashboard, Friend Detail, Group Detail);
  extraction is justified. When the Home Dashboard ships, that PR will
  lift the widget into a shared design-system folder.
- **Bottom sheet (not full screen).** SCR-23 spec describes a full
  screen at `/settle`; the architect overrides to a bottom sheet for
  parity with the PR #38 Add Expense flow and to keep the user
  anchored in the friend-detail context. If the bottom sheet's content
  height exceeds 80% of the viewport on small phones, escalate to a
  full screen at `/settle` (architect's call at §2.2).
- **Telemetry single-fire.** Every event in this flow fires at most
  once per transition: `settle_up_tapped` on card-tap,
  `settle_up_screen_viewed` on first-paint of the body,
  `settlement_recorded` on Saving → Success, `settle_up_error` on
  Saving → SettleUpError. Re-emission is gated by booleans on
  `_SettleUpBottomSheetState` (`_loggedView`) and by the state-machine
  transitions on the controller.
- **PII hashing per ADR-0013.** Every event carrying a `friendship_id`
  or `settlement_id` passes through `hashFriendshipId()` / `hashId()`
  from `lib/core/telemetry/event_id_hash.dart`. The parameter-key
  convention is `friendship_id_hash` / `settlement_id_hash`. The
  PII-leak test enforces by asserting the raw composite UID pair never
  appears in any logged parameter.
- **Carried-forward review items.** PR #42 code review flagged two items
  bundled into this PR:
    - **§R3** — extend `_SettlementRow` in `friend_detail_timeline.dart`
      to differentiate `You paid [Name] ₹X.XX` vs `[Name] paid you ₹X.XX`
      based on `fromUserId == currentUserUid`. Now meaningful because
      this PR produces the first real settlement docs.
    - **§R4** — rename `friend_row_tapped`'s parameter key
      `friendship_id` → `friendship_id_hash` for consistency with
      PR #42's `friend_detail_viewed { friendship_id_hash: ... }`. The
      value was already hashed in PR #35; this is a key-name rename only.
- **No `firestore.rules` change.** PR #37 shipped the rules for
  `settlements/{settlementId}`. The client writer must produce documents
  that satisfy the existing predicates; if a write is rejected, the bug
  is in the client (not in the rules).
- **No `functions/src/**` change.** PR #37 shipped the trigger
  `onSettlementWrite` which consumes this PR's writes.
- **No `firestore.indexes.json` change.** PR #42 already deployed the
  `settlements (contextType ASC, contextId ASC, date DESC)` composite
  that the in-timeline read uses.

---

## Out of scope

- **FR-SE-08 dedicated full-history screen** at `/settlements/history`
  — PR #42's in-timeline rows on Friend Detail already satisfy the v1.0
  FR-SE-08 requirement; the dedicated full-history screen is a separate
  later PR (PM files a follow-up story).
- **Home Dashboard `OBTSettleUpCard` host** (FR-HD-02) — the Home
  Dashboard does not exist yet; the card extraction is justified by the
  planned future use site but the only wired call site in this PR is
  `FriendDetailScreen`.
- **Group context Settle Up** (FR-GR-04) — Sprint 3 groups epic.
- **Edit / delete settlement** — separate later PR; soft-delete is
  server-ready via `deleted: false → true` (per PR #37 rules
  `isValidSettlementUpdate`).
- **Send Reminder** (FR-SE-09 P1) — separate later PR with 24-hour
  rate-limit rules + FCM dependency.
- **Settlement Confirmation animation sub-screen** (SCR-23
  §"Settlement Confirmation Sub-screen") — UX-polish later PR; the
  success snackbar `Settlement recorded.` is the v1.0 confirmation.
- **Two-sided card orientation when the friend owes me** (architect's
  §2.5 default: omit) — the receiving direction depends on FR-SE-09
  (Send Reminder) to feel right; deferred to that PR.
- **Receipt attachment to settlements** — settlements have no receipt
  field in the schema; FR-EX-05 is exclusively for expenses.
- **Activity feed** (FR-AC-01) — Sprint 4+ epic.
- **FCM push notifications** (FR-AC-03) — Sprint 4+ epic.
- **Any change to `firestore.rules`** — PR #37 rules are sufficient.
- **Any change to `functions/src/**`** — PR #37 trigger is sufficient.
- **Any change to `firestore.indexes.json`** — PR #42 composites are
  sufficient.
- **The D5 deadline upgrade** (issues #39 + #40) — its own dedicated PR
  (PR #44 default plan).

---

## Architect Notes

> Appended before implementation begins. References:
> `docs/copilot_prompts/sprint_2/9.md` (this PR's orchestration prompt),
> `.github/shared/invariants.md`, `.github/shared/decision-log.md`
> (ADR-0001, ADR-0002, ADR-0006, ADR-0007, ADR-0013), and
> `docs/patterns/feature-pr-conventions.md`.

### 2.1 File layout

This PR adds the following Flutter source files (under
`lib/features/settlements/`):

- `lib/features/settlements/domain/settle_up_draft.dart` — NEW;
  immutable in-memory form state (suggested amount, edited amount,
  date, optional note). All monetary fields are integer paise.
- `lib/features/settlements/domain/settlement_create_error.dart` —
  NEW; typed `SettlementCreateError` with `SettlementCreateErrorType`
  discriminated union (`permissionDenied`, `network`, `balanceChanged`,
  `invalidAmount`, `unknown`). Mirrors
  `lib/features/expenses/domain/expense_create_error.dart` 1:1.
- `lib/features/settlements/application/settle_up_telemetry.dart` —
  NEW; event-name + parameter-key constants. Mirrors
  `lib/features/expenses/application/expense_telemetry.dart`.
- `lib/features/settlements/application/settle_up_state.dart` — NEW;
  sealed-class hierarchy `SettleUpState { SettleUpEditing, SettleUpSaving,
  SettleUpSuccess, SettleUpError }`. The four states drive the bottom
  sheet UI.
- `lib/features/settlements/application/settle_up_controller.dart` —
  NEW; the `StateNotifier<SettleUpState>` with the sealed state
  machine. Family-keyed by `SettleUpArgs { friendshipId,
  currentUserUid, otherUserUid, suggestedAmountPaise, otherDisplayName }`.
- `lib/features/settlements/presentation/settle_up_bottom_sheet.dart`
  — NEW; the root host. Mirrors
  `lib/features/expenses/presentation/add_expense_bottom_sheet.dart`
  structurally.
- `lib/features/settlements/presentation/widgets/settle_up_header.dart`
  — NEW; payer avatar → arrow → payee avatar + identity text + amount
  echo.
- `lib/features/friends/presentation/widgets/obt_settle_up_card.dart`
  — NEW (per §2.6 extraction decision). Lives under `friends/` (not
  `settlements/`) because it is a navigational affordance hosted by
  the friends context.

This PR extends the following Flutter source files:

- `lib/features/settlements/data/settlement_repository.dart` — EXTEND
  with `createSettlement(...)` on the abstract `SettlementStore` and
  the production `FirestoreSettlementStore`. The `SettlementRepository`
  gains a `createSettlement(...)` method that wraps the Firestore
  failure in a typed `SettlementCreateError`. Tests inject a
  `FakeSettlementStore` that records the write payload.
- `lib/features/settlements/domain/settlement_doc.dart` — EXTEND with
  a `toCreateMap()` method that produces the Firestore-shaped map
  satisfying every predicate in `firestore.rules` lines 379–489.
- `lib/features/friends/presentation/friend_detail_screen.dart` —
  EXTEND. Insert the `OBTSettleUpCard` between
  `FriendDetailHeaderWidget` and `FriendDetailTimelineWidget` when
  `header.balanceState == BalanceState.owes` (the only direction shipped
  in this PR — see §2.5 for the receiving-direction default-omit
  decision). The card's `onSettleUp` opens
  `SettleUpBottomSheet` via `showModalBottomSheet` (mirrors PR #38's
  FAB → `AddExpenseBottomSheet` wiring).
- `lib/features/friends/presentation/widgets/friend_detail_timeline.dart`
  — EXTEND `_SettlementRow` per review §R3. Add a `currentUserUid`
  parameter and a `friendDisplayName` parameter (already plumbed to
  the timeline widget from `FriendDetailScreen`). Render
  `You paid [Friend's first name] ₹X.XX` when
  `doc.fromUserId == currentUserUid`, else
  `[Friend's first name] paid you ₹X.XX`.
- `lib/features/friends/presentation/friends_list_screen.dart` —
  RENAME the `friend_row_tapped` parameter key `friendship_id` →
  `friendship_id_hash` per review §R4. The value (already hashed via
  `hashFriendshipId()`) does not change.
- `lib/features/settlements/README.md` — EXTEND to describe the
  write-path scope shipped in this PR and the hand-off to FR-SE-09
  for the Send Reminder feature.
- `lib/features/friends/README.md` — APPEND a note on the
  `OBTSettleUpCard` insertion at the reserved position between header
  and timeline.

### 2.2 Bottom sheet vs full screen

SCR-23 spec says `/settle` is a full-screen route. The architect
overrides: **bottom sheet** for parity with the PR #38 Add Expense
flow and to keep the user anchored in the friend-detail context. If
implementation surfaces a content height that exceeds 80% of the
viewport on small phones (header + amount input + date picker + note +
button), escalate to a full screen at `/settle`.

A bottom sheet keeps the surrounding Friend Detail screen visible in
the dim backdrop, which reinforces the cognitive link "settling
against this friend" — the same affordance the Add Expense sheet
provides for "expense with this friend". The host is a
`showModalBottomSheet<void>(isScrollControlled: true, useSafeArea:
true)` exactly as the Add Expense sheet uses.

### 2.3 Optional note canonical form

When the user leaves the note empty, the write payload MUST include
`note: null` explicitly (NOT `note` omitted). The PR #37 rules accept
both shapes — `data.note == null || data.note is string` — but
choosing one canonical form keeps the rules-test surface small and
makes the audit story consistent across the read parser
(`SettlementDoc.fromFirestore` handles both) and the write payload
(emits exactly one shape).

The 200-character cap on the note is a client-side validation enforced
by `SettleUpDraft.validate()`; the rules do not enforce a length cap
(they only enforce the type — `String` or `null`). If a client bypasses
the validator, the rules still accept the write — the cap is UX
discipline, not a defence-in-depth check.

### 2.4 `OBTSettleUpCard.onSettleUp` target

The card's `onSettleUp` fires `settle_up_tapped { source:
'friend_detail', friendship_id_hash }` and then opens the Settle Up
bottom sheet via `showModalBottomSheet<void>(...)`. The wiring lives
in `FriendDetailScreen._onSettleUpTapped` (parallel to
`_openAddExpenseSheet` from PR #38). The sheet's
`SettleUpBottomSheet` reads
`settleUpControllerProvider(SettleUpArgs(...))` via Riverpod, which
the host overrides in widget tests with a fake repository + analytics.

### 2.5 Two-sided card orientation — default OMIT receiving direction

`netBalancePaise` has three branches:

- **`netBalancePaise < 0`** (current user owes the friend) — RENDER the
  card. Current user is the payer on the left; friend is the payee on
  the right. The CTA opens the flow pre-filled with the current user
  as the payer; the rules' `fromUserId == request.auth.uid` is
  satisfied because the writer is the payer.
- **`netBalancePaise > 0`** (the friend owes the current user) —
  **OMIT** the card in PR #43. The friend is the payer; the only
  person who can authenticate the write is the current user; the
  rules would reject `fromUserId != request.auth.uid`. The natural
  UX for this direction is a "Send Reminder" CTA, which is FR-SE-09
  (P1; out of scope). Default: omit the card; the receiving direction
  ships without a card in this PR. The two-sided pixel-perfect SCR-23
  layout ships when FR-SE-09 (Send Reminder) lands.
- **`netBalancePaise == 0`** — OMIT the card (AC-2; the header pill
  already reads "Settled up" so no further affordance is needed).

This omission is documented in AC-2 and surfaced in the QA smoke
matrix; the receiving-direction story should not surprise a reviewer.

### 2.6 `OBTSettleUpCard` extraction decision

The design-system catalogue
(`docs/design/02-design-system/components.md` item 13) lists this
component as a first-class reusable widget with three intended call
sites: Home Dashboard (FR-HD-02), Friend Detail (this PR), Group Detail
(FR-GR-04). PR #43 is the first call site.

**Decision:** extract the widget at
`lib/features/friends/presentation/widgets/obt_settle_up_card.dart`
(NOT under `settlements/`).

Rationale: the card is a navigational affordance hosted by the friends
context — it lives near the friends-feature widgets in the file tree
because the only PR #43 host is `FriendDetailScreen`. The settlement
write logic lives in `lib/features/settlements/`. When the Home
Dashboard ships (FR-HD-02), that PR will lift the widget into a
shared design-system folder
(`lib/core/widgets/cards/obt_settle_up_card.dart` per the
`OBTAmountInput` extraction precedent from PR #38).

The card has a clean public API:

```dart
OBTSettleUpCard({
  required String payerDisplayName,
  required String? payerPhotoUrl,
  required String payeeDisplayName,
  required String? payeePhotoUrl,
  required int suggestedAmountPaise,
  required VoidCallback onSettleUp,
});
```

No friendship-specific fields leak into the widget; the host
(`FriendDetailScreen`) is responsible for resolving identity and
binding the callback. This keeps the future lift-to-`lib/core/`
mechanical.

### 2.7 Telemetry single-fire discipline

Every event fires at most once per logical transition:

- `settle_up_tapped` fires on the card's `onSettleUp` callback;
  user-visible single tap.
- `settle_up_screen_viewed` fires once per bottom-sheet open, gated by
  a `_loggedView` boolean on `_SettleUpBottomSheetState`. The first
  paint of the body (not the build of the modal wrapper) fires it via
  a post-frame callback to ensure the controller is constructed.
- `settlement_recorded` fires once on the Saving → Success transition
  in the controller. The transition is one-shot (Success has no
  re-entry path), so a single `_analytics.logEvent(...)` call in the
  success branch suffices.
- `settle_up_error` fires once on the Saving → SettleUpError
  transition. The same one-shot discipline applies; on retry the user
  triggers a new Saving → ... transition.
- `settle_up_validation_failed` fires when the user taps Save on an
  invalid form. The controller checks the validation state at the
  top of `save()`; if invalid, it fires the event and returns without
  attempting the Firestore write. Re-emission is bounded by the
  user's tap count.

### 2.8 PII / telemetry hashing

Every event with `friendship_id` carries `hashFriendshipId(friendshipId)`
(SHA-256 truncated to 16 hex chars). Every event with `settlement_id`
carries `hashId(settlementId)`. Parameter-key convention:
`friendship_id_hash` and `settlement_id_hash` — matches PR #42's
`friend_detail_viewed { friendship_id_hash: ... }` and ratifies the
review §R4 rename for `friend_row_tapped`.

The PII-leak test seeds a known `friendshipId ==
'uid-priyalakshmi_uid-rahulagarwal'`, drives the bottom sheet through
a successful save, captures every emitted analytics payload, and
asserts:

- No raw substring of the friendshipId appears in any event name,
  parameter key, or parameter value.
- The hashed value (length-16 hex) IS present in every
  `friendship_id_hash` / `settlement_id_hash` parameter.

### 2.9 No new ADR required

Every design decision above is within the precedent of:

- **ADR-0001** — simplified debts as the canonical view; this PR reads
  the canonical view to derive the suggested amount and trusts the
  trigger to recompute after a settlement write.
- **ADR-0002** — paise integer arithmetic; every monetary field on the
  path is `int` paise. `formatInrFromPaise()` is the sole conversion
  at the UI boundary.
- **ADR-0006** — Riverpod state management; the controller is a
  `StateNotifier<SettleUpState>` with a `StateNotifierProvider.autoDispose.family`.
- **ADR-0007** — feature-first folder layout; new files live under
  `lib/features/settlements/` and `lib/features/friends/`.
- **ADR-0013** — PII / telemetry hashing; every event carrying an
  identifier passes through `hashFriendshipId()` / `hashId()` at the
  emit boundary.

If a future PR introduces a non-trivial Cloud Function behavioural
change (e.g. settling against multiple parties at once, or a server
arbitrator for the "balance changed since the user opened the sheet"
race), that escalates to a new ADR before implementation.

### 2.10 Settlement Confirmation sub-screen — OUT OF SCOPE

SCR-23 §"Settlement Confirmation Sub-screen" describes an animated
checkmark sub-screen with microcopy `You paid [Name] ₹X.XX. You're all
settled up — high five!` and spring-physics animation. This is **UX
polish** that is OUT OF SCOPE for PR #43.

The v1.0 confirmation is the success snackbar `Settlement recorded.`
plus the auto-dismissal of the bottom sheet plus the header pill
flipping to `Settled up`. The animated sub-screen is deferred to a
later UX-polish PR.

Rationale: the success snackbar + auto-dismissal preserves the user's
context (the Friend Detail screen with the updated pill is the
backdrop they see immediately); a full-screen confirmation would
break that flow. The animated checkmark is a "delight" enhancement
that does not unlock the FR-SE-05 acceptance criteria.

### 2.11 Settle-up entry points other than Friend Detail

Home Dashboard (FR-HD-02) and Group Detail (FR-GR-04) are OUT OF
SCOPE for PR #43. The `OBTSettleUpCard` extraction is justified by
the planned future use sites, but the only wired call site in this
PR is `FriendDetailScreen`. The `settle_up_tapped { source: ... }`
parameter is enumerated for all three sources in the telemetry plan
so the future Home Dashboard / Group Detail PRs are pure
call-site-addition diffs.

The `SettleUpArgs` family-key is friendship-specific
(`friendshipId`, `currentUserUid`, `otherUserUid`) for this PR; when
the Group Detail host ships, the controller is generalised to
`SettleUpArgs.friendship({...})` and `SettleUpArgs.group({...})`
constructors with a shared `contextType` + `contextId` projection at
the write boundary. That refactor is deferred to the Group Detail PR.
