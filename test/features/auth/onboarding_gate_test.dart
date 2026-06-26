// Onboarding first-launch gate tests (DC-04).
//
// Reproduces the auth gate's `AuthUnauthenticated` arm (which renders
// onboarding until the persisted "seen" flag flips, then phone entry) to
// prove first-launch gating without Firebase: onboarding shows once,
// Skip and "Get started" set the persisted flag and route to phone entry,
// and a returning user goes straight to phone entry.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/persistence/preference_keys.dart';
import 'package:onebytwo/core/services/key_value_store.dart';
import 'package:onebytwo/core/services/url_launcher_service.dart';
import 'package:onebytwo/features/auth/application/onboarding_provider.dart';
import 'package:onebytwo/features/auth/presentation/onboarding_screen.dart';

class _NoopUrlLauncher implements UrlLauncherService {
  @override
  Future<bool> canLaunch(Uri uri) async => true;

  @override
  Future<bool> launchExternal(Uri uri) async => true;
}

/// A stand-in for the gate's `AuthUnauthenticated` arm. Renders onboarding
/// until the persisted "seen" flag flips, then the phone-entry marker —
/// exactly the branch in `OneBytwoApp.build`.
class _Gate extends ConsumerWidget {
  const _Gate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(hasSeenOnboardingProvider)
        ? const Scaffold(body: Center(child: Text('phone-entry-marker')))
        : const OnboardingScreen();
  }
}

Future<void> _pumpGate(WidgetTester tester, KeyValueStore store) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        urlLauncherServiceProvider.overrideWithValue(_NoopUrlLauncher()),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const _Gate()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('Onboarding first-launch gate', () {
    testWidgets('first launch shows onboarding, not phone entry', (
      tester,
    ) async {
      await _pumpGate(tester, InMemoryKeyValueStore());

      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('Track every shared spend'), findsOneWidget);
      expect(find.text('phone-entry-marker'), findsNothing);
    });

    testWidgets('Skip sets the seen flag and routes to phone entry', (
      tester,
    ) async {
      final store = InMemoryKeyValueStore();
      await _pumpGate(tester, store);

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('phone-entry-marker'), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(store.getBool(PreferenceKeys.hasSeenOnboarding), isTrue);
    });

    testWidgets('Get started sets the seen flag and routes to phone entry', (
      tester,
    ) async {
      final store = InMemoryKeyValueStore();
      await _pumpGate(tester, store);

      // Advance to the final slide where "Get started" lives.
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();

      expect(find.text('phone-entry-marker'), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(store.getBool(PreferenceKeys.hasSeenOnboarding), isTrue);
    });

    testWidgets('a returning user goes straight to phone entry', (
      tester,
    ) async {
      final store = InMemoryKeyValueStore();
      await store.setBool(PreferenceKeys.hasSeenOnboarding, value: true);

      await _pumpGate(tester, store);

      expect(find.text('phone-entry-marker'), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
    });
  });
}
