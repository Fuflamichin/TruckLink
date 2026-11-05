TruckLink Branding Kit v2
=========================

Sources:
- ALL imagery is derived from the user's supplied splash_logo.png (the SECOND picture, with wordmark).
- The truck, Wi-Fi signal, route and pin are identical across icon and splash.
- The accent has been recolored from mint-green toward the vivid green in the user's FIRST picture.
- splash_logo.png: full transparent logo INCLUDING TruckLink wordmark.
- app_icon.png: identical symbol WITHOUT wordmark on dark background, for launcher icons.
- app_icon_foreground.png: identical symbol WITHOUT wordmark on transparent background, centered for Android adaptive icon.
- android12_splash_icon.png: identical symbol WITHOUT wordmark on transparent background, centered for Android 12+ splash.
- app_icon.ico: Windows launcher icon on dark background.

Copy apps/ into project root (merge folders). Existing app main.dart files are NOT modified.
In apps/mobile: flutter pub add --dev flutter_launcher_icons flutter_native_splash
Then: dart run flutter_launcher_icons
Then: dart run flutter_native_splash:create
Ensure mobile and desktop pubspec.yaml declare assets/branding/splash_logo.png under flutter/assets.
Use the included lib/.../splash_screen.dart from each app for the Flutter in-app splash.

For UI preview/testing, the PNG files have transparency where appropriate; transparent areas may appear black in dark image viewers.
