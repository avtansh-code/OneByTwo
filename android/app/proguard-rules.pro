# ProGuard rules for One By Two
# Keep Dart and Flutter classes
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Keep annotations
-keepattributes *Annotation*
