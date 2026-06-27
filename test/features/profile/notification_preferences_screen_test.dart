// FR-PR-03 NotificationPreferencesScreen widget tests.
//
// Verifies the SCR-27 screen renders three toggle rows, single-fires
// telemetry on mount, surfaces the load/error states from the
// controller, and shows the OS-permission banner when the
// `notificationPermissionControllerProvider` reports `denied` or
// `permanentlyDenied`. AC-11: the banner carries an "Open Settings"
// CTA that deep-links to the OS notification settings via a faked
// `appSettingsServiceProvider`; tapping it logs a PII-free
// `permission_settings_opened` (surface=notifications) event. The
// banner (and its button) are absent when permission is `granted`.

// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/core/connectivity/connectivity_provider.dart';
import 'package:onebytwo/core/services/app_settings_service.dart';
import 'package:onebytwo/core/telemetry/permission_settings_telemetry.dart';
import 'package:onebytwo/core/widgets/feedback/obt_skeleton.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/application/auth_state_provider.dart';
import 'package:onebytwo/features/auth/data/user_repository.dart';
import 'package:onebytwo/features/auth/domain/auth_state.dart';
import 'package:onebytwo/features/auth/domain/user_model.dart';
import 'package:onebytwo/features/notifications/application/notification_permission_controller.dart';
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

class _FakeAppSettingsService implements AppSettingsService {
  _FakeAppSettingsService({this.throwOnOpen = false});

  final bool throwOnOpen;
  int notificationCalls = 0;
  int appSettingsCalls = 0;

  @override
  Future<void> openNotificationSettings() async {
    notificationCalls++;
    if (throwOnOpen) throw Exception('settings unavailable');
  }

  @override
  Future<void> openAppSettings() async {
    appSettingsCalls++;
    if (throwOnOpen) throw Exception('settings unavailable');
  }
}

class _FakeUserRepository implements UserRepository {
  @override
  Future<void> updatePhoneNumber({
    required String uid,
    required String phoneNumber,
  }) async {}

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
  IsOnline? isOnline,
  AuthState? authState,
  AppSettingsService? appSettings,
}) {
  return ProviderScope(
    overrides: [
      userRepositoryProvider.overrideWithValue(repository),
      analyticsServiceProvider.overrideWithValue(analytics),
      appSettingsServiceProvider.overrideWithValue(
        appSettings ?? _FakeAppSettingsService(),
      ),
      connectivityCheckProvider.overrideWithValue(
        isOnline ?? (() async => true),
      ),
      authStateProvider.overrideWith(
        (ref) => Stream<AuthState>.value(
          authState ??
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

    testWidgets('renders the inert Language "Coming soon" slot (DC-10)', (
      tester,
    ) async {
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

      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Coming soon'), findsOneWidget);
      // The Language slot is inert: still exactly three toggle switches.
      expect(find.byType(Switch), findsNWidgets(3));

      // Announced as a single merged node (excludeSemantics), not four.
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Language, coming soon'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Choose your preferred language.'),
        findsNothing,
      );
      handle.dispose();
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
    testWidgets('renders skeleton placeholders while loading', (tester) async {
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
      expect(find.byType(OBTSkeleton), findsWidgets);

      await tester.pumpAndSettle();
      expect(find.byType(OBTSkeleton), findsNothing);
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

    testWidgets(
      'AC-8: tapping Retry re-issues the read and renders toggles on success',
      (tester) async {
        // First getUser throws; second returns the user. The Retry
        // tap must drive the controller's reload() path.
        final repo = _FakeUserRepository()
          ..throwOnGet = Exception('Firestore offline')
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

        expect(find.text('Retry'), findsOneWidget);

        // Clear the throw before tapping Retry so the next read
        // succeeds and the screen transitions to the populated state.
        repo.throwOnGet = null;

        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        expect(find.text('Retry'), findsNothing);
        expect(find.text('New Expenses'), findsOneWidget);
        expect(find.text('Settlements'), findsOneWidget);
        expect(find.text('Reminders'), findsOneWidget);
      },
    );
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
    testWidgets('AC-11: banner shows the architect-ratified copy + the '
        '"Open Settings" button when denied', (tester) async {
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

      // AC-11: the actionable "Open Settings" CTA is present now that
      // the app_settings deep-link plugin is in the lockfile (ADR-0019).
      expect(find.widgetWithText(TextButton, 'Open Settings'), findsOneWidget);
    });

    testWidgets('AC-11: tapping "Open Settings" deep-links to the OS '
        'notification settings and logs PII-free telemetry', (tester) async {
      final repo = _FakeUserRepository()
        ..userToReturn = _userWithPrefs({
          'newExpense': true,
          'settlement': true,
          'reminder': true,
        });
      final analytics = _FakeAnalyticsService();
      final appSettings = _FakeAppSettingsService();

      await tester.pumpWidget(
        _buildSubject(
          repository: repo,
          analytics: analytics,
          permissionState: PermissionState.permanentlyDenied,
          appSettings: appSettings,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      // Routes to the notification-settings open, never the generic one.
      expect(appSettings.notificationCalls, 1);
      expect(appSettings.appSettingsCalls, 0);

      final opened = analytics.events
          .where((e) => e.name == permissionSettingsOpenedEvent)
          .toList();
      expect(opened, hasLength(1));
      expect(opened.single.parameters, {
        permissionSettingsSurfaceParam: permissionSettingsSurfaceNotifications,
      });
      // PII guard: the only parameter is the non-identifying surface enum.
      expect(
        opened.single.parameters!.keys,
        everyElement(equals(permissionSettingsSurfaceParam)),
      );
    });

    testWidgets('AC-5: a failing notification-settings deep-link is absorbed '
        '(banner stays, no uncaught error)', (tester) async {
      final repo = _FakeUserRepository()
        ..userToReturn = _userWithPrefs({
          'newExpense': true,
          'settlement': true,
          'reminder': true,
        });
      final appSettings = _FakeAppSettingsService(throwOnOpen: true);

      await tester.pumpWidget(
        _buildSubject(
          repository: repo,
          analytics: _FakeAnalyticsService(),
          permissionState: PermissionState.permanentlyDenied,
          appSettings: appSettings,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      // The deep-link was attempted, the rejection was swallowed (no
      // uncaught async error), and the banner + button remain so the
      // user can retry.
      expect(appSettings.notificationCalls, 1);
      expect(tester.takeException(), isNull);
      expect(find.widgetWithText(TextButton, 'Open Settings'), findsOneWidget);
    });

    testWidgets('AC-11: banner shows the same copy + button when '
        'permanentlyDenied', (tester) async {
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
      expect(find.widgetWithText(TextButton, 'Open Settings'), findsOneWidget);
    });

    testWidgets('AC-12: banner AND its "Open Settings" button are HIDDEN '
        'when permission state is granted', (tester) async {
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
      expect(find.text('Open Settings'), findsNothing);
    });
  });

  group('NotificationPreferencesScreen — AC-7 persist failure snackbar', () {
    testWidgets(
      'snackbar surfaces with the architect-ratified copy on persist failure',
      (tester) async {
        final repo = _FakeUserRepository()
          ..userToReturn = _userWithPrefs({
            'newExpense': true,
            'settlement': true,
            'reminder': true,
          })
          ..throwOnUpdate = Exception('Firestore write rejected');
        final analytics = _FakeAnalyticsService();

        await tester.pumpWidget(
          _buildSubject(repository: repo, analytics: analytics),
        );
        await tester.pumpAndSettle();

        // Tap Reminders (third switch). The optimistic flip is
        // immediate; the persist fires after the 500 ms debounce and
        // throws, which triggers the revert + AC-7 snackbar.
        await tester.tap(find.byType(Switch).at(2));
        await tester.pump();

        // Drive the debounce + persist + revert through the pipeline.
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();

        expect(
          find.text('Could not update preference. Try again.'),
          findsOneWidget,
          reason:
              'AC-7: the screen MUST surface the revert snackbar when a '
              'persist throws.',
        );

        // The optimistic flip reverted (Reminders back to ON).
        final remindersSwitch = tester
            .widgetList<Switch>(find.byType(Switch))
            .toList()[2];
        expect(remindersSwitch.value, isTrue);

        // The error telemetry fired.
        final errors = analytics.events
            .where((e) => e.name == notificationPrefErrorEvent)
            .toList();
        expect(errors.length, 1);
      },
    );
  });

  group('NotificationPreferencesScreen — auth guard', () {
    testWidgets('unauthenticated state surfaces "Please sign in again."', (
      tester,
    ) async {
      final repo = _FakeUserRepository();

      await tester.pumpWidget(
        _buildSubject(
          repository: repo,
          analytics: _FakeAnalyticsService(),
          authState: const AuthUnauthenticated(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Please sign in again.'), findsOneWidget);
      // Toggles are NOT rendered.
      expect(find.text('New Expenses'), findsNothing);
      // The repository was never asked to persist anything.
      expect(repo.updateCalls, isEmpty);
    });

    testWidgets(
      'AuthenticatedNoProfile state surfaces "Please sign in again."',
      (tester) async {
        final repo = _FakeUserRepository();

        await tester.pumpWidget(
          _buildSubject(
            repository: repo,
            analytics: _FakeAnalyticsService(),
            authState: const AuthenticatedNoProfile(
              uid: 'uid-no-profile',
              phoneNumber: '+919876543210',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Please sign in again.'), findsOneWidget);
        expect(find.text('New Expenses'), findsNothing);
      },
    );
  });

  group('NotificationPreferencesScreen — AC-10 offline banner', () {
    testWidgets(
      'first offline toggle surfaces the offline snackbar exactly once',
      (tester) async {
        final repo = _FakeUserRepository()
          ..userToReturn = _userWithPrefs({
            'newExpense': true,
            'settlement': true,
            'reminder': true,
          });
        final analytics = _FakeAnalyticsService();

        await tester.pumpWidget(
          _buildSubject(
            repository: repo,
            analytics: analytics,
            isOnline: () async => false,
          ),
        );
        await tester.pumpAndSettle();

        // First flip — banner must surface.
        await tester.tap(find.byType(Switch).at(2));
        await tester.pumpAndSettle();

        expect(
          find.text('You are offline. Changes will sync when you reconnect.'),
          findsOneWidget,
          reason: 'AC-10: first offline flip must surface the banner.',
        );

        // Dismiss the snackbar so it does not interfere with the
        // second-flip assertion.
        ScaffoldMessenger.of(
          tester.element(find.byType(Switch).first),
        ).hideCurrentSnackBar();
        await tester.pumpAndSettle();

        expect(
          find.text('You are offline. Changes will sync when you reconnect.'),
          findsNothing,
        );

        // Second flip — banner must NOT re-surface (single-fire per
        // session).
        await tester.tap(find.byType(Switch).at(0));
        await tester.pumpAndSettle();

        expect(
          find.text('You are offline. Changes will sync when you reconnect.'),
          findsNothing,
          reason:
              'AC-10 single-fire-per-session: subsequent offline flips '
              'must NOT re-surface the banner.',
        );
      },
    );

    testWidgets(
      'online toggles never surface the offline banner (no false positives)',
      (tester) async {
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
            isOnline: () async => true,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(Switch).at(2));
        await tester.pumpAndSettle();

        expect(
          find.text('You are offline. Changes will sync when you reconnect.'),
          findsNothing,
        );
      },
    );
  });
}
