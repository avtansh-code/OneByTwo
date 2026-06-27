// Expenses flow Haldi reskin gate (DC-07; 04-qa-test-strategy.md section D).
//
// Complements the behavioural sheet / detail / picker tests by pinning the
// DC-07 visual + AC-2 contract those state-machine tests do not assert:
//   - Step 2 (the rebuild) drives the live "adds up" green / over-under red
//     validation off the integer-paise split sum, and Next is disabled until
//     the split balances (AC-2 / Invariant 1);
//   - the Expense-detail per-person split renders the balance trio
//     (colour + icon + label — payer "gets back", others "owe"), in light AND
//     dark, read from the doc's stored splits (Invariant 2);
//   - the balance-trio colours clear AA, and the white-on-marigold negative
//     case fails (the DC-01 contrast rule);
//   - every Step 2 control is labelled and >= 48 dp; Step 2 does not overflow
//     at 2.0x dynamic type at 390 and 320 dp; the detail skeleton freezes
//     under reduced motion; and the inert "Make recurring" / note slots are
//     announced disabled.
//
// Money is asserted only as formatInrFromPaise() output (Invariant 1); the
// expense_creation_boundary_contract_test grep is the structural guard.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Split;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/core/services/image_picker_service.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/widgets/feedback/obt_skeleton.dart';
import 'package:onebytwo/core/widgets/inputs/obt_segmented_split_control.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/domain/user_model.dart';
import 'package:onebytwo/features/expenses/application/expense_detail_provider.dart';
import 'package:onebytwo/features/expenses/data/expense_repository.dart';
import 'package:onebytwo/features/expenses/data/receipt_storage_service.dart';
import 'package:onebytwo/features/expenses/domain/expense_category.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';
import 'package:onebytwo/features/expenses/domain/split_method.dart';
import 'package:onebytwo/features/expenses/presentation/add_expense_bottom_sheet.dart';
import 'package:onebytwo/features/expenses/presentation/expense_detail_screen.dart';
import 'package:onebytwo/features/friends/application/user_profile_provider.dart';

import '../../support/widget_test_harness.dart';
import 'helpers/fake_services.dart';

const _friendshipId = 'uid-me_uid-friend';
const _currentUid = 'uid-me';
const _friendUid = 'uid-friend';

ExpenseDoc _detailDoc() {
  return ExpenseDoc(
    id: 'eid-test',
    amountPaise: 50000,
    description: 'Group dinner',
    category: ExpenseCategory.food,
    date: DateTime.utc(2026, 6, 24),
    payerId: _currentUid,
    splits: const [
      Split(userId: _currentUid, sharePaise: 25000),
      Split(userId: _friendUid, sharePaise: 25000),
    ],
    splitMethod: SplitMethod.equal,
    createdBy: _currentUid,
  );
}

List<Override> _sheetOverrides() => <Override>[
  analyticsServiceProvider.overrideWithValue(NoopAnalytics()),
  expenseRepositoryProvider.overrideWithValue(NoopExpenseRepository()),
  receiptStorageServiceProvider.overrideWithValue(FakeReceiptStorageService()),
  imagePickerServiceProvider.overrideWithValue(FakeImagePickerService()),
];

Future<void> _pumpAddExpenseToStep2(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  Size surfaceSize = const Size(390, 844),
}) async {
  tester.view.physicalSize = surfaceSize * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: _sheetOverrides(),
      child: MaterialApp(
        theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: const Scaffold(
              body: AddExpenseBottomSheet(
                friendshipId: _friendshipId,
                currentUserUid: _currentUid,
                otherUserUid: _friendUid,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.enterText(find.byKey(const Key('expense_amount_input')), '100');
  await tester.enterText(
    find.byKey(const Key('expense_description_input')),
    'Dinner',
  );
  await tester.tap(find.text('Food'));
  await tester.pumpAndSettle();

  // The OBTStepperSheet chrome can push the CTA below the fold.
  final next = find.widgetWithText(FilledButton, 'Next').last;
  await tester.ensureVisible(next);
  await tester.pumpAndSettle();
  await tester.tap(next);
  await tester.pumpAndSettle();
}

Widget _detailHost(Brightness brightness, {double textScale = 1.0}) {
  return ProviderScope(
    overrides: <Override>[
      ..._sheetOverrides(),
      expenseDetailProvider.overrideWith((ref, args) async => _detailDoc()),
      userProfileProvider(_friendUid).overrideWith(
        (ref) async => UserModel(
          phoneNumber: '+919988776655',
          displayName: 'Rahul',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      ),
    ],
    child: MaterialApp(
      theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: const ExpenseDetailScreen(
            friendshipId: _friendshipId,
            expenseId: 'eid-test',
            currentUserUid: _currentUid,
            otherUserUid: _friendUid,
          ),
        ),
      ),
    ),
  );
}

FilledButton _stepNext(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Next').last);

double _channel(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

double _contrastRatio(Color a, Color b) {
  final la = _luminance(a) + 0.05;
  final lb = _luminance(b) + 0.05;
  return la > lb ? la / lb : lb / la;
}

void main() {
  // --- AC-2: Step 2 segmented control live validation + Next gating ---
  group('Step 2 segmented split validation (rebuild, AC-2)', () {
    testWidgets('default equal split: green "Splits add up" + Next enabled', (
      tester,
    ) async {
      await _pumpAddExpenseToStep2(tester);

      expect(find.byType(OBTSegmentedSplitControl), findsOneWidget);
      final summary = tester.widget<Text>(find.text('Splits add up'));
      expect(summary.style?.color, OBTColors.light.balancePositive);
      expect(_stepNext(tester).onPressed, isNotNull);
    });

    testWidgets(
      'exact split that does not sum: red over/under + Next disabled',
      (tester) async {
        await _pumpAddExpenseToStep2(tester);

        await tester.tap(find.text('Exact'));
        await tester.pumpAndSettle();

        // Two split-row inputs (You / Friend). 60 + 30 = 90 != 100.
        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), '60');
        await tester.pumpAndSettle();
        await tester.enterText(fields.at(1), '30');
        await tester.pumpAndSettle();

        expect(
          find.text('Short by ${formatInrFromPaise(1000)}'),
          findsOneWidget,
        );
        final shortText = tester.widget<Text>(
          find.text('Short by ${formatInrFromPaise(1000)}'),
        );
        expect(shortText.style?.color, AppTheme.light.colorScheme.error);
        expect(
          _stepNext(tester).onPressed,
          isNull,
          reason:
              'AC-2: Next is disabled while the split does not sum to total',
        );

        // Balance it: 60 + 40 = 100 -> green + Next enabled.
        await tester.enterText(fields.at(1), '40');
        await tester.pumpAndSettle();
        expect(find.text('Splits add up'), findsOneWidget);
        expect(_stepNext(tester).onPressed, isNotNull);
      },
    );

    testWidgets('reserved split methods render disabled ("coming soon")', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpAddExpenseToStep2(tester);

      for (final label in <String>['Unequal', '%', 'Shares']) {
        expect(
          find.bySemanticsLabel('$label, coming soon'),
          findsOneWidget,
          reason: '$label must be announced disabled',
        );
      }
      handle.dispose();
    });
  });

  // --- a11y + dynamic type on Step 2 ---
  testWidgets('Step 2: every control is labelled and meets 48 dp', (
    tester,
  ) async {
    await _pumpAddExpenseToStep2(tester);

    await expectAllInteractiveNodesLabelled(tester);
    await expectAllTapTargetsMeetMinSize(tester);
  });

  for (final brightness in Brightness.values) {
    final mode = brightness == Brightness.light ? 'light' : 'dark';
    for (final width in <double>[390, 320]) {
      testWidgets('Step 2 does not overflow at 2.0x text scale '
          '(${width.toInt()} dp, $mode)', (tester) async {
        await _pumpAddExpenseToStep2(
          tester,
          brightness: brightness,
          textScale: 2,
          surfaceSize: Size(width, 844),
        );

        expect(tester.takeException(), isNull);
      });
    }
  }

  // --- AC-1: Step 3 inert "Coming soon" extension slots ---
  testWidgets('Step 3: note + Make-recurring slots are inert', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpAddExpenseToStep2(tester);
    final next = find.widgetWithText(FilledButton, 'Next').last;
    await tester.ensureVisible(next);
    await tester.pumpAndSettle();
    await tester.tap(next);
    await tester.pumpAndSettle();

    // The note field is a disabled (display-only) input.
    expect(find.text('Note (optional)'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    // The "Make recurring" toggle is announced disabled and never wired.
    expect(
      find.bySemanticsLabel('Make recurring, coming soon'),
      findsOneWidget,
    );
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    handle.dispose();
  });

  // --- AC-3: Expense-detail balance trio (light + dark) ---
  for (final brightness in Brightness.values) {
    final mode = brightness == Brightness.light ? 'light' : 'dark';
    final obt = brightness == Brightness.light
        ? OBTColors.light
        : OBTColors.dark;

    testWidgets('detail split: payer gets-back, friend owes ($mode)', (
      tester,
    ) async {
      await tester.pumpWidget(_detailHost(brightness));
      await tester.pumpAndSettle();

      // Colour + icon + label, never colour alone.
      expect(find.text('gets back'), findsOneWidget);
      expect(find.text('owes'), findsOneWidget);
      final up = tester.widget<Icon>(find.byIcon(Icons.arrow_upward));
      expect(up.color, obt.balancePositive);
      final down = tester.widget<Icon>(find.byIcon(Icons.arrow_downward));
      expect(down.color, obt.balanceNegative);

      // Invariant 1: every on-screen amount is formatInrFromPaise() output;
      // the per-person split is read straight from the doc projection.
      expect(find.text(formatInrFromPaise(50000)), findsOneWidget);
      expect(find.text(formatInrFromPaise(25000)), findsNWidgets(2));
      // IST date (fixed UTC+5:30) -> 24 Jun 2026.
      expect(find.text('24 Jun 2026'), findsOneWidget);
    });
  }

  // --- AC-2: the detail hero reflows at 2.0x at 390 AND 320, light + dark ---
  for (final brightness in Brightness.values) {
    final mode = brightness == Brightness.light ? 'light' : 'dark';
    for (final width in <double>[390, 320]) {
      testWidgets('detail does not overflow at 2.0x text scale '
          '(${width.toInt()} dp, $mode)', (tester) async {
        tester.view.physicalSize =
            Size(width, 844) * tester.view.devicePixelRatio;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_detailHost(brightness, textScale: 2));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        // Invariant 1: the hero amount stays whole at 2.0x (never truncated).
        expect(find.text(formatInrFromPaise(50000)), findsOneWidget);
      });
    }
  }

  // --- C.3: reduced motion freezes the detail skeleton (settles) ---
  testWidgets('detail loading skeleton freezes under reduced motion', (
    tester,
  ) async {
    final completer = Completer<ExpenseDoc?>();
    addTearDown(() {
      if (!completer.isCompleted) completer.complete(null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          ..._sheetOverrides(),
          expenseDetailProvider.overrideWith((ref, args) => completer.future),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: const ExpenseDetailScreen(
                friendshipId: _friendshipId,
                expenseId: 'eid-test',
                currentUserUid: _currentUid,
                otherUserUid: _friendUid,
              ),
            ),
          ),
        ),
      ),
    );
    // Reduced motion stops the shimmer controller, so the tree settles.
    await tester.pumpAndSettle();
    expect(find.byType(OBTSkeleton), findsWidgets);
  });

  // --- DC-11 (#123): the step-3 confirm summary border is the warm `outline`
  // in BOTH themes, never the onSurface that `outlineVariant` falls back to
  // (locks FINDING-B). `outlineVariant` is unset in AppTheme -> resolves to
  // onSurface: near-white #F3EBDD (dark) / near-black #2A211B (light); the fix
  // re-points to `outline` (#3A322A dark / #E7DDCD light) for both. The light
  // border is a latent correction (near-black -> soft grey), flagged in review.
  for (final brightness in Brightness.values) {
    final mode = brightness == Brightness.light ? 'light' : 'dark';
    testWidgets('step-3 summary card border is the warm outline ($mode)', (
      tester,
    ) async {
      await _pumpAddExpenseToStep2(tester, brightness: brightness);

      // Advance to step 3 (the default equal split balances, Next enabled).
      final next = find.widgetWithText(FilledButton, 'Next').last;
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();

      expect(find.text('Summary'), findsOneWidget);

      final scheme = brightness == Brightness.light
          ? AppTheme.light.colorScheme
          : AppTheme.dark.colorScheme;
      final summaryDeco = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .firstWhere(
            (d) =>
                d.color == scheme.surface &&
                d.border != null &&
                d.borderRadius == BorderRadius.circular(AppTheme.radiusCard),
          );
      final side = (summaryDeco.border! as Border).top;
      expect(side.color, scheme.outline);
      // Never the onSurface that `outlineVariant` falls back to.
      expect(side.color, isNot(scheme.onSurface));
    });
  }

  // --- B.1/B.2: contrast gate incl. the white-on-marigold negative case ---
  group('contrast gate', () {
    test('balance-trio colours clear AA on the surface (light + dark)', () {
      final cases = <(OBTColors, ColorScheme)>[
        (OBTColors.light, AppTheme.light.colorScheme),
        (OBTColors.dark, AppTheme.dark.colorScheme),
      ];
      for (final (obt, scheme) in cases) {
        final surface = scheme.surface;
        expect(
          _contrastRatio(obt.balancePositive, surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrastRatio(obt.balanceNegative, surface),
          greaterThanOrEqualTo(4.5),
        );
      }
    });

    test('white on marigold fails AA; ink on marigold passes', () {
      for (final scheme in <ColorScheme>[
        AppTheme.light.colorScheme,
        AppTheme.dark.colorScheme,
      ]) {
        expect(
          _contrastRatio(Colors.white, scheme.primary),
          lessThan(3.0),
          reason: 'white on marigold must fail even AA-large',
        );
        expect(
          _contrastRatio(scheme.onPrimary, scheme.primary),
          greaterThanOrEqualTo(4.5),
          reason: 'ink on marigold must clear AA',
        );
      }
    });
  });
}
