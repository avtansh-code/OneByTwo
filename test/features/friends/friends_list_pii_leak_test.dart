// Friends list PII-leak tests.
//
// Verifies that no personally-identifiable information leaks into
// analytics events from the friends list flow. Replicates the assertion
// shape established by PR #32's
// `match_and_invite_pii_leak_test.dart` (the canonical pattern).
//
// PII strings to guard against include raw friendshipIds (which compose
// two UIDs), display names, phone numbers, and photo URLs.
//
// These tests are written BEFORE the implementation exists (test-first).

// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/telemetry/event_id_hash.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/friends/application/friends_list_provider.dart';
import 'package:onebytwo/features/friends/data/contact_service.dart';
import 'package:onebytwo/features/friends/domain/contact_permission_state.dart';
import 'package:onebytwo/features/friends/domain/friend_list_item.dart';
import 'package:onebytwo/features/friends/presentation/friends_list_screen.dart';

const _piiStrings = [
  // Raw friendshipId (composed of two UIDs) — must NEVER appear in events.
  'uid-priyalakshmi_uid-rahulagarwal',
  // Individual UIDs that compose the friendshipId.
  'uid-priyalakshmi',
  'uid-rahulagarwal',
  // Display name fragments.
  'Priya',
  'Lakshmi',
  'Rahul',
  'Agarwal',
  // Photo URLs.
  'https://photos.example.com/priya.png',
  // Phone numbers (even though this flow doesn't render them, they must
  // not leak if seeded through any provider path).
  '+919876543210',
  '9876543210',
];

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

  bool containsPii(String pii) {
    for (final event in loggedEvents) {
      if (event.name.contains(pii)) return true;
      if (event.parameters != null) {
        for (final value in event.parameters!.values) {
          if (value.toString().contains(pii)) return true;
        }
        for (final key in event.parameters!.keys) {
          if (key.contains(pii)) return true;
        }
      }
    }
    return false;
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
      ],
      child: const MaterialApp(home: FriendsListScreen()),
    );
  }

  testWidgets('no PII in analytics events after viewing populated list', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    streamController.add(const [
      FriendListItem(
        friendshipId: 'uid-priyalakshmi_uid-rahulagarwal',
        otherUserId: 'uid-priyalakshmi',
        displayName: 'Priya Lakshmi',
        photoUrl: 'https://photos.example.com/priya.png',
        netBalancePaise: 12345,
      ),
    ]);
    await tester.pumpAndSettle();

    for (final pii in _piiStrings) {
      expect(
        analytics.containsPii(pii),
        isFalse,
        reason: 'Analytics should not contain PII: $pii',
      );
    }
  });

  testWidgets('friend_row_tapped parameter friendship_id is hashed '
      '(not the raw composite UID)', (tester) async {
    await tester.pumpWidget(buildSubject());

    streamController.add(const [
      FriendListItem(
        friendshipId: 'uid-priyalakshmi_uid-rahulagarwal',
        otherUserId: 'uid-priyalakshmi',
        displayName: 'Priya Lakshmi',
        photoUrl: 'https://photos.example.com/priya.png',
        netBalancePaise: 12345,
      ),
    ]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Priya Lakshmi'));
    await tester.pumpAndSettle();

    final rowTapped = analytics.loggedEvents
        .where((e) => e.name == 'friend_row_tapped')
        .toList();
    expect(rowTapped, hasLength(1));

    final params = rowTapped.first.parameters;
    expect(params, isNotNull);
    expect(params!['friendship_id'], isA<String>());
    expect(
      params['friendship_id'],
      equals(hashFriendshipId('uid-priyalakshmi_uid-rahulagarwal')),
    );

    // PII must not leak into any analytics event.
    for (final pii in _piiStrings) {
      expect(
        analytics.containsPii(pii),
        isFalse,
        reason: 'Analytics leaked PII after row tap: $pii',
      );
    }
  });

  testWidgets('no PII in analytics event names', (tester) async {
    await tester.pumpWidget(buildSubject());

    streamController.add(const [
      FriendListItem(
        friendshipId: 'uid-priyalakshmi_uid-rahulagarwal',
        otherUserId: 'uid-priyalakshmi',
        displayName: 'Priya Lakshmi',
        photoUrl: 'https://photos.example.com/priya.png',
        netBalancePaise: 12345,
      ),
    ]);
    await tester.pumpAndSettle();

    for (final event in analytics.loggedEvents) {
      for (final pii in _piiStrings) {
        expect(
          event.name.contains(pii),
          isFalse,
          reason: 'Event name "${event.name}" leaked PII: $pii',
        );
      }
    }
  });

  testWidgets('no PII in analytics event parameter keys', (tester) async {
    await tester.pumpWidget(buildSubject());

    streamController.add(const [
      FriendListItem(
        friendshipId: 'uid-priyalakshmi_uid-rahulagarwal',
        otherUserId: 'uid-priyalakshmi',
        displayName: 'Priya Lakshmi',
        photoUrl: 'https://photos.example.com/priya.png',
        netBalancePaise: 12345,
      ),
    ]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Priya Lakshmi'));
    await tester.pumpAndSettle();

    for (final event in analytics.loggedEvents) {
      if (event.parameters == null) continue;
      for (final key in event.parameters!.keys) {
        for (final pii in _piiStrings) {
          expect(
            key.contains(pii),
            isFalse,
            reason:
                'Event "${event.name}" parameter key "$key" leaked PII: '
                '$pii',
          );
        }
      }
    }
  });

  testWidgets('empty-state analytics never leak PII', (tester) async {
    await tester.pumpWidget(buildSubject());
    streamController.add(const []);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Friend'));
    await tester.pumpAndSettle();

    for (final pii in _piiStrings) {
      expect(
        analytics.containsPii(pii),
        isFalse,
        reason: 'Empty-state CTA leaked PII: $pii',
      );
    }
  });
}
