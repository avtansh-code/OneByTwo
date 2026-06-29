// ignore_for_file: one_member_abstracts
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Thrown by a [RemoveFriendshipCallable] when the `removeFriendship`
/// Cloud Function rejects the request. [errorCode] carries the callable's
/// `code` (e.g. `failed-precondition` when a balance is still outstanding)
/// so the UI can distinguish the "settle up first" case from a generic
/// failure.
class RemoveFriendshipException implements Exception {
  /// Creates a [RemoveFriendshipException].
  const RemoveFriendshipException(this.errorCode);

  /// The callable error code (the Firebase `FunctionsException.code`).
  final String errorCode;

  @override
  String toString() => 'RemoveFriendshipException(errorCode: $errorCode)';
}

/// Minimal callable surface for the `removeFriendship` Cloud Function:
/// takes the request payload and resolves to the response map, or throws a
/// [RemoveFriendshipException]. Mirrors the reminder callable seam so the
/// production wiring (`FirebaseFunctions.instance.httpsCallable(...)`) is
/// injected in `main.dart` and tests inject a fake.
typedef RemoveFriendshipCallable =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> payload);

/// Outcome of a remove-friendship attempt — a small discriminated result so
/// callers never inspect raw exception fields.
sealed class RemoveFriendshipResult {
  const RemoveFriendshipResult();
}

/// The friendship was removed.
class RemoveFriendshipSuccess extends RemoveFriendshipResult {
  /// Creates a [RemoveFriendshipSuccess].
  const RemoveFriendshipSuccess();
}

/// The friendship still has an outstanding balance — the user must settle
/// up before removing (the design "Settle up first" path).
class RemoveFriendshipNotSettled extends RemoveFriendshipResult {
  /// Creates a [RemoveFriendshipNotSettled].
  const RemoveFriendshipNotSettled();
}

/// The removal failed for any other reason.
class RemoveFriendshipFailed extends RemoveFriendshipResult {
  /// Creates a [RemoveFriendshipFailed] with the callable [errorCode].
  const RemoveFriendshipFailed(this.errorCode);

  /// The underlying callable error code.
  final String errorCode;
}

/// Repository for FR-FR-05 Remove friend.
///
/// Wraps the `removeFriendship` Cloud Function callable. The function
/// validates membership, requires the friendship to be fully settled, and
/// recursively deletes the friendship doc + its `expenses` subcollection
/// server-side (the client cannot delete friendships — `firestore.rules`
/// keeps `allow delete: if false`, Invariant 2 preserved).
abstract class RemoveFriendshipRepository {
  /// Creates a default [RemoveFriendshipRepository] backed by [callable].
  const factory RemoveFriendshipRepository({
    required RemoveFriendshipCallable callable,
  }) = _RemoveFriendshipRepositoryImpl;

  /// Default constructor for sub-classing / fakes.
  const RemoveFriendshipRepository._();

  /// Invokes the `removeFriendship` callable for [friendshipId] and maps
  /// the response (or thrown exception) to a [RemoveFriendshipResult].
  Future<RemoveFriendshipResult> removeFriendship(String friendshipId);
}

class _RemoveFriendshipRepositoryImpl extends RemoveFriendshipRepository {
  const _RemoveFriendshipRepositoryImpl({
    required RemoveFriendshipCallable callable,
  }) : _callable = callable,
       super._();

  final RemoveFriendshipCallable _callable;

  @override
  Future<RemoveFriendshipResult> removeFriendship(String friendshipId) async {
    try {
      final response = await _callable(<String, dynamic>{
        'friendshipId': friendshipId,
      });
      if (response['success'] == true) {
        return const RemoveFriendshipSuccess();
      }
      return const RemoveFriendshipFailed('UNKNOWN');
    } on RemoveFriendshipException catch (e) {
      if (e.errorCode == 'failed-precondition') {
        return const RemoveFriendshipNotSettled();
      }
      return RemoveFriendshipFailed(e.errorCode);
    } on Exception {
      return const RemoveFriendshipFailed('UNKNOWN');
    }
  }
}

/// Provides a [RemoveFriendshipRepository]. Production overrides in
/// `main.dart` with the `cloud_functions`-backed callable; tests override
/// with a fake.
final removeFriendshipRepositoryProvider = Provider<RemoveFriendshipRepository>(
  (ref) {
    throw UnimplementedError(
      'removeFriendshipRepositoryProvider must be overridden with a '
      'RemoveFriendshipCallable backed by FirebaseFunctions in main.dart.',
    );
  },
);
