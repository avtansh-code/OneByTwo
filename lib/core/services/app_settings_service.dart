import 'package:app_settings/app_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Abstraction over `app_settings` for testability.
///
/// Wraps `AppSettings.openAppSettings` so features can deep-link the
/// user to the OS settings screen (the AC-11 "Open Settings" CTA on the
/// SCR-27 notification banner and the SCR-10 contact-permission view)
/// without touching the platform channel in unit and widget tests,
/// which override [appSettingsServiceProvider] with a fake. Mirrors
/// `UrlLauncherService` (`lib/core/services/url_launcher_service.dart`).
///
/// Opening OS settings is NOT sharing — it must never be routed through
/// the system share sheet (Invariant 3 is not implicated).
abstract class AppSettingsService {
  /// Opens the OS notification settings screen for this app
  /// (Android `ACTION_APP_NOTIFICATION_SETTINGS`; iOS the app's
  /// settings page, which is the closest notification entry point).
  Future<void> openNotificationSettings();

  /// Opens the OS app settings screen for this app
  /// (Android `ACTION_APPLICATION_DETAILS_SETTINGS`; iOS
  /// `UIApplication.openSettingsURLString`), where the user can grant a
  /// permanently-denied permission.
  Future<void> openAppSettings();
}

/// Production [AppSettingsService] delegating to `app_settings`.
class DefaultAppSettingsService implements AppSettingsService {
  /// Creates a [DefaultAppSettingsService].
  const DefaultAppSettingsService();

  @override
  Future<void> openNotificationSettings() {
    return AppSettings.openAppSettings(type: AppSettingsType.notification);
  }

  @override
  Future<void> openAppSettings() {
    return AppSettings.openAppSettings();
  }
}

/// Provides an [AppSettingsService] instance.
///
/// Override in tests with a fake to avoid platform-channel calls.
final appSettingsServiceProvider = Provider<AppSettingsService>(
  (ref) => const DefaultAppSettingsService(),
);
