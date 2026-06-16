import 'package:cloud_functions/cloud_functions.dart';

import 'package:onebytwo/features/profile/data/delete_account_repository.dart';

/// Production adapter that bridges the `cloud_functions` package to the
/// in-codebase [DeleteAccountCallable] typedef + [DeleteAccountException]
/// (declared in `delete_account_repository.dart`).
///
/// FR-AU-09: wires the `deleteUserAccount` callable into
/// [DeleteAccountRepositoryImpl] via [asCallable]. The repository is
/// testable in isolation without `cloud_functions` because it consumes the
/// `DeleteAccountCallable` typedef directly — this adapter is the only
/// profile file that imports `package:cloud_functions/cloud_functions.dart`.
///
/// Translation contract:
///   - `FirebaseFunctionsException` → [DeleteAccountException].
///   - `details['errorCode']` is propagated as `errorCode` (or
///     `'UNKNOWN'` when missing).
///   - Opaque (non-`FirebaseFunctionsException`) failures re-throw
///     unchanged.
///   - Success: returns `result.data` cast to `Map<String, dynamic>`
///     verbatim (the callable returns `{ success: true }`).
class DeleteAccountCallableAdapter {
  /// Creates a [DeleteAccountCallableAdapter] backed by an [HttpsCallable].
  const DeleteAccountCallableAdapter(this._callable);

  final HttpsCallable _callable;

  /// Invokes the underlying [HttpsCallable] (no input) and translates
  /// `FirebaseFunctionsException` into [DeleteAccountException].
  Future<Map<String, dynamic>> call() async {
    try {
      final result = await _callable.call<Object?>();
      final data = result.data;
      if (data is! Map) return <String, dynamic>{};
      return Map<String, dynamic>.from(data);
    } on FirebaseFunctionsException catch (e) {
      final rawDetails = e.details;
      final details = rawDetails is Map
          ? Map<String, dynamic>.from(rawDetails)
          : <String, dynamic>{};
      throw DeleteAccountException(
        code: e.code,
        errorCode: (details['errorCode'] as String?) ?? 'UNKNOWN',
      );
    }
  }

  /// Returns a [DeleteAccountCallable] tear-off bound to [call]. Used by
  /// `main.dart` to pass the adapter where the typedef is expected.
  DeleteAccountCallable get asCallable => call;
}
