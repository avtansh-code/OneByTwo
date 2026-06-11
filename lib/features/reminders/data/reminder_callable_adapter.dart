import 'package:cloud_functions/cloud_functions.dart';

import 'package:onebytwo/features/reminders/data/reminder_repository.dart';

/// Production adapter that bridges the `cloud_functions` package to
/// the in-codebase [ReminderCallable] typedef + [ReminderCallableException]
/// exception class (declared in `reminder_repository.dart`).
///
/// FR-AC-04 (sprint-2): wires the `sendReminderNotification`
/// callable into [ReminderRepositoryImpl] via [asCallable]. The
/// repository is testable in isolation without `cloud_functions`
/// because it consumes the `ReminderCallable` typedef directly —
/// the adapter is the only file that imports
/// `package:cloud_functions/cloud_functions.dart`.
///
/// Translation contract (architect §2.5):
///   - `FirebaseFunctionsException` → [ReminderCallableException].
///   - `details['errorCode']` is propagated as `errorCode` (or
///     `'UNKNOWN'` when missing — keeps the
///     [ReminderRepositoryImpl] `on Exception` branch consistent).
///   - `details['nextAllowedAtIso']` is propagated as
///     `nextAllowedAtIso` (null when absent).
///   - Opaque (non-`FirebaseFunctionsException`) failures re-throw
///     unchanged; the repository's `on Exception` branch yields
///     `'UNKNOWN'`.
///   - Success: returns `result.data` cast to `Map<String, dynamic>`
///     verbatim.
class ReminderCallableAdapter {
  /// Creates a [ReminderCallableAdapter] backed by [callable].
  const ReminderCallableAdapter(this._callable);

  final HttpsCallable _callable;

  /// Invokes the underlying [HttpsCallable] with [params] and
  /// translates `FirebaseFunctionsException` into
  /// [ReminderCallableException].
  Future<Map<String, dynamic>> call(Map<String, dynamic> params) async {
    try {
      final result = await _callable.call<Object?>(params);
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      final details = e.details is Map
          ? Map<String, dynamic>.from(e.details as Map)
          : <String, dynamic>{};
      throw ReminderCallableException(
        code: e.code,
        errorCode: (details['errorCode'] as String?) ?? 'UNKNOWN',
        nextAllowedAtIso: details['nextAllowedAtIso'] as String?,
      );
    }
  }

  /// Returns a [ReminderCallable] tear-off bound to [call]. Used by
  /// `main.dart` to pass the adapter where the typedef is expected.
  ReminderCallable get asCallable => call;
}
