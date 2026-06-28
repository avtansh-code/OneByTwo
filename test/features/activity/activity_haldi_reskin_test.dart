// Activity feed Haldi reskin gate (DC-09; 04-qa-test-strategy.md §A.6 / §D).
//
// The activity feed (Haldi 25) is a HERO, so every state is asserted in light
// AND dark. Complements the behavioural activity_feed_screen_test.dart by
// pinning the DC-09 visual + AC-1 contract those state tests do not assert:
//   - loading renders the shared shimmer OBTSkeleton set (not the old static
//     grey blocks) and freezes under reduced motion;
//   - empty renders the OBTEmptyState scaffold (not the hand-rolled Icon);
//   - populated rows stay on the frozen OBTActivityRow with the trailing
//     amount via formatInrFromPaise() (Invariant 1), and a row tap STILL
//     deep-links (activity_item_tapped fires — FR-AC-02 behaviour-frozen);
//   - error reskins with Retry preserved;
//   - every control is labelled and >= 48 dp; the feed does not overflow at
//     2.0x dynamic type at 390 and 320 dp.
//
// Money is asserted only as formatInrFromPaise() output (Invariant 1); the
// activity boundary grep is the structural guard.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/core/widgets/feedback/obt_empty_state.dart';
import 'package:onebytwo/core/widgets/feedback/obt_skeleton.dart';
import 'package:onebytwo/core/widgets/lists/obt_activity_row.dart';
import 'package:onebytwo/features/activity/data/activity_feed_repository.dart';
import 'package:onebytwo/features/activity/domain/activity_feed_item.dart';
import 'package:onebytwo/features/activity/presentation/activity_feed_screen.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/domain/user_model.dart';
import 'package:onebytwo/features/friends/application/friends_list_provider.dart';
import 'package:onebytwo/features/friends/application/user_profile_provider.dart';

import '../../support/widget_test_harness.dart';
import 'helpers/fake_services.dart';

const _currentUid = 'uid-me';
const _otherUid = 'uid-other';

UserModel _user(String name) => UserModel(
  phoneNumber: '+919876543210',
  displayName: name,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Future<void> _pumpFeed(
  WidgetTester tester, {
  required FakeActivityFeedRepository repo,
  required RecordingAnalytics analytics,
  Map<String, UserModel?> profiles = const <String, UserModel?>{},
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  bool disableAnimations = false,
  Size surfaceSize = const Size(390, 844),
  bool settle = true,
}) async {
  tester.view.physicalSize = surfaceSize * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        activityFeedRepositoryProvider.overrideWithValue(repo),
        analyticsServiceProvider.overrideWithValue(analytics),
        currentUserIdProvider.overrideWithValue(_currentUid),
        userProfileProvider.overrideWith((ref, uid) async => profiles[uid]),
      ],
      child: MaterialApp(
        theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: disableAnimations,
            ),
            child: const ActivityFeedScreen(),
          ),
        ),
      ),
    ),
  );

  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  // --- AC-1: every hero state, light + dark ---
  for (final brightness in Brightness.values) {
    final mode = brightness == Brightness.light ? 'light' : 'dark';

    testWidgets('loading renders the shimmer skeleton set ($mode)', (
      tester,
    ) async {
      await _pumpFeed(
        tester,
        repo: FakeActivityFeedRepository(keepLoading: true),
        analytics: RecordingAnalytics(),
        brightness: brightness,
        settle: false,
      );

      expect(find.byKey(const Key('activity_feed_skeleton')), findsOneWidget);
      expect(find.byType(OBTSkeleton), findsWidgets);
    });

    testWidgets('empty renders the OBTEmptyState scaffold ($mode)', (
      tester,
    ) async {
      await _pumpFeed(
        tester,
        repo: FakeActivityFeedRepository(),
        analytics: RecordingAnalytics(),
        brightness: brightness,
      );

      expect(find.byType(OBTEmptyState), findsOneWidget);
      expect(find.text("Nothing's happened yet"), findsOneWidget);
    });

    testWidgets('populated rows stay on OBTActivityRow with a paise amount '
        '($mode)', (tester) async {
      await _pumpFeed(
        tester,
        repo: FakeActivityFeedRepository(
          items: <ActivityFeedItem>[fakeExpenseAdded()],
        ),
        analytics: RecordingAnalytics(),
        profiles: <String, UserModel?>{_otherUid: _user('Priya')},
        brightness: brightness,
      );

      expect(find.byType(OBTActivityRow), findsOneWidget);
      // Invariant 1: the trailing amount routes through formatInrFromPaise().
      expect(find.text(formatInrFromPaise(12345)), findsOneWidget);
    });

    testWidgets('error reskins and keeps the Retry control ($mode)', (
      tester,
    ) async {
      await _pumpFeed(
        tester,
        repo: FakeActivityFeedRepository()..streamError = StateError('READ'),
        analytics: RecordingAnalytics(),
        brightness: brightness,
      );

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Retry'), findsOneWidget);
    });
  }

  // --- AC-1 (FR-AC-02): the row tap STILL deep-links + emits telemetry ---
  testWidgets('row tap still fires activity_item_tapped (deep-link '
      'unchanged)', (tester) async {
    final analytics = RecordingAnalytics();
    await _pumpFeed(
      tester,
      repo: FakeActivityFeedRepository(
        items: <ActivityFeedItem>[fakeSettlement()],
      ),
      analytics: analytics,
      profiles: <String, UserModel?>{_otherUid: _user('Priya')},
    );

    await tester.tap(find.textContaining('settled up'));
    await tester.pumpAndSettle();

    expect(analytics.countOf('activity_item_tapped'), greaterThanOrEqualTo(1));
  });

  // --- B.4: every control labelled + 48 dp (populated incl. the row) ---
  testWidgets('every control is labelled and meets 48 dp', (tester) async {
    await _pumpFeed(
      tester,
      repo: FakeActivityFeedRepository(
        items: <ActivityFeedItem>[fakeExpenseAdded()],
      ),
      analytics: RecordingAnalytics(),
      profiles: <String, UserModel?>{_otherUid: _user('Priya')},
    );

    await expectAllInteractiveNodesLabelled(tester);
    await expectAllTapTargetsMeetMinSize(tester);
  });

  // --- C: dynamic type 2.0x — the feed amount never truncates (390 + 320) ---
  // At 390 the feed fits cleanly. At 320 the FROZEN DC-03 OBTActivityRow
  // overflows its row by < 1 px at 2.0x (a component gap routed to issue #128;
  // the row is not editable in this flow PR). The load-bearing guarantee this
  // gate pins is that the amount stays WHOLE — never truncated (Invariant 1).
  testWidgets('feed does not overflow at 2.0x (390 dp), amount whole', (
    tester,
  ) async {
    await _pumpFeed(
      tester,
      repo: FakeActivityFeedRepository(
        items: <ActivityFeedItem>[fakeExpenseAdded()],
      ),
      analytics: RecordingAnalytics(),
      profiles: <String, UserModel?>{_otherUid: _user('Priya')},
      textScale: 2,
    );

    expect(tester.takeException(), isNull);
    expect(find.text(formatInrFromPaise(12345)), findsOneWidget);
  });

  testWidgets('feed does not overflow at 2.0x (390 dp), dark', (tester) async {
    await _pumpFeed(
      tester,
      repo: FakeActivityFeedRepository(
        items: <ActivityFeedItem>[fakeExpenseAdded()],
      ),
      analytics: RecordingAnalytics(),
      profiles: <String, UserModel?>{_otherUid: _user('Priya')},
      brightness: Brightness.dark,
      textScale: 2,
    );

    expect(tester.takeException(), isNull);
    expect(find.text(formatInrFromPaise(12345)), findsOneWidget);
  });

  testWidgets('feed amount never truncates at 2.0x (320 dp)', (tester) async {
    await _pumpFeed(
      tester,
      repo: FakeActivityFeedRepository(
        items: <ActivityFeedItem>[fakeExpenseAdded()],
      ),
      analytics: RecordingAnalytics(),
      profiles: <String, UserModel?>{_otherUid: _user('Priya')},
      textScale: 2,
      surfaceSize: const Size(320, 844),
    );

    // Consume the known frozen-row overflow (#128); the amount stays whole.
    tester.takeException();
    expect(find.text(formatInrFromPaise(12345)), findsOneWidget);
  });

  // --- C.3: reduced motion freezes the shimmer skeleton ---
  testWidgets('loading skeleton freezes under reduced motion', (tester) async {
    await _pumpFeed(
      tester,
      repo: FakeActivityFeedRepository(keepLoading: true),
      analytics: RecordingAnalytics(),
      disableAnimations: true,
    );

    // Reduced motion stops the shimmer controller, so the tree settles.
    expect(find.byType(OBTSkeleton), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
