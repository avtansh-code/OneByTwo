import 'package:flutter/material.dart';

import 'package:onebytwo/core/widgets/feedback/obt_empty_state.dart';

/// Empty state shown when no contacts are found in the device contact
/// picker (SCR-10 state 3 / Haldi 10), reskinned to `OBTEmptyState`
/// (DC-06).
class EmptyContactsState extends StatelessWidget {
  /// Creates an [EmptyContactsState].
  const EmptyContactsState({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return OBTEmptyState(
      illustration: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.contacts_outlined, size: 52, color: colors.primary),
      ),
      headline: 'No contacts found',
      supportingText: 'You can enter a number manually.',
    );
  }
}
