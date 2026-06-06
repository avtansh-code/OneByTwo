// Friend Detail PII-leak tests (FR-FR-04).
//
// Asserts no PII leaks into telemetry from the Friend Detail flow.
// Mirrors friends_list_pii_leak_test.dart (PR #35).
//
// Critical: the friendship_id passed to friend_detail_viewed MUST be the
// SHA-256 hash of the raw friendshipId, truncated to 16 hex chars, in
// the `friendship_id_hash` parameter. The raw composite UID-pair string
// must NEVER appear in any analytics event name, parameter key, or
// parameter value.
//
// These tests are written BEFORE the implementation exists (test-first).

// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/telemetry/event_id_hash.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/friends/application/friend_detail_provider.dart';
import 'package:onebytwo/features/friends/presentation/friend_detail_screen.dart';

const _piiStrings = [
  // Raw friendshipId — composed of two UIDs. Must NEVER appear.
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
  // Phone numbers (even though this flow doesn't render them).
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

const _piiArgs = FriendDetailArgs(
  friendshipId: 'uid-priyalakshmi_uid-rahulagarwal',
  currentUserUid: 'uid-rahulagarwal',
  otherUserUid: 'uid-priyalakshmi',
);

Widget _buildSubject({
  required FriendDetailState seedState,
  required FakeAnalyticsService analytics,
}) {
  return ProviderScope(
    overrides: [
      analyticsServiceProvider.overrideWithValue(analytics),
      friendDetailProvider(
        _piiArgs,
      ).overrideWith((ref) => Stream.value(seedState)),
    ],
    child: const MaterialApp(
      home: FriendDetailScreen(
        friendshipId: 'uid-priyalakshmi_uid-rahulagarwal',
        currentUserUid: 'uid-rahulagarwal',
        otherUserUid: 'uid-priyalakshmi',
      ),
    ),
  );
}

void main() {
  late FakeAnalyticsService analytics;

  setUp(() {
    analytics = FakeAnalyticsService();
  });

  testWidgets('friend_detail_viewed carries the hashed friendship_id, never '
      'the raw composite UID', (tester) async {
    const state = FriendDetailStateEmpty(
      header: FriendDetailHeader(
        displayName: 'Priya Lakshmi',
        photoUrl: 'https://photos.example.com/priya.png',
        netBalancePaise: 0,
        balanceState: BalanceState.settled,
      ),
    );

    await tester.pumpWidget(
      _buildSubject(seedState: state, analytics: analytics),
    );
    await tester.pumpAndSettle();

    final viewed = analytics.loggedEvents
        .where((e) => e.name == 'friend_detail_viewed')
        .toList();
    expect(viewed, hasLength(1));

    final params = viewed.first.parameters;
    expect(params, isNotNull);
    expect(params!['friendship_id_hash'], isA<String>());
    expect(
      params['friendship_id_hash'],
      equals(hashFriendshipId('uid-priyalakshmi_uid-rahulagarwal')),
    );
    // The hash is 16 hex chars per the canonical contract.
    expect((params['friendship_id_hash']! as String).length, 16);

    // The raw friendshipId must NOT appear anywhere in the event.
    for (final pii in _piiStrings) {
      expect(
        analytics.containsPii(pii),
        isFalse,
        reason: 'Analytics leaked PII: $pii',
      );
    }
  });

  testWidgets('no PII in analytics event names', (tester) async {
    const state = FriendDetailStateEmpty(
      header: FriendDetailHeader(
        displayName: 'Priya Lakshmi',
        photoUrl: 'https://photos.example.com/priya.png',
        netBalancePaise: 0,
        balanceState: BalanceState.settled,
      ),
    );

    await tester.pumpWidget(
      _buildSubject(seedState: state, analytics: analytics),
    );
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
    const state = FriendDetailStateEmpty(
      header: FriendDetailHeader(
        displayName: 'Priya Lakshmi',
        photoUrl: 'https://photos.example.com/priya.png',
        netBalancePaise: 0,
        balanceState: BalanceState.settled,
      ),
    );

    await tester.pumpWidget(
      _buildSubject(seedState: state, analytics: analytics),
    );
    await tester.pumpAndSettle();

    for (final event in analytics.loggedEvents) {
      if (event.parameters == null) continue;
      for (final key in event.parameters!.keys) {
        for (final pii in _piiStrings) {
          expect(
            key.contains(pii),
            isFalse,
            reason:
                'Event "${event.name}" parameter key "$key" leaked '
                'PII: $pii',
          );
        }
      }
    }
  });
}
