// FR-PR-03 NotificationPreferencesScreen widget tests.
//
// Verifies the SCR-27 screen renders three toggle rows, single-fires
// telemetry on mount, surfaces the load/error states from the
// controller, and shows the OS-permission banner when the
// `notificationPermissionControllerProvider` reports `denied` or
// `permanentlyDenied`. AC-11 graceful-degradation: per architect §2.4
// fallback, since `firebase_messaging: ^16.2.0` does NOT expose
// `openAppNotificationSettings()` on either platform, the banner SHIPS
// WITHOUT the button. The test asserts the banner copy and the
// absence of the button.

// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/application/auth_state_provider.dart';
import 'package:onebytwo/features/auth/data/user_repository.dart';
import 'package:onebytwo/features/auth/domain/auth_state.dart';
import 'package:onebytwo/features/auth/domain/user_model.dart';
import 'package:onebytwo/features/notifications/application/notification_permission_controller.dart';
import 'package:onebytwo/features/profile/application/notification_preferences_controller.dart';
import 'package:onebytwo/features/profile/application/notification_preferences_telemetry.dart';
import 'package:onebytwo/features/profile/presentation/notification_preferences_screen.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeAnalyticsService implements AnalyticsService {
  final List<({String name, Map<String, Object>? parameters})> events =
      <({String name, Map<String, Object>? parameters})>[];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    events.add((name: name, parameters: parameters));
  }
}

class _FakeUserRepository implements UserRepository {
  UserModel? userToReturn;
  Exception? throwOnGet;

  final List<({String uid, Map<String, bool> prefs})> updateCalls =
      <({String uid, Map<String, bool> prefs})>[];
  Exception? throwOnUpdate;

  @override
  Future<UserModel?> getUser(String uid) async {
    if (throwOnGet != null) throw throwOnGet!;
    return userToReturn;
  }

  @override
  Future<void> updateNotificationPrefs({
    required String uid,
    required Map<String, bool> prefs,
  }) async {
    updateCalls.add((uid: uid, prefs: Map<String, bool>.from(prefs)));
    if (throwOnUpdate != null) throw throwOnUpdate!;
  }

  @override
  Future<void> createUser({
    required String uid,
    required String displayName,
    required String phoneNumber,
    String? photoUrl,
  }) async => throw UnimplementedError();

  @override
  Future<String> uploadAvatar(String uid, String filePath) async =>
      throw UnimplementedError();

  @override
  Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? photoUrl,
    bool removePhoto = false,
  }) async => throw UnimplementedError();

  @override
  Future<void> deleteAvatar(String uid) async => throw UnimplementedError();
}

class _StubPermissionController extends NotificationPermissionController {
  _StubPermissionController(this._initial);
  final PermissionState _initial;

  @override
  PermissionState build() => _initial;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _uid = 'uid-test';

UserModel _userWithPrefs(Map<String, bool> prefs) {
  return UserModel(
    phoneNumber: '+919876543210',
    displayName: 'Test User',
    createdAt: DateTime(2025),
    updatedAt: DateTime(2025),
    notificationPrefs: prefs,
  );
}

Widget _buildSubject({
  required _FakeUserRepository repository,
  required _FakeAnalyticsService analytics,
  PermissionState permissionState = PermissionState.granted,
}) {
  return ProviderScope(
    overrides: [
      userRepositoryProvider.overrideWithValue(repository),
      analyticsServiceProvider.overrideWithValue(analytics),
      authStateNotifierProvider.overrideWith(
        (ref) => Stream<AuthState>.value(
          AuthenticatedWithProfile(
            uid: _uid,
            user:
                repository.userToReturn ??
                _userWithPrefs({
                  'newExpense': true,
                  'settlement': true,
                  'reminder': true,
                }),
          ),
        ),
      ),
      notificationPermissionControllerProvider.overrideWith(
        () => _StubPermissionController(permissionState),
      ),
    ],
    child: const MaterialApp(home: NotificationPreferencesScreen()),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('NotificationPreferencesScreen — populated state', () {
    testWidgets('renders three toggle rows with SCR-27 labels', (tester) async {
      final repo = _FakeUserRepository()
        ..userToReturn = _userWithPrefs({
          'newExpense': true,
          'settlement': false,
          'reminder': true,
        });
      final analytics = _FakeAnalyticsService();

      await tester.pumpWidget(
        _buildSubject(repository: repo, analytics: analytics),
      );
      await tester.pumpAndSettle();

      expect(find.text('New Expenses'), findsOneWidget);
      expect(find.text('Settlements'), findsOneWidget);
      expect(find.text('Reminders'), findsOneWidget);

      // Descriptions per SCR-27 §Toggle Mapping.
      expect(
        find.text('Get notified when someone adds an expense involving you.'),
        findsOneWidget,
      );
      expect(
        find.text('Get notified when someone records a payment involving you.'),
        findsOneWidget,
      );
      expect(
        find.text('Receive reminders about outstanding balances.'),
        findsOneWidget,
      );

      // Three switches — values reflect persisted state.
      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches.length, 3);
      // Persisted values: newExpense=true, settlement=false, reminder=true.
      final values = switches.map((s) => s.value).toList();
      expect(values, [true, false, true]);
    });

    testWidgets('renders the SCR-27 app bar title', (tester) async {
      final repo = _FakeUserRepository()
        ..userToReturn = _userWithPrefs({
          'newExpense': true,
          'settlement': true,
          'reminder': true,
        });

      await tester.pumpWidget(
        _buildSubject(repository: repo, analytics: _FakeAnalyticsService()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notification Preferences'), findsOneWidget);
    });
  });

  group('NotificationPreferencesScreen — loading state', () {
    testWidgets('renders a progress indicator while loading', (tester) async {
      // The fake's getUser completes on a microtask — pump zero so we
      // observe the loading state before the future resolves.
      final repo = _FakeUserRepository()
        ..userToReturn = _userWithPrefs({
          'newExpense': true,
          'settlement': true,
          'reminder': true,
        });
      final analytics = _FakeAnalyticsService();

      await tester.pumpWidget(
        _buildSubject(repository: repo, analytics: analytics),
      );
      // No pumpAndSettle — assert the loading frame.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('NotificationPreferencesScreen — error state (AC-8)', () {
    testWidgets('renders error copy + Retry button when getUser throws', (
      tester,
    ) async {
      final repo = _FakeUserRepository()
        ..throwOnGet = Exception('Firestore offline');
      final analytics = _FakeAnalyticsService();

      await tester.pumpWidget(
        _buildSubject(repository: repo, analytics: analytics),
      );
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Could not load your preferences.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('NotificationPreferencesScreen — telemetry', () {
    testWidgets('notification_prefs_viewed fires exactly once on mount', (
      tester,
    ) async {
      final repo = _FakeUserRepository()
        ..userToReturn = _userWithPrefs({
          'newExpense': true,
          'settlement': true,
          'reminder': true,
        });
      final analytics = _FakeAnalyticsService();

      await tester.pumpWidget(
        _buildSubject(repository: repo, analytics: analytics),
      );
      await tester.pumpAndSettle();

      // Force a rebuild to confirm single-fire discipline.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      final viewed = analytics.events
          .where((e) => e.name == notificationPrefsViewedEvent)
          .toList();
      expect(viewed.length, 1);
      expect(viewed.single.parameters, anyOf([isNull, isEmpty]));
    });
  });

  group('NotificationPreferencesScreen — tap optimistic flip', () {
    testWidgets('tapping the Reminders switch flips it immediately', (
      tester,
    ) async {
      final repo = _FakeUserRepository()
        ..userToReturn = _userWithPrefs({
          'newExpense': true,
          'settlement': true,
          'reminder': true,
        });
      final analytics = _FakeAnalyticsService();

      await tester.pumpWidget(
        _buildSubject(repository: repo, analytics: analytics),
      );
      await tester.pumpAndSettle();

      // Tap the Reminders row's switch (third in render order).
      final remindersSwitch = find.byType(Switch).at(2);
      await tester.tap(remindersSwitch);
      // Pump zero so we observe the OPTIMISTIC state before the
      // 500 ms debounce fires.
      await tester.pump();

      final updatedSwitches = tester
          .widgetList<Switch>(find.byType(Switch))
          .toList();
      expect(updatedSwitches[2].value, isFalse);
    });
  });

  group('NotificationPreferencesScreen — OS-permission banner', () {
    testWidgets('AC-11: banner shows the architect-ratified copy when denied', (
      tester,
    ) async {
      final repo = _FakeUserRepository()
        ..userToReturn = _userWithPrefs({
          'newExpense': true,
          'settlement': true,
          'reminder': true,
        });

      await tester.pumpWidget(
        _buildSubject(
          repository: repo,
          analytics: _FakeAnalyticsService(),
          permissionState: PermissionState.denied,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Notifications are turned off for this app. '
          'Enable them in your device settings to receive alerts.',
        ),
        findsOneWidget,
      );

      // Architect §2.4 fallback: firebase_messaging: ^16.2.0 does NOT
      // expose openAppNotificationSettings() on either platform. Ship
      // the banner without the button — graceful degradation per
      // §2.4 / §2.10 reconciliation 3. The "Open Settings" CTA is
      // EXPECTED ABSENT in v1.0.
      expect(find.text('Open Settings'), findsNothing);
    });

    testWidgets('AC-11: banner shows the same copy when permanentlyDenied', (
      tester,
    ) async {
      final repo = _FakeUserRepository()
        ..userToReturn = _userWithPrefs({
          'newExpense': true,
          'settlement': true,
          'reminder': true,
        });

      await tester.pumpWidget(
        _buildSubject(
          repository: repo,
          analytics: _FakeAnalyticsService(),
          permissionState: PermissionState.permanentlyDenied,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Notifications are turned off for this app. '
          'Enable them in your device settings to receive alerts.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('AC-12: banner is HIDDEN when permission state is granted', (
      tester,
    ) async {
      final repo = _FakeUserRepository()
        ..userToReturn = _userWithPrefs({
          'newExpense': true,
          'settlement': true,
          'reminder': true,
        });

      await tester.pumpWidget(
        _buildSubject(
          repository: repo,
          analytics: _FakeAnalyticsService(),
          // granted is the default for _buildSubject — documenting AC-12
          // intent via the test name; ignoring the lint to keep the
          // permission state explicit at the call site.
          // ignore: avoid_redundant_argument_values
          permissionState: PermissionState.granted,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Notifications are turned off for this app. '
          'Enable them in your device settings to receive alerts.',
        ),
        findsNothing,
      );
    });
  });
}
