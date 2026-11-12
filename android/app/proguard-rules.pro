# ML Kit
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# flutter_local_notifications — prevent ProGuard from stripping/renaming
# the scheduled notification receivers declared in AndroidManifest.xml
-keep class com.dexterous.** { *; }
