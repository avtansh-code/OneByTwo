import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as google_fonts_base;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:onebytwo/app/theme.dart';

/// The Haldi reference frame: 390 x 844 logical pixels (handoff section
/// "Shape, elevation, spacing").
const Size kGoldenLogicalSize = Size(390, 844);

/// The device pixel ratio golden baselines are captured at.
const double kGoldenDevicePixelRatio = 3;

/// Maps each Google Fonts gstatic file hash (the URL `google_fonts` 6.3.3
/// requests for the Haldi regular faces) to the bundled OFL `.ttf` that
/// satisfies its length + checksum guard.
///
/// The bundled files are the exact static `Regular` instances `google_fonts`
/// expects, so the offline mock below serves real bytes and the families load
/// and cache instead of falling back. If `google_fonts` is upgraded these
/// hashes change and the load fails loudly (a golden diff), prompting a
/// refresh of the bundled files.
const _fontFileByHash = <String, String>{
  '2d910251022c851e26d045b9202776cf98dd15af8e539ebbda16503332a2b016':
      'test/golden/fonts/BricolageGrotesque-Regular.ttf',
  '956414e58193ccf0e310474863f25057523ad3572d5c9d6ba75ddf77b3babf12':
      'test/golden/fonts/HankenGrotesk-Regular.ttf',
};

bool _fontsLoaded = false;

/// Loads Bricolage Grotesque and Hanken Grotesk so golden bytes are
/// deterministic offline.
///
/// `app/theme.dart` builds its `TextTheme` from `GoogleFonts`, which fetches
/// over the network by default — non-deterministic and blocked in tests —
/// while disabling fetching makes it throw. Instead the bundled OFL `.ttf`
/// are served through the package's `@visibleForTesting` http seam so the
/// real faces load and cache once; the theme then resolves the real Haldi
/// type ramp rather than the platform fallback, and no font request escapes
/// to the network.
Future<void> loadHaldiFonts() async {
  if (_fontsLoaded) {
    return;
  }
  // google_fonts caches a fetched face to the path_provider support directory;
  // that plugin is not registered in tests, so its method channel is stubbed
  // to a temp directory to keep the (fire-and-forget) save from surfacing as a
  // late unhandled error.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => Directory.systemTemp.path,
      );
  GoogleFonts.config.allowRuntimeFetching = true;
  google_fonts_base.httpClient = MockClient((request) async {
    final hash = request.url.pathSegments.last.replaceAll('.ttf', '');
    final path = _fontFileByHash[hash];
    if (path == null) {
      return http.Response('unexpected font request: ${request.url}', 404);
    }
    return http.Response.bytes(await File(path).readAsBytes(), 200);
  });
  await GoogleFonts.pendingFonts(<TextStyle>[
    GoogleFonts.bricolageGrotesque(),
    GoogleFonts.hankenGrotesk(),
  ]);
  // Material Icons (uses-material-design) so `Icon` glyphs render as their real
  // shapes rather than the test fallback box.
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  _fontsLoaded = true;
}

/// Pumps [child] inside a [MaterialApp] using the real Haldi theme at the
/// pinned Haldi reference frame and density, then settles.
///
/// Rendering runs under reduced motion (`disableAnimations`) so shimmer
/// skeletons and entrance staggers freeze to a stable frame and never leave
/// a running ticker (04-qa-test-strategy.md sections A.2.5 / C.3); a teardown
/// also unmounts the tree so any screen-scheduled timer (splash countdown,
/// OTP resend) is cancelled in `dispose` and leaves nothing pending. The view
/// size and density are reset on teardown so every baseline shares one
/// surface and rasteriser (section A.2).
Future<void> pumpForGolden(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = kGoldenLogicalSize * kGoldenDevicePixelRatio;
  tester.view.devicePixelRatio = kGoldenDevicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
      builder: (context, inner) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: inner!,
      ),
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}
