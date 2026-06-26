import 'package:flutter/material.dart';

import 'package:onebytwo/core/widgets/indicators/obt_balance_pill.dart';
import 'package:onebytwo/features/friends/application/friend_detail_provider.dart';

/// Header rendered at the top of the Friend Detail screen (SCR-11 /
/// Haldi 11), reskinned to the Haldi visual system (DC-06).
///
/// Layout (top to bottom):
/// - Centred avatar (80 dp; falls back to the initial when no photo).
/// - Display name as a title (Bricolage via the Haldi `titleLarge`).
/// - The shared [OBTBalancePill] (large form) below the name, carrying the
///   balance trio (colour + icon + label) derived from the signed
///   `netBalancePaise` projection.
///
/// All paise -> INR conversion goes through `formatInrFromPaise()` inside
/// the pill; no inline rupee arithmetic (Invariant 1). The balance is a
/// read-only `simplifiedBalances` projection (Invariant 2).
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
    final hasPhoto = header.photoUrl != null && header.photoUrl!.isNotEmpty;

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
          const SizedBox(height: 12),
          OBTBalancePill(netBalancePaise: header.netBalancePaise),
        ],
      ),
    );
  }
}
