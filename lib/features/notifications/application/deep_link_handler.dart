import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/core/routing/notification_deep_links.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/notifications/domain/notification_payload.dart';

/// The provenance of a deep-link dispatch — used to attribute
/// telemetry (`fcm_notification_tapped.source` parameter).
enum DeepLinkSource {
  /// Foreground in-app banner tap.
  foreground,

  /// System notification tap while the app was in the background.
  background,

  /// Cold-start launch from a tapped notification (FR-AC-05).
  coldStart,
}

extension _DeepLinkSourceX on DeepLinkSource {
  String get wireName {
    switch (this) {
      case DeepLinkSource.foreground:
        return 'foreground';
      case DeepLinkSource.background:
        return 'background';
      case DeepLinkSource.coldStart:
        return 'cold_start';
    }
  }
}

/// Dispatches a parsed [NotificationPayload] to the correct in-app
/// screen via the shared [NotificationDeepLinks] resolver. Emits the
/// `fcm_notification_tapped` telemetry event on every call.
class DeepLinkHandler {
  /// Creates a [DeepLinkHandler].
  ///
  /// The container is the Riverpod reader used to fetch the analytics
  /// service. Production wiring passes the app-level
  /// [ProviderContainer]; tests pass a hand-rolled container.
  const DeepLinkHandler(this._ref);

  final ProviderContainer _ref;

  /// Pure resolver — delegates to [NotificationDeepLinks.resolve]. The
  /// resolver is a pure function, so this method is testable without
  /// a [BuildContext].
  DeepLinkTarget resolveTarget(
    NotificationPayload payload, {
    required String currentUid,
  }) {
    return NotificationDeepLinks.resolve(payload, currentUid);
  }

  /// Resolves the deep-link target, emits telemetry, and performs the
  /// platform navigation.
  ///
  /// Telemetry: `fcm_notification_tapped` with
  ///   - `notification_type`: payload type's wire name (snake_case).
  ///   - `source`: foreground / background / cold_start.
  ///
  /// **PII guard (ADR-0013).** Friendship composite UIDs are NOT
  /// included in the telemetry parameters (we attribute by type +
  /// source only). If the architect later asks for entity correlation,
  /// add `entity_id_hash` parameter via `hashFriendshipId()` /
  /// `hashId()` per the FR-AC-01 precedent.
  Future<void> handleDeepLink({
    required NotificationPayload payload,
    required BuildContext context,
    required String currentUid,
    required DeepLinkSource source,
  }) async {
    final target = resolveTarget(payload, currentUid: currentUid);
    unawaited(
      _ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: 'fcm_notification_tapped',
            parameters: {
              'notification_type': payload.type.wireName,
              'source': source.wireName,
            },
          ),
    );
    if (!context.mounted) return;
    await NotificationDeepLinks.navigate(context, target);
  }
}

/// Riverpod provider for [DeepLinkHandler].
final deepLinkHandlerProvider = Provider<DeepLinkHandler>(
  (ref) => DeepLinkHandler(ref.container),
);
