import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/features/settlements/data/settlement_repository.dart';
import 'package:onebytwo/features/settlements/domain/settlement_doc.dart';

/// Maximum number of settlement rows the history screen renders for
/// v1.0. Enforced at the provider layer per the SCR-24 §Edge Cases
/// item 1 fallback (no "Load more" footer). Defer cursor-based
/// pagination until there is evidence of contexts exceeding this cap.
const int settlementHistoryItemCap = 50;

/// Family argument tuple that scopes a single settlement-history query.
///
/// The `(contextType, contextId)` pair fully scopes the underlying
/// `SettlementRepository.watchByContext` read. `currentUserUid`,
/// `otherUserUid`, and `otherDisplayName` are NOT part of the family
/// key — they are presentation-only and threaded through the screen
/// constructor, so two screens viewing the same context share one
/// subscription.
@immutable
class SettlementHistoryArgs {
  /// Creates a [SettlementHistoryArgs].
  const SettlementHistoryArgs({
    required this.contextType,
    required this.contextId,
  });

  /// One of `'friendship'` or `'group'`.
  final String contextType;

  /// The friendship or group document ID this history is scoped to.
  final String contextId;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SettlementHistoryArgs &&
        other.contextType == contextType &&
        other.contextId == contextId;
  }

  @override
  int get hashCode => Object.hash(contextType, contextId);
}

/// Family-keyed stream of the most recent settlements for a context,
/// ordered by `date` descending (FR-SE-08 / SCR-24).
///
/// Reuses the PR #42 read path `SettlementRepository.watchByContext`
/// verbatim (soft-deleted entries are already excluded at the
/// repository layer) and applies the [settlementHistoryItemCap] over
/// the projected list. No `dependencies:` override is needed: the
/// repository is a root-scope provider with no per-arm override.
///
/// **Invariant 2 (`simplifiedBalances` server-maintained).** This
/// provider reads only top-level `settlements/{id}` documents; it never
/// references `simplifiedBalances`.
final settlementHistoryProvider =
    StreamProvider.family<List<SettlementDoc>, SettlementHistoryArgs>((
      ref,
      args,
    ) {
      final repository = ref.watch(settlementRepositoryProvider);
      return repository
          .watchByContext(
            contextType: args.contextType,
            contextId: args.contextId,
          )
          .map(
            (settlements) => settlements
                .take(settlementHistoryItemCap)
                .toList(growable: false),
          );
    });
