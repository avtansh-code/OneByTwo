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
    clock: DateTime.now,
  );
}

Future<void> _driveFullSuccessFlow(
  AddExpenseController controller,
) async {
  // Drive every state transition that PR #38 emits an event for.
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
    test('no event name contains any PII fragment after a full success flow',
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
    });

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

      final opened = analytics.loggedEvents
          .firstWhere((e) => e.name == ExpenseTelemetry.step1Opened);
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

      final saved = analytics.loggedEvents
          .firstWhere((e) => e.name == ExpenseTelemetry.saveSucceeded);
      final params = saved.parameters!;
      expect(
        params['friendship_id_hash'],
        equals(hashFriendshipId(_piiFriendshipId)),
      );
      expect(
        params['expense_id_hash'],
        equals(hashId(_piiExpenseId)),
      );
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

      final failed = analytics.loggedEvents
          .firstWhere((e) => e.name == ExpenseTelemetry.saveFailed);
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
}
