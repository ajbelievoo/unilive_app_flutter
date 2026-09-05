# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Agora SDK
-keep class io.agora.** { *; }
-keep class io.agora.rtc.** { *; }
-keep class io.agora.rtm.** { *; }
-dontwarn io.agora.**

# ML Kit
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Facebook login
-keep class com.facebook.** { *; }
-dontwarn com.facebook.**

# Google sign-in
-keep class com.google.android.gms.auth.** { *; }

# Socket.IO
-keep class io.socket.** { *; }
-dontwarn io.socket.**

# Gson/models
-keep class com.believoo.app.models.** { *; }
-keep class **.models.** { *; }

# Keep enum values
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep Parcelable creators
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator CREATOR;
}

# Keep R classes
-keep class **.R { *; }
-keep class **.R$* { *; }

# Keep service providers
-keepattributes ServiceLoader
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# Dio / Dart
-keep class com.believoo.app.** { *; }
