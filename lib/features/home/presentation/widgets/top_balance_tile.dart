import 'package:flutter/material.dart';
import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/widgets/indicators/obt_balance_pill.dart';
import 'package:onebytwo/features/friends/domain/friend_list_item.dart';

/// A single row in the Home dashboard "Top Balances" section (SCR-06
/// Populated State, FR-HD-02).
///
/// Layout: avatar (or fallback initial) + display name + trailing
/// [OBTBalancePill] + a compact marigold "Settle Up" button.
///
/// Uses the shared [OBTBalancePill] (the colour + icon + label trio) for
/// the trailing balance, with the "owes you" positive label, so the
/// direction survives greyscale and colour-blind rendering (DC-05). The
/// home tile is distinct from `FriendListTile` because it carries the
/// per-row "Settle Up" action the friends list does not.
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

    // The shared OBTBalancePill carries the colour + icon + label trio, so
    // the balance signal survives greyscale and colour-blind rendering.
    final pill = OBTBalancePill(
      netBalancePaise: item.netBalancePaise,
      positiveLabelOverride: 'owes you',
    );

    // The Settle Up affordance is a compact marigold-family text link (the
    // Haldi link token, AA on the warm surface), not a fill — matching the
    // Phase3b "Settle up" affordance. The 48 dp tap target is preserved via
    // minimumSize even though the visual is a small link.
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
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Settle Up'),
        ),
      ),
    );

    final nameText = Text(
      item.displayName,
      style: theme.textTheme.titleMedium,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // The shared pill (colour + icon + label + 16 dp tabular amount) is
        // wide; on narrow widths or at large dynamic-type scales the dense
        // single row cannot hold avatar + name + pill + action without
        // clipping, so it reflows to a stacked layout where the amount
        // wraps whole and never truncates (04 section C.2 — the row may
        // grow). Wide layouts (tablets) keep the compact single row.
        final scale = MediaQuery.textScalerOf(context).scale(16);
        final reflow = constraints.maxWidth < 460 || scale >= 22;

        // The tappable identity (avatar + name) navigates to Friend Detail.
        // In the compact single row it also carries the inline pill.
        final identity = Semantics(
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
                  avatar,
                  const SizedBox(width: 16),
                  Expanded(child: nameText),
                  if (!reflow) ...[const SizedBox(width: 12), pill],
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
                const SizedBox(height: 4),
                Align(alignment: Alignment.centerLeft, child: settleUp),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(child: identity),
              const SizedBox(width: 4),
              settleUp,
            ],
          ),
        );
      },
    );
  }

  String _pillSemanticLabel(int netBalancePaise) {
    if (netBalancePaise > 0) return 'owes you';
    if (netBalancePaise < 0) return 'you owe';
    return 'settled up';
  }
}
