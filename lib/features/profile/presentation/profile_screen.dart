import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/constants/legal_urls.dart';
import 'package:onebytwo/core/services/url_launcher_service.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/theme/obt_text.dart';
import 'package:onebytwo/core/widgets/branding/obt_gradient_avatar.dart';
import 'package:onebytwo/core/widgets/dialogs/obt_confirmation_dialog.dart';
import 'package:onebytwo/core/widgets/feedback/obt_skeleton.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/application/auth_state_provider.dart';
import 'package:onebytwo/features/auth/domain/auth_state.dart';
import 'package:onebytwo/features/auth/domain/user_model.dart';
import 'package:onebytwo/features/notifications/application/sign_out_with_fcm_cleanup.dart';
import 'package:onebytwo/features/profile/application/contact_support_controller.dart';
import 'package:onebytwo/features/profile/application/friend_count_provider.dart';
import 'package:onebytwo/features/profile/application/profile_stats_telemetry.dart';
import 'package:onebytwo/features/profile/presentation/contact_support_fallback_dialog.dart';
import 'package:onebytwo/features/profile/presentation/delete_account_screen.dart';
import 'package:onebytwo/features/profile/presentation/edit_profile_screen.dart';
import 'package:onebytwo/features/profile/presentation/notification_preferences_screen.dart';
import 'package:onebytwo/features/shell/application/shell_navigation_controller.dart';

/// Profile view screen for FR-PR-01 (SCR-26).
///
/// Displays the authenticated user's profile information,
/// friend/group counts, and provides access to edit profile,
/// sign out, and other actions.
///
/// This is a tab root screen (no back button, bottom nav visible).
class ProfileScreen extends ConsumerStatefulWidget {
  /// Creates a [ProfileScreen].
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
    // Fire profile_viewed telemetry on mount.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsServiceProvider).logEvent(name: 'profile_viewed');
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authAsync = ref.watch(authStateProvider);

    return Scaffold(
      body: authAsync.when(
        loading: _buildLoadingState,
        error: (error, _) => _buildErrorState(theme, ref),
        data: (authState) {
          final user = switch (authState) {
            AuthenticatedWithProfile(:final user) => user,
            _ => null,
          };

          if (user == null) {
            return _buildErrorState(theme, ref);
          }

          return _buildPopulatedState(context, theme, ref, user);
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    // Shared Haldi skeleton primitives (DC-03) replace the hand-rolled
    // shimmer: the avatar, name and phone silhouettes plus three row
    // placeholders. Colour flows from the theme inside [OBTSkeleton], so no
    // hard-coded greys remain.
    return const SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 24),
            OBTSkeletonCircle(diameter: 96),
            SizedBox(height: 12),
            OBTSkeleton(width: 160, height: 20),
            SizedBox(height: 8),
            OBTSkeleton(width: 120, height: 16),
            SizedBox(height: 24),
            Divider(height: 1),
            OBTSkeletonList(itemCount: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, WidgetRef ref) {
    final subtitle = _retryCount > 0
        ? 'Still not working. Try again or contact support.'
        : 'We could not load your profile. '
              'Check your connection and try again.';
    final link =
        theme.extension<OBTColors>()?.link ?? theme.colorScheme.primary;

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
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _retryCount++;
                  });
                  // ignore: unused_result
                  ref.refresh(authStateProvider);
                },
                child: const Text('Retry'),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _contactSupport,
                child: Text(
                  'Still stuck? Contact Support',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: link,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPopulatedState(
    BuildContext context,
    ThemeData theme,
    WidgetRef ref,
    UserModel user,
  ) {
    // FR-PR-04 — live "My Friends" count. Read-side projection of
    // `friendsListProvider`; a count read failure renders an em dash
    // (never a crash) and never blocks the rest of the screen.
    final friendCountAsync = ref.watch(friendCountProvider);
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;
    final friendsCountText = _friendCountLabel(friendCountAsync);
    final friendsSemanticsLabel = switch (friendCountAsync) {
      AsyncData(:final value) => 'My Friends, $value, button',
      _ => 'My Friends, button',
    };
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Header — avatar, name, +91, and the "Edit profile" pill.
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
            child: Column(
              children: [
                Semantics(
                  label: '${user.displayName} profile photo',
                  image: true,
                  child: OBTGradientAvatar(
                    size: 80,
                    displayName: user.displayName,
                    photoUrl: user.photoUrl,
                  ),
                ),
                const SizedBox(height: 12),
                Semantics(
                  header: true,
                  child: Text(
                    user.displayName,
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 2),
                Semantics(
                  label:
                      'Phone number: ${_formatPhoneForA11y(user.phoneNumber)}',
                  child: Text(
                    _formatPhoneDisplay(user.phoneNumber),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: OBTColors.metaText(theme),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const EditProfileScreen(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurface,
                    backgroundColor: theme.colorScheme.surface,
                    side: BorderSide(color: theme.colorScheme.outline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 9,
                    ),
                  ),
                  icon: const Icon(Icons.edit, size: 17),
                  label: const Text('Edit profile'),
                ),
              ],
            ),
          ),

          // Stat cards — Friends + Groups.
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.group,
                    iconColour: theme.colorScheme.primary,
                    value: friendsCountText,
                    label: 'Friends',
                    semanticsLabel: friendsSemanticsLabel,
                    onTap: () {
                      ref
                          .read(analyticsServiceProvider)
                          .logEvent(name: ProfileStatsTelemetry.friendsTapped);
                      ref
                          .read(shellNavigationControllerProvider.notifier)
                          .selectTab(1);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    icon: Icons.groups,
                    // The category-violet from the Haldi palette (Rent hue).
                    iconColour: obtColors.categoryColor(OBTCategory.rent),
                    // Groups are README-only (Sprint 4 epic) — literal stub.
                    value: '0',
                    label: 'Groups',
                    semanticsLabel: 'My Groups, 0, button',
                    onTap: () {
                      ref
                          .read(analyticsServiceProvider)
                          .logEvent(name: ProfileStatsTelemetry.groupsTapped);
                      ref
                          .read(shellNavigationControllerProvider.notifier)
                          .selectTab(2);
                    },
                  ),
                ),
              ],
            ),
          ),

          // Settings card.
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: _SettingsCard(
              children: [
                _SettingsRow(
                  icon: Icons.notifications_outlined,
                  label: 'Notifications',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const NotificationPreferencesScreen(),
                      ),
                    );
                  },
                ),
                _SettingsRow(
                  icon: Icons.dark_mode_outlined,
                  label: 'Appearance',
                  trailingText: 'System',
                  onTap: _openAppearance,
                ),
                _SettingsRow(
                  icon: Icons.help_outline,
                  label: 'Help & support',
                  onTap: _contactSupport,
                ),
                _SettingsRow(
                  icon: Icons.shield_outlined,
                  label: 'Privacy & terms',
                  onTap: _openPrivacyAndTerms,
                ),
              ],
            ),
          ),

          // Sign out (danger).
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: _SettingsCard(
              children: [
                _SettingsRow(
                  icon: Icons.logout,
                  label: 'Sign out',
                  danger: true,
                  showChevron: false,
                  onTap: _showSignOutDialog,
                ),
              ],
            ),
          ),

          // Delete account — kept reachable (FR-AU-09); a quiet danger row
          // below sign-out (the handoff root omits it, but the shipped
          // feature must not be orphaned).
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: _SettingsCard(
              children: [
                _SettingsRow(
                  icon: Icons.delete_forever,
                  label: 'Delete account',
                  danger: true,
                  showChevron: false,
                  onTap: _openDeleteAccount,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Appearance (theme) is designed but not yet built — surface a
  /// "coming soon" hint rather than a dead control.
  void _openAppearance() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Appearance options are coming soon.')),
    );
  }

  /// Opens the Privacy Policy in the system browser (the "Privacy & terms"
  /// settings row). Falls back to a hint snackbar if no handler exists.
  Future<void> _openPrivacyAndTerms() async {
    final launcher = ref.read(urlLauncherServiceProvider);
    final uri = Uri.parse(LegalUrls.privacyPolicy);
    var launched = false;
    if (await launcher.canLaunch(uri)) {
      launched = await launcher.launchExternal(uri);
    }
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open the link. Visit ${LegalUrls.privacyPolicy}',
          ),
        ),
      );
    }
  }

  /// Runs the Contact Support flow (FR-PR-05 / FR-SH-03): launches the
  /// device's default mail client via a pre-filled `mailto:` URI, or
  /// shows the FR-SH-04 fallback dialog when no mail client is available.
  Future<void> _contactSupport() async {
    final result = await ref
        .read(contactSupportControllerProvider)
        .contactSupport();
    if (!mounted) return;
    if (result is ContactSupportFallbackRequired) {
      await ContactSupportFallbackDialog.show(
        context,
        supportEmailAddress: result.supportEmailAddress,
      );
    }
  }

  /// Opens the FR-AU-09 account-deletion flow (SCR-28 Part B). On a Step D
  /// failure / timeout the screen pops with [DeleteAccountOutcome.failed]
  /// and Profile View shows an error snackbar whose action reuses the
  /// FR-PR-05 Contact Support flow. On success the flow signs out and the
  /// root auth gate routes to the Phone Entry screen, so control never
  /// returns here.
  Future<void> _openDeleteAccount() async {
    final outcome = await Navigator.of(context).push<DeleteAccountOutcome>(
      MaterialPageRoute<DeleteAccountOutcome>(
        builder: (_) => const DeleteAccountScreen(),
      ),
    );
    if (!mounted) return;
    if (outcome == DeleteAccountOutcome.failed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Account deletion failed. Please try again or contact support.',
          ),
          action: SnackBarAction(
            label: 'Contact Support',
            onPressed: _contactSupport,
          ),
        ),
      );
    }
  }

  Future<void> _showSignOutDialog() async {
    // Use the OBTConfirmationDialog widget directly (not the .show helper) so
    // sign_out_cancelled is emitted ONLY on an explicit Cancel tap, matching
    // the previous AlertDialog where a scrim / back dismiss logged nothing
    // (no telemetry behaviour change).
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => OBTConfirmationDialog(
        title: 'Sign out?',
        body:
            "You'll need your +91 number and a fresh code to sign back in. "
            'Your expenses and groups stay safe.',
        confirmLabel: 'Sign out',
        onCancel: () {
          unawaited(
            ref
                .read(analyticsServiceProvider)
                .logEvent(name: 'sign_out_cancelled'),
          );
          Navigator.of(dialogContext).pop(false);
        },
        onConfirm: () => Navigator.of(dialogContext).pop(true),
      ),
    );

    if (confirmed != true) return;

    try {
      await signOutWithFcmCleanup(ref);
      await ref
          .read(analyticsServiceProvider)
          .logEvent(name: 'sign_out_completed');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not sign out. Please try again.')),
      );
    }
  }
}

/// A profile stat card (Friends / Groups) — a white surface card holding a
/// hued icon, a Bricolage count, and a label, per the Haldi 27 stat row.
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColour,
    required this.value,
    required this.label,
    required this.semanticsLabel,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColour;
  final String value;
  final String label;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;
    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              boxShadow: obtColors.rowShadow,
              border: theme.brightness == Brightness.dark
                  ? Border.all(color: theme.colorScheme.outline)
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(icon, size: 22, color: iconColour),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        value,
                        style: OBTText.amount(context).copyWith(fontSize: 17),
                      ),
                      Text(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: OBTColors.metaText(theme),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A rounded settings card grouping [_SettingsRow]s with hairline dividers
/// between them (the Haldi 27 settings list).
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

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
    return DecoratedBox(
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
    );
  }
}

/// A single row inside a [_SettingsCard]: a neutral leading icon, a label,
/// an optional trailing value, and a chevron. [danger] tints the icon +
/// label with the error colour (sign-out / delete).
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailingText,
    this.danger = false,
    this.showChevron = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? trailingText;
  final bool danger;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColour = danger
        ? theme.colorScheme.error
        : OBTColors.metaText(theme);
    final labelColour = danger ? theme.colorScheme.error : null;
    return Semantics(
      button: true,
      label: '$label, button',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Row(
              children: [
                Icon(icon, size: 22, color: iconColour),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: labelColour,
                    ),
                  ),
                ),
                if (trailingText != null) ...[
                  Text(
                    trailingText!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: OBTColors.metaText(theme),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                if (showChevron)
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Formats a phone number for accessible screen reader output.
///
/// Converts "+919876543210" to "plus 91 98765 43210".
String _formatPhoneForA11y(String phone) {
  if (phone.startsWith('+91') && phone.length == 13) {
    final digits = phone.substring(3);
    return 'plus 91 ${digits.substring(0, 5)} ${digits.substring(5)}';
  }
  return phone;
}

/// Formats "+919876543210" for display as "+91 98765 43210" (the design
/// phone presentation). Falls back to the raw value for any other shape.
String _formatPhoneDisplay(String phone) {
  if (phone.startsWith('+91') && phone.length == 13) {
    final digits = phone.substring(3);
    return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
  }
  return phone;
}

/// Maps the FR-PR-04 friend-count async sub-state to the trailing text
/// shown on the "My Friends" stats row: the resolved integer, or an em
/// dash (U+2014) while loading or on a read error. The error case is
/// defensive — a count read failure must never crash the Profile screen
/// or block sign-out (SRS §6.4; AC-3 loading / AC-4 error).
String _friendCountLabel(AsyncValue<int> friendCount) {
  return switch (friendCount) {
    AsyncData(:final value) => '$value',
    _ => '\u2014',
  };
}
