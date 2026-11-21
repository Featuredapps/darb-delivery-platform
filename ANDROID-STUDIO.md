# Preparing DARB for Android Studio

The canonical mobile source is stored in `DARB-source.zip`. Current Flutter and Android integration changes are maintained in `mobile-overrides/`. Do not open the repository root as if it were the Flutter app, and do not copy override files manually.

Run on Linux, macOS, or Git Bash with Flutter stable, Java 17, Python 3, unzip, zip, and curl installed:

```bash
bash prepare-android-studio.sh
```

The script creates `DARB-Android-Studio/`, applies the same mobile override set used by the Android release workflow, generates the Android Gradle scaffold with package identity `com.darb.darb`, downloads and bundles the attributed Syrian city images, applies the app-update receiver and FileProvider manifest entries, and prepares Flutter dependencies.

Open the generated `DARB-Android-Studio/` directory in Android Studio — specifically the directory containing `pubspec.yaml`.

The GitHub Actions workflow `Package DARB for Android Studio` runs the preparation, resolves packages, analyzes the Dart sources, builds a debug APK, and uploads both the ZIP and APK as temporary artifacts. It does not use or modify release-signing secrets.
