import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/core/providers/firebase_providers.dart'
    show firebaseFirestoreProvider;
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';

/// Argument tuple for [expenseDetailProvider]. Keyed on friendship +
/// expense id; equality + hashCode make the family cache stable when
/// the same screen is opened twice with the same arguments.
@immutable
class ExpenseDetailArgs {
  /// Creates an [ExpenseDetailArgs].
  const ExpenseDetailArgs({
    required this.friendshipId,
    required this.expenseId,
  });

  /// The friendship document ID.
  final String friendshipId;

  /// The expense document ID under
  /// `friendships/{friendshipId}/expenses/{expenseId}`.
  final String expenseId;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExpenseDetailArgs &&
        other.friendshipId == friendshipId &&
        other.expenseId == expenseId;
  }

  @override
  int get hashCode => Object.hash(friendshipId, expenseId);
}

/// Fetches a single expense document via `.get()` (one-shot, no
/// stream — the detail screen does not need live updates because the
/// edit and delete flows invalidate this provider explicitly).
///
/// Returns `null` when the document does not exist OR when its data
/// cannot be parsed by [ExpenseDoc.fromMap] (the same defensive null
/// the timeline stream uses).
///
/// The widget invalidates this family on Retry tap to force a fresh
/// fetch; the family is keyed by [ExpenseDetailArgs] so two parallel
/// detail screens for different expenses don't share state.
final expenseDetailProvider = FutureProvider.autoDispose
    .family<ExpenseDoc?, ExpenseDetailArgs>((ref, args) async {
      final firestore = ref.watch(firebaseFirestoreProvider);
      final snap = await firestore
          .collection('friendships')
          .doc(args.friendshipId)
          .collection('expenses')
          .doc(args.expenseId)
          .get();
      if (!snap.exists) return null;
      final data = snap.data();
      if (data == null) return null;
      return ExpenseDoc.fromMap(snap.id, data);
    });
