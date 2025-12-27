# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.

# Keep Google Maps classes
-keep class com.google.android.gms.maps.** { *; }
-keep class com.google.android.gms.location.** { *; }
-keep class com.google.android.gms.common.** { *; }

# Keep Google Play Services
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Keep Google Play Core classes (required by Flutter)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Keep Flutter classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Preserve line numbers for debugging stack traces
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Additional rules for Flutter deferred components - ignore missing classes
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Security: Remove logging in release builds
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

# Keep model classes for JSON serialization
-keep class com.munqeth.app.models.** { *; }
-keep class com.munqeth.app.core.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Parcelable implementations
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep annotations
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions

# ============================================
# Firebase Cloud Messaging (FCM) Rules
# ============================================
# Keep Firebase classes
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Keep Firebase Messaging classes
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.iid.** { *; }

# Keep Firebase Analytics classes
-keep class com.google.firebase.analytics.** { *; }

# Keep Firebase Installations classes (required by FCM)
-keep class com.google.firebase.installations.** { *; }

# Keep Firebase common classes
-keep class com.google.firebase.components.** { *; }

# Keep Firebase Messaging Service
-keep class * extends com.google.firebase.messaging.FirebaseMessagingService {
    *;
}

# Keep Firebase Messaging RemoteMessage
-keep class com.google.firebase.messaging.RemoteMessage { *; }
-keep class com.google.firebase.messaging.RemoteMessage$Notification { *; }

# Keep Firebase Token classes
-keep class com.google.firebase.messaging.FirebaseMessaging { *; }
-keep class com.google.firebase.iid.FirebaseInstanceId { *; }

# Keep Firebase initialization
-keep class com.google.firebase.FirebaseApp { *; }
-keep class com.google.firebase.FirebaseOptions { *; }

# Keep Firebase Messaging background handler
-keep class * implements com.google.firebase.messaging.RemoteMessageReceiver {
    *;
}

# Keep all Firebase-related native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Firebase JSON classes
-keepclassmembers class * {
    @com.google.firebase.messaging.RemoteMessage$Notification *;
}

# Keep Firebase Messaging metadata
-keepattributes *Annotation*,EnclosingMethod,Signature
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# Keep Firebase ProGuard rules from official documentation
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

