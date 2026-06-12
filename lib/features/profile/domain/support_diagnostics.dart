import 'package:flutter/foundation.dart';

/// Immutable device and app diagnostic context for the Contact Support
/// `mailto:` body (FR-PR-05 / FR-SH-03).
///
/// Assembled by `DeviceDiagnosticsService` from `package_info_plus`
/// (app version + build number) and `device_info_plus` (OS version +
/// device model). The user's `userId` is supplied separately by the
/// controller and is not part of this value object.
@immutable
class SupportDiagnostics {
  /// Creates an immutable [SupportDiagnostics].
  const SupportDiagnostics({
    required this.appVersion,
    required this.buildNumber,
    required this.osName,
    required this.osVersion,
    required this.deviceModel,
  });

  /// App marketing version (e.g. `1.0.0`).
  final String appVersion;

  /// App build number (e.g. `1`).
  final String buildNumber;

  /// Operating-system name (`Android` or `iOS`).
  final String osName;

  /// Operating-system version (e.g. Android `14`, iOS `17.4`).
  final String osVersion;

  /// Device model for triage (e.g. `Pixel 6`, `iPhone15,3`).
  final String deviceModel;

  @override
  bool operator ==(Object other) {
    return other is SupportDiagnostics &&
        other.appVersion == appVersion &&
        other.buildNumber == buildNumber &&
        other.osName == osName &&
        other.osVersion == osVersion &&
        other.deviceModel == deviceModel;
  }

  @override
  int get hashCode {
    return Object.hash(appVersion, buildNumber, osName, osVersion, deviceModel);
  }
}
