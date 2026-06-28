import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/widgets/branding/obt_gradient_avatar.dart';
import 'package:onebytwo/features/auth/application/auth_state_provider.dart';
import 'package:onebytwo/features/auth/domain/auth_state.dart';
import 'package:onebytwo/features/profile/application/edit_profile_controller.dart';
import 'package:onebytwo/features/profile/presentation/change_phone_screen.dart';
import 'package:onebytwo/features/profile/presentation/widgets/photo_picker_sheet.dart';

/// Edit profile screen for FR-PR-01 (SCR-26 edit sub-screen).
///
/// Allows the user to update their display name and profile
/// photo. Pushed from the "Edit Profile" row on the profile screen.
class EditProfileScreen extends ConsumerStatefulWidget {
  /// Creates an [EditProfileScreen].
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(editProfileControllerProvider);
    _nameController = TextEditingController(text: state.currentName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(editProfileControllerProvider);
    final controller = ref.read(editProfileControllerProvider.notifier);

    // Get phone number from auth state.
    final authState = ref.watch(authStateProvider).valueOrNull;
    final phoneNumber = switch (authState) {
      AuthenticatedWithProfile(:final user) => user.phoneNumber,
      _ => '',
    };

    // Listen for save success to pop back.
    ref.listen<EditProfileState>(editProfileControllerProvider, (
      previous,
      next,
    ) {
      if (next.saveSucceeded && !(previous?.saveSucceeded ?? false)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile updated')));
        Navigator.of(context).pop();
      }
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            action: SnackBarAction(label: 'Retry', onPressed: controller.save),
          ),
        );
      }
    });

    // Determine the effective photo state for display.
    final hasPhoto =
        !state.isPhotoRemoved &&
        (state.selectedPhotoPath != null || state.originalPhotoUrl != null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        leading: BackButton(
          onPressed: state.isSaving ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: state.isSaving,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Avatar with camera badge.
                _buildAvatar(context, theme, state, controller, hasPhoto),
                const SizedBox(height: 32),

                // Display name text field.
                Semantics(
                  label: state.nameError != null
                      ? 'Display name, text field, required, '
                            'error: ${state.nameError}'
                      : 'Display name, text field, required',
                  textField: true,
                  child: TextField(
                    controller: _nameController,
                    enabled: !state.isSaving,
                    maxLength: 50,
                    decoration: InputDecoration(
                      labelText: 'Display name',
                      errorText: state.nameError,
                      counterText: _nameController.text.length > 40
                          ? '${_nameController.text.length}/50'
                          : '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusChipInput,
                        ),
                      ),
                      suffixIcon:
                          _nameController.text.isNotEmpty && !state.isSaving
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _nameController.clear();
                                controller.updateName('');
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      controller.updateName(value);
                      // Trigger rebuild for suffix icon and
                      // counter.
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Phone number row — tappable "Change Phone Number"
                // (FR-PR-02; resolves SCR-26 Open Question #1).
                Semantics(
                  button: true,
                  label:
                      'Phone number, '
                      '${_formatPhoneForA11y(phoneNumber)}, '
                      'change phone number',
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: state.isSaving
                        ? null
                        : () => Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => const ChangePhoneScreen(),
                            ),
                          ),
                    borderRadius: BorderRadius.circular(
                      AppTheme.radiusChipInput,
                    ),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Phone number',
                        helperText: 'Tap to change your phone number.',
                        suffixIcon: const Icon(Icons.chevron_right),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusChipInput,
                          ),
                        ),
                      ),
                      child: Text(
                        _formatPhoneDisplay(phoneNumber),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Save button.
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: Semantics(
                    button: true,
                    label: state.isSaving
                        ? 'Saving profile'
                        : (state.canSave
                              ? 'Save changes, button'
                              : 'Save changes, button, disabled'),
                    child: FilledButton(
                      onPressed: state.canSave ? controller.save : null,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusButton,
                          ),
                        ),
                      ),
                      child: state.isSaving
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.onPrimary,
                              ),
                            )
                          : const Text('Save changes'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(
    BuildContext context,
    ThemeData theme,
    EditProfileState state,
    EditProfileController controller,
    bool hasPhoto,
  ) {
    Widget avatarChild;
    const avatarSize = 96.0;

    if (state.selectedPhotoPath != null) {
      // Newly-selected local photo — a rounded-square preview.
      avatarChild = Container(
        width: avatarSize,
        height: avatarSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(avatarSize * 0.33),
          image: DecorationImage(
            image: FileImage(File(state.selectedPhotoPath!)),
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      // Existing remote photo, or the gradient initial fallback.
      final name = state.currentName.trim().isNotEmpty
          ? state.currentName
          : state.originalName;
      avatarChild = OBTGradientAvatar(
        size: avatarSize,
        displayName: name,
        photoUrl: state.isPhotoRemoved ? null : state.originalPhotoUrl,
      );
    }

    return Semantics(
      button: true,
      label: 'Change profile photo, button',
      child: GestureDetector(
        onTap: state.isSaving
            ? null
            : () => _showPhotoPicker(context, controller, hasPhoto),
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            avatarChild,
            // Upload progress overlay.
            if (state.isUploadingPhoto)
              Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(avatarSize * 0.33),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                ),
              ),
            // Camera badge — dark disc with a cream glyph and a background
            // ring (the Haldi photo affordance, matching profile setup).
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.scaffoldBackgroundColor,
                  width: 3,
                ),
              ),
              child: Icon(
                Icons.photo_camera,
                size: 16,
                color: theme.colorScheme.surface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPhotoPicker(
    BuildContext context,
    EditProfileController controller,
    bool hasPhoto,
  ) async {
    final action = await showModalBottomSheet<PhotoPickerAction>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusSheet),
        ),
      ),
      builder: (_) => PhotoPickerSheet(hasExistingPhoto: hasPhoto),
    );

    if (action == null) return;

    switch (action) {
      case PhotoPickerAction.takePhoto:
        await controller.pickFromCamera();
      case PhotoPickerAction.chooseFromGallery:
        await controller.pickFromGallery();
      case PhotoPickerAction.removePhoto:
        await controller.removePhotoWithTelemetry();
    }
  }
}

/// Formats "+919876543210" for display as "+91 98765 43210".
String _formatPhoneDisplay(String phone) {
  if (phone.startsWith('+91') && phone.length == 13) {
    final digits = phone.substring(3);
    return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
  }
  return phone;
}

/// Formats a phone number for accessible screen reader output.
///
/// Converts "+919876543210" to "plus 91 98765 43210".
String _formatPhoneForA11y(String phone) {
  if (phone.startsWith('+91') && phone.length == 13) {
    final digits = phone.substring(3);
    return 'plus 91 ${digits.substring(0, 5)} ${digits.substring(5)}';
  }
  return phone;
}
