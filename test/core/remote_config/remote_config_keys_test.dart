import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/remote_config/remote_config_keys.dart';

void main() {
  group('RemoteConfigDefaults', () {
    test('support email key and default match the ratified values', () {
      expect(RemoteConfigKeys.supportEmailAddress, 'support_email_address');
      expect(RemoteConfigDefaults.supportEmailAddress, 'support@onebytwo.app');
      expect(
        RemoteConfigDefaults.values[RemoteConfigKeys.supportEmailAddress],
        'support@onebytwo.app',
      );
    });

    group('resolve', () {
      test('returns the raw value when it is non-empty', () {
        expect(
          RemoteConfigDefaults.resolve(
            RemoteConfigKeys.supportEmailAddress,
            'help-rotated@onebytwo.app',
          ),
          'help-rotated@onebytwo.app',
        );
      });

      test('falls back to the compiled-in default when raw is empty', () {
        expect(
          RemoteConfigDefaults.resolve(
            RemoteConfigKeys.supportEmailAddress,
            '',
          ),
          RemoteConfigDefaults.supportEmailAddress,
        );
      });

      test('returns empty string for an unknown empty key', () {
        expect(RemoteConfigDefaults.resolve('nonexistent_key', ''), '');
      });
    });
  });
}
