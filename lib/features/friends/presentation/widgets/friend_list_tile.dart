import 'package:flutter/material.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/widgets/indicators/obt_balance_pill.dart';
import 'package:onebytwo/features/friends/domain/friend_list_item.dart';

/// A single row in the friends list (SCR-09 / Haldi 9), reskinned to the
/// Haldi visual system (DC-06).
///
/// Layout: a soft rounded surface card holding the friend's avatar (or a
/// fallback initial), their display name, and a trailing shared
/// [OBTBalancePill] (the colour + icon + label trio) derived from the
/// signed `netBalancePaise` projection on [item].
///
/// The pill carries the directional icon + label so the balance signal
/// survives greyscale and colour-blind rendering. Because the shared pill
/// is wide (~187 dp with the 16 dp tabular amount), the dense row reflows
/// to a stacked layout at narrow widths or large dynamic-type scales so
/// the amount never truncates (04 section C.2).
///
/// All paise -> INR conversion goes through `formatInrFromPaise()` inside
/// the pill (Invariant 1); the balance is a read-only `simplifiedBalances`
/// projection (Invariant 2).
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
    final colors = theme.colorScheme;
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;
    final isDark = theme.brightness == Brightness.dark;

    final fallbackInitial = item.displayName.isNotEmpty
        ? item.displayName[0].toUpperCase()
        : '?';
    final hasPhoto = item.photoUrl != null && item.photoUrl!.isNotEmpty;

    final avatar = ExcludeSemantics(
      child: CircleAvatar(
        radius: 22,
        backgroundImage: hasPhoto ? NetworkImage(item.photoUrl!) : null,
        onBackgroundImageError: hasPhoto
            ? (Object _, StackTrace? __) {
                // Silently fall back to the initial — the network failure
                // is recoverable and the initial is already the placeholder.
              }
            : null,
        child: hasPhoto
            ? null
            : Text(fallbackInitial, style: theme.textTheme.titleMedium),
      ),
    );

    final nameText = Text(
      item.displayName,
      style: theme.textTheme.titleMedium,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    // The shared pill carries the colour + icon + label trio; "owes you"
    // is the friend-row positive label (the friend owes the current user).
    final pill = OBTBalancePill(
      netBalancePaise: item.netBalancePaise,
      positiveLabelOverride: 'owes you',
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          boxShadow: obtColors.rowShadow,
          border: isDark ? Border.all(color: colors.outline) : null,
        ),
        child: Semantics(
          button: true,
          label:
              '${item.displayName}, '
              '${_pillSemanticLabel(item.netBalancePaise)}',
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 11,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // The ~187 dp pill plus the avatar leaves the name too
                    // little room on narrow frames / at large text scales,
                    // so the dense row reflows to a stacked layout where the
                    // amount wraps whole and never truncates (04 section C.2).
                    final scale = MediaQuery.textScalerOf(context).scale(16);
                    final reflow = constraints.maxWidth < 320 || scale >= 22;

                    if (reflow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              avatar,
                              const SizedBox(width: 14),
                              Expanded(child: nameText),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(alignment: Alignment.centerLeft, child: pill),
                        ],
                      );
                    }

                    return Row(
                      children: <Widget>[
                        avatar,
                        const SizedBox(width: 14),
                        Expanded(child: nameText),
                        const SizedBox(width: 12),
                        pill,
                      ],
                    );
                  },
                ),
              ),
            ),
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
