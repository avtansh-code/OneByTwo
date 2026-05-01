import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/data/image_picker_service.dart';
import 'package:onebytwo/features/auth/data/user_repository.dart';

/// Immutable state for the profile setup form (SCR-05).
class ProfileSetupState {
  /// Creates a [ProfileSetupState].
  const ProfileSetupState({
    this.displayName = '',
    this.displayNameError,
    this.selectedPhotoPath,
    this.isPhotoUploading = false,
    this.isLoading = false,
    this.isSaved = false,
    this.saveError,
  });

  /// The current display name input.
  final String displayName;

  /// Non-null when the display name has a validation error.
  final String? displayNameError;

  /// Path to the locally-selected photo file.
  final String? selectedPhotoPath;

  /// Whether a photo upload is in progress.
  final bool isPhotoUploading;

  /// Whether the save operation is in progress.
  final bool isLoading;

  /// Whether the profile was saved successfully.
  final bool isSaved;

  /// Non-null when the last save operation failed.
  final String? saveError;

  /// Whether the form can be submitted.
  bool get canSubmit =>
      displayName.trim().isNotEmpty &&
      displayName.trim().length <= 50 &&
      !isLoading;

  /// Creates a copy with the given fields replaced.
  ProfileSetupState copyWith({
    String? displayName,
    String? Function()? displayNameError,
    String? Function()? selectedPhotoPath,
    bool? isPhotoUploading,
    bool? isLoading,
    bool? isSaved,
    String? Function()? saveError,
  }) {
    return ProfileSetupState(
      displayName: displayName ?? this.displayName,
      displayNameError: displayNameError != null
          ? displayNameError()
          : this.displayNameError,
      selectedPhotoPath: selectedPhotoPath != null
          ? selectedPhotoPath()
          : this.selectedPhotoPath,
      isPhotoUploading: isPhotoUploading ?? this.isPhotoUploading,
      isLoading: isLoading ?? this.isLoading,
      isSaved: isSaved ?? this.isSaved,
      saveError: saveError != null ? saveError() : this.saveError,
    );
  }
}

/// Controller for the profile setup screen (FR-AU-06).
///
/// Manages display name input, optional photo selection and
/// upload, user document creation, and telemetry events.
class ProfileSetupController extends StateNotifier<ProfileSetupState> {
  /// Creates a [ProfileSetupController].
  ProfileSetupController({
    required AnalyticsService analytics,
    required UserRepository repository,
    required ImagePickerService imagePicker,
  }) : _analytics = analytics,
       _repository = repository,
       _imagePicker = imagePicker,
       super(const ProfileSetupState());

  final AnalyticsService _analytics;
  final UserRepository _repository;
  final ImagePickerService _imagePicker;

  /// Updates the display name and clears any prior error.
  void setDisplayName(String value) {
    state = state.copyWith(
      displayName: value,
      displayNameError: () => null,
      saveError: () => null,
    );
  }

  /// Opens the image picker (camera or gallery).
  ///
  /// Fires `profile_photo_picker_opened` on invocation and
  /// `profile_photo_selected` on successful selection.
  Future<void> pickPhoto({required bool fromCamera}) async {
    await _analytics.logEvent(name: 'profile_photo_picker_opened');

    final file = fromCamera
        ? await _imagePicker.pickFromCamera()
        : await _imagePicker.pickFromGallery();

    if (file != null) {
      state = state.copyWith(selectedPhotoPath: () => file.path);
      await _analytics.logEvent(
        name: 'profile_photo_selected',
        parameters: {'source': fromCamera ? 'camera' : 'gallery'},
      );
    }
  }

  /// Validates and submits the profile.
  ///
  /// Orchestrates: validate name, upload photo if selected
  /// (handle failure gracefully), create user doc, fire
  /// telemetry. Per SCR-05, photo upload failure does not
  /// block user document creation.
  Future<void> submit({
    required String uid,
    required String phoneNumber,
  }) async {
    final trimmedName = state.displayName.trim();

    // Client-side validation.
    if (trimmedName.isEmpty) {
      state = state.copyWith(displayNameError: () => 'Please enter your name.');
      return;
    }
    if (trimmedName.length > 50) {
      state = state.copyWith(
        displayNameError: () => 'Name must be 50 characters or fewer.',
      );
      return;
    }

    final hasPhoto = state.selectedPhotoPath != null;

    // Fire skipped event if no photo.
    if (!hasPhoto) {
      await _analytics.logEvent(name: 'profile_photo_skipped');
    }

    await _analytics.logEvent(
      name: 'profile_save_requested',
      parameters: {'has_photo': hasPhoto, 'name_length': trimmedName.length},
    );

    state = state.copyWith(isLoading: true, saveError: () => null);

    final stopwatch = Stopwatch()..start();

    // Upload photo if selected (graceful degradation).
    String? photoUrl;
    if (hasPhoto) {
      try {
        state = state.copyWith(isPhotoUploading: true);
        photoUrl = await _repository.uploadAvatar(
          uid,
          state.selectedPhotoPath!,
        );
        state = state.copyWith(isPhotoUploading: false);
      } catch (e) {
        debugPrint('[ProfileSetup] Photo upload failed: $e');
        state = state.copyWith(isPhotoUploading: false);
        await _analytics.logEvent(
          name: 'profile_save_failed',
          parameters: {'error_code': e.toString(), 'error_source': 'storage'},
        );
        // Continue with null photoUrl.
      }
    }

    // Create user document.
    try {
      await _repository.createUser(
        uid: uid,
        displayName: trimmedName,
        phoneNumber: phoneNumber,
        photoUrl: photoUrl,
      );

      stopwatch.stop();

      if (!mounted) return;

      state = state.copyWith(isLoading: false, isSaved: true);

      await _analytics.logEvent(
        name: 'profile_save_succeeded',
        parameters: {
          'duration_ms': stopwatch.elapsedMilliseconds,
          'has_photo': photoUrl != null,
        },
      );
    } catch (e) {
      stopwatch.stop();

      if (!mounted) return;

      final errorMessage =
          e.toString().contains('network') ||
              e.toString().contains('offline') ||
              e.toString().contains('UNAVAILABLE')
          ? 'No internet connection. '
                'Check your network and try again.'
          : 'Could not save your profile. '
                'Please try again.';

      state = state.copyWith(isLoading: false, saveError: () => errorMessage);

      await _analytics.logEvent(
        name: 'profile_save_failed',
        parameters: {'error_code': e.toString(), 'error_source': 'firestore'},
      );
    }
  }
}

/// Riverpod provider for [ProfileSetupController].
///
/// Auto-disposing so the controller is cleaned up when the
/// profile setup screen is removed from the widget tree.
final profileSetupControllerProvider =
    StateNotifierProvider.autoDispose<
      ProfileSetupController,
      ProfileSetupState
    >(
      (ref) => ProfileSetupController(
        analytics: ref.watch(analyticsServiceProvider),
        repository: ref.watch(userRepositoryProvider),
        imagePicker: ref.watch(imagePickerServiceProvider),
      ),
    );
