import 'package:flutter/material.dart';

/// The Haldi gradient avatar — a rounded-square marigold→terracotta tile
/// (the `.av` gradient avatars in the design handoff).
///
/// Shows [photoUrl] when it is a non-empty URL, otherwise the uppercase
/// first initial of [displayName] in **white** Bricolage Grotesque. Per the
/// design handoff the avatar initial is white: the "ink on marigold (never
/// white)" contrast rule applies to marigold *buttons* and the FAB, not to
/// this gradient avatar tile, whose deeper terracotta stop keeps a white
/// glyph legible.
///
/// The gradient fill is always painted, so it also serves as the placeholder
/// while a [photoUrl] image is still loading (or if it fails to load).
///
/// Reusable across the app (Home greeting, Profile, friend rows, …); callers
/// pass the desired [size] and the corner radius scales with it
/// (≈ `size × 0.33`, matching the handoff's 14 px radius on a 42 px tile).
class OBTGradientAvatar extends StatelessWidget {
  /// Creates an [OBTGradientAvatar].
  const OBTGradientAvatar({
    required this.size,
    this.displayName,
    this.photoUrl,
    super.key,
  });

  /// The avatar's square edge length in logical pixels.
  final double size;

  /// The user's display name; its first character (uppercased) is the
  /// fallback initial when no [photoUrl] is available.
  final String? displayName;

  /// Cloud Storage download URL for the user's photo. When non-empty the
  /// photo is shown (cover-fit, clipped to the rounded square); otherwise the
  /// initial is rendered.
  final String? photoUrl;

  /// The brand avatar gradient (`#ECA64A → #C75D3C`, top-left to
  /// bottom-right) from the design handoff's `.av` gradient avatars.
  static const LinearGradient _gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFECA64A), Color(0xFFC75D3C)],
  );

  String get _initial {
    final name = displayName?.trim() ?? '';
    if (name.isEmpty) return '?';
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: _gradient,
        borderRadius: BorderRadius.circular(size * 0.33),
        image: hasPhoto
            ? DecorationImage(image: NetworkImage(photoUrl!), fit: BoxFit.cover)
            : null,
      ),
      child: hasPhoto
          ? null
          : Text(
              _initial,
              textAlign: TextAlign.center,
              style: TextStyle(
                // Bricolage Grotesque from the active text theme (the
                // heading family) so the brand display font is reused
                // without a second google_fonts fetch.
                fontFamily: theme.textTheme.displayLarge?.fontFamily,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.4,
                height: 1,
                color: Colors.white,
              ),
            ),
    );
  }
}
