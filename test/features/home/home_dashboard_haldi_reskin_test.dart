// Home dashboard Haldi reskin gate (DC-05; 04-qa-test-strategy.md §D).
//
// Complements the behavioural home_dashboard_screen_test by pinning the
// DC-05 visual contract that the state-machine tests do not assert:
//   - the net-balance hero renders the balance trio (colour + ICON +
//     label), in light AND dark, with the amount in the Bricolage
//     amount-hero style tinted by the trio colour;
//   - the top-balance tile uses the shared OBTBalancePill (with its
//     directional icon) and an ink-on-marigold Settle Up (never white);
//   - the balance-trio colours clear AA on the hero surface, and the
//     white-on-marigold negative case fails (the DC-01 contrast rule);
//   - every interactive control is labelled and >= 48 dp; and
//   - the populated state does not overflow at 2.0x dynamic type at 390
//     and 320 dp, and the loading skeleton freezes under reduced motion.
//
// Money is asserted only as `formatInrFromPaise()` output (Invariant 1);
// the home_boundary_contract_test grep is the structural guard.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/widgets/indicators/obt_balance_pill.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/friends/application/friends_list_provider.dart';
import 'package:onebytwo/features/friends/domain/friend_list_item.dart';
import 'package:onebytwo/features/home/presentation/home_dashboard_screen.dart';
import 'package:onebytwo/features/home/presentation/widgets/net_balance_header_card.dart';
import 'package:onebytwo/features/home/presentation/widgets/top_balance_tile.dart';

import '../../support/widget_test_harness.dart';

class _NoopAnalytics implements AnalyticsService {
  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {}
}

FriendListItem _item({
  required int netBalancePaise,
  String displayName = 'Aarav',
  String friendshipId = 'uid-a_uid-me',
  String otherUserId = 'uid-a',
}) {
  return FriendListItem(
    friendshipId: friendshipId,
    otherUserId: otherUserId,
    displayName: displayName,
    photoUrl: null,
    netBalancePaise: netBalancePaise,
  );
}

/// A representative populated composition (the hero + the "Top Balances"
/// header + two tiles) used for the labelling, tap-target and
/// dynamic-type gates without wiring the full provider graph (the
/// state-machine + breakdown coverage lives in the screen / card tests).
Widget _composedPopulated() {
  return ListView(
    children: [
      const NetBalanceHeaderCard(netBalancePaise: 150000),
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Text('Top Balances'),
      ),
      TopBalanceTile(
        item: _item(netBalancePaise: 150000),
        onTap: () {},
        onSettleUp: () {},
      ),
      TopBalanceTile(
        item: _item(
          netBalancePaise: -25000,
          displayName: 'Bina Kapoor',
          friendshipId: 'uid-b_uid-me',
          otherUserId: 'uid-b',
        ),
        onTap: () {},
        onSettleUp: () {},
      ),
    ],
  );
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
  // --- AC-1: the net-balance hero balance trio (colour + icon + label) ---
  for (final brightness in Brightness.values) {
    final mode = brightness == Brightness.light ? 'light' : 'dark';
    final obt = brightness == Brightness.light
        ? OBTColors.light
        : OBTColors.dark;

    group('net-balance hero trio ($mode)', () {
      testWidgets('owed: arrow_upward + headline + amount in the positive '
          'hue', (tester) async {
        await pumpThemed(
          tester,
          const NetBalanceHeaderCard(netBalancePaise: 150000),
          brightness: brightness,
        );

        expect(find.text('Overall, you are owed'), findsOneWidget);
        expect(find.text('₹1,500.00'), findsOneWidget);
        final icon = tester.widget<Icon>(find.byIcon(Icons.arrow_upward));
        expect(icon.color, obt.balancePositive);
        final amount = tester.widget<Text>(find.text('₹1,500.00'));
        expect(amount.style?.color, obt.balancePositive);
      });

      testWidgets('owe: arrow_downward + headline + absolute amount in the '
          'negative hue', (tester) async {
        await pumpThemed(
          tester,
          const NetBalanceHeaderCard(netBalancePaise: -25000),
          brightness: brightness,
        );

        expect(find.text('Overall, you owe'), findsOneWidget);
        expect(find.text('₹250.00'), findsOneWidget);
        final icon = tester.widget<Icon>(find.byIcon(Icons.arrow_downward));
        expect(icon.color, obt.balanceNegative);
        final amount = tester.widget<Text>(find.text('₹250.00'));
        expect(amount.style?.color, obt.balanceNegative);
      });

      testWidgets('settled: check + headline, no amount, in the zero hue', (
        tester,
      ) async {
        await pumpThemed(
          tester,
          const NetBalanceHeaderCard(netBalancePaise: 0),
          brightness: brightness,
        );

        expect(find.text("You're all settled up — high five!"), findsOneWidget);
        final icon = tester.widget<Icon>(find.byIcon(Icons.check));
        expect(icon.color, obt.balanceZero);
      });
    });
  }

  // --- DC-11 (#123): the hero card KEEPS its shadow in dark (AC-1) ---
  // net_balance_header_card is a heroShadow surface, not a row: heroShadow is
  // non-empty in dark, so the card keeps its soft lift and is NOT given an
  // outline (03 §2.2 — only rowShadow collapses to a border in dark).
  testWidgets('NetBalanceHeaderCard keeps heroShadow and has no outline in '
      'dark', (tester) async {
    await pumpThemed(
      tester,
      const NetBalanceHeaderCard(netBalancePaise: 150000),
      brightness: Brightness.dark,
    );

    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(NetBalanceHeaderCard),
            matching: find.byType(Container),
          )
          .first,
    );
    final deco = container.decoration! as BoxDecoration;
    expect(deco.boxShadow, isNotEmpty, reason: 'heroShadow is kept in dark');
    expect(deco.boxShadow, OBTColors.dark.heroShadow);
    expect(deco.border, isNull, reason: 'a heroShadow surface gets no outline');
  });

  // --- AC-1: the top-balance tile one-line pill + subtitle + Settle Up ---
  testWidgets('top-balance tile uses the one-line OBTBalancePill (icon + '
      'amount), a directional subtitle, and a marigold Settle Up link', (
    tester,
  ) async {
    await pumpThemed(
      tester,
      TopBalanceTile(
        item: _item(netBalancePaise: 150000),
        onTap: () {},
        onSettleUp: () {},
      ),
    );

    expect(find.byType(OBTBalancePill), findsOneWidget);
    // The pill carries the directional icon + the amount on one line.
    expect(
      find.descendant(
        of: find.byType(OBTBalancePill),
        matching: find.byIcon(Icons.arrow_upward),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(OBTBalancePill),
        matching: find.text('₹1,500.00'),
      ),
      findsOneWidget,
    );
    // The directional label is the identity subtitle, NOT inside the pill.
    expect(find.text('owes you'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(OBTBalancePill),
        matching: find.text('owes you'),
      ),
      findsNothing,
    );

    // Settle Up is the AA-tuned marigold link token, not the low-contrast
    // raw primary; the 48 dp tap target is preserved.
    expect(find.widgetWithText(TextButton, 'Settle Up'), findsOneWidget);
    final button = tester.widget<TextButton>(find.byType(TextButton));
    final foreground = button.style?.foregroundColor?.resolve(<WidgetState>{});
    expect(foreground, OBTColors.light.link);
  });

  // --- §B.1/B.2: contrast gate incl. the white-on-marigold negative case ---
  group('contrast gate', () {
    test('balance-trio colours clear AA (>= 4.5:1) on the hero surface, '
        'light + dark', () {
      final cases = <(OBTColors, ColorScheme)>[
        (OBTColors.light, AppTheme.light.colorScheme),
        (OBTColors.dark, AppTheme.dark.colorScheme),
      ];
      for (final (obt, scheme) in cases) {
        final surface = scheme.surfaceContainerHighest;
        expect(
          _contrastRatio(obt.balancePositive, surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrastRatio(obt.balanceNegative, surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrastRatio(obt.balanceZero, surface),
          greaterThanOrEqualTo(4.5),
        );
      }
    });

    test('white on marigold fails AA (DC-01 negative case) and ink on '
        'marigold passes', () {
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

  // --- §B.3/B.4: every control labelled + 48 dp on the populated state ---
  testWidgets('populated state: every interactive control is labelled and '
      'meets the 48 dp minimum', (tester) async {
    await pumpThemed(tester, _composedPopulated());

    await expectAllInteractiveNodesLabelled(tester);
    await expectAllTapTargetsMeetMinSize(tester);
  });

  // --- §C: dynamic type 2.0x, no overflow at 390/320 (light + dark) ---
  for (final brightness in Brightness.values) {
    final mode = brightness == Brightness.light ? 'light' : 'dark';
    for (final width in <double>[390, 320]) {
      testWidgets('populated state does not overflow at 2.0x text scale '
          '(${width.toInt()} dp, $mode)', (tester) async {
        await pumpThemed(
          tester,
          _composedPopulated(),
          brightness: brightness,
          textScale: 2,
          surfaceSize: Size(width, 844),
        );

        expect(tester.takeException(), isNull);
      });
    }
  }

  // --- §C: reduced motion freezes the loading shimmer ---
  testWidgets('loading skeleton freezes under reduced motion (settles)', (
    tester,
  ) async {
    final controller = StreamController<List<FriendListItem>>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          analyticsServiceProvider.overrideWithValue(_NoopAnalytics()),
          currentUserIdProvider.overrideWithValue('uid-me'),
          friendsListProvider.overrideWith((ref) => controller.stream),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: const HomeDashboardScreen(),
            ),
          ),
        ),
      ),
    );

    // The stream never emits, so the screen stays in its loading state.
    // Under reduced motion the shimmer is a static frame, so pumpAndSettle
    // completes instead of timing out on a perpetual animation.
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home_dashboard_skeleton')), findsOneWidget);
  });
}
