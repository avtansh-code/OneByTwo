// Smoke test for the AppSettingsService seam.
//
// Verifies the abstract type, the default implementation, and the
// Riverpod provider are wired correctly (ADR-0019). Mirrors
// image_picker_service_test.dart.
//
// DefaultAppSettingsService cannot be exercised end-to-end here because
// that would require the app_settings plugin to be initialised against
// a real platform channel. Feature tests inject a fake for that
// purpose (e.g. notification_preferences_screen_test.dart); this file
// just confirms the provider resolves and the default impl implements
// the abstract contract.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/services/app_settings_service.dart';

void main() {
  group('appSettingsServiceProvider', () {
    test('resolves to a DefaultAppSettingsService by default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final service = container.read(appSettingsServiceProvider);
      expect(service, isA<AppSettingsService>());
      expect(service, isA<DefaultAppSettingsService>());
    });

    test('can be overridden with a fake for tests', () {
      final container = ProviderContainer(
        overrides: [
          appSettingsServiceProvider.overrideWithValue(
            _NoopAppSettingsService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(appSettingsServiceProvider);
      expect(service, isA<_NoopAppSettingsService>());
    });
  });
}

class _NoopAppSettingsService implements AppSettingsService {
  @override
  Future<void> openNotificationSettings() async {}

  @override
  Future<void> openAppSettings() async {}
}
