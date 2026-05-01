// Phone Auth Flow Integration Test
//
// This test runs against the Firebase Auth Emulator. Setup:
//
// 1. Start the Firebase Auth emulator:
//    firebase emulators:start --only auth --project demo-onebytwo
//
// 2. The emulator listens on localhost:9099 by default.
//
// 3. Run this test:
//    firebase emulators:exec --only auth \
//      "flutter test integration_test/" \
//      --project demo-onebytwo
//
// The Firebase Auth emulator auto-completes phone verification
// with the code "123456" for any phone number.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/auth/presentation/phone_entry_screen.dart';

void main() {
  group('Phone Auth Flow (emulator)', () {
    testWidgets('phone entry screen renders', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: PhoneEntryScreen())),
      );

      expect(find.text('Enter your mobile number'), findsOneWidget);
    });
  });
}
