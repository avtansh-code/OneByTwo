import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/profile/domain/support_diagnostics.dart';

void main() {
  const base = SupportDiagnostics(
    appVersion: '1.0.0',
    buildNumber: '1',
    osName: 'Android',
    osVersion: '14',
    deviceModel: 'Pixel 6',
  );

  group('SupportDiagnostics', () {
    test('value equality holds for identical field values', () {
      const other = SupportDiagnostics(
        appVersion: '1.0.0',
        buildNumber: '1',
        osName: 'Android',
        osVersion: '14',
        deviceModel: 'Pixel 6',
      );

      expect(base, equals(other));
      expect(base.hashCode, equals(other.hashCode));
    });

    test('differs when any field differs', () {
      const differentModel = SupportDiagnostics(
        appVersion: '1.0.0',
        buildNumber: '1',
        osName: 'Android',
        osVersion: '14',
        deviceModel: 'iPhone15,3',
      );

      expect(base, isNot(equals(differentModel)));
    });
  });
}
