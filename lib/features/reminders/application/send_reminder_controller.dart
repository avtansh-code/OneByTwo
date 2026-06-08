import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/core/telemetry/event_id_hash.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/reminders/application/reminder_cooldown_provider.dart';
import 'package:onebytwo/features/reminders/application/reminder_telemetry.dart';
import 'package:onebytwo/features/reminders/data/reminder_repository.dart';
import 'package:onebytwo/features/reminders/domain/reminder_send_error.dart';

/// State for [SendReminderController].
@immutable
sealed class SendReminderState {
  /// Creates a [SendReminderState].
  const SendReminderState();
}

/// Initial state — no send in flight, no recent outcome.
class SendReminderIdle extends SendReminderState {
  /// Creates a [SendReminderIdle].
  const SendReminderIdle();
}

/// A send is in flight. UI shows a progress indicator on the CTA.
class SendReminderSending extends SendReminderState {
  /// Creates a [SendReminderSending].
  const SendReminderSending();
}

/// The send succeeded. UI may switch to a disabled-with-countdown
/// state via the cooldown provider.
class SendReminderSuccess extends SendReminderState {
  /// Creates a [SendReminderSuccess].
  const SendReminderSuccess({required this.nextAllowedAt});

  /// Server-returned earliest next-allowed time.
  final DateTime nextAllowedAt;
}

/// The send failed with one of the typed [ReminderSendResult] error
/// variants. UI surfaces a per-variant snackbar.
class SendReminderError extends SendReminderState {
  /// Creates a [SendReminderError].
  const SendReminderError(this.error);

  /// The discriminated error variant.
  final ReminderSendResult error;
}

/// Riverpod 2.x [StateNotifier] driving the "Send Reminder" CTA on
/// the OBTSettleUpCard receiving-direction variant.
///
/// Mirrors the SettleUpController precedent: sealed-state hierarchy,
/// repository + analytics injected via constructor, telemetry single-
/// fire discipline (events fire once per transition; concurrent
/// `send()` is short-circuited while the previous send is in flight).
///
/// Side effects:
///   - On success / RATE_LIMITED, updates [reminderCooldownProvider]
///     for the friendshipId so the OBTSettleUpCard receiving-direction
///     button is disabled with a countdown caption.
///   - Emits `reminder_send_*` telemetry per [ReminderTelemetry] with
///     hashed `friendship_id_hash` parameters (ADR-0013 PII guard).
class SendReminderController extends StateNotifier<SendReminderState> {
  /// Creates a [SendReminderController].
  SendReminderController({
    required this.friendshipId,
    required ReminderRepository repository,
    required AnalyticsService analytics,
    required void Function(DateTime?) writeCooldown,
  }) : _repository = repository,
       _analytics = analytics,
       _writeCooldown = writeCooldown,
       super(const SendReminderIdle());

  /// The friendship document ID (`uid-a_uid-b`).
  final String friendshipId;

  final ReminderRepository _repository;
  final AnalyticsService _analytics;
  final void Function(DateTime?) _writeCooldown;

  /// Invokes the `sendReminderNotification` callable and drives the
  /// state machine through Sending → (Success | Error).
  ///
  /// Concurrent calls while in [SendReminderSending] are no-ops to
  /// prevent double-sends. v1.0 callers always omit [message] — the
  /// server defaults to a hardcoded copy per architect §2.5.
  Future<void> send({
    required String toUserId,
    required String contextType,
    required String contextId,
    String? message,
  }) async {
    if (state is SendReminderSending) return;

    _logTapped();
    state = const SendReminderSending();

    final result = await _repository.sendReminder(
      toUserId: toUserId,
      contextType: contextType,
      contextId: contextId,
      message: message,
    );

    switch (result) {
      case ReminderSendSuccess(:final nextAllowedAt):
        _writeCooldown(nextAllowedAt);
        state = SendReminderSuccess(nextAllowedAt: nextAllowedAt);
        _logSucceeded();
      case ReminderSendRateLimited(:final nextAllowedAt):
        _writeCooldown(nextAllowedAt);
        state = SendReminderError(result);
        _logRateLimited(nextAllowedAt);
      case ReminderSendRecipientDoesntOwe():
        state = SendReminderError(result);
        _logRecipientDoesntOwe();
      case ReminderSendRecipientPrefsDisabled():
        state = SendReminderError(result);
        _logRecipientPrefsDisabled();
      case ReminderSendRecipientNoTokens():
        state = SendReminderError(result);
        _logRecipientNoTokens();
      case ReminderSendFailed(:final errorCode):
        state = SendReminderError(result);
        _logFailed(errorCode);
    }
  }

  /// Resets the state to [SendReminderIdle]. Hosts may call this
  /// after surfacing the error snackbar to clear the "error" sticky
  /// state.
  void reset() {
    state = const SendReminderIdle();
  }

  // ---------------------------------------------------------------
  // Telemetry helpers
  // ---------------------------------------------------------------

  Map<String, Object> get _baseParams => {
    ReminderTelemetry.paramFriendshipIdHash: hashFriendshipId(friendshipId),
  };

  void _logTapped() {
    _analytics.logEvent(
      name: ReminderTelemetry.tapped,
      parameters: _baseParams,
    );
  }

  void _logSucceeded() {
    _analytics.logEvent(
      name: ReminderTelemetry.succeeded,
      parameters: _baseParams,
    );
  }

  void _logRateLimited(DateTime nextAllowedAt) {
    final seconds = nextAllowedAt
        .difference(DateTime.now())
        .inSeconds
        .clamp(0, 86400);
    _analytics.logEvent(
      name: ReminderTelemetry.rateLimited,
      parameters: <String, Object>{
        ..._baseParams,
        ReminderTelemetry.paramNextAllowedInSeconds: seconds,
      },
    );
  }

  void _logRecipientPrefsDisabled() {
    _analytics.logEvent(
      name: ReminderTelemetry.recipientPrefsDisabled,
      parameters: _baseParams,
    );
  }

  void _logRecipientNoTokens() {
    _analytics.logEvent(
      name: ReminderTelemetry.recipientNoTokens,
      parameters: _baseParams,
    );
  }

  void _logRecipientDoesntOwe() {
    _analytics.logEvent(
      name: ReminderTelemetry.recipientDoesntOwe,
      parameters: _baseParams,
    );
  }

  void _logFailed(String errorCode) {
    _analytics.logEvent(
      name: ReminderTelemetry.failed,
      parameters: <String, Object>{
        ..._baseParams,
        ReminderTelemetry.paramErrorCode: errorCode,
      },
    );
  }
}

/// Provides a per-friendship [SendReminderController].
///
/// The state is per-friendship so two simultaneous Friend Detail
/// screens do not stomp on each other's send state.
final sendReminderControllerProvider = StateNotifierProvider.autoDispose
    .family<SendReminderController, SendReminderState, String>((
      ref,
      friendshipId,
    ) {
      return SendReminderController(
        friendshipId: friendshipId,
        repository: ref.watch(reminderRepositoryProvider),
        analytics: ref.watch(analyticsServiceProvider),
        writeCooldown: (value) {
          ref.read(reminderCooldownProvider(friendshipId).notifier).state =
              value;
        },
      );
    });
