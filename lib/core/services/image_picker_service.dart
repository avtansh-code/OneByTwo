import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Abstraction over [ImagePicker] for testability.
///
/// Allows tests to inject a fake that returns predetermined
/// file paths without requiring platform plugin initialisation.
abstract class ImagePickerService {
  /// Picks an image from the device gallery.
  Future<XFile?> pickFromGallery({int maxWidth = 1024, int maxHeight = 1024});

  /// Picks an image from the device camera.
  Future<XFile?> pickFromCamera({int maxWidth = 1024, int maxHeight = 1024});
}

/// Production implementation that delegates to [ImagePicker].
class DefaultImagePickerService implements ImagePickerService {
  /// Creates a [DefaultImagePickerService].
  DefaultImagePickerService() : _picker = ImagePicker();

  final ImagePicker _picker;

  @override
  Future<XFile?> pickFromGallery({int maxWidth = 1024, int maxHeight = 1024}) {
    return _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: maxWidth.toDouble(),
      maxHeight: maxHeight.toDouble(),
    );
  }

  @override
  Future<XFile?> pickFromCamera({int maxWidth = 1024, int maxHeight = 1024}) {
    return _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: maxWidth.toDouble(),
      maxHeight: maxHeight.toDouble(),
    );
  }
}

/// Provides an [ImagePickerService] instance.
///
/// Override in tests with a fake implementation to avoid
/// platform plugin initialisation.
final imagePickerServiceProvider = Provider<ImagePickerService>(
  (ref) => DefaultImagePickerService(),
);
