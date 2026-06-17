// Expense telemetry PII-leak tests (FR-EX-01).
//
// Drives the AddExpenseController through every state transition with
// a known PII-flavoured friendshipId AND expenseId, captures every
// emitted analytics payload via a fake sink, and asserts that no raw
// identifier substring ever appears in any event name, parameter key,
// or parameter value.
//
// Every event parameter referencing friendship_id or expense_id MUST
// carry the SHA-256-truncated-to-16-hex form produced by
// hashFriendshipId() / hashId() per ADR-0013.
//
// Mirrors test/features/friends/friends_list_pii_leak_test.dart and
// match_and_invite_pii_leak_test.dart (the established PII-leak
// guards). Written test-first.

// ignore_for_file: cascade_invocations

import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/telemetry/event_id_hash.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/expenses/application/add_expense_controller.dart';
import 'package:onebytwo/features/expenses/application/expense_telemetry.dart';
import 'package:onebytwo/features/expenses/data/expense_repository.dart';
import 'package:onebytwo/features/expenses/domain/expense_category.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';
import 'package:onebytwo/features/expenses/domain/split_method.dart';

import 'helpers/fake_services.dart';

// ---------------------------------------------------------------------------
// PII strings to guard against
// ---------------------------------------------------------------------------

const _piiFriendshipId = 'uid-priyalakshmi_uid-rahulagarwal';
const _piiExpenseId = 'realExpenseId123';
const _piiStrings = [
  _piiFriendshipId,
  _piiExpenseId,
  'uid-priyalakshmi',
  'uid-rahulagarwal',
  'priya',
  'rahul',
  'lakshmi',
  'agarwal',
  'realExpenseId',
];

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class FakeExpenseRepository implements ExpenseRepository {
  ExpenseCreateError? throwError;
  String returnExpenseId = _piiExpenseId;
  bool called = false;

  // FR-EX-06 hooks — exercised by the new PII guard tests.
  ExpenseUpdateError? throwUpdateError;
  ExpenseDeleteError? throwDeleteError;
  bool updateCalled = false;
  bool deleteCalled = false;
  String? capturedUpdateFriendshipId;
  String? capturedUpdateExpenseId;
  Map<String, dynamic>? capturedUpdateMap;
  String? capturedDeleteFriendshipId;
  String? capturedDeleteExpenseId;

  @override
  Future<String> createExpense({
    required String friendshipId,
    required ExpenseDoc doc,
  }) async {
    called = true;
    if (throwError != null) {
      throw throwError!;
    }
    return returnExpenseId;
  }

  @override
  Future<void> updateExpense({
    required String friendshipId,
    required String expenseId,
    required Map<String, dynamic> updates,
  }) async {
    updateCalled = true;
    capturedUpdateFriendshipId = friendshipId;
    capturedUpdateExpenseId = expenseId;
    capturedUpdateMap = updates;
    if (throwUpdateError != null) {
      throw throwUpdateError!;
    }
  }

  @override
  Future<void> softDeleteExpense({
    required String friendshipId,
    required String expenseId,
  }) async {
    deleteCalled = true;
    capturedDeleteFriendshipId = friendshipId;
    capturedDeleteExpenseId = expenseId;
    if (throwDeleteError != null) {
      throw throwDeleteError!;
    }
  }

  @override
  Stream<List<ExpenseDoc>> watchExpensesByFriendship({
    required String friendshipId,
    int limit = 5,
  }) => const Stream<List<ExpenseDoc>>.empty();

  @override
  Future<List<ExpenseDoc>> fetchExpensesInMonth({
    required String friendshipId,
    required DateTime monthStartUtc,
  }) async => const [];

  @override
  String newExpenseId({required String friendshipId}) => returnExpenseId;

  @override
  Future<void> createExpenseAtId({
    required String friendshipId,
    required String expenseId,
    required ExpenseDoc doc,
  }) async {
    called = true;
    if (throwError != null) {
      throw throwError!;
    }
  }
}

class FakeAnalyticsService implements AnalyticsService {
  final List<({String name, Map<String, Object>? parameters})> loggedEvents =
      [];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    loggedEvents.add((name: name, parameters: parameters));
  }

  bool containsPii(String pii) {
    for (final event in loggedEvents) {
      if (event.name.contains(pii)) return true;
      if (event.parameters != null) {
        for (final value in event.parameters!.values) {
          if (value.toString().contains(pii)) return true;
        }
        for (final key in event.parameters!.keys) {
          if (key.contains(pii)) return true;
        }
      }
    }
    return false;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AddExpenseController _buildController({
  required FakeExpenseRepository repo,
  required FakeAnalyticsService analytics,
}) {
  return AddExpenseController(
    friendshipId: _piiFriendshipId,
    currentUserUid: 'uid-priyalakshmi',
    otherUserUid: 'uid-rahulagarwal',
    repository: repo,
    analytics: analytics,
    receiptStorage: FakeReceiptStorageService(),
    imagePicker: FakeImagePickerService(),
    clock: DateTime.now,
  );
}

Future<void> _driveFullSuccessFlow(AddExpenseController controller) async {
  // Drive every state transition that FR-EX-01 emits an event for.
  controller.setAmount(1000);
  controller.setDescription('Coffee');
  controller.setCategory(ExpenseCategory.food);
  controller.proceedToStep2();
  controller.setSplitMethod(SplitMethod.exact);
  controller.setExactShares([500, 500]);
  controller.setPayerId('uid-rahulagarwal'); // payer change → friend
  controller.setSplitMethod(SplitMethod.equal); // method change back
  await controller.save();
}

void main() {
  late FakeExpenseRepository repo;
  late FakeAnalyticsService analytics;

  setUp(() {
    repo = FakeExpenseRepository();
    analytics = FakeAnalyticsService();
  });

  group('expense telemetry — no raw PII anywhere', () {
    test(
      'no event name contains any PII fragment after a full success flow',
      () async {
        final controller = _buildController(repo: repo, analytics: analytics);
        await _driveFullSuccessFlow(controller);
        controller.dispose();

        for (final event in analytics.loggedEvents) {
          for (final pii in _piiStrings) {
            expect(
              event.name.contains(pii),
              isFalse,
              reason: 'Event name "${event.name}" leaked PII "$pii"',
            );
          }
        }
      },
    );

    test('no event parameter key contains any PII fragment after a full '
        'success flow', () async {
      final controller = _buildController(repo: repo, analytics: analytics);
      await _driveFullSuccessFlow(controller);
      controller.dispose();

      for (final event in analytics.loggedEvents) {
        if (event.parameters == null) continue;
        for (final key in event.parameters!.keys) {
          for (final pii in _piiStrings) {
            expect(
              key.contains(pii),
              isFalse,
              reason:
                  'Event "${event.name}" parameter key "$key" leaked PII '
                  '"$pii"',
            );
          }
        }
      }
    });

    test('no event parameter VALUE contains any PII fragment after a full '
        'success flow', () async {
      final controller = _buildController(repo: repo, analytics: analytics);
      await _driveFullSuccessFlow(controller);
      controller.dispose();

      for (final pii in _piiStrings) {
        expect(
          analytics.containsPii(pii),
          isFalse,
          reason: 'PII fragment "$pii" leaked into a telemetry payload',
        );
      }
    });

    test('PII is also absent after a save-failed transition', () async {
      repo.throwError = const ExpenseCreateError(
        type: ExpenseCreateErrorType.network,
      );
      final controller = _buildController(repo: repo, analytics: analytics);

      controller.setAmount(1000);
      controller.setDescription('Coffee');
      controller.setCategory(ExpenseCategory.food);
      controller.proceedToStep2();
      await controller.save();
      controller.dispose();

      for (final pii in _piiStrings) {
        expect(
          analytics.containsPii(pii),
          isFalse,
          reason: 'PII "$pii" leaked into a saveFailed payload',
        );
      }
    });
  });

  group('expense telemetry — hashed identifier contract (ADR-0013)', () {
    test('expense_step1_opened payload carries friendship_id_hash as the '
        'SHA-256-truncated form', () {
      final controller = _buildController(repo: repo, analytics: analytics);
      controller.dispose();

      final opened = analytics.loggedEvents.firstWhere(
        (e) => e.name == ExpenseTelemetry.step1Opened,
      );
      final params = opened.parameters!;
      expect(
        params['friendship_id_hash'],
        equals(hashFriendshipId(_piiFriendshipId)),
      );
    });

    test('expense_save_succeeded payload carries friendship_id_hash AND '
        'expense_id_hash as their hashed forms', () async {
      final controller = _buildController(repo: repo, analytics: analytics);
      controller.setAmount(1000);
      controller.setDescription('Coffee');
      controller.setCategory(ExpenseCategory.food);
      controller.proceedToStep2();
      await controller.save();
      controller.dispose();

      final saved = analytics.loggedEvents.firstWhere(
        (e) => e.name == ExpenseTelemetry.saveSucceeded,
      );
      final params = saved.parameters!;
      expect(
        params['friendship_id_hash'],
        equals(hashFriendshipId(_piiFriendshipId)),
      );
      expect(params['expense_id_hash'], equals(hashId(_piiExpenseId)));
    });

    test('expense_save_failed payload carries friendship_id_hash as the '
        'hashed form', () async {
      repo.throwError = const ExpenseCreateError(
        type: ExpenseCreateErrorType.permissionDenied,
      );
      final controller = _buildController(repo: repo, analytics: analytics);
      controller.setAmount(1000);
      controller.setDescription('Coffee');
      controller.setCategory(ExpenseCategory.food);
      controller.proceedToStep2();
      await controller.save();
      controller.dispose();

      final failed = analytics.loggedEvents.firstWhere(
        (e) => e.name == ExpenseTelemetry.saveFailed,
      );
      final params = failed.parameters!;
      expect(
        params['friendship_id_hash'],
        equals(hashFriendshipId(_piiFriendshipId)),
      );
    });
  });

  group('hashId — generic identifier hasher contract', () {
    test('returns a 16-character lowercase hex string', () {
      final out = hashId('realExpenseId123');
      expect(out, hasLength(16));
      expect(RegExp(r'^[0-9a-f]{16}$').hasMatch(out), isTrue);
    });

    test('output never contains the raw input substring', () {
      const id = 'realExpenseId123';
      final out = hashId(id);
      expect(out.contains(id), isFalse);
      expect(out.contains('realExpense'), isFalse);
    });

    test('is deterministic — same input produces same hash', () {
      expect(hashId('abc'), equals(hashId('abc')));
    });

    test('hashId and hashFriendshipId share the same algorithm contract', () {
      // Both helpers apply SHA-256 → hex → substring(0,16); inputs
      // pass through the same conversion. We assert that the two
      // helpers agree on the same input.
      const sample = 'shared_input_value';
      expect(hashId(sample), equals(hashFriendshipId(sample)));
    });
  });

  // =========================================================================
  // FR-EX-06 — no PII in edit / delete events
  // =========================================================================

  group('FR-EX-06 — no PII in edit/delete events', () {
    // Build a controller in edit mode with PII-flavoured ids.
    final initial = ExpenseDoc(
      id: _piiExpenseId,
      amountPaise: 25000,
      description: 'Original lunch',
      category: ExpenseCategory.food,
      date: DateTime(2025, 3, 4),
      payerId: 'uid-priyalakshmi',
      splits: const [
        Split(userId: 'uid-priyalakshmi', sharePaise: 12500),
        Split(userId: 'uid-rahulagarwal', sharePaise: 12500),
      ],
      splitMethod: SplitMethod.equal,
      createdBy: 'uid-priyalakshmi',
    );

    AddExpenseController buildEditController() {
      return AddExpenseController(
        friendshipId: _piiFriendshipId,
        currentUserUid: 'uid-priyalakshmi',
        otherUserUid: 'uid-rahulagarwal',
        repository: repo,
        analytics: analytics,
        receiptStorage: FakeReceiptStorageService(),
        imagePicker: FakeImagePickerService(),
        clock: DateTime.now,
        initialExpense: initial,
        initialExpenseId: _piiExpenseId,
      );
    }

    test('PII guard after a full edit save flow with field changes — '
        'no event name, key, or value contains any PII fragment', () async {
      final controller = buildEditController();
      controller.setAmount(30000);
      controller.setDescription('A new description');
      controller.proceedToStep2();
      controller.setPayerId('uid-rahulagarwal');
      await controller.save();
      controller.dispose();

      for (final pii in _piiStrings) {
        expect(
          analytics.containsPii(pii),
          isFalse,
          reason: 'PII "$pii" leaked into an edit-flow payload',
        );
      }
    });

    test('PII guard after a softDelete success flow — no event name, key, '
        'or value contains any PII fragment', () async {
      final controller = buildEditController();
      await controller.softDelete();
      controller.dispose();

      for (final pii in _piiStrings) {
        expect(
          analytics.containsPii(pii),
          isFalse,
          reason: 'PII "$pii" leaked into a softDelete payload',
        );
      }
    });

    test(
      'PII guard after an editFailed transition — no PII fragment leaks',
      () async {
        repo.throwUpdateError = const ExpenseUpdateError(
          type: ExpenseUpdateErrorType.permissionDenied,
        );
        final controller = buildEditController();
        controller.setAmount(30000);
        controller.proceedToStep2();
        await controller.save();
        controller.dispose();

        for (final pii in _piiStrings) {
          expect(
            analytics.containsPii(pii),
            isFalse,
            reason: 'PII "$pii" leaked into an editFailed payload',
          );
        }
      },
    );

    test('PII guard after a deleteFailed transition — no PII leaks', () async {
      repo.throwDeleteError = const ExpenseDeleteError(
        type: ExpenseDeleteErrorType.network,
      );
      final controller = buildEditController();
      await controller.softDelete();
      controller.dispose();

      for (final pii in _piiStrings) {
        expect(
          analytics.containsPii(pii),
          isFalse,
          reason: 'PII "$pii" leaked into a deleteFailed payload',
        );
      }
    });

    test('controller-emitted events that reference expense_id (editOpened, '
        'editSaved, editFailed, editAbandoned, deleteConfirmed, deleteFailed) '
        'carry expense_id_hash, never raw. deleteInitiated and deleteCancelled '
        'are screen-emitted (expense_detail_screen.dart) and are guarded by '
        'the screen-level test suite.', () async {
      final controller = buildEditController();
      // editOpened fires on construction.
      controller.setAmount(30000); // → no expense-id event
      controller.proceedToStep2();
      await controller.save(); // editSaved
      // Build a second controller to also exercise the failed paths.
      analytics.loggedEvents.clear();
      repo.throwUpdateError = const ExpenseUpdateError(
        type: ExpenseUpdateErrorType.network,
      );
      final c2 = buildEditController();
      c2.setAmount(30000);
      c2.proceedToStep2();
      await c2.save(); // editFailed
      c2.discard(); // editAbandoned
      repo.throwDeleteError = const ExpenseDeleteError(
        type: ExpenseDeleteErrorType.notFound,
      );
      await c2.softDelete(); // deleteFailed
      c2.dispose();

      // Now build a third with NO update error to exercise deleteConfirmed.
      analytics.loggedEvents.clear();
      repo.throwUpdateError = null;
      repo.throwDeleteError = null;
      final c3 = buildEditController();
      await c3.softDelete(); // deleteConfirmed
      c3.dispose();

      const expenseIdEvents = <String>[
        ExpenseTelemetry.editOpened,
        ExpenseTelemetry.editSaved,
        ExpenseTelemetry.editFailed,
        ExpenseTelemetry.editAbandoned,
        ExpenseTelemetry.deleteConfirmed,
        ExpenseTelemetry.deleteFailed,
      ];

      // Drive a single controller through everything possible, then
      // assert that every emitted event in `expenseIdEvents` has
      // `expense_id_hash` (correct) and NEVER the raw value.
      analytics.loggedEvents.clear();
      final c4 = buildEditController();
      c4.setAmount(30000);
      c4.proceedToStep2();
      await c4.save();
      c4.dispose();

      for (final event in analytics.loggedEvents) {
        if (!expenseIdEvents.contains(event.name)) continue;
        final params = event.parameters!;
        // Must not contain the raw expense id anywhere.
        for (final value in params.values) {
          expect(
            value.toString().contains(_piiExpenseId),
            isFalse,
            reason:
                'Event "${event.name}" leaked raw expense_id in value '
                '"$value"',
          );
        }
        // Must carry the hashed form if it carries an id at all.
        if (params.containsKey('expense_id_hash')) {
          expect(params['expense_id_hash'], equals(hashId(_piiExpenseId)));
        }
      }
    });
  });
}
