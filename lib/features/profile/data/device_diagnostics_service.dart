import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/features/profile/domain/support_diagnostics.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Loads device and app diagnostics for the Contact Support body.
///
/// Abstracted for testability — tests override
/// [deviceDiagnosticsServiceProvider] with a fake returning fixed values
/// so no platform plugin is initialised.
// ignore: one_member_abstracts
abstract class DeviceDiagnosticsService {
  /// Gathers the current [SupportDiagnostics].
  Future<SupportDiagnostics> load();
}

/// Production [DeviceDiagnosticsService] backed by `package_info_plus`
/// and `device_info_plus`.
class PluginDeviceDiagnosticsService implements DeviceDiagnosticsService {
  /// Creates a [PluginDeviceDiagnosticsService].
  PluginDeviceDiagnosticsService() : _deviceInfo = DeviceInfoPlugin();

  final DeviceInfoPlugin _deviceInfo;

  @override
  Future<SupportDiagnostics> load() async {
    final packageInfo = await PackageInfo.fromPlatform();

    var osName = Platform.operatingSystem;
    var osVersion = '';
    var deviceModel = '';

    if (Platform.isAndroid) {
      final android = await _deviceInfo.androidInfo;
      osName = 'Android';
      osVersion = android.version.release;
      deviceModel = android.model;
    } else if (Platform.isIOS) {
      final ios = await _deviceInfo.iosInfo;
      osName = 'iOS';
      osVersion = ios.systemVersion;
      // `utsname.machine` is the precise hardware id (e.g. iPhone15,3),
      // far more useful for triage than the generic `model` ("iPhone").
      deviceModel = ios.utsname.machine;
    }

    return SupportDiagnostics(
      appVersion: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
      osName: osName,
      osVersion: osVersion,
      deviceModel: deviceModel,
    );
  }
}

/// Provides a [DeviceDiagnosticsService] instance.
///
/// Override in tests with a fake to avoid platform-plugin initialisation.
final deviceDiagnosticsServiceProvider = Provider<DeviceDiagnosticsService>(
  (ref) => PluginDeviceDiagnosticsService(),
);
