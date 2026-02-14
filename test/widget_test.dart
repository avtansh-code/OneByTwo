import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:one_by_two/core/theme/app_theme.dart';

void main() {
  testWidgets('OneByTwo app smoke test', (WidgetTester tester) async {
    // Build a minimal app (without Firebase) to verify theme and rendering
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          title: 'One By Two',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: const Scaffold(
            body: Center(
              child: Text('One By Two'),
            ),
          ),
        ),
      ),
    );

    // Verify that the app renders successfully
    expect(find.text('One By Two'), findsOneWidget);
  });
}
