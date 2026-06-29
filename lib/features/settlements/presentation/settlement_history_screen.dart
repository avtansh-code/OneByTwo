import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/core/formatters/ist_date_formatter.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/theme/obt_text.dart';
import 'package:onebytwo/core/widgets/feedback/obt_empty_state.dart';
import 'package:onebytwo/core/widgets/feedback/obt_skeleton.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/settlements/application/settlement_history_provider.dart';
import 'package:onebytwo/features/settlements/application/settlement_history_telemetry.dart';
import 'package:onebytwo/features/settlements/domain/settlement_doc.dart';

/// Settlement History screen (SCR-24 / FR-SE-08; Haldi 24, DC-08 reskin).
///
/// Renders a reverse-chronological list of every settlement recorded
/// against a single context (a friendship or — in a future Sprint —
/// a group). The screen is generic over `(contextType, contextId)` so
/// the Sprint 3 Group Detail surface can push it with
/// `contextType: 'group'`; only the friendship arm is wired today.
///
/// State contract (per SCR-24 §States, Haldi-converted):
/// - Loading: the shimmer `OBTSkeleton` set (skeletons, not spinners).
/// - Populated: a lazy `ListView.builder` of settlement rows ordered by
///   `date` descending (the repository stream guarantees the order; no
///   client-side sort). Each row carries a **sent/received direction icon
///   + signed amount** derived from `fromUserId`/`toUserId` vs the current
///   user (DC-08 AC-3) — never a recomputed balance.
/// - Empty: the shared `OBTEmptyState` scaffold, no CTA.
/// - Error: "Something went wrong" placeholder with a Retry button.
///
/// Telemetry (both events pre-declared in `telemetry-plan.md` §1.3):
/// - `settlement_history_viewed { context_type, item_count }` fires
///   exactly once on the first resolved frame.
/// - `settlement_history_error { error_code, context_type }` fires
///   exactly once on the first error frame.
///
/// PII guard (ADR-0013): neither event carries `context_id` — for the
/// friendship axis the `contextId` is a UID-composite that must not be
/// emitted raw.
///
/// Invariant compliance:
/// - **Invariant 1 (paise)**: every per-row amount flows through
///   `formatInrFromPaise()`; the sign glyph is the only addition and there
///   is no inline `/100` or `double` arithmetic.
/// - **Invariant 2 (`simplifiedBalances` read-only)**: this screen reads
///   only top-level `settlements/{id}` documents and never references
///   `simplifiedBalances`; the direction sign is derived from the
///   settlement document, not from any recomputed balance.
class SettlementHistoryScreen extends ConsumerStatefulWidget {
  /// Creates a [SettlementHistoryScreen].
  const SettlementHistoryScreen({
    required this.contextType,
    required this.contextId,
    required this.currentUserUid,
    required this.otherUserUid,
    required this.otherDisplayName,
    super.key,
  });

  /// One of `'friendship'` or `'group'`.
  final String contextType;

  /// The friendship or group document ID this history is scoped to.
  final String contextId;

  /// Authenticated user UID — used to derive the per-row direction.
  final String currentUserUid;

  /// The other party UID.
  final String otherUserUid;

  /// The other party display name — interpolated into the row labels.
  final String otherDisplayName;

  @override
  ConsumerState<SettlementHistoryScreen> createState() =>
      _SettlementHistoryScreenState();
}

class _SettlementHistoryScreenState
    extends ConsumerState<SettlementHistoryScreen> {
  bool _loggedView = false;
  bool _loggedError = false;

  SettlementHistoryArgs get _args => SettlementHistoryArgs(
    contextType: widget.contextType,
    contextId: widget.contextId,
  );

  @override
  Widget build(BuildContext context) {
    final settlementsAsync = ref.watch(settlementHistoryProvider(_args));

    return Scaffold(
      appBar: AppBar(
        title: Semantics(header: true, child: const Text('Settlements')),
      ),
      body: settlementsAsync.when(
        loading: () => const _SettlementHistoryLoadingState(),
        error: (error, _) {
          _logErrorOnce(error);
          return _SettlementHistoryErrorState(
            onRetry: () => ref.invalidate(settlementHistoryProvider(_args)),
          );
        },
        data: (settlements) {
          _logViewedOnce(settlements.length);
          if (settlements.isEmpty) {
            return const _SettlementHistoryEmptyState();
          }
          return _SettlementHistoryList(
            settlements: settlements,
            currentUserUid: widget.currentUserUid,
            otherDisplayName: widget.otherDisplayName,
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Telemetry helpers
  // -------------------------------------------------------------------------

  void _logViewedOnce(int itemCount) {
    if (_loggedView) return;
    _loggedView = true;
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: SettlementHistoryTelemetry.viewedEvent,
            parameters: <String, Object>{
              SettlementHistoryTelemetry.paramContextType: widget.contextType,
              SettlementHistoryTelemetry.paramItemCount: itemCount,
            },
          ),
    );
  }

  void _logErrorOnce(Object error) {
    if (_loggedError) return;
    _loggedError = true;
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: SettlementHistoryTelemetry.errorEvent,
            parameters: <String, Object>{
              SettlementHistoryTelemetry.paramErrorCode: _errorCode(error),
              SettlementHistoryTelemetry.paramContextType: widget.contextType,
            },
          ),
    );
  }

  /// Maps a stream error to a safe, non-PII `error_code` token per
  /// Architect Notes §2.8: the raw `FirebaseException.code`
  /// (`'permission-denied'` / `'unavailable'` / other) or `'unknown'`
  /// for any non-Firebase error.
  String _errorCode(Object error) {
    if (error is FirebaseException) {
      return error.code;
    }
    return 'unknown';
  }
}

// ---------------------------------------------------------------------------
// Populated list + row
// ---------------------------------------------------------------------------

class _SettlementHistoryList extends StatelessWidget {
  const _SettlementHistoryList({
    required this.settlements,
    required this.currentUserUid,
    required this.otherDisplayName,
  });

  final List<SettlementDoc> settlements;
  final String currentUserUid;
  final String otherDisplayName;

  @override
  Widget build(BuildContext context) {
    // Flatten the date-ordered settlements into a list interleaving IST
    // month-group overline headers (e.g. "JUNE 2026") with their rows, so a
    // lazy ListView keeps the SCR-24 month grouping (Haldi 24).
    final items = <_HistoryItem>[];
    String? currentMonth;
    for (final settlement in settlements) {
      final month = formatIstMonthYear(settlement.date);
      if (month != currentMonth) {
        currentMonth = month;
        items.add(_MonthHeaderItem(month));
      }
      items.add(_SettlementRowItem(settlement));
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is _MonthHeaderItem) {
          return _MonthHeader(label: item.label);
        }
        final settlement = (item as _SettlementRowItem).settlement;
        return _SettlementHistoryRow(
          key: ValueKey<String>(
            'settlement_history_row_${settlement.settlementId}',
          ),
          settlement: settlement,
          currentUserUid: currentUserUid,
          otherDisplayName: otherDisplayName,
        );
      },
    );
  }
}

/// A flattened settlement-history entry: a month header or a settlement row.
sealed class _HistoryItem {
  const _HistoryItem();
}

class _MonthHeaderItem extends _HistoryItem {
  const _MonthHeaderItem(this.label);
  final String label;
}

class _SettlementRowItem extends _HistoryItem {
  const _SettlementRowItem(this.settlement);
  final SettlementDoc settlement;
}

/// The IST month-group overline header (SCR-24 / Haldi 24).
class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
      child: Semantics(
        header: true,
        child: Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 0.8,
            fontWeight: FontWeight.w700,
            color: OBTColors.metaText(theme),
          ),
        ),
      ),
    );
  }
}

class _SettlementHistoryRow extends StatelessWidget {
  const _SettlementHistoryRow({
    required this.settlement,
    required this.currentUserUid,
    required this.otherDisplayName,
    super.key,
  });

  final SettlementDoc settlement;
  final String currentUserUid;
  final String otherDisplayName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;
    final dateText = formatIstLongDate(settlement.date);

    // Direction is derived from the settlement document (Invariant 2 — never
    // a recomputed balance): incoming = the friend paid the current user.
    final isIncoming = settlement.toUserId == currentUserUid;
    final amountHue = isIncoming
        ? obtColors.balancePositive
        : obtColors.balanceNegative;
    // The sign glyph is the only addition to the formatter output; the rupee
    // conversion stays inside formatInrFromPaise() (Invariant 1). Outgoing
    // payments use formatInrFromPaise(-amount) so the Unicode minus prefix is
    // produced by the single formatter, never inline arithmetic.
    final signedAmountText = isIncoming
        ? '+${formatInrFromPaise(settlement.amountPaise)}'
        : formatInrFromPaise(-settlement.amountPaise);
    final friendFirstName = _firstName(otherDisplayName);
    final title = isIncoming
        ? '$friendFirstName paid you'
        : 'You paid $friendFirstName';

    // The semantic label keeps the full, unsigned descriptive sentence so a
    // screen reader announces the transaction once, regardless of the visual
    // sign glyph (SCR-24 §Accessibility).
    final payerLabel = settlement.fromUserId == currentUserUid
        ? 'You'
        : otherDisplayName;
    final payeeLabel = settlement.toUserId == currentUserUid
        ? 'You'
        : otherDisplayName;

    return Semantics(
      container: true,
      label: _semanticLabel(
        payerLabel: payerLabel,
        payeeLabel: payeeLabel,
        amountText: formatInrFromPaise(settlement.amountPaise),
        dateText: dateText,
      ),
      child: ExcludeSemantics(
        child: Container(
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 8),
          constraints: const BoxConstraints(minHeight: 64),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            boxShadow: obtColors.rowShadow,
            border: theme.brightness == Brightness.dark
                ? Border.all(color: theme.colorScheme.outline)
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            child: Row(
              children: [
                _DirectionIconTile(isIncoming: isIncoming, hue: amountHue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateText,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: OBTColors.metaText(theme),
                        ),
                      ),
                      if (settlement.note != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          settlement.note!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: OBTColors.metaText(theme),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // The signed amount must never truncate; it shares the row
                // with the title via flex and scales down only at extreme
                // text scales / narrow widths (so it stays whole — Inv 1).
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      signedAmountText,
                      style: OBTText.amount(context).copyWith(color: amountHue),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the screen-reader label per SCR-24 §Accessibility:
  /// `<payer> paid <payee> rupees <amount> on <date>. Note: <note or
  /// no note>.` The spoken amount strips the leading currency symbol
  /// so the screen reader announces "rupees 800.00" rather than the
  /// glyph, and uses the unsigned amount for natural speech.
  String _semanticLabel({
    required String payerLabel,
    required String payeeLabel,
    required String amountText,
    required String dateText,
  }) {
    final spokenAmount = amountText.replaceAll('₹', '');
    final noteClause = settlement.note ?? 'no note';
    return '$payerLabel paid $payeeLabel rupees $spokenAmount on '
        '$dateText. Note: $noteClause.';
  }

  static String _firstName(String full) {
    final trimmed = full.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed.split(RegExp(r'\s+')).first;
  }
}

/// The Haldi leading tile for a settlement row: a rounded square holding a
/// directional glyph on a ~12%-opacity bed of [hue], the glyph itself in the
/// full [hue]. Purely decorative — the row owns the textual label, so this
/// tile is [ExcludeSemantics].
class _DirectionIconTile extends StatelessWidget {
  const _DirectionIconTile({required this.isIncoming, required this.hue});

  final bool isIncoming;
  final Color hue;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: hue.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        // Received money points inward (south-west); sent money points
        // outward (north-east).
        child: Icon(
          isIncoming ? Icons.south_west : Icons.north_east,
          size: 20,
          color: hue,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Inline state widgets (per Architect Notes §2.3 — no OBT* primitive
// extraction beyond the shared DC-03 set).
// ---------------------------------------------------------------------------

/// Shimmer loading skeleton for the settlement-history list. Freezes under
/// reduced motion via the shared `OBTSkeleton` set (skeletons, not spinners).
class _SettlementHistoryLoadingState extends StatelessWidget {
  const _SettlementHistoryLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: OBTSkeletonList(itemCount: 6),
    );
  }
}

class _SettlementHistoryEmptyState extends StatelessWidget {
  const _SettlementHistoryEmptyState();

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
        child: Icon(Icons.history, size: 52, color: colors.primary),
      ),
      headline: 'No settlements yet',
      supportingText: 'Once you settle up, it will appear here.',
    );
  }
}

class _SettlementHistoryErrorState extends StatelessWidget {
  const _SettlementHistoryErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'We could not load settlement history. Please try again.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: OBTColors.metaText(theme),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
