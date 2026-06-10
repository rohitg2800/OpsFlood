# OpsFlood — ProGuard / R8 rules
# Module 9: Release Hardening
# ============================================================

# ── Flutter engine
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# ── Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ── Firebase Messaging (FCM)
-keep class com.google.firebase.messaging.** { *; }

# ── Hive
-keep class com.hivedb.** { *; }
-keep @com.hive.annotations.HiveType class * { *; }
-keep @com.hive.annotations.HiveField class * { *; }

# ── Kotlin coroutines / stdlib
-keep class kotlin.** { *; }
-dontwarn kotlin.**
-keepclassmembers class kotlinx.** { *; }

# ── OkHttp / Retrofit (used by dio under the hood on Android)
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# ── Dio
-keep class com.dio.** { *; }

# ── pdf / printing plugin (dart:ffi JNI bridge)
-keep class com.zynsoft.** { *; }
-keep class com.pdf.** { *; }

# ── flutter_local_notifications
-keep class com.dexterous.** { *; }

# ── Riverpod (pure Dart — no Java classes, but keep annotations)
-keepattributes *Annotation*

# ── Prevent stripping of native crash reporter
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# ── Gzip / JSON serialisation
-keep class org.json.** { *; }

# ── Generic
-keepattributes Signature
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes EnclosingMethod
