// ActivityFeedProvider unit tests (FR-AC-01).
//
// Tests the Riverpod `StreamProvider<List<ActivityFeedItem>>` that
// wraps the repository's `watchItems` stream. Verifies:
//   - currentUserIdProvider is honoured.
//   - empty stream emission yields an empty list (Empty state).
//   - populated stream emission yields the projected list (Populated).
//   - stream error propagates as AsyncError (Error state).
//   - the list is unmodifiable (defence-in-depth).
//
// Tests are written BEFORE the implementation exists.

// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/activity/application/activity_feed_provider.dart';
import 'package:onebytwo/features/activity/data/activity_feed_repository.dart';
import 'package:onebytwo/features/activity/domain/activity_event_type.dart';
import 'package:onebytwo/features/activity/domain/activity_feed_item.dart';
import 'package:onebytwo/features/friends/application/friends_list_provider.dart';

/// Fake repository whose `watchItems` returns a controllable stream.
class FakeActivityFeedRepository implements ActivityFeedRepository {
  final StreamController<List<ActivityFeedItem>> controller =
      StreamController<List<ActivityFeedItem>>.broadcast();
  String? lastWatchedUid;

  @override
  Stream<List<ActivityFeedItem>> watchItems(String userId) {
    lastWatchedUid = userId;
    return controller.stream;
  }
}

ActivityFeedItem _item({
  required String id,
  ActivityEventType type = ActivityEventType.expenseAdded,
  DateTime? createdAt,
}) {
  return ActivityFeedItem(
    id: id,
    type: type,
    payload: const <String, dynamic>{},
    createdAt: createdAt ?? DateTime.utc(2026, 6, 8),
  );
}

void main() {
  late FakeActivityFeedRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = FakeActivityFeedRepository();
    container = ProviderContainer(
      overrides: [
        activityFeedRepositoryProvider.overrideWithValue(repository),
        currentUserIdProvider.overrideWithValue('uid-me'),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await repository.controller.close();
  });

  group('activityFeedProvider — initial state', () {
    test('starts in AsyncLoading and subscribes with the current uid', () async {
      container.listen(activityFeedProvider, (_, __) {});

      final initial = container.read(activityFeedProvider);
      expect(initial, isA<AsyncLoading<List<ActivityFeedItem>>>());
      expect(repository.lastWatchedUid, 'uid-me');
    });
  });

  group('activityFeedProvider — emissions', () {
    test('empty list emission yields AsyncData<[]>', () async {
      container.listen(activityFeedProvider, (_, __) {});

      repository.controller.add(const <ActivityFeedItem>[]);
      await pumpEventQueue();

      final state = container.read(activityFeedProvider);
      expect(state, isA<AsyncData<List<ActivityFeedItem>>>());
      expect(state.requireValue, isEmpty);
    });

    test('populated emission yields AsyncData with items in order', () async {
      container.listen(activityFeedProvider, (_, __) {});

      final items = [
        _item(id: 'a'),
        _item(id: 'b', type: ActivityEventType.settlementRecorded),
      ];
      repository.controller.add(items);
      await pumpEventQueue();

      final state = container.read(activityFeedProvider);
      expect(state.requireValue, hasLength(2));
      expect(state.requireValue[0].id, 'a');
      expect(state.requireValue[1].id, 'b');
    });

    test('successive emissions replace the prior list (real-time)', () async {
      container.listen(activityFeedProvider, (_, __) {});

      repository.controller.add([_item(id: 'first')]);
      await pumpEventQueue();
      expect(container.read(activityFeedProvider).requireValue, hasLength(1));

      repository.controller.add([
        _item(id: 'first'),
        _item(id: 'second'),
      ]);
      await pumpEventQueue();
      expect(container.read(activityFeedProvider).requireValue, hasLength(2));
    });

    test('stream error propagates as AsyncError', () async {
      container.listen(activityFeedProvider, (_, __) {});

      repository.controller.addError(StateError('permission-denied'));
      await pumpEventQueue();

      final state = container.read(activityFeedProvider);
      expect(state, isA<AsyncError<List<ActivityFeedItem>>>());
    });

    test('the projected list is unmodifiable (defence-in-depth)', () async {
      container.listen(activityFeedProvider, (_, __) {});

      repository.controller.add([_item(id: 'a')]);
      await pumpEventQueue();

      final list = container.read(activityFeedProvider).requireValue;
      expect(
        () => list.add(_item(id: 'tampered')),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}

Future<void> pumpEventQueue() async {
  await Future<void>.delayed(Duration.zero);
}
