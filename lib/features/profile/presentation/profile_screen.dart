import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/application/auth_state_provider.dart';
import 'package:onebytwo/features/auth/domain/auth_state.dart';
import 'package:onebytwo/features/auth/domain/user_model.dart';
import 'package:onebytwo/features/notifications/application/sign_out_with_fcm_cleanup.dart';
import 'package:onebytwo/features/profile/application/contact_support_controller.dart';
import 'package:onebytwo/features/profile/application/friend_count_provider.dart';
import 'package:onebytwo/features/profile/application/profile_stats_telemetry.dart';
import 'package:onebytwo/features/profile/presentation/contact_support_fallback_dialog.dart';
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
    final authAsync = ref.watch(authStateNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        automaticallyImplyLeading: false,
      ),
      body: authAsync.when(
        loading: () => _buildLoadingState(theme),
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

  Widget _buildLoadingState(ThemeData theme) {
    return SafeArea(
      child: SingleChildScrollView(
        child: _ShimmerEffect(
          child: Column(
            children: [
              const SizedBox(height: 24),
              // Avatar shimmer.
              _SkeletonCircle(
                size: 96,
                colour: theme.colorScheme.surfaceContainerHighest,
              ),
              const SizedBox(height: 12),
              // Name shimmer.
              _SkeletonBar(
                width: 160,
                height: 20,
                colour: theme.colorScheme.surfaceContainerHighest,
              ),
              const SizedBox(height: 8),
              // Phone shimmer.
              _SkeletonBar(
                width: 120,
                height: 16,
                colour: theme.colorScheme.surfaceContainerHighest,
              ),
              const SizedBox(height: 24),
              const Divider(height: 1),
              // Row shimmers.
              for (var i = 0; i < 3; i++)
                _SkeletonBar(
                  width: double.infinity,
                  height: 56,
                  colour: theme.colorScheme.surfaceContainerHighest,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, WidgetRef ref) {
    final subtitle = _retryCount > 0
        ? 'Still not working. Try again or contact support.'
        : 'We could not load your profile. '
              'Check your connection and try again.';

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
                  ref.refresh(authStateNotifierProvider);
                },
                child: const Text('Retry'),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _contactSupport,
                child: Text(
                  'Still stuck? Contact Support',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
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
    final friendsCountText = _friendCountLabel(friendCountAsync);
    final friendsSemanticsLabel = switch (friendCountAsync) {
      AsyncData(:final value) => 'My Friends, $value, button',
      _ => 'My Friends, button',
    };
    return SafeArea(
      child: ListView(
        children: [
          // Section 1 — Profile header.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Semantics(
                  label: '${user.displayName} profile photo',
                  image: true,
                  child: user.photoUrl != null
                      ? CircleAvatar(
                          radius: 48,
                          backgroundImage: NetworkImage(user.photoUrl!),
                        )
                      : CircleAvatar(
                          radius: 48,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text(
                            _initials(user.displayName),
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
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
                const SizedBox(height: 4),
                Semantics(
                  label:
                      'Phone number: ${_formatPhoneForA11y(user.phoneNumber)}',
                  child: Text(
                    user.phoneNumber,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Section 2 — Stats.
          Semantics(
            button: true,
            label: friendsSemanticsLabel,
            child: _ProfileRow(
              icon: Icons.people,
              label: 'My Friends',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    friendsCountText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ],
              ),
              onTap: () {
                // Fire-and-forget telemetry (no await) then switch to the
                // Friends tab via the shell controller — NOT a duplicate
                // FriendsListScreen push (AC-5). Parameter-free event
                // (AC-9): a friend count is a non-identifying integer.
                ref
                    .read(analyticsServiceProvider)
                    .logEvent(name: ProfileStatsTelemetry.friendsTapped);
                ref
                    .read(shellNavigationControllerProvider.notifier)
                    .selectTab(1);
              },
            ),
          ),
          Semantics(
            button: true,
            label: 'My Groups, 0, button',
            child: _ProfileRow(
              icon: Icons.groups,
              label: 'My Groups',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    // Groups are README-only (Sprint 3 epic); the count
                    // is a literal stub. The Sprint 3 Groups epic swaps
                    // this for a real `groupCountProvider` without
                    // changing the row or navigation contract.
                    '0',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ],
              ),
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
          const Divider(height: 1),

          // Section 3 — Actions.
          Semantics(
            button: true,
            label: 'Edit Profile, button',
            child: _ProfileRow(
              icon: Icons.edit,
              label: 'Edit Profile',
              trailing: Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const EditProfileScreen(),
                  ),
                );
              },
            ),
          ),
          Semantics(
            button: true,
            label: 'Notification Preferences, button',
            child: _ProfileRow(
              icon: Icons.notifications_outlined,
              label: 'Notification Preferences',
              trailing: Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const NotificationPreferencesScreen(),
                  ),
                );
              },
            ),
          ),
          Semantics(
            button: true,
            label: 'Contact Support, button',
            child: _ProfileRow(
              icon: Icons.mail,
              label: 'Contact Support',
              trailing: Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              onTap: _contactSupport,
            ),
          ),
          const Divider(height: 1),

          // Section 4 — Destructive.
          Semantics(
            button: true,
            label: 'Sign Out, button',
            child: _ProfileRow(
              icon: Icons.logout,
              label: 'Sign Out',
              iconColour: theme.colorScheme.onSurface,
              onTap: () => _showSignOutDialog(context, ref),
            ),
          ),
          Semantics(
            button: true,
            label: 'Delete Account, button',
            child: _ProfileRow(
              icon: Icons.delete_forever,
              label: 'Delete Account',
              iconColour: theme.colorScheme.error,
              labelColour: theme.colorScheme.error,
              onTap: () {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Coming soon')));
              },
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
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

  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Are you sure you want to sign out? You will need '
          'to verify your phone number again to sign back in.',
        ),
        actions: [
          OutlinedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref
                  .read(analyticsServiceProvider)
                  .logEvent(name: 'sign_out_cancelled');
            },
            child: Text(
              'Cancel',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              try {
                await signOutWithFcmCleanup(ref);
                await ref
                    .read(analyticsServiceProvider)
                    .logEvent(name: 'sign_out_completed');
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Could not sign out. Please try again.'),
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

/// A single row in the profile screen with consistent 56dp
/// height, leading icon, label, and optional trailing widget.
class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    this.iconColour,
    this.labelColour,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColour;
  final Color? labelColour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(icon, color: iconColour ?? theme.colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(color: labelColour),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// Skeleton circle shimmer placeholder.
class _SkeletonCircle extends StatelessWidget {
  const _SkeletonCircle({required this.size, required this.colour});

  final double size;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
    );
  }
}

/// Skeleton bar shimmer placeholder.
class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({
    required this.width,
    required this.height,
    required this.colour,
  });

  final double width;
  final double height;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: colour,
        borderRadius: BorderRadius.circular(8),
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

/// Animated shimmer overlay for skeleton loading placeholders.
class _ShimmerEffect extends StatefulWidget {
  const _ShimmerEffect({required this.child});
  final Widget child;

  @override
  State<_ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<_ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                Color(0xFFE0E0E0),
                Color(0xFFF5F5F5),
                Color(0xFFE0E0E0),
              ],
              stops: [
                _controller.value - 0.3,
                _controller.value,
                _controller.value + 0.3,
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
