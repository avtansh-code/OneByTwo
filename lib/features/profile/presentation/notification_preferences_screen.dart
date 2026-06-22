import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/core/services/app_settings_service.dart';
import 'package:onebytwo/core/telemetry/permission_settings_telemetry.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/application/auth_state_provider.dart';
import 'package:onebytwo/features/auth/domain/auth_state.dart';
import 'package:onebytwo/features/notifications/application/notification_permission_controller.dart';
import 'package:onebytwo/features/profile/application/notification_preferences_controller.dart';
import 'package:onebytwo/features/profile/application/notification_preferences_telemetry.dart';

/// SCR-27 Notification Preferences screen (FR-PR-03).
///
/// Three per-category toggle rows with optimistic-with-revert
/// persistence driven by [notificationPreferencesControllerProvider].
/// Surfaces an OS-permission info banner at the top when push
/// permission is `denied` / `permanentlyDenied` (AC-11 / AC-12).
///
/// The AC-11 banner shows an "Open Settings" CTA that deep-links to the
/// OS notification settings via [appSettingsServiceProvider] (backed by
/// the `app_settings` plugin, ADR-0019). The banner copy is unchanged;
/// the button is the graceful-degradation extension the architect §2.4
/// fallback ladder promised, now that a settings-deep-link plugin is in
/// the lockfile (reversing that note's interim "ship without the
/// button" decision).
class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  /// Creates a [NotificationPreferencesScreen].
  const NotificationPreferencesScreen({super.key});

  @override
  ConsumerState<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends ConsumerState<NotificationPreferencesScreen> {
  bool _viewedLogged = false;

  @override
  void initState() {
    super.initState();
    // Single-fire `notification_prefs_viewed` telemetry on mount,
    // gated by `_viewedLogged` so the event fires exactly once per
    // screen lifecycle regardless of rebuilds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _viewedLogged) return;
      _viewedLogged = true;
      ref
          .read(analyticsServiceProvider)
          .logEvent(name: notificationPrefsViewedEvent);
    });
  }

  void _onStateChange(
    NotificationPreferencesState? previous,
    NotificationPreferencesState next,
  ) {
    // AC-7 revert snackbar: detect a transition where savingKeys
    // shrinks AND the prefs value for the just-completed key flipped
    // back to a value different from the pre-shrink optimistic value.
    if (previous is NotificationPreferencesReady &&
        next is NotificationPreferencesReady) {
      final completed = previous.savingKeys.difference(next.savingKeys);
      for (final key in completed) {
        final before = previous.prefs[key];
        final after = next.prefs[key];
        if (before != null && after != null && before != after) {
          // Persist failed — the optimistic flip reverted.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not update preference. Try again.'),
            ),
          );
        }
      }
    }

    // AC-10 offline banner — single-fire-per-controller-session.
    // The controller latches `offlineWriteJustQueued` to `true` on
    // the first offline toggle and preserves it via copyWith for the
    // remainder of the session, so this listener fires the snackbar
    // exactly once on the false → true edge.
    final wasOfflineSignal =
        previous is NotificationPreferencesReady &&
        previous.offlineWriteJustQueued;
    final isOfflineSignal =
        next is NotificationPreferencesReady && next.offlineWriteJustQueued;
    if (!wasOfflineSignal && isOfflineSignal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You are offline. Changes will sync when you reconnect.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Defence-in-depth: SCR-27 is only navigable from SCR-26 which is
    // itself behind auth. If the auth state flips during navigation
    // (e.g. token expiry), surface an honest 'Please sign in again.'
    // rather than letting an empty-uid Firestore read masquerade as a
    // generic load failure. AsyncLoading is treated as "not yet
    // known, don't gate" — the screen waits for resolution.
    final authState = ref.watch(authStateProvider);
    final isAuthed = authState.maybeWhen(
      data: (s) => s is AuthenticatedWithProfile,
      orElse: () => true,
    );
    if (!isAuthed) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notification Preferences')),
        body: _ErrorBody(
          message: 'Please sign in again.',
          onRetry: () => Navigator.of(context).maybePop(),
        ),
      );
    }

    ref.listen<NotificationPreferencesState>(
      notificationPreferencesControllerProvider,
      _onStateChange,
    );

    final state = ref.watch(notificationPreferencesControllerProvider);
    final permission = ref.watch(notificationPermissionControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notification Preferences')),
      body: switch (state) {
        NotificationPreferencesLoading() => const _LoadingBody(),
        NotificationPreferencesError(:final message) => _ErrorBody(
          message: message,
          onRetry: () {
            unawaitedReload(ref);
          },
        ),
        NotificationPreferencesReady(:final prefs, :final savingKeys) =>
          _ReadyBody(
            prefs: prefs,
            savingKeys: savingKeys,
            permission: permission,
            onNewExpenseChanged: (v) => ref
                .read(notificationPreferencesControllerProvider.notifier)
                .setNewExpense(v),
            onSettlementChanged: (v) => ref
                .read(notificationPreferencesControllerProvider.notifier)
                .setSettlement(v),
            onReminderChanged: (v) => ref
                .read(notificationPreferencesControllerProvider.notifier)
                .setReminder(v),
          ),
      },
    );
  }
}

/// Helper that swallows the `Future` returned by `reload` so the
/// `onPressed` callback for the Retry button stays `void`.
void unawaitedReload(WidgetRef ref) {
  // ignore: discarded_futures
  ref.read(notificationPreferencesControllerProvider.notifier).reload();
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: Text(
                  'Something went wrong',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadyBody extends StatelessWidget {
  const _ReadyBody({
    required this.prefs,
    required this.savingKeys,
    required this.permission,
    required this.onNewExpenseChanged,
    required this.onSettlementChanged,
    required this.onReminderChanged,
  });

  final Map<String, bool> prefs;
  final Set<String> savingKeys;
  final PermissionState permission;
  final ValueChanged<bool> onNewExpenseChanged;
  final ValueChanged<bool> onSettlementChanged;
  final ValueChanged<bool> onReminderChanged;

  bool _isPermissionBlocked(PermissionState s) =>
      s == PermissionState.denied || s == PermissionState.permanentlyDenied;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(
        children: [
          if (_isPermissionBlocked(permission)) const _OsPermissionBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Choose which notifications you would like to receive.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          _ToggleRow(
            label: 'New Expenses',
            description:
                'Get notified when someone adds an expense involving you.',
            value: prefs[notificationPrefCategoryNewExpense] ?? true,
            onChanged: onNewExpenseChanged,
          ),
          const Divider(height: 1),
          _ToggleRow(
            label: 'Settlements',
            description:
                'Get notified when someone records a payment involving you.',
            value: prefs[notificationPrefCategorySettlement] ?? true,
            onChanged: onSettlementChanged,
          ),
          const Divider(height: 1),
          _ToggleRow(
            label: 'Reminders',
            description: 'Receive reminders about outstanding balances.',
            value: prefs[notificationPrefCategoryReminder] ?? true,
            onChanged: onReminderChanged,
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      toggled: value,
      label: '$label notifications, switch, ${value ? "on" : "off"}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _OsPermissionBanner extends ConsumerWidget {
  const _OsPermissionBanner();

  void _openNotificationSettings(WidgetRef ref) {
    // PII-free telemetry: a non-identifying `surface` enum only
    // (SRS line 308 / ADR-0013).
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: permissionSettingsOpenedEvent,
            parameters: const {
              permissionSettingsSurfaceParam:
                  permissionSettingsSurfaceNotifications,
            },
          ),
    );
    // Graceful degradation (AC-5): a failed OS-settings deep-link must
    // not crash or surface an uncaught async error; the banner stays so
    // the user can retry or follow the on-screen instruction.
    unawaited(
      ref
          .read(appSettingsServiceProvider)
          .openNotificationSettings()
          .catchError((Object _) {}),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Notifications are turned off for this app. '
                  'Enable them in your device settings to receive alerts.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _openNotificationSettings(ref),
              child: const Text('Open Settings'),
            ),
          ),
        ],
      ),
    );
  }
}
