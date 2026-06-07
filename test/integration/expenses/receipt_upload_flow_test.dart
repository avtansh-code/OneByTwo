// FR-EX-05 receipt upload integration flow tests.
//
// End-to-end round-trip through the Firebase Storage upload + the
// registered `onExpenseWriteFriendship` trigger (PR #36) inside
// `firebase emulators:exec --only auth,firestore,functions,storage`.
//
// Mirrors the skipped-stub pattern from
// test/integration/expenses/edit_delete_expense_flow_test.dart and
// test/integration/expenses/expense_creation_flow_test.dart — the
// concrete steps are documented for the future emulator harness;
// each test is `skip:`ped locally until the harness is reachable.
//
// When run inside `firebase emulators:exec`, the harness will set
// USE_EMULATORS=true (the established convention).

@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Receipt upload integration (FR-EX-05) — round-trip via Firebase '
      'Storage + the onExpenseWriteFriendship trigger', () {
    test('end-to-end: user A creates a friendship expense with a JPEG '
        'receipt attached → file uploads to '
        'gs://onebytwo-avtanshgupta.appspot.com/receipts/friendships/'
        '{fid}/{eid} → Firestore expense doc is written with the '
        'download URL → ExpenseDetailScreen renders the thumbnail', () {
      // TODO(flutter-dev): implement once the emulator harness is
      // wired up. Mirrors the existing skipped-stub precedent.
      //
      // Steps (canonical):
      // 1. Initialise Firebase with the emulator host/port (the
      //    established convention is FIREBASE_FIRESTORE_EMULATOR_HOST,
      //    FIREBASE_AUTH_EMULATOR_HOST, and the Storage emulator
      //    via FirebaseStorage.instance.useStorageEmulator).
      // 2. Seed user A (authenticated as uid-A), user B (uid-B),
      //    and the friendship doc at friendships/uid-A_uid-B with
      //    memberIds == [uid-A, uid-B] and an empty
      //    simplifiedBalances {}.
      // 3. Build a fake ImagePickerService that returns a
      //    test-fixture JPEG file (under 10 MB; valid MIME). The
      //    fake intercepts the picker so the test does not need
      //    platform camera/gallery surfaces.
      // 4. Mount the AddExpenseBottomSheet under flutter_test
      //    with args { friendshipId: 'uid-A_uid-B' } using the
      //    production providers + emulator-backed Firebase.
      // 5. Drive the UI:
      //    a. Enter '500' into the amount input;
      //    b. Enter 'Lunch with B' into the description input;
      //    c. Tap the Food category chip;
      //    d. Tap Next → Step 2;
      //    e. Tap Next → Step 3;
      //    f. Tap 'From Gallery' → fake picker returns the
      //       fixture JPEG;
      //    g. Assert the thumbnail renders inline;
      //    h. Assert telemetry expense_receipt_attached fired
      //       with source: 'gallery';
      //    i. Tap 'Save Expense';
      //    j. Assert state transitions Editing → Uploading →
      //       Saving → Success.
      // 6. Await success snackbar 'Expense added.' and sheet
      //    dismissal.
      // 7. Poll Firebase Storage for the object at
      //    receipts/friendships/uid-A_uid-B/{expenseId} for ≤ 5 s
      //    until present.
      // 8. Poll Firestore for the expense doc at
      //    friendships/uid-A_uid-B/expenses/{expenseId} for ≤ 5 s
      //    until the receiptUrl field is a non-empty string
      //    matching the expected download-URL pattern.
      // 9. Confirm the onExpenseWriteFriendship trigger fired
      //    (a) the simplifiedBalances field updated to
      //    {uid-A: {uid-B: 25000}} (₹250 owed by B → A);
      //    (b) lastActivityAt advanced past the seeded value.
      // 10. Mount the ExpenseDetailScreen for the new expense;
      //    assert the receipt thumbnail Image.network widget
      //    renders the download URL.
      // 11. Tap the thumbnail; assert the
      //    ReceiptFullscreenViewer Dialog opens.
      // 12. Tear down: delete the friendship doc, the expense
      //    doc, the Storage object, and the user docs.
      //
      // Coverage closure: AC-1 through AC-12 of the FR-EX-05
      // story (Step 3 transition, picker, validation, save, edit
      // pre-fill, replace, remove, Storage rules positive paths
      // — though the rules-positive paths are also covered by
      // the dedicated functions/test/storage-rules/receipts.test.ts).
    }, skip: 'Requires emulator suite');

    test('end-to-end: user A edits an existing expense to REPLACE its '
        'receipt → the same Storage object is overwritten → the new '
        'download URL is written to receiptUrl → the friend (user B) '
        'sees the new thumbnail in real time on their device', () {
      // TODO(flutter-dev): implement once the harness is wired up.
      //
      // Steps:
      // 1. Seed the friendship + an expense WITH an existing
      //    receipt URL (uploaded via admin to bypass rules);
      // 2. Sign in as user A; open the Expense Detail screen;
      //    assert the existing thumbnail renders;
      // 3. Tap Edit; advance to Step 3 via Next x2;
      //    assert the existing thumbnail pre-fills;
      // 4. Tap Replace; fake picker returns a NEW JPEG;
      //    assert the new file replaces the existing URL in the
      //    Step 3 preview;
      // 5. Tap Save Changes;
      // 6. Poll Storage; confirm the object at the SAME path now
      //    matches the new bytes (overwrite semantics);
      // 7. Poll Firestore; confirm the receiptUrl has changed
      //    to the new download URL (the token query parameter
      //    invalidates the friend's Image.network cache);
      // 8. Sign in as user B in a separate ProviderScope; open
      //    the same Expense Detail screen; assert the new
      //    thumbnail renders within ≤ 5 s.
    }, skip: 'Requires emulator suite');

    test('end-to-end: user A edits an existing expense to REMOVE its '
        'receipt → Firestore receiptUrl flips to null → Storage object '
        'is deleted → Expense Detail no longer shows a thumbnail', () {
      // TODO(flutter-dev): implement once the harness is wired up.
      //
      // Steps:
      // 1. Seed the friendship + an expense WITH an existing
      //    receipt URL;
      // 2. Sign in as user A; open the Expense Detail screen;
      // 3. Tap Edit; advance to Step 3;
      // 4. Tap Remove on the receipt area; assert the picker UI
      //    returns to the empty state;
      // 5. Tap Save Changes;
      // 6. Poll Firestore; confirm the expense's receiptUrl is
      //    now null and changedFields included 'receiptUrl';
      // 7. Poll Storage; confirm the object at
      //    receipts/friendships/{fid}/{eid} is gone
      //    (deleteFriendshipReceipt fired);
      // 8. Reopen the Expense Detail screen; assert no
      //    thumbnail and no placeholder appears.
    }, skip: 'Requires emulator suite');
  });
}
