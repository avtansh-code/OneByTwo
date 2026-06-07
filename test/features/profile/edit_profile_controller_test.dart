// ignore_for_file: cascade_invocations
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/core/services/image_picker_service.dart';
import 'package:onebytwo/features/auth/data/user_repository.dart';
import 'package:onebytwo/features/auth/domain/user_model.dart';
import 'package:onebytwo/features/profile/application/edit_profile_controller.dart';

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
  /// When true, [updateProfile] throws.
  bool shouldFailUpdate = false;

  /// When true, [uploadAvatar] throws.
  bool shouldFailUpload = false;

  /// When true, [deleteAvatar] throws.
  bool shouldFailDelete = false;

  /// Number of times [updateProfile] was called.
  int updateProfileCallCount = 0;

  /// Last displayName passed to [updateProfile].
  String? lastUpdateDisplayName;

  /// Last photoUrl passed to [updateProfile].
  String? lastUpdatePhotoUrl;

  /// Last removePhoto passed to [updateProfile].
  bool lastRemovePhoto = false;

  /// Number of times [uploadAvatar] was called.
  int uploadAvatarCallCount = 0;

  /// Number of times [deleteAvatar] was called.
  int deleteAvatarCallCount = 0;

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
  Future<String> uploadAvatar(String uid, String filePath) async {
    uploadAvatarCallCount++;
    if (shouldFailUpload) {
      throw Exception('Storage upload failed');
    }
    return 'https://example.com/avatar-new.jpg';
  }

  @override
  Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? photoUrl,
    bool removePhoto = false,
  }) async {
    updateProfileCallCount++;
    lastUpdateDisplayName = displayName;
    lastUpdatePhotoUrl = photoUrl;
    lastRemovePhoto = removePhoto;
    if (shouldFailUpdate) {
      throw Exception('Firestore update failed');
    }
  }

  @override
  Future<void> deleteAvatar(String uid) async {
    deleteAvatarCallCount++;
    if (shouldFailDelete) {
      throw Exception('Storage delete failed');
    }
  }
}

/// Fake [ImagePickerService] with configurable behaviour.
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
  late EditProfileController controller;

  EditProfileController createController({
    String originalName = 'Test User',
    String? originalPhotoUrl,
    String uid = 'test-uid',
  }) {
    return EditProfileController(
      originalName: originalName,
      originalPhotoUrl: originalPhotoUrl,
      uid: uid,
      analytics: fakeAnalytics,
      repository: fakeRepository,
      imagePicker: fakeImagePicker,
    );
  }

  setUp(() {
    fakeAnalytics = FakeAnalyticsService();
    fakeRepository = FakeUserRepository();
    fakeImagePicker = FakeImagePickerService();
    controller = createController();
  });

  tearDown(() {
    controller.dispose();
  });

  group('EditProfileController', () {
    test('initial state has original name and photo from '
        'user model', () {
      final c = createController(
        originalName: 'Avtansh',
        originalPhotoUrl: 'https://example.com/photo.jpg',
      );
      expect(c.state.originalName, 'Avtansh');
      expect(c.state.originalPhotoUrl, 'https://example.com/photo.jpg');
      expect(c.state.currentName, 'Avtansh');
      expect(c.state.hasChanges, isFalse);
      expect(c.state.canSave, isFalse);
      c.dispose();
    });

    test('updateName with valid name clears error '
        'and enables save', () {
      controller.updateName('New Name');
      expect(controller.state.currentName, 'New Name');
      expect(controller.state.nameError, isNull);
      expect(controller.state.canSave, isTrue);
    });

    test('updateName with empty string sets error '
        '"Display name cannot be empty."', () {
      controller.updateName('');
      expect(controller.state.nameError, 'Display name cannot be empty.');
      expect(controller.state.canSave, isFalse);
    });

    test('updateName with whitespace-only sets error '
        '"Display name cannot be empty."', () {
      controller.updateName('   ');
      expect(controller.state.nameError, 'Display name cannot be empty.');
      expect(controller.state.canSave, isFalse);
    });

    test('updateName with >50 chars sets error '
        '"Display name must be 50 characters or fewer."', () {
      controller.updateName('A' * 51);
      expect(
        controller.state.nameError,
        'Display name must be 50 characters or fewer.',
      );
      expect(controller.state.canSave, isFalse);
    });

    test('updateName with exactly 50 characters is accepted', () {
      controller.updateName('A' * 50);
      expect(controller.state.nameError, isNull);
      expect(controller.state.canSave, isTrue);
    });

    test('selectPhoto sets selectedPhotoPath and '
        'enables save', () {
      controller.selectPhoto('/fake/photo.jpg');
      expect(controller.state.selectedPhotoPath, '/fake/photo.jpg');
      expect(controller.state.hasChanges, isTrue);
      expect(controller.state.canSave, isTrue);
    });

    test('removePhoto sets isPhotoRemoved and '
        'enables save', () {
      controller.removePhoto();
      expect(controller.state.isPhotoRemoved, isTrue);
      expect(controller.state.selectedPhotoPath, isNull);
      expect(controller.state.hasChanges, isTrue);
      expect(controller.state.canSave, isTrue);
    });

    test('save with name change only calls updateProfile '
        '(no upload)', () async {
      controller.updateName('New Name');
      await controller.save();

      expect(fakeRepository.updateProfileCallCount, 1);
      expect(fakeRepository.lastUpdateDisplayName, 'New Name');
      expect(fakeRepository.uploadAvatarCallCount, 0);
      expect(controller.state.saveSucceeded, isTrue);
    });

    test('save with photo change calls uploadAvatar '
        'then updateProfile', () async {
      controller.selectPhoto('/fake/photo.jpg');
      await controller.save();

      expect(fakeRepository.uploadAvatarCallCount, 1);
      expect(fakeRepository.updateProfileCallCount, 1);
      expect(
        fakeRepository.lastUpdatePhotoUrl,
        'https://example.com/avatar-new.jpg',
      );
      expect(controller.state.saveSucceeded, isTrue);
    });

    test('save with photo upload failure emits error '
        'and photoUrl unchanged', () async {
      fakeRepository.shouldFailUpload = true;
      controller.selectPhoto('/fake/photo.jpg');
      await controller.save();

      expect(controller.state.error, isNotNull);
      expect(controller.state.saveSucceeded, isFalse);
      expect(fakeRepository.updateProfileCallCount, 0);
    });

    test('save with photo removal calls deleteAvatar '
        'and updateProfile with removePhoto', () async {
      controller.removePhoto();
      await controller.save();

      expect(fakeRepository.deleteAvatarCallCount, 1);
      expect(fakeRepository.updateProfileCallCount, 1);
      expect(fakeRepository.lastRemovePhoto, isTrue);
      expect(controller.state.saveSucceeded, isTrue);
    });

    test('save with Firestore failure emits error', () async {
      fakeRepository.shouldFailUpdate = true;
      controller.updateName('New Name');
      await controller.save();

      expect(controller.state.error, isNotNull);
      expect(controller.state.saveSucceeded, isFalse);
    });

    test('telemetry fires profile_edited on save '
        'success', () async {
      controller.updateName('New Name');
      await controller.save();

      expect(
        fakeAnalytics.loggedEvents.any((e) => e.name == 'profile_edited'),
        isTrue,
      );
      final event = fakeAnalytics.loggedEvents.firstWhere(
        (e) => e.name == 'profile_edited',
      );
      expect(event.parameters?['fields_changed'], contains('displayName'));
    });

    test('pickFromCamera fires profile_photo_changed '
        'with action "take"', () async {
      final tempFile = File('${Directory.systemTemp.path}/test_cam.jpg');
      tempFile.writeAsBytesSync([0xFF, 0xD8]); // minimal JPEG header
      addTearDown(tempFile.deleteSync);

      fakeImagePicker.cameraResult = XFile(tempFile.path);
      await controller.pickFromCamera();

      expect(controller.state.selectedPhotoPath, tempFile.path);
      expect(
        fakeAnalytics.loggedEvents.any(
          (e) =>
              e.name == 'profile_photo_changed' &&
              e.parameters?['action'] == 'take',
        ),
        isTrue,
      );
    });

    test('pickFromGallery fires profile_photo_changed '
        'with action "choose"', () async {
      final tempFile = File('${Directory.systemTemp.path}/test_gallery.jpg');
      tempFile.writeAsBytesSync([0xFF, 0xD8]); // minimal JPEG header
      addTearDown(tempFile.deleteSync);

      fakeImagePicker.galleryResult = XFile(tempFile.path);
      await controller.pickFromGallery();

      expect(controller.state.selectedPhotoPath, tempFile.path);
      expect(
        fakeAnalytics.loggedEvents.any(
          (e) =>
              e.name == 'profile_photo_changed' &&
              e.parameters?['action'] == 'choose',
        ),
        isTrue,
      );
    });

    test('removePhotoWithTelemetry fires '
        'profile_photo_changed with action "remove"', () async {
      await controller.removePhotoWithTelemetry();

      expect(controller.state.isPhotoRemoved, isTrue);
      expect(
        fakeAnalytics.loggedEvents.any(
          (e) =>
              e.name == 'profile_photo_changed' &&
              e.parameters?['action'] == 'remove',
        ),
        isTrue,
      );
    });
  });
}
