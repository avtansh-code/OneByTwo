import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:onebytwo/features/expenses/domain/expense_category.dart';
import 'package:onebytwo/features/expenses/domain/split_calculator.dart';
import 'package:onebytwo/features/expenses/domain/split_method.dart';

// Re-export Split so callers (UI, tests) that only import
// `expense_doc.dart` can construct shares without a second import.
export 'package:onebytwo/features/expenses/domain/split_calculator.dart'
    show Split;

/// Firestore-shaped expense document.
///
/// `toCreateMap()` produces the map that satisfies every predicate in
/// `firestore.rules` lines 153–302 — `hasAllRequiredKeys`,
/// `hasOnlyKnownKeys`, `isValidShape`, `isValidExtensionPointLocks`,
/// `areValidSplitElements`, and `sumOfSharesEquals`. The shape is
/// ratified in Architect Notes §2.4.
///
/// `toUpdateMap(changedFields)` (FR-EX-06 architect §2.3) emits only
/// the changed keys plus `updatedAt: serverTimestamp()`. The
/// `createdBy` + `createdAt` immutability invariant per
/// `firestore.rules` lines 281-282 is preserved by construction: the
/// update map NEVER includes either field.
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
    this.id,
    this.receiptUrl,
  });

  // -------------------------------------------------------------------
  // Field-name constants — referenced from `toUpdateMap` and from the
  // controller's `changedFields` set. Defined once so a typo cannot
  // diverge the diff from the update map (architect §2.3).
  // -------------------------------------------------------------------

  /// Firestore field key for [amountPaise].
  static const String fieldAmountPaise = 'amountPaise';

  /// Firestore field key for [description].
  static const String fieldDescription = 'description';

  /// Firestore field key for [category].
  static const String fieldCategory = 'category';

  /// Firestore field key for [date].
  static const String fieldDate = 'date';

  /// Firestore field key for [payerId].
  static const String fieldPayerId = 'payerId';

  /// Firestore field key for [splits].
  static const String fieldSplits = 'splits';

  /// Firestore field key for [splitMethod].
  static const String fieldSplitMethod = 'splitMethod';

  /// Firestore field key for [receiptUrl] (FR-EX-05).
  static const String fieldReceiptUrl = 'receiptUrl';

  /// Document ID. `null` when constructed via the create flow; populated
  /// when read from Firestore via [fromMap].
  final String? id;

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

  /// Optional receipt download URL (FR-EX-05). `null` when the
  /// expense has no receipt attached. Populated on read via
  /// [fromMap] and written on create / update via [toCreateMap] /
  /// [toUpdateMap].
  final String? receiptUrl;

  /// Serialises to the Firestore create-map shape ratified in
  /// Architect Notes §2.4. Every field aligns with the security rules
  /// at `firestore.rules` lines 167–273.
  Map<String, dynamic> toCreateMap() {
    return <String, dynamic>{
      fieldAmountPaise: amountPaise,
      fieldDescription: description,
      fieldCategory: category.name,
      fieldDate: Timestamp.fromDate(date),
      fieldPayerId: payerId,
      fieldSplits: <Map<String, dynamic>>[
        for (final split in splits)
          <String, dynamic>{
            'userId': split.userId,
            'sharePaise': split.sharePaise,
          },
      ],
      fieldSplitMethod: splitMethod.name,
      fieldReceiptUrl: receiptUrl,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'deleted': false,
      'source': 'manual',
      'currency': 'INR',
    };
  }

  /// Emits ONLY the changed keys + `updatedAt: serverTimestamp()`.
  ///
  /// Suitable for `DocumentReference.update(...)` — Firestore merges
  /// the partial map onto the existing document; the rules at
  /// `firestore.rules` lines 275-302 validate the merged result.
  /// `createdBy` and `createdAt` are NEVER emitted (immutability per
  /// `firestore.rules` lines 281-282). `currency` and `source` are
  /// extension-point-locked per `isValidExtensionPointLocks` and are
  /// likewise never included.
  Map<String, dynamic> toUpdateMap(Set<String> changedFields) {
    final map = <String, dynamic>{};
    if (changedFields.contains(fieldAmountPaise)) {
      map[fieldAmountPaise] = amountPaise;
    }
    if (changedFields.contains(fieldDescription)) {
      map[fieldDescription] = description;
    }
    if (changedFields.contains(fieldCategory)) {
      map[fieldCategory] = category.name;
    }
    if (changedFields.contains(fieldDate)) {
      map[fieldDate] = Timestamp.fromDate(date);
    }
    if (changedFields.contains(fieldPayerId)) {
      map[fieldPayerId] = payerId;
    }
    if (changedFields.contains(fieldSplits)) {
      map[fieldSplits] = <Map<String, dynamic>>[
        for (final split in splits)
          <String, dynamic>{
            'userId': split.userId,
            'sharePaise': split.sharePaise,
          },
      ];
    }
    if (changedFields.contains(fieldSplitMethod)) {
      map[fieldSplitMethod] = splitMethod.name;
    }
    if (changedFields.contains(fieldReceiptUrl)) {
      map[fieldReceiptUrl] = receiptUrl;
    }
    // Always refresh updatedAt — the rules at firestore.rules:283
    // require `data.updatedAt == request.time`.
    map['updatedAt'] = FieldValue.serverTimestamp();
    return map;
  }

  /// Parses a Firestore document snapshot into an [ExpenseDoc].
  ///
  /// Returns `null` on malformed / missing fields. Extracted from
  /// `FirestoreExpenseStore._parseExpense` so the read-side stream
  /// and the new single-doc fetch in `expense_detail_provider.dart`
  /// share the same parser (architect §2.9 item 6). The `(id, data)`
  /// shape adapts cleanly to either a `QueryDocumentSnapshot` or a
  /// `DocumentSnapshot` (both expose `id` + `data()`).
  static ExpenseDoc? fromMap(String id, Map<String, dynamic> data) {
    final amountPaise = data[fieldAmountPaise];
    final description = data[fieldDescription];
    final categoryName = data[fieldCategory];
    final dateRaw = data[fieldDate];
    final payerId = data[fieldPayerId];
    final splitsRaw = data[fieldSplits];
    final splitMethodName = data[fieldSplitMethod];
    final createdBy = data['createdBy'];

    if (amountPaise is! int ||
        description is! String ||
        categoryName is! String ||
        payerId is! String ||
        splitsRaw is! List ||
        splitMethodName is! String ||
        createdBy is! String) {
      return null;
    }

    DateTime? date;
    if (dateRaw is Timestamp) {
      date = dateRaw.toDate();
    } else if (dateRaw is DateTime) {
      date = dateRaw;
    } else {
      return null;
    }

    final category = ExpenseCategory.values.firstWhere(
      (c) => c.name == categoryName,
      orElse: () => ExpenseCategory.other,
    );

    final splitMethod = SplitMethod.values.firstWhere(
      (m) => m.name == splitMethodName,
      orElse: () => SplitMethod.equal,
    );

    final splits = <Split>[];
    for (final raw in splitsRaw) {
      if (raw is! Map) return null;
      final userId = raw['userId'];
      final sharePaise = raw['sharePaise'];
      if (userId is! String || sharePaise is! int) return null;
      splits.add(Split(userId: userId, sharePaise: sharePaise));
    }

    // FR-EX-05: parse the optional receipt URL. Tolerate missing /
    // null / non-string by treating as no receipt — the field is
    // optional and a malformed entry should not break the doc read.
    final receiptUrlRaw = data[fieldReceiptUrl];
    final receiptUrl = receiptUrlRaw is String ? receiptUrlRaw : null;

    return ExpenseDoc(
      id: id,
      amountPaise: amountPaise,
      description: description,
      category: category,
      date: date,
      payerId: payerId,
      splits: splits,
      splitMethod: splitMethod,
      createdBy: createdBy,
      receiptUrl: receiptUrl,
    );
  }
}
