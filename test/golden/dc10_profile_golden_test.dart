@Tags(['golden'])
library;

// DC-10 — light golden scaffolds for the converted Profile & Settings cluster
// (Haldi 27 / Phase3g / 28 / 29 / 30). Profile is a NON-HERO cluster, so
// 04-qa-test-strategy.md §A.6 calls for LIGHT goldens only (no both-brightness
// hero treatment).
//
// This group is ENABLED, consistent with DC-01..DC-09: the pixel
// comparison runs and is no longer skipped. Determinism comes from the
// bundled OFL fonts (Bricolage Grotesque + Hanken Grotesk), loaded once
// via `loadHaldiFonts` in `golden_harness.dart` and served to google_fonts
// through its test http seam, so the real Haldi type ramp rasterises
// identically offline. Baselines are authored on ubuntu-latest via the
// manual `golden-refresh` workflow and committed under `goldens/`; the
// `golden-a11y-checks` CI job (pinned Flutter version) compares against
// them on every PR and fails on any unintended pixel diff
// (04-qa-test-strategy.md sections A.2.2 and E). The load-bearing
// per-screen widget tests (profile_screen_test, change_phone_screen_test,
// delete_account_screen_test, notification_preferences_screen_test,
// contact_support_fallback_dialog_test) + profile_haldi_reskin_test + the
// no-`Color(0x…)` grep also run for real.
//
// edit-profile (27) is a pure radius migration whose contract is fully
// covered by `flutter analyze` + the no-hex grep, so it is not queued here
// as a golden.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/core/connectivity/connectivity_provider.dart';
import 'package:onebytwo/core/providers/phone_auth_provider.dart';
import 'package:onebytwo/core/services/app_settings_service.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/application/auth_state_provider.dart';
import 'package:onebytwo/features/auth/data/user_repository.dart';
import 'package:onebytwo/features/auth/domain/auth_state.dart';
import 'package:onebytwo/features/notifications/application/notification_permission_controller.dart';
import 'package:onebytwo/features/profile/application/change_phone_controller.dart';
import 'package:onebytwo/features/profile/application/delete_account_controller.dart';
import 'package:onebytwo/features/profile/presentation/change_phone_screen.dart';
import 'package:onebytwo/features/profile/presentation/contact_support_fallback_dialog.dart';
import 'package:onebytwo/features/profile/presentation/delete_account_screen.dart';
import 'package:onebytwo/features/profile/presentation/notification_preferences_screen.dart';
import 'package:onebytwo/features/profile/presentation/profile_screen.dart';
import 'package:onebytwo/features/profile/presentation/widgets/photo_picker_sheet.dart';

import '../features/profile/helpers/profile_fakes.dart';
import 'golden_harness.dart';

const _uid = 'uid-1';

class _StubPermission extends NotificationPermissionController {
  _StubPermission(this._state);
  final PermissionState _state;
  @override
  PermissionState build() => _state;
}

ChangePhoneController _changePhone(FakeUserRepo users) => ChangePhoneController(
  uid: _uid,
  currentPhoneNumber: '+919876543210',
  analytics: FakeAnalytics(),
  accountRepository: FakeAccountRepo(),
  userRepository: users,
);

DeleteAccountController _delete() => DeleteAccountController(
  currentPhoneNumber: '+919876543210',
  analytics: FakeAnalytics(),
  accountRepository: FakeAccountRepo(),
  deleteAccountRepository: FakeDeleteRepo(),
  signOut: () async {},
);

Widget _profile({required bool loading}) => ProviderScope(
  overrides: <Override>[
    analyticsServiceProvider.overrideWithValue(FakeAnalytics()),
    phoneAuthRepositoryProvider.overrideWithValue(FakePhoneAuthRepository()),
    userRepositoryProvider.overrideWithValue(FakeUserRepo()),
    authStateProvider.overrideWith(
      (ref) => loading
          ? const Stream<AuthState>.empty()
          : Stream<AuthState>.value(
              AuthenticatedWithProfile(uid: _uid, user: fakeUser()),
            ),
    ),
  ],
  child: const ProfileScreen(),
);

Widget _notifPrefs() => ProviderScope(
  overrides: <Override>[
    userRepositoryProvider.overrideWithValue(FakeUserRepo()),
    analyticsServiceProvider.overrideWithValue(FakeAnalytics()),
    appSettingsServiceProvider.overrideWithValue(FakeAppSettings()),
    connectivityCheckProvider.overrideWithValue(() async => true),
    authStateProvider.overrideWith(
      (ref) => Stream<AuthState>.value(
        AuthenticatedWithProfile(uid: _uid, user: fakeUser()),
      ),
    ),
    notificationPermissionControllerProvider.overrideWith(
      () => _StubPermission(PermissionState.granted),
    ),
  ],
  child: const NotificationPreferencesScreen(),
);

Widget _changePhoneScreen(FakeUserRepo users) => ProviderScope(
  overrides: <Override>[
    changePhoneControllerProvider.overrideWith((ref) => _changePhone(users)),
  ],
  child: const ChangePhoneScreen(),
);

Widget _deleteScreen() => ProviderScope(
  overrides: <Override>[
    deleteAccountControllerProvider.overrideWith((ref) => _delete()),
  ],
  child: const DeleteAccountScreen(),
);

Widget _contactSupportLauncher() => Scaffold(
  body: Builder(
    builder: (context) => ElevatedButton(
      onPressed: () => ContactSupportFallbackDialog.show(
        context,
        supportEmailAddress: 'support@onebytwo.app',
      ),
      child: const Text('open'),
    ),
  ),
);

void main() {
  group('DC-10 Profile cluster goldens (light)', () {
    // ---- profile (27): loading skeleton + populated ----
    testWidgets('profile loading (light)', (tester) async {
      await loadHaldiFonts();
      await pumpForGolden(tester, _profile(loading: true));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/dc10/profile_loading_light.png'),
      );
    });

    testWidgets('profile populated (light)', (tester) async {
      await loadHaldiFonts();
      await pumpForGolden(tester, _profile(loading: false));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/dc10/profile_populated_light.png'),
      );
    });

    // ---- notification preferences (28): incl. the inert Language slot ----
    testWidgets('notification preferences ready (light)', (tester) async {
      await loadHaldiFonts();
      await pumpForGolden(tester, _notifPrefs());
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/dc10/notification_preferences_light.png'),
      );
    });

    // ---- change-phone (Phase3g): the five states ----
    testWidgets('change-phone reauth intro (light)', (tester) async {
      await loadHaldiFonts();
      await pumpForGolden(tester, _changePhoneScreen(FakeUserRepo()));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/dc10/change_phone_reauth_intro_light.png'),
      );
    });

    testWidgets('change-phone reauth OTP (light)', (tester) async {
      await loadHaldiFonts();
      await pumpForGolden(tester, _changePhoneScreen(FakeUserRepo()));
      await tester.tap(find.text('Send verification code'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/dc10/change_phone_reauth_otp_light.png'),
      );
    });

    testWidgets('change-phone new-number entry (light)', (tester) async {
      await loadHaldiFonts();
      await pumpForGolden(tester, _changePhoneScreen(FakeUserRepo()));
      await tester.tap(find.text('Send verification code'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/dc10/change_phone_new_entry_light.png'),
      );
    });

    testWidgets('change-phone new-number OTP (light)', (tester) async {
      await loadHaldiFonts();
      await pumpForGolden(tester, _changePhoneScreen(FakeUserRepo()));
      await tester.tap(find.text('Send verification code'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '9123456780');
      await tester.pump();
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/dc10/change_phone_new_otp_light.png'),
      );
    });

    testWidgets('change-phone sync-pending recovery (light)', (tester) async {
      await loadHaldiFonts();
      await pumpForGolden(
        tester,
        _changePhoneScreen(FakeUserRepo(throwOnSync: true)),
      );
      await tester.tap(find.text('Send verification code'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '9123456780');
      await tester.pump();
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '654321');
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/dc10/change_phone_sync_pending_light.png'),
      );
    });

    // ---- delete-account (30): warning + confirm + success ----
    testWidgets('delete-account warning (light)', (tester) async {
      await loadHaldiFonts();
      await pumpForGolden(tester, _deleteScreen());
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/dc10/delete_account_warning_light.png'),
      );
    });

    testWidgets('delete-account confirm (light)', (tester) async {
      await loadHaldiFonts();
      await pumpForGolden(tester, _deleteScreen());
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send OTP'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/dc10/delete_account_confirm_light.png'),
      );
    });

    // ---- contact-support (29) + photo picker (5/27) ----
    testWidgets('contact-support fallback dialog (light)', (tester) async {
      await loadHaldiFonts();
      await pumpForGolden(tester, _contactSupportLauncher());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/dc10/contact_support_dialog_light.png'),
      );
    });

    testWidgets('photo picker sheet (light)', (tester) async {
      await loadHaldiFonts();
      await pumpForGolden(
        tester,
        const Scaffold(body: PhotoPickerSheet(hasExistingPhoto: true)),
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/dc10/photo_picker_sheet_light.png'),
      );
    });
  });
}
