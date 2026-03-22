import 'package:flutter/material.dart';

/// User avatar widget with fallback to initials.
///
/// Displays a circular avatar that:
/// 1. Shows [imageUrl] if it is non-null and non-empty.
/// 2. Falls back to the first one or two initials of [name].
///
/// The initials background color is deterministically derived from [name] so
/// that the same user always gets the same color.
class AvatarWidget extends StatelessWidget {
  /// Creates an [AvatarWidget].
  ///
  /// [name] is the user's display name. [imageUrl] is an optional profile
  /// photo URL. [radius] controls the size of the [CircleAvatar].
  const AvatarWidget({
    super.key,
    this.imageUrl,
    required this.name,
    this.radius = 20,
  });

  /// Optional URL of the user's profile image.
  ///
  /// If `null` or empty, the avatar falls back to initials.
  final String? imageUrl;

  /// The user's display name, used to derive initials and background color.
  final String name;

  /// Radius of the circular avatar in logical pixels.
  ///
  /// Defaults to 20 (diameter = 40).
  final double radius;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return CircleAvatar(
      radius: radius,
      backgroundColor: _backgroundColor(context),
      backgroundImage: hasImage ? NetworkImage(imageUrl!) : null,
      child: hasImage
          ? null
          : Text(
              _initials,
              style: TextStyle(
                fontSize: radius * 0.8,
                fontWeight: FontWeight.w600,
                color: _foregroundColor(context),
              ),
            ),
    );
  }

  /// Extracts up to two initials from [name].
  ///
  /// "Alice Bob" → "AB", "Charlie" → "C", "" → "?".
  String get _initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.first[0].toUpperCase();
  }

  /// Deterministic background color derived from [name].
  Color _backgroundColor(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hash = name.hashCode.abs();
    final hue = (hash % 360).toDouble();
    final brightness = Theme.of(context).brightness;

    return HSLColor.fromAHSL(
      1.0,
      hue,
      brightness == Brightness.light ? 0.4 : 0.3,
      brightness == Brightness.light ? 0.85 : 0.35,
    ).toColor().withAlpha(
      brightness == Brightness.light
          ? 255
          : (colors.surfaceContainerHighest.a * 255.0).round().clamp(0, 255),
    );
  }

  /// Foreground (text) color for the initials.
  Color _foregroundColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final hash = name.hashCode.abs();
    final hue = (hash % 360).toDouble();

    return HSLColor.fromAHSL(
      1.0,
      hue,
      brightness == Brightness.light ? 0.5 : 0.4,
      brightness == Brightness.light ? 0.35 : 0.8,
    ).toColor();
  }
}
