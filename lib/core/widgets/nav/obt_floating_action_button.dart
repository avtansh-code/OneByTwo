import 'package:flutter/material.dart';

/// Design-system primitive for the One By Two persistent Add-Expense
/// Floating Action Button. See `docs/design/02-design-system/components.md §3
/// OBTFloatingActionButton`.
///
/// **Visual contract:** circular FAB with `Icons.add`,
/// `backgroundColor: Theme.colorScheme.secondary` (Saffron/Marigold),
/// `foregroundColor: Colors.white`, tooltip + semantic label
/// `"Add new expense"`, tap target 56×56 dp, always-active on the
/// authenticated shell's primary tabs.
///
/// **Hero tag:** defaults to `'addExpenseFAB'`. Detail screens that
/// host their own FAB (e.g. `FriendDetailScreen`) MUST override the
/// tag (e.g. `'friendDetailFab'`) to avoid hero-collision when the
/// shell and the detail screen are both on the route stack.
///
/// **Spring physics:** the press scale-down + 200 ms spring release
/// described in `components.md §3 States` is deferred — Flutter's
/// default Material ink-response provides the baseline tap feedback
/// for v1.0.
class OBTFloatingActionButton extends StatelessWidget {
  /// Creates an [OBTFloatingActionButton].
  const OBTFloatingActionButton({
    required this.onPressed,
    this.heroTag = 'addExpenseFAB',
    super.key,
  });

  /// Tap handler. Invoked on every press.
  final VoidCallback onPressed;

  /// Hero animation tag. Defaults to `'addExpenseFAB'`; consumers that
  /// host a sibling FAB (e.g. `FriendDetailScreen`) MUST pass an
  /// explicit alternative to avoid a Hero-tag collision.
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FloatingActionButton(
      heroTag: heroTag,
      onPressed: onPressed,
      backgroundColor: colorScheme.secondary,
      foregroundColor: Colors.white,
      tooltip: 'Add new expense',
      child: const Icon(Icons.add, semanticLabel: 'Add new expense'),
    );
  }
}
