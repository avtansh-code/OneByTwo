import 'package:flutter/material.dart';

import 'package:onebytwo/core/theme/obt_colors.dart';

/// The "One By Two" division mark — a ÷ glyph drawn as a centre bar with
/// a dot above and below (foundation plan section 4.2 #13).
///
/// Defaults to [ColorScheme.primary] (marigold). On a marigold fill pass
/// the **ink** [ColorScheme.onPrimary] as [color] — never white.
class OBTBrandMark extends StatelessWidget {
  /// Creates an [OBTBrandMark].
  const OBTBrandMark({this.size = 64, this.color, super.key});

  /// The mark's square edge length in logical pixels.
  final double size;

  /// The glyph colour; defaults to [ColorScheme.primary].
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final markColor = color ?? Theme.of(context).colorScheme.primary;
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _DivisionMarkPainter(markColor),
      ),
    );
  }
}

class _DivisionMarkPainter extends CustomPainter {
  const _DivisionMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final w = size.width;
    final h = size.height;
    final dotRadius = w * 0.09;
    final barWidth = w * 0.62;
    final barHeight = h * 0.11;

    // Centre bar.
    final barRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w / 2, h / 2),
        width: barWidth,
        height: barHeight,
      ),
      Radius.circular(barHeight / 2),
    );
    canvas
      ..drawRRect(barRect, paint)
      // Dot above and below.
      ..drawCircle(Offset(w / 2, h * 0.27), dotRadius, paint)
      ..drawCircle(Offset(w / 2, h * 0.73), dotRadius, paint);
  }

  @override
  bool shouldRepaint(_DivisionMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// The "One**By**Two" wordmark — Bricolage display type with the "By"
/// accent in the brand token, or a single ink colour on a marigold fill.
class OBTWordmark extends StatelessWidget {
  /// Creates an [OBTWordmark].
  const OBTWordmark({this.style, this.color, super.key});

  /// Optional override for the base text style; defaults to the Bricolage
  /// `headlineLarge` slot.
  final TextStyle? style;

  /// Optional single colour for the whole wordmark. Pass the **ink**
  /// `onPrimary` on a marigold fill (the "By" accent is dropped so it does
  /// not vanish on marigold). When null, "One"/"Two" take
  /// [ColorScheme.onSurface] and "By" the brand accent.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;
    final base = style ?? theme.textTheme.headlineLarge ?? const TextStyle();
    final wordColor = color ?? theme.colorScheme.onSurface;
    final accentColor = color ?? obtColors.primaryPressed;
    final wordStyle = base.copyWith(color: wordColor);
    final accentStyle = base.copyWith(color: accentColor);

    return Semantics(
      label: 'One By Two',
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(
            children: <TextSpan>[
              TextSpan(text: 'One', style: wordStyle),
              TextSpan(text: 'By', style: accentStyle),
              TextSpan(text: 'Two', style: wordStyle),
            ],
          ),
        ),
      ),
    );
  }
}

/// The brand lockup — the [OBTBrandMark] above (or beside) the
/// [OBTWordmark], carrying a single "One By Two" semantic label.
class OBTBrandLockup extends StatelessWidget {
  /// Creates an [OBTBrandLockup].
  const OBTBrandLockup({
    this.direction = Axis.vertical,
    this.markSize = 80,
    this.color,
    super.key,
  });

  /// Whether the mark stacks above (vertical) or beside (horizontal) the
  /// wordmark.
  final Axis direction;

  /// The brand mark size.
  final double markSize;

  /// Optional mark colour override (e.g. ink on a marigold splash).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final mark = OBTBrandMark(size: markSize, color: color);
    const gap = SizedBox(width: 16, height: 16);
    final wordmark = OBTWordmark(color: color);

    return Semantics(
      label: 'One By Two',
      child: ExcludeSemantics(
        child: direction == Axis.vertical
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[mark, gap, wordmark],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[mark, gap, wordmark],
              ),
      ),
    );
  }
}

/// Full-bleed marigold splash backdrop — a [ColorScheme.primary] →
/// [OBTColors.primaryPressed] gradient with **ink** foreground (never
/// white). Hosts the splash brand lockup; the gradient is decorative.
class OBTSplashGradient extends StatelessWidget {
  /// Creates an [OBTSplashGradient] wrapping [child].
  const OBTSplashGradient({required this.child, super.key});

  /// The foreground content (typically an [OBTBrandLockup]).
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final obtColors =
        Theme.of(context).extension<OBTColors>() ?? OBTColors.light;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[colors.primary, obtColors.primaryPressed],
        ),
      ),
      child: Center(child: child),
    );
  }
}
