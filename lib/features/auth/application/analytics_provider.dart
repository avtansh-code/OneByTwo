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

/// Coerces analytics parameter values into Firebase-acceptable types.
///
/// Firebase Analytics only accepts `String` or `num` parameter values; a
/// `bool` throws an assertion in debug builds (breaking the calling flow)
/// and is rejected in release. This coerces any `bool` to its `String`
/// form so semantic boolean params (e.g. `payer_is_self`, `has_receipt`)
/// are recorded as `"true"`/`"false"` rather than crashing the caller
/// (defect D11). All other values pass through unchanged.
Map<String, Object>? sanitiseAnalyticsParameters(
  Map<String, Object>? parameters,
) {
  return parameters?.map(
    (key, value) => MapEntry(key, value is bool ? value.toString() : value),
  );
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
    return _analytics.logEvent(
      name: name,
      parameters: sanitiseAnalyticsParameters(parameters),
    );
  }
}

/// Provides an [AnalyticsService] instance.
///
/// Override this provider in tests with a fake implementation to avoid
/// requiring Firebase initialisation.
final analyticsServiceProvider = Provider<AnalyticsService>(
  (ref) => FirebaseAnalyticsService(FirebaseAnalytics.instance),
);
