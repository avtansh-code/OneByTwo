import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/application/auth_state_provider.dart';
import 'package:onebytwo/core/services/image_picker_service.dart';
import 'package:onebytwo/features/auth/data/user_repository.dart';
import 'package:onebytwo/features/auth/domain/auth_state.dart';

/// Maximum allowed photo file size in bytes (5 MB).
const int maxPhotoSizeBytes = 5 * 1024 * 1024;

/// Accepted photo MIME extensions.
const Set<String> acceptedPhotoExtensions = {'.jpg', '.jpeg', '.png'};

/// Immutable state for the edit profile form (SCR-26).
class EditProfileState {
  /// Creates an [EditProfileState].
  const EditProfileState({
    required this.originalName,
    required this.originalPhotoUrl,
    required this.currentName,
    this.selectedPhotoPath,
    this.isPhotoRemoved = false,
    this.isSaving = false,
    this.isUploadingPhoto = false,
    this.error,
    this.nameError,
    this.saveSucceeded = false,
  });

  /// The display name when the screen was opened.
  final String originalName;

  /// The photo URL when the screen was opened.
  final String? originalPhotoUrl;

  /// The current display name input.
  final String currentName;

  /// Local file path of a newly-selected photo.
  final String? selectedPhotoPath;

  /// Whether the user has chosen to remove their photo.
  final bool isPhotoRemoved;

  /// Whether a save operation is in progress.
  final bool isSaving;

  /// Whether a photo upload is in progress.
  final bool isUploadingPhoto;

  /// Non-null when a general error has occurred.
  final String? error;

  /// Non-null when the display name has a validation error.
  final String? nameError;

  /// Whether the last save operation succeeded.
  final bool saveSucceeded;

  /// Whether the user has made any changes.
  bool get hasChanges =>
      currentName.trim() != originalName ||
      selectedPhotoPath != null ||
      isPhotoRemoved;

  /// Whether the form can be submitted.
  bool get canSave =>
      hasChanges &&
      !isSaving &&
      nameError == null &&
      currentName.trim().isNotEmpty;

  /// Creates a copy with the given fields replaced.
  EditProfileState copyWith({
    String? originalName,
    String? Function()? originalPhotoUrl,
    String? currentName,
    String? Function()? selectedPhotoPath,
    bool? isPhotoRemoved,
    bool? isSaving,
    bool? isUploadingPhoto,
    String? Function()? error,
    String? Function()? nameError,
    bool? saveSucceeded,
  }) {
    return EditProfileState(
      originalName: originalName ?? this.originalName,
      originalPhotoUrl: originalPhotoUrl != null
          ? originalPhotoUrl()
          : this.originalPhotoUrl,
      currentName: currentName ?? this.currentName,
      selectedPhotoPath: selectedPhotoPath != null
          ? selectedPhotoPath()
          : this.selectedPhotoPath,
      isPhotoRemoved: isPhotoRemoved ?? this.isPhotoRemoved,
      isSaving: isSaving ?? this.isSaving,
      isUploadingPhoto: isUploadingPhoto ?? this.isUploadingPhoto,
      error: error != null ? error() : this.error,
      nameError: nameError != null ? nameError() : this.nameError,
      saveSucceeded: saveSucceeded ?? this.saveSucceeded,
    );
  }
}

/// Controller for the edit profile screen (FR-PR-01).
///
/// Manages display name editing, photo selection/removal,
/// validation, and save orchestration.
class EditProfileController extends StateNotifier<EditProfileState> {
  /// Creates an [EditProfileController].
  EditProfileController({
    required String originalName,
    required String? originalPhotoUrl,
    required String uid,
    required AnalyticsService analytics,
    required UserRepository repository,
    required ImagePickerService imagePicker,
  }) : _uid = uid,
       _analytics = analytics,
       _repository = repository,
       _imagePicker = imagePicker,
       super(
         EditProfileState(
           originalName: originalName,
           originalPhotoUrl: originalPhotoUrl,
           currentName: originalName,
         ),
       );

  final String _uid;
  final AnalyticsService _analytics;
  final UserRepository _repository;
  final ImagePickerService _imagePicker;

  /// Updates the display name and validates it.
  void updateName(String name) {
    String? nameError;
    if (name.trim().isEmpty) {
      nameError = 'Display name cannot be empty.';
    } else if (name.trim().length > 50) {
      nameError = 'Display name must be 50 characters or fewer.';
    }

    state = state.copyWith(
      currentName: name,
      nameError: () => nameError,
      error: () => null,
    );
  }

  /// Sets the selected photo path from a local file.
  void selectPhoto(String filePath) {
    state = state.copyWith(
      selectedPhotoPath: () => filePath,
      isPhotoRemoved: false,
    );
  }

  /// Marks the photo for removal.
  void removePhoto() {
    state = state.copyWith(isPhotoRemoved: true, selectedPhotoPath: () => null);
  }

  /// Opens the image picker for camera.
  Future<void> pickFromCamera() async {
    final file = await _imagePicker.pickFromCamera();
    if (file != null) {
      final validationError = await _validatePhoto(file.path);
      if (validationError != null) {
        state = state.copyWith(error: () => validationError);
        return;
      }
      selectPhoto(file.path);
      await _analytics.logEvent(
        name: 'profile_photo_changed',
        parameters: {'action': 'take'},
      );
    }
  }

  /// Opens the image picker for gallery.
  Future<void> pickFromGallery() async {
    final file = await _imagePicker.pickFromGallery();
    if (file != null) {
      final validationError = await _validatePhoto(file.path);
      if (validationError != null) {
        state = state.copyWith(error: () => validationError);
        return;
      }
      selectPhoto(file.path);
      await _analytics.logEvent(
        name: 'profile_photo_changed',
        parameters: {'action': 'choose'},
      );
    }
  }

  /// Validates photo file size (<= 5 MB) and format (JPEG/PNG).
  ///
  /// Returns an error message string if validation fails, or
  /// `null` if the file is acceptable.
  Future<String?> _validatePhoto(String path) async {
    final file = File(path);
    final extension = path.toLowerCase().split('.').last;
    if (!acceptedPhotoExtensions.contains('.$extension')) {
      return 'Unsupported image format.';
    }
    final size = await file.length();
    if (size > maxPhotoSizeBytes) {
      return 'Photo must be under 5 MB.';
    }
    return null;
  }

  /// Removes the profile photo and fires telemetry.
  Future<void> removePhotoWithTelemetry() async {
    removePhoto();
    await _analytics.logEvent(
      name: 'profile_photo_changed',
      parameters: {'action': 'remove'},
    );
  }

  /// Validates and saves the profile changes.
  ///
  /// Orchestrates: upload photo if needed, delete old avatar
  /// if removed, update Firestore document, fire telemetry.
  Future<void> save() async {
    final trimmedName = state.currentName.trim();

    // Validate name.
    if (trimmedName.isEmpty) {
      state = state.copyWith(nameError: () => 'Display name cannot be empty.');
      return;
    }
    if (trimmedName.length > 50) {
      state = state.copyWith(
        nameError: () => 'Display name must be 50 characters or fewer.',
      );
      return;
    }

    state = state.copyWith(
      isSaving: true,
      error: () => null,
      saveSucceeded: false,
    );

    // Upload new photo if selected.
    String? newPhotoUrl;
    if (state.selectedPhotoPath != null) {
      try {
        state = state.copyWith(isUploadingPhoto: true);
        newPhotoUrl = await _repository
            .uploadAvatar(_uid, state.selectedPhotoPath!)
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () => throw TimeoutException('Upload timed out'),
            );
        state = state.copyWith(isUploadingPhoto: false);
      } on TimeoutException {
        if (!mounted) return;
        state = state.copyWith(
          isUploadingPhoto: false,
          isSaving: false,
          error: () =>
              'Photo upload timed out. '
              'Please try again on a better connection.',
        );
        return;
      } catch (e) {
        if (!mounted) return;
        state = state.copyWith(
          isUploadingPhoto: false,
          isSaving: false,
          error: () => 'Photo upload failed. Try again.',
        );
        return;
      }
    }

    // Delete old avatar if photo is being removed.
    if (state.isPhotoRemoved) {
      try {
        await _repository.deleteAvatar(_uid);
      } catch (e) {
        // Non-blocking; continue with the update.
      }
    }

    // Build the fields-changed list for telemetry.
    final fieldsChanged = <String>[];
    final nameChanged = trimmedName != state.originalName;
    if (nameChanged) fieldsChanged.add('displayName');
    if (state.selectedPhotoPath != null) {
      fieldsChanged.add('photoUrl');
    }
    if (state.isPhotoRemoved) fieldsChanged.add('photoRemoved');

    // Update Firestore.
    try {
      await _repository.updateProfile(
        uid: _uid,
        displayName: nameChanged ? trimmedName : null,
        photoUrl: newPhotoUrl,
        removePhoto: state.isPhotoRemoved,
      );

      if (!mounted) return;

      state = state.copyWith(isSaving: false, saveSucceeded: true);

      await _analytics.logEvent(
        name: 'profile_edited',
        parameters: {'fields_changed': fieldsChanged.join(',')},
      );
    } catch (e) {
      if (!mounted) return;

      state = state.copyWith(
        isSaving: false,
        error: () => 'Could not update profile. Try again.',
      );
    }
  }
}

/// Riverpod provider for [EditProfileController].
///
/// Auto-disposing so the controller is cleaned up when the
/// edit profile screen is removed from the widget tree.
final editProfileControllerProvider =
    StateNotifierProvider.autoDispose<EditProfileController, EditProfileState>((
      ref,
    ) {
      final authState = ref.read(authStateNotifierProvider).valueOrNull;
      final user = switch (authState) {
        AuthenticatedWithProfile(:final user) => user,
        _ => null,
      };
      final uid = switch (authState) {
        AuthenticatedWithProfile(:final uid) => uid,
        _ => '',
      };

      return EditProfileController(
        originalName: user?.displayName ?? '',
        originalPhotoUrl: user?.photoUrl,
        uid: uid,
        analytics: ref.watch(analyticsServiceProvider),
        repository: ref.watch(userRepositoryProvider),
        imagePicker: ref.watch(imagePickerServiceProvider),
      );
    });
