---
description: Build and install a release APK for Belive when `flutter run` debug mode fails
---

# Belive Release APK Build and Install

Use this skill when the Belive Flutter app gets stuck at the splash screen or `flutter run` debug builds fail to push Dart code to the device.

## When to use

- Splash screen is stuck and does not navigate.
- `flutter run` repeatedly fails due to DevFS connection errors on the test device.
- You need a reliable way to run the app on the Nokia G42 5G test device.

## Steps

1. Make sure the project is at `f:\believoo\belive_new` and the Android config has been copied from `e:\uni\belive\android\` (build.gradle.kts, settings.gradle.kts, gradle-wrapper.properties, AndroidManifest.xml, google-services.json).

2. Build the release APK:
   ```powershell
   C:\flutter_new\flutter\bin\flutter.bat build apk --release
   ```

3. Install the APK manually on the device:
   ```powershell
   C:\Users\ajayk\AppData\Local\Android\sdk\platform-tools\adb.exe -s CZQ433H001392025061 install -r -t app-release.apk
   ```

## Why this works

`flutter run` in debug mode uses DevFS to push Dart code to the device. If the DevFS connection drops, only the Flutter engine loads and the Dart code never runs. A release build AOT-compiles the Dart code into the APK, so the app is fully self-contained and does not need a DevFS connection.

## Key files involved

- `lib/main.dart` - `FutureBuilder` for `SessionManager` initialization with fallback.
- `lib/screens/splash/splash_screen.dart` - 2-second timer then `context.go()` for GoRouter navigation.
- `android/app/src/main/kotlin/com/believoo/app/MainActivity.kt` - Simplified; custom asset extraction removed.
