import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../logging/app_logger.dart';

/// Service for monitoring network connectivity state.
///
/// Wraps [Connectivity] from `connectivity_plus` and provides a simplified
/// boolean stream indicating whether the device has an active network
/// connection (WiFi, mobile, ethernet, or VPN).
///
/// Usage:
/// ```dart
/// final service = ConnectivityService();
/// service.onConnectivityChanged.listen((isOnline) {
///   // React to connectivity changes.
/// });
/// ```
class ConnectivityService {
  /// Creates a [ConnectivityService].
  ///
  /// An optional [Connectivity] instance can be provided for testing.
  ConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity() {
    _controller = StreamController<bool>.broadcast();
    _subscription = _connectivity.onConnectivityChanged.listen(_handleChange);
  }

  static const String _tag = 'ConnectivityService';

  final Connectivity _connectivity;
  StreamController<bool>? _controller;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Stream that emits `true` when the device is online and `false`
  /// when offline.
  ///
  /// Emits a new value each time the connectivity state changes.
  Stream<bool> get onConnectivityChanged => _controller!.stream;

  /// Returns the current connectivity status.
  ///
  /// Returns `true` if the device has WiFi, mobile, ethernet, or VPN
  /// connectivity; `false` otherwise.
  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    return _isOnline(results);
  }

  /// Handles connectivity change events from the platform.
  void _handleChange(List<ConnectivityResult> results) {
    final online = _isOnline(results);
    AppLogger.info(
      _tag,
      online ? 'Device is online' : 'Device is offline',
      data: {'connectivityResults': results.map((r) => r.name).toList()},
    );
    _controller?.add(online);
  }

  /// Determines if any of the [results] represent an active connection.
  static bool _isOnline(List<ConnectivityResult> results) {
    return results.any(
      (r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet ||
          r == ConnectivityResult.vpn,
    );
  }

  /// Releases resources held by this service.
  ///
  /// After calling [dispose], [onConnectivityChanged] will no longer emit.
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _controller?.close();
    _controller = null;
  }
}
