// ignore_for_file: cascade_invocations
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/application/profile_setup_controller.dart';
import 'package:onebytwo/features/auth/data/image_picker_service.dart';
import 'package:onebytwo/features/auth/data/user_repository.dart';
import 'package:onebytwo/features/auth/domain/user_model.dart';

/// Fake [AnalyticsService] that records logged events.
class FakeAnalyticsService implements AnalyticsService {
  /// Events logged as `(name, parameters)` tuples.
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

/// Fake [UserRepository] with configurable behaviour.
class FakeUserRepository implements UserRepository {
  /// When true, [createUser] throws.
  bool shouldFailCreate = false;

  /// When true, [uploadAvatar] throws.
  bool shouldFailUpload = false;

  /// Number of times [createUser] was called.
  int createUserCallCount = 0;

  /// Last photoUrl passed to [createUser].
  String? lastCreatePhotoUrl;

  /// Last displayName passed to [createUser].
  String? lastCreateDisplayName;

  @override
  Future<UserModel?> getUser(String uid) async => null;

  @override
  Future<void> createUser({
    required String uid,
    required String displayName,
    required String phoneNumber,
    String? photoUrl,
  }) async {
    createUserCallCount++;
    lastCreateDisplayName = displayName;
    lastCreatePhotoUrl = photoUrl;
    if (shouldFailCreate) {
      throw Exception('Firestore write failed');
    }
  }

  @override
  Future<String> uploadAvatar(String uid, String filePath) async {
    if (shouldFailUpload) {
      throw Exception('Storage upload failed');
    }
    return 'https://example.com/avatar.jpg';
  }
}

/// Fake [ImagePickerService] with configurable
/// behaviour.
class FakeImagePickerService implements ImagePickerService {
  /// When non-null, [pickFromGallery] returns this.
  XFile? galleryResult;

  /// When non-null, [pickFromCamera] returns this.
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
  late ProfileSetupController controller;

  setUp(() {
    fakeAnalytics = FakeAnalyticsService();
    fakeRepository = FakeUserRepository();
    fakeImagePicker = FakeImagePickerService();
    controller = ProfileSetupController(
      analytics: fakeAnalytics,
      repository: fakeRepository,
      imagePicker: fakeImagePicker,
    );
  });

  tearDown(() {
    controller.dispose();
  });

  group('ProfileSetupController', () {
    test('initial state has empty displayName '
        'and canSubmit false', () {
      expect(controller.state.displayName, isEmpty);
      expect(controller.state.canSubmit, isFalse);
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.isSaved, isFalse);
    });

    test('setDisplayName updates state', () {
      controller.setDisplayName('Avtansh');
      expect(controller.state.displayName, 'Avtansh');
    });

    test('empty display name results in '
        'canSubmit false', () {
      controller.setDisplayName('');
      expect(controller.state.canSubmit, isFalse);
    });

    test('whitespace-only display name results in '
        'canSubmit false', () {
      controller.setDisplayName('   ');
      expect(controller.state.canSubmit, isFalse);
    });

    test('display name above 50 chars results in '
        'canSubmit false', () {
      controller.setDisplayName('A' * 51);
      expect(controller.state.canSubmit, isFalse);
    });

    test('valid display name results in '
        'canSubmit true', () {
      controller.setDisplayName('Avtansh');
      expect(controller.state.canSubmit, isTrue);
    });

    test('submit success sets isSaved true and '
        'fires profile_save_succeeded', () async {
      controller.setDisplayName('Avtansh');
      await controller.submit(uid: 'uid-1', phoneNumber: '+919876543210');

      expect(controller.state.isSaved, isTrue);
      expect(controller.state.isLoading, isFalse);
      expect(
        fakeAnalytics.loggedEvents.any(
          (e) => e.name == 'profile_save_succeeded',
        ),
        isTrue,
      );
    });

    test('submit failure (Firestore error) sets '
        'saveError and fires profile_save_failed', () async {
      fakeRepository.shouldFailCreate = true;
      controller.setDisplayName('Avtansh');
      await controller.submit(uid: 'uid-1', phoneNumber: '+919876543210');

      expect(controller.state.saveError, isNotNull);
      expect(controller.state.isSaved, isFalse);
      expect(
        fakeAnalytics.loggedEvents.any(
          (e) =>
              e.name == 'profile_save_failed' &&
              e.parameters?['error_source'] == 'firestore',
        ),
        isTrue,
      );
    });

    test('photo upload failure does not block '
        'submit, doc created with null photoUrl', () async {
      fakeRepository.shouldFailUpload = true;
      fakeImagePicker.galleryResult = XFile('/fake/photo.jpg');
      controller.setDisplayName('Avtansh');
      await controller.pickPhoto(fromCamera: false);
      await controller.submit(uid: 'uid-1', phoneNumber: '+919876543210');

      expect(controller.state.isSaved, isTrue);
      expect(fakeRepository.lastCreatePhotoUrl, isNull);
      expect(
        fakeAnalytics.loggedEvents.any(
          (e) =>
              e.name == 'profile_save_failed' &&
              e.parameters?['error_source'] == 'storage',
        ),
        isTrue,
      );
      expect(
        fakeAnalytics.loggedEvents.any(
          (e) => e.name == 'profile_save_succeeded',
        ),
        isTrue,
      );
    });

    test('submit fires profile_save_requested '
        'with correct params', () async {
      controller.setDisplayName('Avtansh');
      await controller.submit(uid: 'uid-1', phoneNumber: '+919876543210');

      final event = fakeAnalytics.loggedEvents.firstWhere(
        (e) => e.name == 'profile_save_requested',
      );
      expect(event.parameters?['has_photo'], 0);
      expect(event.parameters?['name_length'], 7);
    });

    test('submit without photo fires '
        'profile_photo_skipped', () async {
      controller.setDisplayName('Avtansh');
      await controller.submit(uid: 'uid-1', phoneNumber: '+919876543210');

      expect(
        fakeAnalytics.loggedEvents.any(
          (e) => e.name == 'profile_photo_skipped',
        ),
        isTrue,
      );
    });

    test('pickPhoto fires '
        'profile_photo_picker_opened', () async {
      await controller.pickPhoto(fromCamera: false);

      expect(
        fakeAnalytics.loggedEvents.any(
          (e) => e.name == 'profile_photo_picker_opened',
        ),
        isTrue,
      );
    });

    test('pickPhoto with successful selection '
        'fires profile_photo_selected', () async {
      fakeImagePicker.galleryResult = XFile('/fake/photo.jpg');
      await controller.pickPhoto(fromCamera: false);

      expect(controller.state.selectedPhotoPath, '/fake/photo.jpg');
      expect(
        fakeAnalytics.loggedEvents.any(
          (e) =>
              e.name == 'profile_photo_selected' &&
              e.parameters?['source'] == 'gallery',
        ),
        isTrue,
      );
    });

    test('submit with empty name sets '
        'displayNameError', () async {
      controller.setDisplayName('');
      await controller.submit(uid: 'uid-1', phoneNumber: '+919876543210');

      expect(controller.state.displayNameError, 'Please enter your name.');
      expect(fakeRepository.createUserCallCount, 0);
    });

    test('submit with whitespace-only name sets '
        'displayNameError', () async {
      controller.setDisplayName('   ');
      await controller.submit(uid: 'uid-1', phoneNumber: '+919876543210');

      expect(controller.state.displayNameError, 'Please enter your name.');
    });

    test('submit with name over 50 chars sets '
        'displayNameError', () async {
      controller.setDisplayName('A' * 51);
      await controller.submit(uid: 'uid-1', phoneNumber: '+919876543210');

      expect(
        controller.state.displayNameError,
        'Name must be 50 characters or fewer.',
      );
    });
  });
}
