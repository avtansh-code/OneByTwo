import 'package:flutter/material.dart';

import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/features/friends/application/friend_detail_provider.dart';

/// Header rendered at the top of the Friend Detail screen (SCR-11).
///
/// Layout (top to bottom):
/// - Centred avatar (80 dp; falls back to the initial when no photo).
/// - Display name as a title.
/// - Balance pill below the name, colour-coded per [FriendDetailHeader.balanceState].
///
/// All paise → INR conversion goes through [formatInrFromPaise]; no
/// inline rupee arithmetic (Invariant 1).
class FriendDetailHeaderWidget extends StatelessWidget {
  /// Creates a [FriendDetailHeaderWidget].
  const FriendDetailHeaderWidget({required this.header, super.key});

  /// The resolved header projection from the provider.
  final FriendDetailHeader header;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallbackInitial = header.displayName.isNotEmpty
        ? header.displayName[0].toUpperCase()
        : '?';
    final hasPhoto =
        header.photoUrl != null && header.photoUrl!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: CircleAvatar(
              radius: 40,
              backgroundImage:
                  hasPhoto ? NetworkImage(header.photoUrl!) : null,
              onBackgroundImageError: hasPhoto
                  ? (Object _, StackTrace? __) {
                      // Silently fall back; the initial is the placeholder.
                    }
                  : null,
              child: hasPhoto
                  ? null
                  : Text(
                      fallbackInitial,
                      style: theme.textTheme.headlineMedium,
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            header.displayName,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          _FriendDetailBalancePill(
            netBalancePaise: header.netBalancePaise,
            balanceState: header.balanceState,
          ),
        ],
      ),
    );
  }
}

/// Large balance pill for the Friend Detail header (SCR-11 component 4
/// large variant).
///
/// Distinct from `lib/features/friends/presentation/widgets/balance_pill.dart`
/// (the friends-list trailing pill) because the SCR-11 large variant
/// has different copy ("You are owed ₹X.XX" vs "owes you ₹X.XX") and a
/// different layout (centred, larger type). When a third use site
/// appears, both pills will fold into `OBTBalancePill`.
class _FriendDetailBalancePill extends StatelessWidget {
  const _FriendDetailBalancePill({
    required this.netBalancePaise,
    required this.balanceState,
  });

  final int netBalancePaise;
  final BalanceState balanceState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final Color background;
    final Color foreground;
    final String label;

    switch (balanceState) {
      case BalanceState.owed:
        background = colors.tertiaryContainer;
        foreground = colors.onTertiaryContainer;
        label = 'You are owed ${formatInrFromPaise(netBalancePaise)}';
      case BalanceState.owes:
        background = colors.errorContainer;
        foreground = colors.onErrorContainer;
        label = 'You owe ${formatInrFromPaise(netBalancePaise)}';
      case BalanceState.settled:
        background = colors.surfaceContainerHighest;
        foreground = colors.onSurfaceVariant;
        label = 'Settled up';
    }

    return Semantics(
      label: 'Balance: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
