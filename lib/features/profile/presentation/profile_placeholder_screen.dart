import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/application/auth_state_provider.dart';
import 'package:onebytwo/features/auth/domain/auth_state.dart';
import 'package:onebytwo/features/notifications/application/sign_out_with_fcm_cleanup.dart';

/// Minimal Profile placeholder screen for PR #10.
///
/// Displays the authenticated user's basic info and a sign-out row.
/// This stub will be replaced by the full Profile View/Edit (FR-PR-01)
/// in PR #12.
///
/// See `docs/design/06-screen-specs/23-28-settle-activity-profile.md` (SCR-26)
/// for the sign-out flow specification.
class ProfilePlaceholderScreen extends ConsumerWidget {
  /// Creates a [ProfilePlaceholderScreen].
  const ProfilePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authStateNotifierProvider);

    final displayName = authState.whenOrNull(
      data: (state) => switch (state) {
        AuthenticatedWithProfile(:final user) => user.displayName,
        _ => null,
      },
    );

    final phoneNumber = authState.whenOrNull(
      data: (state) => switch (state) {
        AuthenticatedWithProfile(:final user) => user.phoneNumber,
        _ => null,
      },
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), leading: const BackButton()),
      body: SafeArea(
        child: Column(
          children: [
            // Profile header.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  // Avatar placeholder.
                  Semantics(
                    label: '${displayName ?? 'User'} profile photo',
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        _initials(displayName),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (displayName != null)
                    Semantics(
                      header: true,
                      child: Text(
                        displayName,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                  if (phoneNumber != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Semantics(
                        label: 'Phone number: $phoneNumber',
                        child: Text(
                          phoneNumber,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            const Spacer(),
            const Divider(height: 1),
            // Sign out row.
            Semantics(
              button: true,
              label: 'Sign Out, button',
              child: ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign Out'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                minVerticalPadding: 16,
                onTap: () => _showSignOutDialog(context, ref),
              ),
            ),
          ],
        ),
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
          'Are you sure you want to sign out? You will need to verify '
          'your phone number again to sign back in.',
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
