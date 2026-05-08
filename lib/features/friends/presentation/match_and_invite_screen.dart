import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/features/friends/application/match_and_invite_controller.dart';

/// Screen that displays the match-and-invite flow after a contact
/// has been selected from the device picker.
class MatchAndInviteScreen extends ConsumerWidget {
  /// Creates a [MatchAndInviteScreen].
  const MatchAndInviteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(matchAndInviteControllerProvider);
    final controller = ref.read(matchAndInviteControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Friend')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: switch (state) {
          MatchAndInviteInitial() => const SizedBox.shrink(),
          MatchAndInviteLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
          MatchAndInviteMatchFound(:final displayName, :final photoUrl) =>
            _MatchFoundCard(
              displayName: displayName,
              photoUrl: photoUrl,
              onAddFriend: controller.addFriend,
            ),
          MatchAndInviteNoMatch(:final contactDisplayName) => _NoMatchCard(
            contactDisplayName: contactDisplayName,
            onSendInvite: controller.openInviteShareSheet,
          ),
          MatchAndInviteError(:final message) => _ErrorCard(
            message: message,
            onRetry: () => controller.performLookup(null),
          ),
          MatchAndInviteRateLimited() => const Center(
            child: Text('Please try again later'),
          ),
          MatchAndInviteSelfAddBlocked() => const Center(
            child: Text('You cannot add yourself as a friend'),
          ),
          MatchAndInviteDuplicateFriendship() => const Center(
            child: Text('You are already friends'),
          ),
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private widgets
// ---------------------------------------------------------------------------

class _MatchFoundCard extends StatelessWidget {
  const _MatchFoundCard({
    required this.displayName,
    required this.photoUrl,
    required this.onAddFriend,
  });

  final String displayName;
  final String? photoUrl;
  final VoidCallback onAddFriend;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (photoUrl != null)
            CircleAvatar(
              radius: 40,
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
              ),
            ),
          const SizedBox(height: 16),
          Text(displayName, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onAddFriend,
            child: const Text('Add as friend'),
          ),
        ],
      ),
    );
  }
}

class _NoMatchCard extends StatelessWidget {
  const _NoMatchCard({
    required this.contactDisplayName,
    required this.onSendInvite,
  });

  final String contactDisplayName;
  final VoidCallback onSendInvite;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            contactDisplayName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'is not on One By Two yet.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onSendInvite,
            child: const Text('Send invite'),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 16),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
