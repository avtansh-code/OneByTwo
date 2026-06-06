import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:onebytwo/features/expenses/domain/expense_category.dart';
import 'package:onebytwo/features/expenses/domain/split_calculator.dart';
import 'package:onebytwo/features/expenses/domain/split_method.dart';

/// Firestore-shaped expense document.
///
/// `toCreateMap()` produces the map that satisfies every predicate in
/// `firestore.rules` lines 153–302 — `hasAllRequiredKeys`,
/// `hasOnlyKnownKeys`, `isValidShape`, `isValidExtensionPointLocks`,
/// `areValidSplitElements`, and `sumOfSharesEquals`. The shape is
/// ratified in Architect Notes §2.4.
///
/// `recurringRule` is OMITTED per ARCH-EXT-03 (the rules accept absent
/// OR `null`; omitting is simpler). `source` is `'manual'` per
/// ARCH-EXT-07. `currency` is `'INR'` per ARCH-EXT-02.
@immutable
class ExpenseDoc {
  /// Creates an [ExpenseDoc].
  const ExpenseDoc({
    required this.amountPaise,
    required this.description,
    required this.category,
    required this.date,
    required this.payerId,
    required this.splits,
    required this.splitMethod,
    required this.createdBy,
  });

  /// Amount in paise (invariant 1).
  final int amountPaise;

  /// Trimmed description (1–100 chars; the client validator enforces;
  /// the rules permit up to 200 as the defence-in-depth floor).
  final String description;

  /// The selected category enum.
  final ExpenseCategory category;

  /// The user-picked expense date.
  final DateTime date;

  /// The payer's UID (must be one of the two friendship members).
  final String payerId;

  /// The two per-member splits (current-user-first ordering).
  final List<Split> splits;

  /// The split method.
  final SplitMethod splitMethod;

  /// The creator's UID (must equal `request.auth.uid` per the rules).
  final String createdBy;

  /// Serialises to the Firestore create-map shape ratified in
  /// Architect Notes §2.4. Every field aligns with the security rules
  /// at `firestore.rules` lines 167–273.
  Map<String, dynamic> toCreateMap() {
    return <String, dynamic>{
      'amountPaise': amountPaise,
      'description': description,
      'category': category.name,
      'date': Timestamp.fromDate(date),
      'payerId': payerId,
      'splits': <Map<String, dynamic>>[
        for (final split in splits)
          <String, dynamic>{
            'userId': split.userId,
            'sharePaise': split.sharePaise,
          },
      ],
      'splitMethod': splitMethod.name,
      'receiptUrl': null,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'deleted': false,
      'source': 'manual',
      'currency': 'INR',
    };
  }
}
