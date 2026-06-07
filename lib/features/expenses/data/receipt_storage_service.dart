import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:onebytwo/features/auth/data/user_repository.dart'
    show firebaseStorageProvider;
import 'package:onebytwo/features/expenses/domain/receipt_upload_error.dart';

// Re-export the typed error from the domain layer so callers may
// import either path. Mirrors the ExpenseRepository convention.
export 'package:onebytwo/features/expenses/domain/receipt_upload_error.dart';

/// Thin abstraction over Firebase Storage for the expense feature's
/// receipt-attachment surface (FR-EX-05).
///
/// Per architect notes §2.3, this service is the SOLE client-side
/// uploader to `gs://onebytwo-avtanshgupta.appspot.com/receipts/...`
/// from the expense feature. The avatar upload path lives in
/// `UserRepository`; the two paths are intentionally disjoint so each
/// feature owns its own Storage contract.
///
/// Path convention: `receipts/{contextType}/{contextId}/{expenseId}`
/// per `docs/design/07-technical/firestore-schema.md` lines 298-313.
/// PR #48 ships the friendship-context surface only; the
/// group-context method ships with the Sprint 3 groups epic.
abstract class ReceiptStorageService {
  /// Uploads [file] to
  /// `receipts/friendships/{friendshipId}/{expenseId}` and returns
  /// the download URL. Overwrites any existing object at the same
  /// path (Firebase Storage PUT semantics — see architect §2.1).
  Future<String> uploadFriendshipReceipt({
    required String friendshipId,
    required String expenseId,
    required XFile file,
  });

  /// Deletes the object at
  /// `receipts/friendships/{friendshipId}/{expenseId}`. Called when
  /// the user removes a receipt during the edit flow (AC-12).
  /// Ignores `object-not-found` errors — the receipt may already be
  /// absent (e.g. the user removed it on a previous edit that failed
  /// at the Firestore write step).
  Future<void> deleteFriendshipReceipt({
    required String friendshipId,
    required String expenseId,
  });
}

/// Production implementation that delegates to [FirebaseStorage].
class FirebaseReceiptStorageService implements ReceiptStorageService {
  /// Creates a [FirebaseReceiptStorageService].
  const FirebaseReceiptStorageService({required FirebaseStorage storage})
    : _storage = storage;

  final FirebaseStorage _storage;

  @override
  Future<String> uploadFriendshipReceipt({
    required String friendshipId,
    required String expenseId,
    required XFile file,
  }) async {
    final path = 'receipts/friendships/$friendshipId/$expenseId';
    try {
      final ref = _storage.ref(path);
      final metadata = SettableMetadata(contentType: file.mimeType);
      await ref.putFile(File(file.path), metadata);
      return ref.getDownloadURL();
    } on FirebaseException catch (e, st) {
      throw ReceiptUploadError(
        type: _mapUploadCode(e.code),
        underlying: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw ReceiptUploadError(
        type: ReceiptUploadErrorType.unknown,
        underlying: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> deleteFriendshipReceipt({
    required String friendshipId,
    required String expenseId,
  }) async {
    final path = 'receipts/friendships/$friendshipId/$expenseId';
    try {
      await _storage.ref(path).delete();
    } on FirebaseException catch (e, st) {
      if (e.code == 'object-not-found') return;
      throw ReceiptUploadError(
        type: _mapUploadCode(e.code),
        underlying: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw ReceiptUploadError(
        type: ReceiptUploadErrorType.unknown,
        underlying: e,
        stackTrace: st,
      );
    }
  }

  ReceiptUploadErrorType _mapUploadCode(String code) {
    switch (code) {
      case 'unauthorized':
      case 'permission-denied':
        return ReceiptUploadErrorType.permissionDenied;
      case 'invalid-checksum':
      case 'invalid-argument':
        return ReceiptUploadErrorType.unsupportedType;
      case 'retry-limit-exceeded':
      case 'unavailable':
      case 'network-request-failed':
        return ReceiptUploadErrorType.network;
      default:
        return ReceiptUploadErrorType.unknown;
    }
  }
}

/// Production binding: wraps a [FirebaseReceiptStorageService] around
/// the app-wide [firebaseStorageProvider]. Tests override this
/// provider with a fake.
final receiptStorageServiceProvider = Provider<ReceiptStorageService>((ref) {
  return FirebaseReceiptStorageService(
    storage: ref.watch(firebaseStorageProvider),
  );
});
