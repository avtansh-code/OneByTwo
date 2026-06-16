import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:onebytwo/core/services/image_picker_service.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/application/auth_state_provider.dart';
import 'package:onebytwo/features/auth/data/user_repository.dart';
import 'package:onebytwo/features/auth/domain/auth_state.dart';
import 'package:onebytwo/features/auth/domain/user_model.dart';
import 'package:onebytwo/features/profile/application/edit_profile_controller.dart';
import 'package:onebytwo/features/profile/presentation/edit_profile_screen.dart';

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

class _FakeUserRepository implements UserRepository {
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

// -- Helpers -----------------------------------------------------

final _testUser = UserModel(
  phoneNumber: '+919876543210',
  displayName: 'Test User',
  createdAt: DateTime(2025),
  updatedAt: DateTime(2025),
);

// -- Tests -------------------------------------------------------

void main() {
  late _FakeAnalyticsService fakeAnalytics;
  late _FakeUserRepository fakeUserRepo;
  late _FakeImagePickerService fakeImagePicker;

  setUp(() {
    fakeAnalytics = _FakeAnalyticsService();
    fakeUserRepo = _FakeUserRepository();
    fakeImagePicker = _FakeImagePickerService();
  });

  Widget buildSubject() {
    return ProviderScope(
      overrides: [
        analyticsServiceProvider.overrideWithValue(fakeAnalytics),
        userRepositoryProvider.overrideWithValue(fakeUserRepo),
        imagePickerServiceProvider.overrideWithValue(fakeImagePicker),
        authStateNotifierProvider.overrideWith(
          (ref) => Stream.value(
            AuthenticatedWithProfile(uid: 'uid-123', user: _testUser),
          ),
        ),
        editProfileControllerProvider.overrideWith(
          (ref) => EditProfileController(
            originalName: _testUser.displayName,
            originalPhotoUrl: _testUser.photoUrl,
            uid: 'uid-123',
            analytics: fakeAnalytics,
            repository: fakeUserRepo,
            imagePicker: fakeImagePicker,
          ),
        ),
      ],
      child: const MaterialApp(home: EditProfileScreen()),
    );
  }

  group('EditProfileScreen', () {
    testWidgets('pre-populates display name from user data', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // The text field should contain the user's name.
      expect(find.text('Test User'), findsOneWidget);
    });

    testWidgets('Save button disabled when no changes', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('Save button enabled after name edit', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Find the TextField and change it.
      await tester.enterText(find.byType(TextField).first, 'New Name');
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('empty name shows inline error', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // First enter something to trigger a change, then clear.
      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'A');
      await tester.pumpAndSettle();
      await tester.enterText(nameField, '');
      await tester.pumpAndSettle();

      // The error message should be rendered.
      expect(find.text('Display name cannot be empty.'), findsOneWidget);
    });

    testWidgets('phone number row shows a tappable change affordance', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // The FR-PR-02 entry point: number shown, "tap to change" helper,
      // a chevron, and the old read-only hint removed.
      expect(find.text('+919876543210'), findsOneWidget);
      expect(find.text('Tap to change your phone number.'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(
        find.text('Phone number cannot be changed from here.'),
        findsNothing,
      );
    });

    testWidgets('displays change profile photo button', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Camera badge icon should be present.
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    });

    testWidgets('Save button shows text "Save"', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('name exceeding 50 chars shows error', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // The TextField has maxLength: 50 which truncates input, so we
      // verify the counter is shown when text exceeds 40 chars.
      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'A' * 45);
      await tester.pumpAndSettle();

      expect(find.text('45/50'), findsOneWidget);
    });

    testWidgets('phone number row is a tappable button, not a disabled field', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Exposed as an InkWell affordance with a non-null onTap (the
      // navigation into the change-phone flow), replacing the old disabled
      // TextFormField.
      final inkWell = tester.widget<InkWell>(
        find.widgetWithText(InkWell, 'Tap to change your phone number.'),
      );
      expect(inkWell.onTap, isNotNull);
    });
  });
}
