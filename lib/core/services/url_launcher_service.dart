import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Abstraction over `url_launcher` for testability.
///
/// Wraps `canLaunchUrl` / `launchUrl` so features can launch external
/// URIs (e.g. the Contact Support `mailto:` link, FR-PR-05) without
/// touching the platform channel in unit and widget tests, which
/// override [urlLauncherServiceProvider] with a fake.
abstract class UrlLauncherService {
  /// Whether the platform can handle [uri]. Mirrors `canLaunchUrl`.
  Future<bool> canLaunch(Uri uri);

  /// Launches [uri] in an external application (the device's default
  /// handler for the scheme). Returns `true` when the launch succeeds.
  Future<bool> launchExternal(Uri uri);
}

/// Production [UrlLauncherService] delegating to `url_launcher`.
class DefaultUrlLauncherService implements UrlLauncherService {
  /// Creates a [DefaultUrlLauncherService].
  const DefaultUrlLauncherService();

  @override
  Future<bool> canLaunch(Uri uri) => canLaunchUrl(uri);

  @override
  Future<bool> launchExternal(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Provides a [UrlLauncherService] instance.
///
/// Override in tests with a fake to avoid platform-channel calls.
final urlLauncherServiceProvider = Provider<UrlLauncherService>(
  (ref) => const DefaultUrlLauncherService(),
);
