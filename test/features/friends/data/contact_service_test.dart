// Unit tests for FlutterContactService.openSettings().
//
// Verifies the SCR-10 "Open Settings" CTA delegates to the shared
// AppSettingsService (the OS app-settings deep-link) rather than the
// previous FlutterContacts.openExternalPick() contact-picker fallback.

import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/services/app_settings_service.dart';
import 'package:onebytwo/features/friends/data/contact_service.dart';

class _FakeAppSettingsService implements AppSettingsService {
  int notificationCalls = 0;
  int appSettingsCalls = 0;

  @override
  Future<void> openNotificationSettings() async => notificationCalls++;

  @override
  Future<void> openAppSettings() async => appSettingsCalls++;
}

void main() {
  group('FlutterContactService.openSettings', () {
    test('delegates to AppSettingsService.openAppSettings (the OS '
        'app-settings deep-link)', () async {
      final appSettings = _FakeAppSettingsService();
      final service = FlutterContactService(appSettings: appSettings);

      await service.openSettings();

      expect(appSettings.appSettingsCalls, 1);
      // The contacts CTA opens the generic app settings, not the
      // notification-specific screen.
      expect(appSettings.notificationCalls, 0);
    });
  });
}
