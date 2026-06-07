# FR-EX-05: Receipt Attachment for Friendship Expenses

> Implementation-ready user story for the **first client uploader to
> Firebase Storage from the expense feature**. Ships a third Step 3 in
> the existing `AddExpenseBottomSheet` — the SCR-21 surface — that
> allows an optional receipt image (camera or gallery) to be attached
> to a friendship expense at create or edit time. The image is uploaded
> to `gs://onebytwo-avtanshgupta.appspot.com/receipts/friendships/{friendshipId}/{expenseId}`
> with the corresponding `receiptUrl` written into the expense
> document. The existing `onExpenseWriteFriendship` trigger (PR #36)
> re-fires on the underlying `update` and re-runs
> `recomputeSimplifiedBalances` (a no-op recompute, but no-op for
> correctness — balances are unaffected by a receipt). The PR #46
> Expense Detail screen renders the thumbnail on read. The Storage
> rules added in this PR (R7 + R8) enforce per-friendship membership
> validation, a 10 MB file-size cap, and a JPEG/PNG MIME-type
> restriction. The defensive group-context Storage predicate ships in
> the same PR (rules surface only — no UI). Group-context UI is the
> Sprint 3 groups epic and is explicitly out of scope.

---

## SRS Requirement ID(s)

FR-EX-05 (SRS section 4.5 — attach a receipt image to an expense
(camera or gallery), stored in Firebase Storage; P1 priority at line
210; this story covers the friendship half only),
FR-EX-04 (SRS section 4.5 — paise integer arithmetic; the receipt
path is non-monetary but the surrounding save chain still satisfies
the integer invariant by construction),
FR-SE-04 (SRS section 4.6 — `simplifiedBalances` recomputed
atomically on every expense write; consumed unchanged from PR #36
and unchanged by a receipt attach because balances do not depend on
`receiptUrl`).

## Relevant SRS Sections

- Section 4.5 — Expenses (FR-EX-05 P1 at line 210; the receipt path
  is the optional attach surface defined by SCR-21; the FR-EX-06
  edit flow extends to support replace + remove on existing
  receipts, picking up where PR #46 deferred SCR-21 integration).
- Section 4.6 — Atomic recompute of simplified balances on every
  expense write (consumed unchanged from PR #36; receipt-only
  updates produce a no-op recompute that is harmless but adds log
  noise — filed as a FUTURE optimisation, NOT fixed in this PR).
- Section 4.8 — Firebase Storage usage and lifecycle (Bucket-A
  avatars are already in play; this PR is the first Bucket-B writer
  — long-open expense receipts — closing the long-standing R7 + R8
  gaps in the Sprint-1 burndown).
- Section 5.6 — Add Expense flow (Step 3 was previously labelled
  "(deferred)" in the FR-EX-01 architect notes and is now
  reactivated by this PR; the funnel sequence is
  Step 1 → Step 2 → Step 3 → Success).
- Section 5.7 — NFR-PE-04 (P95 2.5 s budget on the save chain; the
  receipt upload counts toward the budget — the architect at §2.5
  of Architect Notes ratifies `image_picker`'s `maxWidth: 1920,
  maxHeight: 1920` as the v1.0 compression strategy and the upload
  proceeds without server-side OCR / WebP conversion).
- Section 5.10 — Observability (telemetry funnel — extends with
  four new events; `expense_save_succeeded` payload widens to carry
  `has_receipt: true` and `receipt_size_bytes` when a receipt is
  attached; every `expense_id` parameter SHA-256 truncated per
  ADR-0013).
- Section 7.3 — Invariants (Invariant 1 — paise integers, N/A on
  the receipt path itself but the surrounding save chain is the
  third Sprint-2 write-side return; Invariant 2 — `simplifiedBalances`
  server-maintained, client-read-only, negative-guard load-bearing;
  Invariant 3 — N/A; Invariant 4 — single Firebase project +
  single Storage bucket; defence-in-depth re-check).
- Section 7.5 — Data model and security rules (`receiptUrl: string
  | null` already accepted by `firestore.rules` at line 205;
  `storage.rules` gains the friendship-receipts predicate AND the
  defensive group-receipts predicate in this PR).

## Priority

**P1 — Should have.** SRS section 4.5 line 210 categorises FR-EX-05
as P1. Without it, users cannot attach a photo of the bill to an
expense — a high-frequency Indian use case (paper receipts at
restaurants, autorickshaw QR-payment confirmations, kirana store
slips). The friendship expense lifecycle is otherwise complete
through PR #46 (create / edit / soft-delete); this PR ships the
optional attachment surface and the Expense Detail thumbnail viewer
that PR #46 deferred because SCR-21 was unbuilt.

## Story Points

**5.** Scope: new Step 3 widget + receipt picker (Take Photo / From
Gallery / Replace / Remove) + new `ReceiptStorageService`
abstraction with typed errors + new `storage.rules` predicates
(friendship-receipts + group-receipts) + 8+ new storage-rules tests
+ new Expense Detail thumbnail + fullscreen viewer + 4 new
telemetry events + extended `saveSucceeded` payload + edit-flow
integration (pre-fill / replace / remove) + extracted
`ImagePickerService` to `lib/core/services/`. Reuses ~70 % of
PR #46's edit-mode controller, sheet, and Expense Detail surface;
only the new code paths (receipt picker, upload chain, thumbnail
viewer, storage rules) carry net-new implementation cost. Escalate
to **8 SP** only if the architect calls for an aggressive
image-compression pipeline (out of scope — `image_picker`'s
`maxWidth/maxHeight` is the v1.0 strategy).

## Status

**Architect Notes ratified — Ready for Implementation.** PM and
Architect authorship complete. Implementation begins at Phase 3 of
the source prompt `docs/copilot_prompts/sprint_2/13.md`
(test-first: write failing storage-rules tests; add the
predicates; extract `ImagePickerService` to core; add
`ReceiptStorageService`; extend the controller; add Step 3 widget;
extend Expense Detail thumbnail; ship integration stub; roll docs).

## PR Target

**PR #48** on branch `feat/fr-ex-05-receipt-attachment`.

## GitHub Issue Closed

**None.** FR-EX-05 is tracked as a P1 SRS row (section 4.5 line
210); no separate GitHub issue exists. The PR body references the
SRS row directly and notes that R7 + R8 from the Sprint-1
Bucket-B burndown are CLOSED. Any post-v1.0 follow-ups
(orphan-cleanup Cloud Function, trigger no-op-recompute
optimisation, group-context UI, OCR / AI on receipts) may file
dedicated issues at that point — the PM filing protocol for the
former two is at Phase 5 step 12 of the source prompt.

## User Story

As **an authenticated friendship member creating or editing an
expense via the `AddExpenseBottomSheet`**,
I want **to optionally attach a single receipt image (JPEG or PNG,
≤ 10 MB) from my camera or photo library at Step 3, see a thumbnail
of the attached receipt before saving, and view the same thumbnail
in the Expense Detail screen after the save lands**,
so that **I have a visual record of the bill associated with the
expense, the other friendship member can see the same receipt
post-sync, and I can replace or remove the receipt later via the
edit flow without losing the expense itself**.

---

## Preconditions

1. The user is authenticated (Phone Auth completed per FR-AU-03 /
   FR-AU-04 / FR-AU-05) and the auth session is restored
   (FR-AU-07).
2. A friendship document exists at `friendships/{fid}` with
   `memberIds == [self, friend]` (deterministic composite ID per
   PR #32) and `simplifiedBalances` populated by the existing
   trigger.
3. The user has reached Step 2 of the `AddExpenseBottomSheet` and
   the Step 1 + Step 2 validators (amount, description, category,
   date, splits, payer) are green. The Step 2 CTA flips from "Save"
   / "Save Changes" to "Next" in this PR; the final save fires from
   Step 3.
4. The `onExpenseWriteFriendship` trigger (PR #36) is live in
   `asia-south1`. The `ChangeType = 'update'` branch re-fires on
   the receipt-attach update; `recomputeSimplifiedBalances` runs
   even though balances do not change (no-op recompute; harmless;
   log noise filed as FUTURE optimisation).
5. The Expense Detail screen from PR #46 renders the AppBar Edit
   + Delete actions and the read-side body. This PR extends the
   body to render the receipt thumbnail when `doc.receiptUrl !=
   null`.
6. `lib/features/auth/data/image_picker_service.dart` exists as
   the avatar picker abstraction. This PR extracts it to
   `lib/core/services/image_picker_service.dart` and updates the
   auth feature to import from the new path. Both auth and
   expenses depend on the same abstraction.
7. `pubspec.yaml` already pins `firebase_storage: ^13.3.0`
   ("Receipt and avatar uploads" — the dependency was added in
   anticipation of FR-EX-05) and `image_picker: ^1.1.2`. No new
   dependencies required.
8. The Firebase Emulator Suite is available for pre-merge
   integration testing. The new integration-test stub at
   `test/integration/expenses/receipt_upload_flow_test.dart`
   ships skipped (PY3 partial credit — running is gated on the
   Flutter emulator harness).
9. The Storage emulator on port 9199 (per `firebase.json`) is
   started by `scripts/dev/start-emulators.sh`. The new
   `functions/test/storage-rules/receipts.test.ts` runs in the
   dedicated `firebase emulators:exec --only firestore,storage`
   session per `.github/workflows/pr.yml` lines 172-194 — the
   same session that PR #46 split out to fix the trigger /
   transaction-lock interference.

---

## Background / Context

- **PR #36** shipped `onExpenseWriteFriendship` — the trigger on
  `friendships/{fid}/expenses/{eid}` that re-fires on every
  `create`, `update`, and `delete` and recomputes
  `simplifiedBalances` plus a `lastActivityAt` monotonicity guard.
  A receipt-attach update fires the trigger and produces a no-op
  recompute (balances do not depend on `receiptUrl`). Log noise
  filed as FUTURE optimisation issue per Phase 5 step 12.
- **PR #38** shipped FR-EX-01 — the first client producer of
  expense `create` writes via the two-step `AddExpenseBottomSheet`.
  `ExpenseDoc.toCreateMap()` writes `receiptUrl: null` on every
  create (see `lib/features/expenses/domain/expense_doc.dart`
  line 119). PR #48 populates that field when the user attaches a
  receipt.
- **PR #46** completed the friendship expense-mutation loop —
  create / view / edit / soft-delete. The Expense Detail screen
  (`lib/features/expenses/presentation/expense_detail_screen.dart`)
  is the canonical read-side surface; the bottom-sheet edit mode
  pre-fills every field from the original document and computes a
  `changedFields` diff for partial updates. PR #46 explicitly
  DEFERRED SCR-21 (receipt summary) — Architect Notes §2.1 cited
  FR-EX-05 as the natural follow-on. PR #48 is that follow-on.
- **PR #46 also extracted `OBTConfirmationDialog`** to
  `lib/core/widgets/dialogs/obt_confirmation_dialog.dart` on first
  use (the soft-delete confirmation). PR #48 reuses the same
  precedent for the new `Step3ReceiptAndConfirm` widget and the
  fullscreen viewer — extract on the SECOND use site (PR #49+),
  inline on first use to avoid premature coupling.
- **Storage rules currently allow only avatars.** `storage.rules`
  has a single non-default rule for `avatars/{userId}` with a 5 MB
  cap and a JPEG/PNG MIME guard. PR #48 adds the
  friendship-receipts predicate AND the defensive group-receipts
  predicate (group-context UI is out of scope; the rule is
  defensive so that R7 + R8 close in a single PR).
- **Firestore rules already accept `receiptUrl`.** The expense
  shape predicate at `firestore.rules` line 205 has
  `(!('receiptUrl' in data) || data.receiptUrl == null ||
  data.receiptUrl is string)`. No `firestore.rules` change is
  required.
- **Bucket-B burndown: R7 + R8.** The Sprint-1 audit at
  `docs/audits/sprint-1/07-bucket-b-burndown.md` lines 136 + 187
  + 232 calls out the Storage rules test gaps for file size + MIME
  type as Sprint 2 chores. PR #48 closes BOTH; the Bucket-B
  remaining count drops from 30 / 37 to 28 / 37.
- **Invariant 1 (paise integers) is N/A on the receipt path
  itself.** The upload pipeline carries an `XFile` and emits a
  `String` URL; no monetary surface. The boundary-contract grep
  at
  `test/features/expenses/expense_creation_boundary_contract_test.dart`
  walks `lib/features/expenses/**` and continues to enforce on
  every new file PR #48 introduces (`receipt_storage_service.dart`,
  `step_3_receipt_and_confirm.dart`,
  `receipt_fullscreen_viewer.dart`).
- **Invariant 2 (`simplifiedBalances` server-only) is the
  load-bearing NEGATIVE invariant** for PR #48 as for every
  client-write PR before it. The new receipt-attach update path
  writes ONLY `{ receiptUrl, updatedAt }` to the expense
  document; never to `friendships/{fid}.simplifiedBalances`. The
  existing PR #36 rules test continues to enforce defence-in-depth
  server-side.
- **Invariant 4 (single Firebase project / single Storage bucket)
  defence-in-depth re-check.** `.firebaserc` continues to declare
  exactly one project; the production bucket is
  `gs://onebytwo-avtanshgupta.appspot.com`; the emulator targets
  the single bucket on `127.0.0.1:9199`. No new project IDs and
  no new buckets.
- **Storage rule cross-collection read.** The friendship-receipts
  predicate at `storage.rules` performs a `firestore.get()` on the
  parent `friendships/{friendshipId}` doc to validate
  `memberIds`. This is a non-trivial first for this codebase
  (avatars don't cross-reference Firestore). The rules-tests
  verify the predicate works end-to-end against the emulator;
  the architect's anticipated reconciliation list at §2.9 of
  Architect Notes flags it as a primary verification item.

---

## Scope (in PR #48)

- **Step 3 as a new dedicated widget — `Step3ReceiptAndConfirm`.**
  Lives at
  `lib/features/expenses/presentation/steps/step_3_receipt_and_confirm.dart`.
  Renders (top-to-bottom) the receipt picker section (empty-state
  placeholder with "Take Photo" + "From Gallery" buttons; attached
  state with thumbnail + "Replace" + "Remove" buttons), the
  summary card (read-only projection of every Step 1 + Step 2
  field per SCR-21 §Components Used), and the "Save Expense" /
  "Save Changes" CTA at the bottom. Per SCR-21 §State 3, the
  uploading state overlays a `CircularProgressIndicator` at 0.5
  opacity on the thumbnail and disables the CTA.
- **Bottom-sheet integration.** The header label flips from `'Add
  Expense (N/2)'` / `'Edit Expense (N/2)'` to `'Add Expense
  (N/3)'` / `'Edit Expense (N/3)'`. Step 2's primary CTA flips
  from "Save" / "Save Changes" to "Next" — Step 3 owns the final
  save CTA. The bottom-sheet's switch statement extends from
  `step == 1 → Step1AmountDetails` / `step == 2 →
  Step2SplitAndPayer` to add `step == 3 →
  Step3ReceiptAndConfirm`. The Success snackbar messages stay
  unchanged ("Expense added." / "Changes saved.") — the receipt
  is part of the same atomic save.
- **`ReceiptStorageService` abstraction.** New file at
  `lib/features/expenses/data/receipt_storage_service.dart` mirrors
  the `ExpenseStore` abstract / `FirestoreExpenseStore` concrete
  pattern. Two methods:
  `uploadFriendshipReceipt({required String friendshipId, required
  String expenseId, required XFile file})` returns the download
  URL; `deleteFriendshipReceipt({required String friendshipId,
  required String expenseId})` removes the file. Maps
  `FirebaseException` to a typed `ReceiptUploadError` enum
  (`permissionDenied`, `oversize`, `unsupportedType`, `network`,
  `unknown`). The Riverpod provider is
  `receiptStorageServiceProvider`.
- **`ImagePickerService` extraction to `lib/core/services/`.**
  The existing `lib/features/auth/data/image_picker_service.dart`
  (a `Provider<ImagePickerService>` with `pickFromGallery` +
  `pickFromCamera`) moves to
  `lib/core/services/image_picker_service.dart`. Both the auth
  feature's `user_repository.dart` / avatar flow AND the new
  expenses controller import from the core path. Tests for both
  features inject the same `FakeImagePickerService`. Architect
  ratifies in §2.4 of Architect Notes.
- **Controller extension — `AddExpenseController` gains receipt
  setters + an upload-then-save chain.** New methods:
  `setReceipt(XFile?)`, `removeReceipt()`,
  `pickReceiptFromCamera()`, `pickReceiptFromGallery()`. The
  internal `save()` chain becomes two-phase: (1) if
  `draft.receiptFile != null && (isCreateMode ||
  receiptChanged)`, transition to `Uploading`, upload to
  `receipts/friendships/{fid}/{eid}`, obtain the download URL;
  (2) transition to `Saving`, write the Firestore document
  (create or update) with the URL populated. The `Uploading`
  state is a new sealed variant on `AddExpenseState` (does NOT
  replace `Saving`).
- **Domain extensions.** `ExpenseDoc` adds `fieldReceiptUrl =
  'receiptUrl'` constant; `toUpdateMap` writes the URL when
  `_changedFields.contains(fieldReceiptUrl)`; `fromMap` parses
  the URL (read-side). `ExpenseDraft` adds `final XFile?
  receiptFile;` and `final String? existingReceiptUrl;` for the
  edit-flow pre-fill.
- **Expense Detail thumbnail.** The body of
  `expense_detail_screen.dart` extends to render the receipt
  thumbnail (240 × 320 dp per SCR-21 line 325) below the splits
  list when `doc.receiptUrl != null`. Tapping the thumbnail
  opens `receipt_fullscreen_viewer.dart` (new file —
  simple `Dialog` + `InteractiveViewer` + `Image.network` per
  architect §2.x; no zoom-gesture polish for v1.0). When
  `doc.receiptUrl == null`, NO placeholder appears (the receipt
  section is omitted entirely; receipts are optional).
- **Edit-flow integration.** Pre-fill: when the bottom sheet
  opens in edit mode and the original expense has a
  `receiptUrl`, Step 3 renders the existing thumbnail in the
  picker area (NOT re-uploaded — `existingReceiptUrl` carries
  the URL; the change-tracking compares against it). Replace:
  the user picks a new file → upload to the SAME canonical path
  (Firebase Storage overwrites) → `changedFields.add('receiptUrl')`
  → save writes the new URL. Remove: the user clears the
  receipt → `changedFields.add('receiptUrl')` → save writes
  `receiptUrl: null` AND `deleteFriendshipReceipt(...)` removes
  the Storage object. The "changed-field indicator" from PR #46
  marks the receipt row when `changedFields.contains('receiptUrl')`.
- **Storage rules — friendship-receipts predicate.** Adds to
  `storage.rules`:
  ```
  match /receipts/friendships/{friendshipId}/{expenseId} {
    allow read, write: if request.auth != null
      && request.auth.uid in
         firestore.get(/databases/(default)/documents/friendships/$(friendshipId)).data.memberIds
      && request.resource.size < 10 * 1024 * 1024
      && request.resource.contentType.matches('image/(jpeg|png)');
  }
  ```
- **Storage rules — group-receipts predicate (defensive).** Adds
  the analogous rule for `receipts/groups/{groupId}/{expenseId}`.
  Same predicate shape; same review surface; closes R7 + R8 in
  one shot. Per the architect at §2.x: ship both predicates now
  to avoid a Sprint 3 follow-up; the UI surface stays
  friendship-only.
- **Storage rules tests — 8+ new tests.** New file at
  `functions/test/storage-rules/receipts.test.ts` mirrors the
  structure of `functions/test/storage-rules/avatars.test.ts`.
  Coverage: authenticated member upload (succeeds — AC-13);
  non-member upload rejected (AC-14); unauthenticated upload
  rejected (AC-15); oversize upload rejected (AC-16); wrong MIME
  rejected (AC-17); authenticated member read (succeeds);
  non-member read rejected; unauthenticated read rejected
  (AC-18 covers all three reads). The architect's call at §2.7
  is whether to also include group-context symmetric tests
  (recommend YES — same predicate shape; same test cost).
- **Four new telemetry events + extended `saveSucceeded`
  payload.** Per SCR-21 §Telemetry lines 357-362 and the
  Telemetry Events Introduced section below.
  `expense_save_succeeded`'s existing payload widens to set
  `has_receipt: true` (was always `false` in FR-EX-01) and to
  carry `receipt_size_bytes` (only when `has_receipt: true`).
- **CI scope.** No workflow change. The new rules tests run
  inside the existing dedicated
  `firebase emulators:exec --only firestore,storage` session
  (PR #46 split). The Flutter test layer runs unchanged; the
  functions trigger / canonical tests are unchanged (no
  `functions/src/**` changes in PR #48).

---

## Out of Scope

- **(a) FR-EX-07 Activity feed (separate P0 story; PR #49+).**
  The trigger already emits the activity entries on every expense
  write per the SRS schema; PR #48 trusts FR-EX-07's later
  implementation to read them. PR #48 must NOT add an
  activity-feed read surface, a `/activity` route, or any
  composite-index design for activity queries.
- **(b) FR-SE-09 Send reminder (separate P1 story; PR #49+).**
  Introduces the FCM dependency + the 24-hour rate-limit
  subcollection. Separate PR; PR #48 must NOT introduce FCM.
- **(c) Group-context UI for FR-EX-05.** The
  `AddExpenseBottomSheet` still launches from friendship surfaces
  only; the group-context Storage rule is defensive only (rules
  surface, no UI). Group-context UI ships with the Sprint 3
  groups epic (FR-EX-02 / FR-EX-05 / FR-EX-06 group halves).
- **(d) Orphan-cleanup Cloud Function.** SRS schema doc line 312
  notes that "Files under `receipts/` that are not referenced by
  any expense document's `receiptUrl` field shall be deleted
  after 90 days. This is enforced by a scheduled Cloud Function
  that scans for orphaned references, not by a Cloud Storage
  lifecycle policy (Firestore cross-reference is required)." The
  function is FUTURE work and is filed as a new tracking issue
  at Phase 5 step 12 of the source prompt. NOT implemented in
  PR #48.
- **(e) Trigger no-op-recompute optimisation.** A receipt-attach
  / receipt-remove update re-fires
  `recomputeSimplifiedBalances` even though balances are
  unaffected. The optimisation ("skip recompute when the update
  touches only `receiptUrl` + `updatedAt`") is FUTURE work and
  is filed as a new tracking issue. NOT implemented in PR #48.
- **(f) Concurrent-edit detection for FR-EX-06.** Still deferred
  per PR #46 §2.4. NOT touched here.
- **(g) OCR / AI category prediction on receipts.** SRS §12.3
  explicit out-of-scope item for v1.0.
- **(h) Multi-receipt expenses.** The schema is 1 receipt per
  expense (single `receiptUrl` field); multi-receipt is out of
  v1.0 scope.
- **(i) WebP / HEIC client conversion.** `image_picker`'s
  built-in `maxWidth/maxHeight` lossy resize is the v1.0
  compression strategy. iOS-side HEIC auto-conversion to JPEG
  is verified, NOT blocked (architect §2.9 anticipated
  reconciliation item).
- **(j) Issue #47 — Firestore rules-hardening for non-creator
  update / delete.** Separate small chore PR. PR #48 must NOT
  touch `firestore.rules`.
- **(k) Rate-limit transaction race refactor.** PR #45 §2.2
  deferred; out of scope here.
- **(l) Dependency bumps for `firebase_storage` or
  `image_picker`.** Stay on issue #22 for Sprint 4+.
- **(m) Hard delete of expenses or receipts independently of
  the soft-delete flow.** Out of SRS scope; the only client-side
  delete path is the soft-delete `{ deleted: true }` flip.

---

## Acceptance Criteria

Every AC is given in Given/When/Then form and is independently
testable. The numbering matches §1 of the source prompt
`docs/copilot_prompts/sprint_2/13.md`.

### Receipt attach flow — positive ACs

#### AC-1 — Step 3 opens after Step 2

> Given the user has completed Step 1 + Step 2 of the
> `AddExpenseBottomSheet` and the validators are green
> When they tap "Next" on Step 2
> Then Step 3 opens with the title `'Add Expense (3/3)'`
> (create mode) or `'Edit Expense (3/3)'` (edit mode)
> And the receipt picker section + the summary card both render
> And telemetry `expense_step3_opened` fires with
> `has_receipt_from_edit: false` (create mode) or `true|false`
> based on the edit-mode `existingReceiptUrl` presence.

#### AC-2 — Camera and gallery pickers

> Given Step 3 is open with no receipt attached
> When the user taps "Take Photo"
> Then `ImagePickerService.pickFromCamera` is invoked
> And on success the picked `XFile` is stored in the draft and
> the thumbnail renders inline
> And telemetry `expense_receipt_attached` fires with
> `source: 'camera'` and `file_size_bytes` (the file's actual
> on-device size in bytes)
> When the user taps "From Gallery"
> Then `ImagePickerService.pickFromGallery` is invoked
> And on success the same draft + thumbnail update path runs
> And telemetry `expense_receipt_attached` fires with
> `source: 'gallery'` and `file_size_bytes`.

#### AC-3 — Replace and remove affordances

> Given a receipt is attached
> When the user taps "Replace"
> Then the picker reopens (same camera-vs-gallery choice surface
> as the empty state)
> When the user taps "Remove"
> Then the receipt is cleared from the draft and the empty-state
> picker UI returns
> And telemetry `expense_receipt_removed` fires.

#### AC-4 — File-size validation client-side

> Given the user picks an image > 10 MB
> When the file is selected (returned by the picker)
> Then the receipt is REJECTED before any upload starts
> And an error snackbar appears: "Image is too large. Please
> choose a photo under 10 MB."
> And NO `expense_receipt_attached` telemetry event fires
> And NO upload begins.

#### AC-5 — MIME-type validation client-side

> Given the user picks a non-JPEG/PNG file (file extension not
> `.jpg`, `.jpeg`, or `.png`; OR mimeType not in
> `image/jpeg`, `image/png`)
> When the file is selected
> Then the receipt is REJECTED before any upload starts
> And an error snackbar appears: "This file format is not
> supported. Please use a JPEG or PNG image."
> And NO `expense_receipt_attached` telemetry event fires
> And NO upload begins
> (Note: HEIC files captured via camera are converted to JPEG by
> `image_picker` automatically — this is verified, NOT blocked.)

#### AC-6 — Save with receipt

> Given a receipt is attached and the user taps "Save Expense"
> When the save chain runs
> Then (a) the controller state transitions to `Uploading`
> And (b) the file is uploaded to
> `gs://onebytwo-avtanshgupta.appspot.com/receipts/friendships/{fid}/{eid}`
> And (c) the download URL is obtained
> And (d) the state transitions to `Saving`
> And (e) the Firestore expense doc is written with
> `receiptUrl: <download-url>`
> And (f) on success, telemetry `expense_save_succeeded` fires
> with `has_receipt: true` and `receipt_size_bytes: <bytes>`
> And (g) the sheet dismisses with the "Expense added." (create)
> or "Changes saved." (edit) snackbar.

#### AC-7 — Save without receipt

> Given no receipt is attached and the user taps "Save Expense"
> When the save chain runs
> Then the create / edit flow proceeds exactly as it did before
> PR #48 (no `Uploading` state; goes directly to `Saving`)
> And the document carries `receiptUrl: null` (create) or
> unchanged (edit)
> And telemetry `expense_save_succeeded` fires with
> `has_receipt: false` and NO `receipt_size_bytes` key.

### Read flow — positive ACs

#### AC-8 — Expense Detail thumbnail

> Given an expense with `receiptUrl != null` is viewed on the
> Expense Detail screen
> When the screen renders
> Then the receipt thumbnail (constrained to 240 × 320 dp per
> SCR-21 line 325) is visible below the splits list
> And tapping the thumbnail opens a fullscreen viewer (`Dialog`
> + `InteractiveViewer` + `Image.network` per architect §2.x).

#### AC-9 — Expense Detail no-receipt

> Given an expense with `receiptUrl == null` is viewed on the
> Expense Detail screen
> When the screen renders
> Then NO thumbnail and NO placeholder appear (the receipt
> section is omitted entirely; receipts are optional).

### Edit flow ACs — integration with PR #46 edit-mode

#### AC-10 — Pre-fill existing receipt

> Given an expense with `receiptUrl != null` is opened in the
> edit-mode bottom sheet
> When Step 3 renders
> Then the existing thumbnail is displayed in the receipt
> section (via `Image.network(existingReceiptUrl)`)
> And the existing URL is preserved (NOT re-uploaded) unless
> the user replaces or removes it.

#### AC-11 — Replace receipt in edit flow

> Given the user replaces the receipt in edit mode and saves
> When the save chain runs
> Then the new file is uploaded to the same canonical path
> (Firebase Storage overwrites the existing object)
> And the Firestore `update` map includes `receiptUrl` (the new
> download URL)
> And `changedFields.contains('receiptUrl')` is true
> And the changed-field indicator from PR #46 marks the receipt
> row on Step 3.

#### AC-12 — Remove receipt in edit flow

> Given the user removes the receipt in edit mode and saves
> When the save chain runs
> Then the Firestore `update` map sets `receiptUrl: null`
> And `changedFields.contains('receiptUrl')` is true
> And the Storage object at
> `receipts/friendships/{fid}/{eid}` is DELETED immediately on
> save (architect §2.x — delete immediately to avoid stale
> Storage; orphan-cleanup will reap any race-condition stragglers
> when it ships).

### Storage rules — negative + positive ACs

#### AC-13 — Storage rules: authenticated member upload succeeds

> Given an authenticated friendship member
> When they upload a JPEG ≤ 10 MB to
> `receipts/friendships/{fid}/{their-friendship's-expense-id}`
> Then the upload succeeds.
> Rules test at `functions/test/storage-rules/receipts.test.ts`.

#### AC-14 — Storage rules: non-member upload rejected

> Same as AC-13 but the caller is NOT a member of the friendship
> → `permission-denied`.

#### AC-15 — Storage rules: unauthenticated upload rejected

> Anonymous client → `permission-denied`.

#### AC-16 — Storage rules: oversized upload rejected

> Authenticated member, file size = 11 MB (> 10 MB cap) →
> rejected.

#### AC-17 — Storage rules: wrong MIME rejected

> Authenticated member, content-type `text/plain` → rejected.

#### AC-18 — Storage rules: read symmetry

> Authenticated member read succeeds.
> Non-member read rejected.
> Unauthenticated read rejected.
> (Three read tests symmetric to AC-13 / AC-14 / AC-15.)

### Cross-cutting and negative ACs

#### AC-19 — Telemetry PII guard

> Given any of the four new telemetry events fires with an
> `expense_id`-derived parameter
> Then the parameter value is the SHA-256-truncated hash via
> `hashId()` from `lib/core/telemetry/event_id_hash.dart`
> (NOT the raw expense ID, NOT the raw storage path)
> And the per-feature PII-leak test pattern at
> `test/features/expenses/expense_telemetry_pii_leak_test.dart`
> extends to cover the new events.

#### AC-20 — Invariant 2 negative guard

> Given the PR diff
> When scanned via the boundary-contract grep
> Then ZERO client-side writes to `simplifiedBalances` exist in
> any new or modified file (the field is server-maintained;
> the existing trigger is the sole writer)
> And the existing PR #36 rules test continues to enforce
> defence-in-depth server-side
> And the boundary-contract grep at
> `test/features/expenses/expense_creation_boundary_contract_test.dart`
> returns 0 matches for `simplifiedBalances` across
> `lib/features/expenses/**/*.dart` non-comment lines.

#### AC-21 — Invariant 1 boundary contract

> Given the PR diff
> When scanned for `double` arithmetic on any monetary value
> Then ZERO `double` operations exist on the receipt code path
> And the boundary-contract grep auto-covers all new files under
> `lib/features/expenses/**` introduced by this PR
> (`receipt_storage_service.dart`,
> `step_3_receipt_and_confirm.dart`,
> `receipt_fullscreen_viewer.dart`).

#### AC-22 — Integration test stub

> Given the PR diff
> When `test/integration/expenses/` is inspected
> Then a new (skipped) integration-test file exists at
> `test/integration/expenses/receipt_upload_flow_test.dart`
> documenting the canonical upload-then-view round-trip steps:
> (i) open the sheet in create mode;
> (ii) populate Step 1 + Step 2;
> (iii) advance to Step 3;
> (iv) attach a receipt via the fake picker;
> (v) tap Save Expense;
> (vi) confirm the upload + the Firestore write;
> (vii) confirm the trigger fires and the (no-op) recompute
> completes;
> (viii) open the Expense Detail screen;
> (ix) confirm the thumbnail is visible
> And the test ships with `skip: 'Requires emulator suite'`
> (partial PY3 credit).

#### AC-23 — `OBTConfirmationDialog` NOT required for remove-receipt

> Given the user taps "Remove" on an attached receipt
> When the action fires
> Then the receipt is cleared immediately with NO confirmation
> dialog (architect-elected per §2.x — the remove operation is
> reversible until save; no user data loss; a confirmation
> would add friction without protection).

---

## Telemetry Events Introduced

The four events PR #48 introduces. Camp B naming (verb-past + state)
matching PR #38's `expense_save_succeeded` / `expense_save_failed`
convention. SCR-21 §Telemetry Events lines 357-362 is the
authoritative source for the event names.

Every parameter that carries `expense_id` MUST be SHA-256 truncated
via `hashId()` from `lib/core/telemetry/event_id_hash.dart` per
ADR-0013 (enforced by AC-19).

| Event Name | Trigger | Parameters (PII-hashed per ADR-0013) | Constant Name in `expense_telemetry.dart` |
|---|---|---|---|
| `expense_step3_opened` | Step 3 becomes visible (AC-1) | `has_receipt_from_edit` (bool) | `step3Opened` |
| `expense_receipt_attached` | User attaches a receipt image (AC-2) | `source` (`'camera' \| 'gallery'`), `file_size_bytes` (int) | `receiptAttached` |
| `expense_receipt_removed` | User removes an attached receipt (AC-3) | — | `receiptRemoved` |
| `expense_step3_abandoned` | User dismisses the sheet from Step 3 | `had_receipt` (bool), `time_spent_ms` (int) | `step3Abandoned` |

The existing `expense_save_succeeded` event payload extends:

- `has_receipt: true` (was hard-coded `false` in FR-EX-01) when a
  receipt is attached.
- `receipt_size_bytes: <bytes>` is added when `has_receipt: true`
  (NEW parameter key `receipt_size_bytes`).

The existing `expense_save_failed` event payload is unchanged
(`error_code` already covers receipt-upload failures via the
mapped `ExpenseCreateErrorType.unknown` variant).

Note: the notification-type schema discriminator `'expense_edited'`
/ `'expense_deleted'` (per SRS §7.5 `firestore-schema.md:202`) is
unchanged. The AC-X4 negative guard from PR #45 still applies to
PR #48 (no schema discriminator changes).

---

## Definition of Ready

- [x] SRS sections cited and present: §4.5 (FR-EX-05 P1 at line
      210; FR-EX-04 paise integers; FR-EX-08 / FR-EX-09 inherited
      from PR #38), §4.6 (FR-SE-04 atomic recompute), §4.8
      (Firebase Storage usage and lifecycle), §5.6 (Add Expense
      Step 3 reactivated), §5.7 (NFR-PE-04 P95 budget — upload
      counts toward 2.5 s), §5.10 (telemetry funnel — extends
      with four new events), §7.3 (Invariants 1 + 2 — Inv-1 N/A
      on the receipt path; negative-guard load-bearing for
      Inv-2), §7.5 (data model — `receiptUrl: string | null`).
- [x] Screen specs cited:
      `docs/design/06-screen-specs/19-22-expenses.md` — SCR-21
      (lines 293-395) is the authoritative spec; SCR-22
      §Components Used "All SCR-21 components" line 429
      confirms the edit flow surfaces the existing thumbnail.
- [x] Wireframe baseline cited:
      `docs/design/04-wireframes/expense-flow.md` — the receipt
      step is wireframed as a dedicated screen but the SCR
      collapses it with the summary into one Step 3; PR #48
      ships the SCR resolution.
- [x] Design-system widget catalogue cited:
      `docs/design/02-design-system/components.md` — items
      used (image picker area, receipt thumbnail, summary card
      — all inlined per architect §2.x); no new design-system
      extractions are mandated by SCR-21 (precedent: PR #46
      extracted `OBTConfirmationDialog` on first use, PR #48
      defers `OBTReceiptThumbnail` extraction to the SECOND use
      site).
- [x] Firestore schema cited:
      `docs/design/07-technical/firestore-schema.md` lines 298-313
      — Storage layout for receipts (path schema, max size, MIME
      types, access rules, lifecycle).
- [x] Firestore security rules cited: `firestore.rules` line 205
      (`receiptUrl: string | null` already accepted; no
      `firestore.rules` change required).
- [x] Storage security rules cited: `storage.rules` — currently
      has only the `avatars/{userId}` rule; PR #48 adds the
      friendship-receipts predicate AND the defensive
      group-receipts predicate.
- [x] Telemetry plan cited:
      `docs/design/07-technical/telemetry-plan.md` — the four
      new event names match SCR-21 §Telemetry; the
      `paramReceiptSizeBytes` constant is added to the
      `ExpenseTelemetry` module (architect's call at §2.6).
- [x] Extension-points register cited:
      `docs/design/03-architecture/extension-points-register.md`
      — ARCH-EXT-02 (currency unchanged), ARCH-EXT-03
      (`recurringRule` stays omitted), ARCH-EXT-07 (`source:
      'manual'` stays). No new extension points are introduced
      by PR #48.
- [x] Architectural precedent cited:
      `lib/features/expenses/` from PR #38 + PR #46 (the full
      feature folder is the blueprint PR #48 extends in-place);
      `lib/features/auth/data/image_picker_service.dart` (the
      avatar-flow abstraction PR #48 extracts to core).
- [x] Hand-off seams confirmed:
      `lib/features/expenses/domain/expense_doc.dart` line 119
      (`'receiptUrl': null` already on the create-map — PR #48
      flips this when the user attaches);
      `lib/features/expenses/presentation/expense_detail_screen.dart`
      (PR #46 ships the Expense Detail body with no thumbnail
      yet — PR #48 adds the thumbnail render);
      `lib/features/auth/data/image_picker_service.dart` (the
      abstraction to extract to `lib/core/services/`);
      `lib/features/expenses/presentation/add_expense_bottom_sheet.dart`
      lines 188-196 (the `(N/2)` label flips to `(N/3)`);
      `lib/features/expenses/presentation/steps/step_2_split_and_payer.dart`
      line 314 (the "Save" / "Save Changes" label flips to
      "Next").

---

## Invariant Applicability Assessment (DoR §9)

- **Invariant 1 (paise integers; conversion to rupees at the UI
  layer only):** N/A on the receipt path itself — the upload
  pipeline carries an `XFile` and emits a `String` URL; no
  monetary surface. The surrounding save chain still runs
  through `OBTAmountInput.paiseValue` (integer) → controller
  state (integer) → `ExpenseDoc.toUpdateMap()` (integer) →
  Firestore write (integer) with zero floating-point arithmetic.
  The boundary-contract grep extends to cover the new files
  PR #48 introduces (`receipt_storage_service.dart`,
  `step_3_receipt_and_confirm.dart`,
  `receipt_fullscreen_viewer.dart`). AC-21 enforces.
- **Invariant 2 (`simplifiedBalances` server-maintained,
  client-read-only):** APPLIES — **negative-guard load-bearing**.
  The client writes ONLY to `friendships/{fid}/expenses/{eid}`
  (the `receiptUrl` field and the surrounding update map);
  NEVER to `friendships/{fid}.simplifiedBalances`. The trigger
  remains the sole writer of that field (and produces a no-op
  recompute on receipt-only updates — log noise filed as
  FUTURE optimisation). The existing PR #36 rules test
  continues to enforce defence-in-depth server-side. AC-20
  enforces.
- **Invariant 3 (system share sheet only — no platform-specific
  share-target imports):** N/A. PR #48 has no share affordance.
- **Invariant 4 (single Firebase project; single Storage
  bucket):** APPLIES — **defence-in-depth re-check**. PR #48
  touches `storage.rules` and the Storage client. `.firebaserc`
  continues to declare exactly one project
  (`"default": "onebytwo-avtanshgupta"`); the production bucket
  is `gs://onebytwo-avtanshgupta.appspot.com`; the local-dev
  emulator targets the single bucket on `127.0.0.1:9199`. The
  CI gate enforces.
- **ADR-0013 (PII / telemetry hashing):** APPLIES to every one
  of the four new telemetry events. Every parameter carrying
  `expense_id` MUST be hashed via `hashId()` from
  `lib/core/telemetry/event_id_hash.dart`. The receipt URL
  itself is NOT PII per se but the storage path embeds
  `expenseId` and SHOULD NOT be logged in raw form. AC-19
  enforces.

---

## Definition of Done

Reference: `docs/design/08-plan/definition-of-ready-and-done.md`.

- [ ] **Storage rules tests added.** New file
      `functions/test/storage-rules/receipts.test.ts` with 8+
      tests covering AC-13 through AC-18 plus the symmetric
      group-context tests per architect §2.7. Baseline: 7
      rules suites / 153 tests pass; target: 8 suites / 161+
      tests pass.
- [ ] **Widget tests.** Step 3 widget tests at
      `test/features/expenses/step_3_receipt_and_confirm_widget_test.dart`
      (empty-state picker; attached-state thumbnail + Replace +
      Remove; oversize / wrong-MIME rejection UI; uploading
      overlay). Expense Detail thumbnail tests extending
      `test/features/expenses/expense_detail_screen_widget_test.dart`
      (thumbnail renders when `receiptUrl != null`;
      omitted when `receiptUrl == null`; tap opens viewer).
      Image picker service smoke test at
      `test/core/services/image_picker_service_test.dart`.
- [ ] **Controller tests.** Receipt-attach / receipt-remove /
      upload-success / upload-failure tests extending
      `test/features/expenses/add_expense_controller_test.dart`
      (the new `setReceipt`, `removeReceipt`,
      `pickReceiptFromCamera`, `pickReceiptFromGallery`
      methods; the `Uploading → Saving → Success` chain; the
      upload-failure → `AddExpenseError` path).
- [ ] **Boundary-contract grep extended.** The existing
      grep at
      `test/features/expenses/expense_creation_boundary_contract_test.dart`
      auto-covers any new files under `lib/features/expenses/**`
      via the recursive walk; AC-20 + AC-21 enforce.
- [ ] **PII-leak test.** The 4 new telemetry events covered by
      extension to
      `test/features/expenses/expense_telemetry_pii_leak_test.dart`.
- [ ] **Integration-test stub.** New (skipped) integration
      test at
      `test/integration/expenses/receipt_upload_flow_test.dart`
      with `skip: 'Requires emulator suite'`. Documents the
      canonical round-trip steps per AC-22.
- [ ] **Manual smoke matrix from Phase 5 step 11** of
      `docs/copilot_prompts/sprint_2/13.md`:
      (i) start emulators (`scripts/dev/start-emulators.sh`);
      (ii) sign in as User A; create an expense with a JPEG
      attached; verify the thumbnail in Expense Detail;
      (iii) edit the same expense; replace the receipt; verify
      the new thumbnail;
      (iv) edit again; remove the receipt; verify the Expense
      Detail no longer shows a thumbnail;
      (v) try to upload an 11 MB file; verify the client
      rejects with the size snackbar;
      (vi) try to upload a `.txt` file; verify the MIME
      snackbar;
      (vii) sign in as the friend (other member); verify they
      can READ the thumbnail;
      (viii) sign in as an outsider; verify they CANNOT read
      (rules enforcement).
- [ ] **Source: storage rules + Step 3 widget + storage service
      + telemetry constants + Expense Detail thumbnail + fullscreen
      viewer + edit-mode pre-fill / replace / remove + extracted
      `ImagePickerService`.** All files in the exhaustive list at
      Architect Notes §2.7.
- [ ] **`flutter analyze --fatal-infos`** exits with "No issues
      found".
- [ ] **`flutter test`** baseline + N new tests pass / 27 + M
      skipped (M = integration stub).
- [ ] **`cd functions && npm run lint && npm run build && npm
      test`** stays at 9 suites / 100 tests pass (no
      `functions/src/**` changes).
- [ ] **`cd functions && npm run test:rules`** runs 8 suites /
      161+ tests pass under the dedicated
      `firebase emulators:exec --only firestore,storage`
      session.
- [ ] **`dart format --set-exit-if-changed .`** exits 0.
- [ ] **Invariant compliance:** Invariant 1 N/A on the receipt
      path (boundary-contract grep auto-covers new files);
      Invariant 2 negative-guard load-bearing (no client
      `simplifiedBalances` writes); Invariant 3 N/A; Invariant 4
      single bucket targeted in production and emulator.
- [ ] **CI green** on PR open: PR title lint (single-token
      conventional commit scope), Flutter Lint & Test, Build
      Android (debug), Build iOS (debug), Firestore + Storage
      Rules tests, Cloud Functions Build & Test, Integration
      Tests (Emulator Suite). The `Title Lint` regex
      `[a-z0-9_-]+` continues to enforce a single-token scope
      (PR #45 verified).
- [ ] **Documentation updated:**
      (i) `docs/sprint-zero/sprint-2-plan.md` — PR #48 row at
      status `merged`; velocity #14 (5 SP, total now 50 SP
      across 14 PRs);
      (ii) `docs/sprint-zero/next-three-prs.md` — PR #48 row
      marked merged; PR #49 / #50 / #51 candidates per Phase 7
      of the source prompt (top: FR-EX-07 activity feed);
      (iii) `docs/audits/sprint-1/07-bucket-b-burndown.md` —
      header timestamp rolled to PR #48; appends a PR #48
      section closing **R7 + R8** (Storage rules tests for
      file size + content type); remaining drops to **28 / 37**;
      (iv) two new FUTURE-work issues filed: orphan-cleanup
      Cloud Function for receipts AND trigger no-op-recompute
      optimisation when only `receiptUrl` + `updatedAt`
      change.
- [ ] **PR body cites:** SCR-21 + SCR-22 §Components Used "All
      SCR-21 components" integration; Invariants 1 / 2 / 4
      (Inv-3 N/A); AC-X4 (notification-type schema discriminator
      UNCHANGED); the deferred items (orphan-cleanup function,
      trigger no-op optimisation, group-context UI, OCR / AI,
      multi-receipt); the explicit closure of R7 + R8;
      `Next PR: PR #49 — TBD per architect's call at kickoff
      (top candidate: FR-EX-07 activity feed).`

---

## Notes for the Architect

1. **Storage path schema.** Confirm the SRS canonical path
   `receipts/friendships/{friendshipId}/{expenseId}` — single
   object per expense; overwrite-on-replace; delete-on-remove. PM
   recommends shipping the group-context predicate in the SAME PR
   (defensive; closes R7 + R8 in one shot; UI stays
   friendship-only).
2. **Upload-then-save chain.** Confirm the two-phase `save()`
   structure: `Uploading` (new sealed-state variant) → upload →
   obtain URL → `Saving` → Firestore write. On upload failure →
   `AddExpenseError` with `errorType:
   ExpenseCreateErrorType.unknown` and a user-facing message
   distinct from the save-failure message.
3. **`ReceiptStorageService` API surface.** Confirm the abstract /
   concrete pattern (`FirebaseReceiptStorageService`); typed
   `ReceiptUploadError` enum.
4. **`ImagePickerService` extraction.** PM recommends extracting
   to `lib/core/services/image_picker_service.dart` (auth feature
   imports from core). Architect ratifies in §2.4.
5. **Image compression strategy.** PM recommends `image_picker`'s
   `maxWidth: 1920, maxHeight: 1920` as the v1.0 strategy; no
   WebP / OCR.
6. **Telemetry constants.** Confirm the 4 new event constants +
   the new `paramSource`, `paramFileSizeBytes`,
   `paramHasReceiptFromEdit`, `paramReceiptSizeBytes`,
   `paramHadReceipt` parameter keys; extend the existing
   `paramHasReceipt` semantic from "always false" to "true when
   attached".
7. **`OBTReceiptThumbnail` extraction.** PM recommends inline on
   first use (Step 3 + Expense Detail use different sizing and
   tap behaviours); extract on the SECOND new use site (PR #49+).
8. **`OBTConfirmationDialog` for remove-receipt?** PM recommends
   NO confirmation (AC-23 — the remove is reversible until save).
9. **Files explicitly NOT to touch.** `firestore.rules`,
   `firestore.indexes.json`, `functions/src/**`,
   `functions/package.json`, `package-lock.json`,
   `firebase.json`, `.github/workflows/*.yml`,
   `lib/features/settlements/**`, `lib/features/friends/**`,
   the notification-type schema discriminator, `pubspec.yaml`,
   `pubspec.lock`, `analysis_options.yaml`, Android / iOS native
   shells.

---

## Architect Notes

> Appended for PR #48 (Phase 2 of
> `docs/copilot_prompts/sprint_2/13.md`). These notes ratify
> the nine PM Notes (§1–§9 above), confirm the Storage rules
> cross-collection predicate pattern is sound, and lock the
> file-touch envelope before implementation begins. References:
> `storage.rules` (existing avatars predicate as precedent);
> `firestore.rules` line 205 (`receiptUrl` shape already
> accepted); SCR-21 at
> `docs/design/06-screen-specs/19-22-expenses.md` lines
> 293-395; SCR-22 §Components Used line 429 ("All SCR-21
> components"); FR-EX-06 architect-notes precedent at
> `docs/sprint-zero/stories/FR-EX-06-edit-delete-expense.md`
> lines 1308+; ADR-0013 (PII / telemetry hashing);
> Invariants 1, 2, 4 from `.github/shared/invariants.md`.

### Mapping of PM Notes to Architect Notes subsections

| PM § | Topic | Ratified in | Verdict |
|---|---|---|---|
| 1 | Storage path schema + group-context defensive rule | §2.1 | RATIFY — single object per expense; ship group-receipts predicate in same PR |
| 2 | Upload-then-save chain + `Uploading` state | §2.2 | RATIFY — new sealed-state variant; reuse `ExpenseCreateErrorType.unknown` |
| 3 | `ReceiptStorageService` API surface | §2.3 | RATIFY — abstract + concrete; typed `ReceiptUploadError` enum |
| 4 | `ImagePickerService` extraction to `lib/core/services/` | §2.4 | RATIFY — Option (a) extract + update auth imports |
| 5 | Image compression — `image_picker` max dims | §2.5 | RATIFY — `maxWidth: 1920, maxHeight: 1920`; no WebP / OCR |
| 6 | Telemetry constants — 4 events + 4 new params | §2.6 | RATIFY — Camp B verb-past + state; extend `paramHasReceipt` semantic |
| 7 | `OBTReceiptThumbnail` extraction | §2.7 + §2.x | DEFER — inline first; extract on the SECOND new use site |
| 8 | `OBTConfirmationDialog` for remove-receipt | §2.x (AC-23) | RATIFY — NO confirmation; remove is reversible until save |
| 9 | Negative scope guardrails | §2.8 | RATIFY — `firestore.rules`, `functions/src/**`, deps all OFF-LIMITS |

---

### §2.1 — Storage path schema and group-context defensive rule

**Decision.** Adopt the SRS canonical path
`receipts/friendships/{friendshipId}/{expenseId}` (single object
per expense; overwrite-on-replace; delete-on-remove). The
group-context rule `receipts/groups/{groupId}/{expenseId}` ships
in the SAME PR — same predicate shape; same review surface;
closes R7 + R8 in one shot.

**Rationale.**
- The SRS schema doc at lines 298-313 specifies the path schema
  unambiguously (`receipts/{contextType}/{contextId}/{expenseId}`);
  the only architect choice is whether to ship the group-context
  half of the rule now. Shipping both predicates now (a) closes
  R7 + R8 in a single PR per the Sprint-1 Bucket-B burndown, (b)
  avoids re-litigating the same predicate shape during the
  Sprint 3 groups epic, (c) costs trivially more test surface
  (the same 8 tests, mirrored).
- The UI surface stays friendship-only per Phase 3 guardrails —
  the bottom sheet does NOT launch from group surfaces in
  PR #48; only the rules surface is defensive.
- The `firestore.get()` predicate that reads the parent
  `friendships/{friendshipId}.memberIds` document is a
  non-trivial first for this codebase's Storage rules (avatars
  don't cross-reference Firestore). The rules-tests verify the
  predicate works end-to-end against the emulator before merge.

**Single-object-per-expense.** The path has NO file-name
suffix (no `.jpg`, no UUID) — replacing the receipt simply
overwrites the object at the same path. Firebase Storage
overwrite semantics are atomic; no client-side delete is needed
before re-uploading. Removing the receipt calls
`deleteFriendshipReceipt(...)` and clears `receiptUrl` in
Firestore in the same `save()` transaction (architect-elected
NOT a true atomic transaction — Firebase Storage operations
can't be bundled with Firestore writes; the receipt is deleted
FIRST, then the Firestore update fires; on Firestore failure
the Storage object is GONE but a follow-up retry replays
cleanly because `receiptUrl: null` reflects the user's intent).
The architect's anticipated reconciliation list at §2.9 flags
this as item 5.

---

### §2.2 — Upload-then-save chain and the new `Uploading` state

**Decision.** RATIFY the two-phase `save()` chain in
`AddExpenseController`:

1. If `draft.receiptFile != null && (isCreateMode ||
   receiptChanged)` → transition to `Uploading(draft: draft)`
   → upload the file via `receiptStorageService.uploadFriendshipReceipt(...)`
   → obtain the download URL.
2. Transition to `Saving(draft: draft)` → repository call
   (`createExpense` with `receiptUrl: <url>` baked into the
   create-map, or `updateExpense` with `receiptUrl` in the
   partial-update map).

Add `Uploading` as a NEW sealed-state variant on
`AddExpenseState` (does NOT replace `Saving`; both are distinct
UI states per SCR-21 §State 3 + §State 4).

```dart
class Uploading extends AddExpenseState {
  const Uploading({required this.draft});
  final ExpenseDraft draft;
}
```

**Error handling.** On `ReceiptUploadError` from the storage
service:
- Map to `AddExpenseError(draft: draft, errorType:
  ExpenseCreateErrorType.unknown, message: <user-facing>)`.
- Re-use the existing `ExpenseCreateErrorType.unknown` variant
  rather than introducing a new `receiptUploadFailed` variant
  — keeps the enum narrow and the failure surface uniform.
- The user-facing message is the SCR-21 receipt-error wording:
  `"Could not attach receipt. Try again."` (NOT the generic
  save-failure copy — the user knows the receipt was the
  problem). Surface this distinct message via the existing
  `state.message` field; the snackbar already renders
  `state.message` verbatim.

**Telemetry on upload failure.** The existing `_emitSaveFailed`
helper fires `expense_save_failed` with
`error_type: 'unknown'` and `is_offline: false`. No new event
is introduced for upload failure per the architect's call —
SCR-21 §Telemetry lists 6 events and upload failures are
folded under `expense_save_failed`; the only distinguishing
parameter is the failure message at the UI surface.

**No save attempt if upload fails.** If the upload throws, the
Firestore write does NOT proceed — the user is left in
`AddExpenseError` and can retry. The architect explicitly
elects this over a "save without receipt" fallback because the
user's intent (an expense WITH a receipt) is preserved across
the retry.

---

### §2.3 — `ReceiptStorageService` API surface

**Decision.** New file
`lib/features/expenses/data/receipt_storage_service.dart`:

```dart
abstract class ReceiptStorageService {
  Future<String> uploadFriendshipReceipt({
    required String friendshipId,
    required String expenseId,
    required XFile file,
  });

  Future<void> deleteFriendshipReceipt({
    required String friendshipId,
    required String expenseId,
  });
}

class FirebaseReceiptStorageService implements ReceiptStorageService {
  const FirebaseReceiptStorageService({required FirebaseStorage storage})
      : _storage = storage;
  final FirebaseStorage _storage;
  // ... implementation that maps FirebaseException → ReceiptUploadError ...
}

final receiptStorageServiceProvider = Provider<ReceiptStorageService>(
  (ref) => FirebaseReceiptStorageService(
    storage: ref.watch(firebaseStorageProvider),
  ),
);
```

**Typed error enum.**

```dart
enum ReceiptUploadErrorType {
  permissionDenied,
  oversize,
  unsupportedType,
  network,
  unknown,
}

class ReceiptUploadError implements Exception {
  const ReceiptUploadError({required this.type});
  final ReceiptUploadErrorType type;
}
```

**Belt-and-braces validation.** The size + MIME-type checks
are performed CLIENT-SIDE in the controller before the upload
starts (so the user gets immediate feedback via the SCR-21
size / MIME snackbars) AND server-side by `storage.rules` (so a
client bypass attempt is caught at the boundary). Both layers
are load-bearing; the client checks are NOT defence-in-depth
for the rules — they're the only path that surfaces the
user-facing snackbars.

**File path construction.** The service builds the path via
`'receipts/friendships/$friendshipId/$expenseId'` — no escaping
needed (friendship IDs are `{uidA}_{uidB}` composite ASCII;
expense IDs are Firestore-generated `[A-Za-z0-9]{20}`).

**`firebaseStorageProvider` reuse.** The existing
`firebaseStorageProvider` at
`lib/features/auth/data/user_repository.dart` lines 19-21 is
the canonical instance provider. The architect elects to
reuse it as-is (no extraction to `lib/core/firebase/` — that
extraction belongs to a separate hygiene PR).

---

### §2.4 — `ImagePickerService` extraction to `lib/core/services/`

**Decision.** RATIFY **Option (a)**: extract from
`lib/features/auth/data/image_picker_service.dart` to
`lib/core/services/image_picker_service.dart`. Update both:

- `lib/features/auth/application/profile_setup_controller.dart`
  (the avatar picker call site)
- `lib/features/profile/application/edit_profile_controller.dart`
  (the avatar edit call site)
- The new `lib/features/expenses/application/add_expense_controller.dart`
  (the receipt picker call site)

so all three import from the core path. Test files for all
three features inject the same `FakeImagePickerService`.

**File extraction strategy.** Move the entire file (1:1) and
delete the original. Update all imports. The existing
`imagePickerServiceProvider` lives in the new core module; the
auth feature's existing tests continue to work after import
path updates.

**Test files that need the import path update:**
- `test/integration/auth/profile_setup_flow_test.dart`
- `test/features/profile/profile_screen_test.dart`
- `test/features/profile/edit_profile_controller_test.dart`
- `test/features/profile/edit_profile_screen_test.dart`
- `test/features/auth/profile_setup_screen_test.dart`
- `test/features/auth/profile_setup_controller_test.dart`

**Rationale.** Having the auth feature own the picker for the
receipt flow is the wrong dependency direction — `expenses`
would import from `features/auth/data/`, which would couple
the two unrelated features. The picker is a domain-agnostic
device-service abstraction; `lib/core/services/` is the
natural home.

---

### §2.5 — Image compression strategy

**Decision.** RATIFY relying on `image_picker`'s
`maxWidth: 1920, maxHeight: 1920` (lossy-resize) as the v1.0
strategy. Both `pickFromCamera` and `pickFromGallery` call
sites in the new controller pass these dimensions explicitly
(the default `maxWidth/maxHeight` in the existing
`ImagePickerService` is 1024 — too aggressive for receipts;
override at the receipt-flow call sites to 1920 to preserve
legibility of small print on receipts).

**Out-of-scope optimisations** (file as FUTURE issue at Phase 5
step 12):
- WebP conversion (smaller files but iOS support quirks);
- Server-side OCR (out of SRS scope per §12.3);
- Progressive upload / resume (out of scope; receipts are
  small enough that a single PUT is acceptable).

**P95 budget.** SRS §5.7 NFR-PE-04 sets a 2.5 s P95 on the
save chain. The architect accepts that a receipt upload may
breach this on slow connections — the user gets the
`Uploading` state's overlay spinner as a progress signal; the
budget is a target, not a contract, for the receipt-attached
path. The architect's anticipated reconciliation list at §2.9
item 7 flags this for QA acceptance.

---

### §2.6 — Telemetry constants

**Decision.** Add to
`lib/features/expenses/application/expense_telemetry.dart`:

**New event constants:**

```dart
static const String step3Opened = 'expense_step3_opened';
static const String receiptAttached = 'expense_receipt_attached';
static const String receiptRemoved = 'expense_receipt_removed';
static const String step3Abandoned = 'expense_step3_abandoned';
```

**New parameter-key constants:**

```dart
static const String paramSource = 'source';
static const String paramFileSizeBytes = 'file_size_bytes';
static const String paramHasReceiptFromEdit = 'has_receipt_from_edit';
static const String paramReceiptSizeBytes = 'receipt_size_bytes';
static const String paramHadReceipt = 'had_receipt';
```

**Extended `paramHasReceipt` semantic.** The existing
`paramHasReceipt = 'has_receipt'` constant flips from
"always false in FR-EX-01" to "true when a receipt is
attached at save time". The constant itself stays; only the
emission logic changes.

**Saved payload schema extension.** `_emitSaveSucceeded`
extends to include `has_receipt: <bool>` (already present —
flip the literal from `false` to a computed value) AND, when
`has_receipt: true`, a new `receipt_size_bytes: <int>` key.

**Camp B naming.** All four new events follow the verb-past +
state pattern (`expense_step3_opened`,
`expense_receipt_attached`, `expense_receipt_removed`,
`expense_step3_abandoned`) matching the FR-EX-01 / FR-EX-06
precedent.

**Step 3 abandonment payload.** When the user dismisses the
sheet from Step 3:
- `had_receipt: true|false` (whether the draft had a receipt
  at dismiss time).
- `time_spent_ms: <int>` (wall-clock time since Step 3 opened
  — NOT since Step 1; the controller adds a new
  `_step3OpenedAt: DateTime?` field).

---

### §2.7 — Files to touch (exhaustive — anything outside this set is scope creep)

#### Storage rules

- `storage.rules` — adds the friendship-receipts predicate
  AND the group-receipts predicate (defensive — UI stays
  friendship-only).

#### Core services

- `lib/core/services/image_picker_service.dart` — **NEW**
  (moved from `lib/features/auth/data/`).
- `lib/features/auth/data/image_picker_service.dart` —
  **DELETED** (extracted to core).
- `lib/features/auth/application/profile_setup_controller.dart`
  — update import path.
- `lib/features/profile/application/edit_profile_controller.dart`
  — update import path.

#### Expense feature — data layer

- `lib/features/expenses/data/receipt_storage_service.dart`
  — **NEW** (`ReceiptStorageService` abstract +
  `FirebaseReceiptStorageService` concrete +
  `receiptStorageServiceProvider`).

#### Expense feature — domain layer

- `lib/features/expenses/domain/expense_doc.dart` — add
  `fieldReceiptUrl = 'receiptUrl'` constant; extend
  `toUpdateMap` to write the URL when in `_changedFields`;
  extend `fromMap` to parse `receiptUrl` from the document
  data.
- `lib/features/expenses/domain/expense_draft.dart` — add
  `final XFile? receiptFile;` and `final String?
  existingReceiptUrl;`; extend `copyWith` to support both
  (use a sentinel for nullable replacement —
  `Object? receiptFile = _sentinel` pattern).
- `lib/features/expenses/domain/add_expense_state.dart` — add
  the `Uploading` sealed variant.
- `lib/features/expenses/domain/receipt_upload_error.dart` —
  **NEW** (typed `ReceiptUploadErrorType` enum +
  `ReceiptUploadError` exception class).

#### Expense feature — application layer

- `lib/features/expenses/application/expense_telemetry.dart`
  — 4 new event constants + 5 new param-key constants;
  extended `paramHasReceipt` semantic.
- `lib/features/expenses/application/add_expense_controller.dart`
  — add `setReceipt(XFile?)`, `removeReceipt()`,
  `pickReceiptFromCamera()`, `pickReceiptFromGallery()`;
  extend `proceedToStep3()` method; extend the `save()` chain
  with the two-phase Upload → Save transition; add new
  `_emitStep3Opened` / `_emitReceiptAttached` /
  `_emitReceiptRemoved` / `_emitStep3Abandoned` emit helpers;
  extend `_emitSaveSucceeded` with the new payload keys;
  inject `ReceiptStorageService` + `ImagePickerService` via
  constructor.

#### Expense feature — presentation layer

- `lib/features/expenses/presentation/add_expense_bottom_sheet.dart`
  — flip the `_SheetHeader` title from `(N/2)` to `(N/3)`;
  extend the step switch to `step == 3 →
  Step3ReceiptAndConfirm`; update the discard / on-pop
  handling for Step 3.
- `lib/features/expenses/presentation/steps/step_2_split_and_payer.dart`
  — flip the `_SaveButton` label from "Save" / "Save Changes"
  to "Next"; the actual save fires from Step 3.
- `lib/features/expenses/presentation/steps/step_3_receipt_and_confirm.dart`
  — **NEW** (SCR-21 surface: receipt picker on top, summary
  card in the middle, Save Expense / Save Changes CTA at the
  bottom).
- `lib/features/expenses/presentation/expense_detail_screen.dart`
  — extend the body to render a 240 × 320 dp receipt
  thumbnail when `doc.receiptUrl != null`; tap → fullscreen
  viewer.
- `lib/features/expenses/presentation/widgets/receipt_fullscreen_viewer.dart`
  — **NEW** (simple `Dialog` + `InteractiveViewer` +
  `Image.network`; tap-outside dismisses).

#### Tests

- `functions/test/storage-rules/receipts.test.ts` — **NEW**
  (8+ tests for AC-13..18 + symmetric group-context tests).
- `test/core/services/image_picker_service_test.dart` —
  **NEW** (smoke test for the extracted service — provider
  resolves; default impl returns a real `ImagePicker`).
- `test/features/expenses/add_expense_controller_test.dart`
  — extend with receipt-attach / receipt-remove / upload-success
  / upload-failure tests; Step 3 transition tests.
- `test/features/expenses/expense_telemetry_pii_leak_test.dart`
  — extend with PII guards for the 4 new events.
- `test/features/expenses/step_3_receipt_and_confirm_widget_test.dart`
  — **NEW** (empty-state picker; attached-state thumbnail +
  Replace + Remove; oversize / wrong-MIME rejection;
  uploading overlay).
- `test/features/expenses/expense_detail_screen_widget_test.dart`
  — extend with thumbnail render test (present when
  `receiptUrl != null`; absent when `null`); tap-opens-viewer
  test.
- `test/integration/expenses/receipt_upload_flow_test.dart`
  — **NEW** (skipped stub per AC-22).

#### Documentation + plan

- `docs/sprint-zero/stories/FR-EX-05-receipt-attachment.md`
  — **NEW** (Phase 1).
- `docs/sprint-zero/sprint-2-plan.md` — add PR #48 row
  (5 SP; cumulative 50 SP / 14 PRs).
- `docs/sprint-zero/next-three-prs.md` — roll PR #48 to
  merged; PR #49 / #50 / #51 candidates.
- `docs/audits/sprint-1/07-bucket-b-burndown.md` — close
  R7 + R8; remaining drops to 28 / 37.

---

### §2.8 — Files explicitly NOT to touch (negative scope guardrails)

**MUST NOT TOUCH** in PR #48:

- `firestore.rules` — no changes required (the `receiptUrl:
  string | null` shape predicate at line 205 already covers
  the field). Touching this file in PR #48 conflates the
  receipt-attachment surface with issue #47 (rules hardening
  for non-creator update / delete) which is a separate small
  chore PR.
- `firestore.indexes.json` — no new queries; no new indexes
  required.
- `functions/src/**` — the orphan-cleanup Cloud Function is
  FUTURE work; the trigger no-op-recompute optimisation is
  FUTURE work. Both filed as new tracking issues at Phase 5
  step 12.
- `functions/package.json`, `functions/package-lock.json` — no
  new functions dependencies.
- `firebase.json` — emulator config + storage rules path
  unchanged.
- `.github/workflows/*.yml` — no workflow changes (the rules
  test runs inside the existing dedicated
  `firebase emulators:exec --only firestore,storage` session
  per PR #46's split).
- `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml` —
  `firebase_storage: ^13.3.0` and `image_picker: ^1.1.2` are
  already pinned. No dependency bumps in PR #48; those stay
  on issue #22 for Sprint 4+.
- `lib/features/settlements/**`, `lib/features/friends/**` —
  unrelated.
- `lib/features/groups/**` (if it exists) — Sprint 3 epic.
- `android/`, `ios/`, `web/` — no native shell changes.
- `firestore-schema.md:202` notification-type schema
  discriminator — AC-X4 carry-forward.

---

### §2.9 — Anticipated reconciliations

Document EXACTLY the verification items the implementation
phase must close before merge:

1. **`firestore.get()` inside Storage rules works against the
   emulator.** The friendship-membership check at
   ```
   request.auth.uid in
     firestore.get(/databases/(default)/documents/friendships/$(friendshipId)).data.memberIds
   ```
   is a non-trivial first for this codebase. Verification: the
   8 rules tests in §2.7 cover (i) authenticated member upload
   succeeds (positive path — the predicate resolves true);
   (ii) non-member upload rejected (negative path — the
   predicate resolves false because the UID is not in the
   array). Both must pass against the local Storage emulator
   AND against the CI `firebase emulators:exec --only
   firestore,storage` session.

2. **Storage emulator local-dev gap.**
   `scripts/dev/start-emulators.sh` already starts the Storage
   emulator (port 9199 per `firebase.json`). Verification: a
   smoke run of `cd functions && npm run test:rules` against
   the local emulator suite returns 8 suites / 161+ tests
   pass.

3. **`image_picker` HEIC → JPEG auto-conversion (iOS-only).**
   iOS's native camera captures HEIC by default. The
   `image_picker` plugin auto-converts HEIC to JPEG when
   returning the `XFile` (verified in upstream
   documentation). Verification: the controller's MIME-type
   check inspects `XFile.mimeType` (or falls back to file
   extension) AFTER the picker returns; HEIC → JPEG happens
   inside the picker so the post-pick MIME is `image/jpeg` and
   the upload satisfies the JPEG/PNG rule. Android does NOT
   have HEIC so no analogous concern.

4. **Trigger no-op recompute on receipt-only updates.** File
   as a FUTURE optimisation issue at Phase 5 step 12. NOT
   fixed in PR #48. The trigger correctness is unchanged;
   only the log noise + the trivial CPU cost of an unnecessary
   recompute is the cost. Wait for the activity-feed work
   (FR-EX-07) to converge before optimising.

5. **Orphan-cleanup Cloud Function.** File as a FUTURE issue
   at Phase 5 step 12 per SRS schema doc line 312 (90-day
   reaper). NOT implemented in PR #48. The remove-receipt
   path in PR #48 calls `deleteFriendshipReceipt(...)`
   immediately on save (architect-elected — see §2.1 for the
   atomicity reasoning), so the only orphan path is a
   crash-mid-save scenario (Storage object uploaded, Firestore
   write fails). The orphan reaper is the long-term solution.

6. **PR #46 changed-field indicator integration.** The
   receipt row in Step 3 surfaces the `ChangedFieldIndicator`
   from
   `lib/features/expenses/presentation/widgets/changed_field_indicator.dart`
   when `controller.isFieldChanged(ExpenseDoc.fieldReceiptUrl)`
   is true. The semantic label suffix ", changed." per
   SCR-22 §449 carries over. Verification: the Step 3 widget
   test covers the changed-field indicator render path.

7. **NFR-PE-04 P95 budget on receipt-attached saves.** The
   save chain has an additional Storage round-trip when a
   receipt is attached; the 2.5 s P95 may be breached on slow
   connections. QA flags this for acceptance: the `Uploading`
   state provides a clear progress signal; the budget is
   honoured for receipt-free saves (no regression). QA's
   smoke matrix at Phase 5 step 11 includes a slow-network
   reproduction to verify the user experience degrades
   gracefully.

8. **Storage object overwrite atomicity on Replace.** Firebase
   Storage's PUT replaces the object atomically (no
   intermediate empty state). The new download URL has the
   SAME path as the old, so any cached read on the friend's
   device would still hit the old object until the cache
   expires. Verification: the `Image.network` widget uses the
   download URL with a server-generated token query parameter
   (`?alt=media&token=...`) that changes on overwrite, so the
   cache key is invalidated automatically. Smoke test in Phase
   5 step 11 (step v) confirms.

9. **Receipt size on the abandonment payload.** SCR-21 line
   362's `had_receipt` parameter is a bool (the receipt was
   attached at sheet-dismiss time, regardless of whether it
   was uploaded). The architect elects NOT to include
   `receipt_size_bytes` on the abandonment event — only the
   "did the user reach Step 3 with a receipt" signal is
   needed for the funnel analysis.

10. **Edit-mode receipt change detection.** `_markChanged`
    extends to handle `fieldReceiptUrl` as a string compare.
    The original snapshot captures `existingReceiptUrl: doc.receiptUrl`
    (which may be `null`); the post-change draft carries either
    a new `receiptFile: XFile?` (which means changed-to-attach
    or changed-to-replace) OR a null clear (which means
    changed-to-remove). The architect's call: the change is
    "any of (file != null && !receiptChanged-from-original) ||
    (file == null && existingReceiptUrl != null)". Spell this
    out in the controller comment so the future maintainer
    doesn't have to derive it.

