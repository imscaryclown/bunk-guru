# ML Kit
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# flutter_local_notifications — prevent ProGuard from stripping/renaming
# the scheduled notification receivers declared in AndroidManifest.xml
-keep class com.dexterous.** { *; }

# GSON rules required for R8 full mode (AGP 8+/9+)
# flutter_local_notifications serializes scheduled alarms via Gson TypeToken.
# Without these, R8 strips generic signatures causing "Missing type parameter" crashes.
-keepattributes Signature, InnerClasses, EnclosingMethod
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
