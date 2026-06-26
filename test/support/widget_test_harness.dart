import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/app/theme.dart';

/// Shared widget-test harness for the DC-03 Haldi shared components.
///
/// Every component test pumps under the real [AppTheme] (light or dark)
/// inside a [testWidgets] zone, so the runtime `google_fonts` fetch is
/// absorbed by the test zone (never build [AppTheme] in a pure `test()`).
///
/// The harness also exposes [expectAllInteractiveNodesLabelled], the
/// 04-qa-test-strategy.md section B.4 gate ("every control is labelled"),
/// applied to each component's populated state.

/// The Haldi reference frame width, mirrored from the golden harness.
const Size kReferenceSurface = Size(390, 844);

/// Pumps [child] under [AppTheme] inside a [MaterialApp] + [Scaffold].
///
/// Optionally applies a [textScale] (for the 2.0x dynamic-type gate,
/// 04 section C), disables animations (reduced-motion, 04 section C.3),
/// and constrains the logical [surfaceSize].
Future<void> pumpThemed(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  bool disableAnimations = false,
  Size surfaceSize = kReferenceSurface,
  bool wrapInScaffold = true,
  bool settle = true,
}) async {
  tester.view.physicalSize = surfaceSize * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);

  final home = wrapInScaffold ? Scaffold(body: child) : child;

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
      home: Builder(
        builder: (context) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: disableAnimations,
            ),
            child: home,
          );
        },
      ),
    ),
  );
  // Components with an always-running shimmer/spin never settle, so callers
  // pass settle: false (and pump a single frame) to avoid a pumpAndSettle
  // timeout. Reduced-motion tests freeze the animation and settle cleanly.
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// Asserts every tappable semantics node carries a non-empty label
/// (04-qa-test-strategy.md section B.4).
///
/// Two layers, because the built-in [labeledTapTargetGuideline] only
/// inspects nodes that expose a tap / long-press action: custom controls
/// that wrap an [InkWell] in `Semantics(button: true, excludeSemantics:
/// true)` carry the button flag but no semantic tap action, so the
/// guideline skips them. The tree walk below additionally requires every
/// button node (that is not a text field) to carry a non-empty label, so
/// a dropped label on a chip / segment is caught. Disabled controls — the
/// inert "Pay via UPI" / "Coming soon" slot — carry no tap action and are
/// asserted separately at their call site (labelled and announced
/// disabled).
Future<void> expectAllInteractiveNodesLabelled(WidgetTester tester) async {
  final handle = tester.ensureSemantics();
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

  final unlabelled = <String>[];
  void visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    final flags = data.flagsCollection;
    if (flags.isButton && !flags.isTextField) {
      final labelled =
          data.label.trim().isNotEmpty ||
          data.tooltip.trim().isNotEmpty ||
          data.value.trim().isNotEmpty;
      if (!labelled) {
        unlabelled.add(data.toString());
      }
    }
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  // Find the root semantics node by traversing the (non-deprecated) root
  // pipeline-owner tree; the actual semantics live in a child owner.
  SemanticsNode? root;
  void searchOwners(PipelineOwner owner) {
    root ??= owner.semanticsOwner?.rootSemanticsNode;
    owner.visitChildren(searchOwners);
  }

  searchOwners(tester.binding.rootPipelineOwner);
  if (root != null) {
    visit(root!);
  }
  expect(
    unlabelled,
    isEmpty,
    reason: 'every button node must carry a non-empty semantic label',
  );
  handle.dispose();
}

/// Asserts every button semantics node meets the minimum tap-target size
/// (accessibility-spec.md; SRS section 5.6).
///
/// Like the labelling guideline, the built-in [androidTapTargetGuideline]
/// only inspects nodes that expose a tap action, so it is defeated by the
/// `Semantics(button: true, excludeSemantics: true)` + [InkWell] pattern
/// (the tap action is excluded). This walk supplements it: every button
/// node that is not a text field must have a rendered hit area of at least
/// [minSize] on both axes.
Future<void> expectAllTapTargetsMeetMinSize(
  WidgetTester tester, {
  double minSize = 48.0,
}) async {
  final handle = tester.ensureSemantics();
  final tooSmall = <String>[];
  void visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    final flags = data.flagsCollection;
    if (flags.isButton && !flags.isTextField) {
      final size = node.rect.size;
      if (size.width < minSize || size.height < minSize) {
        tooSmall.add('"${data.label}" ${size.width}x${size.height}');
      }
    }
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  SemanticsNode? root;
  void searchOwners(PipelineOwner owner) {
    root ??= owner.semanticsOwner?.rootSemanticsNode;
    owner.visitChildren(searchOwners);
  }

  searchOwners(tester.binding.rootPipelineOwner);
  if (root != null) {
    visit(root!);
  }
  expect(
    tooSmall,
    isEmpty,
    reason:
        'every button node must be at least ${minSize}x$minSize dp; '
        'too small: $tooSmall',
  );
  handle.dispose();
}
