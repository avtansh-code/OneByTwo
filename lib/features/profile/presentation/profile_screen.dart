import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/application/auth_state_provider.dart';
import 'package:onebytwo/features/auth/data/phone_auth_repository.dart';
import 'package:onebytwo/features/auth/domain/auth_state.dart';
import 'package:onebytwo/features/auth/domain/user_model.dart';
import 'package:onebytwo/features/profile/presentation/edit_profile_screen.dart';

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
    );
  }

  Widget _buildErrorState(ThemeData theme, WidgetRef ref) {
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
                'We could not load your profile. '
                'Check your connection and try again.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  // ignore: unused_result
                  ref.refresh(authStateNotifierProvider);
                },
                child: const Text('Retry'),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(
                    ref.context,
                  ).showSnackBar(const SnackBar(content: Text('Coming soon')));
                },
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
                  label: 'Phone number: ${user.phoneNumber}',
                  child: Text(
                    user.phoneNumber,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
            label: 'My Friends, 0, button',
            child: _ProfileRow(
              icon: Icons.people,
              label: 'My Friends',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '0',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Coming soon')));
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
                    '0',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Coming soon')));
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
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Coming soon')));
              },
            ),
          ),
          Semantics(
            button: true,
            label: 'Contact Support, button',
            child: _ProfileRow(
              icon: Icons.support_agent,
              label: 'Contact Support',
              trailing: Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              onTap: () {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Coming soon')));
              },
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
                await ref.read(phoneAuthRepositoryProvider).signOut();
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
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
