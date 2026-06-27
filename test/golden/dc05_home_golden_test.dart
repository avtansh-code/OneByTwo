@Tags(['golden'])
library;

// DC-05 — golden scaffolds for the converted Home dashboard (Haldi 6).
//
// Queues the four SCR-06 states (loading-skeleton, empty illustration,
// populated, error) in light + dark — Home 6 is a hero with money on
// screen, so every state needs both brightnesses (04 section A.5/A.6).
//
// This group is ENABLED, consistent with DC-01..DC-04: the pixel
// comparison runs and is no longer skipped. Determinism comes from the
// bundled OFL fonts (Bricolage Grotesque + Hanken Grotesk), loaded once
// via `loadHaldiFonts` in `golden_harness.dart` and served to google_fonts
// through its test http seam, so the real Haldi type ramp rasterises
// identically offline. Baselines are authored on ubuntu-latest via the
// manual `golden-refresh` workflow and committed under `goldens/`; the
// `golden-a11y-checks` CI job (pinned Flutter version) compares against
// them on every PR and fails on any unintended pixel diff
// (04-qa-test-strategy.md sections A.2.2 and E). The load-bearing
// per-screen widget tests (home_dashboard_haldi_reskin_test.dart +
// home_dashboard_screen_test.dart + spending_breakdown_card_test.dart)
// also run for real.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/core/remote_config/remote_config_service.dart';
import 'package:onebytwo/core/services/url_launcher_service.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/expenses/data/expense_repository.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';
import 'package:onebytwo/features/friends/application/friends_list_provider.dart';
import 'package:onebytwo/features/friends/domain/friend_list_item.dart';
import 'package:onebytwo/features/home/presentation/home_dashboard_screen.dart';
import 'package:onebytwo/features/profile/data/device_diagnostics_service.dart';
import 'package:onebytwo/features/profile/domain/support_diagnostics.dart';
import 'package:onebytwo/features/settlements/data/settlement_repository.dart';
import 'package:onebytwo/features/settlements/domain/settlement_doc.dart';

import 'golden_harness.dart';

class _FakeAnalytics implements AnalyticsService {
  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {}
}

class _FakeRemoteConfig implements RemoteConfigService {
  @override
  Future<void> initialise() async {}

  @override
  String getString(String key) => 'support@onebytwo.app';
}

class _FakeDeviceDiagnostics implements DeviceDiagnosticsService {
  @override
  Future<SupportDiagnostics> load() async => const SupportDiagnostics(
    appVersion: '1.0.0',
    buildNumber: '1',
    osName: 'Android',
    osVersion: '14',
    deviceModel: 'Pixel 6',
  );
}

class _FakeUrlLauncher implements UrlLauncherService {
  @override
  Future<bool> canLaunch(Uri uri) async => true;

  @override
  Future<bool> launchExternal(Uri uri) async => true;
}

class _FakeSettlementRepository implements SettlementRepository {
  @override
  Future<String> createSettlement({required SettlementDoc doc}) async => 'sid';

  @override
  Stream<List<SettlementDoc>> watchByContext({
    required String contextType,
    required String contextId,
  }) => const Stream<List<SettlementDoc>>.empty();
}

class _EmptyExpenseStore implements ExpenseStore {
  @override
  Future<List<ExpenseDoc>> fetchExpensesInMonth({
    required String friendshipId,
    required DateTime monthStartUtc,
  }) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

FriendListItem _item(int net, String name, String fid, String oid) {
  return FriendListItem(
    friendshipId: fid,
    otherUserId: oid,
    displayName: name,
    photoUrl: null,
    netBalancePaise: net,
  );
}

/// Builds a Home dashboard whose [friendsListProvider] is driven by
/// [friends] (a `Stream` so loading/error are expressible).
Widget _home(Stream<List<FriendListItem>> friends) {
  return ProviderScope(
    overrides: [
      analyticsServiceProvider.overrideWithValue(_FakeAnalytics()),
      currentUserIdProvider.overrideWithValue('uid-me'),
      friendsListProvider.overrideWith((ref) => friends),
      remoteConfigServiceProvider.overrideWithValue(_FakeRemoteConfig()),
      deviceDiagnosticsServiceProvider.overrideWithValue(
        _FakeDeviceDiagnostics(),
      ),
      urlLauncherServiceProvider.overrideWithValue(_FakeUrlLauncher()),
      settlementRepositoryProvider.overrideWithValue(
        _FakeSettlementRepository(),
      ),
      expenseRepositoryProvider.overrideWithValue(
        ExpenseRepository(store: _EmptyExpenseStore()),
      ),
    ],
    child: const HomeDashboardScreen(),
  );
}

void main() {
  final states = <String, Stream<List<FriendListItem>>>{
    // Loading: a stream that never emits keeps the skeleton on screen.
    'loading': StreamController<List<FriendListItem>>().stream,
    'empty': Stream.value(const <FriendListItem>[]),
    'populated': Stream.value(<FriendListItem>[
      _item(425000, 'Rahul Sharma', 'uid-r_uid-me', 'uid-r'),
      _item(-210000, 'Goa Trip 2026', 'uid-g_uid-me', 'uid-g'),
      _item(120000, 'Aditya Menon', 'uid-a_uid-me', 'uid-a'),
    ]),
    'error': Stream<List<FriendListItem>>.error(Exception('HD-FIRESTORE-READ')),
  };

  group('DC-05 Home dashboard goldens', () {
    for (final entry in states.entries) {
      for (final brightness in Brightness.values) {
        final mode = brightness == Brightness.light ? 'light' : 'dark';
        testWidgets('${entry.key} ($mode)', (tester) async {
          await loadHaldiFonts();
          await pumpForGolden(
            tester,
            _home(entry.value),
            brightness: brightness,
          );
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/dc05/${entry.key}_$mode.png'),
          );
        });
      }
    }
  });
}
