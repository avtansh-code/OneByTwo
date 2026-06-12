import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/remote_config/remote_config_service.dart';
import 'package:onebytwo/core/services/url_launcher_service.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/profile/application/contact_support_controller.dart';
import 'package:onebytwo/features/profile/application/contact_support_telemetry.dart';
import 'package:onebytwo/features/profile/data/device_diagnostics_service.dart';
import 'package:onebytwo/features/profile/domain/support_diagnostics.dart';

class _FakeRemoteConfigService implements RemoteConfigService {
  _FakeRemoteConfigService(this._value);

  final String _value;

  @override
  Future<void> initialise() async {}

  @override
  String getString(String key) => _value;
}

class _FakeDeviceDiagnosticsService implements DeviceDiagnosticsService {
  _FakeDeviceDiagnosticsService(this._diagnostics);

  final SupportDiagnostics _diagnostics;

  @override
  Future<SupportDiagnostics> load() async => _diagnostics;
}

class _FakeUrlLauncherService implements UrlLauncherService {
  _FakeUrlLauncherService({
    this.canLaunchResult = true,
    this.launchResult = true,
    this.throwOnLaunch = false,
  });

  bool canLaunchResult;
  bool launchResult;
  bool throwOnLaunch;
  Uri? lastLaunchedUri;

  @override
  Future<bool> canLaunch(Uri uri) async => canLaunchResult;

  @override
  Future<bool> launchExternal(Uri uri) async {
    lastLaunchedUri = uri;
    if (throwOnLaunch) {
      throw PlatformException(code: 'FAILED_TO_LAUNCH');
    }
    return launchResult;
  }
}

class _RecordingAnalyticsService implements AnalyticsService {
  final List<({String name, Map<String, Object>? parameters})> events = [];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    events.add((name: name, parameters: parameters));
  }
}

const _diagnostics = SupportDiagnostics(
  appVersion: '1.0.0',
  buildNumber: '1',
  osName: 'Android',
  osVersion: '14',
  deviceModel: 'Pixel 6',
);

ContactSupportController _buildController({
  required _FakeUrlLauncherService launcher,
  required _RecordingAnalyticsService analytics,
  String address = 'support@onebytwo.app',
  String userId = 'uid_abc123',
}) {
  return ContactSupportController(
    remoteConfig: _FakeRemoteConfigService(address),
    diagnostics: _FakeDeviceDiagnosticsService(_diagnostics),
    launcher: launcher,
    analytics: analytics,
    userId: userId,
  );
}

void main() {
  group('buildBody', () {
    test('contains all five labelled diagnostic lines', () {
      final body = ContactSupportController.buildBody(
        userId: 'uid_abc123',
        diagnostics: _diagnostics,
      );

      expect(body, contains('User ID: uid_abc123'));
      expect(body, contains('App Version: 1.0.0 (1)'));
      expect(body, contains('OS: Android 14'));
      expect(body, contains('Device Model: Pixel 6'));
      expect(body, contains('Diagnostic Info (do not delete)'));
    });
  });

  group('buildMailtoUri', () {
    test('uses the mailto scheme and the address as the path', () {
      final uri = ContactSupportController.buildMailtoUri(
        address: 'support@onebytwo.app',
        userId: 'uid_abc123',
        diagnostics: _diagnostics,
      );

      expect(uri.scheme, 'mailto');
      expect(uri.path, 'support@onebytwo.app');
    });

    test('encodes spaces as %20 and newlines as %0A, never as +', () {
      final uri = ContactSupportController.buildMailtoUri(
        address: 'support@onebytwo.app',
        userId: 'uid_abc123',
        diagnostics: _diagnostics,
      );

      expect(uri.query, contains('subject=One%20By%20Two%20Support%20Request'));
      expect(uri.query, contains('%0A'));
      expect(uri.query, isNot(contains('+')));
    });
  });

  group('contactSupport', () {
    test('happy path launches the URI and logs method=mailto', () async {
      final launcher = _FakeUrlLauncherService();
      final analytics = _RecordingAnalyticsService();
      final controller = _buildController(
        launcher: launcher,
        analytics: analytics,
      );

      final result = await controller.contactSupport();

      expect(result, isA<ContactSupportLaunched>());
      expect(launcher.lastLaunchedUri?.scheme, 'mailto');
      expect(launcher.lastLaunchedUri?.path, 'support@onebytwo.app');
      expect(analytics.events, hasLength(1));
      expect(
        analytics.events.single.name,
        ContactSupportTelemetry.supportEmailOpenedEvent,
      );
      expect(analytics.events.single.parameters, {
        ContactSupportTelemetry.paramMethod:
            ContactSupportTelemetry.methodMailto,
      });
    });

    test('uses the Remote Config address, not a hardcoded one', () async {
      final launcher = _FakeUrlLauncherService();
      final analytics = _RecordingAnalyticsService();
      final controller = _buildController(
        address: 'help-rotated@onebytwo.app',
        launcher: launcher,
        analytics: analytics,
      );

      await controller.contactSupport();

      expect(launcher.lastLaunchedUri?.path, 'help-rotated@onebytwo.app');
    });

    test('no mail client returns fallback and logs '
        'method=fallback_dialog', () async {
      final launcher = _FakeUrlLauncherService(canLaunchResult: false);
      final analytics = _RecordingAnalyticsService();
      final controller = _buildController(
        launcher: launcher,
        analytics: analytics,
      );

      final result = await controller.contactSupport();

      expect(result, isA<ContactSupportFallbackRequired>());
      expect(launcher.lastLaunchedUri, isNull);
      expect(
        (result as ContactSupportFallbackRequired).supportEmailAddress,
        'support@onebytwo.app',
      );
      expect(analytics.events.single.parameters, {
        ContactSupportTelemetry.paramMethod:
            ContactSupportTelemetry.methodFallbackDialog,
      });
    });

    test('a launch returning false falls back', () async {
      final launcher = _FakeUrlLauncherService(launchResult: false);
      final analytics = _RecordingAnalyticsService();
      final controller = _buildController(
        launcher: launcher,
        analytics: analytics,
      );

      final result = await controller.contactSupport();

      expect(result, isA<ContactSupportFallbackRequired>());
      expect(
        analytics.events.single.parameters?[ContactSupportTelemetry
            .paramMethod],
        ContactSupportTelemetry.methodFallbackDialog,
      );
    });

    test('a thrown PlatformException falls back without crashing', () async {
      final launcher = _FakeUrlLauncherService(throwOnLaunch: true);
      final analytics = _RecordingAnalyticsService();
      final controller = _buildController(
        launcher: launcher,
        analytics: analytics,
      );

      final result = await controller.contactSupport();

      expect(result, isA<ContactSupportFallbackRequired>());
    });

    test('telemetry payload carries no PII', () async {
      final launcher = _FakeUrlLauncherService();
      final analytics = _RecordingAnalyticsService();
      final controller = _buildController(
        launcher: launcher,
        analytics: analytics,
      );

      await controller.contactSupport();

      final params = analytics.events.single.parameters ?? const {};
      expect(params.keys.toList(), [ContactSupportTelemetry.paramMethod]);
      for (final value in params.values) {
        final asText = value.toString();
        expect(asText, isNot(contains('uid_abc123')));
        expect(asText, isNot(contains('@')));
        expect(asText, isNot(contains('Pixel')));
      }
    });
  });
}
