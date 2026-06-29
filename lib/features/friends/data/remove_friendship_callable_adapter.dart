import 'package:cloud_functions/cloud_functions.dart';

import 'package:onebytwo/features/friends/data/remove_friendship_repository.dart';

/// Production adapter bridging the `cloud_functions` package to the
/// in-codebase [RemoveFriendshipCallable] typedef + [RemoveFriendshipException]
/// (declared in `remove_friendship_repository.dart`).
///
/// FR-FR-05: wires the `removeFriendship` callable into the repository via
/// [asCallable]. The repository is testable without `cloud_functions`
/// because it consumes the typedef directly; this adapter is the only
/// remove-friend file that imports `package:cloud_functions/...`.
///
/// Translation contract:
///   - `FirebaseFunctionsException` → [RemoveFriendshipException] carrying
///     the function `code` (e.g. `failed-precondition` when not settled).
///   - Success: returns `result.data` cast to `Map<String, dynamic>`.
class RemoveFriendshipCallableAdapter {
  /// Creates a [RemoveFriendshipCallableAdapter] backed by an
  /// [HttpsCallable].
  const RemoveFriendshipCallableAdapter(this._callable);

  final HttpsCallable _callable;

  /// Invokes the underlying [HttpsCallable] with [payload] and translates
  /// `FirebaseFunctionsException` into [RemoveFriendshipException].
  Future<Map<String, dynamic>> call(Map<String, dynamic> payload) async {
    try {
      final result = await _callable.call<Object?>(payload);
      final data = result.data;
      if (data is! Map) return <String, dynamic>{};
      return Map<String, dynamic>.from(data);
    } on FirebaseFunctionsException catch (e) {
      throw RemoveFriendshipException(e.code);
    }
  }

  /// Returns a [RemoveFriendshipCallable] tear-off bound to [call].
  RemoveFriendshipCallable get asCallable => call;
}
