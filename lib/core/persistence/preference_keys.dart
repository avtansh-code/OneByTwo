/// Central registry of `shared_preferences` keys used across the app.
///
/// Every on-device persistence key MUST be declared here so call sites
/// never hard-code a stringly-typed key. This keeps the namespace
/// auditable in one place and prevents collisions between features.
///
/// **PII:** these are on-device storage keys, NOT Analytics parameters,
/// so a per-friendship key is acceptable (SRS line 308 / ADR-0013
/// govern Analytics/Crashlytics, not local storage). The composed key
/// value MUST NEVER be logged to analytics.
abstract final class PreferenceKeys {
  /// Whether the OS notification prompt has been denied at least once on
  /// this installation (FR-AC-04). Persisted so the pre-permission
  /// dialog is not re-shown automatically on the next launch.
  static const String notificationsPermanentlyDenied =
      'notifications_permanently_denied';

  /// Whether the first-launch onboarding (Haldi 2) has been seen on this
  /// installation (DC-04). Persisted so onboarding is shown exactly once,
  /// before phone entry; Skip and "Get started" both set it.
  static const String hasSeenOnboarding = 'has_seen_onboarding';

  /// Prefix for the FR-SE-09 per-friendship send-reminder cooldown.
  /// The stored value is the server-returned `nextAllowedAt` as an
  /// ISO-8601 string; a stored value in the past is treated as absent.
  static const String reminderCooldownPrefix = 'reminder_cooldown_';

  /// Key for the FR-SE-09 send-reminder cooldown of [friendshipId].
  static String reminderCooldown(String friendshipId) =>
      '$reminderCooldownPrefix$friendshipId';
}
