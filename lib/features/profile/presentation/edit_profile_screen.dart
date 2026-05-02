import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/features/auth/application/auth_state_provider.dart';
import 'package:onebytwo/features/auth/domain/auth_state.dart';
import 'package:onebytwo/features/profile/application/edit_profile_controller.dart';
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
    final authState = ref.watch(authStateNotifierProvider).valueOrNull;
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
                  label: 'Display name, text field, required',
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
                          AppTheme.radiusMedium,
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

                // Phone number field (read-only).
                Semantics(
                  label: 'Phone number, $phoneNumber, read-only',
                  child: TextField(
                    enabled: false,
                    controller: TextEditingController(text: phoneNumber),
                    decoration: InputDecoration(
                      labelText: 'Phone number',
                      helperText:
                          'Phone number cannot be changed '
                          'from here.',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
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
                    label: state.canSave
                        ? 'Save, button'
                        : 'Save, button, disabled',
                    child: FilledButton(
                      onPressed: state.canSave ? controller.save : null,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMedium,
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
                          : const Text('Save'),
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

    if (state.selectedPhotoPath != null) {
      // Newly-selected local photo.
      avatarChild = CircleAvatar(
        radius: 48,
        backgroundImage: FileImage(File(state.selectedPhotoPath!)),
      );
    } else if (!state.isPhotoRemoved && state.originalPhotoUrl != null) {
      // Existing remote photo.
      avatarChild = CircleAvatar(
        radius: 48,
        backgroundImage: NetworkImage(state.originalPhotoUrl!),
      );
    } else {
      // Initials fallback.
      final name = state.currentName.trim().isNotEmpty
          ? state.currentName
          : state.originalName;
      avatarChild = CircleAvatar(
        radius: 48,
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          _initials(name),
          style: theme.textTheme.headlineMedium?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
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
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.camera_alt,
                size: 16,
                color: theme.colorScheme.onPrimary,
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
          top: Radius.circular(AppTheme.radiusXL),
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

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }
}
