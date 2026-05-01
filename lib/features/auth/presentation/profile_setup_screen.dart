import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/application/profile_setup_controller.dart';

/// Profile setup screen for FR-AU-06 (SCR-05).
///
/// Collects the user's display name (required) and optional
/// profile photo on first login. Creates the Firestore user
/// document and navigates to the home placeholder on success.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  /// Creates a [ProfileSetupScreen].
  const ProfileSetupScreen({
    required this.uid,
    required this.phoneNumber,
    super.key,
  });

  /// The authenticated user's UID.
  final String uid;

  /// The user's E.164 phone number.
  final String phoneNumber;

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  @override
  void initState() {
    super.initState();
    // Fire profile_setup_viewed on mount.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: 'profile_setup_viewed',
            parameters: {'source': 'otp'},
          );
    });
  }

  void _showPhotoPicker() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take photo'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  ref
                      .read(profileSetupControllerProvider.notifier)
                      .pickPhoto(fromCamera: true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  ref
                      .read(profileSetupControllerProvider.notifier)
                      .pickPhoto(fromCamera: false);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(profileSetupControllerProvider);
    final controller = ref.read(profileSetupControllerProvider.notifier);

    // Post-save routing is handled reactively by the auth gate.
    // When the user doc is created, the Firestore snapshot listener
    // in authStateNotifierProvider detects it and transitions to
    // AuthenticatedWithProfile, causing the auth gate to show home.
    ref.listen<ProfileSetupState>(profileSetupControllerProvider, (
      previous,
      next,
    ) {
      if (next.saveError != null && previous?.saveError == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Semantics(liveRegion: true, child: Text(next.saveError!)),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    });

    final trimmedName = state.displayName.trim();
    final charCount = trimmedName.length;
    final showCounter = charCount > 40;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),

                // Heading.
                Semantics(
                  header: true,
                  child: Text(
                    'Set up your profile',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle.
                Text(
                  'Tell us your name so your '
                  'friends recognise you.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 32),

                // Avatar.
                Center(
                  child: Semantics(
                    button: true,
                    label: state.selectedPhotoPath != null
                        ? 'Profile photo set. '
                              'Tap to change.'
                        : 'Profile photo. '
                              'Tap to add a photo.',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: state.isLoading ? null : _showPhotoPicker,
                      child: SizedBox(
                        width: 88,
                        height: 88,
                        child: Stack(
                          children: [
                            _buildAvatar(theme, state),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: ExcludeSemantics(
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Display name field.
                Semantics(
                  textField: true,
                  label: 'Display name, required',
                  child: TextField(
                    enabled: !state.isLoading,
                    maxLength: 50,
                    buildCounter:
                        (
                          context, {
                          required currentLength,
                          required isFocused,
                          required maxLength,
                        }) {
                          if (!showCounter) return null;
                          return Text(
                            '$charCount/$maxLength',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: charCount > 50
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.onSurface.withValues(
                                      alpha: 0.6,
                                    ),
                            ),
                          );
                        },
                    decoration: InputDecoration(
                      labelText: 'Display name',
                      hintText: 'Enter your display name',
                      errorText: state.displayNameError,
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                    onChanged: controller.setDisplayName,
                  ),
                ),

                // Error live region.
                if (state.displayNameError != null)
                  Semantics(liveRegion: true, child: const SizedBox.shrink()),

                const Spacer(),

                // Continue button.
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: Semantics(
                    button: true,
                    label: state.isLoading
                        ? 'Saving profile'
                        : state.canSubmit
                        ? 'Continue'
                        : 'Continue, disabled',
                    excludeSemantics: true,
                    child: state.isLoading
                        ? Semantics(
                            liveRegion: true,
                            child: FilledButton(
                              onPressed: null,
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          )
                        : FilledButton(
                            onPressed: state.canSubmit
                                ? () => controller.submit(
                                    uid: widget.uid,
                                    phoneNumber: widget.phoneNumber,
                                  )
                                : null,
                            child: const Text('Continue'),
                          ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme, ProfileSetupState state) {
    final trimmedName = state.displayName.trim();

    // Photo selected.
    if (state.selectedPhotoPath != null) {
      return CircleAvatar(
        radius: 40,
        backgroundImage: FileImage(File(state.selectedPhotoPath!)),
      );
    }

    // Initials fallback.
    if (trimmedName.isNotEmpty) {
      final initial = trimmedName[0].toUpperCase();
      final colorIndex = initial.codeUnitAt(0) % Colors.primaries.length;
      return CircleAvatar(
        radius: 40,
        backgroundColor: Colors.primaries[colorIndex],
        child: Text(
          initial,
          style: theme.textTheme.headlineLarge?.copyWith(color: Colors.white),
        ),
      );
    }

    // Generic person icon.
    return CircleAvatar(
      radius: 40,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.person,
        size: 40,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
      ),
    );
  }
}
