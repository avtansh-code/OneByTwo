// Onboarding screen tests (DC-04, Haldi 2 — net-new).
//
// Covers the three slides, Skip / next-FAB / "Get started" controls, the
// Terms & Privacy links (launched through the url-launcher seam), the
// labelling + 48 dp accessibility gate, dynamic type to 2.0x, the
// reduced-motion paging fallback, and light + dark rendering.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/constants/legal_urls.dart';
import 'package:onebytwo/core/persistence/preference_keys.dart';
import 'package:onebytwo/core/services/key_value_store.dart';
import 'package:onebytwo/core/services/url_launcher_service.dart';
import 'package:onebytwo/core/widgets/branding/obt_brand.dart';
import 'package:onebytwo/features/auth/presentation/onboarding_screen.dart';

import '../../support/widget_test_harness.dart';

class _FakeUrlLauncher implements UrlLauncherService {
  final List<Uri> launched = <Uri>[];

  @override
  Future<bool> canLaunch(Uri uri) async => true;

  @override
  Future<bool> launchExternal(Uri uri) async {
    launched.add(uri);
    return true;
  }
}

/// A launcher with no handler (canLaunch false) — exercises the fallback.
class _FailingUrlLauncher implements UrlLauncherService {
  @override
  Future<bool> canLaunch(Uri uri) async => false;

  @override
  Future<bool> launchExternal(Uri uri) async => false;
}

Future<void> _pumpOnboarding(
  WidgetTester tester, {
  required KeyValueStore store,
  required UrlLauncherService launcher,
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  bool disableAnimations = false,
  Size surfaceSize = const Size(390, 844),
}) async {
  tester.view.physicalSize = surfaceSize * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        keyValueStoreProvider.overrideWithValue(store),
        urlLauncherServiceProvider.overrideWithValue(launcher),
      ],
      child: MaterialApp(
        theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
        home: Builder(
          builder: (context) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                textScaler: TextScaler.linear(textScale),
                disableAnimations: disableAnimations,
              ),
              child: const OnboardingScreen(),
            );
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Taps the next-FAB until the final slide, where "Get started" appears.
Future<void> _advanceToFinalSlide(WidgetTester tester) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late InMemoryKeyValueStore store;
  late _FakeUrlLauncher launcher;

  setUp(() {
    store = InMemoryKeyValueStore();
    launcher = _FakeUrlLauncher();
  });

  group('OnboardingScreen', () {
    testWidgets('first slide shows Track, Skip, and the next-FAB', (
      tester,
    ) async {
      await _pumpOnboarding(tester, store: store, launcher: launcher);

      expect(find.text('Track every shared spend'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      // The terminal CTA is not on the first slide.
      expect(find.text('Get started'), findsNothing);
    });

    testWidgets('advances Track -> Split -> Settle with the ÷ mark on Split', (
      tester,
    ) async {
      await _pumpOnboarding(tester, store: store, launcher: launcher);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('Split it any way you like'), findsOneWidget);
      // The Split slide shows the brand ÷ mark (no icon).
      expect(find.byType(OBTBrandMark), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('Settle up in a single tap'), findsOneWidget);
    });

    testWidgets('final slide shows Get started, Terms/Privacy, and no Skip', (
      tester,
    ) async {
      await _pumpOnboarding(tester, store: store, launcher: launcher);
      await _advanceToFinalSlide(tester);

      expect(find.text('Get started'), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      // Skip and the next-FAB give way to the CTA on the terminal slide.
      expect(find.text('Skip'), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('Skip marks onboarding seen', (tester) async {
      await _pumpOnboarding(tester, store: store, launcher: launcher);

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(store.getBool(PreferenceKeys.hasSeenOnboarding), isTrue);
    });

    testWidgets('Get started marks onboarding seen', (tester) async {
      await _pumpOnboarding(tester, store: store, launcher: launcher);
      await _advanceToFinalSlide(tester);

      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();

      expect(store.getBool(PreferenceKeys.hasSeenOnboarding), isTrue);
    });

    testWidgets('Terms link launches the terms-of-service URL', (tester) async {
      await _pumpOnboarding(tester, store: store, launcher: launcher);
      await _advanceToFinalSlide(tester);

      await tester.tap(find.text('Terms of Service'));
      await tester.pumpAndSettle();

      expect(launcher.launched, contains(Uri.parse(LegalUrls.termsOfService)));
    });

    testWidgets('Privacy link launches the privacy-policy URL', (tester) async {
      await _pumpOnboarding(tester, store: store, launcher: launcher);
      await _advanceToFinalSlide(tester);

      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();

      expect(launcher.launched, contains(Uri.parse(LegalUrls.privacyPolicy)));
    });

    testWidgets('a failed link launch shows a fallback SnackBar with the URL', (
      tester,
    ) async {
      final failing = _FailingUrlLauncher();
      await _pumpOnboarding(tester, store: store, launcher: failing);
      await _advanceToFinalSlide(tester);

      await tester.tap(find.text('Terms of Service'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining(LegalUrls.termsOfService), findsOneWidget);
    });

    testWidgets('first slide: every control is labelled and >= 48 dp', (
      tester,
    ) async {
      await _pumpOnboarding(tester, store: store, launcher: launcher);

      await expectAllInteractiveNodesLabelled(tester);
      await expectAllTapTargetsMeetMinSize(tester);
    });

    testWidgets('final slide: every control is labelled and >= 48 dp', (
      tester,
    ) async {
      await _pumpOnboarding(tester, store: store, launcher: launcher);
      await _advanceToFinalSlide(tester);

      await expectAllInteractiveNodesLabelled(tester);
      await expectAllTapTargetsMeetMinSize(tester);
    });

    testWidgets('no overflow at 2.0x dynamic type (390 and 320 width)', (
      tester,
    ) async {
      await _pumpOnboarding(
        tester,
        store: store,
        launcher: launcher,
        textScale: 2,
      );
      expect(tester.takeException(), isNull);

      await _pumpOnboarding(
        tester,
        store: store,
        launcher: launcher,
        textScale: 2,
        surfaceSize: const Size(320, 844),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('final slide: no overflow at 2.0x dynamic type (320 width)', (
      tester,
    ) async {
      await _pumpOnboarding(
        tester,
        store: store,
        launcher: launcher,
        textScale: 2,
        surfaceSize: const Size(320, 844),
      );
      await _advanceToFinalSlide(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion jumps between slides', (tester) async {
      await _pumpOnboarding(
        tester,
        store: store,
        launcher: launcher,
        disableAnimations: true,
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      expect(find.text('Split it any way you like'), findsOneWidget);
    });

    testWidgets('renders in dark theme', (tester) async {
      await _pumpOnboarding(
        tester,
        store: store,
        launcher: launcher,
        brightness: Brightness.dark,
      );

      expect(find.text('Track every shared spend'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
    });
  });
}
