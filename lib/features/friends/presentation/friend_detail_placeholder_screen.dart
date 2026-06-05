import 'package:flutter/material.dart';

/// Minimal placeholder for the friend-detail screen (SCR-11) that
/// FR-FR-04 will ship. Pushed when a row is tapped in
/// `FriendsListScreen` so the navigation contract is exercised
/// end-to-end and the AC-6 real-time test can walk
/// open → tap → back → real-time update.
///
/// **Intentionally minimal.** The screen does not display the raw
/// `friendshipId` (which would expose a PII-adjacent composite of two
/// UIDs in the UI) or any balance information. The neutral copy makes
/// it obvious to QA and design reviewers that the real screen has not
/// yet shipped.
///
/// Removal moment: replace this widget with the real `FriendDetailScreen`
/// in the FR-FR-04 PR. The call site in `FriendsListScreen.onRowTap`
/// stays the same; only the destination widget changes.
class FriendDetailPlaceholderScreen extends StatelessWidget {
  /// Creates a [FriendDetailPlaceholderScreen].
  const FriendDetailPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Friend')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.hourglass_empty,
                size: 64,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 16),
              Text(
                'Friend details coming soon',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Detailed expenses and settle-up actions will appear here.',
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
}
