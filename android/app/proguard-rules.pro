## Flutter-specific — keep the Flutter engine and plugins intact.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

## The embedding references Play Core's split-install API for deferred
## components. This app has none, so the library is not a dependency and those
## references dangle — R8 fails the build over them unless told they are fine.
-dontwarn com.google.android.play.core.**

## Supabase / GoTrue / Realtime — uses Gson-style reflection under the hood.
-keep class io.supabase.** { *; }
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-dontwarn com.google.errorprone.annotations.**

## flutter_secure_storage — needs the Android Keystore provider classes.
-keep class com.it_nomads.fluttersecurestorage.** { *; }

## flutter_local_notifications — receivers registered in the manifest.
-keep class com.dexterous.flutterlocalnotifications.** { *; }

## Drift / SQLite — the native sqlite3 library must not be stripped.
-keep class org.sqlite.** { *; }
-keep class com.tekartik.** { *; }

## flutter_tts — uses platform channels + reflection.
-keep class com.tundralabs.fluttertts.** { *; }

## camera — keeps CameraX / Camera2 interop.
-keep class io.flutter.plugins.camera.** { *; }

## image_picker
-keep class io.flutter.plugins.imagepicker.** { *; }

## Keep native method names.
-keepclasseswithmembernames class * {
    native <methods>;
}

## Keep enums (Dart interop through platform channels often relies on name()).
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
