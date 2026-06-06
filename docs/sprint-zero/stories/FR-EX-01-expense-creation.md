# FR-EX-01: Expense Creation UI (Friendship Context)

> Implementation-ready user story for the **first client producer of expense
> writes** in the OneByTwo application. Ships a two-step bottom sheet that
> captures amount, description, category, date, split method, payer, and
> per-split amounts, then writes a well-formed expense document to
> `friendships/{fid}/expenses/{eid}`. PR #36's `onExpenseWriteFriendship`
> trigger consumes the write, `recomputeAndWrite` updates
> `simplifiedBalances` + `lastActivityAt` atomically, and PR #35's friends
> list re-renders the new net balance. Closes the simplified-debts
> round-trip for the first time. Also resolves chore #25 (expense event
> naming convention) per Critical Constraint C-1.

---

## SRS Requirement ID(s)

FR-EX-01 (SRS section 4.5 — add expense, friendship context),
FR-EX-04 (SRS section 4.5 — paise integers; splits sum exactly to total),
FR-EX-08 (SRS section 4.5 — category enum),
FR-EX-09 (SRS section 4.5 — expense date defaults to today, no future dates).

## Relevant SRS Sections

- Section 4.5 — Expenses (add, split methods enum, paise integer
  arithmetic, category enum, date constraints)
- Section 5.6 — Add Expense flow (the three-step bottom sheet pattern;
  Step 3 receipt is DEFERRED to a later PR)
- Section 5.9 — Localisation and internationalisation (INR formatting,
  Indian numbering)
- Section 5.10 — Observability (telemetry events and PII hashing)
- Section 6.3 — Bottom sheet pattern for primary create flows
- Section 6.4 — Loading, empty, and error states
- Section 7.3 — Key architectural decisions (Invariant 1 — paise
  integers; Invariant 2 — `simplifiedBalances` is server-maintained,
  client-read-only)
- Section 7.5 — Security rules (expense subcollection rules, shipped
  in PR #36)

## Priority

**P0 — Must have.** Until this PR ships, the only producer of expense
documents in production is the admin SDK (integration tests and ops
scripts). Without a client write path, the simplified-debts round-trip
that PR #35, PR #36, and PR #37 collectively built is dormant. PR #38
is the load-bearing piece that proves the round-trip works in
production for real user input.

## Story Points

**5.** Scope: scaffold the expenses feature folder; build the two-step
bottom sheet UI; build the controller with the explicit state machine,
splitter, and validation; build the repository for the Firestore write;
resolve chore #25 and propagate the chosen event names; widget tests +
provider/controller tests + boundary-contract grep test + a PII-leak
test for telemetry + an integration test that closes the round-trip.
Patterns from FR-FR-03 (PR #35) and FR-SE-03/04 (PR #36) are ratified;
this story reuses, does not re-derive.

## Status

**Ready for Architect Notes.** Architect appends `## Architect Notes`
in a separate commit; chore #25 decision is recorded as §2.0 and
unblocks Phase 3 implementation per Critical Constraint C-1.

## PR Target

**PR #38** on branch `feat/fr-ex-01-expense-creation`.

## User Story

As **an authenticated friendship member who has at least one accepted
friend**,
I want **to add an expense incurred with that friend by entering the
amount, a short description, the category, the date, the split method,
the payer, and the per-split amounts through a two-step bottom sheet
that opens from the friend's detail screen**,
so that **the friendship's simplified net balance updates automatically
and the friends list reflects the post-expense state without any manual
refresh or client-side debt arithmetic**.

---

## Preconditions

1. The user is authenticated (Phone Auth completed) and has at least one
   friendship document at `friendships/{fid}` with `memberIds == [self, friend]`
   (deterministic composite ID per PR #32).
2. The Friend Detail placeholder screen
   (`lib/features/friends/presentation/friend_detail_placeholder_screen.dart`,
   shipped in PR #35) is reachable by tapping a row on the Friends list.
3. The `onExpenseWriteFriendship` trigger (PR #36) is live in production at
   `asia-south1` and the expense subcollection security rules from PR #36
   are in `firestore.rules`.
4. `friendsListProvider` (PR #35) is subscribed to the `friendships`
   snapshot stream and projects `simplifiedBalances` to a list of
   `FriendListItem` with INR-formatted net balances via
   `formatInrFromPaise()`.
5. The Firebase Emulator Suite is available for pre-merge integration
   testing (the integration test exercises the full round-trip through the
   registered trigger inside `firebase emulators:exec`).
6. No network connectivity is required for the bottom sheet to open;
   Firestore's offline write queue handles offline saves transparently
   (the SCR-19 state #6 offline `OBTSnackbar` informs the user).

---

## Background / Context

- **PR #35** shipped `friendsListProvider` — the read path that subscribes
  to `friendships` snapshots, projects `simplifiedBalances` per friend, and
  formats paise to INR via `formatInrFromPaise()`. That PR made
  `simplifiedBalances` a live read-side abstraction for the first time.
- **PR #36** shipped `onExpenseWriteFriendship` — the Cloud Function
  trigger at `friendships/{fid}/expenses/{eid}` that recomputes
  `simplifiedBalances` and `lastActivityAt` atomically on every expense
  write. The trigger has been live in `asia-south1` since PR #36 merged.
  Until PR #38 ships, the only producer of documents it consumes is the
  admin SDK (integration tests and ops scripts).
- **PR #37** shipped `onSettlementWrite` — the parallel trigger on the
  top-level `settlements/{settlementId}` collection. Live in production;
  **not exercised by PR #38** because the settlement-creation UI
  (FR-SE-08) is a later PR. PR #38's integration test seeds expenses only;
  settlement coverage is the responsibility of the future settle-up PR.
  Mentioning #37 here keeps the context map honest: the simplified-debts
  pipeline is fully live on the server, but only the expense half is
  exercised end-to-end by this PR.
- **PR #38 is the first PR that pivots back to Flutter UI work** after
  three consecutive Cloud Functions PRs. It is the first client producer
  of monetary writes end-to-end:
  `AddExpenseController.save()` → Firestore write to
  `friendships/{fid}/expenses/{eid}` → PR #36 trigger →
  `recomputeAndWrite` transaction → `simplifiedBalances` + `lastActivityAt`
  updated atomically → snapshot listener fires → `friendsListProvider`
  re-projects → friends list row reorders and re-renders the new net
  balance. This is the round-trip the integration test (AC-14) proves.
- **Invariant 1** (paise integers; conversion to rupees at the UI layer
  only) graduates from a read-side abstraction to a live client-side write
  producer for the first time. The `OBTAmountInput` component is the
  boundary: it accepts rupee text from the user and emits paise to the
  controller; that paise integer flows unchanged through the splitter, the
  controller, and the Firestore write map. Any defect — a stray `double`,
  a rounding off-by-one in the splitter, a UI-layer `/100` that bypasses
  `formatInrFromPaise()` — propagates to every expense the user creates.
- **Invariant 2** (`simplifiedBalances` server-maintained) is honoured by
  having the controller write ONLY to the `expenses` subcollection; the
  trigger remains the sole writer of `simplifiedBalances`.

---

## Scope (in PR #38)

- **Step 1 of the Add Expense bottom sheet:** amount, description (1–100
  characters, trimmed), category (one of the eight FR-EX-08 enum values),
  date (default today; future dates rejected).
- **Step 2 of the Add Expense bottom sheet:** split method, payer, per-
  split amount editors (used by the `exact` method).
- **Two split methods enabled:** `equal` (default; auto 50/50 with extra
  paise on the first share for odd totals) and `exact` (per-split inputs
  that must sum to the total). The other three methods (`unequal`,
  `percentage`, `shares`) appear as disabled chips with a "Coming soon"
  affordance and produce no state change on tap.
- **Manual category selection** from the eight FR-EX-08 categories —
  `food`, `travel`, `rent`, `utilities`, `groceries`, `entertainment`,
  `shopping`, `other` — stored as snake-case strings.
- **Single currency: INR.** `currency: 'INR'` is hardcoded on every write
  per ARCH-EXT-02. No currency picker in the UI.
- **Friendship context only.** `friendships/{fid}/expenses/{eid}` is the
  only write target. The repository's call site is structured so that
  supporting groups later is additive (an enum-discriminated method, not a
  fork), but the only producer shipped in this PR is the friendship
  producer.
- **FAB on `friend_detail_placeholder_screen.dart` only.** Wires the
  placeholder's FAB to
  `showModalBottomSheet(... AddExpenseBottomSheet(...))` with the
  friendship pre-bound from the route argument. The placeholder remains a
  placeholder for the list view; only the FAB action is wired through this
  PR.

---

## Out of Scope

- **Receipt attachment (FR-EX-05, SCR-21)** — Step 3 of the bottom sheet.
  The schema's `receiptUrl` is written as `null` on every PR #38 create
  (the security rules accept `null`).
- **Edit / delete (FR-EX-06, SCR-22)** — separate PR. The PR #36 trigger
  already supports update + soft-delete from any source.
- **Activity-feed item writes (FR-EX-07, FR-AC-01)** — separate later
  sprint; the PR #36 trigger has `// TODO(FR-AC-01)` hand-off seams.
- **Groups context (FR-EX-02)** — Sprint 3 groups epic;
  `onExpenseWriteGroup` binding is also deferred per the PR #36 architect
  notes.
- **Split methods `'unequal'`, `'percentage'`, `'shares'`** — disabled
  chips with a "Coming soon" tooltip; follow-up PR.
- **Multi-context entry-point chooser** (FAB on home / friends / groups
  tabs → context picker → add-expense sheet) — default: FAB only on the
  per-friend Friend Detail placeholder.
- **FAB on `friends_list_screen.dart`** — default: no-op for this PR. The
  trivial "Pick a friend first" snackbar variant is the architect's call
  (see Open Questions).
- **Real-time receipt OCR, AI-suggested splits, recurring expenses** —
  post-v1.0 per SRS section 12.3.

---

## Acceptance Criteria

### AC-1 — Open from Friend Detail

> Given a user is viewing the Friend Detail placeholder for a friend
> (the FR-FR-04 placeholder from PR #35)
> When they tap the FAB
> Then the Add Expense bottom sheet opens at Step 1 with the friend's
> identity pre-bound as the friendship context
> And `expense_step1_opened { context_type: 'friend', entry_point: 'friend_detail' }` fires.
>
> Reconciliation note: `context_type` is `'friend'` per the SCR-08 column
> of the telemetry plan; this is distinct from the Firestore schema's
> `contextType` which uses `'friendship'` for the same concept. The
> divergence is to be reconciled in the Architect Notes — the controller
> MUST NOT silently coerce one to the other.

### AC-2 — Step 1 validation (amount)

> Given the bottom sheet is at Step 1
> When the user enters an amount of `0` or leaves the field empty
> Then the Next button stays disabled (state #3 in SCR-19).
>
> When the user enters an amount in paise (the output of `OBTAmountInput`)
> that exceeds `99999999` (`9,99,99,999` paise = `₹99,99,999.99` cap per
> SCR-19)
> Then an inline `danger`-coloured error appears: "Amount cannot exceed
> ₹99,99,999.99."
> And Next stays disabled.
> And the error clears when the user corrects the value.

### AC-3 — Step 1 validation (description)

> Given the bottom sheet is at Step 1
> When the user enters a description of 1–100 characters (trimmed)
> Then the constraint passes.
>
> When the description is empty
> Then the inline error reads: "Add a short description."
>
> When the description exceeds 100 characters
> Then the inline error reads: "Description must be under 100 characters."

### AC-4 — Step 1 validation (category)

> Given the eight category chips are displayed
> When the user selects exactly one
> Then `expense_category_selected { category }` fires on tap.
>
> The eight categories are `food`, `travel`, `rent`, `utilities`,
> `groceries`, `entertainment`, `shopping`, `other` (snake-case enum
> values per the schema; user-facing titles supplied via the
> `OBTCategoryChip` `label`).

### AC-5 — Step 1 validation (date)

> Given the date field
> When the bottom sheet first opens
> Then the date defaults to today.
>
> When the user picks any past date or today
> Then the constraint passes.
>
> When the user picks a future date
> Then an inline error appears: "Date cannot be in the future."

### AC-6 — Step 1 valid → Step 2

> Given amount > 0 paise AND description is non-empty (trimmed) AND a
> category is selected AND date is valid
> Then the Next button activates.
>
> When the user taps Next
> Then the sheet advances to Step 2
> And `expense_step1_completed { amount_range, category, has_notes }`
> fires, with `amount_range` per the bucketing table in section 2.1 of the
> telemetry plan (`under_100`, `100_500`, `500_2500`, `2500_10000`,
> `10000_25000`, `over_25000`).

### AC-7 — Step 2 split-method UI

> Given the user is on Step 2
> Then two split-method chips are enabled — `equal` (default, auto 50/50
> between the two friendship members) and `exact` (per-split amount
> inputs, one row per member)
> And the other three methods (`unequal`, `percentage`, `shares`) appear
> as disabled chips with a "Coming soon" tooltip.
>
> When a disabled chip is tapped
> Then no event fires and no UI side effect occurs (silent disable — no
> error toast).
>
> When Step 2 first renders
> Then `expense_step2_opened { split_method: 'equal' | 'exact', participant_count: 2 }`
> fires.
>
> When the user changes the split method
> Then `expense_split_method_changed { from_method, to_method }` fires.

### AC-8 — Step 2 payer

> Given the Step 2 payer dropdown
> Then the two friendship members (the current user + the friend) are
> listed with the current user as the default.
>
> When the user changes the payer to the friend
> Then `expense_payer_changed { payer_is_self: false }` fires.

### AC-9 — Step 2 splitter (equal)

> Given `splitMethod == 'equal'` and `amountPaise == 1000` (`₹10.00`)
> Then the splitter computes
> `splits = [{userId: current, sharePaise: 500}, {userId: friend, sharePaise: 500}]`.
>
> Given `splitMethod == 'equal'` and an odd `amountPaise == 1001`
> Then the splitter computes `[{current: 501}, {friend: 500}]` — the
> extra paise lands on the first share with deterministic ordering
> (current user first).
>
> The sum-check `splits[0].sharePaise + splits[1].sharePaise == amountPaise`
> is a unit-test invariant (FR-EX-04).

### AC-10 — Step 2 splitter (exact)

> Given `splitMethod == 'exact'`
> When the user types two `OBTAmountInput` values, one per member
> Then the Save button is disabled until the per-split amounts sum
> exactly to `amountPaise` (Invariant 1, FR-EX-04).
>
> When the sum is under the total
> Then an inline `danger` message reads:
> "Splits must sum to ₹X.XX (currently ₹Y.YY — ₹Z.ZZ short)."
>
> When the sum is over the total
> Then the message reads:
> "Splits must sum to ₹X.XX (currently ₹Y.YY — ₹Z.ZZ over)."
>
> On validation fail,
> `expense_split_validation_failed { split_method: 'exact', direction: 'under' | 'over' }`
> fires.

### AC-11 — Step 2 → Save (success path)

> Given Step 2's validation passes
> When the user taps Save
> Then `expense_step2_completed { split_method, participant_count: 2, payer_is_self }`
> fires
> And the controller transitions to a `saving` state
> And the Save button shows a loading spinner
> And the controller calls `expenseRepository.createExpense(...)`.
>
> On success:
> Then **the chosen chore #25 success event name (to be ratified in
> Architect Notes §2.0)** fires carrying
> `{ context_type: 'friend', amount_range, category, split_method, participant_count: 2, has_receipt: false, has_notes, is_offline }`
> And the bottom sheet dismisses
> And the parent screen shows an `OBTSnackbar` of type `success`:
> "Expense added."

### AC-12 — Save failure (network / rules)

> Given the Firestore write throws (network, permission-denied, or any
> other Firebase failure)
> When the controller observes the error
> Then it transitions to an `error` state
> And the Save button is restored (no spinner)
> And **the chosen chore #25 failure event name (to be ratified in
> Architect Notes §2.0)** fires carrying
> `{ error_type: 'network' | 'permission_denied' | 'unknown', is_offline }`
> And an inline `OBTSnackbar` of type `danger` appears at the bottom of
> the sheet: "Couldn't add the expense. Try again."
> And the sheet does NOT dismiss
> And subsequent Save attempts retry from the same state.

### AC-13 — Discard with confirmation

> Given the user taps the back arrow or invokes the system back gesture
> When the sheet is on Step 1 with empty fields
> Then the sheet dismisses immediately with no telemetry emitted.
>
> When the sheet is on Step 1 with any data entered, OR on Step 2 in any
> state
> Then an `OBTSnackbar` of type `warning` confirms: "Discard this
> expense?" with "Discard" and "Keep editing" CTAs
> And tapping "Discard" dismisses the sheet AND fires either
> `expense_step1_abandoned` or `expense_step2_abandoned` per the current
> step
> And tapping "Keep editing" returns the user to the sheet unchanged.
>
> If the SCR-19 / SCR-20 screen spec mandates an explicit confirm dialog
> rather than the warning snackbar, the screen spec wins.

### AC-14 — Round-trip via the trigger (integration)

> Given a friendship A ↔ B with `simplifiedBalances == {}`
> When user A creates an expense of ₹100 split equally
> Then within the integration-test polling window (≤ 2.5 s per NFR-PE-04)
> the friends list row for B reads "owes you ₹50.00".
>
> This asserts the full chain: the Firestore write fires; the PR #36
> trigger fires; `recomputeAndWrite` updates `simplifiedBalances` to
> `{B: {A: 5000}}` and `lastActivityAt` to the trigger's `event.time`;
> the snapshot stream emits; `friendsListProvider` re-projects; the
> friends list renders the new net balance via `formatInrFromPaise(5000)`.
> Failure of any link in the chain fails this AC.

### AC-15 — Invariant 1 (paise) at the write boundary (NEGATIVE)

> A boundary-contract grep test asserts:
>
> `grep -rEn '\.toDouble\(\)|/100\b|/100\.0\b|double ' lib/features/expenses/`
> returns **0 matches**. (Exception: `int.parse` / `int.tryParse` is
> allowed; `as double` is not.)
>
> The amount path from `OBTAmountInput.onChanged` → controller state →
> `splits[].sharePaise` → Firestore write map is integer paise throughout.

### AC-16 — Invariant 2 (`simplifiedBalances` server-only) (NEGATIVE)

> A boundary-contract grep test asserts:
>
> `grep -rEn 'simplifiedBalances' lib/features/expenses/` returns
> **0 matches**.
>
> The Flutter expense feature NEVER references `simplifiedBalances` — the
> trigger is the sole writer; the read path lives in `lib/features/friends/`.

### AC-17 — Telemetry PII guard (NEGATIVE)

> A new test `expense_telemetry_pii_leak_test.dart` emits every expense
> event with a known `friendshipId == 'uidA_uidB'` and
> `expenseId == 'realExpenseId123'` and captures the emitted parameter
> payloads via a fake telemetry sink.
>
> Then no payload contains the raw `'uidA_uidB'` or `'realExpenseId123'`
> substring
> And every parameter expected to carry an identifier carries the
> SHA-256-truncated value (length-16 hex) produced by `hashFriendshipId()`
> / `hashId()` from `lib/core/telemetry/event_id_hash.dart`.
>
> Mirrors the existing PII-leak tests in `test/features/friends/`.

### AC-18 — Chore #25 ratified (PROCESS GATE)

> Given the architect has appended `## Architect Notes` to this story
> Then §2.0 records the chosen convention (Camp A —
> `expense_added` / `expense_add_failed` — or Camp B —
> `expense_save_succeeded` / `expense_save_failed`) with a one-paragraph
> rationale
> And the chosen names are reflected in:
> - `docs/design/07-technical/telemetry-plan.md` (the table rows in
>   sections 1.3 and 2.1, and the section 6 funnel diagram).
> - `lib/features/expenses/application/expense_telemetry.dart` (or
>   wherever the event-name constants live).
> - Every test that asserts event names.
>
> And `Closes #25` appears in the PR body.
>
> Until §2.0 is recorded, the orchestrator MUST refuse to start Phase 3
> implementation per Critical Constraint C-1 of
> `docs/sprint-zero/sprint-2-plan.md`.

---

## Definition of Ready

- [x] SRS sections cited and present: §4.5 (FR-EX-01, -04, -08, -09),
      §5.6 (usability), §6.3 (core screens — three-step bottom sheet, of
      which this PR ships two), §7.3 (Invariants 1 and 2), §7.5 (security
      rules, already shipped in PR #36).
- [x] Screen specs available:
      `docs/design/06-screen-specs/19-22-expenses.md` — SCR-19 (Amount
      and Details) and SCR-20 (Split Method). SCR-21 (Receipt) and
      SCR-22 (Edit/Delete) are referenced for context only; their
      requirements are explicitly deferred.
- [x] Wireframe baseline cited:
      `docs/design/04-wireframes/expense-flow.md`.
- [x] Design-system widget catalogue cited:
      `docs/design/02-design-system/components.md` — `OBTAmountInput`
      (item 6), `OBTRupeeText` (item 5), `OBTCategoryChip` (item 12),
      `OBTPrimaryButton`, `OBTSnackbar`, `OBTSkeletonLoader`,
      `OBTBottomSheet`.
- [x] Firestore schema cited:
      `docs/design/07-technical/firestore-schema.md` —
      `friendships/{friendshipId}/expenses/{expenseId}` document table.
- [x] Firestore security rules cited:
      `docs/design/07-technical/firestore-security-rules.md` and
      `firestore.rules` (expense subcollection rules shipped in PR #36;
      this PR consumes them, does not modify them).
- [x] Telemetry plan cited:
      `docs/design/07-technical/telemetry-plan.md` sections 1.3 (expense-
      flow events), 2.1 (amount bucketing), 2.2 (document identifiers —
      SHA-256 truncated hashing).
- [x] Extension-points register cited:
      `docs/design/03-architecture/extension-points-register.md` —
      ARCH-EXT-01 (split methods enum), ARCH-EXT-02 (currency locked to
      INR), ARCH-EXT-03 (recurring expenses null in v1.0), ARCH-EXT-07
      (`source: 'manual'`).
- [x] Architectural precedent cited: `lib/features/friends/` mirrors the
      controller / repository / domain / presentation feature-first
      layout to be applied to `lib/features/expenses/`.

---

## Invariant Applicability Assessment (DoR §9)

The text in this section is reproduced verbatim from Phase 1 of the source
orchestration prompt (`docs/copilot_prompts/sprint_2/7.md`).

- **Invariant 1 (paise integers, conversion at UI):** APPLIES at the write
  boundary for the first time. The splitter, validators, controller
  state, and Firestore write map are all integer-paise.
  `formatInrFromPaise()` is the sole rupee-conversion call site on the
  UI. `OBTAmountInput`'s emitted value is paise. Boundary-contract test
  (AC-15) enforces.
- **Invariant 2 (`simplifiedBalances` server-only):** APPLIES. The
  controller writes ONLY to `friendships/{fid}/expenses/{eid}`. It NEVER
  writes to `friendships/{fid}.simplifiedBalances`. The trigger is the
  sole writer of that field. Boundary-contract test (AC-16) enforces.
- **Invariant 3 (system share sheet):** N/A for PR #38.
- **Invariant 4 (single Firebase project):** APPLIES. No new project; the
  controller writes via the existing `FirebaseFirestore.instance` (or the
  injected `FakeFirebaseFirestore` in tests).
- **ADR-0013 (PII hashing):** APPLIES to expense telemetry.
  `friendship_id` and `expense_id` parameters MUST be hashed via the
  existing helpers in `lib/core/telemetry/event_id_hash.dart`. AC-17 test
  enforces.

---

## Telemetry Events Introduced

The events PR #38 introduces. The success and failure event names are
deferred to the architect's chore #25 decision in Architect Notes §2.0 —
placeholder forms are recorded below pending that decision.

- `expense_step1_opened` — bottom sheet opens at Step 1 (AC-1).
- `expense_step1_completed` — user advances from Step 1 to Step 2 (AC-6).
- `expense_step1_abandoned` — user discards from Step 1 with data entered
  (AC-13).
- `expense_category_selected` — user selects a category chip (AC-4).
- `expense_step2_opened` — Step 2 first renders (AC-7).
- `expense_split_method_changed` — user switches between `equal` and
  `exact` (AC-7).
- `expense_payer_changed` — user changes the payer in Step 2 (AC-8).
- `expense_step2_completed` — user taps Save and validation passes
  (AC-11).
- `expense_split_validation_failed` — the `exact` split sum-check fails
  (AC-10).
- `expense_step2_abandoned` — user discards from Step 2 (AC-13).
- `expense_added` **OR** `expense_save_succeeded` — Firestore write
  succeeds (AC-11). **Chore #25 — convention deferred to Architect
  Notes §2.0.**
- `expense_add_failed` **OR** `expense_save_failed` — Firestore write
  throws (AC-12). **Chore #25 — convention deferred to Architect
  Notes §2.0.**

Step-3 events (`expense_step3_opened`, `expense_receipt_attached`, etc.)
are NOT emitted in PR #38; their introduction is deferred to the receipt
PR (FR-EX-05).

Every event parameter that carries `friendship_id` or `expense_id` MUST be
the SHA-256-truncated value from `hashFriendshipId()` / `hashId()` per
ADR-0013 (see AC-17).

---

## Definition of Done

Reference: `docs/design/08-plan/definition-of-ready-and-done.md`.

- [ ] `flutter analyze --fatal-infos` is clean.
- [ ] `flutter test` is green across all new and existing tests,
      including:
      widget tests for the bottom sheet and Step 1 / Step 2 states;
      provider / controller tests for `AddExpenseController`;
      repository tests against `FakeFirebaseFirestore`;
      the boundary-contract grep test (no `.toDouble()`, no `/100`, no
      `simplifiedBalances` in `lib/features/expenses/`);
      the PII-leak test (`expense_telemetry_pii_leak_test.dart`).
- [ ] Integration test
      `test/integration/expenses/expense_creation_flow_test.dart` is
      green against the Firebase Emulator Suite — walks the round-trip
      via the registered PR #36 trigger and asserts the friends list row
      updates within the NFR-PE-04 polling window (AC-14).
- [ ] `firebase deploy --only firestore:rules` — **NOT required**. No
      rules change in this PR; the expense subcollection rules shipped
      in PR #36 are sufficient.
- [ ] `firebase deploy --only functions` — **NOT required**. No functions
      change in this PR; the PR #36 and PR #37 triggers consume this
      PR's writes unchanged.
- [ ] Coverage gate per SRS section 5.7: `lib/features/expenses/**`
      per-module ≥ 70 % (target ≥ 80 % on the controller and the
      splitter); `lib/core/**` coverage unchanged; overall Flutter ≥ 50
      %.
- [ ] Boundary contracts pass:
      `grep -rEn '\.toDouble\(\)|/100\b|/100\.0\b|double ' lib/features/expenses/`
      and `grep -rEn 'simplifiedBalances' lib/features/expenses/` both
      return 0 matches.
- [ ] Architect Notes appended with **§2.0 chore #25 decision FIRST**,
      followed by §2.1–§2.9 per the source prompt's Phase 2 outline.
- [ ] `Closes #25` appears in the PR body.
- [ ] `docs/design/07-technical/telemetry-plan.md` updated with the
      chosen chore #25 names (search-and-replace across sections 1.3,
      2.1, and the section 6 funnel diagram).
- [ ] `docs/sprint-zero/sprint-2-plan.md` updated — PR #38 status set to
      merged; velocity entry added (5 SP); Critical Constraint C-1
      marked RESOLVED with the chosen names and a citation to Architect
      Notes §2.0.
- [ ] `docs/sprint-zero/next-three-prs.md` rolled to the next PR #39
      candidate (FR-FR-04 full screen OR FR-EX-05 receipt attachment —
      architect's call at PR #39 kickoff).
- [ ] `docs/audits/sprint-1/07-bucket-b-burndown.md` marks SR8 (expense
      event naming convention) CLOSED with citation to the chosen names
      in the Architect Notes.
- [ ] `lib/features/expenses/README.md` replaces its placeholder one-
      liner with a description of the implemented scope and the deferred
      items.
- [ ] QA reviewed and verified all 18 acceptance criteria, including the
      negative cases AC-12, AC-15, AC-16, AC-17, AC-18.
- [ ] Telemetry events in place and firing correctly; verified by the
      PII-leak test (AC-17) and by manual emulator-suite inspection of
      Firebase Analytics DebugView (or equivalent).
- [ ] Accessibility verified — semantic labels on every interactive
      widget per SCR-19 / SCR-20 accessibility sections; screen-reader
      walk-through on iOS (VoiceOver) and Android (TalkBack).
- [ ] Dark mode checked (WCAG AA contrast ratios) on both Step 1 and
      Step 2.
- [ ] No open S1 or S2 bugs.

---

## Design Artefact References

| Artefact | Path |
|---|---|
| Screen spec (Step 1) | `docs/design/06-screen-specs/19-22-expenses.md` (SCR-19) |
| Screen spec (Step 2) | `docs/design/06-screen-specs/19-22-expenses.md` (SCR-20) |
| Wireframe baseline | `docs/design/04-wireframes/expense-flow.md` |
| Design-system components | `docs/design/02-design-system/components.md` |
| Firestore schema (expense subcollection) | `docs/design/07-technical/firestore-schema.md` |
| Firestore security rules (expense subcollection — shipped in PR #36) | `docs/design/07-technical/firestore-security-rules.md` |
| Telemetry plan | `docs/design/07-technical/telemetry-plan.md` |
| State-management plan | `docs/design/07-technical/state-management.md` |
| Cloud Functions catalogue (consumer side — `onExpenseWriteFriendship`) | `docs/design/07-technical/cloud-functions-catalogue.md` |
| Extension-points register | `docs/design/03-architecture/extension-points-register.md` |
| PR #35 story (friends list — the round-trip read side) | `docs/sprint-zero/stories/FR-FR-03-friends-list.md` |
| PR #36 story (expense trigger — the round-trip server side) | `docs/sprint-zero/stories/FR-SE-03-04-expense-trigger-friendship.md` |
| PR #37 story (settlement trigger — live but not exercised by this PR) | `docs/sprint-zero/stories/FR-SE-05-06-settlement-trigger.md` |
| Feature-PR conventions | `docs/patterns/feature-pr-conventions.md` |

---

## Responsible Agents

| Agent | Responsibility |
|---|---|
| PM | Story authorship, AC clarity, scope discipline (no widening into receipt / edit / delete / groups / extra split methods / multi-context FAB / real-time updates beyond the PR #36 trigger). |
| Architect | Source-layout decision for `lib/features/expenses/`, chore #25 ratification (§2.0 of Architect Notes), `OBTAmountInput` extract-vs-inline (§2.8), controller state-machine shape, splitter discipline, repository write-shape, payer-dropdown label convention, FAB-on-friends-list-screen behaviour. |
| Flutter Dev | Implementation of the controller, repository, splitter, domain models, and the bottom sheet UI (Step 1 + Step 2 + shared widgets); wiring the FAB on `friend_detail_placeholder_screen.dart`; writing the test pyramid (unit + property + widget + repository + boundary-contract + PII-leak + integration). |
| QA | Verification of all 18 ACs including the negative cases; manual screen-reader and dark-mode walk-through; round-trip smoke against the emulator suite. |
| Designer | Sign-off on Step 1 / Step 2 layout fidelity to SCR-19 / SCR-20, the disabled-chip "Coming soon" affordance, the discard-confirmation pattern, dark-mode contrast on the error states. |
| DevOps | None required — no CI workflow change, no rules deploy, no functions deploy. |

---

## Technical Notes

- **Feature folder:** `lib/features/expenses/` currently contains only
  `README.md` + `.gitkeep`. PR #38 fills it with the
  `application/`, `data/`, `domain/`, and `presentation/` sub-folders per
  the architect-ratified layout (Architect Notes §2.1).
- **FAB wiring target:**
  `lib/features/friends/presentation/friend_detail_placeholder_screen.dart`
  currently has NO FAB. PR #38 adds the FAB and wires its `onPressed` to
  `showModalBottomSheet(... AddExpenseBottomSheet(...))`. No other change
  to the placeholder is in scope.
- **`OBTAmountInput`:** does NOT yet exist as a reusable widget;
  `lib/core/widgets/` contains only `india_phone_input_formatter.dart`.
  The extract-vs-inline decision is captured in Open Questions item 2 /
  Architect Notes §2.8.
- **Repository write path:**
  `FirebaseFirestore.instance.collection('friendships').doc(friendshipId).collection('expenses').add(doc.toCreateMap())`.
  The write map MUST satisfy the rules' `hasAllRequiredKeys`,
  `hasOnlyKnownKeys`, `isValidShape`, `isValidExtensionPointLocks`,
  `areValidSplitElements`, and `sumOfSharesEquals` predicates from PR #36
  (`firestore.rules` lines 153–380). If the rules reject a well-formed
  PR #38 write, the bug is in the client, not the rules.
- **`recurringRule`:** OMITTED from the write map per ARCH-EXT-03 (the
  rules accept absent OR `null`; omitting is simpler).
- **`source` and `currency`:** hardcoded to `'manual'` and `'INR'` per
  ARCH-EXT-07 and ARCH-EXT-02.
- **Telemetry plumbing:** the existing `lib/core/telemetry/` helpers
  (Firebase Analytics wrapper + `hashFriendshipId()` / `hashId()`) are
  reused. No new telemetry infrastructure is introduced.
- **Offline behaviour:** Firestore's offline write queue handles the
  basic case automatically (the SDK queues the write and syncs when
  online). The bottom sheet shows the SCR-19 state #6 offline
  `OBTSnackbar` if `connectivity_plus` reports offline at open. The
  integration test does NOT cover offline; that is deferred to a later
  PR.
- **Test paths:**
  - `test/features/expenses/split_calculator_test.dart` — unit tests.
  - `test/features/expenses/split_calculator_property_test.dart` —
    property tests (mirrors the property-test discipline already in
    `functions/test/simplified-debts/algorithm.property.test.ts`).
  - `test/features/expenses/add_expense_controller_test.dart` —
    controller state-machine tests.
  - `test/features/expenses/add_expense_bottom_sheet_widget_test.dart` —
    widget tests.
  - `test/features/expenses/expense_repository_test.dart` — repository
    tests with `FakeFirebaseFirestore`.
  - `test/features/expenses/expense_creation_boundary_contract_test.dart`
    — grep contracts (mirrors
    `test/features/friends/friends_list_boundary_contract_test.dart`).
  - `test/features/expenses/expense_telemetry_pii_leak_test.dart` —
    PII-leak guard.
  - `test/integration/expenses/expense_creation_flow_test.dart` —
    end-to-end round-trip via the registered PR #36 trigger inside
    `firebase emulators:exec`.

---

## Open Questions for the Architect

These items are surfaced for the architect to ratify in `## Architect
Notes`. The defaults noted below are the PM's working assumption; the
architect may override with rationale.

1. **Chore #25 — expense event naming convention.** Camp A
   (`expense_added` / `expense_add_failed` — the legacy asymmetric names
   currently in `docs/design/07-technical/telemetry-plan.md` section 1.3)
   vs Camp B (`expense_save_succeeded` / `expense_save_failed` —
   symmetric with the edit / delete cluster in section 1.6, which
   already uses `expense_edit_saved` / `expense_edit_failed` /
   `expense_save_failed`). **PM recommendation: Camp B** on consistency
   grounds with the section-1.6 cluster. Architect's final call goes
   into Architect Notes §2.0 with a one-paragraph rationale and
   propagates to the telemetry plan, the `expense_telemetry.dart`
   constants, and every test that asserts event names.
2. **`OBTAmountInput` extraction.** Option E (extract to
   `lib/core/design_system/inputs/obt_amount_input.dart` with a
   paise-emitting `ValueChanged<int>` contract; establishes the boundary
   for the future FR-SE-08 settle-up UI) vs Option I (inline in
   `lib/features/expenses/presentation/widgets/_amount_input.dart` with a
   TODO to extract on the next use site). Note: `lib/core/widgets/`
   currently contains only `india_phone_input_formatter.dart` — no OBT
   widgets exist in the codebase yet, so Option E also creates the
   convention. **PM working assumption: Option E** per the source
   prompt's preference and to avoid a later refactor when FR-SE-08
   needs the same widget. Architect's call in Architect Notes §2.8.
3. **FAB on `friends_list_screen.dart`.** Default behaviour for this PR:
   no-op (the only entry point to the Add Expense flow is the FAB on
   the per-friend Friend Detail placeholder). Alternative: trivially
   wire it to show an `OBTSnackbar` reading "Pick a friend first". **PM
   working assumption: no-op** to avoid scope creep into a multi-friend
   picker. Architect's call.
4. **Payer dropdown labels in Step 2.** Three options: UID suffix (e.g.
   "user@a1b2c3"), generic placeholders ("You" / "Friend"), or real
   display names resolved via `userProfileProvider`. The third option
   drags `userProfileProvider` into the bottom sheet and complicates
   testing (the controller would otherwise have no provider
   dependencies). **PM default in this story: "You" / "Friend"**
   placeholders. Architect may override and route the real-names option
   as a polish follow-up PR.

---

## Architect Notes

> Appended for PR #38. These notes ratify the design decisions taken
> before implementation begins. References:
> `docs/copilot_prompts/sprint_2/7.md` (Phase 2 §2.0–§2.9),
> `.github/shared/invariants.md`, `.github/shared/decision-log.md`
> (ADR-0001 simplified debts; ADR-0002 paise integers; ADR-0006
> Riverpod; ADR-0007 feature-first layout; ADR-0013 PII /
> telemetry hashing). Architect Notes §2.0 (chore #25) is the
> first item per Critical Constraint C-1 of
> `docs/sprint-zero/sprint-2-plan.md` — Phase 3 implementation is
> blocked until §2.0 is recorded. With §2.0 ratified below,
> flutter-dev may begin Phase 3.

### 2.0 Chore #25 — expense event naming convention (BLOCKING ITEM, RESOLVED)

**Decision: Camp B.** The success event is
`expense_save_succeeded`; the failure event is `expense_save_failed`.
The legacy `expense_added` / `expense_add_failed` names are retired
across the codebase and the telemetry plan in this PR.

Rationale. Three factors point the same way. First, the existing
edit / delete cluster in section 1.6 of
`docs/design/07-technical/telemetry-plan.md` already runs on the
verb-past + state pattern: `expense_edit_saved`, `expense_edit_failed`,
`expense_delete_confirmed`, `expense_delete_failed`, and crucially the
Step-3 success-side `expense_save_failed` from SCR-21. The add cluster
is the only sub-cluster that breaks the pattern (noun-past `*_added`
beside verb-past `*_add_failed`), and that asymmetry was flagged in
the Sprint 1 audit as SR8 ("Expense event naming asymmetry. Success
logs `expense_added`; failure logs `expense_save_failed`. Inconsistent
naming harms funnel analysis." —
`docs/audits/sprint-1/05-sprint-2-readiness.md` line 138). Second,
adopting `expense_save_succeeded` brings the add and edit paths under
a single dashboard query template (`event_name LIKE
'expense_%_succeeded'`) without a per-path special case — the OBT
project-internal architectural goal of symmetry across feature
clusters is honoured. Third, the failure-side name `expense_save_failed`
already exists in the plan for SCR-21; aligning the add cluster's
failure-side name with it eliminates a duplicate event when the
receipt PR ships. The cost is a one-shot search-and-replace across
the telemetry plan (this commit's sibling) and the test fixtures
flutter-dev writes in Phase 4 — both bounded, both performed before
any production user has seen an event.

Propagation in this PR. (a) `docs/design/07-technical/telemetry-plan.md`
sections 1.1 (Core Funnel Events), 1.3 (Home and Search Events), 2.1
(Amount Ranges narrative), and 4.2 (Expense Funnel diagram + metrics)
are updated by sibling commit `docs(telemetry): adopt chore #25
expense event naming convention (Closes #25)`. (b) `lib/features/expenses/application/expense_telemetry.dart`
constants will name the success event
`expenseSaveSucceeded` / `'expense_save_succeeded'` and the failure
event `expenseSaveFailed` / `'expense_save_failed'`. (c) Every test
in `test/features/expenses/` that asserts an event name uses the new
strings. (d) Sprint 2 plan Critical Constraint C-1 is marked RESOLVED
with a citation back to this §2.0. (e) `docs/audits/sprint-1/07-bucket-b-burndown.md`
SR8 is marked CLOSED with the same citation. (f) The PR body carries
`Closes #25`.

Audit trail. (a) Telemetry plan section 1.6 cluster:
`docs/design/07-technical/telemetry-plan.md` lines 154–183 (the
edit / delete row block already uses verb-past + state). (b) Audit
finding: `docs/audits/sprint-1/05-sprint-2-readiness.md` line 138
(SR8). (c) OBT-internal architectural goal: §7.3 of the SRS describes
the simplified-debts and Invariant 2 patterns as a single
client-read-only contract, and the telemetry expense-funnel diagram
in section 4.2 of the telemetry plan reads success events
left-to-right; keeping success and failure names on the same verb
root (`save`) lets the funnel diagram render the failure edges as a
structural mirror. (Note: the source prompt called this "section 6
funnel diagram" — that section number is stale; the actual location
is §4.2, which the sibling telemetry-plan commit edits.)

### 2.1 Source layout for the expenses feature

Feature-first folder layout, mirroring `lib/features/friends/`
exactly. The `lib/features/expenses/` folder currently contains only
`README.md` + `.gitkeep`; PR #38 fills it.

```
lib/features/expenses/
  application/
    add_expense_controller.dart           # Riverpod StateNotifier (AddExpenseState)
    expense_telemetry.dart                # Event-name constants (post-chore-#25) + emit helpers
  data/
    expense_repository.dart               # Firestore writer + ExpenseCreateError typed errors
  domain/
    add_expense_state.dart                # Sealed AddExpenseState (Editing / Saving / Success / Error)
    expense_category.dart                 # ExpenseCategory enum + label/icon map
    expense_draft.dart                    # UI-state model
    expense_doc.dart                      # Firestore-shape model with toCreateMap()
    split_method.dart                     # SplitMethod enum (equal + exact enabled in PR #38)
    split_calculator.dart                 # Pure top-level computeSplits(...); integer paise only
  presentation/
    add_expense_bottom_sheet.dart         # Root sheet (host)
    steps/
      step_1_amount_details.dart
      step_2_split_and_payer.dart
    widgets/
      expense_category_grid.dart
      split_row.dart
      split_validation_message.dart
  README.md                               # Populated by Phase 3 with implemented scope
```

Tests at `test/features/expenses/` mirror the source layout, plus
`test/integration/expenses/expense_creation_flow_test.dart` for the
emulator round-trip and `test/core/widgets/inputs/obt_amount_input_test.dart`
per §2.8.

### 2.2 Controller state machine

`AddExpenseController extends StateNotifier<AddExpenseState>`
(Riverpod 2.x). Precedent: `MatchAndInviteController` at
`lib/features/friends/application/match_and_invite_controller.dart`,
which uses a sealed-class state hierarchy and emits one telemetry
event per state transition through private `_emit*` helpers.
PR #38 mirrors that contract.

`AddExpenseState` is a sealed class with the following cases (defined
in `lib/features/expenses/domain/add_expense_state.dart`):

```dart
sealed class AddExpenseState { const AddExpenseState(); }

class Editing extends AddExpenseState {
  const Editing({
    required this.step,                  // 1 or 2
    required this.draft,                 // ExpenseDraft
    required this.validationErrors,      // Map<String, String>
  });
  final int step;
  final ExpenseDraft draft;
  final Map<String, String> validationErrors;
}

class Saving extends AddExpenseState {
  const Saving({required this.draft});
  final ExpenseDraft draft;
}

class Success extends AddExpenseState {
  const Success({required this.expenseId});
  final String expenseId;
}

class Error extends AddExpenseState {
  const Error({
    required this.draft,
    required this.errorType,             // ExpenseCreateErrorType
    required this.message,               // User-facing copy
  });
  final ExpenseDraft draft;
  final ExpenseCreateErrorType errorType;
  final String message;
}
```

The controller is the sole owner of: (a) telemetry emission via the
private `_emit*` helpers in `expense_telemetry.dart`, (b) Firestore
writes via the injected `ExpenseRepository`, and (c) splitter
invocation via the pure top-level function described in §2.3. UI
widgets are pure projections of state — they NEVER call the
repository directly and NEVER emit telemetry directly.

Telemetry hand-offs follow the FR-FR-03 / FR-SE-03-04 precedent of
**one event per state transition**, named via the post-chore-#25
constants. Each `_emit*` method takes explicitly typed parameters and
hashes any identifier via `hashFriendshipId()` / `hashId()` from
`lib/core/telemetry/event_id_hash.dart` (ADR-0013). The
PII-leak test (AC-17) enforces this.

Transition map (informative):

| Transition | Telemetry event |
|---|---|
| `null → Editing(step:1)` (sheet open) | `expense_step1_opened` |
| `Editing(step:1) → Editing(step:1)` (category tap) | `expense_category_selected` |
| `Editing(step:1) → Editing(step:2)` (Next) | `expense_step1_completed` THEN `expense_step2_opened` |
| `Editing(step:2) → Editing(step:2)` (method change) | `expense_split_method_changed` |
| `Editing(step:2) → Editing(step:2)` (payer change) | `expense_payer_changed` |
| `Editing(step:2) → Editing(step:2)` (failed sum check) | `expense_split_validation_failed` |
| `Editing(step:2) → Saving` (Save valid) | `expense_step2_completed` |
| `Saving → Success` (write ok) | `expense_save_succeeded` (post-chore-#25) |
| `Saving → Error` (write throws) | `expense_save_failed` (post-chore-#25) |
| `Editing(step:1) → null` (discard with data) | `expense_step1_abandoned` |
| `Editing(step:2) → null` (discard) | `expense_step2_abandoned` |

Discards from step 1 with an empty draft emit nothing — the user has
expressed no intent to add an expense.

### 2.3 Splitter discipline

`split_calculator.dart` exports a pure top-level function:

```dart
List<Split> computeSplits({
  required SplitMethod method,
  required int totalPaise,
  required List<String> memberUids,
  String? payerUid,
  List<int>? exactShares,
});
```

The function is pure, integer-only, deterministic. The caller
(controller) MUST pre-sort `memberUids` current-user-first; the
splitter does NOT re-sort (a single ordering convention prevents
two-source-of-truth bugs). The returned `splits[i].userId` follows
the order of the passed `memberUids`.

Algorithm per method (friendship has exactly two members; N = 2):

- `equal`: `share = totalPaise ~/ 2; remainder = totalPaise % 2;
  splits = [{memberUids[0], share + remainder}, {memberUids[1],
  share}]`. The extra paise lands on the first share (deterministic;
  current-user-first). Sum is `totalPaise` by construction.
- `exact`: `splits = [{memberUids[0], exactShares[0]}, {memberUids[1],
  exactShares[1]}]`. The controller's validator gates on
  `exactShares.fold(0, (a, b) => a + b) == totalPaise` BEFORE the
  splitter is called; the splitter `assert`s the same invariant as
  defence in depth (the assertion only fires in debug; the security
  rules' `sumOfSharesEquals` check is the production safety net).
- `unequal`, `percentage`, `shares` are present in the
  `SplitMethod` enum but the controller treats their selection as a
  no-op for PR #38 (the UI's chip is disabled and `setSplitMethod`
  ignores them). When they ship in a follow-up PR, the splitter
  acquires three additional algorithm branches; the controller and
  repository contracts remain unchanged.

Integer discipline is absolute. The splitter MUST NOT take a `double`
anywhere. The boundary-contract grep test (AC-15) enforces no
`.toDouble()`, no `/100`, and no `double ` declarations across
`lib/features/expenses/**`.

Property-test discipline. The project already runs property tests on
the server splitter at
`functions/test/simplified-debts/algorithm.property.test.ts`; PR #38
brings the same discipline to the client at
`test/features/expenses/split_calculator_property_test.dart`. Properties:

1. `equal` with any `totalPaise ∈ [1, 99999999]` produces splits
   whose sum equals `totalPaise`.
2. `exact` with any valid `(totalPaise, exactShares)` pair (where the
   sum already matches) returns identity and the sum still equals
   `totalPaise`.
3. Determinism — for any input, two invocations with the same
   arguments return splits with identical ordering and values.
4. The extra-paise-on-first-share rule — for any odd `totalPaise`,
   `splits[0].sharePaise == splits[1].sharePaise + 1`.

### 2.4 Repository write target and shape

`expense_repository.dart` exposes:

```dart
abstract class ExpenseRepository {
  Future<String> createExpense({
    required String friendshipId,
    required ExpenseDoc doc,
  });
}
```

The Firestore-backed implementation writes to
`FirebaseFirestore.instance.collection('friendships').doc(friendshipId).collection('expenses').add(doc.toCreateMap())`
and returns the new auto-generated `expenseId`. The repository follows
the `FriendshipRepository` precedent at
`lib/features/friends/data/friendship_repository.dart` — abstract
store interface, Firestore-backed concrete implementation, and a
parse-failure sink for observability (when read paths are added in a
later PR).

`ExpenseDoc.toCreateMap()` MUST produce a document that satisfies every
predicate in `firestore.rules` lines 153–302 — specifically
`hasAllRequiredKeys`, `hasOnlyKnownKeys`, `isValidShape`,
`isValidExtensionPointLocks`, `areValidSplitElements`, and
`sumOfSharesEquals`. The exact field set:

```dart
Map<String, dynamic> toCreateMap() => {
  'amountPaise': amountPaise,                   // int, > 0 (rules: isValidShape)
  'description': description,                   // String (rules: size() <= 200; story tightens to 100 client-side)
  'category': category.name,                    // snake_case enum value (rules: is string)
  'date': Timestamp.fromDate(date),             // Timestamp (rules: is timestamp)
  'payerId': payerId,                           // String, must be in parent memberIds (rules: data.payerId in members)
  'splits': [
    {'userId': splits[0].userId, 'sharePaise': splits[0].sharePaise},
    {'userId': splits[1].userId, 'sharePaise': splits[1].sharePaise},
  ],                                            // size in [1,2]; each share >= 0; sum == amountPaise
  'splitMethod': splitMethod.name,              // 'equal' | 'exact' (others disabled in this PR)
  'receiptUrl': null,                           // FR-EX-05 deferred; rules accept null
  'createdBy': currentUserUid,                  // String == request.auth.uid (rules: isValidExpenseCreate)
  'createdAt': FieldValue.serverTimestamp(),    // Timestamp == request.time
  'updatedAt': FieldValue.serverTimestamp(),    // Timestamp == request.time
  'deleted': false,                             // bool (rules: deleted == false on create)
  'source': 'manual',                           // ARCH-EXT-07
  'currency': 'INR',                            // ARCH-EXT-02
};
```

`recurringRule` is **omitted** from the map per ARCH-EXT-03. The
rules accept absent OR `null` (`firestore.rules` line 190:
`!('recurringRule' in data) || data.recurringRule == null`). Omitting
is simpler than setting `null` and is explicitly permitted by the
rules; the schema doc lists `recurringRule` as optional with
`null` default, which is the absent case.

Note on schema vs screen-spec description length. The Firestore rules
permit `description.size() <= 200`
(`firestore.rules` line 197); the screen spec SCR-19 caps the client
input at 100 characters
(`docs/design/06-screen-specs/19-22-expenses.md` lines 71, 105). The
client validator uses the stricter spec value (100) so that the user
never composes a description the UI cannot re-display; the rules'
looser bound is the defence-in-depth floor and is not relaxed by
this PR.

Typed-error wrapper. The repository wraps the Firestore write in a
typed try/catch:

```dart
try {
  final ref = await _firestore
      .collection('friendships').doc(friendshipId)
      .collection('expenses').add(doc.toCreateMap());
  return ref.id;
} on FirebaseException catch (e, st) {
  throw ExpenseCreateError(
    type: switch (e.code) {
      'permission-denied' => ExpenseCreateErrorType.permissionDenied,
      'unavailable'       => ExpenseCreateErrorType.network,
      _                   => ExpenseCreateErrorType.unknown,
    },
    underlying: e,
    stackTrace: st,
  );
}
```

`ExpenseCreateError` is a value type with three cases:
`permissionDenied`, `network`, `unknown`. The controller catches
`ExpenseCreateError`, fires `expense_save_failed { error_type, is_offline }`
with the matching `error_type` parameter, and transitions to
`Error(draft, errorType, message)`. The user-facing message follows
SCR-19 / SCR-20 — "Couldn't add the expense. Try again."

### 2.5 Reading the friendship for context binding

The bottom sheet is opened from the Friend Detail placeholder
(`lib/features/friends/presentation/friend_detail_placeholder_screen.dart`),
which already holds the friendship doc via `friendsListProvider`
(PR #35). The bottom sheet constructor accepts the friendship's
identity directly — there is NO re-fetch inside the sheet:

```dart
class AddExpenseBottomSheet extends ConsumerWidget {
  const AddExpenseBottomSheet({
    super.key,
    required this.friendshipId,
    required this.currentUserUid,
    required this.otherUserUid,
  });
  final String friendshipId;
  final String currentUserUid;
  final String otherUserUid;
  // ...
}
```

The controller (created via a `StateNotifierProvider.family` keyed on
`friendshipId`) consumes the three values directly. The controller
does NOT depend on `userProfileProvider`, `friendsListProvider`, or any
other provider — its only injected dependencies are `expenseRepository`,
the telemetry sink, and a deterministic clock (for `time_spent_ms`
computation). This keeps controller tests pure and free of provider
setup.

**Payer dropdown labels — architect's call (PM Open Question 4).**
Adopt the PM default: **"You" / "Friend" placeholders**, with no
real-name resolution in this PR. Rationale: pulling `userProfileProvider`
into the bottom sheet drags a provider dependency into the controller
test surface, complicates the integration test setup, and would force
PR #38's scope to absorb a profile-resolution failure-mode branch
(deleted user; rules-denied; stale cache) that the FR-FR-03
architect notes §4 already documented as a polish concern with a
fallback to `displayName: "Unknown"`. The polish PR (likely paired
with FR-FR-04 Friend Detail full screen) replaces the placeholders
with real names; the bottom sheet's constructor gains an optional
`Map<String, String>? memberNames` parameter at that point.
Accessibility labels still read sensibly with the placeholders
(`Semantics(label: 'Payer: You')`).

### 2.6 No new ADR required

All technical moves above are within the precedent of existing ADRs:

- **ADR-0001** (simplified debts is the sole debt mechanism) — the
  client writes to `expenses`; the trigger maintains
  `simplifiedBalances`. No new debt model is introduced.
- **ADR-0002** (paise integer arithmetic) — every monetary value on
  the path from `OBTAmountInput.onChanged` to the Firestore write is
  an `int`. No `double` anywhere.
- **ADR-0006** (Riverpod state management) — `AddExpenseController`
  is a `StateNotifier`, exposed via a `StateNotifierProvider.family`
  keyed on `friendshipId`. The `MatchAndInviteController` precedent
  is followed unmodified.
- **ADR-0007** (feature-first folder layout) — `lib/features/expenses/`
  follows the same `application/` + `data/` + `domain/` +
  `presentation/` partition used by `lib/features/friends/`.
- **ADR-0013** (PII / telemetry hashing) — every event parameter
  carrying `friendship_id` or `expense_id` is hashed at the emit
  boundary via `hashFriendshipId()` / `hashId()` from
  `lib/core/telemetry/event_id_hash.dart`. The PII-leak test
  (AC-17) enforces.

The chore #25 decision (§2.0) is a naming-convention ratification —
too small to warrant a fresh ADR. It is recorded here, propagated
through the telemetry plan, and tracked by the audit's SR8 closure.

### 2.7 Coverage gate posture

- `lib/features/expenses/**` is a NEW feature folder. Per-module
  coverage gate is ≥ 70 %. Target ≥ 80 % on the controller
  (`add_expense_controller.dart`) and the splitter
  (`split_calculator.dart`) — both are pure / mostly pure and
  exhaustively testable.
- `lib/features/expenses/presentation/**` widgets target ≥ 70 % via
  the bottom sheet widget tests in
  `test/features/expenses/add_expense_bottom_sheet_widget_test.dart`.
- `lib/core/**` sees no changes; its coverage is unchanged.
- The integration test
  `test/integration/expenses/expense_creation_flow_test.dart` runs
  against the emulator and exercises the round-trip via the
  registered PR #36 trigger. It does not contribute to the per-module
  coverage gate (integration tests run separately under
  `firebase emulators:exec`) but is mandatory for AC-14.
- The property tests at
  `test/features/expenses/split_calculator_property_test.dart`
  extend the property-test discipline already established on the
  server splitter (`functions/test/simplified-debts/algorithm.property.test.ts`).

### 2.8 `OBTAmountInput` extract vs inline — Option E (extract)

**Decision: Option E.** Extract `OBTAmountInput` to
`lib/core/widgets/inputs/obt_amount_input.dart` with the contract that
it emits paise via `onChanged: ValueChanged<int>`.

Path rationale. The source prompt's preferred path is
`lib/core/design_system/inputs/obt_amount_input.dart`, but that
namespace does NOT exist in the codebase today —
`lib/core/widgets/` is the established location for shared widgets and
currently contains only `india_phone_input_formatter.dart` (a
`TextInputFormatter`, not a widget). The codebase-aligned choice is to
extend the existing `lib/core/widgets/` namespace with a new sub-folder
`inputs/` rather than create a parallel `lib/core/design_system/`
namespace that does not exist anywhere else in the tree. This avoids
two divergent conventions and keeps the import paths consistent with
the existing `import 'package:onebytwo/core/widgets/india_phone_input_formatter.dart';`
pattern. When the design-system catalogue grows (FR-SE-08 settle-up
will need the same widget; future PRs introducing `OBTCategoryChip`,
`OBTRupeeText`, `OBTBalancePill`, etc. will follow), they all land in
sub-folders under `lib/core/widgets/` (e.g. `chips/`, `text/`).
The conflict with the source prompt is recorded; the codebase-aligned
path wins per the task brief's hard constraint.

Contract:

```dart
class OBTAmountInput extends StatefulWidget {
  const OBTAmountInput({
    super.key,
    this.initialAmountPaise,
    required this.onChanged,
    this.autoFocus = true,
    this.errorText,
    this.enabled = true,
  });

  /// Pre-filled amount in paise for edit flows; null shows the empty placeholder.
  final int? initialAmountPaise;

  /// Fires on every valid change with the current value in PAISE (int).
  /// Never emits a double; never emits a rupee value. Per Invariant 1, paise
  /// is the integer unit on every monetary boundary above the rendering layer.
  final ValueChanged<int> onChanged;

  final bool autoFocus;
  final String? errorText;
  final bool enabled;
}
```

Implementation contract:

- `keyboardType: TextInputType.numberWithOptions(decimal: true)`.
- A `TextInputFormatter` that (a) refuses non-numeric input, (b)
  enforces at most two digits after the decimal point, (c)
  live-formats the integer rupee component with Indian numbering via
  `NumberFormat.decimalPattern('en_IN')` (the same package
  `lib/core/formatters/inr_formatter.dart` uses for the read side).
- The `₹` prefix is rendered as a fixed `Text` widget inside the
  input decoration; it is never part of the editable text.
- The emitted `int` value is computed as
  `(rupees * 100) + paiseFractional` using integer arithmetic only.
  No `double.parse`, no `toDouble()`, no division by 100.
- Maximum value enforced: `99999999` paise (₹99,99,999.99 per the
  catalogue and SCR-19); any keystroke that would exceed the cap is
  silently rejected and the `errorText` is rendered as supplied by
  the caller (the controller hosts the error message — the widget is
  presentation-only).

Tests live at `test/core/widgets/inputs/obt_amount_input_test.dart`
and cover: integer-only emission contract (typing "12.34" emits
`1234` after each valid keystroke); cap enforcement (typing
"100000000.00" tops at the cap and never emits an out-of-range value);
backspace re-emits the lower value; disabled state suppresses
`onChanged`; the `₹` prefix is non-editable; the formatter rejects
multiple decimal points and non-numeric input.

Coverage impact. The widget contributes a new module under
`lib/core/widgets/inputs/**`; per the existing per-module 70 % gate,
the widget tests must clear that bar. Aim for full branch coverage on
the formatter logic since it is the boundary at which user rupee
input becomes the paise integer that flows through every downstream
layer to Firestore.

### 2.9 `expense_category.dart` enum + label / icon map

Eight values from FR-EX-08 per
`docs/design/06-screen-specs/19-22-expenses.md` line 33. Snake-case
strings on Firestore (`expense_category.dart` uses Dart enum
`.name` which is the snake-case value — Dart enums preserve the
declared identifier verbatim). The screen spec lists icon names
informally; the architect-ratified Material Icons set is below.

```dart
enum ExpenseCategory {
  food,
  travel,
  rent,
  utilities,
  groceries,
  entertainment,
  shopping,
  other,
}

const Map<ExpenseCategory, String> expenseCategoryLabel = {
  ExpenseCategory.food:          'Food',
  ExpenseCategory.travel:        'Travel',
  ExpenseCategory.rent:          'Rent',
  ExpenseCategory.utilities:     'Utilities',
  ExpenseCategory.groceries:     'Groceries',
  ExpenseCategory.entertainment: 'Entertainment',
  ExpenseCategory.shopping:      'Shopping',
  ExpenseCategory.other:         'Other',
};

const Map<ExpenseCategory, IconData> expenseCategoryIcon = {
  ExpenseCategory.food:          Icons.restaurant,
  ExpenseCategory.travel:        Icons.flight,
  ExpenseCategory.rent:          Icons.home,
  ExpenseCategory.utilities:     Icons.bolt,
  ExpenseCategory.groceries:     Icons.local_grocery_store,
  ExpenseCategory.entertainment: Icons.movie,
  ExpenseCategory.shopping:      Icons.shopping_bag,
  ExpenseCategory.other:         Icons.more_horiz,
};
```

Rationale for the icon picks: each icon is a single-glyph Material
Icon that reads at 24 dp without ambiguity on both light and dark
backgrounds. `restaurant` (not `fastfood` or `local_dining`) is
the broadest food affordance; `flight` (not `directions_car`)
generalises across travel modes; `home` is the universal rent /
housing affordance; `bolt` (not `flash_on` which is deprecated)
covers electricity, water, internet; `local_grocery_store` is
unambiguous; `movie` (not `theaters`) reads as entertainment
broadly; `shopping_bag` (not `shopping_cart` which conflates with
groceries) keeps shopping visually distinct from groceries;
`more_horiz` is the standard "other / overflow" affordance.

The Firestore `category` field is a `string` (per the schema, line 138
of `docs/design/07-technical/firestore-schema.md`); the rules do NOT
enumerate the allowed values (`firestore.rules` line 198 is just
`data.category is string`). The client enum is therefore the gate —
the validator only accepts an `ExpenseCategory` instance; the
`toCreateMap()` serialises via `.name`; an unknown server-side value
read in a future PR (read paths are out of scope here) will need a
`ExpenseCategory? tryParseExpenseCategory(String)` companion. The
parse helper is NOT shipped in PR #38; it is added when the first
read path lands (likely FR-FR-04 Friend Detail full screen).

### 2.10 Entry-point scope — FAB on `friends_list_screen.dart` (PM Open Question 3)

**Decision: no-op for PR #38.** The only entry point to the Add
Expense flow shipped in this PR is the FAB on
`lib/features/friends/presentation/friend_detail_placeholder_screen.dart`
(the per-friend Friend Detail placeholder, which has the friendship
identity pre-bound from the route argument). The FAB on
`lib/features/friends/presentation/friends_list_screen.dart` remains a
no-op — tapping it does nothing visible.

Rationale. The trivial "Pick a friend first" snackbar variant would
itself need its own telemetry event, its own copy review, its own
accessibility label, and would create a UX dead-end (the user
expects the FAB to do something useful, sees a snackbar that tells
them they have to do something else first, and is left to navigate
on their own). The right answer to "I want to add an expense from
the friends list" is a friend picker — which is the SCR-08
multi-context entry-point chooser, and that is its own story per
the Out of Scope list. Shipping the snackbar half-measure here would
either be retired when the chooser arrives (sunk work) or harden
into a long-lived placeholder (a worse UX than no-op). The no-op is
honest: the FAB on the friends list is reserved for the chooser PR,
and the only producer of expense writes in PR #38 is the FAB on the
per-friend placeholder where the friendship context is already
bound.

A `// TODO(SCR-08): wire the multi-context FAB chooser` comment is
placed in `friends_list_screen.dart` next to the FAB's `onPressed`
to make the deferred work discoverable. No telemetry event is
emitted for the no-op (Firebase Analytics does not record events that
do not fire, and adding a `fab_tapped_unwired` would breach the
"events fire on real user-visible state changes" rule from the
telemetry plan section 3 privacy rules).
