import 'package:flutter/material.dart';

import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/theme/obt_text.dart';
import 'package:onebytwo/features/friends/application/friend_detail_provider.dart';

/// Header rendered at the top of the Friend Detail screen (SCR-11 /
/// Haldi 11), reskinned to the Haldi visual system (DC-06).
///
/// Layout (top to bottom):
/// - Centred avatar (80 dp; falls back to the initial when no photo).
/// - Display name as a title (Bricolage via the Haldi `titleLarge`).
/// - The inline hero balance line — `[icon] "<name> owes you ₹amount"` —
///   below the name, in the balance hue (Phase3c friend detail, line
///   ~196). This is NOT a pill: it is one line of hero text whose icon +
///   colour + phrasing carry the direction, so the signal survives
///   greyscale and colour-blind rendering.
///
/// The hero line is `maxLines: 1, softWrap: false` inside a [FittedBox]
/// ([BoxFit.scaleDown]) so a long name + amount scales DOWN to fit rather
/// than wrapping or truncating. All paise -> INR conversion goes through
/// `formatInrFromPaise()`; no inline rupee arithmetic (Invariant 1). The
/// balance is a read-only `simplifiedBalances` projection (Invariant 2).
class FriendDetailHeaderWidget extends StatelessWidget {
  /// Creates a [FriendDetailHeaderWidget].
  const FriendDetailHeaderWidget({required this.header, super.key});

  /// The resolved header projection from the provider.
  final FriendDetailHeader header;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;
    final fallbackInitial = header.displayName.isNotEmpty
        ? header.displayName[0].toUpperCase()
        : '?';
    final hasPhoto = header.photoUrl != null && header.photoUrl!.isNotEmpty;

    final Color hue;
    final IconData icon;
    final String balanceText;
    final amount = formatInrFromPaise(header.netBalancePaise.abs());
    if (header.netBalancePaise > 0) {
      hue = obtColors.balancePositive;
      icon = Icons.arrow_upward;
      balanceText = '${header.displayName} owes you $amount';
    } else if (header.netBalancePaise < 0) {
      hue = obtColors.balanceNegative;
      icon = Icons.arrow_downward;
      balanceText = 'You owe ${header.displayName} $amount';
    } else {
      hue = obtColors.balanceZero;
      icon = Icons.check;
      balanceText = "You're all settled up";
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ExcludeSemantics(
            child: CircleAvatar(
              radius: 40,
              backgroundImage: hasPhoto ? NetworkImage(header.photoUrl!) : null,
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
          const SizedBox(height: 8),
          // Inline hero balance: `[icon] "<name> owes you ₹amount"` on one
          // line, in the balance hue. Scales down (never wraps/truncates).
          Semantics(
            label: balanceText,
            excludeSemantics: true,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, size: 18, color: hue),
                  const SizedBox(width: 6),
                  Text(
                    balanceText,
                    style: OBTText.amount(context).copyWith(color: hue),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
