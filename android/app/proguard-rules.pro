# Keep Flutter wrapper and engine
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Handle Google Fonts dynamic loading
-keep class com.google.fonts.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Supabase and typical JSON mapping
-keepattributes Signature,Annotation,EnclosingMethod,InnerClasses
-keep class com.supabase.** { *; }

# General optimizations
-optimizations !code/simplification/arithmetic,!field/*,!class/merging/*
-allowaccessmodification
-mergeinterfacesaggressively

# Strip debug info for smaller release APK
-renamesourcefileattribute SourceFile
-keepattributes !SourceFile,!LineNumberTable

# Obfuscation - Move all classes into a single package for maximum compression
-repackageclasses ''
