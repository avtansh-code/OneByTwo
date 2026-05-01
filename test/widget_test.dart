import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/presentation/phone_entry_screen.dart';

/// Fake [AnalyticsService] for the smoke test.
class _FakeAnalyticsService implements AnalyticsService {
  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {}
}

void main() {
  testWidgets('app boots and shows the phone entry screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          analyticsServiceProvider.overrideWithValue(_FakeAnalyticsService()),
        ],
        child: const MaterialApp(home: PhoneEntryScreen()),
      ),
    );

    expect(find.text('Enter your mobile number'), findsOneWidget);
  });
}
