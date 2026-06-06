// Add expense controller state-machine tests (FR-EX-01).
//
// Tests `AddExpenseController` — the Riverpod 2.x StateNotifier that
// drives the two-step bottom sheet, owns telemetry emission, and is
// the sole client-side producer of expense writes via the injected
// `ExpenseRepository`.
//
// Mirrors the FakeRepository / FakeAnalyticsService pattern from
// test/features/friends/match_and_invite_controller_test.dart.
//
// These tests are written BEFORE the implementation exists (test-first).

// ignore_for_file: cascade_invocations

import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/telemetry/event_id_hash.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/expenses/application/add_expense_controller.dart';
import 'package:onebytwo/features/expenses/application/expense_telemetry.dart';
import 'package:onebytwo/features/expenses/data/expense_repository.dart';
import 'package:onebytwo/features/expenses/domain/add_expense_state.dart';
import 'package:onebytwo/features/expenses/domain/expense_category.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';
import 'package:onebytwo/features/expenses/domain/split_method.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class FakeExpenseRepository implements ExpenseRepository {
  String? capturedFriendshipId;
  ExpenseDoc? capturedDoc;
  String returnExpenseId = 'expense-id-123';
  ExpenseCreateError? throwError;
  bool called = false;

  @override
  Future<String> createExpense({
    required String friendshipId,
    required ExpenseDoc doc,
  }) async {
    called = true;
    capturedFriendshipId = friendshipId;
    capturedDoc = doc;
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

  int countOf(String name) => loggedEvents.where((e) => e.name == name).length;

  Map<String, Object>? lastParamsFor(String name) =>
      loggedEvents.lastWhere((e) => e.name == name).parameters;

  bool hasEvent(String name) => loggedEvents.any((e) => e.name == name);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _friendshipId = 'uid-current_uid-friend';
const _currentUid = 'uid-current';
const _friendUid = 'uid-friend';

AddExpenseController buildController({
  required FakeExpenseRepository repo,
  required FakeAnalyticsService analytics,
  DateTime Function()? clock,
}) {
  return AddExpenseController(
    friendshipId: _friendshipId,
    currentUserUid: _currentUid,
    otherUserUid: _friendUid,
    repository: repo,
    analytics: analytics,
    clock: clock ?? DateTime.now,
  );
}

void main() {
  late FakeExpenseRepository repo;
  late FakeAnalyticsService analytics;

  setUp(() {
    repo = FakeExpenseRepository();
    analytics = FakeAnalyticsService();
  });

  group('AddExpenseController initial state', () {
    test('starts in Editing(step: 1) with an empty draft', () {
      final controller = buildController(repo: repo, analytics: analytics);
      final state = controller.state;
      expect(state, isA<Editing>());
      expect((state as Editing).step, 1);
      expect(state.draft.amountPaise, 0);
      expect(state.draft.description, isEmpty);
      expect(state.draft.category, isNull);
      expect(state.validationErrors, isEmpty);
      controller.dispose();
    });

    test('logs expense_step1_opened on construction', () {
      buildController(repo: repo, analytics: analytics);
      expect(analytics.hasEvent(ExpenseTelemetry.step1Opened), isTrue);
      final params = analytics.lastParamsFor(ExpenseTelemetry.step1Opened)!;
      expect(params['context_type'], 'friend');
      expect(params['entry_point'], 'friend_detail');
      expect(params['friendship_id_hash'], hashFriendshipId(_friendshipId));
    });
  });

  group('AddExpenseController step 1 setters', () {
    test('setAmount updates draft.amountPaise (paise)', () {
      final controller = buildController(repo: repo, analytics: analytics);
      controller.setAmount(12345);
      expect((controller.state as Editing).draft.amountPaise, 12345);
      controller.dispose();
    });

    test('setAmount over the AC-2 cap surfaces a validation error', () {
      final controller = buildController(repo: repo, analytics: analytics);
      controller.setAmount(100000000); // 1 over the cap
      final state = controller.state as Editing;
      expect(
        state.validationErrors.containsKey('amount'),
        isTrue,
        reason: 'over-cap amount must be flagged',
      );
      controller.dispose();
    });

    test('setDescription trims and stores', () {
      final controller = buildController(repo: repo, analytics: analytics);
      controller.setDescription('   Dinner at Dosa Plaza   ');
      expect(
        (controller.state as Editing).draft.description,
        'Dinner at Dosa Plaza',
      );
      controller.dispose();
    });

    test('setDescription over 100 chars flags validation error', () {
      final controller = buildController(repo: repo, analytics: analytics);
      controller.setDescription('a' * 101);
      expect(
        (controller.state as Editing).validationErrors.containsKey(
          'description',
        ),
        isTrue,
      );
      controller.dispose();
    });

    test('setCategory updates the draft and logs '
        'expense_category_selected', () {
      final controller = buildController(repo: repo, analytics: analytics);
      controller.setCategory(ExpenseCategory.food);
      expect((controller.state as Editing).draft.category, ExpenseCategory.food);

      final categoryEvents = analytics.loggedEvents
          .where((e) => e.name == ExpenseTelemetry.categorySelected)
          .toList();
      expect(categoryEvents, isNotEmpty);
      expect(categoryEvents.last.parameters?['category'], 'food');
      controller.dispose();
    });

    test('setDate accepts today', () {
      final controller = buildController(repo: repo, analytics: analytics);
      final today = DateTime.now();
      controller.setDate(today);
      expect((controller.state as Editing).draft.date, today);
      expect(
        (controller.state as Editing).validationErrors.containsKey('date'),
        isFalse,
      );
      controller.dispose();
    });

    test('setDate in the future flags a validation error', () {
      final controller = buildController(repo: repo, analytics: analytics);
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      controller.setDate(tomorrow);
      expect(
        (controller.state as Editing).validationErrors.containsKey('date'),
        isTrue,
      );
      controller.dispose();
    });
  });

  group('AddExpenseController step transitions', () {
    test('proceedToStep2 advances when step 1 is valid', () {
      final controller = buildController(repo: repo, analytics: analytics);
      controller.setAmount(10000);
      controller.setDescription('Coffee');
      controller.setCategory(ExpenseCategory.food);
      controller.proceedToStep2();

      expect((controller.state as Editing).step, 2);
      controller.dispose();
    });

    test('proceedToStep2 is a no-op when step 1 is invalid', () {
      final controller = buildController(repo: repo, analytics: analytics);
      controller.setAmount(0); // invalid
      controller.proceedToStep2();
      expect((controller.state as Editing).step, 1);
      controller.dispose();
    });

    test('proceedToStep2 fires step1_completed and step2_opened on success',
        () {
      final controller = buildController(repo: repo, analytics: analytics);
      controller.setAmount(10000);
      controller.setDescription('Coffee');
      controller.setCategory(ExpenseCategory.food);
      controller.proceedToStep2();

      expect(analytics.hasEvent(ExpenseTelemetry.step1Completed), isTrue);
      expect(analytics.hasEvent(ExpenseTelemetry.step2Opened), isTrue);

      final completedParams =
          analytics.lastParamsFor(ExpenseTelemetry.step1Completed)!;
      expect(completedParams['amount_range'], isA<String>());
      expect(completedParams['category'], 'food');
      expect(completedParams['has_notes'], false);

      final openedParams =
          analytics.lastParamsFor(ExpenseTelemetry.step2Opened)!;
      expect(openedParams['split_method'], 'equal');
      expect(openedParams['participant_count'], 2);
      controller.dispose();
    });

    test('back from step 2 returns to step 1', () {
      final controller = buildController(repo: repo, analytics: analytics);
      controller.setAmount(10000);
      controller.setDescription('Coffee');
      controller.setCategory(ExpenseCategory.food);
      controller.proceedToStep2();
      controller.back();

      expect((controller.state as Editing).step, 1);
      controller.dispose();
    });
  });

  group('AddExpenseController step 2 setters', () {
    AddExpenseController buildOnStep2() {
      final controller = buildController(repo: repo, analytics: analytics);
      controller.setAmount(1000);
      controller.setDescription('Coffee');
      controller.setCategory(ExpenseCategory.food);
      controller.proceedToStep2();
      return controller;
    }

    test('setSplitMethod fires expense_split_method_changed', () {
      final controller = buildOnStep2();
      controller.setSplitMethod(SplitMethod.exact);

      expect(analytics.hasEvent(ExpenseTelemetry.splitMethodChanged), isTrue);
      final params =
          analytics.lastParamsFor(ExpenseTelemetry.splitMethodChanged)!;
      expect(params['from_method'], 'equal');
      expect(params['to_method'], 'exact');
      controller.dispose();
    });

    test('setSplitMethod to a disabled method is a silent no-op (no event, '
        'no state change)', () {
      final controller = buildOnStep2();
      final eventsBefore = analytics.loggedEvents.length;
      final stateBefore = controller.state;

      controller.setSplitMethod(SplitMethod.percentage);

      expect(analytics.loggedEvents.length, eventsBefore);
      expect(controller.state, stateBefore);
      controller.dispose();
    });

    test('setPayerId(currentUid) fires expense_payer_changed { payer_is_self: '
        'true } when switching from the other user', () {
      final controller = buildOnStep2();
      // First switch away from the default (self), then switch back.
      controller.setPayerId(_friendUid);
      controller.setPayerId(_currentUid);

      final payerEvents = analytics.loggedEvents
          .where((e) => e.name == ExpenseTelemetry.payerChanged)
          .toList();
      expect(payerEvents, hasLength(2));
      expect(payerEvents.first.parameters?['payer_is_self'], false);
      expect(payerEvents.last.parameters?['payer_is_self'], true);
      controller.dispose();
    });

    test('setExactShares populates draft and clears validation when sums '
        'match', () {
      final controller = buildOnStep2();
      controller.setSplitMethod(SplitMethod.exact);
      controller.setExactShares([400, 600]);

      final state = controller.state as Editing;
      expect(state.draft.exactShares, [400, 600]);
      expect(state.validationErrors.containsKey('splits'), isFalse);
      controller.dispose();
    });

    test('setExactShares mismatch (under) flags validation error and fires '
        'expense_split_validation_failed', () {
      final controller = buildOnStep2();
      controller.setSplitMethod(SplitMethod.exact);
      controller.setExactShares([300, 600]); // 900 < 1000

      final state = controller.state as Editing;
      expect(state.validationErrors.containsKey('splits'), isTrue);

      final failedEvents = analytics.loggedEvents
          .where((e) => e.name == ExpenseTelemetry.splitValidationFailed)
          .toList();
      expect(failedEvents, hasLength(1));
      expect(failedEvents.first.parameters?['split_method'], 'exact');
      expect(failedEvents.first.parameters?['direction'], 'under');
      controller.dispose();
    });

    test('setExactShares mismatch (over) flags validation error and fires '
        'expense_split_validation_failed { direction: over }', () {
      final controller = buildOnStep2();
      controller.setSplitMethod(SplitMethod.exact);
      controller.setExactShares([600, 600]); // 1200 > 1000

      final state = controller.state as Editing;
      expect(state.validationErrors.containsKey('splits'), isTrue);

      final failedEvents = analytics.loggedEvents
          .where((e) => e.name == ExpenseTelemetry.splitValidationFailed)
          .toList();
      expect(failedEvents.last.parameters?['direction'], 'over');
      controller.dispose();
    });
  });

  group('AddExpenseController.save — success path', () {
    Future<AddExpenseController> arrangeValidStep2() async {
      final controller = buildController(repo: repo, analytics: analytics);
      controller.setAmount(10000);
      controller.setDescription('Dinner');
      controller.setCategory(ExpenseCategory.food);
      controller.proceedToStep2();
      return controller;
    }

    test('transitions Editing → Saving → Success', () async {
      final controller = await arrangeValidStep2();

      final saveFuture = controller.save();
      // We capture the transient Saving state by reading immediately.
      expect(controller.state, isA<Saving>());

      await saveFuture;
      expect(controller.state, isA<Success>());
      expect((controller.state as Success).expenseId, 'expense-id-123');
      controller.dispose();
    });

    test('writes via the repository with the captured friendshipId', () async {
      final controller = await arrangeValidStep2();
      await controller.save();

      expect(repo.called, isTrue);
      expect(repo.capturedFriendshipId, _friendshipId);
      controller.dispose();
    });

    test('fires expense_step2_completed before save and '
        'expense_save_succeeded on success', () async {
      final controller = await arrangeValidStep2();
      await controller.save();

      expect(analytics.hasEvent(ExpenseTelemetry.step2Completed), isTrue);
      expect(analytics.hasEvent(ExpenseTelemetry.saveSucceeded), isTrue);

      final saveParams =
          analytics.lastParamsFor(ExpenseTelemetry.saveSucceeded)!;
      expect(saveParams['context_type'], 'friend');
      expect(saveParams['amount_range'], isA<String>());
      expect(saveParams['category'], 'food');
      expect(saveParams['split_method'], 'equal');
      expect(saveParams['participant_count'], 2);
      expect(saveParams['has_receipt'], false);
      expect(saveParams['has_notes'], false);
      expect(saveParams['friendship_id_hash'], hashFriendshipId(_friendshipId));
      expect(saveParams['expense_id_hash'], isNotNull);
      controller.dispose();
    });
  });

  group('AddExpenseController.save — failure path', () {
    Future<AddExpenseController> arrangeValidStep2() async {
      final controller = buildController(repo: repo, analytics: analytics);
      controller.setAmount(10000);
      controller.setDescription('Dinner');
      controller.setCategory(ExpenseCategory.food);
      controller.proceedToStep2();
      return controller;
    }

    test('permission-denied error transitions to Error state with '
        'permissionDenied type', () async {
      repo.throwError = const ExpenseCreateError(
        type: ExpenseCreateErrorType.permissionDenied,
      );
      final controller = await arrangeValidStep2();
      await controller.save();

      expect(controller.state, isA<AddExpenseError>());
      final err = controller.state as AddExpenseError;
      expect(err.errorType, ExpenseCreateErrorType.permissionDenied);
      controller.dispose();
    });

    test('network error transitions to Error state with network type', () async {
      repo.throwError = const ExpenseCreateError(
        type: ExpenseCreateErrorType.network,
      );
      final controller = await arrangeValidStep2();
      await controller.save();

      expect(controller.state, isA<AddExpenseError>());
      expect(
        (controller.state as AddExpenseError).errorType,
        ExpenseCreateErrorType.network,
      );
      controller.dispose();
    });

    test('fires expense_save_failed with hashed friendship_id_hash', () async {
      repo.throwError = const ExpenseCreateError(
        type: ExpenseCreateErrorType.network,
      );
      final controller = await arrangeValidStep2();
      await controller.save();

      expect(analytics.hasEvent(ExpenseTelemetry.saveFailed), isTrue);
      final params = analytics.lastParamsFor(ExpenseTelemetry.saveFailed)!;
      expect(params['error_type'], 'network');
      expect(params['friendship_id_hash'], hashFriendshipId(_friendshipId));
      controller.dispose();
    });

    test('after a failed save, retrying transitions to Success when the '
        'repository succeeds', () async {
      repo.throwError = const ExpenseCreateError(
        type: ExpenseCreateErrorType.network,
      );
      final controller = await arrangeValidStep2();
      await controller.save();
      expect(controller.state, isA<AddExpenseError>());

      // Clear the error and retry.
      repo.throwError = null;
      await controller.save();
      expect(controller.state, isA<Success>());
      controller.dispose();
    });
  });

  group('AddExpenseController.discard', () {
    test('discard on an empty step 1 emits no abandonment event', () {
      final controller = buildController(repo: repo, analytics: analytics);
      controller.discard();
      expect(analytics.hasEvent(ExpenseTelemetry.step1Abandoned), isFalse);
      controller.dispose();
    });

    test('discard on step 1 with data fires expense_step1_abandoned', () {
      final controller = buildController(repo: repo, analytics: analytics);
      controller.setAmount(10000);
      controller.setDescription('partial');
      controller.discard();

      expect(analytics.hasEvent(ExpenseTelemetry.step1Abandoned), isTrue);
      final params = analytics.lastParamsFor(ExpenseTelemetry.step1Abandoned)!;
      expect(params['fields_filled_count'], isA<int>());
      expect(params['time_spent_ms'], isA<int>());
    });

    test('discard on step 2 fires expense_step2_abandoned', () {
      final controller = buildController(repo: repo, analytics: analytics);
      controller.setAmount(10000);
      controller.setDescription('partial');
      controller.setCategory(ExpenseCategory.food);
      controller.proceedToStep2();
      controller.discard();

      expect(analytics.hasEvent(ExpenseTelemetry.step2Abandoned), isTrue);
      final params = analytics.lastParamsFor(ExpenseTelemetry.step2Abandoned)!;
      expect(params['split_method'], 'equal');
      expect(params['time_spent_ms'], isA<int>());
    });
  });

  group('AddExpenseController telemetry PII contract', () {
    test('no event ever carries the raw friendshipId as a parameter value', () {
      final controller = buildController(repo: repo, analytics: analytics);
      controller.setAmount(10000);
      controller.setDescription('Dinner');
      controller.setCategory(ExpenseCategory.food);
      controller.proceedToStep2();

      for (final event in analytics.loggedEvents) {
        if (event.parameters == null) continue;
        for (final value in event.parameters!.values) {
          expect(
            value.toString().contains(_friendshipId),
            isFalse,
            reason: 'Event "${event.name}" leaked raw friendshipId',
          );
        }
      }
      controller.dispose();
    });
  });
}
