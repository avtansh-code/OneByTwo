import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/features/home/domain/monthly_spend_breakdown.dart';
import 'package:onebytwo/features/home/presentation/widgets/spending_category_palette.dart';

/// FR-HD-03 donut chart for the monthly category breakdown (SCR-06;
/// `fl_chart` per ADR-0017 section 5).
///
/// Geometry: 160 dp outer diameter, 28 dp ring thickness
/// (`radius`), ~52 dp centre-hole radius (`centerSpaceRadius`), and a
/// 2 dp gap drawn in the card `surface` colour so each arc is visually
/// bounded. One section per non-zero category (descending paise),
/// coloured via [spendingCategoryColor]. The centre shows the month
/// total via `formatInrFromPaise` with a "spent" caption.
///
/// **Invariant 1.** Each section's sweep is the **integer-paise ratio**
/// `categoryPaise / monthTotalPaise` — a derived geometry ratio, never a
/// `double` money value. The caller renders the chart only when
/// `monthTotalPaise > 0`, so the ratio never divides by zero.
///
/// **Accessibility.** The painted chart is decorative and wrapped in
/// [ExcludeSemantics]; meaning is carried by the card's donut-summary
/// node and the legend (SCR-06; SRS section 5.6).
class SpendingDonutChart extends StatelessWidget {
  /// Creates a [SpendingDonutChart] for [breakdown].
  const SpendingDonutChart({required this.breakdown, super.key});

  /// The populated breakdown to chart (`monthTotalPaise > 0`).
  final MonthlySpendBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final surface = theme.colorScheme.surface;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return ExcludeSemantics(
      child: SizedBox(
        height: 160,
        width: 160,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PieChart(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 300),
              PieChartData(
                startDegreeOffset: -90,
                sectionsSpace: 2,
                centerSpaceRadius: 52,
                pieTouchData: PieTouchData(enabled: false),
                sections: [
                  for (final spend in breakdown.categories)
                    PieChartSectionData(
                      value: spend.totalPaise / breakdown.monthTotalPaise,
                      color: spendingCategoryColor(spend.category, brightness),
                      radius: 28,
                      showTitle: false,
                      borderSide: BorderSide(width: 2, color: surface),
                    ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatInrFromPaise(breakdown.monthTotalPaise),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'spent',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
