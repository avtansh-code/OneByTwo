import 'package:flutter/material.dart';

import 'package:onebytwo/core/formatters/inr_formatter.dart';

/// Settle Up CTA card (FR-SE-07 / SCR-23 / design-system §13).
///
/// Renders a payer-avatar → arrow → payee-avatar row with a centred
/// suggested amount and a Settle Up call-to-action. Hosts:
/// - Friend Detail screen (FR-SE-05 / PR #43 — this PR's wired call site)
/// - Home Dashboard (FR-HD-02 — deferred; planned future use site)
/// - Group Detail (FR-GR-04 — deferred; planned future use site)
///
/// Architectural placement (Architect Notes §2.6): the widget lives
/// under `lib/features/friends/presentation/widgets/` for PR #43
/// because the only wired host is `FriendDetailScreen`. When the Home
/// Dashboard ships, that PR will lift this widget into a shared
/// design-system folder (`lib/core/widgets/cards/`) per the
/// `OBTAmountInput` extraction precedent from PR #38.
///
/// Invariant compliance:
/// - **Invariant 1 (paise)**: [suggestedAmountPaise] is `int`; display
///   uses `formatInrFromPaise()`. No inline `/100` math.
/// - **Invariant 2 (`simplifiedBalances` read-only)**: this widget is
///   presentational and never touches Firestore.
class OBTSettleUpCard extends StatelessWidget {
  /// Creates an [OBTSettleUpCard].
  const OBTSettleUpCard({
    required this.payerDisplayName,
    required this.payerPhotoUrl,
    required this.payeeDisplayName,
    required this.payeePhotoUrl,
    required this.suggestedAmountPaise,
    required this.onSettleUp,
    super.key,
  });

  /// Display name of the payer (the user who pays the settlement).
  final String payerDisplayName;

  /// Avatar URL of the payer (nullable).
  final String? payerPhotoUrl;

  /// Display name of the payee (the user who receives the settlement).
  final String payeeDisplayName;

  /// Avatar URL of the payee (nullable).
  final String? payeePhotoUrl;

  /// The simplified-debts suggestion amount in paise.
  final int suggestedAmountPaise;

  /// Fires when the user taps the Settle Up CTA. The host is
  /// responsible for opening the Settle Up bottom sheet (or
  /// equivalent) and for firing the `settle_up_tapped` telemetry
  /// event.
  final VoidCallback onSettleUp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AvatarLabel(
                  displayName: payerDisplayName,
                  photoUrl: payerPhotoUrl,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.arrow_forward,
                    color: theme.colorScheme.primary,
                    semanticLabel: 'pays',
                  ),
                ),
                _AvatarLabel(
                  displayName: payeeDisplayName,
                  photoUrl: payeePhotoUrl,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              formatInrFromPaise(suggestedAmountPaise),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onSettleUp,
                icon: const Icon(Icons.handshake_outlined),
                label: const Text('Settle Up'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarLabel extends StatelessWidget {
  const _AvatarLabel({required this.displayName, required this.photoUrl});

  final String displayName;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: theme.colorScheme.surface,
          backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
              ? NetworkImage(photoUrl!)
              : null,
          child: (photoUrl == null || photoUrl!.isEmpty)
              ? Text(_initials(displayName), style: theme.textTheme.titleSmall)
              : null,
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 80,
          child: Text(
            displayName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  static String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}
