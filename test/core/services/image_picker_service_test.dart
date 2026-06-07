// Smoke test for the extracted ImagePickerService.
//
// Verifies that the abstract type, the default implementation, and
// the Riverpod provider are all wired correctly after the move from
// lib/features/auth/data/ to lib/core/services/ (FR-EX-05 architect
// notes section 2.4).
//
// The DefaultImagePickerService cannot be exercised end-to-end here
// because that would require the image_picker plugin to be
// initialised against a real platform channel. The expense feature
// tests inject a FakeImagePickerService for that purpose; this file
// just confirms the provider resolves and the default impl
// implements the abstract contract.

// ignore_for_file: cascade_invocations

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:onebytwo/core/services/image_picker_service.dart';

void main() {
  group('imagePickerServiceProvider', () {
    test('resolves to a DefaultImagePickerService by default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final picker = container.read(imagePickerServiceProvider);
      expect(picker, isA<ImagePickerService>());
      expect(picker, isA<DefaultImagePickerService>());
    });

    test('can be overridden with a fake for tests', () {
      final container = ProviderContainer(
        overrides: [
          imagePickerServiceProvider.overrideWithValue(_NoopPickerService()),
        ],
      );
      addTearDown(container.dispose);

      final picker = container.read(imagePickerServiceProvider);
      expect(picker, isA<_NoopPickerService>());
    });
  });
}

class _NoopPickerService implements ImagePickerService {
  @override
  Future<XFile?> pickFromCamera({
    int maxWidth = 1024,
    int maxHeight = 1024,
  }) async => null;

  @override
  Future<XFile?> pickFromGallery({
    int maxWidth = 1024,
    int maxHeight = 1024,
  }) async => null;
}
