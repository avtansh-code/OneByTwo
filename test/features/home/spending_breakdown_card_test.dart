// FR-HD-03 SpendingBreakdownCard widget tests (SCR-06 Category
// Breakdown Section).
//
// Mirrors the home_dashboard_screen_test harness: a `FakeAnalyticsService`
// over `analyticsServiceProvider`, plus the Contact Support fakes
// (remote config / device diagnostics / url launcher). The breakdown
// provider is driven by overriding its inputs — `friendsListProvider`,
// `expenseRepositoryProvider` (a canned `ExpenseStore` wrapped in a real
// `ExpenseRepository`, no `fake_cloud_firestore`), and `homeClockProvider`
// — and letting the real provider compute, so the tests exercise the
// genuine read-path → aggregator → card pipeline.

// ignore_for_file: only_throw_errors

import 'dart:async';

import 'package:flutter/material.dart' hide Split;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/remote_config/remote_config_service.dart';
import 'package:onebytwo/core/services/url_launcher_service.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/expenses/data/expense_repository.dart';
import 'package:onebytwo/features/expenses/domain/expense_category.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';
import 'package:onebytwo/features/expenses/domain/split_method.dart';
import 'package:onebytwo/features/friends/application/friends_list_provider.dart';
import 'package:onebytwo/features/friends/domain/friend_list_item.dart';
import 'package:onebytwo/features/home/application/home_telemetry.dart';
import 'package:onebytwo/features/home/application/monthly_spend_breakdown_provider.dart';
import 'package:onebytwo/features/home/presentation/widgets/spending_breakdown_card.dart';
import 'package:onebytwo/features/home/presentation/widgets/spending_donut_chart.dart';
import 'package:onebytwo/features/profile/data/device_diagnostics_service.dart';
import 'package:onebytwo/features/profile/domain/support_diagnostics.dart';

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
}

class FakeRemoteConfigService implements RemoteConfigService {
  @override
  Future<void> initialise() async {}

  @override
  String getString(String key) => 'support@onebytwo.app';
}

class FakeDeviceDiagnosticsService implements DeviceDiagnosticsService {
  @override
  Future<SupportDiagnostics> load() async => const SupportDiagnostics(
    appVersion: '1.0.0',
    buildNumber: '1',
    osName: 'Android',
    osVersion: '14',
    deviceModel: 'Pixel 6',
  );
}

class FakeUrlLauncherService implements UrlLauncherService {
  bool canLaunchResult = false;

  @override
  Future<bool> canLaunch(Uri uri) async => canLaunchResult;

  @override
  Future<bool> launchExternal(Uri uri) async => canLaunchResult;
}

/// Canned `ExpenseStore`: returns scripted per-friendship expenses or,
/// optionally, throws for a friendship. Records call count so the Retry
/// path can assert a re-fan-out.
class _CannedExpenseStore implements ExpenseStore {
  _CannedExpenseStore({this.byFriendship = const {}, this.errorFor = const {}});

  final Map<String, List<ExpenseDoc>> byFriendship;
  final Map<String, Object> errorFor;
  int fetchCount = 0;

  @override
  Future<List<ExpenseDoc>> fetchExpensesInMonth({
    required String friendshipId,
    required DateTime monthStartUtc,
  }) async {
    fetchCount++;
    final error = errorFor[friendshipId];
    if (error != null) throw error;
    return byFriendship[friendshipId] ?? const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// `ExpenseStore` whose single read resolves only when [completer]
/// completes — used to hold the card in its loading sub-state.
class _PendingExpenseStore implements ExpenseStore {
  _PendingExpenseStore(this.completer);

  final Completer<List<ExpenseDoc>> completer;

  @override
  Future<List<ExpenseDoc>> fetchExpensesInMonth({
    required String friendshipId,
    required DateTime monthStartUtc,
  }) {
    return completer.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

FriendListItem _friend(String friendshipId, String otherUserId) {
  return FriendListItem(
    friendshipId: friendshipId,
    otherUserId: otherUserId,
    displayName: 'Friend',
    photoUrl: null,
    netBalancePaise: 0,
  );
}

ExpenseDoc _expense({
  required ExpenseCategory category,
  required int userSharePaise,
  String counterpartyId = 'uid-bob',
}) {
  return ExpenseDoc(
    amountPaise: userSharePaise * 2,
    description: 'expense',
    category: category,
    date: DateTime.utc(2026, 6, 10),
    payerId: 'uid-me',
    splits: [
      Split(userId: 'uid-me', sharePaise: userSharePaise),
      Split(userId: counterpartyId, sharePaise: userSharePaise),
    ],
    splitMethod: SplitMethod.equal,
    createdBy: 'uid-me',
  );
}

void main() {
  late FakeAnalyticsService analytics;
  late FakeUrlLauncherService launcher;

  setUp(() {
    analytics = FakeAnalyticsService();
    launcher = FakeUrlLauncherService();
  });

  // Fixed June 2026 clock → window start 2026-05-31T18:30:00Z.
  DateTime fixedNow() => DateTime.utc(2026, 6, 15, 12);

  Widget buildSubject({
    required ExpenseStore store,
    List<FriendListItem> friends = const [],
  }) {
    return ProviderScope(
      overrides: [
        analyticsServiceProvider.overrideWithValue(analytics),
        currentUserIdProvider.overrideWithValue('uid-me'),
        friendsListProvider.overrideWith((ref) => Stream.value(friends)),
        expenseRepositoryProvider.overrideWithValue(
          ExpenseRepository(store: store),
        ),
        homeClockProvider.overrideWithValue(fixedNow),
        remoteConfigServiceProvider.overrideWithValue(
          FakeRemoteConfigService(),
        ),
        deviceDiagnosticsServiceProvider.overrideWithValue(
          FakeDeviceDiagnosticsService(),
        ),
        urlLauncherServiceProvider.overrideWithValue(launcher),
      ],
      child: const MaterialApp(home: Scaffold(body: SpendingBreakdownCard())),
    );
  }

  _CannedExpenseStore populatedStore() {
    return _CannedExpenseStore(
      byFriendship: {
        'fid-bob': [
          _expense(category: ExpenseCategory.food, userSharePaise: 70000),
          _expense(category: ExpenseCategory.travel, userSharePaise: 30000),
        ],
      },
    );
  }

  group('populated sub-state', () {
    testWidgets('renders the donut, the month total, and the legend rows', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          store: populatedStore(),
          friends: [_friend('fid-bob', 'uid-bob')],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SpendingDonutChart), findsOneWidget);
      // Donut centre = month total.
      expect(find.text('₹1,000.00'), findsOneWidget);
      // Legend subtotals + percentages.
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('₹700.00'), findsOneWidget);
      expect(find.text('70%'), findsOneWidget);
      expect(find.text('Travel'), findsOneWidget);
      expect(find.text('₹300.00'), findsOneWidget);
      expect(find.text('30%'), findsOneWidget);
    });

    testWidgets('exposes the donut summary and per-row a11y labels', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        buildSubject(
          store: populatedStore(),
          friends: [_friend('fid-bob', 'uid-bob')],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(
          'This month you have spent ₹1,000.00 across 2 categories',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Food, ₹700.00, 70 per cent'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Travel, ₹300.00, 30 per cent'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('logs home_spending_breakdown_viewed once with the '
        'category_count', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          store: populatedStore(),
          friends: [_friend('fid-bob', 'uid-bob')],
        ),
      );
      await tester.pumpAndSettle();

      expect(analytics.countOf(HomeTelemetry.spendingBreakdownViewed), 1);
      expect(analytics.lastParamsFor(HomeTelemetry.spendingBreakdownViewed), {
        HomeTelemetry.paramCategoryCount: 2,
      });

      // A further rebuild must not re-fire (single-fire gate).
      await tester.pump();
      expect(analytics.countOf(HomeTelemetry.spendingBreakdownViewed), 1);
    });

    testWidgets('single-category month renders one full segment at 100%', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          store: _CannedExpenseStore(
            byFriendship: {
              'fid-bob': [
                _expense(
                  category: ExpenseCategory.rent,
                  userSharePaise: 120000,
                ),
              ],
            },
          ),
          friends: [_friend('fid-bob', 'uid-bob')],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SpendingDonutChart), findsOneWidget);
      // The single category's subtotal equals the month total, so the
      // amount appears twice: the donut centre and the one legend row.
      expect(find.text('₹1,200.00'), findsNWidgets(2));
      expect(find.text('Rent'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(analytics.lastParamsFor(HomeTelemetry.spendingBreakdownViewed), {
        HomeTelemetry.paramCategoryCount: 1,
      });
    });

    testWidgets('single-category a11y uses the singular "1 category" '
        'summary noun', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        buildSubject(
          store: _CannedExpenseStore(
            byFriendship: {
              'fid-bob': [
                _expense(
                  category: ExpenseCategory.rent,
                  userSharePaise: 120000,
                ),
              ],
            },
          ),
          friends: [_friend('fid-bob', 'uid-bob')],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(
          'This month you have spent ₹1,200.00 across 1 category',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Rent, ₹1,200.00, 100 per cent'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('legend percentages use largest-remainder and sum to 100', (
      tester,
    ) async {
      // 33334 + 33333 + 33333 = 100000. Independent rounding would show
      // 33% + 33% + 33% = 99%; largest-remainder lifts the largest
      // remainder (Food) to 34% so the displayed set sums to exactly 100.
      await tester.pumpWidget(
        buildSubject(
          store: _CannedExpenseStore(
            byFriendship: {
              'fid-bob': [
                _expense(category: ExpenseCategory.food, userSharePaise: 33334),
                _expense(
                  category: ExpenseCategory.travel,
                  userSharePaise: 33333,
                ),
                _expense(category: ExpenseCategory.rent, userSharePaise: 33333),
              ],
            },
          ),
          friends: [_friend('fid-bob', 'uid-bob')],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('34%'), findsOneWidget);
      expect(find.text('33%'), findsNWidgets(2));
    });
  });

  group('empty sub-state', () {
    testWidgets('renders the no-spend copy and no chart', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          store: _CannedExpenseStore(byFriendship: const {'fid-bob': []}),
          friends: [_friend('fid-bob', 'uid-bob')],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No spending yet this month'), findsOneWidget);
      expect(
        find.text('Add an expense to see your monthly breakdown'),
        findsOneWidget,
      );
      expect(find.byType(SpendingDonutChart), findsNothing);
    });

    testWidgets('logs the viewed event with category_count 0', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          store: _CannedExpenseStore(byFriendship: const {'fid-bob': []}),
          friends: [_friend('fid-bob', 'uid-bob')],
        ),
      );
      await tester.pumpAndSettle();

      expect(analytics.countOf(HomeTelemetry.spendingBreakdownViewed), 1);
      expect(analytics.lastParamsFor(HomeTelemetry.spendingBreakdownViewed), {
        HomeTelemetry.paramCategoryCount: 0,
      });
    });
  });

  group('loading sub-state', () {
    testWidgets('shows the skeleton and never fires telemetry', (tester) async {
      final completer = Completer<List<ExpenseDoc>>();
      await tester.pumpWidget(
        buildSubject(
          store: _PendingExpenseStore(completer),
          friends: [_friend('fid-bob', 'uid-bob')],
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('spending_breakdown_skeleton')),
        findsOneWidget,
      );
      expect(find.byType(SpendingDonutChart), findsNothing);
      expect(analytics.countOf(HomeTelemetry.spendingBreakdownViewed), 0);

      // Release the read so the test settles cleanly.
      completer.complete(const []);
      await tester.pumpAndSettle();
      expect(analytics.countOf(HomeTelemetry.spendingBreakdownViewed), 1);
    });
  });

  group('error sub-state', () {
    testWidgets('renders the message, Retry, Contact Support, and the code', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          store: _CannedExpenseStore(
            errorFor: {'fid-bob': Exception('Firestore read failed')},
          ),
          friends: [_friend('fid-bob', 'uid-bob')],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text("We couldn't load your spending breakdown."),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Contact Support'), findsOneWidget);
      expect(find.text('Error code: HD-FIRESTORE-READ'), findsOneWidget);
      expect(find.byType(SpendingDonutChart), findsNothing);
    });

    testWidgets('never fires the viewed event', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          store: _CannedExpenseStore(
            errorFor: {'fid-bob': Exception('Firestore read failed')},
          ),
          friends: [_friend('fid-bob', 'uid-bob')],
        ),
      );
      await tester.pumpAndSettle();

      expect(analytics.countOf(HomeTelemetry.spendingBreakdownViewed), 0);
    });

    testWidgets('Retry re-runs the fan-out', (tester) async {
      final store = _CannedExpenseStore(
        errorFor: {'fid-bob': Exception('Firestore read failed')},
      );
      await tester.pumpWidget(
        buildSubject(store: store, friends: [_friend('fid-bob', 'uid-bob')]),
      );
      await tester.pumpAndSettle();
      expect(store.fetchCount, 1);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(store.fetchCount, 2);
    });

    testWidgets('Contact Support logs the reused error event and shows the '
        'fallback dialog', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          store: _CannedExpenseStore(
            errorFor: {'fid-bob': Exception('Firestore read failed')},
          ),
          friends: [_friend('fid-bob', 'uid-bob')],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Contact Support'));
      await tester.pumpAndSettle();

      expect(analytics.countOf(HomeTelemetry.errorSupportTapped), 1);
      expect(analytics.lastParamsFor(HomeTelemetry.errorSupportTapped), {
        HomeTelemetry.paramErrorCode: HomeTelemetry.errorCodeFirestoreRead,
      });
      // canLaunch == false → the no-mail-client fallback dialog.
      expect(find.text('No Mail App Found'), findsOneWidget);
    });
  });
}
