import 'package:flutter/material.dart';

import 'package:onebytwo/app/theme.dart';

/// Shape spec for the rows rendered by [OBTSkeletonList].
@immutable
class OBTSkeletonRowSpec {
  /// Creates an [OBTSkeletonRowSpec].
  const OBTSkeletonRowSpec({
    this.height = 56,
    this.leadingDiameter = 40,
    this.lineCount = 2,
  });

  /// Row height (defaults to the 56 dp list-row minimum).
  final double height;

  /// Diameter of the leading circle silhouette (avatar placeholder).
  final double leadingDiameter;

  /// Number of text-line placeholders rendered after the leading circle.
  final int lineCount;
}

/// A single shimmering placeholder block — the one shared loading
/// primitive for the Haldi visual system (foundation plan section 4.2 #1;
/// handoff "skeletons, not spinners").
///
/// The base fill is [ColorScheme.surfaceContainerHighest] with a brighter
/// highlight band sweeping across. The block is purely decorative
/// ([ExcludeSemantics]); host presets ([OBTSkeletonList], [OBTSkeletonRow])
/// carry the single `liveRegion` "Loading…" announcement. Under
/// [MediaQueryData.disableAnimations] the shimmer freezes to a static
/// frame and no animation controller is left running (04 section C.3).
class OBTSkeleton extends StatefulWidget {
  /// Creates an [OBTSkeleton].
  const OBTSkeleton({
    this.width,
    this.height,
    this.borderRadius,
    this.shape,
    super.key,
  });

  /// Optional fixed width; null lets the parent constrain it.
  final double? width;

  /// Optional fixed height; null lets the parent constrain it.
  final double? height;

  /// Corner radius for the rounded-rectangle form; defaults to
  /// [AppTheme.radiusChipInput]. Ignored when [shape] is set.
  final BorderRadiusGeometry? borderRadius;

  /// Optional non-rectangular shape (e.g. a [CircleBorder] for an avatar
  /// silhouette). Overrides [borderRadius] when present.
  final ShapeBorder? shape;

  @override
  State<OBTSkeleton> createState() => _OBTSkeletonState();
}

class _OBTSkeletonState extends State<OBTSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppTheme.motionDurationMedium * 4,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  void _syncAnimation() {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      if (_controller.isAnimating) {
        _controller.stop();
      }
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final base = colors.surfaceContainerHighest;
    final highlight = Color.alphaBlend(
      colors.onSurface.withValues(alpha: 0.05),
      base,
    );
    final radius =
        widget.borderRadius ?? BorderRadius.circular(AppTheme.radiusChipInput);

    return ExcludeSemantics(
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final reduceMotion = MediaQuery.of(context).disableAnimations;
            final gradient = reduceMotion
                ? null
                : LinearGradient(
                    begin: Alignment(_controller.value * 2 - 2, 0),
                    end: Alignment(_controller.value * 2, 0),
                    colors: <Color>[base, highlight, base],
                    stops: const <double>[0.25, 0.5, 0.75],
                  );
            return DecoratedBox(
              decoration: widget.shape != null
                  ? ShapeDecoration(
                      shape: widget.shape!,
                      color: gradient == null ? base : null,
                      gradient: gradient,
                    )
                  : BoxDecoration(
                      borderRadius: radius,
                      color: gradient == null ? base : null,
                      gradient: gradient,
                    ),
            );
          },
        ),
      ),
    );
  }
}

/// A circular [OBTSkeleton] — the donut/avatar silhouette.
class OBTSkeletonCircle extends StatelessWidget {
  /// Creates an [OBTSkeletonCircle] of the given [diameter].
  const OBTSkeletonCircle({required this.diameter, super.key});

  /// The circle diameter in logical pixels.
  final double diameter;

  @override
  Widget build(BuildContext context) {
    return OBTSkeleton(
      width: diameter,
      height: diameter,
      shape: const CircleBorder(),
    );
  }
}

/// A single list-row silhouette: a leading circle plus stacked text-line
/// placeholders. Carries the shared `liveRegion` "Loading…" announcement.
class OBTSkeletonRow extends StatelessWidget {
  /// Creates an [OBTSkeletonRow].
  const OBTSkeletonRow({
    this.spec = const OBTSkeletonRowSpec(),
    this.announce = true,
    super.key,
  });

  /// The row geometry.
  final OBTSkeletonRowSpec spec;

  /// Whether to wrap the row in the `liveRegion` "Loading…" announcement.
  /// Set false when the row is rendered inside an [OBTSkeletonList] that
  /// already announces.
  final bool announce;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: <Widget>[
          OBTSkeletonCircle(diameter: spec.leadingDiameter),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (var i = 0; i < spec.lineCount; i++) ...<Widget>[
                  if (i > 0) const SizedBox(height: 8),
                  OBTSkeleton(height: 12, width: i.isEven ? null : 120),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    if (!announce) {
      return row;
    }
    return Semantics(liveRegion: true, label: 'Loading…', child: row);
  }
}

/// A card-shaped [OBTSkeleton] silhouette for hero/elevated card slots.
class OBTSkeletonCard extends StatelessWidget {
  /// Creates an [OBTSkeletonCard].
  const OBTSkeletonCard({this.height = 120, super.key});

  /// Card height in logical pixels.
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Loading…',
      child: OBTSkeleton(
        height: height,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
    );
  }
}

/// A vertical list of [OBTSkeletonRow] silhouettes, wrapped in a single
/// `liveRegion` "Loading…" announcement. Replaces hand-rolled static list
/// skeletons (activity feed, friends list, spending legend).
class OBTSkeletonList extends StatelessWidget {
  /// Creates an [OBTSkeletonList] of [itemCount] rows.
  const OBTSkeletonList({
    required this.itemCount,
    this.spec = const OBTSkeletonRowSpec(),
    super.key,
  });

  /// Number of placeholder rows to render.
  final int itemCount;

  /// The per-row geometry.
  final OBTSkeletonRowSpec spec;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Loading…',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var i = 0; i < itemCount; i++)
            OBTSkeletonRow(spec: spec, announce: false),
        ],
      ),
    );
  }
}
