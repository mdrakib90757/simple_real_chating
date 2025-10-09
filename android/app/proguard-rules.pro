
# Flutter-specific rules.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

# Zego Cloud SDK & ZPNS (Zego Push Notification Service) rules
-keep class **.zego.** {*;}
-keep class **.im.zego.** {*;}
-dontwarn **.zego.**
-dontwarn **.im.zego.**


-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken {*;}
-keep class * extends com.google.gson.TypeAdapter

# Firebase-messaging and other common Google libraries
-keep class com.google.firebase.** {*;}
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** {*;}
-dontwarn com.google.android.gms.**

