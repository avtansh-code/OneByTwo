// Settle Up PII-leak tests (FR-SE-05).
//
// Verifies that no personally-identifiable information leaks into
// analytics events emitted during the Settle Up flow. Replicates the
// assertion shape established by friends_list_pii_leak_test.dart
// (PR #35) and friend_detail_pii_leak_test.dart (PR #42).
//
// PII strings to guard against:
// - Raw friendshipId (composite UID pair) must NEVER appear
// - Individual UIDs that compose the friendshipId
// - Display name fragments
// - Phone numbers
//
// Written test-first; will fail to compile until Step C bottom sheet
// implementation lands.

// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/telemetry/event_id_hash.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/settlements/application/settle_up_telemetry.dart';
import 'package:onebytwo/features/settlements/data/settlement_repository.dart';
import 'package:onebytwo/features/settlements/domain/settlement_doc.dart';
import 'package:onebytwo/features/settlements/presentation/settle_up_bottom_sheet.dart';

const _friendshipId = 'uid-priyalakshmi_uid-rahulagarwal';
const _currentUid = 'uid-priyalakshmi';
const _otherUid = 'uid-rahulagarwal';
const _otherName = 'Priya Lakshmi';

const _piiStrings = [
  // Raw composite friendshipId — must NEVER appear.
  _friendshipId,
  // Individual UIDs.
  _currentUid,
  _otherUid,
  // Display name fragments.
  'Priya',
  'Lakshmi',
  'priyalakshmi',
  'Rahul',
  'Agarwal',
  'rahulagarwal',
  // Phone numbers (even though this flow doesn't render them).
  '+919876543210',
  '9876543210',
];

class FakeSettlementRepository implements SettlementRepository {
  String returnSettlementId = 'sid-priyalakshmi-rahulagarwal-001';

  @override
  Future<String> createSettlement({required SettlementDoc doc}) async {
    return returnSettlementId;
  }

  @override
  Stream<List<SettlementDoc>> watchByContext({
    required String contextType,
    required String contextId,
  }) => const Stream<List<SettlementDoc>>.empty();
}

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

Widget _buildSubject({
  required FakeSettlementRepository repo,
  required FakeAnalyticsService analytics,
}) {
  return ProviderScope(
    overrides: [
      settlementRepositoryProvider.overrideWithValue(repo),
      analyticsServiceProvider.overrideWithValue(analytics),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: SettleUpBottomSheet(
          friendshipId: _friendshipId,
          currentUserUid: _currentUid,
          otherUserUid: _otherUid,
          otherDisplayName: _otherName,
          suggestedAmountPaise: 5000,
        ),
      ),
    ),
  );
}

void main() {
  late FakeSettlementRepository repo;
  late FakeAnalyticsService analytics;

  setUp(() {
    repo = FakeSettlementRepository();
    analytics = FakeAnalyticsService();
  });

  testWidgets('no PII leaks after the screen renders', (tester) async {
    await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));
    await tester.pumpAndSettle();

    for (final pii in _piiStrings) {
      expect(
        analytics.containsPii(pii),
        isFalse,
        reason: 'Settle Up screen leaked PII after first paint: $pii',
      );
    }
  });

  testWidgets('no PII leaks after a successful save', (tester) async {
    await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record Settlement'));
    await tester.pumpAndSettle();

    for (final pii in _piiStrings) {
      expect(
        analytics.containsPii(pii),
        isFalse,
        reason: 'Settle Up flow leaked PII after save: $pii',
      );
    }
  });

  testWidgets(
    'settlement_recorded carries hashed friendship_id_hash + '
    'settlement_id_hash (not raw values)',
    (tester) async {
      await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record Settlement'));
      await tester.pumpAndSettle();

      final recorded = analytics.loggedEvents
          .where((e) => e.name == SettleUpTelemetry.settlementRecorded)
          .toList();
      expect(recorded, hasLength(1));

      final params = recorded.first.parameters!;
      expect(
        params[SettleUpTelemetry.paramFriendshipIdHash],
        equals(hashFriendshipId(_friendshipId)),
      );
      expect(
        params[SettleUpTelemetry.paramSettlementIdHash],
        equals(hashId(repo.returnSettlementId)),
      );

      // Hashed values are length-16 hex strings.
      expect(
        (params[SettleUpTelemetry.paramFriendshipIdHash]! as String).length,
        16,
      );
      expect(
        (params[SettleUpTelemetry.paramSettlementIdHash]! as String).length,
        16,
      );
    },
  );

  testWidgets('screen_viewed carries hashed friendship_id_hash', (
    tester,
  ) async {
    await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));
    await tester.pumpAndSettle();

    final viewed = analytics.loggedEvents
        .where((e) => e.name == SettleUpTelemetry.screenViewed)
        .toList();
    expect(viewed, hasLength(1));

    final params = viewed.first.parameters!;
    expect(
      params[SettleUpTelemetry.paramFriendshipIdHash],
      equals(hashFriendshipId(_friendshipId)),
    );
  });

  testWidgets('no PII in event names', (tester) async {
    await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record Settlement'));
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

  testWidgets('no PII in event parameter keys', (tester) async {
    await tester.pumpWidget(_buildSubject(repo: repo, analytics: analytics));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record Settlement'));
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
}
