import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/services/app_settings_service.dart';
import 'package:onebytwo/core/telemetry/permission_settings_telemetry.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/widgets/feedback/obt_skeleton.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/application/auth_state_provider.dart';
import 'package:onebytwo/features/auth/domain/auth_state.dart';
import 'package:onebytwo/features/notifications/application/notification_permission_controller.dart';
import 'package:onebytwo/features/profile/application/notification_preferences_controller.dart';
import 'package:onebytwo/features/profile/application/notification_preferences_telemetry.dart';

/// SCR-27 Notification Preferences screen (FR-PR-03).
///
/// Four per-category toggle rows (new expenses, settlements, reminders &
/// nudges, group activity) grouped in a card with optimistic-with-revert
/// persistence driven by [notificationPreferencesControllerProvider],
/// plus a disabled "Coming soon" Language row and a rate-limit info
/// callout (Haldi screen 28). Surfaces an OS-permission info banner at
/// the top when push permission is `denied` / `permanentlyDenied`
/// (AC-11 / AC-12).
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
        appBar: AppBar(title: const Text('Notifications')),
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
      appBar: AppBar(title: const Text('Notifications')),
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
            onGroupActivityChanged: (v) => ref
                .read(notificationPreferencesControllerProvider.notifier)
                .setGroupActivity(v),
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
    // Skeletons, not spinners (DC-03): three row silhouettes stand in for
    // the toggle rows while preferences load.
    return const SafeArea(
      child: Padding(
        padding: EdgeInsets.only(top: 8),
        child: OBTSkeletonList(itemCount: 3),
      ),
    );
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
    required this.onGroupActivityChanged,
  });

  final Map<String, bool> prefs;
  final Set<String> savingKeys;
  final PermissionState permission;
  final ValueChanged<bool> onNewExpenseChanged;
  final ValueChanged<bool> onSettlementChanged;
  final ValueChanged<bool> onReminderChanged;
  final ValueChanged<bool> onGroupActivityChanged;

  bool _isPermissionBlocked(PermissionState s) =>
      s == PermissionState.denied || s == PermissionState.permanentlyDenied;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (_isPermissionBlocked(permission)) const _OsPermissionBanner(),
          const _SectionHeader('Push notifications'),
          _PrefsCard(
            children: [
              _ToggleRow(
                label: 'New expenses',
                description: 'When someone adds an expense with you',
                value: prefs[notificationPrefCategoryNewExpense] ?? true,
                onChanged: onNewExpenseChanged,
              ),
              _ToggleRow(
                label: 'Settlements',
                description: 'When a payment is recorded with you',
                value: prefs[notificationPrefCategorySettlement] ?? true,
                onChanged: onSettlementChanged,
              ),
              _ToggleRow(
                label: 'Reminders & nudges',
                description: 'When a friend nudges you to pay',
                value: prefs[notificationPrefCategoryReminder] ?? true,
                onChanged: onReminderChanged,
              ),
              _ToggleRow(
                label: 'Group activity',
                description: 'Members joining, edits & changes',
                value: prefs[notificationPrefCategoryGroupActivity] ?? false,
                onChanged: onGroupActivityChanged,
              ),
            ],
          ),
          const _SectionHeader('Preferences'),
          const _PrefsCard(children: [_LanguageSlot()]),
          const _InfoCallout(
            'Reminders you receive are always rate-limited to protect '
            'everyone from spam.',
          ),
        ],
      ),
    );
  }
}

/// A small uppercase section label above a [_PrefsCard] (the Haldi 28
/// "PUSH NOTIFICATIONS" / "PREFERENCES" group headers).
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: OBTColors.metaText(theme),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

/// A rounded white card grouping notification rows with hairline dividers
/// (the Haldi 28 settings card).
class _PrefsCard extends StatelessWidget {
  const _PrefsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        rows.add(
          Divider(
            height: 1,
            indent: 15,
            endIndent: 15,
            color: theme.dividerColor,
          ),
        );
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          boxShadow: obtColors.rowShadow,
          border: theme.brightness == Brightness.dark
              ? Border.all(color: theme.colorScheme.outline)
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: Column(mainAxisSize: MainAxisSize.min, children: rows),
        ),
      ),
    );
  }
}

/// A cream info callout with a leading info glyph (the Haldi 28
/// rate-limit notice).
class _InfoCallout extends StatelessWidget {
  const _InfoCallout(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: obtColors.warning.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 18, color: obtColors.link),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: OBTColors.metaText(theme),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
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
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;
    return Semantics(
      toggled: value,
      label: '$label notifications, switch, ${value ? "on" : "off"}',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: OBTColors.metaText(theme),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: obtColors.balancePositive,
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageSlot extends StatelessWidget {
  const _LanguageSlot();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;
    final disabled = obtColors.disabledText;
    final meta = OBTColors.metaText(theme);
    // Inert "Coming soon" slot: announced disabled, never a switch, so the
    // language picker is discoverable without shipping a switcher (no real
    // language switching is built in DC-10).
    return Semantics(
      enabled: false,
      excludeSemantics: true,
      label: 'Language, English India, coming soon',
      child: Opacity(
        opacity: 0.7,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
          child: Row(
            children: [
              Icon(Icons.translate, size: 22, color: meta),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Language',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: disabled,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'English (India)',
                      style: theme.textTheme.bodySmall?.copyWith(color: meta),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: obtColors.warning.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'COMING SOON',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: obtColors.link,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          border: Border.all(color: theme.colorScheme.outline),
        ),
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
                style: TextButton.styleFrom(
                  foregroundColor:
                      theme.extension<OBTColors>()?.link ??
                      theme.colorScheme.primary,
                ),
                onPressed: () => _openNotificationSettings(ref),
                child: const Text('Open Settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
