/// Telemetry event-name and parameter-key constants for the AC-11
/// "Open Settings" deep-link CTA, shared by the two surfaces that offer
/// it: the SCR-27 notification-permission banner (FR-PR-03 / FR-AC-04)
/// and the SCR-10 contact-permission view (FR-FR-01).
///
/// Declared in `docs/design/07-technical/telemetry-plan.md`:
///
///   | `permission_settings_opened` | `surface` |
///       `string` (`notifications` / `contacts`) |
///       User taps "Open Settings" on a permission-denied surface |
///       SCR-27 / SCR-10 |
///
/// PII-guard note (SRS line 308 / ADR-0013): the event carries no
/// `userId`, `uid`, `friendship_id`, or `friendship_id_hash`. The
/// [permissionSettingsSurfaceParam] value is a SAFE non-identifying
/// token — either [permissionSettingsSurfaceNotifications] or
/// [permissionSettingsSurfaceContacts].
library;

/// User tapped "Open Settings" on a permission-denied surface, which
/// deep-links to the OS settings screen via `AppSettingsService`.
const String permissionSettingsOpenedEvent = 'permission_settings_opened';

/// The originating surface. Value is one of
/// [permissionSettingsSurfaceNotifications] or
/// [permissionSettingsSurfaceContacts].
const String permissionSettingsSurfaceParam = 'surface';

/// The SCR-27 notification-permission banner surface.
const String permissionSettingsSurfaceNotifications = 'notifications';

/// The SCR-10 contact-permission view surface.
const String permissionSettingsSurfaceContacts = 'contacts';
