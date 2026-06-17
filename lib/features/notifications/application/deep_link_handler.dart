import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/core/routing/notification_deep_links.dart';
import 'package:onebytwo/core/widgets/nav/obt_bottom_nav.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/notifications/domain/notification_payload.dart';
import 'package:onebytwo/features/shell/application/shell_navigation_controller.dart';

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
/// screen via the shared [NotificationDeepLinks] resolver. Selects the
/// relevant primary bottom-nav tab (via `shellNavigationControllerProvider`)
/// before the navigation so the user lands in a coherent tab context
/// (FR-AC-05 tab-switch, ADR-0018), and emits the `fcm_notification_tapped`
/// telemetry event on every call.
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

  /// Resolves the deep-link target, emits telemetry, selects the relevant
  /// primary tab, and performs the platform navigation.
  ///
  /// Telemetry: `fcm_notification_tapped` with
  ///   - `notification_type`: payload type's wire name (snake_case).
  ///   - `source`: foreground / background / cold_start.
  ///   - `target_tab`: the non-identifying tab token the deep-link selects
  ///     (`friends` / `activity`) or `none` when no tab switch occurs.
  ///
  /// **Tab-switch (FR-AC-05, ADR-0018).** The target's
  /// [DeepLinkTarget.homeTabIndex] is selected via
  /// `shellNavigationControllerProvider.selectTab(...)` **before** the
  /// root-navigator push, so the detail screen is presented over the correct
  /// tab (no wrong-tab flash) and pop returns there. `selectTab` ignores a
  /// `null`/out-of-range index. The Activity-feed row tap consumes the resolver
  /// + `navigate` directly (not this handler), so it never switches tabs.
  ///
  /// **PII guard (ADR-0013).** Friendship composite UIDs are NOT
  /// included in the telemetry parameters (we attribute by type +
  /// source + the non-identifying `target_tab` only). If the architect later
  /// asks for entity correlation, add `entity_id_hash` parameter via
  /// `hashFriendshipId()` / `hashId()` per the FR-AC-01 precedent.
  Future<void> handleDeepLink({
    required NotificationPayload payload,
    required BuildContext context,
    required String currentUid,
    required DeepLinkSource source,
  }) async {
    final target = resolveTarget(payload, currentUid: currentUid);
    final tabIndex = target.homeTabIndex;
    unawaited(
      _ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: 'fcm_notification_tapped',
            parameters: {
              'notification_type': payload.type.wireName,
              'source': source.wireName,
              'target_tab': _targetTabToken(tabIndex),
            },
          ),
    );
    if (tabIndex != null) {
      _ref.read(shellNavigationControllerProvider.notifier).selectTab(tabIndex);
    }
    if (!context.mounted) return;
    await NotificationDeepLinks.navigate(context, target);
  }

  /// Maps a target's [DeepLinkTarget.homeTabIndex] to the non-identifying
  /// `target_tab` telemetry token — the canonical `OBTBottomNav` tab label, or
  /// `'none'` when the target does not switch tabs. PII-free by construction (a
  /// fixed tab token, never a UID/composite) — ADR-0013.
  String _targetTabToken(int? tabIndex) {
    if (tabIndex == null ||
        tabIndex < 0 ||
        tabIndex >= OBTBottomNav.tabs.length) {
      return 'none';
    }
    return OBTBottomNav.tabs[tabIndex].telemetryLabel;
  }
}

/// Riverpod provider for [DeepLinkHandler].
final deepLinkHandlerProvider = Provider<DeepLinkHandler>(
  (ref) => DeepLinkHandler(ref.container),
);
