import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/features/reminders/domain/reminder_send_error.dart';

// ignore_for_file: one_member_abstracts
//
// The abstract class exists because [ReminderRepository] is a typed
// factory constructor surface that hides the concrete
// [ReminderRepositoryImpl]; this is the established pattern in the
// codebase (see [SettlementRepository] in
// lib/features/settlements/data/). Single-method-abstracts is the
// signal here that the repository is a one-call surface.

/// Callable signature for the `sendReminderNotification` Cloud
/// Function. Matches the response shape returned by
/// `FirebaseFunctions.httpsCallable(...).call(...)`.
typedef ReminderCallable =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> data);

/// Exception thrown by [ReminderCallable] when the callable rejects
/// with a typed `HttpsError`. Repository callers should expect this
/// shape; the production wiring catches `FirebaseFunctionsException`
/// at the `cloud_functions` boundary and re-throws as
/// [ReminderCallableException].
class ReminderCallableException implements Exception {
  /// Creates a [ReminderCallableException].
  const ReminderCallableException({
    required this.code,
    required this.errorCode,
    this.nextAllowedAtIso,
  });

  /// The Firebase `HttpsError.code` (e.g. `'resource-exhausted'`).
  final String code;

  /// The server-side `details.errorCode` (e.g. `'RATE_LIMITED'`).
  final String errorCode;

  /// For `RATE_LIMITED` only — the server-returned next-allowed
  /// timestamp ISO-8601 string.
  final String? nextAllowedAtIso;

  @override
  String toString() =>
      'ReminderCallableException(code: $code, errorCode: $errorCode)';
}

/// Repository surface for FR-SE-09 Send Reminder.
///
/// Wraps the `sendReminderNotification` Cloud Function callable. The
/// production override in `main.dart` injects a [ReminderCallable]
/// backed by `FirebaseFunctions.instance.httpsCallable(...)`; tests
/// inject a fake callable directly so no Firebase initialisation is
/// needed.
///
/// Returns a [ReminderSendResult] discriminated union. Callers
/// (controller / UI) switch on the runtime type and never inspect
/// raw exception fields.
abstract class ReminderRepository {
  /// Creates a default [ReminderRepository] backed by [callable].
  const factory ReminderRepository({required ReminderCallable callable}) =
      ReminderRepositoryImpl;

  /// Default constructor for sub-classing / fakes.
  const ReminderRepository._();

  /// Invokes the `sendReminderNotification` callable and maps the
  /// response (or thrown exception) to a [ReminderSendResult].
  ///
  /// v1.0 callers always omit [message] — the server defaults to a
  /// hardcoded copy per architect §2.5.
  Future<ReminderSendResult> sendReminder({
    required String toUserId,
    required String contextType,
    required String contextId,
    String? message,
  });
}

/// Concrete implementation of [ReminderRepository].
class ReminderRepositoryImpl extends ReminderRepository {
  /// Creates a [ReminderRepositoryImpl] with the given [callable].
  const ReminderRepositoryImpl({required ReminderCallable callable})
    : _callable = callable,
      super._();

  final ReminderCallable _callable;

  @override
  Future<ReminderSendResult> sendReminder({
    required String toUserId,
    required String contextType,
    required String contextId,
    String? message,
  }) async {
    try {
      final payload = <String, dynamic>{
        'toUserId': toUserId,
        'contextType': contextType,
        'contextId': contextId,
      };
      if (message != null) payload['message'] = message;

      final response = await _callable(payload);
      final nextAllowedAtIso = response['nextAllowedAtIso'] as String?;
      if (nextAllowedAtIso == null) {
        return ReminderSendFailed('UNKNOWN');
      }
      return ReminderSendSuccess(
        nextAllowedAt: DateTime.parse(nextAllowedAtIso),
      );
    } on ReminderCallableException catch (e) {
      switch (e.errorCode) {
        case 'RATE_LIMITED':
          final iso = e.nextAllowedAtIso;
          if (iso == null) return ReminderSendFailed('RATE_LIMITED');
          return ReminderSendRateLimited(nextAllowedAt: DateTime.parse(iso));
        case 'RECIPIENT_DOESNT_OWE':
          return const ReminderSendRecipientDoesntOwe();
        case 'RECIPIENT_PREFS_DISABLED':
          return const ReminderSendRecipientPrefsDisabled();
        case 'RECIPIENT_NO_TOKENS':
          return const ReminderSendRecipientNoTokens();
        default:
          return ReminderSendFailed(e.errorCode);
      }
    } on Exception {
      return ReminderSendFailed('UNKNOWN');
    }
  }
}

/// Provides a [ReminderRepository]. Production overrides in
/// `main.dart` with the `cloud_functions`-backed callable; tests
/// override with a fake.
final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  throw UnimplementedError(
    'reminderRepositoryProvider must be overridden with a '
    'ReminderCallable backed by FirebaseFunctions in main.dart.',
  );
});
