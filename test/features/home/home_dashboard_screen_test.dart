// Home dashboard screen widget tests (SCR-06 / FR-HD-01 + FR-HD-02).
//
// Covers the four SCR-06 states (loading / empty / populated / error),
// the FR-HD-01 net-balance header copy for each direction, the FR-HD-02
// top-balances list with Settle Up + tile-tap interactions, the empty
// CTA, and the error-state retry / Contact Support affordances.
//
// The screen state machine is driven by overriding `friendsListProvider`
// with a controllable stream; the derived providers
// (`overallNetBalanceProvider`, `topBalancesProvider`) recompute from it.

// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/remote_config/remote_config_service.dart';
import 'package:onebytwo/core/services/url_launcher_service.dart';
import 'package:onebytwo/core/telemetry/event_id_hash.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/application/auth_state_provider.dart';
import 'package:onebytwo/features/auth/domain/auth_state.dart';
import 'package:onebytwo/features/auth/domain/user_model.dart';
import 'package:onebytwo/features/expenses/data/expense_repository.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';
import 'package:onebytwo/features/friends/application/friends_list_provider.dart';
import 'package:onebytwo/features/friends/domain/friend_list_item.dart';
import 'package:onebytwo/features/friends/presentation/friend_detail_screen.dart';
import 'package:onebytwo/features/home/application/home_telemetry.dart';
import 'package:onebytwo/features/home/presentation/home_dashboard_screen.dart';
import 'package:onebytwo/features/home/presentation/widgets/net_balance_header_card.dart';
import 'package:onebytwo/features/home/presentation/widgets/spending_breakdown_card.dart';
import 'package:onebytwo/features/profile/data/device_diagnostics_service.dart';
import 'package:onebytwo/features/profile/domain/support_diagnostics.dart';
import 'package:onebytwo/features/profile/presentation/contact_support_fallback_dialog.dart';
import 'package:onebytwo/features/settlements/data/settlement_repository.dart';
import 'package:onebytwo/features/settlements/domain/settlement_doc.dart';
import 'package:onebytwo/features/settlements/presentation/settle_up_bottom_sheet.dart';
import 'package:onebytwo/features/shell/application/shell_navigation_controller.dart';

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
  Uri? lastLaunchedUri;

  @override
  Future<bool> canLaunch(Uri uri) async => canLaunchResult;

  @override
  Future<bool> launchExternal(Uri uri) async {
    lastLaunchedUri = uri;
    return canLaunchResult;
  }
}

class FakeSettlementRepository implements SettlementRepository {
  @override
  Future<String> createSettlement({required SettlementDoc doc}) async =>
      'sid-test';

  @override
  Stream<List<SettlementDoc>> watchByContext({
    required String contextType,
    required String contextId,
  }) => const Stream<List<SettlementDoc>>.empty();
}

/// FR-HD-03: the breakdown card fans out through `expenseRepositoryProvider`
/// once mounted in the dashboard's populated state. These screen tests
/// focus on the balances axis, so the store returns no expenses — the
/// card resolves to its empty sub-state (covered in detail by
/// spending_breakdown_card_test.dart).
class _EmptyExpenseStore implements ExpenseStore {
  @override
  Future<List<ExpenseDoc>> fetchExpensesInMonth({
    required String friendshipId,
    required DateTime monthStartUtc,
  }) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

FriendListItem _item({
  required String friendshipId,
  required String otherUserId,
  required String displayName,
  required int netBalancePaise,
}) {
  return FriendListItem(
    friendshipId: friendshipId,
    otherUserId: otherUserId,
    displayName: displayName,
    photoUrl: null,
    netBalancePaise: netBalancePaise,
  );
}

UserModel _user(String displayName) {
  final now = DateTime.utc(2026, 6, 28);
  return UserModel(
    phoneNumber: '+919876500000',
    displayName: displayName,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late FakeAnalyticsService analytics;
  late StreamController<List<FriendListItem>> controller;
  late FakeUrlLauncherService launcher;

  setUp(() {
    analytics = FakeAnalyticsService();
    controller = StreamController<List<FriendListItem>>.broadcast();
    launcher = FakeUrlLauncherService();
  });

  tearDown(() async {
    await controller.close();
  });

  Widget buildSubject({Override? friendsOverride, Override? authOverride}) {
    return ProviderScope(
      overrides: [
        analyticsServiceProvider.overrideWithValue(analytics),
        currentUserIdProvider.overrideWithValue('uid-me'),
        currentUserPhoneProvider.overrideWithValue('+919876500000'),
        // Default: no profile resolved → the greeting shows "Namaste,"
        // with no name. Individual tests pass an [authOverride] to exercise
        // the named path. Overriding here also keeps the real
        // Firebase-backed provider (and its `FirebaseAuth.instance`) out of
        // the widget tests.
        authOverride ??
            authStateProvider.overrideWith(
              (ref) => const Stream<AuthState>.empty(),
            ),
        friendsOverride ??
            friendsListProvider.overrideWith((ref) => controller.stream),
        remoteConfigServiceProvider.overrideWithValue(
          FakeRemoteConfigService(),
        ),
        deviceDiagnosticsServiceProvider.overrideWithValue(
          FakeDeviceDiagnosticsService(),
        ),
        urlLauncherServiceProvider.overrideWithValue(launcher),
        settlementRepositoryProvider.overrideWithValue(
          FakeSettlementRepository(),
        ),
        expenseRepositoryProvider.overrideWithValue(
          ExpenseRepository(store: _EmptyExpenseStore()),
        ),
      ],
      child: const MaterialApp(home: HomeDashboardScreen()),
    );
  }

  group('loading state', () {
    testWidgets('renders the skeleton before the first emission', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byKey(const Key('home_dashboard_skeleton')), findsOneWidget);
      // The AppBar (and its "Home" title) is gone; the greeting header
      // sits above every state instead.
      expect(find.text('Home'), findsNothing);
      expect(find.text('Namaste,'), findsOneWidget);
    });

    testWidgets('does not log home_viewed while loading', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(analytics.countOf(HomeTelemetry.viewed), 0);
    });
  });

  group('greeting header', () {
    testWidgets('shows "Namaste," with the first name when a profile is '
        'resolved', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          authOverride: authStateProvider.overrideWith(
            (ref) => Stream<AuthState>.value(
              AuthenticatedWithProfile(
                uid: 'uid-me',
                user: _user('Priya Sharma'),
              ),
            ),
          ),
        ),
      );
      controller.add(const []);
      await tester.pumpAndSettle();

      expect(find.text('Namaste,'), findsOneWidget);
      // First name only — not the full display name.
      expect(find.text('Priya'), findsOneWidget);
      expect(find.text('Priya Sharma'), findsNothing);
    });

    testWidgets('omits the name (no crash) when no profile is available', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      controller.add(const []);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Namaste,'), findsOneWidget);
    });

    testWidgets('search button is labelled and shows a "coming soon" '
        'SnackBar', (tester) async {
      await tester.pumpWidget(buildSubject());
      controller.add(const []);
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Search'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Search'));
      await tester.pump();

      expect(find.text('Search is coming soon.'), findsOneWidget);
    });
  });

  group('empty state', () {
    testWidgets('renders the designed empty composition when no non-zero '
        'balances', (tester) async {
      await tester.pumpWidget(buildSubject());
      controller.add(const []);
      await tester.pumpAndSettle();

      expect(find.text("You're all settled up"), findsOneWidget);
      expect(find.text("Let's split your first bill"), findsOneWidget);
      expect(find.text('Add an expense'), findsOneWidget);
      expect(find.text('Invite a friend'), findsOneWidget);
      // The settled-up zero hero shows ₹0.00 via formatInrFromPaise.
      expect(find.text('₹0.00'), findsOneWidget);
    });

    testWidgets('all-settled friendships still render the empty state', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      controller.add([
        _item(
          friendshipId: 'uid-a_uid-me',
          otherUserId: 'uid-a',
          displayName: 'Aarav',
          netBalancePaise: 0,
        ),
      ]);
      await tester.pumpAndSettle();

      expect(find.text("Let's split your first bill"), findsOneWidget);
    });

    testWidgets('logs home_viewed with zero state once', (tester) async {
      await tester.pumpWidget(buildSubject());
      controller.add(const []);
      await tester.pumpAndSettle();

      expect(analytics.countOf(HomeTelemetry.viewed), 1);
      expect(analytics.lastParamsFor(HomeTelemetry.viewed), {
        HomeTelemetry.paramNetBalanceState: HomeTelemetry.netBalanceStateZero,
      });
    });

    testWidgets('empty CTA logs home_empty_cta_tapped and opens the picker', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      controller.add(const []);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Add an expense'));
      await tester.tap(find.text('Add an expense'));
      await tester.pumpAndSettle();

      expect(analytics.countOf(HomeTelemetry.emptyCtaTapped), 1);
    });
  });

  group('populated state', () {
    testWidgets('positive net renders "Overall, you are owed" + amount', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      controller.add([
        _item(
          friendshipId: 'uid-a_uid-me',
          otherUserId: 'uid-a',
          displayName: 'Aarav',
          netBalancePaise: 150000,
        ),
      ]);
      await tester.pumpAndSettle();

      expect(find.text('Overall, you are owed'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(NetBalanceHeaderCard),
          matching: find.text('₹1,500.00'),
        ),
        findsOneWidget,
      );
      expect(find.text('Top balances'), findsOneWidget);
      expect(find.byType(SpendingBreakdownCard), findsOneWidget);
    });

    testWidgets('section titles are exposed as accessibility headers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(buildSubject());
      controller.add([
        _item(
          friendshipId: 'uid-a_uid-me',
          otherUserId: 'uid-a',
          displayName: 'Aarav',
          netBalancePaise: 5000,
        ),
      ]);
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.text('Top balances')).flagsCollection.isHeader,
        isTrue,
      );
      expect(
        tester.getSemantics(find.text('This Month')).flagsCollection.isHeader,
        isTrue,
      );
      handle.dispose();
    });

    testWidgets('negative net renders "Overall, you owe" + absolute amount', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      controller.add([
        _item(
          friendshipId: 'uid-a_uid-me',
          otherUserId: 'uid-a',
          displayName: 'Aarav',
          netBalancePaise: -25000,
        ),
      ]);
      await tester.pumpAndSettle();

      expect(find.text('Overall, you owe'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(NetBalanceHeaderCard),
          matching: find.text('₹250.00'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('zero net with offsetting balances renders the settled '
        'header AND the tiles (Edge Case 1)', (tester) async {
      await tester.pumpWidget(buildSubject());
      controller.add([
        _item(
          friendshipId: 'uid-a_uid-me',
          otherUserId: 'uid-a',
          displayName: 'Aarav',
          netBalancePaise: 1000,
        ),
        _item(
          friendshipId: 'uid-b_uid-me',
          otherUserId: 'uid-b',
          displayName: 'Bina',
          netBalancePaise: -1000,
        ),
      ]);
      await tester.pumpAndSettle();

      expect(find.text("You're all settled up — high five!"), findsOneWidget);
      expect(find.text('Aarav'), findsOneWidget);
      expect(find.text('Bina'), findsOneWidget);
      // AC-3: a populated-but-overall-settled dashboard still emits the
      // zero net_balance_state token (distinct from the empty-state path
      // which also emits zero but renders no tiles).
      expect(analytics.countOf(HomeTelemetry.viewed), 1);
      expect(analytics.lastParamsFor(HomeTelemetry.viewed), {
        HomeTelemetry.paramNetBalanceState: HomeTelemetry.netBalanceStateZero,
      });
    });

    testWidgets('logs home_viewed once with the positive state', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      controller.add([
        _item(
          friendshipId: 'uid-a_uid-me',
          otherUserId: 'uid-a',
          displayName: 'Aarav',
          netBalancePaise: 5000,
        ),
      ]);
      await tester.pumpAndSettle();

      expect(analytics.countOf(HomeTelemetry.viewed), 1);
      expect(analytics.lastParamsFor(HomeTelemetry.viewed), {
        HomeTelemetry.paramNetBalanceState:
            HomeTelemetry.netBalanceStatePositive,
      });
    });

    testWidgets('tapping a tile logs home_tile_tapped (hashed id) and '
        'navigates to Friend Detail', (tester) async {
      await tester.pumpWidget(buildSubject());
      controller.add([
        _item(
          friendshipId: 'uid-a_uid-me',
          otherUserId: 'uid-a',
          displayName: 'Aarav',
          netBalancePaise: 5000,
        ),
      ]);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Aarav'));
      await tester.pumpAndSettle();

      expect(find.byType(FriendDetailScreen), findsOneWidget);
      expect(analytics.countOf(HomeTelemetry.tileTapped), 1);
      final params = analytics.lastParamsFor(HomeTelemetry.tileTapped)!;
      expect(
        params[HomeTelemetry.paramContextType],
        HomeTelemetry.contextTypeFriend,
      );
      expect(
        params[HomeTelemetry.paramContextIdHash],
        hashFriendshipId('uid-a_uid-me'),
      );
    });

    testWidgets('tapping Settle Up logs home_settle_up_tapped and opens '
        'the settle-up sheet', (tester) async {
      await tester.pumpWidget(buildSubject());
      controller.add([
        _item(
          friendshipId: 'uid-a_uid-me',
          otherUserId: 'uid-a',
          displayName: 'Aarav',
          netBalancePaise: -7500,
        ),
      ]);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settle Up'));
      await tester.pumpAndSettle();

      expect(find.byType(SettleUpBottomSheet), findsOneWidget);
      expect(analytics.countOf(HomeTelemetry.settleUpTapped), 1);
      final params = analytics.lastParamsFor(HomeTelemetry.settleUpTapped)!;
      expect(
        params[HomeTelemetry.paramContextType],
        HomeTelemetry.contextTypeFriend,
      );
      expect(
        params[HomeTelemetry.paramContextIdHash],
        hashFriendshipId('uid-a_uid-me'),
      );
      expect(params[HomeTelemetry.paramAmountRange], 'under_500');
    });

    testWidgets('settle-up sheet receives the home_dashboard source', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      controller.add([
        _item(
          friendshipId: 'uid-a_uid-me',
          otherUserId: 'uid-a',
          displayName: 'Aarav',
          netBalancePaise: -7500,
        ),
      ]);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settle Up'));
      await tester.pumpAndSettle();

      final sheet = tester.widget<SettleUpBottomSheet>(
        find.byType(SettleUpBottomSheet),
      );
      expect(sheet.source, 'home_dashboard');
      expect(sheet.suggestedAmountPaise, 7500);
    });

    testWidgets('shows at most five top-balance rows', (tester) async {
      // One By Two targets phones only (SRS 12.3), and the Phase3b
      // top-balance row is a single line with a trailing pill-over-link
      // column. Pin the reference phone surface so the lazy ListView
      // realises the full capped set of five rows; the default 800x600
      // desktop surface would page the fifth row out of the build window.
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildSubject());
      controller.add([
        for (var i = 0; i < 7; i++)
          _item(
            friendshipId: 'uid-${i}_uid-me',
            otherUserId: 'uid-$i',
            displayName: 'Friend$i',
            netBalancePaise: (i + 1) * 1000,
          ),
      ]);
      await tester.pumpAndSettle();

      expect(find.text('Settle Up'), findsNWidgets(5));
    });

    testWidgets('Settle Up node exposes an explicit semantic tap action', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(buildSubject());
      controller.add([
        _item(
          friendshipId: 'uid-a_uid-me',
          otherUserId: 'uid-a',
          displayName: 'Aarav',
          netBalancePaise: 5000,
        ),
      ]);
      await tester.pumpAndSettle();

      final settleNode = tester.getSemantics(
        find.bySemanticsLabel(RegExp('^Settle up with')),
      );
      expect(
        settleNode.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
        reason:
            'the Settle Up node must carry SemanticsAction.tap so screen '
            'readers can activate it explicitly (ExcludeSemantics strips '
            "the inner button's action)",
      );
      handle.dispose();
    });

    testWidgets('FR-HD-03 breakdown card mounts in the dashboard scroll view', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      controller.add([
        _item(
          friendshipId: 'uid-a_uid-me',
          otherUserId: 'uid-a',
          displayName: 'Aarav',
          netBalancePaise: 5000,
        ),
      ]);
      await tester.pumpAndSettle();

      expect(find.byType(SpendingBreakdownCard), findsOneWidget);
      // The empty / populated card carries no per-segment drill-down
      // (SCR-06 Edge Case 5); detailed sub-state coverage lives in
      // spending_breakdown_card_test.dart.
      expect(
        find.descendant(
          of: find.byType(SpendingBreakdownCard),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
    });
  });

  group('shell navigation', () {
    ProviderContainer containerFor(WidgetTester tester) {
      return ProviderScope.containerOf(
        tester.element(find.byType(HomeDashboardScreen)),
        listen: false,
      );
    }

    testWidgets('tapping the avatar selects the Profile tab (index 4)', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      controller.add(const []);
      await tester.pumpAndSettle();

      // Keep the autoDispose nav controller alive across the tap + read.
      final container = containerFor(tester);
      final sub = container.listen(
        shellNavigationControllerProvider,
        (_, _) {},
      );
      addTearDown(sub.close);

      await tester.tap(find.bySemanticsLabel('Profile'));
      await tester.pump();

      expect(container.read(shellNavigationControllerProvider), 4);
    });

    testWidgets('tapping "See all" selects the Friends tab (index 1)', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      controller.add([
        _item(
          friendshipId: 'uid-a_uid-me',
          otherUserId: 'uid-a',
          displayName: 'Aarav',
          netBalancePaise: 5000,
        ),
      ]);
      await tester.pumpAndSettle();

      final container = containerFor(tester);
      final sub = container.listen(
        shellNavigationControllerProvider,
        (_, _) {},
      );
      addTearDown(sub.close);

      expect(find.text('See all'), findsOneWidget);
      await tester.tap(find.text('See all'));
      await tester.pump();

      expect(container.read(shellNavigationControllerProvider), 1);
    });
  });

  group('error state', () {
    testWidgets('renders error copy + code on stream error', (tester) async {
      await tester.pumpWidget(buildSubject());
      controller.addError(Exception('Firestore down'));
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Error code: HD-FIRESTORE-READ'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Contact Support'), findsOneWidget);
    });

    testWidgets('logs home_viewed with error state once', (tester) async {
      await tester.pumpWidget(buildSubject());
      controller.addError(Exception('boom'));
      await tester.pumpAndSettle();

      expect(analytics.countOf(HomeTelemetry.viewed), 1);
      expect(analytics.lastParamsFor(HomeTelemetry.viewed), {
        HomeTelemetry.paramNetBalanceState: HomeTelemetry.netBalanceStateError,
      });
    });

    testWidgets('Retry logs home_error_retry_tapped with attempt_number', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      controller.addError(Exception('boom'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(analytics.countOf(HomeTelemetry.errorRetryTapped), 1);
      expect(analytics.lastParamsFor(HomeTelemetry.errorRetryTapped), {
        HomeTelemetry.paramAttemptNumber: 1,
      });
    });

    testWidgets('second retry increments attempt_number and shows the '
        '"still not working" copy', (tester) async {
      // An always-erroring stream so each invalidate re-enters the error
      // state — exercising the showSecondTryCopy branch and attempt 2.
      await tester.pumpWidget(
        buildSubject(
          friendsOverride: friendsListProvider.overrideWith(
            (ref) => Stream<List<FriendListItem>>.error(Exception('boom')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // First error render uses the first-try copy.
      expect(
        find.textContaining('We could not load your balances'),
        findsOneWidget,
      );

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      // After the first retry the copy escalates.
      expect(find.textContaining('Still not working'), findsOneWidget);
      expect(
        find.textContaining('We could not load your balances'),
        findsNothing,
      );

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(analytics.countOf(HomeTelemetry.errorRetryTapped), 2);
      expect(analytics.lastParamsFor(HomeTelemetry.errorRetryTapped), {
        HomeTelemetry.paramAttemptNumber: 2,
      });
    });

    testWidgets('Contact Support logs home_error_support_tapped and shows '
        'the fallback dialog when no mail client', (tester) async {
      launcher.canLaunchResult = false;
      await tester.pumpWidget(buildSubject());
      controller.addError(Exception('boom'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Contact Support'));
      await tester.pumpAndSettle();

      expect(analytics.countOf(HomeTelemetry.errorSupportTapped), 1);
      expect(analytics.lastParamsFor(HomeTelemetry.errorSupportTapped), {
        HomeTelemetry.paramErrorCode: HomeTelemetry.errorCodeFirestoreRead,
      });
      expect(find.byType(ContactSupportFallbackDialog), findsOneWidget);
    });
  });
}
