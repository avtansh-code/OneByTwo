import 'package:flutter/material.dart';
import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/features/friends/domain/friend_list_item.dart';
import 'package:onebytwo/features/friends/presentation/widgets/balance_pill.dart';

/// A single row in the Home dashboard "Top Balances" section (SCR-06
/// Populated State, FR-HD-02).
///
/// Layout: avatar (or fallback initial) + display name + trailing
/// [BalancePill] + a compact "Settle Up" text button.
///
/// Reuses the friends-feature [BalancePill] verbatim (the home feature
/// already composes the friends domain — `friendsListProvider` and
/// `FriendListItem` — so reusing the pill avoids duplicating the
/// balance-direction logic without a premature `OBTBalancePill`
/// extraction). The home tile is distinct from `FriendListTile` because
/// it carries the per-row "Settle Up" action the friends list does not.
///
/// Tap handling is delegated: [onTap] navigates to Friend Detail,
/// [onSettleUp] opens the Settle Up flow. The parent screen owns the
/// telemetry and navigation contract.
///
/// All paise → INR conversion goes through [formatInrFromPaise]
/// (invariant 1).
class TopBalanceTile extends StatelessWidget {
  /// Creates a [TopBalanceTile].
  const TopBalanceTile({
    required this.item,
    required this.onTap,
    required this.onSettleUp,
    super.key,
  });

  /// The projected friend item (non-zero balance, from
  /// `topBalancesProvider`).
  final FriendListItem item;

  /// Invoked when the tile body is activated (navigate to Friend Detail).
  final VoidCallback onTap;

  /// Invoked when the "Settle Up" button is activated.
  final VoidCallback onSettleUp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallbackInitial = item.displayName.isNotEmpty
        ? item.displayName[0].toUpperCase()
        : '?';
    final hasPhoto = item.photoUrl != null && item.photoUrl!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label:
                  '${item.displayName}, '
                  '${_pillSemanticLabel(item.netBalancePaise)}',
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      ExcludeSemantics(
                        child: CircleAvatar(
                          radius: 22,
                          backgroundImage: hasPhoto
                              ? NetworkImage(item.photoUrl!)
                              : null,
                          onBackgroundImageError: hasPhoto
                              ? (Object _, StackTrace? __) {
                                  // Silently fall back to the initial.
                                }
                              : null,
                          child: hasPhoto
                              ? null
                              : Text(
                                  fallbackInitial,
                                  style: theme.textTheme.titleMedium,
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          item.displayName,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      BalancePill(netBalancePaise: item.netBalancePaise),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Semantics(
            button: true,
            onTap: onSettleUp,
            label:
                'Settle up with ${item.displayName}, '
                'rupees ${formatInrFromPaise(item.netBalancePaise.abs())}',
            child: ExcludeSemantics(
              child: TextButton(
                onPressed: onSettleUp,
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  foregroundColor: theme.colorScheme.primary,
                ),
                child: const Text('Settle Up'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _pillSemanticLabel(int netBalancePaise) {
    if (netBalancePaise > 0) return 'owes you';
    if (netBalancePaise < 0) return 'you owe';
    return 'settled up';
  }
}
