OneByTwo — App Icon export
==========================

iOS
  ios/AppIcon.appiconset/  — drop straight into Xcode's asset catalog.
  Square, fully opaque, no alpha (iOS applies the corner mask itself).

Android
  android/mipmap-anydpi-v26/ic_launcher.xml  — adaptive icon descriptor.
  android/mipmap-*/ic_launcher_foreground.png — ÷ mark, transparent, safe zone.
  android/mipmap-*/ic_launcher_background.png — marigold gradient, full bleed.
  android/mipmap-*/ic_launcher.png / _round.png — legacy pre-masked fallbacks.
  android/play-store-512.png — Play Console listing icon (512x512).

Mark: division sign (two dots, one bar). Cream #FFFBF2 on a marigold
radial gradient (#F6BD63 -> #E69234 -> #CF6E16).
