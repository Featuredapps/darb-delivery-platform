# Google Sign-In setup for DARB

The mobile app and NestJS API already contain the Google ID-token sign-in flow. A successful Android build alone does **not** prove Google Sign-In is configured: Google requires an Android OAuth client (package name + signing SHA-1) and a Web OAuth client ID used as the token audience.

## 1. Create the OAuth clients in Google Cloud

1. Open the Google Cloud project used by DARB and configure the OAuth consent screen / Google Auth Platform branding and audience.
2. If the app is still in Testing mode, add the Google accounts that will test sign-in as test users.
3. Create an OAuth client ID with application type **Android**. Use the exact Android package name and release SHA-1 printed in the **Google OAuth setup for this Android release** section of the GitHub Actions run summary.
4. Create a second OAuth client ID with application type **Web application**. This is the **Web client ID**. The backend verifies incoming ID tokens against this audience; do not use the Android client ID here.

## 2. Configure the same Web client ID in both environments

- GitHub repository → Settings → Secrets and variables → Actions → New repository secret:
  - Name: `GOOGLE_SERVER_CLIENT_ID`
  - Value: the Web application client ID ending in `.apps.googleusercontent.com`
- Render → `darb-api` service → Environment:
  - Key: `GOOGLE_SERVER_CLIENT_ID`
  - Value: the exact same Web application client ID

Save the Render environment change and wait for the service to redeploy. The Render Blueprint declares this variable as manually supplied; it cannot be populated safely by the repository.

## 3. Build and verify

1. Run **Build signed DARB Android release** from GitHub Actions (or merge this change to `main`, which triggers it).
2. Confirm the run succeeds and its summary prints the Android package name and release signing SHA-1.
3. Install the APK from the `darb-android-signed-release` artifact on a device and select **Continue with Google**.
4. Confirm the API returns tokens and the app opens the customer shell. A build passing is not a substitute for this real-account device test.

## Important

- The Android OAuth client must match the **release** signing certificate. A debug APK has a different SHA-1.
- If the signing key changes, register the new SHA-1 and rebuild.
- Keep the Web client ID public only as an OAuth client identifier; never commit private keys, service-account JSON, or signing passwords.
- If Google Cloud's consent screen is in Testing mode, accounts not listed as test users may be blocked.
