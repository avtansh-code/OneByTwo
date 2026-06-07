import 'package:flutter/material.dart';

/// Wraps an editable field with the FR-EX-06 changed-field indicator
/// when [isChanged] is true.
///
/// Visual: 2-px left border in `Theme.of(context).colorScheme.secondary`
/// (the design-system `secondary` / `#F4A261` token per
/// SCR-22 §Edit Flow line 449).
///
/// Semantics: a sibling `, changed.` label appended to the descendant
/// semantic tree (WCAG 1.4.1 — information not conveyed by colour
/// alone, per SCR-22 §Accessibility line 509).
///
/// When [isChanged] is false the widget returns [child] unchanged so
/// there is zero layout / semantic cost in create mode or for
/// unmodified fields.
class ChangedFieldIndicator extends StatelessWidget {
  /// Creates a [ChangedFieldIndicator].
  const ChangedFieldIndicator({
    required this.isChanged,
    required this.child,
    super.key,
  });

  /// Whether this field has been modified from its original value.
  final bool isChanged;

  /// The editable field widget to decorate.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!isChanged) return child;
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: theme.colorScheme.secondary, width: 2),
        ),
      ),
      padding: const EdgeInsetsDirectional.only(start: 8),
      child: Semantics(label: ', changed.', child: child),
    );
  }
}
