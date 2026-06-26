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

import 'package:flutter/material.dart' hide Split;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/services/image_picker_service.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/expenses/application/expense_telemetry.dart';
import 'package:onebytwo/features/expenses/data/expense_repository.dart';
import 'package:onebytwo/features/expenses/data/receipt_storage_service.dart';
import 'package:onebytwo/features/expenses/domain/expense_category.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';
import 'package:onebytwo/features/expenses/domain/split_method.dart';
import 'package:onebytwo/features/expenses/presentation/add_expense_bottom_sheet.dart';

import 'helpers/fake_services.dart';

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

  @override
  Future<void> updateExpense({
    required String friendshipId,
    required String expenseId,
    required Map<String, dynamic> updates,
  }) async {
    // Not exercised in FR-EX-01 tests; FR-EX-06 wiring uses dedicated
    // detail-screen tests with their own fakes.
  }

  @override
  Future<void> softDeleteExpense({
    required String friendshipId,
    required String expenseId,
  }) async {
    // Not exercised in FR-EX-01 tests.
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
  String newExpenseId({required String friendshipId}) => returnId;

  @override
  Future<void> createExpenseAtId({
    required String friendshipId,
    required String expenseId,
    required ExpenseDoc doc,
  }) async {
    // Not exercised by the FR-EX-01 widget tests.
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
  ExpenseDoc? initialExpense,
  String? initialExpenseId,
}) {
  return ProviderScope(
    overrides: [
      analyticsServiceProvider.overrideWithValue(analytics),
      expenseRepositoryProvider.overrideWithValue(repo),
      receiptStorageServiceProvider.overrideWithValue(
        FakeReceiptStorageService(),
      ),
      imagePickerServiceProvider.overrideWithValue(FakeImagePickerService()),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: AddExpenseBottomSheet(
          friendshipId: _friendshipId,
          currentUserUid: _currentUid,
          otherUserUid: _friendUid,
          initialExpense: initialExpense,
          initialExpenseId: initialExpenseId,
        ),
      ),
    ),
  );
}

/// Ensures the matching FilledButton CTA is on-screen, then taps it and
/// settles. The OBTStepperSheet shell (grabber + header + visual stepper)
/// consumes vertical space, so a step's bottom CTA can sit below the fold
/// in the default test viewport.
Future<void> tapStepCta(WidgetTester tester, String label) async {
  final finder = find.widgetWithText(FilledButton, label).last;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  late FakeExpenseRepository repo;
  late FakeAnalyticsService analytics;

  setUp(() {
    repo = FakeExpenseRepository();
    analytics = FakeAnalyticsService();
  });

  group('Step 1 — initial render', () {
    testWidgets('shows the step title "Add Expense" with the step counter', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(repo: repo, analytics: analytics));
      await tester.pumpAndSettle();

      expect(find.text('Add Expense'), findsOneWidget);
      expect(find.text('Step 1 of 3'), findsOneWidget);
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
        reason:
            'Next must be disabled until amount + description + '
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

    testWidgets('description error appears when empty after attempting Next', (
      tester,
    ) async {
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
    testWidgets(
      'tapping Next advances to step 2 and shows "Add Expense (2/3)"',
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
        await tapStepCta(tester, 'Next');

        expect(find.text('Add Expense'), findsOneWidget);
        expect(find.text('Step 2 of 3'), findsOneWidget);
      },
    );

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
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Next'));
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
      await tapStepCta(tester, 'Next');
    }

    testWidgets('Equal and Exact chips are enabled; other three are disabled '
        '("Coming soon")', (tester) async {
      await advanceToStep2(tester);

      expect(find.text('Equally'), findsOneWidget);
      expect(find.text('Exact'), findsOneWidget);
      expect(find.text('Unequal'), findsOneWidget);
      expect(find.text('%'), findsOneWidget);
      expect(find.text('Shares'), findsOneWidget);
    });

    testWidgets('Next button on Step 2 is enabled with default Equal split', (
      tester,
    ) async {
      await advanceToStep2(tester);

      // FR-EX-05: Step 2's primary CTA flips from "Save" to
      // "Next" — the final save fires from Step 3.
      final nextButtons = find.widgetWithText(FilledButton, 'Next');
      // Multiple "Next" buttons may exist if both Step 1's Next is
      // still on screen (it isn't — we're on Step 2). Use the last
      // one as the active CTA.
      expect(nextButtons, findsWidgets);
      final nextOnStep2 = nextButtons.last;
      expect(
        tester.widget<FilledButton>(nextOnStep2).onPressed,
        isNotNull,
        reason:
            'Equal split is always valid by construction; Next must be '
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
      // Each step's bottom CTA can sit below the fold under the
      // OBTStepperSheet shell, so scroll it into view before tapping.
      await tapStepCta(tester, 'Next'); // Step 1 -> Step 2.
      await tapStepCta(tester, 'Next'); // Step 2 -> Step 3 (FR-EX-05).
      await tapStepCta(tester, 'Save Expense'); // Step 3 -> Save.
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

    testWidgets('shows the success snackbar "Expense added." on success', (
      tester,
    ) async {
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
      await tapStepCta(tester, 'Next');
      await tapStepCta(tester, 'Next');
      await tapStepCta(tester, 'Save Expense');

      expect(find.text("Couldn't add the expense. Try again."), findsOneWidget);
      expect(analytics.hasEvent(ExpenseTelemetry.saveFailed), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // FR-EX-06 edit-mode UI assertions (AC-3 disabled-CTA semantic label;
  // AC-4 changed-field indicator on Step 2 rows). The reusable
  // ChangedFieldIndicator widget is unit-tested separately at
  // test/features/expenses/changed_field_indicator_test.dart.
  // ---------------------------------------------------------------------------

  group('FR-EX-06 — edit-mode CTA + indicators', () {
    Widget buildEditSubject({
      required FakeExpenseRepository repo,
      required FakeAnalyticsService analytics,
      required ExpenseDoc initialExpense,
      String initialExpenseId = 'eid-existing',
    }) {
      return ProviderScope(
        overrides: [
          analyticsServiceProvider.overrideWithValue(analytics),
          expenseRepositoryProvider.overrideWithValue(repo),
          receiptStorageServiceProvider.overrideWithValue(
            FakeReceiptStorageService(),
          ),
          imagePickerServiceProvider.overrideWithValue(
            FakeImagePickerService(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AddExpenseBottomSheet(
              friendshipId: _friendshipId,
              currentUserUid: _currentUid,
              otherUserUid: _friendUid,
              initialExpense: initialExpense,
              initialExpenseId: initialExpenseId,
            ),
          ),
        ),
      );
    }

    ExpenseDoc seedExpense() {
      return ExpenseDoc(
        amountPaise: 10000,
        description: 'Coffee',
        category: ExpenseCategory.food,
        date: DateTime(2026, 6, 5),
        payerId: _currentUid,
        splits: const [
          Split(userId: _currentUid, sharePaise: 5000),
          Split(userId: _friendUid, sharePaise: 5000),
        ],
        splitMethod: SplitMethod.equal,
        createdBy: _currentUid,
      );
    }

    testWidgets('header reads "Edit Expense" with the step counter in edit '
        'mode', (tester) async {
      await tester.pumpWidget(
        buildEditSubject(
          repo: repo,
          analytics: analytics,
          initialExpense: seedExpense(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Edit Expense'), findsOneWidget);
      expect(find.text('Step 1 of 3'), findsOneWidget);
    });

    testWidgets(
      'AC-3 — Step 3 Save Changes CTA is wrapped in Semantics with the '
      'disabled-CTA label when in edit mode and no fields are changed',
      (tester) async {
        await tester.pumpWidget(
          buildEditSubject(
            repo: repo,
            analytics: analytics,
            initialExpense: seedExpense(),
          ),
        );
        await tester.pumpAndSettle();
        // Tap Next twice to advance to Step 3 (Step 1 -> Step 2 -> Step 3).
        await tapStepCta(tester, 'Next');
        await tapStepCta(tester, 'Next');

        // The CTA label is "Save Changes" in edit mode on Step 3.
        final cta = find.widgetWithText(FilledButton, 'Save Changes');
        await tester.ensureVisible(cta);
        await tester.pumpAndSettle();
        expect(cta, findsOneWidget);

        // No fields modified → CTA disabled and wrapped in the AC-3 label.
        final semantics = find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              (w.properties.label ?? '') ==
                  'Save changes, no modifications made.',
        );
        expect(
          semantics,
          findsWidgets,
          reason:
              'AC-3: a disabled "Save Changes" CTA in edit mode must announce '
              '"Save changes, no modifications made."',
        );
      },
    );

    testWidgets(
      'AC-4 — changing the split method renders the changed-field indicator '
      'on the split-method group (Step 2)',
      (tester) async {
        await tester.pumpWidget(
          buildEditSubject(
            repo: repo,
            analytics: analytics,
            initialExpense: seedExpense(),
          ),
        );
        await tester.pumpAndSettle();
        await tapStepCta(tester, 'Next');

        // Flip split method from Equal (original) to Exact via the
        // segmented split control.
        await tester.tap(find.text('Exact'));
        await tester.pumpAndSettle();

        // Indicator wrapping the split-method group.
        final indicator = find.byWidgetPredicate(
          (w) =>
              w is Semantics && (w.properties.label ?? '').contains('changed'),
        );
        expect(
          indicator,
          findsAtLeastNWidgets(1),
          reason:
              'AC-4: at least one ChangedFieldIndicator must report '
              '", changed." after the split method flips from its original.',
        );

        // AC-2: flipping to Exact leaves the per-member shares empty (0),
        // which does not sum to the total, so the Step 2 Next CTA is
        // disabled until the split balances.
        final cta = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Next').last,
        );
        expect(cta.onPressed, isNull);
      },
    );
  });
}
