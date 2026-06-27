// Friends flow Haldi reskin gate (DC-06; 04-qa-test-strategy.md section D).
//
// Complements the behavioural friends screen/widget tests by pinning the
// DC-06 visual contract the state-machine tests do not assert:
//   - the friend-list rows, the friend-detail header, and the friend-history
//     rows carry the balance trio (colour + ICON/sign + label), in light AND
//     dark;
//   - the balance-trio colours clear AA on the surface, and the
//     white-on-marigold negative case fails (the DC-01 contrast rule);
//   - every interactive control on the populated list is labelled and
//     >= 48 dp; and
//   - the populated list does not overflow at 2.0x dynamic type at 390 and
//     320 dp, and the loading skeleton freezes under reduced motion.
//
// Money is asserted only as formatInrFromPaise() output (Invariant 1); the
// friends_list_boundary_contract_test grep is the structural guard.

// ignore_for_file: cascade_invocations

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Split;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/widgets/indicators/obt_balance_pill.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/expenses/domain/expense_category.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';
import 'package:onebytwo/features/expenses/domain/split_method.dart';
import 'package:onebytwo/features/friends/application/friend_detail_provider.dart';
import 'package:onebytwo/features/friends/application/friend_history_provider.dart';
import 'package:onebytwo/features/friends/application/friends_list_provider.dart';
import 'package:onebytwo/features/friends/domain/friend_list_item.dart';
import 'package:onebytwo/features/friends/presentation/friend_history_screen.dart';
import 'package:onebytwo/features/friends/presentation/friends_list_screen.dart';
import 'package:onebytwo/features/friends/presentation/widgets/friend_detail_header.dart';
import 'package:onebytwo/features/friends/presentation/widgets/friend_list_tile.dart';

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

FriendDetailHeader _header(int net, BalanceState state) {
  return FriendDetailHeader(
    displayName: 'Rahul Sharma',
    photoUrl: null,
    netBalancePaise: net,
    balanceState: state,
  );
}

List<FriendDetailTimelineEvent> _history() {
  return <FriendDetailTimelineEvent>[
    TimelineExpense(
      doc: ExpenseDoc(
        amountPaise: 320000,
        description: 'Dinner',
        category: ExpenseCategory.food,
        date: DateTime(2026, 6, 22),
        payerId: 'uid-me',
        splits: const [
          Split(userId: 'uid-me', sharePaise: 160000),
          Split(userId: 'uid-friend', sharePaise: 160000),
        ],
        splitMethod: SplitMethod.equal,
        createdBy: 'uid-me',
      ),
    ),
    TimelineExpense(
      doc: ExpenseDoc(
        amountPaise: 90000,
        description: 'Cab',
        category: ExpenseCategory.travel,
        date: DateTime(2026, 6, 20),
        payerId: 'uid-friend',
        splits: const [
          Split(userId: 'uid-me', sharePaise: 45000),
          Split(userId: 'uid-friend', sharePaise: 45000),
        ],
        splitMethod: SplitMethod.equal,
        createdBy: 'uid-friend',
      ),
    ),
  ];
}

Widget _friendHistory(Brightness brightness) {
  return ProviderScope(
    overrides: [
      friendHistoryProvider.overrideWith(
        (ref, args) => Stream.value(_history()),
      ),
    ],
    child: MaterialApp(
      theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
      home: const FriendHistoryScreen(
        friendshipId: 'uid-friend_uid-me',
        currentUserUid: 'uid-me',
        otherUserUid: 'uid-friend',
        friendDisplayName: 'Rahul Sharma',
      ),
    ),
  );
}

Future<void> _pumpFriendsList(
  WidgetTester tester,
  List<FriendListItem> items, {
  double textScale = 1.0,
  Size surfaceSize = const Size(390, 844),
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = surfaceSize * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        analyticsServiceProvider.overrideWithValue(_NoopAnalytics()),
        currentUserIdProvider.overrideWithValue('uid-me'),
        friendsListProvider.overrideWith((ref) => Stream.value(items)),
      ],
      child: MaterialApp(
        theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: const FriendsListScreen(),
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

/// The [BoxDecoration] of the [FriendListTile]'s outer surface card — the one
/// rounded to [AppTheme.radiusLarge] that carries the `rowShadow` / outline.
BoxDecoration _tileDecoration(WidgetTester tester) {
  return tester
      .widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(FriendListTile),
          matching: find.byType(DecoratedBox),
        ),
      )
      .map((box) => box.decoration)
      .whereType<BoxDecoration>()
      .firstWhere(
        (d) => d.borderRadius == BorderRadius.circular(AppTheme.radiusLarge),
      );
}

void main() {
  for (final brightness in Brightness.values) {
    final mode = brightness == Brightness.light ? 'light' : 'dark';
    final obt = brightness == Brightness.light
        ? OBTColors.light
        : OBTColors.dark;

    // --- AC-1: friend-list row pill trio (colour + icon + label) ---
    group('friend-list row pill trio ($mode)', () {
      testWidgets('owed: arrow_upward + "owes you" in the positive hue', (
        tester,
      ) async {
        await pumpThemed(
          tester,
          FriendListTile(item: _item(netBalancePaise: 150000), onTap: () {}),
          brightness: brightness,
        );

        expect(find.byType(OBTBalancePill), findsOneWidget);
        final icon = tester.widget<Icon>(
          find.descendant(
            of: find.byType(OBTBalancePill),
            matching: find.byIcon(Icons.arrow_upward),
          ),
        );
        expect(icon.color, obt.balancePositive);
        expect(find.text('owes you'), findsOneWidget);
      });

      testWidgets('owe: arrow_downward + "you owe" in the negative hue', (
        tester,
      ) async {
        await pumpThemed(
          tester,
          FriendListTile(item: _item(netBalancePaise: -25000), onTap: () {}),
          brightness: brightness,
        );

        final icon = tester.widget<Icon>(
          find.descendant(
            of: find.byType(OBTBalancePill),
            matching: find.byIcon(Icons.arrow_downward),
          ),
        );
        expect(icon.color, obt.balanceNegative);
        expect(find.text('you owe'), findsOneWidget);
      });

      testWidgets('settled: check + "Settled up" in the zero hue', (
        tester,
      ) async {
        await pumpThemed(
          tester,
          FriendListTile(item: _item(netBalancePaise: 0), onTap: () {}),
          brightness: brightness,
        );

        final icon = tester.widget<Icon>(
          find.descendant(
            of: find.byType(OBTBalancePill),
            matching: find.byIcon(Icons.check),
          ),
        );
        expect(icon.color, obt.balanceZero);
        expect(find.text('Settled up'), findsOneWidget);
      });
    });

    // --- AC-4: friend-detail header pill trio ---
    testWidgets('friend-detail header uses the OBTBalancePill trio ($mode)', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        FriendDetailHeaderWidget(header: _header(425000, BalanceState.owed)),
        brightness: brightness,
      );

      expect(find.byType(OBTBalancePill), findsOneWidget);
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byType(OBTBalancePill),
          matching: find.byIcon(Icons.arrow_upward),
        ),
      );
      expect(icon.color, obt.balancePositive);
      expect(find.text('you are owed'), findsOneWidget);
      expect(find.text(formatInrFromPaise(425000)), findsOneWidget);
    });

    // --- AC-5: friend-history signed amounts in the trio hues ---
    testWidgets('friend-history rows carry signed amounts in the trio hues '
        '($mode)', (tester) async {
      await tester.pumpWidget(_friendHistory(brightness));
      await tester.pumpAndSettle();

      final lent = '+${formatInrFromPaise(160000)}';
      expect(
        tester.widget<Text>(find.text(lent)).style?.color,
        obt.balancePositive,
      );
      final borrowed = formatInrFromPaise(-45000);
      expect(
        tester.widget<Text>(find.text(borrowed)).style?.color,
        obt.balanceNegative,
      );
      // The sign survives greyscale: the descriptor names the direction.
      expect(find.textContaining('you lent'), findsOneWidget);
      expect(find.textContaining('you borrowed'), findsOneWidget);
    });
  }

  // --- DC-11 (#123): the canonical shadow -> outline swap (AC-1) ---
  // friend_list_tile is the one hero surface that leans on rowShadow for
  // separation; in dark rowShadow collapses to [] and a 1px `outline` border
  // takes over so the tile never vanishes into the dark surface (03 §2.2).
  testWidgets('FriendListTile swaps rowShadow -> outline border in dark', (
    tester,
  ) async {
    await pumpThemed(
      tester,
      FriendListTile(item: _item(netBalancePaise: 150000), onTap: () {}),
      brightness: Brightness.dark,
    );

    final deco = _tileDecoration(tester);
    expect(deco.boxShadow, isEmpty, reason: 'rowShadow collapses in dark');
    expect(deco.border, isNotNull, reason: 'a 1px outline border replaces it');
    expect(
      (deco.border! as Border).top.color,
      AppTheme.dark.colorScheme.outline,
    );
  });

  testWidgets('FriendListTile keeps the soft rowShadow (no border) in light', (
    tester,
  ) async {
    await pumpThemed(
      tester,
      FriendListTile(item: _item(netBalancePaise: 150000), onTap: () {}),
    );

    final deco = _tileDecoration(tester);
    expect(deco.boxShadow, OBTColors.light.rowShadow);
    expect(deco.boxShadow, isNotEmpty);
    expect(deco.border, isNull, reason: 'light mode separates by shadow');
  });

  // --- section B.1/B.2: contrast gate incl. the negative case ---
  group('contrast gate', () {
    test('balance-trio colours clear AA (>= 4.5:1) on the surface, '
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

  // --- section B.3/B.4: every control labelled + 48 dp on the populated list
  testWidgets('populated list: every interactive control is labelled and '
      'meets the 48 dp minimum', (tester) async {
    await _pumpFriendsList(tester, <FriendListItem>[
      _item(netBalancePaise: 150000),
      _item(
        netBalancePaise: -25000,
        displayName: 'Bina Kapoor',
        friendshipId: 'uid-b_uid-me',
        otherUserId: 'uid-b',
      ),
    ]);

    await expectAllInteractiveNodesLabelled(tester);
    await expectAllTapTargetsMeetMinSize(tester);
  });

  // --- section C: dynamic type 2.0x, no overflow at 390/320 (light + dark) ---
  for (final brightness in Brightness.values) {
    final mode = brightness == Brightness.light ? 'light' : 'dark';
    for (final width in <double>[390, 320]) {
      testWidgets('populated list does not overflow at 2.0x text scale '
          '(${width.toInt()} dp, $mode)', (tester) async {
        await _pumpFriendsList(
          tester,
          <FriendListItem>[
            _item(netBalancePaise: 695000),
            _item(
              netBalancePaise: -210000,
              displayName: 'Bina Kapoor',
              friendshipId: 'uid-b_uid-me',
              otherUserId: 'uid-b',
            ),
          ],
          brightness: brightness,
          textScale: 2,
          surfaceSize: Size(width, 844),
        );

        expect(tester.takeException(), isNull);
      });
    }
  }

  // --- section C.3: reduced motion freezes the loading shimmer ---
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
              child: const FriendsListScreen(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('friends_list_skeleton')), findsOneWidget);
  });
}
