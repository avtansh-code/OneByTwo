import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/theme/obt_text.dart';

/// One donut/legend slice keyed on the Haldi palette [OBTCategory].
@immutable
class OBTCategorySlice {
  /// Creates an [OBTCategorySlice].
  const OBTCategorySlice({required this.category, required this.totalPaise});

  /// The palette category driving the hue.
  final OBTCategory category;

  /// The category subtotal in integer paise.
  final int totalPaise;
}

/// User-facing labels for the Haldi palette categories.
const Map<OBTCategory, String> obtCategoryLabel = <OBTCategory, String>{
  OBTCategory.food: 'Food',
  OBTCategory.transport: 'Transport',
  OBTCategory.groceries: 'Groceries',
  OBTCategory.entertainment: 'Entertainment',
  OBTCategory.rent: 'Rent',
  OBTCategory.utilities: 'Utilities',
  OBTCategory.shopping: 'Shopping',
  OBTCategory.other: 'Other',
};

/// Glyph per Haldi palette category.
const Map<OBTCategory, IconData> obtCategoryIcon = <OBTCategory, IconData>{
  OBTCategory.food: Icons.restaurant,
  OBTCategory.transport: Icons.directions_car,
  OBTCategory.groceries: Icons.local_grocery_store,
  OBTCategory.entertainment: Icons.movie,
  OBTCategory.rent: Icons.home,
  OBTCategory.utilities: Icons.bolt,
  OBTCategory.shopping: Icons.shopping_bag,
  OBTCategory.other: Icons.more_horiz,
};

/// Monthly-spend donut (foundation plan section 4.2 #9; reskin of the
/// FR-HD-03 chart to the Haldi 8-hue).
///
/// One section per slice, coloured via [OBTColors.categoryColor]; the
/// centre shows the month total in Bricolage tabular. The caller renders
/// only when `monthTotalPaise > 0`.
///
/// **Invariant 1.** Each section's sweep is the integer-paise ratio
/// `slice.totalPaise / monthTotalPaise` — a derived geometry ratio, never
/// a float money value; the centre total is [formatInrFromPaise]. The
/// painted ring is decorative ([ExcludeSemantics]); the summary node and
/// the [OBTCategoryLegend] carry the meaning.
class OBTSpendingDonut extends StatelessWidget {
  /// Creates an [OBTSpendingDonut].
  const OBTSpendingDonut({
    required this.slices,
    required this.monthTotalPaise,
    super.key,
  });

  /// The non-zero category slices (descending paise).
  final List<OBTCategorySlice> slices;

  /// The month total in integer paise (`> 0`).
  final int monthTotalPaise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;
    final surface = theme.colorScheme.surface;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Semantics(
      container: true,
      label: _summaryLabel(slices, monthTotalPaise),
      child: ExcludeSemantics(
        child: SizedBox(
          height: 160,
          width: 160,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              PieChart(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                PieChartData(
                  startDegreeOffset: -90,
                  sectionsSpace: 2,
                  centerSpaceRadius: 52,
                  pieTouchData: PieTouchData(enabled: false),
                  sections: <PieChartSectionData>[
                    for (final slice in slices)
                      PieChartSectionData(
                        value: slice.totalPaise / monthTotalPaise,
                        color: obtColors.categoryColor(slice.category),
                        radius: 28,
                        showTitle: false,
                        borderSide: BorderSide(width: 2, color: surface),
                      ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    formatInrFromPaise(monthTotalPaise),
                    style: OBTText.amount(context),
                  ),
                  Text(
                    'spent',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: OBTColors.metaText(theme),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The donut's six-category legend (foundation plan section 4.2 #9).
///
/// One row per slice: a hue swatch + category icon + label + rupee
/// subtotal + integer percentage. Each row is announced as a single
/// label so no meaning is colour-only (swatch + icon + label + value).
class OBTCategoryLegend extends StatelessWidget {
  /// Creates an [OBTCategoryLegend].
  const OBTCategoryLegend({
    required this.slices,
    required this.monthTotalPaise,
    super.key,
  });

  /// The non-zero category slices (descending paise).
  final List<OBTCategorySlice> slices;

  /// The month total in integer paise (`> 0`).
  final int monthTotalPaise;

  @override
  Widget build(BuildContext context) {
    final percents = _allocatePercentages(slices, monthTotalPaise);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < slices.length; i++)
          _LegendRow(slice: slices[i], percent: percents[i]),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.slice, required this.percent});

  final OBTCategorySlice slice;
  final int percent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;
    final swatch = obtColors.categoryColor(slice.category);
    final label = obtCategoryLabel[slice.category]!;

    return Semantics(
      container: true,
      label:
          '$label, ${formatInrFromPaise(slice.totalPaise)}, '
          '$percent per cent',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: <Widget>[
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: swatch,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              obtCategoryIcon[slice.category],
              size: 20,
              color: theme.colorScheme.onSurface,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
            Text(
              formatInrFromPaise(slice.totalPaise),
              style: OBTText.amount(context),
            ),
            const SizedBox(width: 8),
            Text(
              '$percent%',
              style: theme.textTheme.labelSmall?.copyWith(
                color: OBTColors.metaText(theme),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The donut's accessible alternative summary line.
String _summaryLabel(List<OBTCategorySlice> slices, int monthTotalPaise) {
  final count = slices.length;
  final noun = count == 1 ? 'category' : 'categories';
  final total = formatInrFromPaise(monthTotalPaise);
  return 'This month you have spent $total across $count $noun';
}

/// Allocates a whole-number percentage to each slice such that the set
/// sums to exactly 100, using the largest-remainder method (pure integer
/// arithmetic over the category paise — Invariant 1, a derived ratio, not
/// money). The caller renders only when `monthTotalPaise > 0`.
List<int> _allocatePercentages(
  List<OBTCategorySlice> slices,
  int monthTotalPaise,
) {
  final percents = <int>[];
  final remainders = <int>[];
  var allocated = 0;
  for (final slice in slices) {
    final scaled = slice.totalPaise * 100;
    final floor = scaled ~/ monthTotalPaise;
    percents.add(floor);
    remainders.add(scaled % monthTotalPaise);
    allocated += floor;
  }
  final order = <int>[for (var i = 0; i < slices.length; i++) i]
    ..sort((a, b) {
      final byRemainder = remainders[b].compareTo(remainders[a]);
      if (byRemainder != 0) return byRemainder;
      return a.compareTo(b);
    });
  var leftover = 100 - allocated;
  for (final i in order) {
    if (leftover <= 0) break;
    percents[i] += 1;
    leftover -= 1;
  }
  return List<int>.unmodifiable(percents);
}
