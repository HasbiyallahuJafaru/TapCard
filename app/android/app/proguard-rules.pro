# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Play Core — Flutter references these for deferred components; we don't use them.
# Suppress missing-class errors from R8 rather than adding the full Play Core dep.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Hive — keep generated adapter names
-keep class com.tapcard.** { *; }

# AdMob
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# Glance
-keep class androidx.glance.** { *; }
