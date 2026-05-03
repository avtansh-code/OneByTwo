import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/friends/presentation/contact_picker_screen.dart';

/// Placeholder friends list screen (FR-FR-03).
///
/// Displays the user's friends with an add-friend action in the app
/// bar. This is a placeholder implementation that will be fleshed out
/// in a subsequent task.
class FriendsListScreen extends ConsumerWidget {
  /// Creates a [FriendsListScreen].
  const FriendsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add friend',
            onPressed: () => _onAddFriendTapped(context, ref),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.people_outline,
                size: 64,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 16),
              Text(
                'No friends yet',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Add a friend and start sharing expenses.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onAddFriendTapped(BuildContext context, WidgetRef ref) {
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(name: 'friend_add_button_tapped'),
    );
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const ContactPickerScreen()),
    );
  }
}
