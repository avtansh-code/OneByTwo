@Tags(['golden'])
library;

// DC-09 — golden scaffolds for the converted Activity feed (Haldi 25, a hero)
// and the in-app notification banner (Haldi 26, a non-hero surface).
//
// Queues the four Activity states in light + dark (04-qa-test-strategy.md
// §A.6: a hero gets both brightnesses for every state — loading-skeleton,
// empty, populated, error) and the in-app banner per-type in light (§A.6: a
// non-hero converted surface gets light goldens).
//
// This group is ENABLED, consistent with DC-01..DC-08: the pixel
// comparison runs and is no longer skipped. Determinism comes from the
// bundled OFL fonts (Bricolage Grotesque + Hanken Grotesk), loaded once
// via `loadHaldiFonts` in `golden_harness.dart` and served to google_fonts
// through its test http seam, so the real Haldi type ramp rasterises
// identically offline. Baselines are authored on ubuntu-latest via the
// manual `golden-refresh` workflow and committed under `goldens/`; the
// `golden-a11y-checks` CI job (pinned Flutter version) compares against
// them on every PR and fails on any unintended pixel diff
// (04-qa-test-strategy.md sections A.2.2 and E). The load-bearing
// per-screen widget tests (activity_feed_screen_test.dart,
// activity_haldi_reskin_test.dart, the banner/dialog widget tests,
// notifications_haldi_reskin_test.dart) + the no-`Color(0x…)` grep also
// run for real.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/features/activity/data/activity_feed_repository.dart';
import 'package:onebytwo/features/activity/domain/activity_feed_item.dart';
import 'package:onebytwo/features/activity/presentation/activity_feed_screen.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/domain/user_model.dart';
import 'package:onebytwo/features/friends/application/friends_list_provider.dart';
import 'package:onebytwo/features/friends/application/user_profile_provider.dart';
import 'package:onebytwo/features/notifications/domain/notification_payload.dart';
import 'package:onebytwo/features/notifications/presentation/widgets/in_app_notification_banner.dart';

import '../features/activity/helpers/fake_services.dart';
import '../features/notifications/helpers/fake_payloads.dart';
import 'golden_harness.dart';

const _currentUid = 'uid-me';
const _otherUid = 'uid-other';

UserModel _user(String name) => UserModel(
  phoneNumber: '+919876543210',
  displayName: name,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Widget _feed(
  FakeActivityFeedRepository repo, {
  Map<String, UserModel?> profiles = const <String, UserModel?>{},
}) {
  return ProviderScope(
    overrides: <Override>[
      activityFeedRepositoryProvider.overrideWithValue(repo),
      analyticsServiceProvider.overrideWithValue(RecordingAnalytics()),
      currentUserIdProvider.overrideWithValue(_currentUid),
      userProfileProvider.overrideWith((ref, uid) async => profiles[uid]),
    ],
    child: const ActivityFeedScreen(),
  );
}

Widget _banner(NotificationPayload payload) {
  return Scaffold(
    body: Align(
      alignment: Alignment.topCenter,
      child: InAppNotificationBanner(
        payload: payload,
        onTap: (_) {},
        onDismiss: () {},
      ),
    ),
  );
}

void main() {
  group('DC-09 Activity + Notifications goldens', () {
    // ---- Activity feed 25 (a hero — light + dark) ----
    for (final brightness in Brightness.values) {
      final mode = brightness == Brightness.light ? 'light' : 'dark';
      final activityStates = <String, FakeActivityFeedRepository>{
        'loading': FakeActivityFeedRepository(keepLoading: true),
        'empty': FakeActivityFeedRepository(),
        'populated': FakeActivityFeedRepository(
          items: <ActivityFeedItem>[fakeExpenseAdded(), fakeSettlement()],
        ),
        'error': FakeActivityFeedRepository()..streamError = Exception('READ'),
      };
      for (final entry in activityStates.entries) {
        testWidgets('activity ${entry.key} ($mode)', (tester) async {
          await loadHaldiFonts();
          await pumpForGolden(
            tester,
            _feed(
              entry.value,
              profiles: <String, UserModel?>{_otherUid: _user('Priya')},
            ),
            brightness: brightness,
          );
          expectGoldenState(entry.key, errorText: 'Something went wrong');
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/dc09/activity_${entry.key}_$mode.png'),
          );
        });
      }
    }

    // ---- In-app banner 26 (a non-hero — light only) ----
    final bannerStates = <String, NotificationType>{
      'expense': NotificationType.expenseAdded,
      'settlement': NotificationType.settlementReceived,
      'reminder': NotificationType.reminder,
    };
    for (final entry in bannerStates.entries) {
      testWidgets('banner ${entry.key} (light)', (tester) async {
        await loadHaldiFonts();
        await pumpForGolden(
          tester,
          _banner(notificationPayload(type: entry.value)),
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/dc09/banner_${entry.key}_light.png'),
        );
      });
    }
  });
}
