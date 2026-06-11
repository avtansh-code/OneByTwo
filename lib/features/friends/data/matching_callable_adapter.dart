import 'package:cloud_functions/cloud_functions.dart';

import 'package:onebytwo/features/friends/data/matching_repository.dart';

/// Production adapter that bridges the `cloud_functions` package to
/// the in-codebase [LookupCallable] typedef + [CloudFunctionException]
/// exception class (declared in `matching_repository.dart`).
///
/// FR-AC-04 (sprint-2): wires the `lookupUserByPhoneNumber` callable
/// into [MatchingRepository] via [asCallable]. The repository is
/// testable in isolation without `cloud_functions` because it
/// consumes the `LookupCallable` typedef directly — the adapter is
/// the only file that imports `package:cloud_functions/cloud_functions.dart`.
///
/// Translation contract (architect §2.5):
///   - `FirebaseFunctionsException` → [CloudFunctionException].
///   - `details` on the existing exception is a STRING (not a Map).
///     It is populated from `e.details['errorCode']` when present,
///     and falls back to `e.code` when the details map is absent or
///     does not carry an `errorCode`. This preserves the existing
///     [MatchingRepository.lookupUser] branch that switches on
///     `e.details == 'RATE_LIMITED'`.
///   - Opaque (non-`FirebaseFunctionsException`) failures re-throw
///     unchanged; the repository's `on Exception` branch yields
///     `Failed('INTERNAL')`.
///   - Success: returns `result.data` cast to `Map<String, dynamic>`
///     verbatim.
class MatchingCallableAdapter {
  /// Creates a [MatchingCallableAdapter] backed by an [HttpsCallable].
  const MatchingCallableAdapter(this._callable);

  final HttpsCallable _callable;

  /// Invokes the underlying [HttpsCallable] with [params] and
  /// translates `FirebaseFunctionsException` into
  /// [CloudFunctionException].
  Future<Map<String, dynamic>> call(Map<String, dynamic> params) async {
    try {
      final result = await _callable.call<Object?>(params);
      final data = result.data;
      if (data is! Map) return <String, dynamic>{};
      return Map<String, dynamic>.from(data);
    } on FirebaseFunctionsException catch (e) {
      final rawDetails = e.details;
      final details = rawDetails is Map
          ? Map<String, dynamic>.from(rawDetails)
          : <String, dynamic>{};
      final errorCode = (details['errorCode'] as String?) ?? e.code;
      throw CloudFunctionException(code: e.code, details: errorCode);
    }
  }

  /// Returns a [LookupCallable] tear-off bound to [call]. Used by
  /// `main.dart` to pass the adapter where the typedef is expected.
  LookupCallable get asCallable => call;
}
