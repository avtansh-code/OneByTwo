import 'package:flutter/foundation.dart';

import 'package:onebytwo/features/activity/domain/activity_event_type.dart';

/// Immutable value type representing a single
/// `activity/{userId}/items/{itemId}` document as read from Firestore.
///
/// The schema is deliberately schemaless in the `payload` field per
/// `docs/design/07-technical/firestore-schema.md` lines 194-211 — the
/// shape varies by `type` discriminator. The widget layer derives
/// per-type rendering (icon, primary text, amount) from the payload
/// map.
///
/// Per **invariant 2**, this is a READ-ONLY view: nothing in this file
/// or its callers may produce a write back to Firestore that touches
/// the activity collection (rules enforce server-only writes per
/// FR-EX-07).
@immutable
class ActivityFeedItem {
  /// Creates an [ActivityFeedItem].
  const ActivityFeedItem({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
  });

  /// Parses a Firestore document snapshot into an [ActivityFeedItem],
  /// performing strict type validation. Returns `null` and reports via
  /// [onParseFailure] when the document is malformed (unknown `type`
  /// discriminator, missing `type`, non-map `payload`).
  ///
  /// Mirrors the `FriendshipDoc.fromFirestore` strict-parsing
  /// precedent: a single corrupt entry never silently shows as a
  /// rendered row — every dropped entry is observable downstream via
  /// the structured-log callback.
  static ActivityFeedItem? fromFirestore({
    required String id,
    required Map<String, dynamic> data,
    DateTime? Function(Object? raw)? timestampParser,
    void Function(String message)? onParseFailure,
  }) {
    if (!data.containsKey('type')) {
      onParseFailure?.call(
        'activity item $id: missing type discriminator; dropped',
      );
      return null;
    }

    final rawType = data['type'];
    if (rawType is! String) {
      onParseFailure?.call('activity item $id: type must be a String; dropped');
      return null;
    }

    final parsedType = ActivityEventTypeX.parseSnakeCase(rawType);
    if (parsedType == null) {
      onParseFailure?.call(
        'activity item $id: unknown type "$rawType"; dropped',
      );
      return null;
    }

    final rawPayload = data['payload'];
    if (rawPayload is! Map) {
      onParseFailure?.call('activity item $id: payload must be a Map; dropped');
      return null;
    }
    final payload = Map<String, dynamic>.from(rawPayload);

    final parser = timestampParser ?? _defaultTimestampParser;
    final createdAt = parser(data['createdAt']);

    return ActivityFeedItem(
      id: id,
      type: parsedType,
      payload: payload,
      createdAt: createdAt,
    );
  }

  /// Auto-generated Firestore document ID (opaque).
  final String id;

  /// Event-type discriminator parsed from the Firestore `type` field.
  final ActivityEventType type;

  /// Schemaless event payload. Shape varies by [type]; the widget
  /// layer derives per-type fields via map access.
  final Map<String, dynamic> payload;

  /// Server-set timestamp at which the activity item was written.
  /// `null` for synthetic test fixtures and for documents whose
  /// server timestamp has not yet resolved.
  final DateTime? createdAt;

  static DateTime? _defaultTimestampParser(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    // Handles cloud_firestore's Timestamp via dynamic dispatch so that
    // pure-Dart tests can construct an ActivityFeedItem from raw data
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
    return other is ActivityFeedItem &&
        other.id == id &&
        other.type == type &&
        mapEquals(other.payload, payload) &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(id, type, createdAt);
}
