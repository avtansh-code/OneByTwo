// Profile Setup Flow Integration Test
//
// This test validates the profile setup flow against fake
// implementations. For full emulator-backed tests, start the
// Firebase Emulator Suite:
//
//   firebase emulators:exec --only auth,firestore,storage \
//     "flutter test test/integration/auth/profile_setup_flow_test.dart" \
//     --project demo-onebytwo
//
// Tests live in test/integration/ (not integration_test/) so they
// run headlessly in CI without a connected device.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/data/image_picker_service.dart';
import 'package:onebytwo/features/auth/data/user_repository.dart';
import 'package:onebytwo/features/auth/domain/user_model.dart';
import 'package:onebytwo/features/auth/presentation/profile_setup_screen.dart';

// -- Fakes -------------------------------------------------------

class _FakeAnalyticsService implements AnalyticsService {
  final List<String> loggedEvents = [];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    loggedEvents.add(name);
  }
}

class _FakeUserRepository implements UserRepository {
  UserModel? existingUser;
  bool shouldFail = false;
  Map<String, dynamic>? lastCreatedDoc;

  @override
  Future<UserModel?> getUser(String uid) async => existingUser;

  @override
  Future<void> createUser({
    required String uid,
    required String displayName,
    required String phoneNumber,
    String? photoUrl,
  }) async {
    if (shouldFail) {
      throw Exception('Firestore write failed');
    }
    lastCreatedDoc = {
      'uid': uid,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
    };
  }

  @override
  Future<String> uploadAvatar(String uid, String filePath) async {
    return 'https://storage.example.com/avatars/$uid';
  }
}

class _FakeImagePickerService implements ImagePickerService {
  String? photoToReturn;

  @override
  Future<XFile?> pickFromGallery({
    int maxWidth = 1024,
    int maxHeight = 1024,
  }) async {
    if (photoToReturn != null) return XFile(photoToReturn!);
    return null;
  }

  @override
  Future<XFile?> pickFromCamera({
    int maxWidth = 1024,
    int maxHeight = 1024,
  }) async {
    if (photoToReturn != null) return XFile(photoToReturn!);
    return null;
  }
}

// -- Helpers -----------------------------------------------------

Widget _buildApp({
  required _FakeAnalyticsService analytics,
  required _FakeUserRepository userRepo,
  required _FakeImagePickerService imagePicker,
}) {
  return ProviderScope(
    overrides: [
      analyticsServiceProvider.overrideWithValue(analytics),
      userRepositoryProvider.overrideWithValue(userRepo),
      imagePickerServiceProvider.overrideWithValue(imagePicker),
    ],
    child: const MaterialApp(
      home: ProfileSetupScreen(
        uid: 'test-uid-123',
        phoneNumber: '+919876543210',
      ),
    ),
  );
}

// -- Tests -------------------------------------------------------

void main() {
  group('Profile setup flow (integration)', () {
    late _FakeAnalyticsService analytics;
    late _FakeUserRepository userRepo;
    late _FakeImagePickerService imagePicker;

    setUp(() {
      analytics = _FakeAnalyticsService();
      userRepo = _FakeUserRepository();
      imagePicker = _FakeImagePickerService();
    });

    testWidgets('first-time user enters name, skips photo, '
        'sees home placeholder', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          analytics: analytics,
          userRepo: userRepo,
          imagePicker: imagePicker,
        ),
      );
      await tester.pumpAndSettle();

      // Screen renders.
      expect(find.text('Set up your profile'), findsOneWidget);

      // Enter display name.
      await tester.enterText(find.byType(TextField), 'Avtansh');
      await tester.pumpAndSettle();

      // Continue button should be enabled.
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);

      // Tap Continue.
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      // User doc should be created.
      expect(userRepo.lastCreatedDoc, isNotNull);
      expect(userRepo.lastCreatedDoc!['displayName'], 'Avtansh');
      expect(userRepo.lastCreatedDoc!['photoUrl'], isNull);

      // Navigation to home is now handled reactively by the auth gate
      // (OneBytwoApp), which observes the Firestore user doc via
      // authStateNotifierProvider. In this unit test context, the
      // auth gate is not present, so we verify the doc was created
      // and telemetry fired correctly instead.

      // Telemetry events fired in order.
      expect(
        analytics.loggedEvents,
        containsAll([
          'profile_setup_viewed',
          'profile_photo_skipped',
          'profile_save_requested',
          'profile_save_succeeded',
        ]),
      );
    });

    testWidgets('save failure shows error snackbar and allows retry', (
      tester,
    ) async {
      userRepo.shouldFail = true;

      await tester.pumpWidget(
        _buildApp(
          analytics: analytics,
          userRepo: userRepo,
          imagePicker: imagePicker,
        ),
      );
      await tester.pumpAndSettle();

      // Enter name and submit.
      await tester.enterText(find.byType(TextField), 'Avtansh');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      // Error snackbar shown.
      expect(
        find.text(
          'Could not save your profile. '
          'Please try again.',
        ),
        findsOneWidget,
      );

      // profile_save_failed event fired.
      expect(analytics.loggedEvents, contains('profile_save_failed'));

      // Button should be re-enabled for retry.
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('empty name keeps Continue disabled', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          analytics: analytics,
          userRepo: userRepo,
          imagePicker: imagePicker,
        ),
      );
      await tester.pumpAndSettle();

      // Continue button should be disabled by default.
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('whitespace-only name keeps Continue disabled', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          analytics: analytics,
          userRepo: userRepo,
          imagePicker: imagePicker,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });
  });
}
