/// Telemetry event-name and parameter constants for the Contact Support
/// flow (FR-PR-05 / FR-SH-03 / FR-SH-04).
///
/// The `support_email_opened` event is a pre-declared v1.0 funnel (SRS
/// section 5.10; `docs/design/07-technical/telemetry-plan.md`). Its only
/// parameter is the safe enum token `method` — the payload carries NO
/// PII. The user's `userId` and device diagnostics appear only in the
/// user-visible `mailto:` body the user chooses to send, never as
/// analytics parameters, so no hashing
/// (`lib/core/telemetry/event_id_hash.dart`) is required here.
abstract final class ContactSupportTelemetry {
  /// Fires once per Contact Support tap, after the launch/fallback
  /// branch decision. Payload: [paramMethod].
  static const String supportEmailOpenedEvent = 'support_email_opened';

  /// Parameter key distinguishing the two paths.
  static const String paramMethod = 'method';

  /// `method` value for the happy path (mail client launched).
  static const String methodMailto = 'mailto';

  /// `method` value for the FR-SH-04 no-mail-client fallback dialog path.
  static const String methodFallbackDialog = 'fallback_dialog';
}
