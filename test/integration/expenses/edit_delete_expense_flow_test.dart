// Edit / Delete expense integration flow tests (FR-EX-06).
//
// End-to-end round-trip through the registered
// `onExpenseWriteFriendship` trigger (FR-SE-03/04) inside
// `firebase emulators:exec`.
//
// Mirrors the skipped-stub pattern from
// test/integration/expenses/expense_creation_flow_test.dart and
// test/integration/friends/friends_list_flow_test.dart — the concrete
// steps are documented for the future emulator harness; each test is
// `skip:`ped locally until the harness is reachable, but the presence
// of the test is mandatory.
//
// When run inside `firebase emulators:exec`, the harness will set
// USE_EMULATORS=true (the established convention).

@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Edit Expense integration (FR-EX-06) — round-trip via the '
      'onExpenseWriteFriendship trigger', () {
    test(
      'end-to-end: user A edits the amount of an existing ₹100 expense '
      'to ₹150 → simplifiedBalances re-recomputes to {B: {A: 7500}} → '
      'friends list re-renders "₹75.00"',
      () {
        // TODO(flutter-dev): implement once the emulator harness is
        // wired up. Mirrors the existing skipped-stub precedent.
        //
        // Steps (canonical):
        // 1. Initialise Firebase with the emulator host/port (the
        //    established convention is FIREBASE_FIRESTORE_EMULATOR_HOST
        //    and FIREBASE_AUTH_EMULATOR_HOST).
        // 2. Seed user A (authenticated as uid-A), user B (uid-B), and
        //    the friendship doc at friendships/uid-A_uid-B with
        //    memberIds == [uid-A, uid-B] and simplifiedBalances ==
        //    {uid-B: {uid-A: 5000}} (the after-state of the FR-EX-01
        //    seeding step). Seed the original ₹100 expense at
        //    friendships/uid-A_uid-B/expenses/eid-original-1 with
        //    amountPaise: 10000, equal split, payer uid-A, createdBy:
        //    uid-A.
        // 3. Mount the ExpenseDetailScreen under flutter_test with
        //    args { friendshipId, expenseId: 'eid-original-1' } using
        //    the production expenseRepositoryProvider and emulator-
        //    backed FirebaseFirestore.instance.
        // 4. Drive the UI: tap the Edit AppBar action; in the sheet
        //    bump the amount to '150'; tap Next; tap Save.
        // 5. Await success snackbar 'Changes saved.' and sheet
        //    dismissal.
        // 6. Poll friendships/uid-A_uid-B for ≤ 10 s until:
        //    a. simplifiedBalances == {uid-B: {uid-A: 7500}};
        //    b. lastActivityAt has advanced past the seeded value.
        // 7. Read via friendsListProvider for uid-A and assert the
        //    projected FriendListItem for uid-B has
        //    netBalancePaise == 7500 and that
        //    formatInrFromPaise(7500) equals '₹75.00'.
        // 8. Tear down: delete the friendship doc, the expense
        //    subcollection doc, and the seeded user docs.
        fail('Not implemented — requires emulator harness wire-up.');
      },
      skip:
          'Integration test skipped locally — run inside '
          'firebase emulators:exec with USE_EMULATORS=true.',
    );
  });

  group('Delete Expense integration (FR-EX-06) — round-trip via the '
      'onExpenseWriteFriendship trigger', () {
    test(
      'end-to-end: user A soft-deletes a ₹100 expense → '
      'simplifiedBalances re-recomputes to {} → friends list re-renders '
      '"Settled up"',
      () {
        // TODO(flutter-dev): implement once the emulator harness is
        // wired up.
        //
        // Steps (canonical):
        // 1. Initialise Firebase with the emulator host/port.
        // 2. Seed user A, user B, the friendship doc with
        //    simplifiedBalances == {uid-B: {uid-A: 5000}}, and a single
        //    ₹100 expense at friendships/uid-A_uid-B/expenses/
        //    eid-original-1 (amount 10000, equal split, payer uid-A,
        //    createdBy uid-A).
        // 3. Mount the ExpenseDetailScreen for that expense id.
        // 4. Drive the UI: tap the Delete AppBar action; in the
        //    confirmation dialog tap 'Delete'.
        // 5. Await success snackbar 'Expense deleted.' and screen
        //    pop.
        // 6. Poll friendships/uid-A_uid-B for ≤ 10 s until:
        //    a. simplifiedBalances == {} (empty);
        //    b. lastActivityAt has advanced past the seeded value;
        //    c. the expense doc has `deleted: true`.
        // 7. Read via friendsListProvider for uid-A and assert the
        //    projected FriendListItem for uid-B has balanceState ==
        //    BalanceState.settled.
        // 8. Tear down.
        fail('Not implemented — requires emulator harness wire-up.');
      },
      skip:
          'Integration test skipped locally — run inside '
          'firebase emulators:exec with USE_EMULATORS=true.',
    );
  });

  group('Edit Expense — concurrent-edit reconciliation', () {
    test(
      'two users editing the same expense both succeed (last-write-wins '
      'per architect §2.4) — no concurrentEdit error surfaced to the user',
      () {
        // TODO(flutter-dev): implement once the emulator harness is
        // wired up.
        //
        // Architect §2.4 explicitly DEFERS full transactional
        // concurrent-edit detection from v1.0. The
        // ExpenseUpdateErrorType.concurrentEdit variant is enumerated
        // for forward compatibility but is NEVER produced. This
        // integration test documents the expected last-write-wins
        // behaviour:
        //
        // 1. Seed user A + user B + friendship + a single ₹100 expense
        //    created by user A.
        // 2. Mount two ExpenseDetailScreen instances (one auth'd as
        //    A, one as B). [In a real scenario the rules would still
        //    permit B's edit per architect §2.9 item 5 — UI-gated
        //    only.]
        // 3. A edits amount → 150; B edits description → 'Updated by B'.
        //    Both Save concurrently.
        // 4. Await both success snackbars.
        // 5. The Firestore doc reflects the LATER of the two writes
        //    on every field (server timestamp ordering). No
        //    `permission-denied`, no `concurrentEdit` typed error.
        // 6. Tear down.
        fail('Not implemented — requires emulator harness wire-up.');
      },
      skip:
          'Integration test skipped locally — run inside '
          'firebase emulators:exec with USE_EMULATORS=true.',
    );
  });
}
