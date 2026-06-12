import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/core/remote_config/remote_config_keys.dart';
import 'package:onebytwo/core/remote_config/remote_config_service.dart';
import 'package:onebytwo/core/services/url_launcher_service.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/friends/application/friends_list_provider.dart';
import 'package:onebytwo/features/profile/application/contact_support_telemetry.dart';
import 'package:onebytwo/features/profile/data/device_diagnostics_service.dart';
import 'package:onebytwo/features/profile/domain/support_diagnostics.dart';

/// Result of a Contact Support attempt (FR-PR-05 / FR-SH-03 / FR-SH-04).
sealed class ContactSupportResult {
  const ContactSupportResult();
}

/// The device's default mail client was launched with the pre-filled
/// `mailto:` URI (happy path).
class ContactSupportLaunched extends ContactSupportResult {
  /// Creates a [ContactSupportLaunched] result.
  const ContactSupportLaunched();
}

/// No mail client could be launched, so the caller must show the
/// FR-SH-04 fallback dialog with [supportEmailAddress].
class ContactSupportFallbackRequired extends ContactSupportResult {
  /// Creates a [ContactSupportFallbackRequired] carrying the resolved
  /// [supportEmailAddress] to display in the fallback dialog.
  const ContactSupportFallbackRequired(this.supportEmailAddress);

  /// The resolved support address (Remote Config value or compiled-in
  /// default) to display in the fallback dialog.
  final String supportEmailAddress;
}

/// Orchestrates the Profile "Contact Support" action (FR-PR-05,
/// FR-SH-03, FR-SH-04).
///
/// Gathers diagnostics, resolves the support address from Remote Config,
/// builds the `mailto:` URI, launches the device's default mail client,
/// and fires the [ContactSupportTelemetry.supportEmailOpenedEvent]
/// telemetry. When no mail client is available it returns
/// [ContactSupportFallbackRequired] so the widget can show the FR-SH-04
/// dialog. All branching is unit-testable without a `BuildContext`.
class ContactSupportController {
  /// Creates a [ContactSupportController].
  ContactSupportController({
    required RemoteConfigService remoteConfig,
    required DeviceDiagnosticsService diagnostics,
    required UrlLauncherService launcher,
    required AnalyticsService analytics,
    required String userId,
  }) : _remoteConfig = remoteConfig,
       _diagnostics = diagnostics,
       _launcher = launcher,
       _analytics = analytics,
       _userId = userId;

  final RemoteConfigService _remoteConfig;
  final DeviceDiagnosticsService _diagnostics;
  final UrlLauncherService _launcher;
  final AnalyticsService _analytics;
  final String _userId;

  /// Subject line for the support email (canonical contract — see the
  /// FR-PR-05 architect notes section 4.1).
  static const String subject = 'One By Two Support Request';

  /// Builds the `mailto:` URI, launches the default mail client, and
  /// fires `support_email_opened`.
  ///
  /// Returns [ContactSupportLaunched] when the mail client opened, or
  /// [ContactSupportFallbackRequired] (carrying the resolved address)
  /// when no mail client is available so the caller can show the
  /// FR-SH-04 dialog.
  Future<ContactSupportResult> contactSupport() async {
    final diagnostics = await _diagnostics.load();
    final address = _remoteConfig.getString(
      RemoteConfigKeys.supportEmailAddress,
    );
    final uri = buildMailtoUri(
      address: address,
      userId: _userId,
      diagnostics: diagnostics,
    );

    if (await _launcher.canLaunch(uri)) {
      try {
        if (await _launcher.launchExternal(uri)) {
          await _analytics.logEvent(
            name: ContactSupportTelemetry.supportEmailOpenedEvent,
            parameters: const <String, Object>{
              ContactSupportTelemetry.paramMethod:
                  ContactSupportTelemetry.methodMailto,
            },
          );
          return const ContactSupportLaunched();
        }
      } on PlatformException catch (_) {
        // A canLaunch false-positive must never crash; fall through to
        // the fallback dialog below.
      }
    }

    await _analytics.logEvent(
      name: ContactSupportTelemetry.supportEmailOpenedEvent,
      parameters: const <String, Object>{
        ContactSupportTelemetry.paramMethod:
            ContactSupportTelemetry.methodFallbackDialog,
      },
    );
    return ContactSupportFallbackRequired(address);
  }

  /// Builds the diagnostic email body (canonical contract — FR-PR-05
  /// architect notes section 4.1). The block is labelled "do not delete"
  /// so support receives the context even if the user types above it.
  @visibleForTesting
  static String buildBody({
    required String userId,
    required SupportDiagnostics diagnostics,
  }) {
    return 'Hi One By Two team,\n\n\n\n'
        '--- Diagnostic Info (do not delete) ---\n'
        'User ID: $userId\n'
        'App Version: ${diagnostics.appVersion} '
        '(${diagnostics.buildNumber})\n'
        'OS: ${diagnostics.osName} ${diagnostics.osVersion}\n'
        'Device Model: ${diagnostics.deviceModel}\n'
        '---';
  }

  /// Builds the `mailto:` URI (canonical contract — FR-PR-05 architect
  /// notes section 4.2).
  ///
  /// Encodes the subject and body with [Uri.encodeComponent] (spaces ->
  /// `%20`, newlines -> `%0A`) and passes them through the `query:`
  /// named parameter. The form-encoding alternatives
  /// (`queryParameters:` / `Uri.encodeQueryComponent`) are deliberately
  /// avoided because they emit `+` for spaces, which several mail
  /// clients render literally and corrupt the diagnostic text.
  @visibleForTesting
  static Uri buildMailtoUri({
    required String address,
    required String userId,
    required SupportDiagnostics diagnostics,
  }) {
    final body = buildBody(userId: userId, diagnostics: diagnostics);
    return Uri(
      scheme: 'mailto',
      path: address,
      query:
          'subject=${Uri.encodeComponent(subject)}'
          '&body=${Uri.encodeComponent(body)}',
    );
  }
}

/// Provides the [ContactSupportController].
///
/// Declares `currentUserIdProvider` as a dependency so the scoped
/// override bound by the authenticated shell
/// (`lib/main.dart`) resolves correctly on the Profile screen, mirroring
/// `friendsListProvider`. Without this the controller would sit in the
/// root scope and throw when reading `currentUserIdProvider` in
/// production.
final contactSupportControllerProvider = Provider<ContactSupportController>((
  ref,
) {
  return ContactSupportController(
    remoteConfig: ref.watch(remoteConfigServiceProvider),
    diagnostics: ref.watch(deviceDiagnosticsServiceProvider),
    launcher: ref.watch(urlLauncherServiceProvider),
    analytics: ref.watch(analyticsServiceProvider),
    userId: ref.watch(currentUserIdProvider),
  );
}, dependencies: [currentUserIdProvider]);
