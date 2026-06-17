import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/expenses/domain/expense_category.dart';
import 'package:onebytwo/features/home/application/home_telemetry.dart';
import 'package:onebytwo/features/home/application/monthly_spend_breakdown_provider.dart';
import 'package:onebytwo/features/home/domain/monthly_spend_breakdown.dart';
import 'package:onebytwo/features/home/presentation/widgets/spending_category_palette.dart';
import 'package:onebytwo/features/home/presentation/widgets/spending_donut_chart.dart';
import 'package:onebytwo/features/profile/application/contact_support_controller.dart';
import 'package:onebytwo/features/profile/presentation/contact_support_fallback_dialog.dart';

/// FR-HD-03 "This Month" spend-breakdown card (SCR-06 Populated State),
/// replacing the v1.0 spending-breakdown placeholder card.
///
/// A `ConsumerStatefulWidget` so it can own the single-fire telemetry
/// gate (`home_spending_breakdown_viewed`) on its own terminal sub-state,
/// which has a separate data lifecycle from the balances axis that drives
/// `home_viewed` (ADR-0017 section 7).
///
/// Watches [monthlySpendBreakdownProvider] and renders four sub-states:
/// - **loading** — a chart-shaped skeleton (no telemetry);
/// - **empty** (`monthTotalPaise == 0`) — "No spending yet this month",
///   no chart;
/// - **populated** — the [SpendingDonutChart] plus a vertical legend and
///   the month total; and
/// - **error** — a message, Retry (invalidates the provider), and a
///   Contact Support link reusing the FR-PR-05 `ContactSupportController`
///   with `HD-FIRESTORE-READ` (no telemetry).
///
/// The card is non-interactive in its populated/empty sub-states (no
/// per-segment drill-down, SCR-06 Edge Case 5).
///
/// **Invariants.** Integer paise throughout, rupees only via
/// `formatInrFromPaise` (Invariant 1); reads `expenses` only, never
/// `simplifiedBalances` (Invariant 2 N/A).
class SpendingBreakdownCard extends ConsumerStatefulWidget {
  /// Creates a [SpendingBreakdownCard].
  const SpendingBreakdownCard({super.key});

  @override
  ConsumerState<SpendingBreakdownCard> createState() =>
      _SpendingBreakdownCardState();
}

class _SpendingBreakdownCardState extends ConsumerState<SpendingBreakdownCard> {
  bool _loggedBreakdownView = false;

  @override
  Widget build(BuildContext context) {
    final breakdownAsync = ref.watch(monthlySpendBreakdownProvider);
    return breakdownAsync.when(
      loading: () => const _BreakdownSkeleton(),
      error: (error, stack) => _BreakdownErrorBody(
        onRetry: _onRetry,
        onContactSupport: _onContactSupport,
      ),
      data: (breakdown) {
        _logBreakdownViewOnce(breakdown.categories.length);
        if (breakdown.isEmpty) {
          return const _BreakdownEmptyBody();
        }
        return _BreakdownPopulatedBody(breakdown: breakdown);
      },
    );
  }

  void _logBreakdownViewOnce(int categoryCount) {
    if (_loggedBreakdownView) return;
    _loggedBreakdownView = true;
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: HomeTelemetry.spendingBreakdownViewed,
            parameters: <String, Object>{
              HomeTelemetry.paramCategoryCount: categoryCount,
            },
          ),
    );
  }

  void _onRetry() {
    ref.invalidate(monthlySpendBreakdownProvider);
  }

  Future<void> _onContactSupport() async {
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: HomeTelemetry.errorSupportTapped,
            parameters: <String, Object>{
              HomeTelemetry.paramErrorCode:
                  HomeTelemetry.errorCodeFirestoreRead,
            },
          ),
    );
    final result = await ref
        .read(contactSupportControllerProvider)
        .contactSupport();
    if (!mounted) return;
    if (result is ContactSupportFallbackRequired) {
      await ContactSupportFallbackDialog.show(
        context,
        supportEmailAddress: result.supportEmailAddress,
      );
    }
  }
}

/// Shared card frame: `surface`, 24 dp corner, `elevationLow`, 16 dp
/// internal padding (SCR-06).
class _BreakdownCardFrame extends StatelessWidget {
  const _BreakdownCardFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

/// Loading sub-state: a 160 dp chart skeleton plus three bar lines,
/// reusing the dashboard skeleton discipline (SCR-06 Loading State).
class _BreakdownSkeleton extends StatelessWidget {
  const _BreakdownSkeleton();

  @override
  Widget build(BuildContext context) {
    final box = Theme.of(context).colorScheme.surfaceContainerHighest;
    return _BreakdownCardFrame(
      child: Semantics(
        liveRegion: true,
        label: 'Loading content',
        child: Column(
          key: const Key('spending_breakdown_skeleton'),
          children: [
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(color: box, shape: BoxShape.circle),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: box,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Empty / zero-spend sub-state (`monthTotalPaise == 0`): no chart, an
/// encouraging message (SCR-06; SRS section 6.5).
class _BreakdownEmptyBody extends StatelessWidget {
  const _BreakdownEmptyBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _BreakdownCardFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.insights_outlined,
              size: 40,
              color: theme.colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No spending yet this month',
            style: theme.textTheme.titleSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Add an expense to see your monthly breakdown',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Populated sub-state: the donut summary plus a one-column legend
/// (SCR-06; AC-10..AC-14).
class _BreakdownPopulatedBody extends StatelessWidget {
  const _BreakdownPopulatedBody({required this.breakdown});

  final MonthlySpendBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    return _BreakdownCardFrame(
      child: Column(
        children: [
          Center(
            child: Semantics(
              container: true,
              label: _summaryLabel(breakdown),
              child: SpendingDonutChart(breakdown: breakdown),
            ),
          ),
          const SizedBox(height: 16),
          for (final spend in breakdown.categories)
            _LegendRow(
              spend: spend,
              percent: _percent(spend.totalPaise, breakdown.monthTotalPaise),
            ),
        ],
      ),
    );
  }
}

/// One legend row: colour swatch + category icon + label + rupee
/// subtotal + percentage. Announced as a single Semantics label so no
/// information is conveyed by colour alone (SCR-06; SRS section 5.6).
class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.spend, required this.percent});

  final CategorySpend spend;
  final int percent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final swatch = spendingCategoryColor(spend.category, theme.brightness);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Semantics(
      container: true,
      label:
          '${expenseCategoryLabel[spend.category]}, '
          '${formatInrFromPaise(spend.totalPaise)}, '
          '$percent per cent',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
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
              expenseCategoryIcon[spend.category],
              size: 20,
              color: theme.colorScheme.onSurface,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                expenseCategoryLabel[spend.category]!,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Text(
              formatInrFromPaise(spend.totalPaise),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(width: 8),
            Text(
              '$percent%',
              style: theme.textTheme.labelSmall?.copyWith(color: muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error sub-state: a message, a Retry affordance, and a Contact Support
/// link reusing the FR-PR-05 path with `HD-FIRESTORE-READ` (SCR-06 Error
/// State; AC-9). Telemetry never fires here (AC-17).
class _BreakdownErrorBody extends StatelessWidget {
  const _BreakdownErrorBody({
    required this.onRetry,
    required this.onContactSupport,
  });

  final VoidCallback onRetry;
  final VoidCallback onContactSupport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _BreakdownCardFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.error_outline,
              size: 40,
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "We couldn't load your spending breakdown.",
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
          const SizedBox(height: 4),
          TextButton(
            onPressed: onContactSupport,
            child: const Text('Contact Support'),
          ),
          const SizedBox(height: 4),
          Text(
            'Error code: ${HomeTelemetry.errorCodeFirestoreRead}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// The donut's accessible alternative — "This month you have spent
/// {total} across {N} categories" — using the singular "category" when
/// there is exactly one (SCR-06 Accessibility; AC-14).
String _summaryLabel(MonthlySpendBreakdown breakdown) {
  final count = breakdown.categories.length;
  final noun = count == 1 ? 'category' : 'categories';
  final total = formatInrFromPaise(breakdown.monthTotalPaise);
  return 'This month you have spent $total across $count $noun';
}

/// Integer-rounded `categoryPaise * 100 / monthTotalPaise` (a derived
/// ratio, not money; Invariant 1). The caller renders the legend only
/// when `monthTotalPaise > 0`.
int _percent(int categoryPaise, int monthTotalPaise) {
  return (categoryPaise * 100 / monthTotalPaise).round();
}
