import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/features/expenses/domain/expense_create_error.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';

// Re-export the typed error from the domain layer so callers may
// import either path. The architect notes group the error type with
// the repository file; the domain location is the canonical
// definition.
export 'package:onebytwo/features/expenses/domain/expense_create_error.dart';

/// Repository contract for the expense feature. The controller depends
/// on this interface; production code uses the Firestore-backed impl
/// (added in a follow-up commit), tests inject a fake.
///
/// The repository is the sole client-side producer of writes to the
/// `friendships/{fid}/expenses/{eid}` subcollection. It MUST NOT touch
/// `simplifiedBalances` — that field is server-maintained
/// (invariant 2).
// ignore: one_member_abstracts
abstract class ExpenseRepository {
  /// Creates an expense document under the given friendship and
  /// returns the auto-generated document ID. Throws an
  /// [ExpenseCreateError] on any failure; the controller catches
  /// that typed error and classifies the user experience.
  Future<String> createExpense({
    required String friendshipId,
    required ExpenseDoc doc,
  });
}

/// Provider override-point. The production binding lives in
/// `data/firestore_expense_repository.dart` (added in a follow-up
/// commit); tests override this provider with a fake.
final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  throw UnimplementedError(
    'expenseRepositoryProvider must be overridden; the production '
    'Firestore binding lands in a follow-up commit.',
  );
});
