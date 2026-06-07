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

**Ready for Architect Notes.** PM authorship complete. Architect
appends `## Architect Notes` (Phase 2 §2.1–§2.9 per the source
prompt `docs/copilot_prompts/sprint_2/13.md`) in a separate commit
before Phase 3 implementation begins.

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
