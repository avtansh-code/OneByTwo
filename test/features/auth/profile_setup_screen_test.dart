import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/core/services/image_picker_service.dart';
import 'package:onebytwo/features/auth/data/user_repository.dart';
import 'package:onebytwo/features/auth/domain/user_model.dart';
import 'package:onebytwo/features/auth/presentation/profile_setup_screen.dart';

/// Fake [AnalyticsService] that records events.
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
}

/// Fake [UserRepository] for screen tests.
class FakeUserRepository implements UserRepository {
  bool shouldFailCreate = false;

  /// When non-null, [createUser] waits on this completer.
  Completer<void>? createCompleter;

  @override
  Future<UserModel?> getUser(String uid) async => null;

  @override
  Future<void> createUser({
    required String uid,
    required String displayName,
    required String phoneNumber,
    String? photoUrl,
  }) async {
    if (createCompleter != null) {
      await createCompleter!.future;
    }
    if (shouldFailCreate) {
      throw Exception('Firestore write failed');
    }
  }

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
}

/// Fake [ImagePickerService] for screen tests.
class FakeImagePickerService implements ImagePickerService {
  XFile? galleryResult;
  XFile? cameraResult;

  @override
  Future<XFile?> pickFromGallery({
    int maxWidth = 1024,
    int maxHeight = 1024,
  }) async => galleryResult;

  @override
  Future<XFile?> pickFromCamera({
    int maxWidth = 1024,
    int maxHeight = 1024,
  }) async => cameraResult;
}

void main() {
  late FakeAnalyticsService fakeAnalytics;
  late FakeUserRepository fakeRepository;
  late FakeImagePickerService fakeImagePicker;

  setUp(() {
    fakeAnalytics = FakeAnalyticsService();
    fakeRepository = FakeUserRepository();
    fakeImagePicker = FakeImagePickerService();
  });

  Widget buildSubject() {
    return ProviderScope(
      overrides: [
        analyticsServiceProvider.overrideWithValue(fakeAnalytics),
        userRepositoryProvider.overrideWithValue(fakeRepository),
        imagePickerServiceProvider.overrideWithValue(fakeImagePicker),
      ],
      child: const MaterialApp(
        home: ProfileSetupScreen(uid: 'test-uid', phoneNumber: '+919876543210'),
      ),
    );
  }

  group('ProfileSetupScreen', () {
    testWidgets('renders default state correctly', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('Set up your profile'), findsOneWidget);
      expect(
        find.text(
          'Tell us your name so your '
          'friends recognise you.',
        ),
        findsOneWidget,
      );
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('Continue button is disabled when '
        'display name is empty', (tester) async {
      await tester.pumpWidget(buildSubject());

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('Continue button enables when valid '
        'name is entered', (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.enterText(find.byType(TextField), 'Avtansh');
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('shows character counter after '
        '40 characters', (tester) async {
      await tester.pumpWidget(buildSubject());

      // Enter 41 characters.
      await tester.enterText(find.byType(TextField), 'A' * 41);
      await tester.pump();

      expect(find.text('41/50'), findsOneWidget);
    });

    testWidgets('tapping avatar opens photo picker '
        'bottom sheet', (tester) async {
      await tester.pumpWidget(buildSubject());

      // Tap the avatar area (GestureDetector).
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      expect(find.text('Take photo'), findsOneWidget);
      expect(find.text('Choose from gallery'), findsOneWidget);
    });

    testWidgets('shows loading state when saving', (tester) async {
      // Use a completer to keep createUser pending.
      fakeRepository.createCompleter = Completer<void>();

      await tester.pumpWidget(buildSubject());

      await tester.enterText(find.byType(TextField), 'Avtansh');
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      // During loading, a progress indicator
      // should appear.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the completer to avoid hanging.
      fakeRepository.createCompleter!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('shows snackbar error on save failure', (tester) async {
      fakeRepository.shouldFailCreate = true;

      await tester.pumpWidget(buildSubject());

      await tester.enterText(find.byType(TextField), 'Avtansh');
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.text(
          'Could not save your profile. '
          'Please try again.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('accessibility: heading has Semantics '
        'header', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.bySemanticsLabel('Set up your profile'), findsOneWidget);
    });

    testWidgets('accessibility: avatar has correct '
        'semantic label', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(
        find.bySemanticsLabel('Profile photo. Tap to add a photo.'),
        findsOneWidget,
      );
    });

    testWidgets('prevents back navigation', (tester) async {
      await tester.pumpWidget(buildSubject());

      // Simulate a back button press via
      // PopScope.
      final dynamic widgetsApp = tester.widget(find.byType(MaterialApp));
      expect(widgetsApp, isNotNull);

      // Verify PopScope is present.
      expect(find.byType(PopScope), findsOneWidget);

      final popScope = tester.widget<PopScope>(find.byType(PopScope));
      expect(popScope.canPop, isFalse);
    });
  });
}
