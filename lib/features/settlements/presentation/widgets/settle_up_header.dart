import 'package:flutter/material.dart';

import 'package:onebytwo/core/formatters/inr_formatter.dart';

/// Header row of the Settle Up bottom sheet (SCR-23).
///
/// Renders the payer-on-the-left → arrow → payee-on-the-right
/// orientation with a centred "Suggested" amount echo. Inlined here
/// because the design-system catalogue's `OBTUserAvatar` /
/// `OBTBalancePill` components do not yet exist (per PR #42 Architect
/// Notes §6 inlining precedent).
class SettleUpHeader extends StatelessWidget {
  /// Creates a [SettleUpHeader].
  const SettleUpHeader({
    required this.payerDisplayName,
    required this.payerPhotoUrl,
    required this.payeeDisplayName,
    required this.payeePhotoUrl,
    required this.suggestedAmountPaise,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _AvatarColumn(
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
              _AvatarColumn(
                displayName: payeeDisplayName,
                photoUrl: payeePhotoUrl,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Suggested: ${formatInrFromPaise(suggestedAmountPaise)}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarColumn extends StatelessWidget {
  const _AvatarColumn({required this.displayName, required this.photoUrl});

  final String displayName;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
              ? NetworkImage(photoUrl!)
              : null,
          child: (photoUrl == null || photoUrl!.isEmpty)
              ? Text(_initials(displayName), style: theme.textTheme.titleMedium)
              : null,
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 96,
          child: Text(
            displayName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
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
