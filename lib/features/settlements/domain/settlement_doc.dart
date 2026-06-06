import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Immutable value type representing a `settlements/{settlementId}`
/// document as read from Firestore.
///
/// The shape mirrors the canonical schema in
/// `docs/design/07-technical/firestore-schema.md`. PR #42 is the FIRST
/// client surface that reads this collection; FR-SE-08 / PR #43 will be
/// the first client write producer.
///
/// **Read-only.** Per the ARCH-EXT-06 parallel to Invariant 2 for the
/// `verificationStatus` field, no caller of this type may write back to
/// Firestore.
@immutable
class SettlementDoc {
  /// Creates a [SettlementDoc].
  const SettlementDoc({
    required this.settlementId,
    required this.fromUserId,
    required this.toUserId,
    required this.amountPaise,
    required this.contextType,
    required this.contextId,
    required this.date,
    required this.note,
    required this.method,
    required this.verificationStatus,
    required this.currency,
    required this.createdAt,
    required this.deleted,
  });

  /// Parses a Firestore document snapshot into a [SettlementDoc],
  /// performing strict type and shape validation per the schema in
  /// `docs/design/07-technical/firestore-schema.md`.
  ///
  /// Returns `null` if any required field is missing or has the wrong
  /// type, or if `amountPaise` is not a positive integer (Invariant 1).
  /// In every failure case [onParseFailure] (when supplied) receives a
  /// descriptive message that names the settlement ID and the offending
  /// field so silent corruption stays observable downstream.
  ///
  /// Soft-deleted documents (`deleted == true`) still parse — the
  /// repository layer is responsible for filtering them out at the
  /// next layer.
  static SettlementDoc? fromFirestore({
    required String id,
    required Map<String, dynamic> data,
    void Function(String message)? onParseFailure,
  }) {
    String? requireString(String field) {
      final value = data[field];
      if (value is String) return value;
      onParseFailure?.call(
        'settlement $id: $field is missing or not a String; dropped',
      );
      return null;
    }

    int? requirePositiveInt(String field) {
      final value = data[field];
      if (value is int && value > 0) return value;
      onParseFailure?.call(
        'settlement $id: $field is not a positive integer; dropped',
      );
      return null;
    }

    DateTime? requireTimestamp(String field) {
      final value = data[field];
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      onParseFailure?.call(
        'settlement $id: $field is not a Timestamp; dropped',
      );
      return null;
    }

    bool? requireBool(String field) {
      final value = data[field];
      if (value is bool) return value;
      onParseFailure?.call('settlement $id: $field is not a bool; dropped');
      return null;
    }

    final fromUserId = requireString('fromUserId');
    if (fromUserId == null) return null;

    final toUserId = requireString('toUserId');
    if (toUserId == null) return null;

    final amountPaise = requirePositiveInt('amountPaise');
    if (amountPaise == null) return null;

    final contextType = requireString('contextType');
    if (contextType == null) return null;

    final contextId = requireString('contextId');
    if (contextId == null) return null;

    final date = requireTimestamp('date');
    if (date == null) return null;

    final method = requireString('method');
    if (method == null) return null;

    final verificationStatus = requireString('verificationStatus');
    if (verificationStatus == null) return null;

    final currency = requireString('currency');
    if (currency == null) return null;

    final createdAt = requireTimestamp('createdAt');
    if (createdAt == null) return null;

    final deleted = requireBool('deleted');
    if (deleted == null) return null;

    // `note` is the only nullable field. Accept null or a string; reject
    // any other type so a typo'd document still surfaces a parse failure.
    String? note;
    if (data.containsKey('note')) {
      final rawNote = data['note'];
      if (rawNote != null && rawNote is! String) {
        onParseFailure?.call('settlement $id: note is not a String; dropped');
        return null;
      }
      note = rawNote as String?;
    }

    return SettlementDoc(
      settlementId: id,
      fromUserId: fromUserId,
      toUserId: toUserId,
      amountPaise: amountPaise,
      contextType: contextType,
      contextId: contextId,
      date: date,
      note: note,
      method: method,
      verificationStatus: verificationStatus,
      currency: currency,
      createdAt: createdAt,
      deleted: deleted,
    );
  }

  /// Auto-generated Firestore document ID.
  final String settlementId;

  /// UID of the user making the payment (the debtor).
  final String fromUserId;

  /// UID of the user receiving the payment (the creditor).
  final String toUserId;

  /// Settlement amount in paise. Positive integer (Invariant 1).
  final int amountPaise;

  /// One of `'friendship'` or `'group'`.
  final String contextType;

  /// The document ID of the friendship or group this settlement belongs
  /// to.
  final String contextId;

  /// The date the settlement was made (user-specified).
  final DateTime date;

  /// Optional free-text note. Maximum 200 characters.
  final String? note;

  /// Settlement method discriminator. v1.0: always `'manual'`.
  final String method;

  /// Verification state. v1.0: always `'unverified'`. Client-read-only
  /// (ARCH-EXT-06).
  final String verificationStatus;

  /// ISO 4217 currency code. v1.0: always `'INR'`.
  final String currency;

  /// Server timestamp set at create. Immutable after create.
  final DateTime createdAt;

  /// Soft-delete flag.
  final bool deleted;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SettlementDoc &&
        other.settlementId == settlementId &&
        other.fromUserId == fromUserId &&
        other.toUserId == toUserId &&
        other.amountPaise == amountPaise &&
        other.contextType == contextType &&
        other.contextId == contextId &&
        other.date == date &&
        other.note == note &&
        other.method == method &&
        other.verificationStatus == verificationStatus &&
        other.currency == currency &&
        other.createdAt == createdAt &&
        other.deleted == deleted;
  }

  @override
  int get hashCode => Object.hash(
    settlementId,
    fromUserId,
    toUserId,
    amountPaise,
    contextType,
    contextId,
    date,
    note,
    method,
    verificationStatus,
    currency,
    createdAt,
    deleted,
  );
}
