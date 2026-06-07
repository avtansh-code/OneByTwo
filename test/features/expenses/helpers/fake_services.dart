// FR-EX-05 test helpers — fakes for the ReceiptStorageService and
// ImagePickerService injected into AddExpenseController. Kept here
// so every controller / widget / pii-leak test file in the expense
// feature reuses the same minimal stubs without duplicating
// boilerplate.

import 'package:image_picker/image_picker.dart';
import 'package:onebytwo/core/services/image_picker_service.dart';
import 'package:onebytwo/features/expenses/data/receipt_storage_service.dart';

/// Recording fake [ReceiptStorageService]. Defaults to a successful
/// upload returning a deterministic URL. Tests that exercise the
/// upload-failure branch set [throwUploadError]; tests that exercise
/// the remove path inspect [deleteCalled] / [deletedFriendshipId] /
/// [deletedExpenseId].
class FakeReceiptStorageService implements ReceiptStorageService {
  String returnUrl =
      'https://example.com/receipts/friendships/uid-a_uid-b/exp-id-123';

  bool uploadCalled = false;
  String? uploadedFriendshipId;
  String? uploadedExpenseId;
  XFile? uploadedFile;
  ReceiptUploadError? throwUploadError;

  bool deleteCalled = false;
  String? deletedFriendshipId;
  String? deletedExpenseId;
  ReceiptUploadError? throwDeleteError;

  @override
  Future<String> uploadFriendshipReceipt({
    required String friendshipId,
    required String expenseId,
    required XFile file,
  }) async {
    uploadCalled = true;
    uploadedFriendshipId = friendshipId;
    uploadedExpenseId = expenseId;
    uploadedFile = file;
    if (throwUploadError != null) {
      throw throwUploadError!;
    }
    return returnUrl;
  }

  @override
  Future<void> deleteFriendshipReceipt({
    required String friendshipId,
    required String expenseId,
  }) async {
    deleteCalled = true;
    deletedFriendshipId = friendshipId;
    deletedExpenseId = expenseId;
    if (throwDeleteError != null) {
      throw throwDeleteError!;
    }
  }
}

/// Recording fake [ImagePickerService]. Defaults to returning null
/// (user cancelled). Tests that exercise the picker path set
/// [returnFromCamera] / [returnFromGallery] to a pre-built [XFile].
class FakeImagePickerService implements ImagePickerService {
  XFile? returnFromCamera;
  XFile? returnFromGallery;

  int cameraCalls = 0;
  int galleryCalls = 0;

  @override
  Future<XFile?> pickFromCamera({
    int maxWidth = 1024,
    int maxHeight = 1024,
  }) async {
    cameraCalls += 1;
    return returnFromCamera;
  }

  @override
  Future<XFile?> pickFromGallery({
    int maxWidth = 1024,
    int maxHeight = 1024,
  }) async {
    galleryCalls += 1;
    return returnFromGallery;
  }
}
