/// Firebase Remote Config parameter keys and their compiled-in defaults.
///
/// Keys use `snake_case` matching the Firebase Console parameter names
/// (a feature flag would use a `feature_` prefix; these are plain
/// configuration values). Every key declared here must have a matching
/// compiled-in default in [RemoteConfigDefaults] so the value resolves
/// offline and before the first successful fetch (ADR-0006).
abstract final class RemoteConfigKeys {
  /// Support email address used by the Contact Support `mailto:` flow on
  /// the Profile screen (FR-PR-05 / FR-SH-03). Read at runtime so the
  /// address can be rotated without an app release.
  static const String supportEmailAddress = 'support_email_address';
}

/// Compiled-in default values for [RemoteConfigKeys].
///
/// These ship inside the binary and are registered via `setDefaults` at
/// app start, so a read returns a sensible value even when Remote Config
/// has never been fetched (first launch offline, fetch failure, or a
/// genuinely missing/empty remote value).
abstract final class RemoteConfigDefaults {
  /// Default support address. Matches the wireframe fallback dialog and
  /// the QA test cases. The customer supplies the final GA address via
  /// the Remote Config server value before launch (SRS section 3.5);
  /// rotating it later needs no client release.
  static const String supportEmailAddress = 'support@onebytwo.app';

  /// Map of every Remote Config key to its compiled-in default. Passed to
  /// `setDefaults` and consumed by [resolve].
  static const Map<String, String> values = <String, String>{
    RemoteConfigKeys.supportEmailAddress: supportEmailAddress,
  };

  /// Resolves a Remote Config read to a non-empty value.
  ///
  /// Returns [rawValue] when it is non-empty; otherwise falls back to the
  /// compiled-in default for [key] (empty string if [key] is unknown).
  /// `FirebaseRemoteConfig.getString` returns `''` for an unknown key, so
  /// this guard deterministically covers the "fetch failed or key absent"
  /// case (FR-PR-05 acceptance scenario, dry-run Scenario 5).
  static String resolve(String key, String rawValue) {
    if (rawValue.isNotEmpty) {
      return rawValue;
    }
    return values[key] ?? '';
  }
}
