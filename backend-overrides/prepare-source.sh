#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:?source root required}"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import json, sys
root = Path(sys.argv[1])
backend = root / "backend"
mobile = root / "mobile"

package = backend / "package.json"
data = json.loads(package.read_text())
data.setdefault("dependencies", {})["google-auth-library"] = "^9.15.1"
data["dependencies"]["firebase-admin"] = "^12.7.0"
package.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")

pubspec = mobile / "pubspec.yaml"
s = pubspec.read_text()
deps = [
    "  google_sign_in: ^6.2.1",
    "  geolocator: ^13.0.2",
    "  url_launcher: ^6.3.1",
    "  firebase_core: ^3.8.1",
    "  firebase_messaging: ^15.1.6",
]
for dep in deps:
    name = dep.split(":")[0].strip()
    if name + ":" not in s:
        s = s.replace(
            "  flutter_secure_storage: ^9.2.2\n",
            "  flutter_secure_storage: ^9.2.2\n" + dep + "\n",
        )
pubspec.write_text(s)

manifest = mobile / "android/app/src/main/AndroidManifest.xml"
m = manifest.read_text()
for permission in [
    '<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />',
    '<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />',
    '<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />',
]:
    if permission not in m:
        m = m.replace(
            '<uses-permission android:name="android.permission.INTERNET" />',
            '<uses-permission android:name="android.permission.INTERNET" />\n    ' + permission,
        )
manifest.write_text(m)
PY
