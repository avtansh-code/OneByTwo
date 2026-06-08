import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/features/notifications/domain/notification_payload.dart';

/// Holds a pending deep-link intent until it can be resolved (FR-AC-05).
///
/// Set by `NotificationHandler.handleColdStart` when the user taps a
/// notification while the app is terminated AND not authenticated.
/// Consumed by the auth-state listener inside `lib/main.dart`: when
/// the state transitions to `AuthenticatedWithProfile`, the listener
/// reads this provider, clears it, and dispatches via the
/// `DeepLinkHandler.handleDeepLink`.
///
/// Defaults to `null` (no pending intent) on each `ProviderScope`
/// construction — i.e. each process launch.
final pendingDeepLinkProvider = StateProvider<NotificationPayload?>(
  (ref) => null,
);
