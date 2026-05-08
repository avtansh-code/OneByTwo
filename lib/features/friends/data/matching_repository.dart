import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Callable signature for the lookupUserByPhoneNumber Cloud Function.
typedef LookupCallable =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> data);

/// Exception thrown when a Cloud Function returns an error.
class CloudFunctionException implements Exception {
  /// Creates a [CloudFunctionException].
  const CloudFunctionException({required this.code, required this.details});

  /// The error code from the Cloud Function (e.g. 'invalid-argument').
  final String code;

  /// The error details string (e.g. 'INVALID_INPUT', 'RATE_LIMITED').
  final String details;

  @override
  String toString() => 'CloudFunctionException(code: $code, details: $details)';
}

// ---------------------------------------------------------------------------
// MatchResult sealed hierarchy
// ---------------------------------------------------------------------------

/// The result of looking up a phone number via the Cloud Function.
sealed class MatchResult {
  /// Creates a [MatchResult].
  const MatchResult();
}

/// The phone number matched a registered user.
class Matched extends MatchResult {
  /// Creates a [Matched] result.
  const Matched({
    required this.displayName,
    required this.photoUrl,
    required this.otherUserId,
  });

  /// The matched user's display name.
  final String displayName;

  /// The matched user's photo URL, if available.
  final String? photoUrl;

  /// The matched user's UID.
  final String otherUserId;
}

/// The phone number did not match any registered user.
class Unmatched extends MatchResult {
  /// Creates an [Unmatched] result.
  const Unmatched();
}

/// The lookup failed with a specific error code.
class Failed extends MatchResult {
  /// Creates a [Failed] result.
  const Failed(this.errorCode);

  /// The error code describing the failure.
  final String errorCode;
}

/// The user has been rate-limited and should try again later.
class RateLimited extends MatchResult {
  /// Creates a [RateLimited] result.
  const RateLimited();
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

/// Repository that looks up users by phone number via the
/// `lookupUserByPhoneNumber` Cloud Function.
class MatchingRepository {
  /// Creates a [MatchingRepository].
  const MatchingRepository({required LookupCallable lookupCallable})
    : _lookupCallable = lookupCallable;

  final LookupCallable _lookupCallable;

  /// Looks up a user by their E.164 phone number and returns a
  /// [MatchResult] describing whether a match was found.
  Future<MatchResult> lookupUser(String phoneNumber) async {
    try {
      final response = await _lookupCallable({'phoneNumber': phoneNumber});

      final matched = response['matched'] as bool;
      if (!matched) return const Unmatched();

      return Matched(
        displayName: response['displayName'] as String,
        photoUrl: response['photoUrl'] as String?,
        otherUserId: response['otherUserId'] as String,
      );
    } on CloudFunctionException catch (e) {
      if (e.details == 'RATE_LIMITED') return const RateLimited();
      return Failed(e.details);
    } on Exception {
      return const Failed('INTERNAL');
    }
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Provides a [MatchingRepository].
///
/// In production, override this provider with a [MatchingRepository]
/// wired to the `lookupUserByPhoneNumber` Cloud Function. The
/// `cloud_functions` dependency is kept out of this file so that
/// unit tests can import it without requiring Firebase initialisation.
final matchingRepositoryProvider = Provider<MatchingRepository>((ref) {
  throw UnimplementedError(
    'matchingRepositoryProvider must be overridden with a '
    'LookupCallable backed by FirebaseFunctions.',
  );
});
