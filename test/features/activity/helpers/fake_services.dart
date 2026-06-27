// Shared activity test fakes — reused by the DC-09 reskin gate
// (activity_haldi_reskin_test.dart) and the golden scaffold
// (dc09_activity_golden_test.dart) so neither file redefines a
// `Fake…`/`Noop…` per file (the DC-07 / DC-08 review lesson).

import 'dart:async';

import 'package:onebytwo/features/activity/data/activity_feed_repository.dart';
import 'package:onebytwo/features/activity/domain/activity_event_type.dart';
import 'package:onebytwo/features/activity/domain/activity_feed_item.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';

/// Recording [AnalyticsService] that captures every emitted event so a test
/// can assert the deep-link / view telemetry still fires without a real
/// Firebase Analytics.
class RecordingAnalytics implements AnalyticsService {
  /// Every event logged during the test, in order.
  final List<({String name, Map<String, Object>? parameters})> events =
      <({String name, Map<String, Object>? parameters})>[];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    events.add((name: name, parameters: parameters));
  }

  /// Count of events with [name].
  int countOf(String name) => events.where((e) => e.name == name).length;

  /// Parameters of the last event named [name].
  Map<String, Object>? lastParamsFor(String name) =>
      events.lastWhere((e) => e.name == name).parameters;
}

/// Configurable fake [ActivityFeedRepository]. Defaults to an empty feed and
/// a successful read. Seed [items] / set [keepLoading] / set [streamError] to
/// drive each list state.
class FakeActivityFeedRepository implements ActivityFeedRepository {
  /// Creates a [FakeActivityFeedRepository] seeded with [items].
  FakeActivityFeedRepository({
    this.items = const <ActivityFeedItem>[],
    this.keepLoading = false,
  });

  /// The list emitted by [watchItems].
  List<ActivityFeedItem> items;

  /// When true, [watchItems] returns a never-emitting stream so the screen
  /// stays in its loading (skeleton) state.
  final bool keepLoading;

  /// When non-null, [watchItems] emits this error (drives the error state).
  /// Takes precedence over [keepLoading] / [items].
  Object? streamError;

  @override
  Stream<List<ActivityFeedItem>> watchItems(String userId) {
    if (streamError != null) {
      return Stream<List<ActivityFeedItem>>.error(streamError!);
    }
    return keepLoading
        ? Stream<List<ActivityFeedItem>>.fromFuture(
            Completer<List<ActivityFeedItem>>().future,
          )
        : Stream<List<ActivityFeedItem>>.value(items);
  }
}

/// Builds an "expense added" activity item carrying a trailing amount so the
/// frozen `OBTActivityRow` renders the `formatInrFromPaise()` money path.
ActivityFeedItem fakeExpenseAdded({
  String id = 'e-1',
  String authorUid = 'uid-other',
  String description = 'Dinner',
  int amountPaise = 12345,
}) {
  return ActivityFeedItem(
    id: id,
    type: ActivityEventType.expenseAdded,
    payload: <String, dynamic>{
      'expenseId': 'exp-1',
      'friendshipId': 'uid-me_uid-other',
      'description': description,
      'amountPaise': amountPaise,
      'category': 'food',
      'authorUid': authorUid,
    },
    createdAt: DateTime.utc(2026, 6, 8, 11),
  );
}

/// Builds a "settlement recorded by the current user" activity item.
ActivityFeedItem fakeSettlement({String id = 's-1', int amountPaise = 5000}) {
  return ActivityFeedItem(
    id: id,
    type: ActivityEventType.settlementRecorded,
    payload: <String, dynamic>{
      'settlementId': 'set-1',
      'fromUserId': 'uid-me',
      'toUserId': 'uid-other',
      'amountPaise': amountPaise,
      'contextType': 'friendship',
      'contextId': 'uid-me_uid-other',
      'authorUid': 'uid-me',
    },
    createdAt: DateTime.utc(2026, 6, 8, 11, 30),
  );
}
