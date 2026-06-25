import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:onebytwo/app/theme.dart';

/// The Haldi reference frame: 390 x 844 logical pixels (handoff section
/// "Shape, elevation, spacing").
const Size kGoldenLogicalSize = Size(390, 844);

/// The device pixel ratio golden baselines are captured at.
const double kGoldenDevicePixelRatio = 3;

/// Makes Bricolage Grotesque and Hanken Grotesk available locally so
/// golden bytes are deterministic offline.
///
/// `google_fonts` fetches at runtime by default, which is non-deterministic
/// and fails offline in CI. DC-13 (the `golden-a11y-checks` job on
/// `ubuntu-latest`) bundles the two families' `.ttf` as test assets and
/// loads them through a `FontLoader` here. Until that job lands the golden
/// suite is skipped, so this only disables runtime fetching.
Future<void> loadHaldiFonts() async {
  GoogleFonts.config.allowRuntimeFetching = false;
}

/// Pumps [child] inside a [MaterialApp] using the real Haldi theme at the
/// pinned Haldi reference frame and density, resetting the view on
/// teardown. Use for golden capture so every baseline shares one surface
/// size and rasteriser (04-qa-test-strategy.md section A.2).
Future<void> pumpForGolden(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = kGoldenLogicalSize * kGoldenDevicePixelRatio;
  tester.view.devicePixelRatio = kGoldenDevicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}
