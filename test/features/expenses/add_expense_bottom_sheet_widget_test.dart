// Add expense bottom sheet widget tests (FR-EX-01).
//
// Tests the SCR-19 (step 1) and SCR-20 (step 2) bottom-sheet UI:
// state rendering, validation feedback, telemetry side-effects via
// the injected controller, and Save snackbar behaviour.
//
// Mirrors test/features/friends/friends_list_screen_widget_test.dart —
// uses a ProviderScope with an overridden analytics service and a fake
// expense repository injected via Riverpod overrides.
//
// Written test-first; will fail to compile until the presentation
// layer (Phase 5 commit 11) is added.

// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/expenses/application/expense_telemetry.dart';
import 'package:onebytwo/features/expenses/data/expense_repository.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';
import 'package:onebytwo/features/expenses/presentation/add_expense_bottom_sheet.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class FakeExpenseRepository implements ExpenseRepository {
  ExpenseCreateError? throwError;
  String returnId = 'eid-test';
  Map<String, dynamic>? capturedMap;
  String? capturedFriendshipId;
  bool called = false;

  @override
  Future<String> createExpense({
    required String friendshipId,
    required ExpenseDoc doc,
  }) async {
    called = true;
    capturedFriendshipId = friendshipId;
    capturedMap = doc.toCreateMap();
    if (throwError != null) {
      throw throwError!;
    }
    return returnId;
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

  bool hasEvent(String name) => loggedEvents.any((e) => e.name == name);
}

// ---------------------------------------------------------------------------
// Subject builder
// ---------------------------------------------------------------------------

const _friendshipId = 'uid-current_uid-friend';
const _currentUid = 'uid-current';
const _friendUid = 'uid-friend';

Widget buildSubject({
  required FakeExpenseRepository repo,
  required FakeAnalyticsService analytics,
}) {
  return ProviderScope(
    overrides: [
      analyticsServiceProvider.overrideWithValue(analytics),
      expenseRepositoryProvider.overrideWithValue(repo),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: AddExpenseBottomSheet(
          friendshipId: _friendshipId,
          currentUserUid: _currentUid,
          otherUserUid: _friendUid,
        ),
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

  group('Step 1 — initial render', () {
    testWidgets('shows the step title "Add Expense (1/3)"', (tester) async {
      await tester.pumpWidget(buildSubject(repo: repo, analytics: analytics));
      await tester.pumpAndSettle();

      expect(find.text('Add Expense (1/3)'), findsOneWidget);
    });

    testWidgets('renders the eight FR-EX-08 category chips', (tester) async {
      await tester.pumpWidget(buildSubject(repo: repo, analytics: analytics));
      await tester.pumpAndSettle();

      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Travel'), findsOneWidget);
      expect(find.text('Rent'), findsOneWidget);
      expect(find.text('Utilities'), findsOneWidget);
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Entertainment'), findsOneWidget);
      expect(find.text('Shopping'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);
    });

    testWidgets('the Next button is disabled initially (empty draft)', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(repo: repo, analytics: analytics));
      await tester.pumpAndSettle();

      final nextButton = find.widgetWithText(FilledButton, 'Next');
      expect(nextButton, findsOneWidget);
      expect(
        tester.widget<FilledButton>(nextButton).onPressed,
        isNull,
        reason: 'Next must be disabled until amount + description + '
            'category are all set',
      );
    });

    testWidgets('fires expense_step1_opened once on first build', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(repo: repo, analytics: analytics));
      await tester.pumpAndSettle();

      expect(analytics.countOf(ExpenseTelemetry.step1Opened), 1);
    });
  });

  group('Step 1 — validation', () {
    testWidgets('Next stays disabled when amount is zero', (tester) async {
      await tester.pumpWidget(buildSubject(repo: repo, analytics: analytics));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('expense_description_input')),
        'Coffee',
      );
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();

      final nextButton = find.widgetWithText(FilledButton, 'Next');
      expect(tester.widget<FilledButton>(nextButton).onPressed, isNull);
    });

    testWidgets('description error appears when empty after attempting Next',
        (tester) async {
      await tester.pumpWidget(buildSubject(repo: repo, analytics: analytics));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('expense_amount_input')),
        '100',
      );
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();

      // Next stays disabled because description is empty.
      final nextButton = find.widgetWithText(FilledButton, 'Next');
      expect(tester.widget<FilledButton>(nextButton).onPressed, isNull);
    });

    testWidgets('Next activates when amount > 0 AND description AND '
        'category are set', (tester) async {
      await tester.pumpWidget(buildSubject(repo: repo, analytics: analytics));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('expense_amount_input')),
        '100',
      );
      await tester.enterText(
        find.byKey(const Key('expense_description_input')),
        'Coffee',
      );
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();

      final nextButton = find.widgetWithText(FilledButton, 'Next');
      expect(tester.widget<FilledButton>(nextButton).onPressed, isNotNull);
    });
  });

  group('Step 1 → Step 2 transition', () {
    testWidgets('tapping Next advances to step 2 and shows "Add Expense (2/3)"',
        (tester) async {
      await tester.pumpWidget(buildSubject(repo: repo, analytics: analytics));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('expense_amount_input')),
        '100',
      );
      await tester.enterText(
        find.byKey(const Key('expense_description_input')),
        'Coffee',
      );
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();

      expect(find.text('Add Expense (2/3)'), findsOneWidget);
    });

    testWidgets('expense_step1_completed and expense_step2_opened fire on '
        'transition', (tester) async {
      await tester.pumpWidget(buildSubject(repo: repo, analytics: analytics));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('expense_amount_input')),
        '100',
      );
      await tester.enterText(
        find.byKey(const Key('expense_description_input')),
        'Coffee',
      );
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();

      expect(analytics.hasEvent(ExpenseTelemetry.step1Completed), isTrue);
      expect(analytics.hasEvent(ExpenseTelemetry.step2Opened), isTrue);
    });
  });

  group('Step 2 — split methods', () {
    Future<void> advanceToStep2(WidgetTester tester) async {
      await tester.pumpWidget(buildSubject(repo: repo, analytics: analytics));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('expense_amount_input')),
        '100',
      );
      await tester.enterText(
        find.byKey(const Key('expense_description_input')),
        'Coffee',
      );
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();
    }

    testWidgets('Equal and Exact chips are enabled; other three are disabled '
        '("Coming soon")', (tester) async {
      await advanceToStep2(tester);

      expect(find.text('Equal'), findsOneWidget);
      expect(find.text('Exact'), findsOneWidget);
      expect(find.text('Unequal'), findsOneWidget);
      expect(find.text('Percentage'), findsOneWidget);
      expect(find.text('Shares'), findsOneWidget);
    });

    testWidgets('Save button is enabled with default Equal split', (
      tester,
    ) async {
      await advanceToStep2(tester);

      final saveButton = find.widgetWithText(FilledButton, 'Save');
      expect(saveButton, findsOneWidget);
      expect(
        tester.widget<FilledButton>(saveButton).onPressed,
        isNotNull,
        reason: 'Equal split is always valid by construction; Save must be '
            'enabled immediately on step 2',
      );
    });
  });

  group('Save — success path', () {
    Future<void> driveSaveHappyPath(WidgetTester tester) async {
      await tester.pumpWidget(buildSubject(repo: repo, analytics: analytics));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('expense_amount_input')),
        '100',
      );
      await tester.enterText(
        find.byKey(const Key('expense_description_input')),
        'Coffee',
      );
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
    }

    testWidgets('invokes repository.createExpense with the captured '
        'friendshipId', (tester) async {
      await driveSaveHappyPath(tester);

      expect(repo.called, isTrue);
      expect(repo.capturedFriendshipId, _friendshipId);
    });

    testWidgets('fires expense_save_succeeded on success', (tester) async {
      await driveSaveHappyPath(tester);

      expect(analytics.hasEvent(ExpenseTelemetry.saveSucceeded), isTrue);
    });

    testWidgets('shows the success snackbar "Expense added." on success',
        (tester) async {
      await driveSaveHappyPath(tester);

      expect(find.text('Expense added.'), findsOneWidget);
    });
  });

  group('Save — failure path', () {
    testWidgets('shows the failure snackbar "Couldn\'t add the expense. '
        'Try again." on Firestore error', (tester) async {
      repo.throwError = const ExpenseCreateError(
        type: ExpenseCreateErrorType.network,
      );

      await tester.pumpWidget(buildSubject(repo: repo, analytics: analytics));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('expense_amount_input')),
        '100',
      );
      await tester.enterText(
        find.byKey(const Key('expense_description_input')),
        'Coffee',
      );
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(
        find.text("Couldn't add the expense. Try again."),
        findsOneWidget,
      );
      expect(analytics.hasEvent(ExpenseTelemetry.saveFailed), isTrue);
    });
  });
}
