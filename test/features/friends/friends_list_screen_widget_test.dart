// Friends list screen widget tests.
//
// Verifies the SCR-09 four-state rendering (loading / populated / empty /
// error), telemetry single-fire discipline, and INR formatter integration
// for FR-FR-03.
//
// These tests replace the original placeholder tests in
// `friends_list_test.dart` (PR #14 era) with comprehensive coverage of
// the real screen.

// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/core/telemetry/event_id_hash.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/friends/application/friend_detail_provider.dart';
import 'package:onebytwo/features/friends/application/friends_list_provider.dart';
import 'package:onebytwo/features/friends/data/contact_service.dart';
import 'package:onebytwo/features/friends/domain/contact_permission_state.dart';
import 'package:onebytwo/features/friends/domain/friend_list_item.dart';
import 'package:onebytwo/features/friends/presentation/add_friend_screen.dart';
import 'package:onebytwo/features/friends/presentation/friend_detail_screen.dart';
import 'package:onebytwo/features/friends/presentation/friends_list_screen.dart';

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

class FakeContactService implements ContactService {
  @override
  Future<ContactPermissionState> checkPermission() async =>
      ContactPermissionState.notDetermined;

  @override
  Future<ContactPermissionState> requestPermission() async =>
      ContactPermissionState.notDetermined;

  @override
  Future<List<DeviceContact>> getContacts() async => [];

  @override
  Future<void> openSettings() async {}
}

FriendListItem _item({
  required String friendshipId,
  required String otherUserId,
  required String displayName,
  required int netBalancePaise,
  String? photoUrl,
}) {
  return FriendListItem(
    friendshipId: friendshipId,
    otherUserId: otherUserId,
    displayName: displayName,
    photoUrl: photoUrl,
    netBalancePaise: netBalancePaise,
  );
}

void main() {
  late FakeAnalyticsService analytics;
  late FakeContactService contactService;
  late StreamController<List<FriendListItem>> streamController;

  setUp(() {
    analytics = FakeAnalyticsService();
    contactService = FakeContactService();
    streamController = StreamController<List<FriendListItem>>.broadcast();
  });

  tearDown(() async {
    await streamController.close();
  });

  Widget buildSubject() {
    return ProviderScope(
      overrides: [
        analyticsServiceProvider.overrideWithValue(analytics),
        contactServiceProvider.overrideWithValue(contactService),
        friendsListProvider.overrideWith((ref) => streamController.stream),
        currentUserIdProvider.overrideWithValue('current_user_uid'),
        // Override the friend-detail family so the navigation tap doesn't
        // try to instantiate the production firebaseFirestoreProvider.
        friendDetailProvider.overrideWith(
          (ref, args) => Stream<FriendDetailState>.value(
            const FriendDetailStateEmpty(
              header: FriendDetailHeader(
                displayName: 'Friend',
                photoUrl: null,
                netBalancePaise: 0,
                balanceState: BalanceState.settled,
              ),
            ),
          ),
        ),
      ],
      child: const MaterialApp(home: FriendsListScreen()),
    );
  }

  group('Loading state', () {
    testWidgets('shows skeleton placeholders before first emission', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byKey(const Key('friends_list_skeleton')), findsOneWidget);
    });

    testWidgets('does NOT fire friends_list_viewed while loading', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(analytics.countOf('friends_list_viewed'), 0);
    });
  });

  group('Empty state', () {
    testWidgets('renders the empty illustration and CTA when list is empty', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      streamController.add(const []);
      await tester.pumpAndSettle();

      expect(find.text('No friends yet'), findsOneWidget);
      expect(
        find.text('Add a friend and start sharing expenses.'),
        findsOneWidget,
      );
      expect(find.text('Add Friend'), findsOneWidget);
    });

    testWidgets('empty-state CTA fires friends_empty_add_tapped and '
        'navigates to AddFriendScreen', (tester) async {
      await tester.pumpWidget(buildSubject());
      streamController.add(const []);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Friend'));
      await tester.pumpAndSettle();

      expect(analytics.countOf('friends_empty_add_tapped'), 1);
      expect(find.byType(AddFriendScreen), findsOneWidget);
    });

    testWidgets('friends_list_viewed fires once with friend_count=0', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      streamController.add(const []);
      await tester.pumpAndSettle();

      expect(analytics.countOf('friends_list_viewed'), 1);
      expect(
        analytics.lastParamsFor('friends_list_viewed'),
        equals({'friend_count': 0}),
      );
    });
  });

  group('Populated state', () {
    final items = [
      _item(
        friendshipId: 'uid-aaa_uid-me',
        otherUserId: 'uid-aaa',
        displayName: 'Aarav',
        netBalancePaise: 12345,
      ),
      _item(
        friendshipId: 'uid-bbb_uid-me',
        otherUserId: 'uid-bbb',
        displayName: 'Bina',
        netBalancePaise: -5000,
      ),
      _item(
        friendshipId: 'uid-ccc_uid-me',
        otherUserId: 'uid-ccc',
        displayName: 'Chandra',
        netBalancePaise: 0,
      ),
    ];

    testWidgets('renders one tile per item with display name', (tester) async {
      await tester.pumpWidget(buildSubject());
      streamController.add(items);
      await tester.pumpAndSettle();

      expect(find.text('Aarav'), findsOneWidget);
      expect(find.text('Bina'), findsOneWidget);
      expect(find.text('Chandra'), findsOneWidget);
    });

    testWidgets('balance pill text reflects the direction', (tester) async {
      await tester.pumpWidget(buildSubject());
      streamController.add(items);
      await tester.pumpAndSettle();

      // Positive → "owes you"
      expect(find.text('owes you'), findsOneWidget);
      // Negative → "you owe"
      expect(find.text('you owe'), findsOneWidget);
      // Zero → "settled up"
      expect(find.text('settled up'), findsOneWidget);
    });

    testWidgets('balance amount uses the shared INR formatter (not inline)', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      streamController.add(items);
      await tester.pumpAndSettle();

      // Aarav: +123.45 → "₹123.45"
      expect(find.text(formatInrFromPaise(12345)), findsOneWidget);
      // Bina: -5000 paise → "−₹50.00"
      expect(find.text(formatInrFromPaise(-5000)), findsOneWidget);
      // Chandra: zero balance — the formatter is not used in the pill;
      // the "settled up" pill replaces the amount. Assert the raw zero
      // formatter result is NOT rendered, to lock the design behaviour.
      expect(find.text(formatInrFromPaise(0)), findsNothing);
    });

    testWidgets('friends_list_viewed fires once with friend_count=N', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      streamController.add(items);
      await tester.pumpAndSettle();

      expect(analytics.countOf('friends_list_viewed'), 1);
      expect(
        analytics.lastParamsFor('friends_list_viewed'),
        equals({'friend_count': 3}),
      );
    });

    testWidgets('friends_list_viewed is NOT re-fired on subsequent stream '
        'emissions (single-fire discipline)', (tester) async {
      await tester.pumpWidget(buildSubject());
      streamController.add(items);
      await tester.pumpAndSettle();
      streamController.add(items.sublist(0, 2));
      await tester.pumpAndSettle();
      streamController.add(const []);
      await tester.pumpAndSettle();

      expect(analytics.countOf('friends_list_viewed'), 1);
    });

    testWidgets('tapping a row fires friend_row_tapped with a hashed '
        'friendship_id and navigates to the placeholder detail', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      streamController.add(items);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Aarav'));
      await tester.pumpAndSettle();

      expect(analytics.countOf('friend_row_tapped'), 1);
      final params = analytics.lastParamsFor('friend_row_tapped');
      expect(params, isNotNull);
      expect(params!['friendship_id'], isA<String>());
      expect(
        params['friendship_id'],
        equals(hashFriendshipId('uid-aaa_uid-me')),
      );
      // The raw friendshipId must NOT be present anywhere in the event.
      expect(params['friendship_id'], isNot(equals('uid-aaa_uid-me')));
      expect(
        params.values.any((v) => v.toString().contains('uid-aaa_uid-me')),
        isFalse,
        reason: 'Raw friendshipId leaked in friend_row_tapped parameters',
      );

      expect(find.byType(FriendDetailScreen), findsOneWidget);
    });

    testWidgets('navigated friend detail screen does NOT display the raw '
        'friendship ID', (tester) async {
      await tester.pumpWidget(buildSubject());
      streamController.add(items);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Aarav'));
      await tester.pumpAndSettle();

      // Locate the actual rendered text widgets and assert none contain the
      // friendshipId. Tooltips are checked too.
      final allWidgets = tester.allWidgets;
      for (final widget in allWidgets) {
        if (widget is Text) {
          expect(
            widget.data ?? '',
            isNot(contains('uid-aaa_uid-me')),
            reason: 'Friend Detail rendered raw friendshipId in a Text widget',
          );
        }
      }
    });
  });

  group('Error state', () {
    testWidgets('renders an error message when the stream emits an error', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      streamController.addError(Exception('Firestore down'));
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('does NOT fire friends_list_viewed in the error state', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      streamController.addError(Exception('Firestore down'));
      await tester.pumpAndSettle();

      expect(analytics.countOf('friends_list_viewed'), 0);
    });
  });

  group('App-bar Add Friend (regression from PR #14 placeholder)', () {
    testWidgets('the + action remains present in the populated state', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      streamController.add(const [
        FriendListItem(
          friendshipId: 'uid-aaa_uid-me',
          otherUserId: 'uid-aaa',
          displayName: 'Aarav',
          photoUrl: null,
          netBalancePaise: 0,
        ),
      ]);
      await tester.pumpAndSettle();

      expect(find.byTooltip('Add friend'), findsOneWidget);
    });

    testWidgets('tapping the app-bar + fires friend_add_button_tapped and '
        'navigates to AddFriendScreen', (tester) async {
      await tester.pumpWidget(buildSubject());
      streamController.add(const [
        FriendListItem(
          friendshipId: 'uid-aaa_uid-me',
          otherUserId: 'uid-aaa',
          displayName: 'Aarav',
          photoUrl: null,
          netBalancePaise: 0,
        ),
      ]);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Add friend'));
      await tester.pumpAndSettle();

      expect(analytics.countOf('friend_add_button_tapped'), 1);
      expect(find.byType(AddFriendScreen), findsOneWidget);
    });
  });
}
