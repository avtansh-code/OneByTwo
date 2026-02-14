import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/auth_providers.dart';

/// Settings screen with sign out functionality
/// 
/// Displays:
/// - Account settings
/// - App preferences
/// - Sign out option
/// 
/// This is a basic implementation for Sprint 1 auth session management.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signOutNotifier = ref.watch(signOutProvider.notifier);
    final signOutState = ref.watch(signOutProvider);
    final deleteAccountNotifier = ref.watch(deleteAccountProvider.notifier);
    final deleteAccountState = ref.watch(deleteAccountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account section
          Text(
            'Account',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outlined),
                  title: const Text('Edit Profile'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO(profile): Navigate to profile edit
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profile edit coming soon'),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock_outlined),
                  title: const Text('Privacy'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO(privacy): Navigate to privacy settings
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Privacy settings coming soon'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // App section
          Text(
            'App',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Notifications'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO(notifications): Navigate to notification settings
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Notification settings coming soon'),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.language_outlined),
                  title: const Text('Language'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO(language): Navigate to language settings
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Language settings coming soon'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Sign out section
          Text(
            'Session',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.logout,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Sign Out',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              onTap: signOutState.isLoading
                  ? null
                  : () {
                      _showSignOutConfirmation(context, ref, signOutNotifier);
                    },
              trailing: signOutState.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 24),

          // Danger zone section
          Text(
            'Danger Zone',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Card(
            color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
            child: ListTile(
              leading: Icon(
                Icons.delete_forever,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Delete Account',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Permanently delete your account and all data',
              ),
              onTap: deleteAccountState.isLoading
                  ? null
                  : () {
                      _showDeleteAccountConfirmation(
                        context,
                        ref,
                        deleteAccountNotifier,
                      );
                    },
              trailing: deleteAccountState.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 24),

          // App info
          Center(
            child: Text(
              'One By Two v1.0.0',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountConfirmation(
    BuildContext context,
    WidgetRef ref,
    DeleteAccount deleteAccountNotifier,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) => _DeleteAccountDialog(
        onConfirm: () async {
          // Close the dialog
          Navigator.of(context).pop();
          
          // Perform deletion
          await deleteAccountNotifier.deleteAccount();
          
          // Check result
          final state = ref.read(deleteAccountProvider);
          if (context.mounted) {
            if (state.hasError) {
              // Show error
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Failed to delete account: ${state.error}',
                  ),
                  backgroundColor: Theme.of(context).colorScheme.error,
                  action: SnackBarAction(
                    label: 'Retry',
                    textColor: Colors.white,
                    onPressed: () {
                      _showDeleteAccountConfirmation(
                        context,
                        ref,
                        deleteAccountNotifier,
                      );
                    },
                  ),
                ),
              );
            }
            // If successful, navigation will happen automatically via auth state change
          }
        },
      ),
    );
  }

  void _showSignOutConfirmation(
    BuildContext context,
    WidgetRef ref,
    SignOut signOutNotifier,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out? '
          "You'll need to sign in again to access your account.",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await signOutNotifier.signOut();
              
              // Check if sign out was successful
              final state = ref.read(signOutProvider);
              if (context.mounted && state.hasError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Failed to sign out: ${state.error}',
                    ),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

/// Dialog for confirming account deletion
/// 
/// Implements multi-step confirmation:
/// 1. Warning about consequences
/// 2. User must type "DELETE" to confirm
/// 3. Final confirmation button
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({
    required this.onConfirm,
  });

  final VoidCallback onConfirm;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _confirmationController = TextEditingController();
  bool _canDelete = false;

  @override
  void initState() {
    super.initState();
    _confirmationController.addListener(_checkConfirmation);
  }

  @override
  void dispose() {
    _confirmationController.dispose();
    super.dispose();
  }

  void _checkConfirmation() {
    final text = _confirmationController.text.trim();
    setState(() {
      _canDelete = text == 'DELETE';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Icon(
        Icons.warning_amber_rounded,
        color: Theme.of(context).colorScheme.error,
        size: 48,
      ),
      title: const Text('Delete Account?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This action is permanent and cannot be undone. '
              'All your data will be deleted:',
            ),
            const SizedBox(height: 16),
            _buildDeleteItem(context, 'Your profile and account'),
            _buildDeleteItem(context, 'All groups and expenses'),
            _buildDeleteItem(context, 'All friend connections'),
            _buildDeleteItem(context, 'All settlements and history'),
            _buildDeleteItem(context, 'Uploaded images and files'),
            const SizedBox(height: 24),
            Text(
              'Type DELETE to confirm:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmationController,
              decoration: const InputDecoration(
                hintText: 'DELETE',
                border: OutlineInputBorder(),
              ),
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canDelete ? widget.onConfirm : null,
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          child: const Text('Delete Account'),
        ),
      ],
    );
  }

  Widget _buildDeleteItem(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.close,
            size: 16,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text),
          ),
        ],
      ),
    );
  }
}
