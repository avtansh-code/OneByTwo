import 'package:flutter/material.dart';

/// The action chosen in the [PhotoPickerSheet].
enum PhotoPickerAction {
  /// Take a photo with the camera.
  takePhoto,

  /// Choose an image from the gallery.
  chooseFromGallery,

  /// Remove the existing photo.
  removePhoto,
}

/// Bottom sheet for selecting a profile photo action.
///
/// Presents options to take a photo, choose from gallery,
/// and optionally remove the current photo. Returns the
/// chosen [PhotoPickerAction] via [Navigator.pop].
class PhotoPickerSheet extends StatelessWidget {
  /// Creates a [PhotoPickerSheet].
  ///
  /// When [hasExistingPhoto] is true, the "Remove Photo"
  /// option is displayed.
  const PhotoPickerSheet({required this.hasExistingPhoto, super.key});

  /// Whether the user currently has a profile photo.
  final bool hasExistingPhoto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Semantics(
          label: 'Change Profile Photo, action sheet',
          container: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  'Change Profile Photo',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 8),
              Semantics(
                button: true,
                label: 'Take Photo, button',
                child: SizedBox(
                  height: 56,
                  child: ListTile(
                    leading: Icon(
                      Icons.camera_alt,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text('Take Photo'),
                    minVerticalPadding: 12,
                    onTap: () =>
                        Navigator.of(context).pop(PhotoPickerAction.takePhoto),
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: 'Choose from Gallery, button',
                child: SizedBox(
                  height: 56,
                  child: ListTile(
                    leading: Icon(
                      Icons.photo_library,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text('Choose from Gallery'),
                    minVerticalPadding: 12,
                    onTap: () => Navigator.of(
                      context,
                    ).pop(PhotoPickerAction.chooseFromGallery),
                  ),
                ),
              ),
              if (hasExistingPhoto)
                Semantics(
                  button: true,
                  label: 'Remove Photo, destructive, button',
                  child: SizedBox(
                    height: 56,
                    child: ListTile(
                      leading: Icon(
                        Icons.delete_outline,
                        color: theme.colorScheme.error,
                      ),
                      title: Text(
                        'Remove Photo',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                      minVerticalPadding: 12,
                      onTap: () => Navigator.of(
                        context,
                      ).pop(PhotoPickerAction.removePhoto),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Semantics(
                button: true,
                label: 'Cancel, button',
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
