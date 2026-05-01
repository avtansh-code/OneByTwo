import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Abstraction over analytics logging to allow easy testing
/// without Firebase initialisation.
// ignore: one_member_abstracts
abstract class AnalyticsService {
  /// Logs a named event with optional parameters.
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  });
}

/// Production implementation that delegates to [FirebaseAnalytics].
class FirebaseAnalyticsService implements AnalyticsService {
  /// Creates a [FirebaseAnalyticsService] backed by the given instance.
  const FirebaseAnalyticsService(this._analytics);

  final FirebaseAnalytics _analytics;

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) {
    return _analytics.logEvent(name: name, parameters: parameters);
  }
}

/// Provides an [AnalyticsService] instance.
///
/// Override this provider in tests with a fake implementation to avoid
/// requiring Firebase initialisation.
final analyticsServiceProvider = Provider<AnalyticsService>(
  (ref) => FirebaseAnalyticsService(FirebaseAnalytics.instance),
);
