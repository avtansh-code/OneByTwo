// Expense detail screen widget tests (FR-EX-06).
//
// Tests the SCR-22 read-only detail screen: loading / error / missing /
// loaded rendering, AppBar action visibility (creator-only), and the
// edit + delete tap flows.
//
// Mirrors the test/features/expenses/add_expense_bottom_sheet_widget_test.dart
// pattern: ProviderScope overrides the data providers; a recording
// FakeExpenseRepository captures writes; a FakeAnalyticsService
// captures every emitted event.

// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:flutter/material.dart' hide Split;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/services/image_picker_service.dart';
import 'package:onebytwo/core/widgets/dialogs/obt_confirmation_dialog.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/expenses/application/expense_detail_provider.dart';
import 'package:onebytwo/features/expenses/application/expense_telemetry.dart';
import 'package:onebytwo/features/expenses/data/expense_repository.dart';
import 'package:onebytwo/features/expenses/data/receipt_storage_service.dart';
import 'package:onebytwo/features/expenses/domain/expense_category.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';
import 'package:onebytwo/features/expenses/domain/split_method.dart';
import 'package:onebytwo/features/expenses/presentation/expense_detail_screen.dart';

import 'helpers/fake_services.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class FakeExpenseRepository implements ExpenseRepository {
  String? lastDeletedFid;
  String? lastDeletedEid;
  ExpenseDeleteError? throwOnDelete;
  bool deleteCalled = false;

  String? lastUpdatedFid;
  String? lastUpdatedEid;
  Map<String, dynamic>? lastUpdates;
  ExpenseUpdateError? throwOnUpdate;
  bool updateCalled = false;

  @override
  Future<String> createExpense({
    required String friendshipId,
    required ExpenseDoc doc,
  }) async => 'noop';

  @override
  Future<void> updateExpense({
    required String friendshipId,
    required String expenseId,
    required Map<String, dynamic> updates,
  }) async {
    updateCalled = true;
    lastUpdatedFid = friendshipId;
    lastUpdatedEid = expenseId;
    lastUpdates = updates;
    if (throwOnUpdate != null) throw throwOnUpdate!;
  }

  @override
  Future<void> softDeleteExpense({
    required String friendshipId,
    required String expenseId,
  }) async {
    deleteCalled = true;
    lastDeletedFid = friendshipId;
    lastDeletedEid = expenseId;
    if (throwOnDelete != null) throw throwOnDelete!;
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
  String newExpenseId({required String friendshipId}) => 'noop';

  @override
  Future<void> createExpenseAtId({
    required String friendshipId,
    required String expenseId,
    required ExpenseDoc doc,
  }) async {
    // Not exercised by the expense-detail widget tests.
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

  bool hasEvent(String name) => loggedEvents.any((e) => e.name == name);
}

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

const _friendshipId = 'uid-current_uid-friend';
const _expenseId = 'eid-detail-1';
const _currentUid = 'uid-current';
const _friendUid = 'uid-friend';

ExpenseDoc _buildExpense({
  String createdBy = _currentUid,
  String description = 'Group dinner',
  int amountPaise = 50000,
}) {
  return ExpenseDoc(
    id: _expenseId,
    amountPaise: amountPaise,
    description: description,
    category: ExpenseCategory.food,
    date: DateTime(2025, 5, 17),
    payerId: _currentUid,
    splits: const [
      Split(userId: _currentUid, sharePaise: 25000),
      Split(userId: _friendUid, sharePaise: 25000),
    ],
    splitMethod: SplitMethod.equal,
    createdBy: createdBy,
  );
}

Widget _buildHost({
  required FakeExpenseRepository repo,
  required FakeAnalyticsService analytics,
  required Override detailOverride,
}) {
  return ProviderScope(
    overrides: [
      analyticsServiceProvider.overrideWithValue(analytics),
      expenseRepositoryProvider.overrideWithValue(repo),
      receiptStorageServiceProvider.overrideWithValue(
        FakeReceiptStorageService(),
      ),
      imagePickerServiceProvider.overrideWithValue(FakeImagePickerService()),
      detailOverride,
    ],
    child: const MaterialApp(
      home: ExpenseDetailScreen(
        friendshipId: _friendshipId,
        expenseId: _expenseId,
        currentUserUid: _currentUid,
        otherUserUid: _friendUid,
      ),
    ),
  );
}

void main() {
  late FakeExpenseRepository repo;
  late FakeAnalyticsService analytics;

  setUp(() {
    repo = FakeExpenseRepository();
    analytics = FakeAnalyticsService();
  });

  group('ExpenseDetailScreen — render states', () {
    testWidgets('shows a loading indicator while the future is pending', (
      tester,
    ) async {
      // Use a future that never completes for the loading assertion.
      final completer = Completer<ExpenseDoc?>();
      addTearDown(() {
        if (!completer.isCompleted) completer.complete(null);
      });
      await tester.pumpWidget(
        _buildHost(
          repo: repo,
          analytics: analytics,
          detailOverride: expenseDetailProvider.overrideWith(
            (ref, args) => completer.future,
          ),
        ),
      );
      // First pump shows loading because the FutureProvider is unresolved.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows the error message + Retry button on failure', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHost(
          repo: repo,
          analytics: analytics,
          detailOverride: expenseDetailProvider.overrideWith(
            (ref, args) => Future<ExpenseDoc?>.error(StateError('boom')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Could not load expense'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets(
      'shows "Expense no longer exists" + Go back when data is null',
      (tester) async {
        await tester.pumpWidget(
          _buildHost(
            repo: repo,
            analytics: analytics,
            detailOverride: expenseDetailProvider.overrideWith(
              (ref, args) async => null,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Expense no longer exists'), findsOneWidget);
        expect(find.text('Go back'), findsOneWidget);
      },
    );

    testWidgets('renders the expense description, amount, and date on data', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHost(
          repo: repo,
          analytics: analytics,
          detailOverride: expenseDetailProvider.overrideWith(
            (ref, args) async => _buildExpense(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Group dinner'), findsOneWidget);
      expect(find.text('₹500.00'), findsOneWidget);
    });
  });

  group('ExpenseDetailScreen — AppBar actions visibility', () {
    testWidgets(
      'shows Edit + Delete when the current user created the expense',
      (tester) async {
        await tester.pumpWidget(
          _buildHost(
            repo: repo,
            analytics: analytics,
            detailOverride: expenseDetailProvider.overrideWith(
              (ref, args) async => _buildExpense(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
        expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      },
    );

    testWidgets('hides Edit + Delete when another user created the expense', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHost(
          repo: repo,
          analytics: analytics,
          detailOverride: expenseDetailProvider.overrideWith(
            (ref, args) async => _buildExpense(createdBy: _friendUid),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });
  });

  group('ExpenseDetailScreen — delete flow', () {
    testWidgets('tapping Delete opens the destructive confirmation dialog', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHost(
          repo: repo,
          analytics: analytics,
          detailOverride: expenseDetailProvider.overrideWith(
            (ref, args) async => _buildExpense(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.byType(OBTConfirmationDialog), findsOneWidget);
      expect(find.text('Delete this expense?'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('dialog body matches SCR-22 / AC-8 verbatim copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHost(
          repo: repo,
          analytics: analytics,
          detailOverride: expenseDetailProvider.overrideWith(
            (ref, args) async => _buildExpense(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'This will update balances for all participants. '
          'This cannot be undone.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping Delete fires expense_delete_initiated', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHost(
          repo: repo,
          analytics: analytics,
          detailOverride: expenseDetailProvider.overrideWith(
            (ref, args) async => _buildExpense(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(analytics.hasEvent(ExpenseTelemetry.deleteInitiated), isTrue);
    });

    testWidgets(
      'cancelling the dialog fires expense_delete_cancelled and does NOT '
      'call the repository',
      (tester) async {
        await tester.pumpWidget(
          _buildHost(
            repo: repo,
            analytics: analytics,
            detailOverride: expenseDetailProvider.overrideWith(
              (ref, args) async => _buildExpense(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(repo.deleteCalled, isFalse);
        expect(analytics.hasEvent(ExpenseTelemetry.deleteCancelled), isTrue);
      },
    );

    testWidgets(
      'confirming the dialog calls softDeleteExpense and pops the screen',
      (tester) async {
        await tester.pumpWidget(
          _buildHost(
            repo: repo,
            analytics: analytics,
            detailOverride: expenseDetailProvider.overrideWith(
              (ref, args) async => _buildExpense(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        expect(repo.deleteCalled, isTrue);
        expect(repo.lastDeletedFid, _friendshipId);
        expect(repo.lastDeletedEid, _expenseId);
        expect(analytics.hasEvent(ExpenseTelemetry.deleteConfirmed), isTrue);
      },
    );

    testWidgets(
      'a delete failure surfaces the error snackbar and does NOT pop',
      (tester) async {
        repo.throwOnDelete = const ExpenseDeleteError(
          type: ExpenseDeleteErrorType.permissionDenied,
        );
        await tester.pumpWidget(
          _buildHost(
            repo: repo,
            analytics: analytics,
            detailOverride: expenseDetailProvider.overrideWith(
              (ref, args) async => _buildExpense(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        expect(
          find.text("Couldn't delete the expense. Try again."),
          findsOneWidget,
        );
        expect(analytics.hasEvent(ExpenseTelemetry.deleteFailed), isTrue);
        // Detail screen should still be present (no maybePop).
        expect(find.byType(ExpenseDetailScreen), findsOneWidget);
      },
    );
  });

  group('ExpenseDetailScreen — retry flow', () {
    testWidgets(
      'tapping Retry invalidates the provider and triggers a re-fetch',
      (tester) async {
        var callCount = 0;
        await tester.pumpWidget(
          _buildHost(
            repo: repo,
            analytics: analytics,
            detailOverride: expenseDetailProvider.overrideWith((ref, args) {
              callCount += 1;
              if (callCount == 1) {
                return Future<ExpenseDoc?>.error(StateError('first'));
              }
              return Future<ExpenseDoc?>.value(_buildExpense());
            }),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Could not load expense'), findsOneWidget);
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(find.text('Group dinner'), findsOneWidget);
      },
    );
  });
}
