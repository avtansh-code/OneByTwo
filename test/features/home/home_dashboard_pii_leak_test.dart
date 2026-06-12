// Home dashboard PII-leak tests (SCR-06 telemetry).
//
// Verifies that no personally-identifiable information leaks into
// analytics events from the Home dashboard flow. Mirrors the assertion
// shape of `friends_list_pii_leak_test.dart`.
//
// PII strings guarded against: raw friendshipIds (two composed UIDs),
// the individual UIDs, display-name fragments, photo URLs, and phone
// numbers. The `home_settle_up_tapped` and `home_tile_tapped` events
// carry a `context_id_hash`, which MUST be the SHA-256-truncated hash
// of the friendshipId — never the raw composite UID.

// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/telemetry/event_id_hash.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/friends/application/friends_list_provider.dart';
import 'package:onebytwo/features/friends/domain/friend_list_item.dart';
import 'package:onebytwo/features/home/application/home_telemetry.dart';
import 'package:onebytwo/features/home/presentation/home_dashboard_screen.dart';
import 'package:onebytwo/features/settlements/data/settlement_repository.dart';
import 'package:onebytwo/features/settlements/domain/settlement_doc.dart';

const _piiStrings = [
  'uid-priyalakshmi_uid-rahulagarwal',
  'uid-priyalakshmi',
  'uid-rahulagarwal',
  'Priya',
  'Lakshmi',
  'Rahul',
  'Agarwal',
  'https://photos.example.com/priya.png',
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
      final params = event.parameters;
      if (params != null) {
        for (final value in params.values) {
          if (value.toString().contains(pii)) return true;
        }
        for (final key in params.keys) {
          if (key.contains(pii)) return true;
        }
      }
    }
    return false;
  }
}

class FakeSettlementRepository implements SettlementRepository {
  @override
  Future<String> createSettlement({required SettlementDoc doc}) async =>
      'sid-test';

  @override
  Stream<List<SettlementDoc>> watchByContext({
    required String contextType,
    required String contextId,
  }) => const Stream<List<SettlementDoc>>.empty();
}

void main() {
  late FakeAnalyticsService analytics;
  late StreamController<List<FriendListItem>> controller;

  setUp(() {
    analytics = FakeAnalyticsService();
    controller = StreamController<List<FriendListItem>>.broadcast();
  });

  tearDown(() async {
    await controller.close();
  });

  Widget buildSubject() {
    return ProviderScope(
      overrides: [
        analyticsServiceProvider.overrideWithValue(analytics),
        currentUserIdProvider.overrideWithValue('uid-rahulagarwal'),
        friendsListProvider.overrideWith((ref) => controller.stream),
        settlementRepositoryProvider.overrideWithValue(
          FakeSettlementRepository(),
        ),
      ],
      child: const MaterialApp(home: HomeDashboardScreen()),
    );
  }

  const pii = FriendListItem(
    friendshipId: 'uid-priyalakshmi_uid-rahulagarwal',
    otherUserId: 'uid-priyalakshmi',
    displayName: 'Priya Lakshmi',
    photoUrl: 'https://photos.example.com/priya.png',
    netBalancePaise: 12345,
  );

  testWidgets('no PII after viewing the populated dashboard', (tester) async {
    await tester.pumpWidget(buildSubject());
    controller.add(const [pii]);
    await tester.pumpAndSettle();

    for (final p in _piiStrings) {
      expect(analytics.containsPii(p), isFalse, reason: 'leaked PII: $p');
    }
  });

  testWidgets('home_tile_tapped context_id is hashed, not raw', (tester) async {
    await tester.pumpWidget(buildSubject());
    controller.add(const [pii]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Priya Lakshmi'));
    await tester.pumpAndSettle();

    final tile = analytics.loggedEvents
        .where((e) => e.name == HomeTelemetry.tileTapped)
        .toList();
    expect(tile, hasLength(1));
    expect(
      tile.first.parameters![HomeTelemetry.paramContextIdHash],
      hashFriendshipId('uid-priyalakshmi_uid-rahulagarwal'),
    );

    for (final p in _piiStrings) {
      expect(analytics.containsPii(p), isFalse, reason: 'leaked PII: $p');
    }
  });

  testWidgets('home_settle_up_tapped context_id is hashed, not raw', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    controller.add(const [pii]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settle Up'));
    await tester.pumpAndSettle();

    final settle = analytics.loggedEvents
        .where((e) => e.name == HomeTelemetry.settleUpTapped)
        .toList();
    expect(settle, hasLength(1));
    expect(
      settle.first.parameters![HomeTelemetry.paramContextIdHash],
      hashFriendshipId('uid-priyalakshmi_uid-rahulagarwal'),
    );

    for (final p in _piiStrings) {
      expect(analytics.containsPii(p), isFalse, reason: 'leaked PII: $p');
    }
  });

  testWidgets('no PII in any event name or parameter key', (tester) async {
    await tester.pumpWidget(buildSubject());
    controller.add(const [pii]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Priya Lakshmi'));
    await tester.pumpAndSettle();

    for (final event in analytics.loggedEvents) {
      for (final p in _piiStrings) {
        expect(event.name.contains(p), isFalse);
        if (event.parameters != null) {
          for (final key in event.parameters!.keys) {
            expect(key.contains(p), isFalse);
          }
        }
      }
    }
  });
}
