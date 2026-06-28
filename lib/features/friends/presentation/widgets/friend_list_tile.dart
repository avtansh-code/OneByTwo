import 'package:flutter/material.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/widgets/indicators/obt_balance_pill.dart';
import 'package:onebytwo/features/friends/domain/friend_list_item.dart';

/// A single row in the friends list (SCR-09 / Haldi 9), reskinned to the
/// Haldi visual system (DC-06).
///
/// Layout: a soft rounded surface card holding the friend's avatar (or a
/// fallback initial), a two-line identity block (the display name over a
/// `text-tertiary` directional subtitle — "owes you" / "you owe" /
/// "settled up"), and a trailing one-line [OBTBalancePill] showing the
/// `[icon] [amount]` derived from the signed `netBalancePaise` projection
/// on [item].
///
/// The colour + icon + label trio that survives greyscale and colour-blind
/// rendering is split per the Phase3c friend rows: the pill carries the
/// colour + directional icon (+ amount), the subtitle carries the label.
/// Because the one-line pill is narrow, the dense single row holds at
/// typical widths; it only reflows to a stacked layout at very narrow
/// frames or large (>= 2.0x) dynamic-type scales so the identity keeps its
/// full width (04 section C.2).
///
/// All paise -> INR conversion goes through `formatInrFromPaise()` (the
/// pill amount and the row's accessibility label; Invariant 1); the
/// balance is a read-only `simplifiedBalances` projection (Invariant 2).
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

    // The two-line identity: display name over the directional subtitle in
    // `text-tertiary` (the Phase3c row label moved out of the pill).
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          item.displayName,
          style: theme.textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          _directionLabel(item.netBalancePaise),
          style: theme.textTheme.bodySmall?.copyWith(
            color: OBTColors.metaText(theme),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    // The shared pill is now the one-line `[icon] [amount]` signal; the
    // directional label lives in the subtitle above.
    final pill = OBTBalancePill(netBalancePaise: item.netBalancePaise);

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
          label: _rowSemanticLabel(item),
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
                    // The one-line pill is narrow, so the single row holds
                    // at typical widths. It only reflows to a stacked
                    // layout at very narrow frames or >= 2.0x dynamic type,
                    // where the identity needs the full width (04 §C.2).
                    final scale = MediaQuery.textScalerOf(context).scale(16);
                    final reflow = constraints.maxWidth < 260 || scale >= 32;

                    if (reflow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              avatar,
                              const SizedBox(width: 14),
                              Expanded(child: identity),
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
                        Expanded(child: identity),
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

  /// The directional subtitle / label for the row (also the colour-free
  /// accessibility direction): "owes you" (the friend owes the current
  /// user), "you owe", or "settled up".
  String _directionLabel(int netBalancePaise) {
    if (netBalancePaise > 0) return 'owes you';
    if (netBalancePaise < 0) return 'you owe';
    return 'settled up';
  }

  /// The colour-independent row label "<name>, <direction>, <amount>" (or
  /// "<name>, settled up" when zero). The pill itself is [ExcludeSemantics],
  /// so this is where the amount is announced; the magnitude goes through
  /// `formatInrFromPaise()` (Invariant 1).
  String _rowSemanticLabel(FriendListItem item) {
    final direction = _directionLabel(item.netBalancePaise);
    if (item.netBalancePaise == 0) {
      return '${item.displayName}, $direction';
    }
    return '${item.displayName}, $direction, '
        '${formatInrFromPaise(item.netBalancePaise.abs())}';
  }
}
