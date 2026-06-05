import 'package:flutter/material.dart';
import 'package:onebytwo/features/friends/domain/friend_list_item.dart';
import 'package:onebytwo/features/friends/presentation/widgets/balance_pill.dart';

/// A single row in the friends list (SCR-09 component 16).
///
/// Displays the friend's avatar (or a fallback initial), their display
/// name, and a trailing `BalancePill` derived from the
/// `netBalancePaise` field on [item].
///
/// Tap handling is delegated to [onTap]; the parent screen owns the
/// telemetry and navigation contract.
class FriendListTile extends StatelessWidget {
  /// Creates a [FriendListTile].
  const FriendListTile({required this.item, required this.onTap, super.key});

  /// The projected friend item from the friends-list provider.
  final FriendListItem item;

  /// Tap handler. Invoked when the tile is activated.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallbackInitial = item.displayName.isNotEmpty
        ? item.displayName[0].toUpperCase()
        : '?';
    final hasPhoto = item.photoUrl != null && item.photoUrl!.isNotEmpty;
    return Semantics(
      button: true,
      label: '${item.displayName}, ${_pillSemanticLabel(item.netBalancePaise)}',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                          // Silently fall back to the initial — the
                          // network failure is recoverable and the
                          // initial is already the placeholder.
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
    );
  }

  String _pillSemanticLabel(int netBalancePaise) {
    if (netBalancePaise > 0) return 'owes you';
    if (netBalancePaise < 0) return 'you owe';
    return 'settled up';
  }
}
