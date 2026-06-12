import 'package:flutter/material.dart';

/// FR-HD-03 (P1) "This Month" spending-breakdown placeholder card
/// (SCR-06 Populated State, "Category Breakdown Section").
///
/// v1.0 ships ONLY this placeholder — the real donut/bar chart is
/// deferred to a separate P1 PR because it needs a charting dependency
/// and a category-aggregation read path (out of scope here; no charting
/// plugin is added). The card is non-interactive: no tap handler, no
/// navigation, no pressed state (SCR-06 Edge Case 5).
class SpendingBreakdownPlaceholderCard extends StatelessWidget {
  /// Creates a [SpendingBreakdownPlaceholderCard].
  const SpendingBreakdownPlaceholderCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'Monthly spending breakdown, coming soon',
      child: ExcludeSemantics(
        child: Card(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: SizedBox(
            height: 160,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.pie_chart_outline,
                    size: 40,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Spending breakdown coming soon',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
