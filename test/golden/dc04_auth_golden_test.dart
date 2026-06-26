@Tags(['golden'])
library;

// DC-04 — golden scaffolds for the converted Auth & onboarding flow.
//
// Queues the five screens in light + dark: the splash REBUILD and the
// onboarding BUILD are hero brand moments needing fresh baselines; the
// phone-entry / OTP / profile-setup reskins re-baseline the same tree.
//
// The pixel comparison is intentionally SKIPPED, consistent with
// DC-01..DC-03: golden bytes are byte-sensitive across macOS/Linux, so the
// baselines must be authored on ubuntu-latest by the DC-13
// `golden-a11y-checks` job (04-qa-test-strategy.md sections A.2.2 / E).
// DC-13 un-skips this group, bundles the fonts in `loadHaldiFonts`, and
// runs `--update-goldens` on the canonical host. The load-bearing proof
// until then is the per-screen widget tests, which run for real.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/providers/phone_auth_provider.dart';
import 'package:onebytwo/core/result.dart';
import 'package:onebytwo/core/services/image_picker_service.dart';
import 'package:onebytwo/core/services/key_value_store.dart';
import 'package:onebytwo/core/services/url_launcher_service.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/data/phone_auth_repository.dart';
import 'package:onebytwo/features/auth/data/user_repository.dart';
import 'package:onebytwo/features/auth/domain/auth_error.dart';
import 'package:onebytwo/features/auth/domain/auth_user.dart';
import 'package:onebytwo/features/auth/domain/user_model.dart';
import 'package:onebytwo/features/auth/domain/verification_session.dart';
import 'package:onebytwo/features/auth/presentation/onboarding_screen.dart';
import 'package:onebytwo/features/auth/presentation/otp_entry_screen.dart';
import 'package:onebytwo/features/auth/presentation/phone_entry_screen.dart';
import 'package:onebytwo/features/auth/presentation/profile_setup_screen.dart';
import 'package:onebytwo/features/auth/presentation/splash_screen.dart';

import 'golden_harness.dart';

class _FakeAnalytics implements AnalyticsService {
  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {}
}

class _FakePhoneAuth implements PhoneAuthRepository {
  @override
  Future<void> requestOtp({
    required String phoneNumber,
    required void Function(VerificationSession session) onCodeSent,
    required void Function(AuthUser user) onAutoVerified,
    required void Function(AuthError error) onError,
    void Function()? onAutoRetrievalTimeout,
  }) async {}

  @override
  Future<Result<AuthUser, AuthError>> verifyOtp({
    required String verificationId,
    required String code,
  }) async => const Failure(AuthError.unknown);

  @override
  Future<void> resendOtp({
    required String phoneNumber,
    required void Function(VerificationSession session) onCodeSent,
    required void Function(AuthError error) onError,
    int? resendToken,
  }) async {}

  @override
  Future<void> signOut() async {}
}

class _FakeUserRepo implements UserRepository {
  @override
  Future<void> updatePhoneNumber({
    required String uid,
    required String phoneNumber,
  }) async {}

  @override
  Future<UserModel?> getUser(String uid) async => null;

  @override
  Future<void> createUser({
    required String uid,
    required String displayName,
    required String phoneNumber,
    String? photoUrl,
  }) async {}

  @override
  Future<String> uploadAvatar(String uid, String filePath) async => '';

  @override
  Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? photoUrl,
    bool removePhoto = false,
  }) async {}

  @override
  Future<void> deleteAvatar(String uid) async {}

  @override
  Future<void> updateNotificationPrefs({
    required String uid,
    required Map<String, bool> prefs,
  }) async {}
}

class _FakeImagePicker implements ImagePickerService {
  @override
  Future<XFile?> pickFromGallery({int maxWidth = 1024, int maxHeight = 1024}) =>
      Future<XFile?>.value();

  @override
  Future<XFile?> pickFromCamera({int maxWidth = 1024, int maxHeight = 1024}) =>
      Future<XFile?>.value();
}

class _NoopLauncher implements UrlLauncherService {
  @override
  Future<bool> canLaunch(Uri uri) async => true;

  @override
  Future<bool> launchExternal(Uri uri) async => true;
}

Future<void> _pumpScreen(
  WidgetTester tester,
  Widget screen,
  List<Override> overrides, {
  required Brightness brightness,
}) async {
  tester.view.physicalSize = kGoldenLogicalSize * kGoldenDevicePixelRatio;
  tester.view.devicePixelRatio = kGoldenDevicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
        home: screen,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  final authOverrides = <Override>[
    analyticsServiceProvider.overrideWithValue(_FakeAnalytics()),
    phoneAuthRepositoryProvider.overrideWithValue(_FakePhoneAuth()),
  ];

  List<Override> profileOverrides() => <Override>[
    analyticsServiceProvider.overrideWithValue(_FakeAnalytics()),
    userRepositoryProvider.overrideWithValue(_FakeUserRepo()),
    imagePickerServiceProvider.overrideWithValue(_FakeImagePicker()),
  ];

  List<Override> onboardingOverrides() => <Override>[
    keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
    urlLauncherServiceProvider.overrideWithValue(_NoopLauncher()),
  ];

  // Screen builder + override pairs, queued per brightness below.
  final cases = <String, ({Widget Function() build, List<Override> overrides})>{
    'splash': (
      build: () => const SplashScreen(timeoutDuration: Duration(seconds: 999)),
      overrides: authOverrides,
    ),
    'onboarding': (
      build: OnboardingScreen.new,
      overrides: onboardingOverrides(),
    ),
    'phone_entry': (build: PhoneEntryScreen.new, overrides: authOverrides),
    'otp_entry': (
      build: () => const OtpEntryScreen(
        phoneNumber: '9876543210',
        verificationId: 'vid-golden',
      ),
      overrides: authOverrides,
    ),
    'profile_setup': (
      build: () => const ProfileSetupScreen(
        uid: 'uid-golden',
        phoneNumber: '+919876543210',
      ),
      overrides: profileOverrides(),
    ),
  };

  group(
    'DC-04 Auth flow goldens',
    () {
      for (final entry in cases.entries) {
        for (final brightness in Brightness.values) {
          final mode = brightness == Brightness.light ? 'light' : 'dark';
          testWidgets('${entry.key} ($mode)', (tester) async {
            await loadHaldiFonts();
            await _pumpScreen(
              tester,
              entry.value.build(),
              entry.value.overrides,
              brightness: brightness,
            );
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile('goldens/dc04/${entry.key}_$mode.png'),
            );
          });
        }
      }
    },
    skip:
        'DC-13 (#125) authors and un-skips Auth-flow goldens on '
        'ubuntu-latest; baselines are not committed from macOS.',
  );
}
