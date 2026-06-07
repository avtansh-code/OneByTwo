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

import 'package:flutter/foundation.dart';
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
  Exception? throwUnknown;
  bool called = false;

  // FR-EX-06 hooks — populated by the edit-mode test groups.
  String? updatedFriendshipId;
  String? updatedExpenseId;
  Map<String, dynamic>? updatedMap;
  ExpenseUpdateError? throwUpdateError;
  bool updateCalled = false;

  String? deletedFriendshipId;
  String? deletedExpenseId;
  ExpenseDeleteError? throwDeleteError;
  bool deleteCalled = false;

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
    if (throwUnknown != null) {
      throw throwUnknown!;
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
    updatedFriendshipId = friendshipId;
    updatedExpenseId = expenseId;
    updatedMap = updates;
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
    deletedFriendshipId = friendshipId;
    deletedExpenseId = expenseId;
    if (throwDeleteError != null) {
      throw throwDeleteError!;
    }
  }

  @override
  Stream<List<ExpenseDoc>> watchExpensesByFriendship({
    required String friendshipId,
    int limit = 5,
  }) => const Stream<List<ExpenseDoc>>.empty();
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
      controller.setAmount(1000000000); // 1 over the cap (999,999,999)
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
      expect(
        (controller.state as Editing).draft.category,
        ExpenseCategory.food,
      );

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

    test(
      'proceedToStep2 fires step1_completed and step2_opened on success',
      () {
        final controller = buildController(repo: repo, analytics: analytics);
        controller.setAmount(10000);
        controller.setDescription('Coffee');
        controller.setCategory(ExpenseCategory.food);
        controller.proceedToStep2();

        expect(analytics.hasEvent(ExpenseTelemetry.step1Completed), isTrue);
        expect(analytics.hasEvent(ExpenseTelemetry.step2Opened), isTrue);

        final completedParams = analytics.lastParamsFor(
          ExpenseTelemetry.step1Completed,
        )!;
        expect(completedParams['amount_range'], isA<String>());
        expect(completedParams['category'], 'food');
        expect(completedParams['has_notes'], false);

        final openedParams = analytics.lastParamsFor(
          ExpenseTelemetry.step2Opened,
        )!;
        expect(openedParams['split_method'], 'equal');
        expect(openedParams['participant_count'], 2);
        controller.dispose();
      },
    );

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
      final params = analytics.lastParamsFor(
        ExpenseTelemetry.splitMethodChanged,
      )!;
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

      final saveParams = analytics.lastParamsFor(
        ExpenseTelemetry.saveSucceeded,
      )!;
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

    test(
      'network error transitions to Error state with network type',
      () async {
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
      },
    );

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

    test('unexpected (non-ExpenseCreateError) exception transitions to '
        'AddExpenseError with unknown type, fires expense_save_failed with '
        'error_type=unknown, and reports to FlutterError.onError WITHOUT '
        'rethrowing (so VoidCallback save() callers do not produce an '
        'unhandled async error)', () async {
      repo.throwUnknown = const FormatException('unexpected ExpenseStore boom');
      final controller = await arrangeValidStep2();

      final captured = <FlutterErrorDetails>[];
      final previousOnError = FlutterError.onError;
      FlutterError.onError = captured.add;
      try {
        await expectLater(controller.save(), completes);
      } finally {
        FlutterError.onError = previousOnError;
      }

      expect(controller.state, isA<AddExpenseError>());
      expect(
        (controller.state as AddExpenseError).errorType,
        ExpenseCreateErrorType.unknown,
      );
      final params = analytics.lastParamsFor(ExpenseTelemetry.saveFailed)!;
      expect(params['error_type'], 'unknown');
      expect(captured, hasLength(1));
      expect(captured.single.exception, isA<FormatException>());
      expect(captured.single.library, 'expenses');
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

  // ===========================================================================
  // FR-EX-06 — Edit mode
  // ===========================================================================

  group('AddExpenseController — edit mode', () {
    const initialId = 'expense-id-edit-7';
    final initial = ExpenseDoc(
      id: initialId,
      amountPaise: 50000, // ₹500
      description: 'Original dinner',
      category: ExpenseCategory.food,
      date: DateTime(2025, 1, 15, 12, 30),
      payerId: _currentUid,
      splits: const [
        Split(userId: _currentUid, sharePaise: 25000),
        Split(userId: _friendUid, sharePaise: 25000),
      ],
      splitMethod: SplitMethod.equal,
      createdBy: _currentUid,
    );

    AddExpenseController buildEditController({DateTime Function()? clock}) {
      return AddExpenseController(
        friendshipId: _friendshipId,
        currentUserUid: _currentUid,
        otherUserUid: _friendUid,
        repository: repo,
        analytics: analytics,
        clock: clock ?? () => DateTime(2025, 6, 1, 10),
        initialExpense: initial,
        initialExpenseId: initialId,
      );
    }

    test('isEditMode is true when initialExpense is provided', () {
      final controller = buildEditController();
      expect(controller.isEditMode, isTrue);
      controller.dispose();
    });

    test('constructor pre-fills the draft from initialExpense', () {
      final controller = buildEditController();
      final state = controller.state as Editing;
      expect(state.step, 1);
      expect(state.draft.amountPaise, 50000);
      expect(state.draft.description, 'Original dinner');
      expect(state.draft.category, ExpenseCategory.food);
      expect(state.draft.date, DateTime(2025, 1, 15, 12, 30));
      expect(state.draft.splitMethod, SplitMethod.equal);
      expect(state.draft.payerId, _currentUid);
      controller.dispose();
    });

    test('constructor in edit mode fires expense_edit_opened with hashed '
        'friendship_id_hash and expense_id_hash', () {
      buildEditController();
      expect(analytics.hasEvent(ExpenseTelemetry.editOpened), isTrue);
      final params = analytics.lastParamsFor(ExpenseTelemetry.editOpened)!;
      expect(params[ExpenseTelemetry.paramContextType], 'friend');
      expect(
        params[ExpenseTelemetry.paramFriendshipIdHash],
        hashFriendshipId(_friendshipId),
      );
      expect(params[ExpenseTelemetry.paramExpenseIdHash], hashId(initialId));
      // No raw IDs leaked
      expect(
        params.values.any((v) => v.toString().contains(_friendshipId)),
        isFalse,
      );
      expect(
        params.values.any((v) => v.toString().contains(initialId)),
        isFalse,
      );
    });

    test('constructor in edit mode does NOT fire expense_step1_opened', () {
      buildEditController();
      expect(analytics.hasEvent(ExpenseTelemetry.step1Opened), isFalse);
    });

    test('changedFields starts empty in edit mode', () {
      final controller = buildEditController();
      expect(controller.changedFields, isEmpty);
      controller.dispose();
    });

    test(
      'isFieldChanged(field) returns false in create mode for every field',
      () {
        final controller = buildController(repo: repo, analytics: analytics);
        for (final f in const <String>[
          ExpenseDoc.fieldAmountPaise,
          ExpenseDoc.fieldDescription,
          ExpenseDoc.fieldCategory,
          ExpenseDoc.fieldDate,
          ExpenseDoc.fieldPayerId,
          ExpenseDoc.fieldSplits,
          ExpenseDoc.fieldSplitMethod,
        ]) {
          expect(
            controller.isFieldChanged(f),
            isFalse,
            reason: 'create mode must report no field as changed for $f',
          );
        }
        controller.dispose();
      },
    );

    test('isFieldChanged(field) tracks changedFields in edit mode '
        '(AC-4 helper for the changed-field indicator)', () {
      final controller = buildEditController();
      expect(controller.isFieldChanged(ExpenseDoc.fieldAmountPaise), isFalse);
      controller.setAmount(60000);
      expect(controller.isFieldChanged(ExpenseDoc.fieldAmountPaise), isTrue);
      // Other fields stay unchanged.
      expect(controller.isFieldChanged(ExpenseDoc.fieldDescription), isFalse);
      // Flipping back removes it.
      controller.setAmount(50000);
      expect(controller.isFieldChanged(ExpenseDoc.fieldAmountPaise), isFalse);
      controller.dispose();
    });

    test('setAmount with the original value does NOT add amountPaise to '
        'changedFields and does NOT fire expense_edit_field_changed', () {
      final controller = buildEditController();
      analytics.loggedEvents.clear();
      controller.setAmount(50000); // same as original
      expect(controller.changedFields, isEmpty);
      expect(analytics.hasEvent(ExpenseTelemetry.editFieldChanged), isFalse);
      controller.dispose();
    });

    test('setAmount with a different value adds amountPaise to changedFields '
        'and fires expense_edit_field_changed once', () {
      final controller = buildEditController();
      analytics.loggedEvents.clear();
      controller.setAmount(60000); // different
      expect(controller.changedFields, contains(ExpenseDoc.fieldAmountPaise));
      expect(analytics.countOf(ExpenseTelemetry.editFieldChanged), 1);
      final params = analytics.lastParamsFor(
        ExpenseTelemetry.editFieldChanged,
      )!;
      expect(
        params[ExpenseTelemetry.paramFieldName],
        ExpenseDoc.fieldAmountPaise,
      );
      // Updating again to a different new value does NOT re-emit.
      controller.setAmount(70000);
      expect(analytics.countOf(ExpenseTelemetry.editFieldChanged), 1);
      controller.dispose();
    });

    test('flipping a field back to its original value removes it from '
        'changedFields (and does NOT emit a second editFieldChanged)', () {
      final controller = buildEditController();
      controller.setAmount(60000);
      expect(controller.changedFields, contains(ExpenseDoc.fieldAmountPaise));
      analytics.loggedEvents.clear();
      controller.setAmount(50000); // back to original
      expect(controller.changedFields, isEmpty);
      expect(analytics.hasEvent(ExpenseTelemetry.editFieldChanged), isFalse);
      controller.dispose();
    });

    test('setDate with same Y/M/D (different time) is NOT a change '
        '(date-only equality)', () {
      final controller = buildEditController();
      analytics.loggedEvents.clear();
      // Same calendar date but earlier time-of-day.
      controller.setDate(DateTime(2025, 1, 15));
      expect(controller.changedFields, isEmpty);
      expect(analytics.hasEvent(ExpenseTelemetry.editFieldChanged), isFalse);
      controller.dispose();
    });

    test('setDate with a different day adds date to changedFields', () {
      final controller = buildEditController();
      analytics.loggedEvents.clear();
      controller.setDate(DateTime(2025, 1, 16)); // next day
      expect(controller.changedFields, contains(ExpenseDoc.fieldDate));
      expect(analytics.countOf(ExpenseTelemetry.editFieldChanged), 1);
      controller.dispose();
    });

    test('setCategory to a different value adds category to changedFields', () {
      final controller = buildEditController();
      analytics.loggedEvents.clear();
      controller.setCategory(ExpenseCategory.travel);
      expect(controller.changedFields, contains(ExpenseDoc.fieldCategory));
      controller.dispose();
    });

    test('setDescription to a different trimmed value tracks the change', () {
      final controller = buildEditController();
      analytics.loggedEvents.clear();
      controller.setDescription('A totally different meal');
      expect(controller.changedFields, contains(ExpenseDoc.fieldDescription));
      controller.dispose();
    });

    test('setPayerId to the other user adds payerId to changedFields '
        '(after advancing to step 2)', () {
      final controller = buildEditController();
      controller.proceedToStep2();
      analytics.loggedEvents.clear();
      controller.setPayerId(_friendUid);
      expect(controller.changedFields, contains(ExpenseDoc.fieldPayerId));
      controller.dispose();
    });

    test(
      'no-op guard: save() is a silent no-op when changedFields is empty',
      () async {
        final controller = buildEditController();
        controller.proceedToStep2();
        await controller.save();
        expect(repo.updateCalled, isFalse);
        expect(controller.state, isA<Editing>());
        controller.dispose();
      },
    );

    test('save() in edit mode calls ExpenseRepository.updateExpense with the '
        'partial map shaped from changedFields', () async {
      final controller = buildEditController();
      controller.setAmount(60000);
      controller.proceedToStep2();
      await controller.save();
      expect(repo.updateCalled, isTrue);
      expect(repo.updatedFriendshipId, _friendshipId);
      expect(repo.updatedExpenseId, initialId);
      // Only changed keys + updatedAt should be present.
      final map = repo.updatedMap!;
      expect(map.keys, containsAll([ExpenseDoc.fieldAmountPaise, 'updatedAt']));
      // createdBy / createdAt are immutable per the rules; they must
      // NEVER appear in the update map even if (hypothetically) added
      // to changedFields.
      expect(map.containsKey('createdBy'), isFalse);
      expect(map.containsKey('createdAt'), isFalse);
      expect(map[ExpenseDoc.fieldAmountPaise], 60000);
      controller.dispose();
    });

    test('save() in edit mode transitions to Success(action: editSaved) with '
        'the original expense id on the happy path', () async {
      final controller = buildEditController();
      controller.setAmount(60000);
      controller.proceedToStep2();
      await controller.save();
      final s = controller.state;
      expect(s, isA<Success>());
      expect((s as Success).expenseId, initialId);
      expect(s.action, SuccessAction.editSaved);
      controller.dispose();
    });

    test('save() in edit mode fires expense_edit_saved with fields_changed '
        'and hashed IDs', () async {
      final controller = buildEditController();
      controller.setAmount(60000);
      controller.setDescription('Lunch upgrade');
      controller.proceedToStep2();
      await controller.save();
      expect(analytics.hasEvent(ExpenseTelemetry.editSaved), isTrue);
      final params = analytics.lastParamsFor(ExpenseTelemetry.editSaved)!;
      expect(params[ExpenseTelemetry.paramFieldsChanged], isA<String>());
      // Stable sort makes assertion deterministic.
      final fields = (params[ExpenseTelemetry.paramFieldsChanged]! as String)
          .split(',');
      expect(
        fields,
        containsAll([ExpenseDoc.fieldAmountPaise, ExpenseDoc.fieldDescription]),
      );
      expect(
        params[ExpenseTelemetry.paramFriendshipIdHash],
        hashFriendshipId(_friendshipId),
      );
      expect(params[ExpenseTelemetry.paramExpenseIdHash], hashId(initialId));
      controller.dispose();
    });

    test('save() in edit mode failure fires expense_edit_failed and '
        'transitions to AddExpenseError', () async {
      repo.throwUpdateError = const ExpenseUpdateError(
        type: ExpenseUpdateErrorType.network,
      );
      final controller = buildEditController();
      controller.setAmount(60000);
      controller.proceedToStep2();
      await controller.save();
      final s = controller.state;
      expect(s, isA<AddExpenseError>());
      expect(analytics.hasEvent(ExpenseTelemetry.editFailed), isTrue);
      final params = analytics.lastParamsFor(ExpenseTelemetry.editFailed)!;
      expect(params[ExpenseTelemetry.paramErrorCode], 'network');
      controller.dispose();
    });

    test('discard() in edit mode fires expense_edit_abandoned with '
        'had_changes:true and a non-negative time_spent_ms', () {
      final clockTimes = <DateTime>[
        DateTime(2025, 6, 1, 10),
        DateTime(2025, 6, 1, 10, 0, 5), // 5 s later, used by discard()
      ];
      var i = 0;
      DateTime clock() {
        final idx = i.clamp(0, clockTimes.length - 1);
        i++;
        return clockTimes[idx];
      }

      final controller = buildEditController(clock: clock);
      controller.setAmount(60000);
      analytics.loggedEvents.clear();
      controller.discard();
      expect(analytics.hasEvent(ExpenseTelemetry.editAbandoned), isTrue);
      final params = analytics.lastParamsFor(ExpenseTelemetry.editAbandoned)!;
      expect(params[ExpenseTelemetry.paramHadChanges], isTrue);
      expect(params[ExpenseTelemetry.paramTimeSpentMs], isA<int>());
      expect(
        params[ExpenseTelemetry.paramFriendshipIdHash],
        hashFriendshipId(_friendshipId),
      );
      expect(params[ExpenseTelemetry.paramExpenseIdHash], hashId(initialId));
      controller.dispose();
    });

    test('discard() in edit mode fires expense_edit_abandoned with '
        'had_changes:false when no fields were changed', () {
      final controller = buildEditController();
      analytics.loggedEvents.clear();
      controller.discard();
      expect(analytics.hasEvent(ExpenseTelemetry.editAbandoned), isTrue);
      final params = analytics.lastParamsFor(ExpenseTelemetry.editAbandoned)!;
      expect(params[ExpenseTelemetry.paramHadChanges], isFalse);
      controller.dispose();
    });

    test('discard() in edit mode does NOT fire expense_step1_abandoned or '
        'expense_step2_abandoned', () {
      final controller = buildEditController();
      controller.setAmount(60000);
      controller.proceedToStep2();
      analytics.loggedEvents.clear();
      controller.discard();
      expect(analytics.hasEvent(ExpenseTelemetry.step1Abandoned), isFalse);
      expect(analytics.hasEvent(ExpenseTelemetry.step2Abandoned), isFalse);
      controller.dispose();
    });

    test('softDelete() calls ExpenseRepository.softDeleteExpense and '
        'transitions to Success(action: deleted)', () async {
      final controller = buildEditController();
      await controller.softDelete();
      expect(repo.deleteCalled, isTrue);
      expect(repo.deletedFriendshipId, _friendshipId);
      expect(repo.deletedExpenseId, initialId);
      final s = controller.state;
      expect(s, isA<Success>());
      expect((s as Success).action, SuccessAction.deleted);
      expect(s.expenseId, initialId);
      controller.dispose();
    });

    test('softDelete() fires expense_delete_confirmed with amount_paise '
        'and participant_count on success', () async {
      final controller = buildEditController();
      await controller.softDelete();
      expect(analytics.hasEvent(ExpenseTelemetry.deleteConfirmed), isTrue);
      final params = analytics.lastParamsFor(ExpenseTelemetry.deleteConfirmed)!;
      expect(params[ExpenseTelemetry.paramAmountPaise], 50000);
      expect(params[ExpenseTelemetry.paramParticipantCount], 2);
      expect(params[ExpenseTelemetry.paramExpenseIdHash], hashId(initialId));
      controller.dispose();
    });

    test('softDelete() failure fires expense_delete_failed and transitions '
        'to AddExpenseError', () async {
      repo.throwDeleteError = const ExpenseDeleteError(
        type: ExpenseDeleteErrorType.permissionDenied,
      );
      final controller = buildEditController();
      await controller.softDelete();
      final s = controller.state;
      expect(s, isA<AddExpenseError>());
      expect(analytics.hasEvent(ExpenseTelemetry.deleteFailed), isTrue);
      final params = analytics.lastParamsFor(ExpenseTelemetry.deleteFailed)!;
      expect(params[ExpenseTelemetry.paramErrorCode], 'permissionDenied');
      controller.dispose();
    });

    test(
      'softDelete() is a no-op in create mode (no initialExpenseId)',
      () async {
        final controller = buildController(repo: repo, analytics: analytics);
        await controller.softDelete();
        expect(repo.deleteCalled, isFalse);
        controller.dispose();
      },
    );
  });
}
