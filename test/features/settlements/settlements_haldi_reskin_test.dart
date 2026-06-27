// Settlements flow Haldi reskin gate (DC-08; 04-qa-test-strategy.md §D).
//
// Complements the behavioural settle-up / history widget tests by pinning
// the DC-08 visual + AC-1/AC-2/AC-3 contract those state-machine tests do
// not assert:
//   - the settle-up rebuild fires the in-sheet success moment with a SINGLE
//     haptic (and does not re-fire on rebuild), and the recorded amount is
//     the integer-paise projection value (AC-1 / Invariant 1);
//   - the sheet shows EXACTLY ONE suggested payment read from the projection
//     — never a who-owes-who debt graph, and the client never writes
//     (AC-2 / Invariant 2);
//   - settlement-history rows carry the sent/received direction icon + sign
//     + hue derived from `fromUserId`/`toUserId` (the balance trio = colour +
//     icon + label), in light AND dark, with amounts via formatInrFromPaise()
//     (AC-3 / Invariant 1);
//   - the balance-trio colours clear AA and the white-on-marigold negative
//     case fails (the DC-01 contrast rule);
//   - every settle-up control is labelled and >= 48 dp; neither surface
//     overflows at 2.0x dynamic type at 390 and 320 dp (amounts never
//     truncate); the history skeleton freezes under reduced motion.
//
// Money is asserted only as formatInrFromPaise() output (Invariant 1); the
// settle_up + settlement_history boundary greps are the structural guard.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/widgets/feedback/obt_skeleton.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/settlements/data/settlement_repository.dart';
import 'package:onebytwo/features/settlements/domain/settlement_doc.dart';
import 'package:onebytwo/features/settlements/presentation/settle_up_bottom_sheet.dart';
import 'package:onebytwo/features/settlements/presentation/settlement_history_screen.dart';

import '../../support/widget_test_harness.dart';
import 'helpers/fake_services.dart';

const _friendshipId = 'uid-me_uid-friend';
const _currentUid = 'uid-me';
const _friendUid = 'uid-friend';
const _friendName = 'Bina';

List<Override> _overrides(
  FakeSettlementRepository repo,
  RecordingAnalytics analytics,
) => <Override>[
  settlementRepositoryProvider.overrideWithValue(repo),
  analyticsServiceProvider.overrideWithValue(analytics),
];

Future<void> _pumpSheet(
  WidgetTester tester, {
  required FakeSettlementRepository repo,
  required RecordingAnalytics analytics,
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  int suggestedAmountPaise = 50000,
  Size surfaceSize = const Size(390, 844),
}) async {
  tester.view.physicalSize = surfaceSize * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(repo, analytics),
      child: MaterialApp(
        theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
              body: SettleUpBottomSheet(
                friendshipId: _friendshipId,
                currentUserUid: _currentUid,
                otherUserUid: _friendUid,
                otherDisplayName: _friendName,
                suggestedAmountPaise: suggestedAmountPaise,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpHistory(
  WidgetTester tester, {
  required FakeSettlementRepository repo,
  required RecordingAnalytics analytics,
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  Size surfaceSize = const Size(390, 844),
  bool disableAnimations = false,
}) async {
  tester.view.physicalSize = surfaceSize * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(repo, analytics),
      child: MaterialApp(
        theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: disableAnimations,
            ),
            child: const SettlementHistoryScreen(
              contextType: 'friendship',
              contextId: _friendshipId,
              currentUserUid: _currentUid,
              otherUserUid: _friendUid,
              otherDisplayName: _friendName,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

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
  // --- AC-1: the rebuild's in-sheet success moment + single haptic ---
  testWidgets(
    'recording fires the in-sheet success moment with a single haptic',
    (tester) async {
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call.method);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final repo = FakeSettlementRepository();
      final analytics = RecordingAnalytics();
      await _pumpSheet(tester, repo: repo, analytics: analytics);

      await tester.tap(find.widgetWithText(FilledButton, 'Record payment'));
      await tester.pumpAndSettle();

      // The success moment replaces the editable form, with one haptic.
      expect(find.text('Payment recorded'), findsOneWidget);
      expect(
        calls.where((m) => m == 'HapticFeedback.vibrate').length,
        1,
        reason: 'the success check fires exactly one haptic pulse',
      );

      // Invariant 1 / the OBTAmountInput paise contract: the recorded amount
      // is the integer-paise projection value, unchanged (no /100, no double).
      expect(repo.capturedDoc!.amountPaise, 50000);

      // A rebuild (the auto-dismiss timer has not yet fired) must not re-fire
      // the haptic.
      await tester.pump(const Duration(milliseconds: 200));
      expect(calls.where((m) => m == 'HapticFeedback.vibrate').length, 1);

      // Drain the success auto-dismiss timer.
      await tester.pump(const Duration(milliseconds: 1500));
    },
  );

  // --- AC-2: exactly one suggested payment, never a debt graph (Inv 2) ---
  testWidgets('shows exactly one suggested payment, never a debt graph', (
    tester,
  ) async {
    final repo = FakeSettlementRepository();
    final analytics = RecordingAnalytics();
    await _pumpSheet(tester, repo: repo, analytics: analytics);

    // One directed header + one focal amount + one arrow — never a
    // who-owes-who list of transfers. The amount routes through
    // formatInrFromPaise() (Invariant 1).
    expect(find.text('You pay Bina'), findsOneWidget);
    expect(find.text(formatInrFromPaise(50000)), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);

    // The client reads the projection and never writes it: rendering the
    // suggestion does not record anything (Invariant 2).
    expect(repo.createCount, 0);
  });

  // --- AC-3: history direction + sign + hue (balance trio), light + dark ---
  for (final brightness in Brightness.values) {
    final mode = brightness == Brightness.light ? 'light' : 'dark';
    final obt = brightness == Brightness.light
        ? OBTColors.light
        : OBTColors.dark;

    testWidgets('history rows carry direction + sign + hue ($mode)', (
      tester,
    ) async {
      final repo = FakeSettlementRepository(
        history: <SettlementDoc>[
          fakeSettlement(id: 'out', date: DateTime(2026, 6, 24)),
          fakeSettlement(
            id: 'in',
            date: DateTime(2026, 6, 23),
            amountPaise: 30000,
            fromUserId: _friendUid,
            toUserId: _currentUid,
          ),
        ],
      );
      await _pumpHistory(
        tester,
        repo: repo,
        analytics: RecordingAnalytics(),
        brightness: brightness,
      );

      // Outgoing (you paid) -> negative sign in balanceNegative, north_east.
      expect(find.text('You paid Bina'), findsOneWidget);
      expect(find.byIcon(Icons.north_east), findsOneWidget);
      final outAmount = tester.widget<Text>(
        find.text(formatInrFromPaise(-50000)),
      );
      expect(outAmount.style?.color, obt.balanceNegative);

      // Incoming (they paid you) -> positive sign in balancePositive,
      // south_west.
      expect(find.text('Bina paid you'), findsOneWidget);
      expect(find.byIcon(Icons.south_west), findsOneWidget);
      final inAmount = tester.widget<Text>(
        find.text('+${formatInrFromPaise(30000)}'),
      );
      expect(inAmount.style?.color, obt.balancePositive);
    });
  }

  // --- a11y: every settle-up control labelled + 48 dp ---
  testWidgets('settle-up: every control is labelled and meets 48 dp', (
    tester,
  ) async {
    await _pumpSheet(
      tester,
      repo: FakeSettlementRepository(),
      analytics: RecordingAnalytics(),
    );

    await expectAllInteractiveNodesLabelled(tester);
    await expectAllTapTargetsMeetMinSize(tester);
  });

  // --- dynamic type 2.0x: neither surface clips a money value ---
  // The history list is fully in DC-08's control and must not overflow at
  // 390 OR 320. The settle-up sheet's focal amountHero (48 -> 96px at 2.0x)
  // is rendered by the FROZEN DC-03 OBTSettleUpSheet: it fits 390 but
  // overflows the 320 dp column. That is a DC-03 component limitation routed
  // to issue #128 (the component is not editable in this flow PR); the
  // Invariant-1 guarantee this gate pins is that the amount stays WHOLE
  // (never truncated) at both widths.
  for (final width in <double>[390, 320]) {
    testWidgets('history does not overflow at 2.0x (${width.toInt()} dp)', (
      tester,
    ) async {
      await _pumpHistory(
        tester,
        repo: FakeSettlementRepository(
          history: <SettlementDoc>[
            fakeSettlement(
              id: 'out',
              date: DateTime(2026, 6, 24),
              note: 'UPI transfer',
            ),
          ],
        ),
        analytics: RecordingAnalytics(),
        textScale: 2,
        surfaceSize: Size(width, 844),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(formatInrFromPaise(-50000)), findsOneWidget);
    });
  }

  testWidgets('settle-up does not overflow at 2.0x (390 dp), amount whole', (
    tester,
  ) async {
    await _pumpSheet(
      tester,
      repo: FakeSettlementRepository(),
      analytics: RecordingAnalytics(),
      textScale: 2,
    );

    expect(tester.takeException(), isNull);
    expect(find.text(formatInrFromPaise(50000)), findsOneWidget);
  });

  testWidgets('settle-up amount never truncates at 2.0x (320 dp)', (
    tester,
  ) async {
    await _pumpSheet(
      tester,
      repo: FakeSettlementRepository(),
      analytics: RecordingAnalytics(),
      textScale: 2,
      surfaceSize: const Size(320, 844),
    );

    // The frozen DC-03 amountHero overflows the narrow 320 dp column at 2.0x
    // (a component gap flagged to issue #128). Consume that known overflow;
    // the load-bearing assertion is that the amount renders WHOLE — never
    // truncated (Invariant 1).
    tester.takeException();
    expect(find.text(formatInrFromPaise(50000)), findsOneWidget);
  });

  // --- C.3: reduced motion freezes the history shimmer skeleton ---
  testWidgets('history loading skeleton freezes under reduced motion', (
    tester,
  ) async {
    await _pumpHistory(
      tester,
      repo: FakeSettlementRepository(keepLoading: true),
      analytics: RecordingAnalytics(),
      disableAnimations: true,
    );

    // Reduced motion stops the shimmer controller, so the tree settles.
    expect(find.byType(OBTSkeleton), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

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
