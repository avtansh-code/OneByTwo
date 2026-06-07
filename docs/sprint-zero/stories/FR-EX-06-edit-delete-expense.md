# FR-EX-06: Edit / Delete an Existing Expense (Friendship Context)

> Implementation-ready user story for the **first client mutator of
> existing expense documents** in the OneByTwo application. Ships an
> edit surface (dedicated Expense Detail screen or direct edit sheet
> — architect's choice at §2.1) that pre-fills the existing expense
> values into the same two-step `AddExpenseBottomSheet` PR #38 built,
> lets the creator modify any non-immutable field, and writes a
> partial-update map back to `friendships/{fid}/expenses/{eid}`.
> Adds a soft-delete affordance via `OBTConfirmationDialog`, writing
> `{ deleted: true, updatedAt: serverTimestamp() }` only. The
> existing `onExpenseWriteFriendship` trigger (PR #36) re-fires on
> every update and every soft-delete and recomputes
> `simplifiedBalances` + `lastActivityAt` atomically; PR #42's
> Friend Detail timeline re-emits and re-renders the post-edit
> state within NFR-PE-04's 2.5 s P95 budget. Closes the friendship
> expense-mutation loop. Group-context edit / delete is the Sprint 3
> groups epic and is explicitly out of scope.

---

## SRS Requirement ID(s)

FR-EX-06 (SRS section 4.5 — edit / delete expenses, both friendship
and group contexts; this story covers the friendship half only),
FR-EX-04 (SRS section 4.5 — paise integer arithmetic; per-split
shares sum exactly to total on every update),
FR-SE-04 (SRS section 4.6 — `simplifiedBalances` recomputed
atomically on every expense write, including updates and
soft-deletes; consumed unchanged from PR #36).

## Relevant SRS Sections

- Section 4.5 — Expenses (FR-EX-06 edit / delete, including the P0
  priority assignment at line 211; the corresponding group-context
  edit / delete is the Sprint 3 groups epic and is out of scope
  here).
- Section 4.6 — Atomic recompute of simplified balances on every
  expense write (consumed unchanged from PR #36; no server work in
  this PR).
- Section 5.10 — Observability (telemetry funnel — extends with
  nine new edit / delete events; every `expense_id` and
  `friendship_id` parameter SHA-256 truncated per ADR-0013).
- Section 7.3 — Invariants (Invariant 1 — paise integers,
  write-side return; Invariant 2 — `simplifiedBalances`
  server-maintained, client-read-only, negative-guard load-bearing
  on this PR; Invariant 3 — N/A; Invariant 4 — single Firebase
  project, defence-in-depth re-check).
- Section 7.5 — Data model and security rules (`expenses`
  subcollection schema; soft-delete is the deletion mechanism — the
  `deleted: true` flip is the only "delete" path the rules permit
  for clients; `allow delete: if false` per `firestore.rules`
  line 301).

## Priority

**P0 — Must have.** SRS section 4.5 line 211 categorises FR-EX-06
as P0. Without it, the only mutation a user can perform on a
created expense is to add a compensating expense, which (a) breaks
the activity-log invariant ("each entry is the truth of what
happened" — SRS §7.5), (b) accumulates incorrect rows on the
Friend Detail timeline PR #42 ships, and (c) makes genuine
corrections impossible (a typo in the amount, a wrong category, a
wrong split method). PR #46 completes the friendship expense
lifecycle: create (PR #38) → view (PR #42) → edit / delete (this
PR).

## Story Points

**5.** Scope: extend the existing `AddExpenseBottomSheet` with an
edit-mode constructor + per-field pre-fill; add `updateExpense` +
`softDeleteExpense` to `ExpenseRepository` with typed-error
mapping; extract `OBTConfirmationDialog` to
`lib/core/widgets/dialogs/`; add nine new telemetry constants +
propagation; wire the on-tap stub at
`lib/features/friends/presentation/widgets/friend_detail_timeline.dart`
lines 92-95; extend the rules-test suite with four new tests for
the update + soft-delete paths; extend the boundary-contract grep;
extend the PII-leak test; add a skipped integration-test stub.
Reuses ~50 % of PR #38's sheet + controller + repository surface;
only the new code paths (edit mode, soft-delete, the dialog) carry
net-new implementation cost. Escalate to **8 SP** only if the user
requests full transactional concurrent-edit detection at PR review
(see Out of Scope item (f)).

## Status

**Ready for Architect Notes.** PM authorship complete. Architect
appends `## Architect Notes` (Phase 2 §2.1–§2.9 per the source
prompt `docs/copilot_prompts/sprint_2/12.md`) in a separate commit
before Phase 3 implementation begins.

## PR Target

**PR #46** on branch `feat/fr-ex-06-edit-delete-expense`.

## GitHub Issue Closed

**None.** FR-EX-06 is tracked as a P0 SRS row (section 4.5 line
211); no separate GitHub issue exists. The PR body references the
SRS row directly. Any post-v1.0 follow-ups (group-context
edit / delete, transactional concurrent-edit detection, receipt
re-attach) may file dedicated issues at that point.

## User Story

As **an authenticated friendship member who created an expense
visible on the Friend Detail timeline**,
I want **to tap the expense row and either modify any of its
non-immutable fields (amount, description, category, date, split
method, payer, per-split amounts) and save the changes, or
soft-delete the expense with a confirmation step**,
so that **typos and category mistakes can be corrected and
unwanted expenses can be removed without leaving stale rows, with
the friendship's simplified net balance and the Friend Detail
timeline both re-rendering the post-edit state automatically and
without any client-side debt arithmetic**.

---

## Preconditions

1. The user is authenticated (Phone Auth completed per FR-AU-03 /
   FR-AU-04 / FR-AU-05) and the auth session is restored
   (FR-AU-07).
2. A friendship document exists at `friendships/{fid}` with
   `memberIds == [self, friend]` (deterministic composite ID per
   PR #32) and `simplifiedBalances` populated by the existing
   trigger.
3. At least one non-deleted expense document exists at
   `friendships/{fid}/expenses/{eid}` with `createdBy ==
   currentUser.uid` (i.e. the current user created it; the rules
   at `firestore.rules` lines 297-298 gate update on
   `isCallerFriendshipMember()` AND `isValidExpenseUpdate()`,
   whose `createdBy == prev.createdBy` clause means a non-creator
   cannot mutate `createdBy` to themselves — combined with the
   client-side UI gate, only the creator can edit or soft-delete
   in practice).
4. The `onExpenseWriteFriendship` trigger (PR #36) is live in
   `asia-south1`. The `ChangeType` discriminator at
   `functions/src/triggers/on-expense-write/function.ts` line 79
   already covers `create`, `update`, `delete`;
   `recomputeSimplifiedBalances` re-runs on each.
   **Zero server-side work** is required in this PR.
5. The Friend Detail timeline from PR #42 renders the expense
   rows with the reserved on-tap stub at
   `lib/features/friends/presentation/widgets/friend_detail_timeline.dart`
   lines 92-95 (`// No-op for PR #42. FR-EX-06 will own the edit
   / delete flow.`). This PR wires that stub.
6. `lib/features/expenses/domain/expense_doc.dart` line 84 sets
   `updatedAt: FieldValue.serverTimestamp()` on every create; this
   is the timestamp the eventual concurrent-edit detection
   (deferred per Out of Scope item (f)) would compare against.
7. The Firebase Emulator Suite is available for pre-merge
   integration testing. The new integration-test stub at
   `test/integration/expenses/edit_delete_expense_flow_test.dart`
   ships skipped (PY3 partial credit — running is gated on the
   Flutter emulator harness).

---

## Background / Context

- **PR #36** shipped `onExpenseWriteFriendship` — the trigger on
  `friendships/{fid}/expenses/{eid}` that discriminates
  `ChangeType = create | update | delete` at
  `functions/src/triggers/on-expense-write/function.ts:79` and
  re-runs `recomputeSimplifiedBalances` plus a `lastActivityAt`
  monotonicity guard on every write. The trigger has been live in
  production since PR #36 merged; its update + delete branches
  have been exercised end-to-end by integration tests but never by
  a real client. PR #46 is the first client producer of the
  `update` and the soft-delete writes.
- **PR #38** shipped FR-EX-01 — the first client producer of
  expense `create` writes via the two-step
  `AddExpenseBottomSheet`. PR #38 is the architectural blueprint
  PR #46 extends in-place: the same sheet, the same controller
  (`AddExpenseController`), the same repository
  (`ExpenseRepository`), the same telemetry constants module
  (`lib/features/expenses/application/expense_telemetry.dart`),
  and the same `OBTAmountInput` reusable widget. SCR-21 (receipt
  summary) was DEFERRED in PR #38 to FR-EX-05; the two-step flow
  PR #38 shipped is therefore the basis for PR #46's edit flow.
  Re-introducing SCR-21 here is scope creep (see Out of Scope
  item (a)).
- **PR #42** made the per-friend expense rows visible on the
  Friend Detail timeline (read-only). The on-tap callback at
  `friend_detail_timeline.dart:92-95` was reserved for PR #46
  with the explicit comment `// No-op for PR #42. FR-EX-06 will
  own the edit / delete flow.`. This PR wires that callback.
- **PR #43** shipped FR-SE-05 / FR-SE-06 settle-up — the second
  client producer of monetary writes (settlements rather than
  expenses). Patterns from PR #43 (typed-error repository, no-op
  guard on the primary CTA, snackbar feedback, integration-test
  stubs) are precedent.
- **PR #45** landed the bundled hygiene plus the
  `lookupUserByPhoneNumber` rate-limit doc-path fix. Sprint 2
  velocity through end of PR #45: 40 SP across 12 PRs. PR #46 is
  the natural P0 follow-on — the simplified-debts round-trip
  closes for the first time via a real client **mutation** of a
  monetary document (rather than just creation).
- **The trigger consumes PR #46's writes unchanged.** The `update`
  branch of `ChangeType` re-fires `recomputeSimplifiedBalances`
  on the new shape; the soft-delete is an `update` from the
  trigger's perspective (the document still exists; only the
  `deleted` flag flips). `recomputeSimplifiedBalances` filters
  non-deleted expenses, so a soft-deleted expense drops out of
  the projection automatically.
- **Invariant 1 (paise integers) is write-side load-bearing** for
  the third time in Sprint 2 (PR #38 added create-side; PR #43
  added settlement-side; PR #46 adds edit-side). Every edited
  `amountPaise` flows from `OBTAmountInput.paiseValue` through
  the controller into `ExpenseDoc.toUpdateMap(...)` with zero
  floating-point arithmetic. The boundary-contract grep extends
  to cover any new files under
  `lib/features/expenses/presentation/**` AND
  `lib/features/expenses/application/**`.
- **Invariant 2 (`simplifiedBalances` server-only) is the
  load-bearing NEGATIVE invariant** for PR #46. The client writes
  ONLY to `friendships/{fid}/expenses/{eid}` on edit AND on
  soft-delete; never to `friendships/{fid}.simplifiedBalances`.
  The existing PR #36 rules test ("rejects client writes to
  simplifiedBalances") continues to enforce defence-in-depth.
- **The merged-document rules posture.** Firestore evaluates
  security rules against the **post-write merged document**
  (`request.resource.data`), not against the partial-update
  payload. So a partial update of the form
  `.update({ amountPaise: 2500, updatedAt: serverTimestamp() })`
  is merged onto the existing document, and `isValidExpenseShared`
  (lines 254-263) and `isValidExpenseUpdate` (lines 275-284) are
  then evaluated on the merged result. This is why the
  partial-update map need not carry every required key — Firestore
  fills the rest from the existing document — but the merged
  result must still satisfy `hasAllRequiredKeys`,
  `hasOnlyKnownKeys`, `sumOfSharesEquals`, etc. The architect
  ratifies the typed-mapping helper that produces the
  partial-update map by diffing `(edited, original)` in §2.3.

---

## Scope (in PR #46)

- **Edit flow as a two-step bottom sheet, mirroring PR #38's
  `AddExpenseBottomSheet` with pre-filled values.** The edit
  sheet is titled "Edit Expense (N/2)" (NOT "Edit Expense (N/3)"
  — SCR-22 §Components Used line 427 describes a three-step flow
  because SCR-21 (receipt summary) was part of the original
  FR-EX-01 plan, but PR #38 shipped FR-EX-01 with the receipt
  step DEFERRED to FR-EX-05). The third receipt-summary step
  remains deferred with FR-EX-05; the architect ratifies this
  position in §2.1 of Architect Notes.
- **Pre-fill from Firestore.** Every editable field — amount
  (Step 1), description (Step 1), category (Step 1), date
  (Step 1), payer (Step 2), split method (Step 2), per-split
  amounts (Step 2) — is pre-filled from the existing expense
  document at sheet-open. `OBTAmountInput.initialAmountPaise`
  carries the existing `amountPaise`; the category chip for the
  existing category is pre-selected; the date picker shows the
  existing date; the payer dropdown reflects the existing
  `payerId`; the split-method chip and the per-split rows
  reflect the existing `splitMethod` and `splits[]`.
- **No-op guard.** The "Save Changes" primary CTA on Step 2 is
  disabled until the user has modified at least one field. The
  comparison is field-by-field per SCR-22 §Inputs and Validation
  line 487 (amount in paise, description trimmed, date,
  category, payer, split method, each `sharePaise`). The
  semantic label on the disabled CTA reads "Save changes, no
  modifications made." per SCR-22 §Accessibility line 510.
- **Changed-field indicator.** When at least one field has been
  modified, the modified rows on Step 2's summary render with a
  `secondary` (`#F4A261`) left border AND a semantic label
  suffix ", changed." per SCR-22 §Accessibility line 509
  (information not conveyed by colour alone — WCAG 1.4.1).
- **Partial-update write shape.** On Save, the repository emits
  a partial-update map containing ONLY the changed fields PLUS
  `updatedAt: FieldValue.serverTimestamp()`. The map MUST NOT
  contain either of the two immutable historical fields
  enforced by `isValidExpenseUpdate()` at `firestore.rules`
  lines 281-282 — `createdBy` and `createdAt`. The other fields
  validated by `isValidExpenseShared()` (`payerId`, `splits`,
  `splitMethod`, `category`, `currency`, `amountPaise`,
  `description`, `date`, `receiptUrl`) are shape-validated on
  every update but are NOT immutability-locked, so the edit
  flow may include any of them in the partial-update map;
  SCR-22's edit-flow assumption (every editable field on Step 1
  + Step 2 may legitimately change) is correct.
- **Soft-delete flow via `OBTConfirmationDialog`.** A Delete
  affordance (overflow menu in the edit sheet, OR app-bar action
  on the Expense Detail screen — architect's call at §2.1)
  opens an `OBTConfirmationDialog` with `title: "Delete this
  expense?"`, `body: "This will update balances for all
  participants. This cannot be undone."`,
  `cancelLabel: "Cancel"`, `confirmLabel: "Delete"`,
  `isDestructive: true` per SCR-22 §Delete Flow lines 456-461.
  On confirm, `softDeleteExpense(...)` writes
  `{ deleted: true, updatedAt: FieldValue.serverTimestamp() }`
  ONLY (no other field touched — rules test (iv) enforces).
- **`OBTConfirmationDialog` extraction.** The component is
  listed at `docs/design/02-design-system/components.md` item 24
  but does NOT yet exist in the codebase. PM recommends
  extraction to
  `lib/core/widgets/dialogs/obt_confirmation_dialog.dart` per
  the `OBTAmountInput` precedent from PR #38 (extract on first
  use to lock in the contract for the future SCR-13 "Leave
  group" use site). Architect ratifies in §2.5.
- **On-tap wire-up.** The reserved no-op at
  `lib/features/friends/presentation/widgets/friend_detail_timeline.dart`
  lines 92-95 is wired to navigate to the architect-chosen edit
  surface (dedicated Expense Detail screen per §2.1 choice (a)
  recommended, OR direct edit sheet per §2.1 choice (b)).
- **Friendship context only.** Group-context edit / delete is the
  Sprint 3 groups epic and is out of scope (see Out of Scope
  item (d)).
- **Nine new telemetry events.** Camp B naming (verb-past +
  state) matching PR #38's `expense_save_succeeded` /
  `expense_save_failed` convention. The full table is in
  the Telemetry Events Introduced section below.
- **Four new rules tests.** Extends
  `functions/test/firestore-rules/expenses-friendship.test.ts`
  with failing-first tests for: (i) rejects malformed update
  mutating `createdBy`; (ii) rejects malformed update mutating
  `createdAt`; (iii) rejects update by non-creator (rules-side
  defence-in-depth to complement the UI gate);
  (iv) rejects soft-delete that also mutates any other field
  (the soft-delete write must carry only `deleted: true` +
  `updatedAt`).

---

## Out of Scope

- **(a) FR-EX-05 Receipt attachment (SCR-21 — separate P1
  story).** Step 3 of the original three-step SCR-22 spec assumed
  FR-EX-05 had landed. PR #38 deferred FR-EX-05 to PR #47+
  candidates; PR #46 holds that line and stays at two steps. The
  Expense Detail screen (if elected per §2.1 choice (a)) is the
  natural future viewing surface for receipts.
- **(b) FR-EX-07 Activity feed (separate P0 story; PR #47+).**
  The trigger already emits the activity entries per the SRS
  schema on every `update` and `delete`; PR #46 trusts FR-EX-07's
  later implementation to read them. PR #46 must NOT add an
  activity-feed read surface, a `/activity` route, or any
  composite-index design for activity queries.
- **(c) FR-SE-09 Send reminder (separate P1 story).** Introduces
  the FCM dependency + the 24-hour rate-limit subcollection at
  `_rateLimits/{uid}/sends/counter` (which will exercise the
  PR #45 §2.9 pattern). Separate PR; PR #46 must NOT introduce
  FCM.
- **(d) Group-context edit / delete.** The second half of
  FR-EX-06 belongs to the Sprint 3 groups epic. The repository's
  `updateExpense` and `softDeleteExpense` methods will be
  generalisable to the `groups/{gid}/expenses/{eid}`
  subcollection, but the only call site shipped in this PR is
  the friendship caller. The `onExpenseWriteGroup` trigger and
  the groups UI are Sprint 3 surfaces.
- **(e) Hard delete.** SRS §7.5 explicitly defines deletion as
  the `deleted: true` flip (soft delete) so the activity feed
  can preserve audit history and balances can be re-derived
  from the log. `firestore.rules` line 301 denies `allow delete`
  for all clients (`allow delete: if false`). Hard delete is out
  of v1.0 scope.
- **(f) Full transactional concurrent-edit detection (AC-11 /
  AC-12 deferred — the trigger always re-fires on the latest
  state, server `updatedAt: serverTimestamp()` reflects latest
  write; defer to a follow-up PR — escalate scope to 8 SP if
  user requests at review).** The AC-11 and AC-12 wording in
  this story describes the EVENTUAL transactional
  `runTransaction()`-based behaviour for documentation purposes;
  the v1.0 implementation accepts last-write-wins and relies on
  the trigger's idempotent recomputation plus server
  `updatedAt: serverTimestamp()` for consistency. The architect
  ratifies this deferral in §2.4 of Architect Notes.
- **(g) Rate-limit transaction race refactor.** PR #45 §2.2
  explicitly deferred the `lookupUserByPhoneNumber` rate-limit
  transaction race fix (a behavioural-correctness concern under
  concurrent load). PR #46 does not touch the rate-limit
  subsystem.
- **(h) Any D-row Bucket-B item.** D1, D2, D4, D6, D7 stay on
  issue #22 for Sprint 4+.
- **`pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`,
  Android / iOS native shells, any Flutter dependency.**
  Dependency bumps stay on issue #22 for Sprint 4+.
- **`functions/package.json`, `functions/package-lock.json`,
  `firebase.json`, any GitHub Actions workflow file.** Runtime
  + SDK matrix fixed by PR #44; PR #46 does NOT touch the
  runtime configuration.
- **The notification-type schema discriminator** (`type:
  'expense_added' | 'expense_edited' | 'expense_deleted' | ...`
  in `docs/design/07-technical/firestore-schema.md:202` and
  cross-references). The AC-X4 negative guard from PR #45 still
  applies; the notification type is a Firestore **schema** field
  consumed by the FR-EX-07 activity feed, NOT a telemetry event.
  The chore-#25 Camp B ratification was scoped to telemetry
  only.

---

## Acceptance Criteria

### AC-1 — Row tap opens the edit surface

> Given a non-deleted expense row on the Friend Detail timeline
> rendered by
> `lib/features/friends/presentation/widgets/friend_detail_timeline.dart`
> (currently lines 92-95 carry the reserved no-op `// No-op for
> PR #42. FR-EX-06 will own the edit / delete flow.`)
> And the current user created the expense
> (`expense.createdBy == currentUser.uid`)
> When the user taps the row
> Then the architect-chosen edit surface opens — either a
> dedicated Expense Detail screen per §2.1 choice (a)
> recommended, OR the two-step edit bottom sheet directly per
> §2.1 choice (b) — with the expense pre-filled from Firestore
> And telemetry event `expense_edit_opened` fires with
> `expense_id` (SHA-256-truncated via `hashId()`),
> `context_type: 'friendship'`, `context_id` (`friendship_id_hash`
> via `hashFriendshipId()`).

### AC-2 — Pre-fill correctness

> Given an existing expense document at
> `friendships/{fid}/expenses/{eid}` with `amountPaise`,
> `description`, `category`, `date`, `payerId`, `splits`,
> `splitMethod`
> When the two-step edit sheet opens (mirroring PR #38's
> `AddExpenseBottomSheet` with pre-filled values; the third
> receipt-summary step remains deferred with FR-EX-05)
> Then every editable field on Step 1 (amount, description,
> category, date) and on Step 2 (split method, payer, per-split
> amounts) shows the existing value in the same format the
> create flow accepts
> And the amount field shows
> `formatInrFromPaise(existing.amountPaise)` as the initial
> display
> And the underlying `OBTAmountInput.paiseValue` initially
> equals the original `amountPaise` (integer paise; no `double`
> conversion on the read path)
> And the sheet title reads "Edit Expense (N/2)" (NOT "N/3").

### AC-3 — No-op guard on Step 2

> Given the two-step edit sheet is open with pre-filled values
> from AC-2
> And the user has NOT modified any field
> When the user navigates to Step 2 (the final step, where the
> primary CTA renders)
> Then the "Save Changes" CTA is disabled
> And the disabled-state semantic label reads "Save changes, no
> modifications made." per SCR-22 §Accessibility line 510
> And no Firestore write is issued
> And no `expense_edit_field_changed` event fires.

### AC-4 — Changed-field indicator on Step 2

> Given the user has modified one or more fields on Step 1 or
> Step 2
> When the Step 2 summary re-renders the changed rows
> Then each changed row carries a `secondary` (`#F4A261`)
> left border per SCR-22 §Edit Flow line 449
> AND each changed row's semantic label suffix reads
> ", changed." per SCR-22 §Accessibility line 509 (information
> not conveyed by colour alone — WCAG 1.4.1)
> And `expense_edit_field_changed` fires once per changed
> field per change session, deduplicated by field name within
> the session, with `field_name` (e.g. `amount`, `description`,
> `category`, `date`, `split_method`, `payer`, `share_amount`)
> and `expense_id` (hashed).

### AC-5 — Successful save

> Given the user has modified at least one field
> And all validations pass (amount > 0; description 1-100 chars
> trimmed; category selected; date not in the future; per-split
> amounts sum to total — identical to PR #38's Step 1 + Step 2
> validation per SCR-19 / SCR-20)
> When "Save Changes" is tapped on Step 2
> Then `ExpenseRepository.updateExpense(...)` writes a
> partial-update map containing ONLY the changed fields PLUS
> `updatedAt: FieldValue.serverTimestamp()` (NOT `createdBy`,
> NOT `createdAt` — see AC-14)
> And the existing `onExpenseWriteFriendship` trigger
> (`functions/src/triggers/on-expense-write/function.ts:79`
> `ChangeType = 'update'`) re-fires and re-computes
> `simplifiedBalances` + `lastActivityAt` atomically
> And the snapshot listener re-emits and the Friend Detail
> header pill + the updated row both re-render within the
> NFR-PE-04 2.5 s P95 budget
> And an `OBTSnackbar` of type `info` reading "Changes saved."
> appears per SCR-22 §Components Used
> And telemetry events `expense_edit_field_changed` (one per
> changed field, fired during the edit session) and
> `expense_edit_saved` (with `expense_id` hashed,
> `fields_changed` array, `split_method`, `friendship_id_hash`)
> fire.

### AC-6 — Validation failure on save

> Given the user attempts to save an invalid edit (e.g. amount
> set to 0; per-split amounts no longer sum to total;
> description empty after trim; date in the future)
> When the save is attempted
> Then the inline validation errors from the SCR-19 / SCR-20
> spec re-surface beneath the offending fields with `danger`
> borders
> AND no Firestore write is issued
> AND telemetry event `expense_edit_failed` fires with
> `expense_id` (hashed), `error_code` from the validation
> domain (e.g. `VALIDATION_FAILED_AMOUNT_ZERO`,
> `VALIDATION_FAILED_SPLITS_MISMATCH`,
> `VALIDATION_FAILED_DESCRIPTION_EMPTY`,
> `VALIDATION_FAILED_DATE_FUTURE`), and `is_offline`.

### AC-7 — Delete affordance visibility

> Given the user is the expense's creator
> (`expense.createdBy == currentUser.uid`)
> When the architect-chosen delete affordance renders
> (overflow menu item in the edit sheet per §2.1 choice (b),
> OR app-bar action on the Expense Detail screen per §2.1
> choice (a) recommended)
> Then "Delete" is visible and tappable
> And given the user is NOT the expense's creator
> Then the Delete affordance is NOT visible (the rules at
> `firestore.rules` lines 297-298 enforce the same constraint
> server-side via `isValidExpenseUpdate()`'s
> `createdBy == prev.createdBy` clause, but the client gates
> the UI first to avoid presenting an action that will always
> fail with `permission-denied`).

### AC-8 — Confirmation dialog opens

> Given the user (the creator) taps "Delete"
> When the dialog opens
> Then `OBTConfirmationDialog` (extracted to
> `lib/core/widgets/dialogs/obt_confirmation_dialog.dart` per
> §2.5 of Architect Notes, OR inlined per the architect's
> alternative) renders with
> `title: "Delete this expense?"`,
> `body: "This will update balances for all participants. This
> cannot be undone."`,
> `cancelLabel: "Cancel"`,
> `confirmLabel: "Delete"`,
> `isDestructive: true` per SCR-22 §Delete Flow lines 456-461
> And the dialog is announced as a modal with focus trapped
> ("Alert: Delete this expense?") per SCR-22 §Accessibility
> line 511
> And telemetry event `expense_delete_initiated` fires with
> `expense_id` (hashed via `hashId()`) and
> `context_type: 'friendship'`.

### AC-9 — Cancel the delete dialog

> Given the `OBTConfirmationDialog` is open
> When the user taps Cancel, the scrim, or invokes the system
> back gesture (which per SCR-22 §Accessibility line 514 maps
> to Cancel, NOT to the destructive action)
> Then the dialog dismisses
> And no Firestore write is issued
> And the edit surface returns to its prior state
> And telemetry event `expense_delete_cancelled` fires with
> `expense_id` (hashed).

### AC-10 — Successful soft-delete

> Given the user confirms the deletion
> When "Delete" is tapped in the dialog
> Then `ExpenseRepository.softDeleteExpense(...)` writes
> `{ deleted: true, updatedAt: FieldValue.serverTimestamp() }`
> ONLY (no other field touched — the rules tests in
> `functions/test/firestore-rules/expenses-friendship.test.ts`
> include test (iv) which rejects a soft-delete that also
> mutates any other field)
> And the existing `onExpenseWriteFriendship` trigger re-fires
> with `ChangeType = 'update'` (a soft-delete is an update
> from the trigger's perspective; the document still exists,
> only `deleted` flips;
> `recomputeSimplifiedBalances` filters non-deleted expenses
> so the soft-deleted expense drops out of the projection)
> And the snapshot listener emits and the row disappears from
> the Friend Detail timeline within NFR-PE-04's 2.5 s P95
> budget
> And the architect-chosen post-delete navigation lands (close
> the Expense Detail screen and pop back to Friend Detail per
> §2.1 choice (a); dismiss the sheet per §2.1 choice (b))
> And an `OBTSnackbar` of type `info` reading "Expense
> deleted." appears per SCR-22 §Components Used
> And telemetry event `expense_delete_confirmed` fires with
> `expense_id` (hashed), `amount_paise`, `participant_count: 2`.

### AC-11 — Concurrent-edit detection (DEFERRED — describes eventual behaviour)

> **DEFERRAL NOTE.** Full transactional concurrent-edit
> detection is deferred per Out of Scope item (f) and
> Architect Notes §2.4. The v1.0 implementation accepts
> last-write-wins and relies on the trigger's idempotent
> recomputation + server `updatedAt: serverTimestamp()` for
> consistency. The text below describes the EVENTUAL
> behaviour for documentation purposes and for the follow-up
> PR that ships transactional detection.
>
> Given the user opens the edit sheet and the same expense is
> updated by another client before the user taps "Save
> Changes"
> When the user taps Save
> Then the eventual implementation compares the original
> snapshot's `updatedAt` against the server's current
> `updatedAt` (via a `runTransaction()` read inside the same
> transaction as the write)
> And if they differ, the save is rejected with an
> `OBTSnackbar` type `error` reading "This expense was updated
> by someone else. Please reload and try again." with a
> "Reload" action that re-fetches and re-prefills the sheet
> per SCR-22 §Edit Flow line 488
> And telemetry event `expense_edit_failed` fires with
> `error_code: 'CONCURRENT_EDIT'` and `expense_id` (hashed).

### AC-12 — Concurrent-delete detection (DEFERRED — describes eventual behaviour)

> **DEFERRAL NOTE.** Same deferral as AC-11 — describes the
> eventual behaviour, not the v1.0 implementation. The v1.0
> behaviour is that the trigger re-fires on the latest state
> and the snapshot listener reconciles within 2.5 s; if the
> user's stale save lands after another client's delete, the
> rules' `isValidExpenseUpdate()` may still accept it (because
> the document exists post-`update`), and the user sees their
> edit applied followed by the deletion re-converging on the
> next listener tick.
>
> Given the user opens the edit sheet and the same expense is
> concurrently deleted by another client
> When the user taps Save
> Then the eventual implementation detects `not-found` via the
> transactional read
> And the save is rejected with an `OBTErrorState` showing
> title "Expense no longer exists" + subtitle "This expense
> was deleted by another user." + a "Go Back" CTA that
> navigates to the parent list per SCR-22 §States row 4
> (line 470) and §Edge Cases item 1 (line 520)
> And telemetry event `expense_edit_failed` fires with
> `error_code: 'NOT_FOUND'` and `expense_id` (hashed).

### AC-13 — Negative: non-creator cannot edit or delete

> Given a user who did NOT create the expense
> (`expense.createdBy != currentUser.uid`) is viewing the
> Friend Detail timeline
> When they attempt to tap the row
> Then either (a) the tap is a no-op per §2.1 choice (b), OR
> (b) a read-only Expense Detail screen opens with NO Edit
> and NO Delete affordances per §2.1 choice (a) recommended
> And in NO scenario does a non-creator's client issue an
> `updateExpense` or a `softDeleteExpense` call
> And the rules at `firestore.rules` lines 297-298 enforce
> defence-in-depth: `isValidExpenseUpdate()` requires
> `data.createdBy == prev.createdBy`, so any non-creator's
> attempted update either fails the `createdBy` immutability
> check (if they preserve it, the trigger and recomputation
> still credit the original creator) or fails outright with
> `permission-denied` at the rules layer.

### AC-14 — Negative: immutable-field protection

> Given the edit flow
> When the user saves changes
> Then the partial-update map MUST NOT contain either of the
> two immutable historical fields enforced by
> `isValidExpenseUpdate()` at `firestore.rules` lines
> 281-282 — specifically `createdBy` and `createdAt` (the
> only two fields the rules verify match the previous value
> via `data.createdBy == prev.createdBy` and
> `data.createdAt == prev.createdAt`)
> And the other fields validated by `isValidExpenseShared()`
> (`payerId`, `splits`, `splitMethod`, `category`, `currency`,
> `amountPaise`, `description`, `date`, `receiptUrl`) are
> shape-validated on every update but are NOT
> immutability-locked — the edit flow may include any of them
> in the partial-update map; SCR-22 §Edit Flow Differences
> from Add Flow lines 442-446 (which list category, date,
> payer, split method as pre-filled and editable) is correct
> And the rules-test suite extension in
> `functions/test/firestore-rules/expenses-friendship.test.ts`
> includes new test (i) which rejects malformed updates that
> mutate `createdBy` AND new test (ii) which rejects
> malformed updates that mutate `createdAt`.

### AC-15 — Negative: no client write to `simplifiedBalances`

> Given the PR diff
> When scanned via the boundary-contract grep across all
> changed and new files
> Then ZERO client-side writes to `simplifiedBalances` exist
> in any new or modified file (the field is server-maintained
> per Invariant 2; the existing trigger is the sole writer)
> And the existing PR #36 rules test ("rejects client writes
> to simplifiedBalances") continues to enforce
> defence-in-depth server-side
> And the existing boundary-contract grep test at
> `test/features/expenses/expense_creation_boundary_contract_test.dart`
> (extended per the architect's call to cover edit + delete
> files, OR a sibling
> `test/features/expenses/expense_edit_delete_boundary_contract_test.dart`)
> returns 0 matches for `simplifiedBalances` across
> `lib/features/expenses/**/*.dart` non-comment lines.

### AC-16 — Negative: Invariant 1 paise integers

> Given the PR diff
> When scanned for `double` arithmetic on any monetary value
> (`amountPaise`, `sharePaise`)
> Then ZERO `double` operations exist on the path from
> `OBTAmountInput.paiseValue` to
> `ExpenseRepository.updateExpense(...)` or to
> `ExpenseRepository.softDeleteExpense(...)`
> And the boundary-contract grep
> `grep -rEn '\.toDouble\(\)|/100\b|/100\.0\b|double ' lib/features/expenses/`
> returns 0 matches across `.dart` non-comment lines
> (excluding existing README inverse-documentation and the
> existing `///` doc-comment in `expense_repository.dart`)
> And the grep contract extends to cover any new files under
> `lib/features/expenses/presentation/**` AND
> `lib/features/expenses/application/**` introduced by this
> PR.

### AC-17 — Telemetry PII guard

> Given the PR diff
> When any of the nine new telemetry events fire with an
> `expense_id` or `friendship_id` parameter
> Then the parameter value is the SHA-256-truncated hash
> produced by `hashId()` (for `expense_id`) or
> `hashFriendshipId()` (for `friendship_id`) from
> `lib/core/telemetry/event_id_hash.dart` per ADR-0013
> And the per-feature PII-leak test pattern from PR #35 /
> PR #38 / PR #42 is extended (new test file
> `test/features/expenses/expense_edit_delete_telemetry_pii_leak_test.dart`
> OR new cases in the existing
> `test/features/expenses/expense_telemetry_pii_leak_test.dart`
> per the architect's call) to assert that no raw
> `expense_id` or `friendship_id` value appears in any
> emitted parameter payload across the edit + delete code
> paths.

### AC-18 — Integration-test stub for the round-trip

> Given the PR diff
> When `test/integration/expenses/` is inspected
> Then a new (skipped) integration-test file exists at
> `test/integration/expenses/edit_delete_expense_flow_test.dart`
> documenting the canonical edit + delete round-trip steps:
> (i) seed a friendship A↔B with one expense;
> (ii) open the edit sheet as user A;
> (iii) modify the amount;
> (iv) tap Save Changes;
> (v) confirm the trigger fires with `ChangeType = 'update'`;
> (vi) confirm the snapshot re-emits and the row updates
> with the new amount;
> (vii) open the delete dialog;
> (viii) confirm the deletion;
> (ix) confirm the trigger fires with `ChangeType = 'update'`
> (soft-delete);
> (x) confirm the snapshot re-emits and the row disappears
> And the test ships with `skip: 'Requires emulator suite'`
> (partial PY3 credit; running the test is gated on the
> Flutter emulator harness — same pattern as PR #38's
> `expense_creation_flow_test.dart` and PR #43's settle-up
> stub).

---

## Telemetry Events Introduced

The nine events PR #46 introduces. Camp B naming (verb-past +
state) matching PR #38's `expense_save_succeeded` /
`expense_save_failed` convention per the chore-#25 ratification
at Architect Notes §2.0 of FR-EX-01. SCR-22 §Telemetry Events
lines 494-502 is the authoritative source for the event names;
the architect may revisit the `saved`-vs-`succeeded` choice in
§2.6 of Architect Notes (PM recommendation: keep
`expense_edit_saved` per the SCR spec — the SCR is the source of
truth for screen-level events).

Every parameter that carries `expense_id` or `friendship_id`
MUST be SHA-256 truncated via `hashId()` / `hashFriendshipId()`
from `lib/core/telemetry/event_id_hash.dart` per ADR-0013
(enforced by AC-17).

| Event Name | Trigger | Parameters (PII-hashed per ADR-0013) | Constant Name in `expense_telemetry.dart` |
|---|---|---|---|
| `expense_edit_opened` | The edit surface first renders with pre-filled values (AC-1) | `expense_id` (hashed via `hashId()`), `context_type: 'friendship'`, `context_id` (`friendship_id_hash` via `hashFriendshipId()`) | `editOpened` |
| `expense_edit_field_changed` | A field flips from its original value (one event per field per change, deduplicated by field name within the session) (AC-4) | `field_name` (e.g. `amount`, `description`, `category`, `date`, `split_method`, `payer`, `share_amount`), `expense_id` (hashed) | `editFieldChanged` |
| `expense_edit_saved` | The edit successfully writes (AC-5) | `expense_id` (hashed), `fields_changed` (array of field names), `split_method`, `friendship_id_hash` | `editSaved` |
| `expense_edit_failed` | The edit save fails — validation, network, permission-denied, or (eventual) concurrent-edit / not-found (AC-6, AC-11, AC-12) | `expense_id` (hashed), `error_code` (e.g. `VALIDATION_FAILED_*`, `NETWORK`, `PERMISSION_DENIED`, `CONCURRENT_EDIT`, `NOT_FOUND`, `UNKNOWN`), `is_offline` | `editFailed` |
| `expense_edit_abandoned` | The user dismisses the edit sheet without saving (back arrow, scrim tap, system back gesture) | `expense_id` (hashed), `had_changes` (bool), `time_spent_ms` | `editAbandoned` |
| `expense_delete_initiated` | The user taps "Delete" (the `OBTConfirmationDialog` opens) (AC-8) | `expense_id` (hashed), `context_type: 'friendship'` | `deleteInitiated` |
| `expense_delete_confirmed` | The deletion successfully writes (AC-10) | `expense_id` (hashed), `amount_paise`, `participant_count: 2` | `deleteConfirmed` |
| `expense_delete_cancelled` | The user cancels the deletion dialog (AC-9) | `expense_id` (hashed) | `deleteCancelled` |
| `expense_delete_failed` | The deletion write fails (network, permission-denied, or unknown) | `expense_id` (hashed), `error_code` (e.g. `NETWORK`, `PERMISSION_DENIED`, `UNKNOWN`), `is_offline` | `deleteFailed` |

Note: the notification-type schema discriminator `'expense_edited'`
and `'expense_deleted'` (per SRS §7.5
`firestore-schema.md:202`) is a SEPARATE concern and is NOT a
telemetry event — it is a Firestore field name used by the
FR-EX-07 activity feed. The AC-X4 negative guard from PR #45
(notification-type schema discriminator unchanged) still applies
to PR #46.

---

## Definition of Ready

- [x] SRS sections cited and present: §4.5 (FR-EX-06 P0 at
      line 211; FR-EX-04 paise integers; FR-EX-08 / FR-EX-09
      inherited from PR #38), §4.6 (FR-SE-04 atomic recompute),
      §5.10 (telemetry funnel — extends with nine new events),
      §7.3 (Invariants 1 + 2 — write-side return for Inv-1;
      negative-guard load-bearing for Inv-2), §7.5 (data model
      — `deleted: boolean` for soft delete; hard delete out of
      scope per `allow delete: if false`).
- [x] Screen specs cited:
      `docs/design/06-screen-specs/19-22-expenses.md` — SCR-22
      (lines 398-530) is the authoritative spec, with the
      three-step flow CORRECTED to two steps per the Scope
      section (FR-EX-05 / SCR-21 receipt deferred per PR #38).
- [x] Wireframe baseline cited:
      `docs/design/04-wireframes/expense-flow.md` — the edit
      wireframes mirror the add wireframes with pre-filled
      values; the delete dialog is a standard
      `OBTConfirmationDialog`.
- [x] Design-system widget catalogue cited:
      `docs/design/02-design-system/components.md` —
      `OBTAmountInput` (item 6, reused from PR #38),
      `OBTConfirmationDialog` (item 24, to be extracted per
      §2.5 of Architect Notes), `OBTSnackbar` (item 25),
      `OBTErrorState` (item 19), `OBTSkeletonLoader` (item 20).
- [x] Firestore schema cited:
      `docs/design/07-technical/firestore-schema.md` —
      `friendships/{friendshipId}/expenses/{expenseId}` document
      table.
- [x] Firestore security rules cited: `firestore.rules` lines
      275-284 (`isValidExpenseUpdate()`) and lines 297-301
      (`allow update` + `allow delete: if false`). The expense
      subcollection rules shipped in PR #36; this PR consumes
      them, does not modify them.
- [x] Telemetry plan cited:
      `docs/design/07-technical/telemetry-plan.md` — section
      1.6 cluster for the edit / delete events; section 2.1
      for parameter conventions; section 2.2 for the SHA-256
      truncated identifier hashing pattern.
- [x] Extension-points register cited:
      `docs/design/03-architecture/extension-points-register.md`
      — ARCH-EXT-02 (currency locked to INR; must stay `'INR'`
      on every update), ARCH-EXT-03 (`recurringRule` stays
      omitted), ARCH-EXT-07 (`source: 'manual'` must stay).
- [x] Architectural precedent cited:
      `lib/features/expenses/` from PR #38 (the full feature
      folder is the blueprint PR #46 extends in-place: existing
      `application/`, `data/`, `domain/`, `presentation/`
      sub-folders); the `MatchAndInviteController` precedent
      from
      `lib/features/friends/application/match_and_invite_controller.dart`
      for sealed-class state hierarchy + private `_emit*`
      telemetry helpers.
- [x] Hand-off seams confirmed:
      `lib/features/friends/presentation/widgets/friend_detail_timeline.dart`
      lines 92-95 (no-op `InkWell.onTap` to be wired);
      `lib/features/expenses/domain/expense_doc.dart` line 84
      (`updatedAt: FieldValue.serverTimestamp()` already set on
      create — the eventual concurrent-edit detection's
      freshness baseline);
      `functions/src/triggers/on-expense-write/function.ts` line
      79 (`ChangeType` discriminator already covers `update` +
      `delete`).

---

## Invariant Applicability Assessment (DoR §9)

- **Invariant 1 (paise integers; conversion to rupees at the UI
  layer only):** APPLIES — **write-side return**. The edit
  flow's amount path runs `OBTAmountInput.paiseValue` (integer)
  → controller state (integer) → `ExpenseDoc.toUpdateMap()`
  (integer) → Firestore write (integer). The soft-delete write
  carries no monetary field at all. The boundary-contract grep
  extends to cover any new files under
  `lib/features/expenses/presentation/**` AND
  `lib/features/expenses/application/**`. AC-16 enforces.
- **Invariant 2 (`simplifiedBalances` server-maintained,
  client-read-only):** APPLIES — **negative-guard load-bearing**.
  The client writes ONLY to `friendships/{fid}/expenses/{eid}`
  on both edit and soft-delete; NEVER to
  `friendships/{fid}.simplifiedBalances`. The trigger remains
  the sole writer of that field. The existing PR #36 rules test
  ("rejects client writes to simplifiedBalances") continues to
  enforce defence-in-depth server-side. AC-15 enforces.
- **Invariant 3 (system share sheet only — no platform-specific
  share-target imports):** N/A. PR #46 has no share affordance.
- **Invariant 4 (single Firebase project):** APPLIES —
  **defence-in-depth re-check**. PR #46 touches a deployed
  client surface that talks to Firestore. `.firebaserc`
  continues to declare exactly one project
  (`"default": "onebytwo-avtanshgupta"`); the CI gate enforces.
  No additional project IDs introduced.
- **ADR-0013 (PII / telemetry hashing):** APPLIES to every one
  of the nine new telemetry events. Every parameter carrying
  `expense_id` or `friendship_id` MUST be hashed via `hashId()`
  / `hashFriendshipId()` from
  `lib/core/telemetry/event_id_hash.dart`. AC-17 enforces.

---

## Definition of Done

Reference: `docs/design/08-plan/definition-of-ready-and-done.md`.

- [ ] **Rules tests added.** Four new tests appended to
      `functions/test/firestore-rules/expenses-friendship.test.ts`:
      (i) rejects malformed update mutating `createdBy`;
      (ii) rejects malformed update mutating `createdAt`;
      (iii) rejects update by non-creator (rules-side
      defence-in-depth);
      (iv) rejects soft-delete that also mutates any other
      field.
      Baseline: 7 rules suites / 149 tests pass; target: 7
      suites / 153 tests pass.
- [ ] **Widget tests.** `OBTConfirmationDialog` leaf widget
      test at
      `test/core/widgets/dialogs/obt_confirmation_dialog_test.dart`
      (title + body rendering; cancel + confirm callbacks;
      `isDestructive` colour change; scrim dismiss; system back
      gesture maps to Cancel; accessibility — focus trap, label
      semantics). Edit-mode `AddExpenseBottomSheet` widget
      tests extending
      `test/features/expenses/add_expense_bottom_sheet_widget_test.dart`
      (pre-fill correctness for every field; "Edit Expense
      (N/2)" title; "Save Changes" CTA disabled-by-default
      until a field modifies; changed-field indicator on Step
      2). Expense Detail screen widget test at
      `test/features/expenses/expense_detail_screen_test.dart`
      (if §2.1 choice (a) is elected).
- [ ] **Controller tests.** Edit-mode `AddExpenseController`
      tests extending
      `test/features/expenses/add_expense_controller_test.dart`
      (constructor with `initialExpense: ExpenseDoc`;
      `originalSnapshot` capture; `changedFields` set updates
      on each field mutation; no-op guard prevents
      `updateExpense` call when set is empty; successful save
      transitions; failure transitions). Delete-mode tests in
      `test/features/expenses/delete_expense_flow_test.dart`
      (dialog open transition; cancel transition;
      confirm-success transition; confirm-failure transition).
- [ ] **Boundary-contract grep extended.** The existing
      `formatInrFromPaise` boundary-contract grep at
      `test/features/expenses/expense_creation_boundary_contract_test.dart`
      extends (or a sibling
      `test/features/expenses/expense_edit_delete_boundary_contract_test.dart`
      adds) coverage for any new files under
      `lib/features/expenses/presentation/**` AND
      `lib/features/expenses/application/**`. Greps for
      `.toDouble()`, `/100`, `simplifiedBalances` all return 0
      matches against `.dart` non-comment lines.
- [ ] **PII-leak test.** Edit + delete telemetry PII-leak
      coverage extending
      `test/features/expenses/expense_telemetry_pii_leak_test.dart`
      (or a sibling file per the architect's call). Drives the
      controller through every edit + delete state with
      PII-flavoured `expenseId == 'realExpenseId123'` and
      asserts no raw value appears in any emitted parameter
      payload across all nine events.
- [ ] **Integration-test stub.** New (skipped) integration
      test at
      `test/integration/expenses/edit_delete_expense_flow_test.dart`
      with `skip: 'Requires emulator suite'`. Documents the
      canonical round-trip steps. Partial PY3 credit; the CI
      `Integration Tests (Emulator Suite)` job is the eventual
      gate (PY3 remains open pending the Flutter emulator
      harness).
- [ ] **Manual smoke matrix from Phase 5 step 9** of
      `docs/copilot_prompts/sprint_2/12.md`:
      (i) start emulators (`scripts/dev/start-emulators.sh`);
      (ii) sign in as User A; create an expense; tap the row on
      Friend Detail; confirm the Expense Detail screen / edit
      sheet opens with pre-filled values;
      (iii) tap Edit; modify the amount; tap "Save Changes";
      confirm the snackbar + the row re-renders within ~2.5 s;
      (iv) tap Delete; tap Cancel in the dialog; confirm no
      write; tap Delete again; tap Confirm; confirm the row
      disappears and the snackbar appears;
      (v) sign out; sign in as User B; confirm User B sees the
      edited / deleted expense state in real time on their own
      Friend Detail screen;
      (vi) try to tap a User-A-created expense as User B;
      confirm no Edit / Delete affordance appears (UI gates;
      rules enforce server-side).
- [ ] **CI all green.** PR Title Lint (single-token scope, e.g.
      `feat(expenses)` — NOT `feat(expenses,friends)` per the
      PR #45 title-lint gotcha); Flutter Lint & Test; Cloud
      Functions Lint & Test (9 suites / 100 tests unchanged
      — no `functions/src/**` changes); Integration Tests
      (Emulator Suite); Coverage Gate (SRS 5.7); Build Android
      (debug); Build iOS (no signing).
      `dart format --set-exit-if-changed .` returns 0;
      `flutter analyze --fatal-infos` returns "No issues
      found".
- [ ] **Docs roll-up.**
      `docs/sprint-zero/sprint-2-plan.md` — PR #46 row added to
      the PR Tracking + Velocity table (5 SP; cumulative 45 SP
      across 13 PRs);
      `docs/sprint-zero/next-three-prs.md` — PR #46 marked
      merged and rolled to PR #47 / PR #48 / PR #49 candidates
      (top: FR-EX-05 receipt attachment; FR-EX-07 activity
      feed; FR-SE-09 send reminder; FR-SE-08 dedicated
      settlements history; the rate-limit transaction race
      refactor; concurrent-edit detection for FR-EX-06);
      `docs/audits/sprint-1/07-bucket-b-burndown.md` — header
      timestamp updated to PR #46; appended PR #46 section
      noting PY3 partial credit for the integration-test stub;
      otherwise zero Bucket-B item movement.
- [ ] **Coverage gate per SRS section 5.7.**
      `lib/features/expenses/**` per-module ≥ 70 % (target
      ≥ 80 % on the controller and the repository); coverage
      measurably INCREASES from PR #45 baseline due to the new
      edit + delete code paths and their tests;
      `lib/core/widgets/dialogs/` covered by the leaf widget
      test at ≥ 80 % line; `lib/features/friends/**` unchanged
      (only the on-tap callback wires up); overall Flutter
      ≥ 50 %.
- [ ] **Invariant compliance (DoD §7).** Inv-1 (paise integers
      — write-side return; boundary-contract grep extends to
      new files; no `double` arithmetic on the monetary path);
      Inv-2 (`simplifiedBalances` server-only — zero client
      writes; rules test continues to enforce); Inv-3 (N/A);
      Inv-4 (single Firebase project — `.firebaserc` CI gate
      green).
- [ ] **AC walk-through.** QA sign-off referencing all 18
      acceptance criteria (including AC-11 / AC-12 documented
      as DEFERRED per Out of Scope item (f)), the negative
      cases AC-13 / AC-14 / AC-15 / AC-16 / AC-17, and the
      integration-test stub AC-18.
- [ ] **Telemetry events firing.** Verified by the PII-leak
      test (AC-17) and by manual emulator-suite inspection of
      Firebase Analytics DebugView. All nine event names match
      the table in "Telemetry Events Introduced" above and the
      constants in
      `lib/features/expenses/application/expense_telemetry.dart`.
- [ ] **Accessibility verified.** Semantic labels on the edit
      sheet ("Edit expense, step [N] of 2."), the
      changed-field indicator (", changed." suffix), the
      disabled "Save Changes" CTA ("Save changes, no
      modifications made."), the delete dialog ("Alert: Delete
      this expense?", focus trap, ESC dismiss). VoiceOver
      (iOS) + TalkBack (Android) walk-through deferred to PR
      review (requires device).
- [ ] **Dark mode checked.** WCAG AA contrast on the edit
      sheet's pre-filled fields, the `secondary` changed-field
      left border, the `danger`-coloured Delete confirmation
      button. Deferred to PR review (requires device).
- [ ] **No open S1 or S2 bugs.**

---

## Design Artefact References

| Artefact | Path |
|---|---|
| Screen spec (Edit / Delete) | `docs/design/06-screen-specs/19-22-expenses.md` (SCR-22 lines 398-530) |
| Screen specs (Add — for pre-fill reference) | `docs/design/06-screen-specs/19-22-expenses.md` (SCR-19 + SCR-20) |
| Wireframe baseline | `docs/design/04-wireframes/expense-flow.md` |
| Design-system components | `docs/design/02-design-system/components.md` — item 6 `OBTAmountInput` (reused from PR #38); item 24 `OBTConfirmationDialog` (to be extracted) |
| Firestore schema (expense subcollection) | `docs/design/07-technical/firestore-schema.md` |
| Firestore security rules (expense subcollection — shipped in PR #36) | `docs/design/07-technical/firestore-security-rules.md` and `firestore.rules` lines 275-301 |
| Telemetry plan | `docs/design/07-technical/telemetry-plan.md` (section 1.6 edit / delete cluster) |
| Cloud Functions catalogue (consumer side — `onExpenseWriteFriendship`) | `docs/design/07-technical/cloud-functions-catalogue.md` |
| Extension-points register | `docs/design/03-architecture/extension-points-register.md` — ARCH-EXT-02, ARCH-EXT-03, ARCH-EXT-07 |
| PR #38 story (FR-EX-01 — the architectural blueprint) | `docs/sprint-zero/stories/FR-EX-01-expense-creation.md` |
| PR #36 story (the trigger that consumes this PR's writes) | `docs/sprint-zero/stories/FR-SE-03-04-expense-trigger-friendship.md` |
| PR #42 story (the read surface that re-emits this PR's writes) | `docs/sprint-zero/stories/FR-FR-04-friend-detail.md` |
| PR #43 story (settle-up — typed-error repository precedent) | `docs/sprint-zero/stories/FR-SE-05-settle-up.md` |
| Feature-PR conventions | `docs/patterns/feature-pr-conventions.md` |
| Sprint 2 kickoff prompt (this PR) | `docs/copilot_prompts/sprint_2/12.md` |

---

## Responsible Agents

| Agent | Responsibility |
|---|---|
| PM | Story authorship, AC clarity, scope discipline (no widening into FR-EX-05 receipt; no widening into FR-EX-07 activity feed; no widening into FR-SE-09 reminders; no group-context edit / delete; no transactional concurrent-edit detection unless escalated to 8 SP at user request). Phase 7 docs roll-up (sprint-2-plan, next-three-prs, burndown). |
| Architect | §2.1 entry-point choice (Expense Detail screen vs direct edit sheet); §2.2 edit-mode controller architecture (in-place extension of `AddExpenseController` recommended); §2.3 repository API surface (`updateExpense` + `softDeleteExpense` + typed-error mapping); §2.4 concurrent-edit deferral confirmation; §2.5 `OBTConfirmationDialog` extraction; §2.6 telemetry event-name final ratification (`saved` vs `succeeded`); §2.7 exhaustive file-touch list; §2.8 negative scope guardrails; §2.9 anticipated reconciliations. |
| Flutter Dev | Extract `OBTConfirmationDialog`; extend `ExpenseRepository` with `updateExpense` + `softDeleteExpense` and the typed-error mappings; extend `AddExpenseController` with edit-mode path + no-op guard + nine new telemetry constants; add new `expense_detail_screen.dart` (if §2.1 choice (a) is elected); wire the on-tap at `friend_detail_timeline.dart:92-95`; add the skipped integration-test stub. |
| QA | Write the four new rules tests (failing first per Phase 4 step 2); extend the boundary-contract grep test; extend the PII-leak test; verify all 18 ACs at sign-off (including the DEFERRED notes on AC-11 / AC-12); run the manual smoke matrix from Phase 5 step 9 on a physical device or simulator at PR review. |
| Designer | Sign-off on the changed-field indicator (`secondary` left border) fidelity; dark-mode contrast on the `danger`-coloured Delete button; accessibility — focus trap + ESC dismiss + back-gesture-as-Cancel on `OBTConfirmationDialog`. |
| DevOps | None required — no CI workflow change, no rules deploy (the rules-test extension validates against the existing deployed rules), no functions deploy (no `functions/src/**` change). |

---

## Technical Notes

- **`OBTConfirmationDialog` does not yet exist.** The component
  is listed at `docs/design/02-design-system/components.md`
  item 24 (props: `title`, `body`, `cancelLabel`,
  `confirmLabel`, `isDestructive`, `onCancel`, `onConfirm`)
  but has never been built. PR #46 is the first use site; PM
  recommends extraction to
  `lib/core/widgets/dialogs/obt_confirmation_dialog.dart` per
  the `OBTAmountInput` precedent from PR #38 (extract on first
  use to lock in the contract for the future SCR-13 "Leave
  group" use site). The component must be widget-testable in
  isolation; see the Widget tests bullet under DoD.
- **The edit sheet ships as a two-step flow, NOT a three-step
  flow.** SCR-22 §Components Used lines 427-429 describe a
  three-step flow ("Sheet title: 'Edit Expense (N/3)'")
  because SCR-21 (receipt summary) was part of the original
  FR-EX-01 plan. PR #38 shipped FR-EX-01 with SCR-21 DEFERRED
  to FR-EX-05 (re-affirmed in Phase 3 guardrails of
  `docs/copilot_prompts/sprint_2/12.md`). PR #46 mirrors
  PR #38's two-step shape; the third receipt-summary step
  remains deferred with FR-EX-05. The architect ratifies this
  position in §2.1 of Architect Notes.
- **The immutable historical fields per `isValidExpenseUpdate()`
  are `createdBy` + `createdAt` ONLY.** Read `firestore.rules`
  lines 281-282 verbatim:

  ```
  // Immutable fields preserved.
  && data.createdBy == prev.createdBy
  && data.createdAt == prev.createdAt
  ```

  The other fields validated by `isValidExpenseShared()` at
  lines 254-263 (`payerId`, `splits`, `splitMethod`,
  `category`, `currency`, `amountPaise`, `description`,
  `date`, `receiptUrl`) are shape-validated on every update
  but are NOT immutability-locked. Earlier framings in the
  kickoff prompt that listed `payerId`, `splits`,
  `splitMethod`, `category`, `currency` as immutable were
  incorrect; SCR-22's edit-flow assumption that any of those
  is editable is correct.
- **The `updatedAt` field must equal `request.time` on every
  update** per `firestore.rules` line 283
  (`data.updatedAt == request.time`). The client MUST emit
  `updatedAt: FieldValue.serverTimestamp()` on every update +
  every soft-delete; this is the existing pattern from
  `lib/features/expenses/domain/expense_doc.dart` line 84
  (the same field, set the same way, on create).
- **Hard delete is denied at the rules layer** per
  `firestore.rules` line 301: `allow delete: if false`. The
  only "delete" path the rules permit for clients is the
  soft-delete-via-update: a partial-update write of
  `{ deleted: true, updatedAt: FieldValue.serverTimestamp() }`
  that passes `isValidExpenseUpdate()`.
- **The trigger consumes both edit and soft-delete writes
  unchanged.** `functions/src/triggers/on-expense-write/function.ts`
  line 79 declares `type ChangeType = "create" | "update" |
  "delete"`; the `deriveChangeType` helper at lines 87-100
  derives the discriminator from snapshot existence on each
  side of the `Change<DocumentSnapshot>`. A soft-delete (which
  is an update from Firestore's point of view — the document
  still exists, only `deleted` flips) is therefore handled by
  the `update` branch. `recomputeSimplifiedBalances` reads
  non-deleted expenses, so the soft-deleted expense
  automatically drops out of the projection on the next
  trigger fire.
- **The merged-document rules posture.** Firestore evaluates
  security rules against the **post-write merged document**
  (`request.resource.data`), not against the partial-update
  payload. A partial update of the form
  `.update({ amountPaise: 2500, updatedAt: serverTimestamp() })`
  is merged onto the existing document, and
  `isValidExpenseShared` (lines 254-263) and
  `isValidExpenseUpdate` (lines 275-284) are evaluated on the
  merged result. This is why the partial-update map need not
  carry every required key — Firestore fills the rest from
  the existing document — but the merged result must still
  satisfy `hasAllRequiredKeys`, `hasOnlyKnownKeys`,
  `sumOfSharesEquals`, etc. The architect should ratify the
  typed-mapping helper that produces the partial-update map by
  diffing `(edited, original)` in §2.3.
- **`recurringRule` stays omitted on every update map** per
  ARCH-EXT-03; the rules accept absent OR `null` (the existing
  predicate at `firestore.rules` is unchanged from PR #36).
- **`source: 'manual'` and `currency: 'INR'` stay** per
  ARCH-EXT-07 and ARCH-EXT-02. The edit flow MUST NOT change
  either; if a `splits` or `amountPaise` edit somehow tried to
  flip them, the `isValidExtensionPointLocks` predicate would
  reject the write. The architect's typed-mapping helper
  (§2.3) excludes them from the diff by construction.
- **Camp B telemetry naming holds.** The existing constants
  module
  `lib/features/expenses/application/expense_telemetry.dart`
  already uses Camp B for the create flow
  (`expense_save_succeeded` / `expense_save_failed`); the
  nine new edit / delete constants follow the same
  verb-past + state pattern. The constant identifiers are
  listed in the Telemetry Events Introduced table.
- **Boundary-contract grep extension.** The existing
  expense-feature boundary-contract grep at
  `test/features/expenses/expense_creation_boundary_contract_test.dart`
  enforces no `.toDouble()`, no `/100`, no `simplifiedBalances`
  in `lib/features/expenses/**/*.dart` non-comment lines. The
  architect's call at §2.7 is whether to extend the existing
  grep test or add a sibling
  `expense_edit_delete_boundary_contract_test.dart`. Either
  way, the contract MUST extend to any new files under
  `lib/features/expenses/presentation/**` AND
  `lib/features/expenses/application/**`.
- **PR Title Lint gotcha.** The CI title-lint regex
  `[a-z0-9_-]+` rejects comma-separated scopes (verified by
  PR #45). Use `feat(expenses)`, NOT
  `feat(expenses,friends)`. The single-token scope rule is
  load-bearing.
- **Tooling baseline.** Pre-push: `dart format .` AND
  `flutter analyze --fatal-infos` AND `flutter test` AND
  `cd functions && npm run lint && npm run build && npm test`
  AND `cd functions && npm run test:rules`. The Flutter
  formatter check and the rules-test layer are the most
  common failure modes for a missed local step.

---

## Open Questions for the Architect

These items are surfaced for the architect to ratify in
`## Architect Notes`. The defaults noted below are the PM's
working assumption; the architect may override with rationale.

1. **Entry-point choice — Expense Detail screen vs direct
   edit sheet (§2.1).** Option (a): dedicated full-page
   Expense Detail screen at
   `lib/features/expenses/presentation/expense_detail_screen.dart`
   with Edit + Delete actions in `OBTAppBar`. Matches SCR-22's
   "Reachable from Expense Detail screen" wording verbatim;
   future FR-EX-05 receipt-attachment viewing surface naturally
   lives here; future FR-EX-07 activity-feed deep-link target.
   Option (b): row-tap opens the edit sheet directly with the
   delete action surfaced via an in-sheet overflow menu. Ships
   faster; consistent with the chore-#25 / Camp B
   minimal-surface ethos. **PM working assumption: Option (a)**
   per the SCR text and future-proofing.
2. **Edit-mode controller architecture (§2.2).** Option (a):
   extend `AddExpenseController` in-place with an
   `initialExpense: ExpenseDoc?` constructor parameter and an
   `originalSnapshot` field for the no-op guard + the
   changed-field set. Option (b): separate
   `EditExpenseController` extending a shared
   `ExpenseSheetController` base. **PM working assumption:
   Option (a) in-place extension** — minimises diff; the state
   machine, validators, and step navigation are identical.
3. **Repository error-type hierarchy (§2.3).** Option (a):
   three sibling discriminated unions (`ExpenseCreateError`,
   `ExpenseUpdateError`, `ExpenseDeleteError`). Option (b):
   shared parent with common error codes plus per-method
   discriminators. **PM working assumption: Option (a)
   siblings** — three small enums + a shared mapping helper
   keep the surface narrow; mirrors PR #38's
   `ExpenseCreateError` precedent.
4. **`OBTConfirmationDialog` extraction path (§2.5).** Option
   (a): extract to
   `lib/core/widgets/dialogs/obt_confirmation_dialog.dart` on
   first use. Option (b): inline in
   `lib/features/expenses/presentation/` and extract later when
   the SCR-13 "Leave group" CTA arrives. **PM working
   assumption: Option (a) extract** — matches the
   `OBTAmountInput` precedent from PR #38 (extract on first
   use to lock in the contract).
5. **Telemetry event name — `saved` vs `succeeded` (§2.6).**
   Option (a): keep `expense_edit_saved` per SCR-22 spec lines
   494-502 (the spec is the source of truth for screen-level
   events). Option (b): rename to `expense_edit_succeeded` for
   verb-symmetry with the create flow's
   `expense_save_succeeded`. **PM working assumption: Option
   (a) keep** — the SCR is the screen-level authority; the
   verb-symmetry rename should re-touch the SCR spec in a
   follow-up if pursued.
6. **Boundary-contract grep extension — extend vs sibling
   (§2.7).** Option (a): extend
   `test/features/expenses/expense_creation_boundary_contract_test.dart`
   to cover the new edit + delete files. Option (b): add a
   sibling
   `test/features/expenses/expense_edit_delete_boundary_contract_test.dart`.
   **PM working assumption: architect's call** — both
   patterns are equally enforceable; (a) keeps the test
   surface unified; (b) keeps PR diffs cleaner per feature
   slice.
7. **PII-leak test extension — extend vs sibling (§2.7).**
   Same shape as Q6. **PM working assumption: architect's
   call.**
8. **Non-creator UI gate behaviour (AC-13).** Option (a):
   tap is a no-op for non-creators. Option (b): tap opens a
   read-only Expense Detail screen with NO Edit / NO Delete
   affordances. The choice is downstream of Q1 — Option (b)
   here pairs with Option (a) of Q1; Option (a) here pairs
   with Option (b) of Q1. **PM working assumption: follows
   from Q1 choice.**
