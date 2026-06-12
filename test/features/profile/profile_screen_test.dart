import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:onebytwo/core/remote_config/remote_config_service.dart';
import 'package:onebytwo/core/result.dart';
import 'package:onebytwo/core/services/image_picker_service.dart';
import 'package:onebytwo/core/services/url_launcher_service.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/application/auth_state_provider.dart';
import 'package:onebytwo/features/auth/data/phone_auth_repository.dart';
import 'package:onebytwo/features/auth/data/user_repository.dart';
import 'package:onebytwo/features/auth/domain/auth_error.dart';
import 'package:onebytwo/features/auth/domain/auth_state.dart';
import 'package:onebytwo/features/auth/domain/auth_user.dart';
import 'package:onebytwo/features/auth/domain/user_model.dart';
import 'package:onebytwo/features/auth/domain/verification_session.dart';
import 'package:onebytwo/features/friends/application/friends_list_provider.dart';
import 'package:onebytwo/features/profile/data/device_diagnostics_service.dart';
import 'package:onebytwo/features/profile/domain/support_diagnostics.dart';
import 'package:onebytwo/features/profile/presentation/profile_screen.dart';

// -- Fakes -------------------------------------------------------

class _FakeAnalyticsService implements AnalyticsService {
  final List<({String name, Map<String, Object>? parameters})> loggedEvents =
      [];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    loggedEvents.add((name: name, parameters: parameters));
  }
}

class _FakePhoneAuthRepository implements PhoneAuthRepository {
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

class _FakeUserRepository implements UserRepository {
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
  Future<String> uploadAvatar(String uid, String filePath) async =>
      'https://example.com/avatar.jpg';

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

class _FakeImagePickerService implements ImagePickerService {
  @override
  Future<XFile?> pickFromGallery({
    int maxWidth = 1024,
    int maxHeight = 1024,
  }) async => null;

  @override
  Future<XFile?> pickFromCamera({
    int maxWidth = 1024,
    int maxHeight = 1024,
  }) async => null;
}

class _FakeRemoteConfigService implements RemoteConfigService {
  @override
  Future<void> initialise() async {}

  @override
  String getString(String key) => 'support@onebytwo.app';
}

class _FakeDeviceDiagnosticsService implements DeviceDiagnosticsService {
  @override
  Future<SupportDiagnostics> load() async => const SupportDiagnostics(
    appVersion: '1.0.0',
    buildNumber: '1',
    osName: 'Android',
    osVersion: '14',
    deviceModel: 'Pixel 6',
  );
}

class _FakeUrlLauncherService implements UrlLauncherService {
  bool canLaunchResult = true;
  bool launchResult = true;
  Uri? lastLaunchedUri;

  @override
  Future<bool> canLaunch(Uri uri) async => canLaunchResult;

  @override
  Future<bool> launchExternal(Uri uri) async {
    lastLaunchedUri = uri;
    return launchResult;
  }
}

// -- Helpers -----------------------------------------------------

final _testUser = UserModel(
  phoneNumber: '+919876543210',
  displayName: 'Test User',
  createdAt: DateTime(2025),
  updatedAt: DateTime(2025),
);

final _testUserNoPhoto = UserModel(
  phoneNumber: '+919876543210',
  displayName: 'Test User',
  createdAt: DateTime(2025),
  updatedAt: DateTime(2025),
);

// -- Tests -------------------------------------------------------

void main() {
  late _FakeAnalyticsService fakeAnalytics;
  late _FakePhoneAuthRepository fakeAuthRepo;
  late _FakeUserRepository fakeUserRepo;
  late _FakeImagePickerService fakeImagePicker;
  late _FakeRemoteConfigService fakeRemoteConfig;
  late _FakeDeviceDiagnosticsService fakeDiagnostics;
  late _FakeUrlLauncherService fakeLauncher;

  setUp(() {
    fakeAnalytics = _FakeAnalyticsService();
    fakeAuthRepo = _FakePhoneAuthRepository();
    fakeUserRepo = _FakeUserRepository();
    fakeImagePicker = _FakeImagePickerService();
    fakeRemoteConfig = _FakeRemoteConfigService();
    fakeDiagnostics = _FakeDeviceDiagnosticsService();
    fakeLauncher = _FakeUrlLauncherService();
  });

  List<Override> contactSupportOverrides() => [
    currentUserIdProvider.overrideWithValue('uid-123'),
    remoteConfigServiceProvider.overrideWithValue(fakeRemoteConfig),
    deviceDiagnosticsServiceProvider.overrideWithValue(fakeDiagnostics),
    urlLauncherServiceProvider.overrideWithValue(fakeLauncher),
  ];

  Widget buildSubject({UserModel? user}) {
    final effectiveUser = user ?? _testUser;
    return ProviderScope(
      overrides: [
        analyticsServiceProvider.overrideWithValue(fakeAnalytics),
        phoneAuthRepositoryProvider.overrideWithValue(fakeAuthRepo),
        userRepositoryProvider.overrideWithValue(fakeUserRepo),
        imagePickerServiceProvider.overrideWithValue(fakeImagePicker),
        ...contactSupportOverrides(),
        authStateNotifierProvider.overrideWith(
          (ref) => Stream.value(
            AuthenticatedWithProfile(uid: 'uid-123', user: effectiveUser),
          ),
        ),
      ],
      child: const MaterialApp(home: ProfileScreen()),
    );
  }

  Widget buildSubjectWithLoading() {
    return ProviderScope(
      overrides: [
        analyticsServiceProvider.overrideWithValue(fakeAnalytics),
        phoneAuthRepositoryProvider.overrideWithValue(fakeAuthRepo),
        userRepositoryProvider.overrideWithValue(fakeUserRepo),
        imagePickerServiceProvider.overrideWithValue(fakeImagePicker),
        authStateNotifierProvider.overrideWith(
          // Stream that never emits keeps state as AsyncLoading.
          (ref) => const Stream<AuthState>.empty(),
        ),
      ],
      child: const MaterialApp(home: ProfileScreen()),
    );
  }

  Widget buildSubjectWithError() {
    return ProviderScope(
      overrides: [
        analyticsServiceProvider.overrideWithValue(fakeAnalytics),
        phoneAuthRepositoryProvider.overrideWithValue(fakeAuthRepo),
        userRepositoryProvider.overrideWithValue(fakeUserRepo),
        imagePickerServiceProvider.overrideWithValue(fakeImagePicker),
        ...contactSupportOverrides(),
        authStateNotifierProvider.overrideWith(
          (ref) => Stream<AuthState>.error(Exception('Network error')),
        ),
      ],
      child: const MaterialApp(home: ProfileScreen()),
    );
  }

  group('ProfileScreen', () {
    testWidgets('renders display name and phone number '
        'from user state', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('+919876543210'), findsOneWidget);
    });

    testWidgets('shows initials avatar when photoUrl is null', (tester) async {
      await tester.pumpWidget(buildSubject(user: _testUserNoPhoto));
      await tester.pumpAndSettle();

      // "TU" initials should appear.
      expect(find.text('TU'), findsOneWidget);
    });

    testWidgets('Sign Out row is present', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Sign Out'), findsOneWidget);
    });

    testWidgets('Edit Profile row is present', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Edit Profile'), findsOneWidget);
    });

    testWidgets('stats rows show placeholder counts', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('My Friends'), findsOneWidget);
      expect(find.text('My Groups'), findsOneWidget);
      // Both counts should show "0".
      expect(find.text('0'), findsNWidgets(2));
    });

    testWidgets('profile_viewed telemetry fires on mount', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(
        fakeAnalytics.loggedEvents.any((e) => e.name == 'profile_viewed'),
        isTrue,
      );
    });

    testWidgets('Delete Account row is present with text', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Scroll down to reveal the Delete Account row.
      await tester.scrollUntilVisible(
        find.text('Delete Account'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Delete Account'), findsOneWidget);
    });

    testWidgets('Notification Preferences row is present', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Notification Preferences'), findsOneWidget);
    });

    testWidgets('Contact Support row is present', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Contact Support'), findsOneWidget);
    });

    testWidgets('loading state shows skeleton placeholders', (tester) async {
      await tester.pumpWidget(buildSubjectWithLoading());
      // Pump a single frame so loading state is rendered.
      await tester.pump();

      // Skeleton placeholders should be present (ShaderMask from shimmer).
      expect(find.byType(ShaderMask), findsOneWidget);
    });

    testWidgets('error state shows error message and retry', (tester) async {
      await tester.pumpWidget(buildSubjectWithError());
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Still stuck? Contact Support'), findsOneWidget);
    });

    testWidgets('Contact Support row preserves its semantics label', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics && w.properties.label == 'Contact Support, button',
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping Contact Support launches a mailto: URI', (
      tester,
    ) async {
      fakeLauncher
        ..canLaunchResult = true
        ..launchResult = true;
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Contact Support'));
      await tester.pumpAndSettle();

      expect(fakeLauncher.lastLaunchedUri?.scheme, 'mailto');
      expect(fakeLauncher.lastLaunchedUri?.path, 'support@onebytwo.app');
      expect(find.text('No Mail App Found'), findsNothing);
      expect(
        fakeAnalytics.loggedEvents.any(
          (e) =>
              e.name == 'support_email_opened' &&
              e.parameters?['method'] == 'mailto',
        ),
        isTrue,
      );
    });

    testWidgets('tapping Contact Support with no mail client shows '
        'the fallback dialog', (tester) async {
      fakeLauncher.canLaunchResult = false;
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Contact Support'));
      await tester.pumpAndSettle();

      expect(find.text('No Mail App Found'), findsOneWidget);
      expect(
        fakeAnalytics.loggedEvents.any(
          (e) =>
              e.name == 'support_email_opened' &&
              e.parameters?['method'] == 'fallback_dialog',
        ),
        isTrue,
      );
    });

    testWidgets('error-state Contact Support link runs the support flow', (
      tester,
    ) async {
      fakeLauncher
        ..canLaunchResult = true
        ..launchResult = true;
      await tester.pumpWidget(buildSubjectWithError());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Still stuck? Contact Support'));
      await tester.pumpAndSettle();

      expect(fakeLauncher.lastLaunchedUri?.scheme, 'mailto');
    });
  });
}
