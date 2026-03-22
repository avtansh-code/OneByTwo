import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/avatar_widget.dart';
import '../../../providers/auth_providers.dart';

/// Profile setup screen displayed after successful OTP verification for
/// new users.
///
/// Collects the user's display name (required), an optional email address,
/// and an optional profile photo. On submission the avatar is uploaded to
/// Firebase Storage and the user document is created in Firestore via
/// [ProfileSetupNotifier].
///
/// Receives `uid` and `phone` via [GoRouterState.extra] as a
/// `Map<String, String>`.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  /// Creates a [ProfileSetupScreen].
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _imagePicker = ImagePicker();

  /// The image selected by the user from camera or gallery.
  ///
  /// `null` when no image has been selected or after the user removes it.
  XFile? _selectedImage;

  /// Whether the form is currently being submitted (avatar upload + profile
  /// creation).
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Avatar helpers
  // ---------------------------------------------------------------------------

  /// Uploads the selected avatar image to Firebase Storage.
  ///
  /// Returns the download URL on success, or `null` if no image is selected
  /// or if the upload fails. On failure a [SnackBar] is shown but the profile
  /// creation is **not** blocked.
  Future<String?> _uploadAvatar(String uid) async {
    if (_selectedImage == null) return null;
    try {
      final storageRef = FirebaseStorage.instance.ref('users/$uid/avatar');
      await storageRef.putFile(File(_selectedImage!.path));
      return await storageRef.getDownloadURL();
    } catch (_) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.avatarUploadFailed)));
      }
      return null;
    }
  }

  /// Picks an image from the given [source] (camera or gallery).
  ///
  /// Updates [_selectedImage] and triggers a rebuild so the avatar preview
  /// reflects the new selection.
  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        setState(() => _selectedImage = pickedFile);
      }
    } catch (_) {
      // Silently ignore — the user may have denied permissions or cancelled.
    }
  }

  /// Displays a modal bottom sheet with avatar picker options.
  ///
  /// Options include taking a photo, choosing from the gallery, and removing
  /// the current photo (only shown when an image is already selected).
  void _showAvatarOptions() {
    final l10n = AppLocalizations.of(context);

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                l10n.avatarPickerTitle,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(l10n.takePhoto),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(l10n.chooseFromGallery),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_selectedImage != null)
              ListTile(
                leading: const Icon(Icons.delete),
                title: Text(l10n.removePhoto),
                onTap: () {
                  Navigator.pop(sheetContext);
                  setState(() => _selectedImage = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Form submission
  // ---------------------------------------------------------------------------

  /// Validates the form, uploads the avatar (if any), and creates the user
  /// profile in Firestore.
  ///
  /// On success navigates to [RoutePaths.home]. On failure shows a
  /// [SnackBar] with [AppLocalizations.profileSaveFailed].
  Future<void> _onSubmit({required String uid, required String phone}) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // 1. Upload avatar (failures are non-blocking).
    final avatarUrl = await _uploadAvatar(uid);

    // 2. Create the user profile document.
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    final success = await ref
        .read(profileSetupNotifierProvider.notifier)
        .createProfile(
          uid: uid,
          name: name,
          phone: phone,
          email: email.isNotEmpty ? email : null,
          avatarUrl: avatarUrl,
        );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      context.go(RoutePaths.home);
    } else {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.profileSaveFailed)));
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // Extract route parameters passed via GoRouterState.extra.
    final extra = GoRouterState.of(context).extra as Map<String, String>? ?? {};
    final uid = extra['uid'] ?? '';
    final phone = extra['phone'] ?? '';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Title & subtitle ──────────────────────────────
                  Text(
                    l10n.profileSetupTitle,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.profileSetupSubtitle,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // ── Avatar ────────────────────────────────────────
                  _AvatarSection(
                    selectedImage: _selectedImage,
                    name: _nameController.text,
                    onTap: _isLoading ? null : _showAvatarOptions,
                    changePhotoLabel: l10n.changePhoto,
                  ),
                  const SizedBox(height: 32),

                  // ── Name input ────────────────────────────────────
                  Semantics(
                    label: l10n.nameHint,
                    child: TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: l10n.nameHint,
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
                      enabled: !_isLoading,
                      validator: Validators.displayName,
                      onChanged: (_) {
                        // Rebuild so the avatar initials update live.
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Email input (optional) ────────────────────────
                  Semantics(
                    label: l10n.emailHint,
                    child: TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        hintText: l10n.emailHint,
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                      textInputAction: TextInputAction.done,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      enabled: !_isLoading,
                      validator: (value) {
                        // Email is optional — only validate when non-empty.
                        if (value == null || value.trim().isEmpty) return null;
                        return Validators.email(value);
                      },
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Submit button ─────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: Semantics(
                      button: true,
                      label: l10n.completeProfile,
                      child: FilledButton(
                        onPressed: _isLoading
                            ? null
                            : () => _onSubmit(uid: uid, phone: phone),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: _isLoading
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                )
                              : Text(l10n.completeProfile),
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
    );
  }
}

// ---------------------------------------------------------------------------
// Private widgets
// ---------------------------------------------------------------------------

/// Displays the circular avatar preview with a tap-to-change overlay.
///
/// When [selectedImage] is non-null it shows a local file preview. Otherwise
/// it falls back to [AvatarWidget] with the user's current [name] (which
/// renders initials or a person icon when the name is empty).
class _AvatarSection extends StatelessWidget {
  const _AvatarSection({
    required this.selectedImage,
    required this.name,
    required this.onTap,
    required this.changePhotoLabel,
  });

  /// The locally-picked image, if any.
  final XFile? selectedImage;

  /// The user's display name (used for initials fallback).
  final String name;

  /// Callback when the avatar area is tapped. `null` disables the tap.
  final VoidCallback? onTap;

  /// Localized label for the "Change Photo" text.
  final String changePhotoLabel;

  static const double _avatarRadius = 48.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: changePhotoLabel,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                // Avatar circle
                if (selectedImage != null)
                  CircleAvatar(
                    radius: _avatarRadius,
                    backgroundImage: FileImage(File(selectedImage!.path)),
                  )
                else if (name.trim().isNotEmpty)
                  AvatarWidget(name: name.trim(), radius: _avatarRadius)
                else
                  CircleAvatar(
                    radius: _avatarRadius,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.person,
                      size: _avatarRadius,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),

                // Camera badge
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.surface,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    size: 16,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              changePhotoLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
