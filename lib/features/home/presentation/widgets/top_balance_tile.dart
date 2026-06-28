import 'package:flutter/material.dart';
import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/widgets/indicators/obt_balance_pill.dart';
import 'package:onebytwo/features/friends/domain/friend_list_item.dart';

/// A single row in the Home dashboard "Top Balances" section (SCR-06
/// Populated State, FR-HD-02).
///
/// Layout: avatar (or fallback initial) + a two-line identity block (the
/// display name over a `text-tertiary` directional subtitle — "owes you"
/// / "you owe" / "settled up") + a trailing column holding the one-line
/// [OBTBalancePill] (`[icon] [amount]`) above a compact marigold
/// "Settle Up" link (the Phase3b trailing block).
///
/// The colour + icon + label trio that survives greyscale and colour-blind
/// rendering is split per the Phase3b top-balance rows: the pill carries
/// the colour + directional icon (+ amount), the subtitle carries the
/// label (DC-05). The home tile is distinct from `FriendListTile` because
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
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;
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
                // Silently fall back to the initial.
              }
            : null,
        child: hasPhoto
            ? null
            : Text(fallbackInitial, style: theme.textTheme.titleMedium),
      ),
    );

    // The shared OBTBalancePill is the one-line `[icon] [amount]` signal;
    // the directional label lives in the identity subtitle below.
    final pill = OBTBalancePill(netBalancePaise: item.netBalancePaise);

    // The Settle Up affordance is a compact marigold-family text link (the
    // Haldi link token, AA on the warm surface), not a fill — matching the
    // Phase3b "Settle up" affordance. The 48 dp tap target is preserved via
    // minimumSize, but the label is top-aligned so it sits tight under the
    // pill (the handoff's 3 dp gap) while the hit area extends downward.
    final settleUp = Semantics(
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
            foregroundColor: obtColors.link,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.topCenter,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Settle Up'),
        ),
      ),
    );

    // The two-line identity: display name over the directional subtitle in
    // `text-tertiary` (the Phase3b row label moved out of the pill).
    final nameBlock = Column(
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

    return LayoutBuilder(
      builder: (context, constraints) {
        // Phase3b lays the row out as avatar + a two-line identity (name
        // over the directional subtitle) + a trailing column holding the
        // one-line pill above the compact "Settle up" link. Because the
        // one-line pill is narrow, this holds on a single row at typical
        // phone widths. It reflows to a stacked layout on very small frames
        // or at large dynamic-type scales, where the dense trailing column
        // would otherwise crowd the name out (04 section C.2 — the row may
        // grow); the amount always scales whole and never truncates.
        final scale = MediaQuery.textScalerOf(context).scale(16);
        final reflow = constraints.maxWidth < 300 || scale >= 26;

        // The tappable identity (avatar + name + subtitle) navigates to
        // Friend Detail. The pill is [ExcludeSemantics], so the colour-free
        // amount is announced through this label (Invariant 1).
        final identity = Semantics(
          button: true,
          label: _identitySemanticLabel(item),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  avatar,
                  const SizedBox(width: 16),
                  Expanded(child: nameBlock),
                ],
              ),
            ),
          ),
        );

        if (reflow) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                identity,
                const SizedBox(height: 8),
                pill,
                const SizedBox(height: 3),
                Align(alignment: Alignment.centerLeft, child: settleUp),
              ],
            ),
          );
        }

        // Single row: the trailing column stacks the pill over the compact
        // Settle Up link, right-aligned, per the Phase3b trailing block.
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(child: identity),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [pill, const SizedBox(height: 3), settleUp],
              ),
            ],
          ),
        );
      },
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

  /// The colour-independent identity label "<name>, <direction>, <amount>"
  /// (or "<name>, settled up" when zero). The pill is [ExcludeSemantics],
  /// so the navigable identity is where the amount is announced; the
  /// magnitude goes through `formatInrFromPaise()` (Invariant 1).
  String _identitySemanticLabel(FriendListItem item) {
    final direction = _directionLabel(item.netBalancePaise);
    if (item.netBalancePaise == 0) {
      return '${item.displayName}, $direction';
    }
    return '${item.displayName}, $direction, '
        '${formatInrFromPaise(item.netBalancePaise.abs())}';
  }
}
