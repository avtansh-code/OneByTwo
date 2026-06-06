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
