import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/settlements/application/settlement_history_provider.dart';
import 'package:onebytwo/features/settlements/application/settlement_history_telemetry.dart';
import 'package:onebytwo/features/settlements/domain/settlement_doc.dart';

/// Settlement History screen (SCR-24 / FR-SE-08).
///
/// Renders a reverse-chronological list of every settlement recorded
/// against a single context (a friendship or — in a future Sprint —
/// a group). The screen is generic over `(contextType, contextId)` so
/// the Sprint 3 Group Detail surface can push it with
/// `contextType: 'group'`; only the friendship arm is wired today.
///
/// State contract (per SCR-24 §States):
/// - Loading: a centred `CircularProgressIndicator`.
/// - Populated: a `ListView` of settlement rows ordered by `date`
///   descending (the repository stream guarantees the order; no
///   client-side sort).
/// - Empty: "No settlements yet" placeholder, no CTA.
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
/// - **Invariant 1 (paise)**: the per-row amount flows through
///   `formatInrFromPaise()`; no inline arithmetic.
/// - **Invariant 2 (`simplifiedBalances` read-only)**: this screen reads
///   only top-level `settlements/{id}` documents and never references
///   `simplifiedBalances`.
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

  /// Authenticated user UID — used to label the payer/payee avatars.
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
        title: Semantics(header: true, child: const Text('Settlement History')),
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
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: settlements.length,
      itemBuilder: (context, index) {
        final settlement = settlements[index];
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
    final dateText = DateFormat('dd MMM yyyy').format(settlement.date);
    final amountText = formatInrFromPaise(settlement.amountPaise);

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
        amountText: amountText,
        dateText: dateText,
      ),
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateText,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _InitialAvatar(label: payerLabel),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.arrow_forward,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    _InitialAvatar(label: payeeLabel),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            amountText,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (settlement.note != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              settlement.note!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
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
  /// glyph.
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
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CircleAvatar(
      radius: 16,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      child: Text(_initial(label), style: theme.textTheme.labelMedium),
    );
  }

  static String _initial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }
}

// ---------------------------------------------------------------------------
// Inline state widgets (per Architect Notes §2.3 — no OBT* primitive
// extraction; mirrors the friend_detail_states.dart precedent).
// ---------------------------------------------------------------------------

class _SettlementHistoryLoadingState extends StatelessWidget {
  const _SettlementHistoryLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _SettlementHistoryEmptyState extends StatelessWidget {
  const _SettlementHistoryEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.history,
                size: 64,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No settlements yet',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Once you settle up, it will appear here.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
