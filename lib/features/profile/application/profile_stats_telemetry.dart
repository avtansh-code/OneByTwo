/// Telemetry for the FR-PR-04 Profile Stats rows (SCR-26). Both events
/// are parameter-free — a friend count is a non-identifying integer, so
/// no payload and no hashing (per the telemetry-plan PII convention).
/// Pre-declared in `docs/design/07-technical/telemetry-plan.md` §1.7.
abstract final class ProfileStatsTelemetry {
  /// User tapped the "My Friends" row; shell switches to the Friends tab.
  static const String friendsTapped = 'profile_friends_tapped';

  /// User tapped the "My Groups" row; shell switches to the Groups tab.
  static const String groupsTapped = 'profile_groups_tapped';
}
