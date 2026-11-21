#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${DARB_WORK_DIR:-$ROOT/.darb-android-studio-work}"
OUT_DIR="${1:-$ROOT/DARB-Android-Studio}"
SOURCE_DIR="$WORK_DIR/extracted/darb-project"
MOBILE_DIR="$SOURCE_DIR/mobile"
OVERRIDES="$ROOT/mobile-overrides"

for required in \
  "$ROOT/DARB-source.zip" \
  "$OVERRIDES/main.dart" \
  "$OVERRIDES/login_screen.dart" \
  "$OVERRIDES/city_carousel.dart" \
  "$OVERRIDES/prepare_city_assets.sh" \
  "$OVERRIDES/MainActivity.kt" \
  "$OVERRIDES/DarbUpdateDownloadReceiver.kt"; do
  if [ ! -s "$required" ]; then
    echo "Required project input is missing: $required" >&2
    exit 1
  fi
done

rm -rf "$WORK_DIR" "$OUT_DIR"
mkdir -p "$WORK_DIR/extracted"
unzip -q "$ROOT/DARB-source.zip" -d "$WORK_DIR/extracted"

if [ ! -s "$MOBILE_DIR/pubspec.yaml" ] || [ ! -s "$MOBILE_DIR/lib/main.dart" ]; then
  echo "DARB-source.zip does not contain the expected Flutter mobile project." >&2
  exit 1
fi

# Keep the Android project already shipped with DARB. Regenerating it with
# flutter create can overwrite Firebase, OAuth, signing, Gradle and package
# configuration needed by the installed application and in-place updates.
if [ ! -s "$MOBILE_DIR/android/app/src/main/AndroidManifest.xml" ]; then
  echo "The source archive is missing its AndroidManifest.xml; refusing to generate a replacement." >&2
  exit 1
fi
if [ ! -f "$MOBILE_DIR/android/app/build.gradle" ] && [ ! -f "$MOBILE_DIR/android/app/build.gradle.kts" ]; then
  echo "The source archive is missing the Android app Gradle file." >&2
  exit 1
fi

GRADLE_FILE="$MOBILE_DIR/android/app/build.gradle"
[ -f "$GRADLE_FILE" ] || GRADLE_FILE="$MOBILE_DIR/android/app/build.gradle.kts"
if ! grep -Eq "applicationId[[:space:]]*(=[[:space:]]*)?['\"]com\\.darb\\.darb['\"]" "$GRADLE_FILE"; then
  echo "The existing Android applicationId is not confirmed as com.darb.darb. Refusing to change the installed app identity." >&2
  exit 1
fi

mkdir -p "$MOBILE_DIR/lib/screens" "$MOBILE_DIR/lib/core"
mkdir -p "$MOBILE_DIR/android/app/src/main/kotlin/com/darb/darb"
mkdir -p "$MOBILE_DIR/android/app/src/main/res/xml"
mkdir -p "$MOBILE_DIR/android/app/src/main/res/drawable"

cp "$OVERRIDES/login_screen.dart" "$MOBILE_DIR/lib/screens/login_screen.dart"
cp "$OVERRIDES/city_carousel.dart" "$MOBILE_DIR/lib/screens/city_carousel.dart"
bash "$OVERRIDES/prepare_city_assets.sh" "$MOBILE_DIR"
cp "$OVERRIDES/main.dart" "$MOBILE_DIR/lib/main.dart"
cp "$OVERRIDES/design_system.dart" "$MOBILE_DIR/lib/design_system.dart"
cp "$OVERRIDES/localizations.dart" "$MOBILE_DIR/lib/localizations.dart"
cp "$OVERRIDES/api.dart" "$MOBILE_DIR/lib/core/api.dart"
cp "$OVERRIDES/app_shell.dart" "$MOBILE_DIR/lib/screens/app_shell.dart"
cp "$OVERRIDES/admin_screens.dart" "$MOBILE_DIR/lib/screens/admin_screens.dart"
cp "$OVERRIDES/customer_screens.dart" "$MOBILE_DIR/lib/screens/customer_screens.dart"
cp "$OVERRIDES/peer_delivery_screen.dart" "$MOBILE_DIR/lib/screens/peer_delivery_screen.dart"
cp "$OVERRIDES/vendor_screens.dart" "$MOBILE_DIR/lib/screens/vendor_screens.dart"
cp "$OVERRIDES/driver_screens.dart" "$MOBILE_DIR/lib/screens/driver_screens.dart"
cp "$OVERRIDES/account_screens.dart" "$MOBILE_DIR/lib/screens/account_screens.dart"
cp "$OVERRIDES/account_pages.dart" "$MOBILE_DIR/lib/screens/account_pages.dart"
cp "$OVERRIDES/notifications.dart" "$MOBILE_DIR/lib/notifications.dart"
cp "$OVERRIDES/app_update.dart" "$MOBILE_DIR/lib/app_update.dart"

cp "$OVERRIDES/MainActivity.kt" "$MOBILE_DIR/android/app/src/main/kotlin/com/darb/darb/MainActivity.kt"
cp "$OVERRIDES/DarbUpdateDownloadReceiver.kt" "$MOBILE_DIR/android/app/src/main/kotlin/com/darb/darb/DarbUpdateDownloadReceiver.kt"
cp "$OVERRIDES/darb_file_paths.xml" "$MOBILE_DIR/android/app/src/main/res/xml/darb_file_paths.xml"
cp "$OVERRIDES/ic_launcher.xml" "$MOBILE_DIR/android/app/src/main/res/drawable/ic_launcher.xml"

python3 - "$MOBILE_DIR/pubspec.yaml" "$MOBILE_DIR/android/app/src/main/AndroidManifest.xml" <<'PY'
from pathlib import Path
import sys

pubspec, manifest = map(Path, sys.argv[1:])
lines = pubspec.read_text().splitlines()
dependencies = [
    "  geolocator: ^13.0.2",
    "  url_launcher: ^6.3.1",
    "  firebase_core: ^3.8.1",
    "  firebase_messaging: ^15.1.6",
    "  package_info_plus: ^8.1.2",
    "  crypto: ^3.0.6",
    "  path_provider: ^2.1.5",
    "  intl: ^0.20.3",
    "  google_sign_in: ^6.2.1",
]
dep_index = next((i for i, line in enumerate(lines) if line.strip() == "dependencies:"), None)
if dep_index is None:
    raise SystemExit("pubspec.yaml has no dependencies section")
for dependency in dependencies:
    name = dependency.split(":")[0].strip()
    if not any(line.strip().startswith(name + ":") for line in lines[dep_index + 1:]):
        dep_index += 1
        lines.insert(dep_index, dependency)
pubspec.write_text("\n".join(lines) + "\n")

text = manifest.read_text()
internet = '<uses-permission android:name="android.permission.INTERNET" />'
if internet not in text:
    raise SystemExit("AndroidManifest.xml has no INTERNET permission anchor")
for permission in (
    "ACCESS_FINE_LOCATION",
    "ACCESS_COARSE_LOCATION",
    "POST_NOTIFICATIONS",
    "REQUEST_INSTALL_PACKAGES",
):
    tag = f'<uses-permission android:name="android.permission.{permission}" />'
    if tag not in text:
        text = text.replace(internet, internet + "\n    " + tag, 1)

receiver = """    <receiver
        android:name=".DarbUpdateDownloadReceiver"
        android:exported="false">
        <intent-filter>
            <action android:name="android.intent.action.DOWNLOAD_COMPLETE" />
        </intent-filter>
    </receiver>"""
provider = """    <provider
        android:name="androidx.core.content.FileProvider"
        android:authorities="${applicationId}.fileprovider"
        android:exported="false"
        android:grantUriPermissions="true">
        <meta-data
            android:name="android.support.FILE_PROVIDER_PATHS"
            android:resource="@xml/darb_file_paths" />
    </provider>"""
if "DarbUpdateDownloadReceiver" not in text:
    text = text.replace("</application>", receiver + "\n    </application>", 1)
if "androidx.core.content.FileProvider" not in text:
    text = text.replace("</application>", provider + "\n    </application>", 1)
text = text.replace('android:icon="@mipmap/ic_launcher"', 'android:icon="@drawable/ic_launcher"')
manifest.write_text(text)
PY

mkdir -p "$OUT_DIR"
cp -a "$MOBILE_DIR/." "$OUT_DIR/"

cat > "$OUT_DIR/ANDROID-STUDIO-SETUP.txt" <<'SETUP'
DARB — Flutter Android Studio package

1. Install Flutter SDK and Android Studio.
2. Install the Flutter plugin in Android Studio (the Dart plugin is installed with it).
3. Open this extracted project folder — the folder containing pubspec.yaml.
4. Run in the Android Studio Terminal:
   flutter doctor
   flutter pub get
   flutter analyze
5. Connect an Android phone with USB debugging enabled, or start an emulator.
6. Run:
   flutter devices
   flutter run

Google Sign-In:
Supply the existing Web/server OAuth client ID without changing Firebase or OAuth
console credentials:
   flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_WEB_CLIENT_ID

The existing Android Gradle project, applicationId, Firebase files, signing
configuration, and release versioning are preserved. Do not change applicationId
or signing keys if you need in-place updates for existing DARB installations.
SETUP

echo "Prepared Flutter project: $OUT_DIR"
echo "Open this folder in Android Studio; it must contain pubspec.yaml."
