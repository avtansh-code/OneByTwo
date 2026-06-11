import 'package:flutter/material.dart';

/// Placeholder content for the Groups tab (index 2 of
/// [AuthenticatedShell]).
///
/// `lib/features/groups/` is greenfield (no real screens ship before
/// the Sprint 3 Groups epic). This placeholder is the shell's
/// stand-in so the bottom-nav tab cluster is complete and the user
/// understands the feature is on the roadmap.
///
/// The widget is colocated with the shell (architect §2.5) so the
/// Sprint 3 Groups epic can delete this file and replace the
/// AuthenticatedShell's tab-2 entry with the real
/// `GroupsListScreen` in a single focused PR.
class GroupsListPlaceholder extends StatelessWidget {
  /// Creates the Groups tab placeholder.
  const GroupsListPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.groups_outlined,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text('Groups', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Coming in Sprint 3 — group expense splitting and '
                  'shared balances.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
