// Settlement history telemetry-constant tests (FR-SE-08 / SCR-24).
//
// Locks the two pre-declared event names and the parameter-key /
// enum-token constants against the telemetry-plan §1.3 contract. The
// authoritative source is `docs/design/07-technical/telemetry-plan.md`
// §1.3:
//   settlement_history_viewed { context_type, item_count }
//   settlement_history_error  { error_code, context_type }
// NEITHER event carries context_id (PII guard, ADR-0013).

import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/settlements/application/settlement_history_telemetry.dart';

void main() {
  group('SettlementHistoryTelemetry — event names', () {
    test('viewedEvent matches the telemetry-plan contract', () {
      expect(
        SettlementHistoryTelemetry.viewedEvent,
        'settlement_history_viewed',
      );
    });

    test('errorEvent matches the telemetry-plan contract', () {
      expect(SettlementHistoryTelemetry.errorEvent, 'settlement_history_error');
    });
  });

  group('SettlementHistoryTelemetry — parameter keys', () {
    test('paramContextType is context_type', () {
      expect(SettlementHistoryTelemetry.paramContextType, 'context_type');
    });

    test('paramItemCount is item_count', () {
      expect(SettlementHistoryTelemetry.paramItemCount, 'item_count');
    });

    test('paramErrorCode is error_code', () {
      expect(SettlementHistoryTelemetry.paramErrorCode, 'error_code');
    });

    test('there is NO context_id parameter constant (PII guard)', () {
      // Defence-in-depth: the contract deliberately omits context_id.
      // Assert none of the declared parameter keys is 'context_id'.
      const declaredParamKeys = <String>[
        SettlementHistoryTelemetry.paramContextType,
        SettlementHistoryTelemetry.paramItemCount,
        SettlementHistoryTelemetry.paramErrorCode,
      ];
      expect(declaredParamKeys, isNot(contains('context_id')));
    });
  });

  group('SettlementHistoryTelemetry — context-type tokens', () {
    test('contextTypeFriendship is friendship', () {
      expect(SettlementHistoryTelemetry.contextTypeFriendship, 'friendship');
    });

    test('contextTypeGroup is group', () {
      expect(SettlementHistoryTelemetry.contextTypeGroup, 'group');
    });
  });
}
