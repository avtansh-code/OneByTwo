// SettlementCreateError tests (FR-SE-05).
//
// Tests the typed error returned by `SettlementRepository.createSettlement`
// on failure. Mirrors ExpenseCreateError 1:1 — each SettlementCreateErrorType
// enum value maps to a user-facing message via the canonical
// `userFacingMessage` getter, and the exception carries the original
// FirebaseException for observability.
//
// Written test-first; will fail to compile until the implementation
// (Step A) lands.

// ignore_for_file: cascade_invocations

import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/settlements/domain/settlement_create_error.dart';

void main() {
  group('SettlementCreateErrorType enum', () {
    test('has exactly five values (permissionDenied, network, '
        'balanceChanged, invalidAmount, unknown)', () {
      expect(SettlementCreateErrorType.values, hasLength(5));
      expect(
        SettlementCreateErrorType.values.toSet(),
        equals({
          SettlementCreateErrorType.permissionDenied,
          SettlementCreateErrorType.network,
          SettlementCreateErrorType.balanceChanged,
          SettlementCreateErrorType.invalidAmount,
          SettlementCreateErrorType.unknown,
        }),
      );
    });
  });

  group('SettlementCreateError construction', () {
    test('preserves the type and underlying error', () {
      final cause = Exception('firestore failed');
      final err = SettlementCreateError(
        type: SettlementCreateErrorType.permissionDenied,
        underlying: cause,
      );
      expect(err.type, SettlementCreateErrorType.permissionDenied);
      expect(err.underlying, same(cause));
    });

    test('toString includes the type name', () {
      final err = SettlementCreateError(
        type: SettlementCreateErrorType.network,
      );
      expect(err.toString(), contains('network'));
    });

    test('is an Exception subtype', () {
      const err = SettlementCreateError(
        type: SettlementCreateErrorType.unknown,
      );
      expect(err, isA<Exception>());
    });
  });

  group('userFacingMessage', () {
    test('permissionDenied → "Couldn\'t record the settlement..."', () {
      expect(
        SettlementCreateErrorType.permissionDenied.userFacingMessage,
        "Couldn't record the settlement. Please try again.",
      );
    });

    test('network → offline-aware copy', () {
      expect(
        SettlementCreateErrorType.network.userFacingMessage,
        "You're offline. The settlement will be recorded when you reconnect.",
      );
    });

    test('balanceChanged → conflict copy', () {
      expect(
        SettlementCreateErrorType.balanceChanged.userFacingMessage,
        contains('balance'),
      );
    });

    test('invalidAmount → rule-friendly copy', () {
      expect(
        SettlementCreateErrorType.invalidAmount.userFacingMessage,
        contains('amount'),
      );
    });

    test('unknown → generic fallback', () {
      expect(
        SettlementCreateErrorType.unknown.userFacingMessage,
        "Couldn't record the settlement. Please try again.",
      );
    });
  });

  group('telemetryErrorCode', () {
    test('permissionDenied → "permission_denied"', () {
      expect(
        SettlementCreateErrorType.permissionDenied.telemetryErrorCode,
        'permission_denied',
      );
    });

    test('network → "network"', () {
      expect(
        SettlementCreateErrorType.network.telemetryErrorCode,
        'network',
      );
    });

    test('balanceChanged → "balance_changed"', () {
      expect(
        SettlementCreateErrorType.balanceChanged.telemetryErrorCode,
        'balance_changed',
      );
    });

    test('invalidAmount → "invalid_amount"', () {
      expect(
        SettlementCreateErrorType.invalidAmount.telemetryErrorCode,
        'invalid_amount',
      );
    });

    test('unknown → "unknown"', () {
      expect(
        SettlementCreateErrorType.unknown.telemetryErrorCode,
        'unknown',
      );
    });
  });
}
