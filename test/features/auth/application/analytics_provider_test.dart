import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';

void main() {
  group('sanitiseAnalyticsParameters (D11)', () {
    test('coerces bool values to "true"/"false" strings', () {
      final result = sanitiseAnalyticsParameters(<String, Object>{
        'payer_is_self': true,
        'has_receipt': false,
        'has_notes': false,
        'is_offline': false,
      });

      expect(result, <String, Object>{
        'payer_is_self': 'true',
        'has_receipt': 'false',
        'has_notes': 'false',
        'is_offline': 'false',
      });
    });

    test('passes String and num values through unchanged', () {
      final result = sanitiseAnalyticsParameters(<String, Object>{
        'amount_range': '500_5000',
        'participant_count': 2,
        'receipt_size_bytes': 12345,
      });

      expect(result, <String, Object>{
        'amount_range': '500_5000',
        'participant_count': 2,
        'receipt_size_bytes': 12345,
      });
    });

    test('handles a mixed map without throwing (no String||num assertion)', () {
      final result = sanitiseAnalyticsParameters(<String, Object>{
        'context_type': 'friend',
        'payer_is_self': true,
        'participant_count': 2,
      });

      // Every value must now be String or num — the contract Firebase
      // Analytics asserts on.
      for (final value in result!.values) {
        expect(value is String || value is num, isTrue);
      }
    });

    test('returns null for null input', () {
      expect(sanitiseAnalyticsParameters(null), isNull);
    });
  });
}
