// Activity feed screen widget tests (FR-AC-01).
//
// Verifies the SCR-25 multi-state rendering (Loading / Populated /
// Empty / Error / Refreshing), telemetry single-fire discipline for
// activity_feed_viewed, the activity_item_tapped event including PII
// hashing of friendship entity_ids (AC-17), and the FR-AC-02 deep-link
// routing surface.
//
// Tests are written BEFORE the implementation exists.

// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/telemetry/event_id_hash.dart';
import 'package:onebytwo/features/activity/application/activity_feed_provider.dart';
import 'package:onebytwo/features/activity/data/activity_feed_repository.dart';
import 'package:onebytwo/features/activity/domain/activity_event_type.dart';
import 'package:onebytwo/features/activity/domain/activity_feed_item.dart';
import 'package:onebytwo/features/activity/presentation/activity_feed_screen.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/domain/user_model.dart';
import 'package:onebytwo/features/friends/application/friends_list_provider.dart';
import 'package:onebytwo/features/friends/application/user_profile_provider.dart';

class FakeAnalyticsService implements AnalyticsService {
  final List<({String name, Map<String, Object>? parameters})> loggedEvents =
      [];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    loggedEvents.add((name: name, parameters: parameters));
  }

  int countOf(String name) => loggedEvents.where((e) => e.name == name).length;

  Map<String, Object>? lastParamsFor(String name) {
    return loggedEvents.lastWhere((e) => e.name == name).parameters;
  }
}

class FakeActivityFeedRepository implements ActivityFeedRepository {
  final StreamController<List<ActivityFeedItem>> controller =
      StreamController<List<ActivityFeedItem>>.broadcast();

  @override
  Stream<List<ActivityFeedItem>> watchItems(String userId) {
    return controller.stream;
  }
}

ActivityFeedItem _expenseAddedByOther({String id = 'e-1'}) {
  return ActivityFeedItem(
    id: id,
    type: ActivityEventType.expenseAdded,
    payload: const <String, dynamic>{
      'expenseId': 'exp-1',
      'friendshipId': 'uid-me_uid-other',
      'description': 'Dinner',
      'amountPaise': 12345,
      'category': 'food',
      'payerId': 'uid-other',
      'authorUid': 'uid-other',
      'splits': <Map<String, dynamic>>[],
      'splitMethod': 'equal',
      'hasReceipt': false,
    },
    createdAt: DateTime.utc(2026, 6, 8, 11),
  );
}

ActivityFeedItem _settlementByCurrent({String id = 's-1'}) {
  return ActivityFeedItem(
    id: id,
    type: ActivityEventType.settlementRecorded,
    payload: const <String, dynamic>{
      'settlementId': 'set-1',
      'fromUserId': 'uid-me',
      'toUserId': 'uid-other',
      'amountPaise': 5000,
      'contextType': 'friendship',
      'contextId': 'uid-me_uid-other',
      'authorUid': 'uid-me',
    },
    createdAt: DateTime.utc(2026, 6, 8, 11, 30),
  );
}

UserModel _user(String name) {
  return UserModel(
    phoneNumber: '+919876543210',
    displayName: name,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

ProviderContainer _makeContainer({
  required FakeActivityFeedRepository repository,
  required FakeAnalyticsService analytics,
  Map<String, UserModel?> profiles = const <String, UserModel?>{},
}) {
  return ProviderContainer(
    overrides: [
      activityFeedRepositoryProvider.overrideWithValue(repository),
      analyticsServiceProvider.overrideWithValue(analytics),
      currentUserIdProvider.overrideWithValue('uid-me'),
      userProfileProvider.overrideWith(
        (ref, uid) async => profiles[uid],
      ),
    ],
  );
}

Widget _wrap(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: ActivityFeedScreen()),
  );
}

void main() {
  group('ActivityFeedScreen — Loading state', () {
    testWidgets('displays a skeleton loader while resolving', (tester) async {
      final repo = FakeActivityFeedRepository();
      final analytics = FakeAnalyticsService();
      final container = _makeContainer(
        repository: repo,
        analytics: analytics,
      );
      addTearDown(container.dispose);
      addTearDown(() async => repo.controller.close());

      await tester.pumpWidget(_wrap(container));
      await tester.pump();

      expect(find.byKey(const Key('activity_feed_skeleton')), findsOneWidget);
    });
  });

  group('ActivityFeedScreen — Populated state', () {
    testWidgets('renders one OBTActivityRow per item in stream order', (
      tester,
    ) async {
      final repo = FakeActivityFeedRepository();
      final analytics = FakeAnalyticsService();
      final container = _makeContainer(
        repository: repo,
        analytics: analytics,
        profiles: {'uid-other': _user('Priya')},
      );
      addTearDown(container.dispose);
      addTearDown(() async => repo.controller.close());

      await tester.pumpWidget(_wrap(container));
      await tester.pump();

      repo.controller.add([_expenseAddedByOther(), _settlementByCurrent()]);
      await tester.pumpAndSettle();

      expect(find.textContaining('Dinner'), findsOneWidget);
      expect(find.textContaining('settled up'), findsOneWidget);
    });

    testWidgets('fires activity_feed_viewed exactly once with item_count', (
      tester,
    ) async {
      final repo = FakeActivityFeedRepository();
      final analytics = FakeAnalyticsService();
      final container = _makeContainer(
        repository: repo,
        analytics: analytics,
        profiles: {'uid-other': _user('Priya')},
      );
      addTearDown(container.dispose);
      addTearDown(() async => repo.controller.close());

      await tester.pumpWidget(_wrap(container));
      await tester.pump();

      repo.controller.add([_expenseAddedByOther(), _settlementByCurrent()]);
      await tester.pumpAndSettle();

      repo.controller.add([
        _expenseAddedByOther(id: 'e-2'),
        _settlementByCurrent(id: 's-2'),
      ]);
      await tester.pumpAndSettle();

      expect(analytics.countOf('activity_feed_viewed'), 1);
      expect(
        analytics.lastParamsFor('activity_feed_viewed'),
        containsPair('item_count', 2),
      );
    });
  });

  group('ActivityFeedScreen — Empty state', () {
    testWidgets('shows the SCR-25 empty copy when items list is empty', (
      tester,
    ) async {
      final repo = FakeActivityFeedRepository();
      final analytics = FakeAnalyticsService();
      final container = _makeContainer(
        repository: repo,
        analytics: analytics,
      );
      addTearDown(container.dispose);
      addTearDown(() async => repo.controller.close());

      await tester.pumpWidget(_wrap(container));
      await tester.pump();

      repo.controller.add(const <ActivityFeedItem>[]);
      await tester.pumpAndSettle();

      expect(find.text('All quiet here'), findsOneWidget);
      expect(
        find.textContaining(
          'Your activity will show up as you add expenses and settle up.',
        ),
        findsOneWidget,
      );
    });
  });

  group('ActivityFeedScreen — Error state', () {
    testWidgets('shows the SCR-25 error copy on stream error', (tester) async {
      final repo = FakeActivityFeedRepository();
      final analytics = FakeAnalyticsService();
      final container = _makeContainer(
        repository: repo,
        analytics: analytics,
      );
      addTearDown(container.dispose);
      addTearDown(() async => repo.controller.close());

      await tester.pumpWidget(_wrap(container));
      await tester.pump();

      repo.controller.addError(StateError('permission-denied'));
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(
        find.textContaining(
          'We could not load your activity. Please try again.',
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(OutlinedButton, 'Retry'), findsOneWidget);
    });

    testWidgets('fires activity_feed_error with an error_code parameter', (
      tester,
    ) async {
      final repo = FakeActivityFeedRepository();
      final analytics = FakeAnalyticsService();
      final container = _makeContainer(
        repository: repo,
        analytics: analytics,
      );
      addTearDown(container.dispose);
      addTearDown(() async => repo.controller.close());

      await tester.pumpWidget(_wrap(container));
      await tester.pump();

      repo.controller.addError(StateError('permission-denied'));
      await tester.pumpAndSettle();

      expect(analytics.countOf('activity_feed_error'), 1);
      final params = analytics.lastParamsFor('activity_feed_error');
      expect(params, isNotNull);
      expect(params!.containsKey('error_code'), isTrue);
      expect(params['error_code'], isA<String>());
    });
  });

  group('ActivityFeedScreen — telemetry (PII hashing)', () {
    testWidgets(
      'activity_item_tapped hashes the friendship entity_id (AC-17)',
      (tester) async {
        final repo = FakeActivityFeedRepository();
        final analytics = FakeAnalyticsService();
        final container = _makeContainer(
          repository: repo,
          analytics: analytics,
          profiles: {'uid-other': _user('Priya')},
        );
        addTearDown(container.dispose);
        addTearDown(() async => repo.controller.close());

        await tester.pumpWidget(_wrap(container));
        await tester.pump();

        repo.controller.add([_settlementByCurrent()]);
        await tester.pumpAndSettle();

        await tester.tap(find.textContaining('settled up'));
        await tester.pumpAndSettle();

        expect(
          analytics.countOf('activity_item_tapped'),
          greaterThanOrEqualTo(1),
        );
        final params = analytics.lastParamsFor('activity_item_tapped')!;
        expect(params['event_type'], 'settlementRecorded');
        // The settlement row deep-links to the Friend Detail screen
        // (a friendship target). The entity_id parameter MUST be the
        // hashed composite friendship UID per ADR-0013.
        final expectedHash = hashFriendshipId('uid-me_uid-other');
        expect(params['entity_id'], expectedHash);
        // The raw composite UID MUST NOT appear.
        expect(params['entity_id'], isNot(equals('uid-me_uid-other')));
      },
    );

    testWidgets(
      'activity_item_tapped uses raw opaque expenseId for expense rows',
      (tester) async {
        final repo = FakeActivityFeedRepository();
        final analytics = FakeAnalyticsService();
        final container = _makeContainer(
          repository: repo,
          analytics: analytics,
          profiles: {'uid-other': _user('Priya')},
        );
        addTearDown(container.dispose);
        addTearDown(() async => repo.controller.close());

        await tester.pumpWidget(_wrap(container));
        await tester.pump();

        repo.controller.add([_expenseAddedByOther()]);
        await tester.pumpAndSettle();

        await tester.tap(find.textContaining('Dinner'));
        await tester.pumpAndSettle();

        final params = analytics.lastParamsFor('activity_item_tapped')!;
        expect(params['event_type'], 'expenseAdded');
        // Expense IDs are opaque Firestore auto IDs — NOT subject to
        // ADR-0013 hashing per the FR-FR-03 memory.
        expect(params['entity_id'], 'exp-1');
      },
    );
  });
}


ActivityFeedItem _expenseAddedByOther({String id = 'e-1'}) {
  return ActivityFeedItem(
    id: id,
    type: ActivityEventType.expenseAdded,
    payload: const <String, dynamic>{
      'expenseId': 'exp-1',
      'friendshipId': 'uid-me_uid-other',
      'description': 'Dinner',
      'amountPaise': 12345,
      'category': 'food',
      'payerId': 'uid-other',
      'authorUid': 'uid-other',
      'splits': <Map<String, dynamic>>[],
      'splitMethod': 'equal',
      'hasReceipt': false,
    },
    createdAt: DateTime.utc(2026, 6, 8, 11),
  );
}

ActivityFeedItem _settlementByCurrent({String id = 's-1'}) {
  return ActivityFeedItem(
    id: id,
    type: ActivityEventType.settlementRecorded,
    payload: const <String, dynamic>{
      'settlementId': 'set-1',
      'fromUserId': 'uid-me',
      'toUserId': 'uid-other',
      'amountPaise': 5000,
      'contextType': 'friendship',
      'contextId': 'uid-me_uid-other',
      'authorUid': 'uid-me',
    },
    createdAt: DateTime.utc(2026, 6, 8, 11, 30),
  );
}

UserModel _user(String name) {
  return UserModel(
    phoneNumber: '+919876543210',
    displayName: name,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

ProviderContainer _makeContainer({
  required FakeActivityFeedRepository repository,
  required FakeAnalyticsService analytics,
  required FakeUserRepository userRepository,
}) {
  return ProviderContainer(
    overrides: [
      activityFeedRepositoryProvider.overrideWithValue(repository),
      analyticsServiceProvider.overrideWithValue(analytics),
      currentUserIdProvider.overrideWithValue('uid-me'),
      userRepositoryProvider.overrideWithValue(userRepository),
    ],
  );
}

Widget _wrap(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: ActivityFeedScreen()),
  );
}

void main() {
  group('ActivityFeedScreen — Loading state', () {
    testWidgets('displays a skeleton loader while resolving', (tester) async {
      final repo = FakeActivityFeedRepository();
      final analytics = FakeAnalyticsService();
      final userRepo = FakeUserRepository();
      final container = _makeContainer(
        repository: repo,
        analytics: analytics,
        userRepository: userRepo,
      );
      addTearDown(container.dispose);
      addTearDown(() async => repo.controller.close());

      await tester.pumpWidget(_wrap(container));
      await tester.pump();

      expect(find.byKey(const Key('activity_feed_skeleton')), findsOneWidget);
    });
  });

  group('ActivityFeedScreen — Populated state', () {
    testWidgets('renders one OBTActivityRow per item in stream order', (
      tester,
    ) async {
      final repo = FakeActivityFeedRepository();
      final analytics = FakeAnalyticsService();
      final userRepo = FakeUserRepository()
        ..users['uid-other'] = _user('Priya');
      final container = _makeContainer(
        repository: repo,
        analytics: analytics,
        userRepository: userRepo,
      );
      addTearDown(container.dispose);
      addTearDown(() async => repo.controller.close());

      await tester.pumpWidget(_wrap(container));
      await tester.pump();

      repo.controller.add([_expenseAddedByOther(), _settlementByCurrent()]);
      await tester.pumpAndSettle();

      expect(find.textContaining('Dinner'), findsOneWidget);
      expect(find.textContaining('settled up'), findsOneWidget);
    });

    testWidgets('fires activity_feed_viewed exactly once with item_count', (
      tester,
    ) async {
      final repo = FakeActivityFeedRepository();
      final analytics = FakeAnalyticsService();
      final userRepo = FakeUserRepository()
        ..users['uid-other'] = _user('Priya');
      final container = _makeContainer(
        repository: repo,
        analytics: analytics,
        userRepository: userRepo,
      );
      addTearDown(container.dispose);
      addTearDown(() async => repo.controller.close());

      await tester.pumpWidget(_wrap(container));
      await tester.pump();

      repo.controller.add([_expenseAddedByOther(), _settlementByCurrent()]);
      await tester.pumpAndSettle();

      // A second emission should NOT double-log the viewed event.
      repo.controller.add([
        _expenseAddedByOther(id: 'e-2'),
        _settlementByCurrent(id: 's-2'),
      ]);
      await tester.pumpAndSettle();

      expect(analytics.countOf('activity_feed_viewed'), 1);
      expect(
        analytics.lastParamsFor('activity_feed_viewed'),
        containsPair('item_count', 2),
      );
    });
  });

  group('ActivityFeedScreen — Empty state', () {
    testWidgets('shows the SCR-25 empty copy when items list is empty', (
      tester,
    ) async {
      final repo = FakeActivityFeedRepository();
      final analytics = FakeAnalyticsService();
      final userRepo = FakeUserRepository();
      final container = _makeContainer(
        repository: repo,
        analytics: analytics,
        userRepository: userRepo,
      );
      addTearDown(container.dispose);
      addTearDown(() async => repo.controller.close());

      await tester.pumpWidget(_wrap(container));
      await tester.pump();

      repo.controller.add(const <ActivityFeedItem>[]);
      await tester.pumpAndSettle();

      expect(find.text('All quiet here'), findsOneWidget);
      expect(
        find.textContaining(
          'Your activity will show up as you add expenses and settle up.',
        ),
        findsOneWidget,
      );
    });
  });

  group('ActivityFeedScreen — Error state', () {
    testWidgets('shows the SCR-25 error copy on stream error', (tester) async {
      final repo = FakeActivityFeedRepository();
      final analytics = FakeAnalyticsService();
      final userRepo = FakeUserRepository();
      final container = _makeContainer(
        repository: repo,
        analytics: analytics,
        userRepository: userRepo,
      );
      addTearDown(container.dispose);
      addTearDown(() async => repo.controller.close());

      await tester.pumpWidget(_wrap(container));
      await tester.pump();

      repo.controller.addError(StateError('permission-denied'));
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(
        find.textContaining(
          'We could not load your activity. Please try again.',
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(OutlinedButton, 'Retry'), findsOneWidget);
    });

    testWidgets('fires activity_feed_error with an error_code parameter', (
      tester,
    ) async {
      final repo = FakeActivityFeedRepository();
      final analytics = FakeAnalyticsService();
      final userRepo = FakeUserRepository();
      final container = _makeContainer(
        repository: repo,
        analytics: analytics,
        userRepository: userRepo,
      );
      addTearDown(container.dispose);
      addTearDown(() async => repo.controller.close());

      await tester.pumpWidget(_wrap(container));
      await tester.pump();

      repo.controller.addError(StateError('permission-denied'));
      await tester.pumpAndSettle();

      expect(analytics.countOf('activity_feed_error'), 1);
      final params = analytics.lastParamsFor('activity_feed_error');
      expect(params, isNotNull);
      expect(params!.containsKey('error_code'), isTrue);
      expect(params['error_code'], isA<String>());
    });
  });

  group('ActivityFeedScreen — telemetry (PII hashing)', () {
    testWidgets(
      'activity_item_tapped hashes the friendship entity_id (AC-17)',
      (tester) async {
        final repo = FakeActivityFeedRepository();
        final analytics = FakeAnalyticsService();
        final userRepo = FakeUserRepository()
          ..users['uid-other'] = _user('Priya');
        final container = _makeContainer(
          repository: repo,
          analytics: analytics,
          userRepository: userRepo,
        );
        addTearDown(container.dispose);
        addTearDown(() async => repo.controller.close());

        await tester.pumpWidget(_wrap(container));
        await tester.pump();

        repo.controller.add([_settlementByCurrent()]);
        await tester.pumpAndSettle();

        await tester.tap(find.textContaining('settled up'));
        await tester.pumpAndSettle();

        expect(analytics.countOf('activity_item_tapped'), greaterThanOrEqualTo(1));
        final params = analytics.lastParamsFor('activity_item_tapped')!;
        expect(params['event_type'], 'settlementRecorded');
        // The settlement row deep-links to the Friend Detail screen
        // (a friendship target). The entity_id parameter MUST be the
        // hashed composite friendship UID per ADR-0013.
        final expectedHash = hashFriendshipId('uid-me_uid-other');
        expect(params['entity_id'], expectedHash);
        // The raw composite UID MUST NOT appear.
        expect(params['entity_id'], isNot(equals('uid-me_uid-other')));
      },
    );

    testWidgets(
      'activity_item_tapped uses raw opaque expenseId for expense rows',
      (tester) async {
        final repo = FakeActivityFeedRepository();
        final analytics = FakeAnalyticsService();
        final userRepo = FakeUserRepository()
          ..users['uid-other'] = _user('Priya');
        final container = _makeContainer(
          repository: repo,
          analytics: analytics,
          userRepository: userRepo,
        );
        addTearDown(container.dispose);
        addTearDown(() async => repo.controller.close());

        await tester.pumpWidget(_wrap(container));
        await tester.pump();

        repo.controller.add([_expenseAddedByOther()]);
        await tester.pumpAndSettle();

        await tester.tap(find.textContaining('Dinner'));
        await tester.pumpAndSettle();

        final params = analytics.lastParamsFor('activity_item_tapped')!;
        expect(params['event_type'], 'expenseAdded');
        // Expense IDs are opaque Firestore auto IDs — NOT subject to
        // ADR-0013 hashing per the FR-FR-03 memory.
        expect(params['entity_id'], 'exp-1');
      },
    );
  });
}
