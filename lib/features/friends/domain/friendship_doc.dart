import 'package:flutter/foundation.dart';

/// Immutable value type representing a `friendships/{friendshipId}`
/// document as read from Firestore.
///
/// The shape mirrors the canonical schema in
/// `docs/design/07-technical/firestore-schema.md`. Only the fields the
/// client needs to RENDER the friends list are projected — write-side
/// fields (e.g. `createdBy`) are not exposed.
///
/// Per **invariant 2**, this is a READ-ONLY view: nothing in this file
/// or its callers may produce a write back to Firestore that touches
/// `simplifiedBalances`.
@immutable
class FriendshipDoc {
  /// Creates a [FriendshipDoc].
  const FriendshipDoc({
    required this.friendshipId,
    required this.memberIds,
    required this.simplifiedBalances,
    required this.lastActivityAt,
  });

  /// Parses a Firestore document snapshot into a [FriendshipDoc],
  /// performing strict type validation on the `simplifiedBalances`
  /// field.
  ///
  /// Missing or `null` `simplifiedBalances` is normalised to an empty
  /// map (the freshly-created friendship case before the Cloud Function
  /// has run — the net balance will resolve to zero, which the UI
  /// renders as "settled up").
  ///
  /// Malformed nested entries (non-`Map` outer values, non-`int`
  /// leaves) are dropped and reported via [onParseFailure] when
  /// supplied. The remaining valid entries are preserved. This way a
  /// single corrupt entry never silently shows "settled up" for an
  /// entire row — every dropped entry is observable downstream.
  factory FriendshipDoc.fromFirestore({
    required String id,
    required Map<String, dynamic> data,
    DateTime? Function(Object? raw)? timestampParser,
    void Function(String message)? onParseFailure,
  }) {
    final memberIds =
        (data['memberIds'] as List?)?.whereType<String>().toList(
          growable: false,
        ) ??
        const <String>[];

    final rawBalances = data['simplifiedBalances'];
    final parsedBalances = _parseSimplifiedBalances(
      rawBalances,
      friendshipId: id,
      onParseFailure: onParseFailure,
    );

    final parser = timestampParser ?? _defaultTimestampParser;
    return FriendshipDoc(
      friendshipId: id,
      memberIds: memberIds,
      simplifiedBalances: parsedBalances,
      lastActivityAt: parser(data['lastActivityAt']),
    );
  }

  /// Deterministic document ID (sorted UIDs joined with `_`).
  final String friendshipId;

  /// Exactly two member UIDs, sorted ascending.
  final List<String> memberIds;

  /// Server-maintained nested balance map; read-only on the client
  /// (invariant 2).
  final Map<String, Map<String, int>> simplifiedBalances;

  /// Most recent activity timestamp; `null` only for synthetic test
  /// fixtures or freshly written docs whose server timestamp has not
  /// resolved yet.
  final DateTime? lastActivityAt;

  static Map<String, Map<String, int>> _parseSimplifiedBalances(
    Object? raw, {
    required String friendshipId,
    void Function(String message)? onParseFailure,
  }) {
    if (raw == null) return const {};
    if (raw is! Map) {
      onParseFailure?.call(
        'friendship $friendshipId: simplifiedBalances is not a Map; '
        'defaulting to empty',
      );
      return const {};
    }

    final result = <String, Map<String, int>>{};
    raw.forEach((debtor, creditorMap) {
      if (debtor is! String) {
        onParseFailure?.call(
          'friendship $friendshipId: simplifiedBalances has non-string '
          'debtor key; dropped',
        );
        return;
      }
      if (creditorMap is! Map) {
        onParseFailure?.call(
          'friendship $friendshipId: simplifiedBalances[$debtor] is not a '
          'Map; dropped',
        );
        return;
      }
      final inner = <String, int>{};
      creditorMap.forEach((creditor, paise) {
        if (creditor is! String || paise is! int) {
          onParseFailure?.call(
            'friendship $friendshipId: malformed entry in '
            'simplifiedBalances[$debtor]; dropped',
          );
          return;
        }
        inner[creditor] = paise;
      });
      if (inner.isNotEmpty) {
        result[debtor] = inner;
      }
    });

    return Map.unmodifiable(result);
  }

  static DateTime? _defaultTimestampParser(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    // Handles cloud_firestore's Timestamp via dynamic dispatch so that
    // pure-Dart tests can construct a FriendshipDoc from raw data
    // without importing the cloud_firestore package.
    try {
      // ignore: avoid_dynamic_calls
      final converted = (raw as dynamic).toDate();
      if (converted is DateTime) return converted;
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      return null;
    }
    return null;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FriendshipDoc &&
        other.friendshipId == friendshipId &&
        listEquals(other.memberIds, memberIds) &&
        mapEquals(other.simplifiedBalances, simplifiedBalances) &&
        other.lastActivityAt == lastActivityAt;
  }

  @override
  int get hashCode =>
      Object.hash(friendshipId, Object.hashAll(memberIds), lastActivityAt);
}
